"""Multi-Agent Style System using Google ADK + Gemini LLM"""
import logging
import uuid
from typing import Dict, List, Optional

from agent.adk_config import get_agent_config
from agent.tools.closet import get_closet_items
from agent.tools.gemini_outfit_composer import compose_outfit_with_gemini, generate_marketplace_links
from agent.tools.rakuten_api import supplement_outfit_with_rakuten

logger = logging.getLogger(__name__)

# ==================== ベースエージェントクラス ====================


class BaseStyleAgent:
    """Base class for style agents with Gemini LLM outfit composition"""

    def __init__(
        self,
        agent_type: str,
        style_instructions: str,
        color_palette: List[str],
        formality_preference: str,
    ):
        """
        Initialize style agent

        Args:
            agent_type: Agent type (casual, formal, balanced, unique)
            style_instructions: Instructions for outfit generation
            color_palette: Preferred color palette
            formality_preference: Preferred formality level
        """
        self.agent_type = agent_type
        self.style_instructions = style_instructions
        self.color_palette = color_palette
        self.formality_preference = formality_preference

        # ADK configuration
        self.config = get_agent_config()

    @property
    def agent_persona_prompt(self) -> str:
        """Agent-specific Gemini system prompt. Override in subclasses."""
        return "あなたはファッションスタイリストです。最適なコーディネートを提案してください。"

    async def generate_outfit(
        self,
        user_id: str,
        context: Dict,
    ) -> Dict:
        """
        Generate outfit recommendation using Gemini LLM.

        Falls back to deterministic selection if Gemini fails.

        Args:
            user_id: User ID
            context: Context including:
                - weather: Weather data
                - tpo: TPO requirements
                - user_preferences: User preferences
                - closet_items: Pre-fetched closet items (optional, fetched if missing)

        Returns:
            dict: Outfit recommendation
        """
        weather = context.get("weather", {})
        tpo = context.get("tpo", {})
        user_preferences = context.get("user_preferences", {})
        gender = user_preferences.get("gender", "male")

        # Use pre-fetched closet items from orchestrator, or fetch if not provided
        closet_items = context.get("closet_items")
        if closet_items is None:
            closet_items = await get_closet_items(user_id=user_id)

        # Try Gemini LLM composition
        try:
            gemini_result = await compose_outfit_with_gemini(
                closet_items=closet_items,
                weather=weather,
                tpo=tpo,
                user_preferences=user_preferences,
                agent_persona=self.agent_persona_prompt,
                gender=gender,
            )

            selected_items = gemini_result["selected_items"]
            reasoning = gemini_result["reasoning"]
            score = gemini_result["confidence_score"]
            image_prompt_en = gemini_result.get("image_prompt_en", "")

            # Determine outfit source
            has_external = any(i.get("item_source") == "external" for i in selected_items)
            has_closet = any(i.get("item_source") == "closet" for i in selected_items)
            if has_external and has_closet:
                source = "mixed"
            elif has_external:
                source = "external"
            else:
                source = "closet"

            logger.info(f"[{self.agent_type}] Gemini composed {len(selected_items)} items (source={source}, score={score})")

            return {
                "outfit_id": str(uuid.uuid4()),
                "agent_type": self.agent_type,
                "items": selected_items,
                "score": score,
                "reasoning": reasoning,
                "source": source,
                "image_prompt_en": image_prompt_en,
            }

        except Exception as e:
            logger.warning(f"[{self.agent_type}] Gemini failed, using fallback: {e}")
            return await self._fallback_generate(user_id, closet_items, weather, tpo, user_preferences, gender)

    async def _fallback_generate(
        self,
        user_id: str,
        closet_items: List[Dict],
        weather: Dict,
        tpo: Dict,
        user_preferences: Dict,
        gender: str,
    ) -> Dict:
        """
        Fallback outfit generation using deterministic logic.
        Preserves the original behavior when Gemini is unavailable.
        """
        # Filter by formality preference
        filtered = [i for i in closet_items if i.get("formality") == self.formality_preference]
        if not filtered:
            filtered = closet_items

        # Select one item per required category
        selected_items = []
        for cat in ["tops", "bottoms", "shoes"]:
            cat_items = [i for i in filtered if i.get("category") == cat]
            if cat_items:
                item = cat_items[0].copy()
                item["item_source"] = "closet"
                selected_items.append(item)

        # Create initial outfit
        outfit = {
            "outfit_id": str(uuid.uuid4()),
            "agent_type": self.agent_type,
            "items": selected_items,
            "score": 0,
            "reasoning": "",
            "source": "closet",
        }

        # Supplement missing categories
        required_categories = ["tops", "bottoms", "shoes"]
        present_categories = [item.get("category") for item in selected_items]
        missing_categories = [cat for cat in required_categories if cat not in present_categories]

        if missing_categories:
            logger.info(f"[{self.agent_type}] Fallback: missing {missing_categories}, supplementing")
            outfit = await supplement_outfit_with_rakuten(outfit, missing_categories, weather, gender)
            selected_items = outfit["items"]
            # Mark supplemented items as external
            for item in selected_items:
                if not item.get("item_source"):
                    item["item_source"] = "external"
                    keyword = item.get("name", "")
                    if keyword:
                        item["marketplace_links"] = generate_marketplace_links(keyword)

        if not selected_items:
            return self._empty_outfit()

        # Score and reason
        score = self._score_outfit(selected_items, weather, tpo, user_preferences)
        outfit["score"] = score
        outfit["reasoning"] = self._generate_reasoning(selected_items, weather, tpo, score)

        return outfit

    def _empty_outfit(self) -> Dict:
        """Return empty outfit structure"""
        return {
            "outfit_id": str(uuid.uuid4()),
            "agent_type": self.agent_type,
            "items": [],
            "score": 0,
            "reasoning": f"コーディネートを生成できませんでした。",
            "source": "closet",
        }

    # ==================== スコアリング（フォールバック用） ====================

    def _score_outfit(
        self,
        items: List[Dict],
        weather: Dict,
        tpo: Dict,
        user_preferences: Dict,
    ) -> float:
        """Score outfit based on multiple factors"""
        scores = []

        weather_score = self._score_weather_appropriateness(items, weather)
        scores.append(weather_score * 0.3)

        tpo_score = self._score_tpo_match(items, tpo)
        scores.append(tpo_score * 0.4)

        pref_score = self._score_preference_alignment(items, user_preferences)
        scores.append(pref_score * 0.2)

        style_score = self._score_style_confidence(items)
        scores.append(style_score * 0.1)

        total = sum(scores)
        return round(min(100, max(0, total)), 2)

    def _score_weather_appropriateness(self, items: List[Dict], weather: Dict) -> float:
        """Score based on weather appropriateness"""
        temp = weather.get("temperature", 20)
        score = 50.0

        for item in items:
            temp_range = item.get("temperature_range", {})
            if temp_range:
                min_temp = temp_range.get("min", 0)
                max_temp = temp_range.get("max", 40)
                if min_temp <= temp <= max_temp:
                    score += 10
                else:
                    score -= 5

        current_season = self._infer_season_from_temp(temp)
        for item in items:
            seasons = item.get("season", [])
            if current_season in seasons or "all_season" in seasons:
                score += 10

        return min(100, max(0, score))

    def _score_tpo_match(self, items: List[Dict], tpo: Dict) -> float:
        """Score based on TPO match"""
        required_formality = tpo.get("formality_required", "casual")
        score = 50.0

        formality_map = {
            "casual": 1,
            "business_casual": 2,
            "formal": 3,
        }

        required_level = formality_map.get(required_formality, 2)

        for item in items:
            item_formality = item.get("formality", "casual")
            item_level = formality_map.get(item_formality, 1)

            if item_level == required_level:
                score += 15
            elif abs(item_level - required_level) == 1:
                score += 5
            else:
                score -= 10

        return min(100, max(0, score))

    def _score_preference_alignment(self, items: List[Dict], user_preferences: Dict) -> float:
        """Score based on user preference alignment"""
        score = 50.0

        style_scores = user_preferences.get("style_scores", {})
        agent_pref = style_scores.get(self.agent_type, 50)
        score += (agent_pref - 50) * 0.5

        color_prefs = user_preferences.get("color_preferences", {})
        for item in items:
            color = item.get("color")
            if color and color in color_prefs:
                color_score = color_prefs[color]
                score += (color_score - 50) * 0.2

        return min(100, max(0, score))

    def _score_style_confidence(self, items: List[Dict]) -> float:
        """Score based on agent's style confidence"""
        return 70.0

    def _infer_season_from_temp(self, temp: float) -> str:
        """Infer season from temperature"""
        if temp < 10:
            return "winter"
        elif temp < 15:
            return "autumn"
        elif temp < 25:
            return "spring"
        else:
            return "summer"

    def _generate_reasoning(
        self,
        items: List[Dict],
        weather: Dict,
        tpo: Dict,
        score: float,
    ) -> str:
        """Generate detailed reasoning for outfit recommendation (fallback)"""
        temp = weather.get("temperature", 20)
        formality = tpo.get("formality_required", "casual")
        condition = weather.get("condition", "晴れ")

        colors = [item.get("color") for item in items if item.get("color")]
        trend_colors = self._detect_trend_colors(colors)

        reasoning_parts = []

        reasoning_parts.append(
            f"{self.agent_type.capitalize()}スタイル（AIスコア: {score:.1f}/100）"
        )

        if temp < 10:
            reasoning_parts.append(f"極寒の{temp}°Cに対応した防寒重視コーデ")
        elif temp < 15:
            reasoning_parts.append(f"肌寒い{temp}°Cに最適なレイヤードスタイル")
        elif temp < 20:
            reasoning_parts.append(f"過ごしやすい{temp}°Cに合わせた快適スタイル")
        elif temp < 25:
            reasoning_parts.append(f"春らしい{temp}°Cで軽やかな印象のコーデ")
        else:
            reasoning_parts.append(f"暑い{temp}°Cでも快適な通気性重視コーデ")

        tpo_map = {
            'formal': 'フォーマルな場に相応しいエレガントな装い',
            'business_casual': 'ビジネスシーンで好印象を与える洗練スタイル',
            'casual': 'リラックスした雰囲気の動きやすいコーデ',
        }
        reasoning_parts.append(tpo_map.get(formality, 'バランスの取れた装い'))

        if trend_colors:
            reasoning_parts.append(
                f"今季トレンドの{', '.join(trend_colors)}を取り入れた旬な配色"
            )

        if condition.lower() in ['rain', '雨']:
            reasoning_parts.append("雨天に配慮した撥水素材推奨")
        elif condition.lower() in ['snow', '雪']:
            reasoning_parts.append("雪の日に対応した防水・防寒仕様")

        return '。'.join(reasoning_parts) + '。'

    def _detect_trend_colors(self, colors: List[str]) -> List[str]:
        """Detect 2026 trend colors in the outfit"""
        trend_colors_2026 = {
            'ベージュ': ['beige', 'ベージュ', 'タン'],
            'アースカラー': ['earth', 'アース', 'ブラウン', 'brown', 'カーキ', 'khaki'],
            'グリーン': ['green', 'グリーン', '緑', 'オリーブ', 'olive'],
            'ラベンダー': ['lavender', 'ラベンダー', 'purple', 'パープル', '紫'],
            'テラコッタ': ['terracotta', 'テラコッタ', 'オレンジ', 'orange'],
        }

        detected = []

        for color_input in colors:
            if not color_input:
                continue

            color_lower = color_input.lower()

            for trend_name, keywords in trend_colors_2026.items():
                if any(keyword.lower() in color_lower for keyword in keywords):
                    if trend_name not in detected:
                        detected.append(trend_name)

            if len(detected) >= 2:
                break

        return detected


# ==================== カジュアルエージェント ====================


class CasualStyleAgent(BaseStyleAgent):
    """Casual style specialist agent"""

    def __init__(self):
        super().__init__(
            agent_type="casual",
            style_instructions="Create relaxed, comfortable outfits for everyday wear",
            color_palette=["denim", "beige", "olive", "gray", "white"],
            formality_preference="casual",
        )

    @property
    def agent_persona_prompt(self) -> str:
        return """あなたはカジュアルファッション専門のスタイリストです。
リラックスした日常スタイルを提案します。

重視するポイント:
- 着心地と動きやすさを最優先
- デニム、Tシャツ、スニーカーなどカジュアルアイテムを好む
- 色はアースカラー（ベージュ、オリーブ、グレー）やベーシックカラーを中心に
- カジュアルなアイテムの中でも統一感のある配色を心がける
- フォーマルなアイテムしかない場合でも「カジュアルダウン」する組み合わせを提案
- 休日のお出かけや友人との食事に最適なスタイリング"""


# ==================== フォーマルエージェント ====================


class FormalStyleAgent(BaseStyleAgent):
    """Formal style specialist agent"""

    def __init__(self):
        super().__init__(
            agent_type="formal",
            style_instructions="Create professional, elegant outfits for formal occasions",
            color_palette=["navy", "charcoal", "white", "black", "gray"],
            formality_preference="formal",
        )

    @property
    def agent_persona_prompt(self) -> str:
        return """あなたはフォーマルファッション専門のスタイリストです。
プロフェッショナルでエレガントな装いを提案します。

重視するポイント:
- ビジネスシーンで好印象を与える清潔感を最優先
- ジャケット、ドレスシャツ、革靴などフォーマルアイテムを好む
- 色はネイビー、グレー、白、黒を基調とした上品な配色
- TPO（時・場所・場面）に応じたフォーマル度の調整
- カジュアルアイテムしかない場合でも「ドレスアップ」する組み合わせを提案
- 会議、商談、セミナーなどビジネスシーンに最適なスタイリング"""


# ==================== バランスエージェント ====================


class BalancedStyleAgent(BaseStyleAgent):
    """Balanced style specialist agent"""

    def __init__(self):
        super().__init__(
            agent_type="balanced",
            style_instructions="Create versatile outfits that work for multiple occasions",
            color_palette=["navy", "gray", "beige", "white", "olive"],
            formality_preference="business_casual",
        )

    @property
    def agent_persona_prompt(self) -> str:
        return """あなたはスマートカジュアル専門のスタイリストです。
複数のシーンに対応できる万能なコーディネートを提案します。

重視するポイント:
- オフィスでもプライベートでも違和感のないスタイル
- きれいめカジュアルの絶妙なバランスを追求
- 上品さとリラックス感を両立する配色（ネイビー、グレー、ベージュ）
- 「ちょっとしたお出かけ」にも対応できる汎用性
- 異なるフォーマル度のアイテムをミックスする技術
- オフィスカジュアルやスマートカジュアルドレスコードに最適"""


# ==================== ユニークエージェント ====================


class UniqueStyleAgent(BaseStyleAgent):
    """Unique/trendy style specialist agent"""

    def __init__(self):
        super().__init__(
            agent_type="unique",
            style_instructions="Recommend bold, distinctive outfits with trend-forward styling",
            color_palette=["bold_colors", "patterns", "statement_pieces"],
            formality_preference="casual",
        )

    @property
    def agent_persona_prompt(self) -> str:
        return """あなたはトレンド・個性派ファッション専門のスタイリストです。
最新トレンドを取り入れた個性的なスタイリングを提案します。

重視するポイント:
- 2026年のトレンドカラー（ラベンダー、テラコッタ、アースカラー、グリーン）を積極活用
- 大胆な色の組み合わせやパターンミックスで印象的なコーデを作る
- ステートメントピースを1つ入れてコーデの主役を作る
- クローゼットの意外なアイテムを新しい組み合わせで活かす提案
- クローゼットに足りないトレンドアイテムは外部購入提案を積極的に行う
- ファッション感度の高いスタイリングで差をつける"""
