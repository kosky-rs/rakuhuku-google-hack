"""Multi-Agent Style System using Google ADK"""
import logging
import uuid
from typing import Dict, List, Optional

from agent.adk_config import get_agent_config
from agent.tools.closet import get_closet_items
from agent.tools.rakuten_api import search_rakuten_products, supplement_outfit_with_rakuten

logger = logging.getLogger(__name__)

# ==================== ベースエージェントクラス ====================


class BaseStyleAgent:
    """Base class for style agents"""

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

    async def generate_outfit(
        self,
        user_id: str,
        context: Dict,
    ) -> Dict:
        """
        Generate outfit recommendation

        Args:
            user_id: User ID
            context: Context including:
                - weather: Weather data
                - tpo: TPO requirements
                - user_preferences: User preferences

        Returns:
            dict: Outfit recommendation
        """
        raise NotImplementedError("Subclasses must implement generate_outfit()")

    def _score_outfit(
        self,
        items: List[Dict],
        weather: Dict,
        tpo: Dict,
        user_preferences: Dict,
    ) -> float:
        """
        Score outfit based on multiple factors

        Args:
            items: List of clothing items
            weather: Weather context
            tpo: TPO context
            user_preferences: User preferences

        Returns:
            float: Score (0-100)
        """
        scores = []

        # Weather appropriateness (0-100)
        weather_score = self._score_weather_appropriateness(items, weather)
        scores.append(weather_score * 0.3)

        # TPO match (0-100)
        tpo_score = self._score_tpo_match(items, tpo)
        scores.append(tpo_score * 0.4)

        # User preference alignment (0-100)
        pref_score = self._score_preference_alignment(items, user_preferences)
        scores.append(pref_score * 0.2)

        # Agent style confidence (0-100)
        style_score = self._score_style_confidence(items)
        scores.append(style_score * 0.1)

        total = sum(scores)
        return round(min(100, max(0, total)), 2)

    def _score_weather_appropriateness(self, items: List[Dict], weather: Dict) -> float:
        """Score based on weather appropriateness"""
        temp = weather.get("temperature", 20)
        score = 50.0  # Base score

        # Temperature-based scoring
        for item in items:
            temp_range = item.get("temperature_range", {})
            if temp_range:
                min_temp = temp_range.get("min", 0)
                max_temp = temp_range.get("max", 40)
                if min_temp <= temp <= max_temp:
                    score += 10
                else:
                    score -= 5

        # Season-based scoring
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

            # Exact match
            if item_level == required_level:
                score += 15
            # Close match (within 1 level)
            elif abs(item_level - required_level) == 1:
                score += 5
            # Mismatch
            else:
                score -= 10

        return min(100, max(0, score))

    def _score_preference_alignment(self, items: List[Dict], user_preferences: Dict) -> float:
        """Score based on user preference alignment"""
        score = 50.0

        # Style scores
        style_scores = user_preferences.get("style_scores", {})
        agent_pref = style_scores.get(self.agent_type, 50)
        score += (agent_pref - 50) * 0.5

        # Color preferences
        color_prefs = user_preferences.get("color_preferences", {})
        for item in items:
            color = item.get("color")
            if color and color in color_prefs:
                color_score = color_prefs[color]
                score += (color_score - 50) * 0.2

        return min(100, max(0, score))

    def _score_style_confidence(self, items: List[Dict]) -> float:
        """Score based on agent's style confidence"""
        # Base confidence for this agent type
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
        """
        Generate detailed reasoning for outfit recommendation

        Enhanced with:
        - Temperature-specific context
        - TPO mapping with detailed descriptions
        - Trend color detection
        - Weather condition considerations
        """
        temp = weather.get("temperature", 20)
        formality = tpo.get("formality_required", "casual")
        condition = weather.get("condition", "晴れ")

        # Detect trend colors in the outfit
        colors = [item.get("color") for item in items if item.get("color")]
        trend_colors = self._detect_trend_colors(colors)

        reasoning_parts = []

        # 1. Agent type and AI score
        reasoning_parts.append(
            f"{self.agent_type.capitalize()}スタイル（AIスコア: {score:.1f}/100）"
        )

        # 2. Temperature context (more detailed)
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

        # 3. TPO context (detailed mapping)
        tpo_map = {
            'formal': 'フォーマルな場に相応しいエレガントな装い',
            'business_casual': 'ビジネスシーンで好印象を与える洗練スタイル',
            'casual': 'リラックスした雰囲気の動きやすいコーデ',
        }
        reasoning_parts.append(tpo_map.get(formality, 'バランスの取れた装い'))

        # 4. Trend colors (if detected)
        if trend_colors:
            reasoning_parts.append(
                f"今季トレンドの{', '.join(trend_colors)}を取り入れた旬な配色"
            )

        # 5. Weather condition special notes
        if condition.lower() in ['rain', '雨']:
            reasoning_parts.append("雨天に配慮した撥水素材推奨")
        elif condition.lower() in ['snow', '雪']:
            reasoning_parts.append("雪の日に対応した防水・防寒仕様")

        return '。'.join(reasoning_parts) + '。'

    def _detect_trend_colors(self, colors: List[str]) -> List[str]:
        """
        Detect 2026 trend colors in the outfit

        2026 Trend Colors:
        - ベージュ (Beige) - Earth tones
        - アースカラー (Earth colors) - Natural tones
        - グリーン (Green) - Nature-inspired
        - ラベンダー (Lavender) - Soft purple
        - テラコッタ (Terracotta) - Warm clay tones

        Args:
            colors: List of color names from items

        Returns:
            list: Detected trend colors (max 2)
        """
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
                # Check if any keyword matches
                if any(keyword.lower() in color_lower for keyword in keywords):
                    if trend_name not in detected:
                        detected.append(trend_name)

            # Stop after finding 2 trend colors
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

    async def generate_outfit(self, user_id: str, context: Dict) -> Dict:
        """Generate casual outfit from closet with Rakuten supplementation"""
        weather = context.get("weather", {})
        tpo = context.get("tpo", {})
        user_preferences = context.get("user_preferences", {})

        # Get casual items from closet
        items = await get_closet_items(
            user_id=user_id,
            formality="casual",
        )

        if not items:
            logger.warning(f"No casual items found for user {user_id}")
            return self._empty_outfit()

        # Select items by category
        selected_items = self._select_items_by_category(items)

        if not selected_items:
            return self._empty_outfit()

        # Create initial outfit
        outfit = {
            "outfit_id": str(uuid.uuid4()),
            "agent_type": self.agent_type,
            "items": selected_items,
            "score": 0,
            "reasoning": "",
            "source": "closet",
        }

        # Detect missing categories and supplement with Rakuten
        required_categories = ["tops", "bottoms", "shoes"]
        present_categories = [item.get("category") for item in selected_items]
        missing_categories = [cat for cat in required_categories if cat not in present_categories]

        if missing_categories:
            gender = user_preferences.get("gender", "male")
            outfit = await supplement_outfit_with_rakuten(
                outfit,
                missing_categories,
                weather,
                gender,
            )
            # Update items list with supplemented products
            selected_items = outfit["items"]

        # Score the outfit
        score = self._score_outfit(selected_items, weather, tpo, user_preferences)
        outfit["score"] = score

        # Generate reasoning
        reasoning = self._generate_reasoning(selected_items, weather, tpo, score)
        outfit["reasoning"] = reasoning

        return outfit

    def _select_items_by_category(self, items: List[Dict]) -> List[Dict]:
        """Select one item from each category"""
        selected = []
        categories = ["tops", "bottoms", "shoes"]

        for category in categories:
            category_items = [item for item in items if item.get("category") == category]
            if category_items:
                # Pick first item (can be improved with better selection logic)
                selected.append(category_items[0])

        return selected

    def _empty_outfit(self) -> Dict:
        """Return empty outfit structure"""
        return {
            "outfit_id": str(uuid.uuid4()),
            "agent_type": self.agent_type,
            "items": [],
            "score": 0,
            "reasoning": "クローゼットにカジュアルアイテムが見つかりませんでした。",
            "source": "closet",
        }


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

    async def generate_outfit(self, user_id: str, context: Dict) -> Dict:
        """Generate formal outfit from closet with Rakuten supplementation"""
        weather = context.get("weather", {})
        tpo = context.get("tpo", {})
        user_preferences = context.get("user_preferences", {})

        # Get formal/business casual items
        items = await get_closet_items(
            user_id=user_id,
            formality="formal",
        )

        if not items:
            # Fallback to business casual
            items = await get_closet_items(
                user_id=user_id,
                formality="business_casual",
            )

        if not items:
            logger.warning(f"No formal items found for user {user_id}")
            return self._empty_outfit()

        selected_items = self._select_items_by_category(items)

        if not selected_items:
            return self._empty_outfit()

        # Create initial outfit
        outfit = {
            "outfit_id": str(uuid.uuid4()),
            "agent_type": self.agent_type,
            "items": selected_items,
            "score": 0,
            "reasoning": "",
            "source": "closet",
        }

        # Detect missing categories and supplement with Rakuten
        required_categories = ["tops", "bottoms", "outerwear", "shoes"]
        present_categories = [item.get("category") for item in selected_items]
        missing_categories = [cat for cat in required_categories if cat not in present_categories]

        if missing_categories:
            gender = user_preferences.get("gender", "male")
            outfit = await supplement_outfit_with_rakuten(
                outfit,
                missing_categories,
                weather,
                gender,
            )
            selected_items = outfit["items"]

        # Score the outfit
        score = self._score_outfit(selected_items, weather, tpo, user_preferences)
        outfit["score"] = score

        # Generate reasoning
        reasoning = self._generate_reasoning(selected_items, weather, tpo, score)
        outfit["reasoning"] = reasoning

        return outfit

    def _select_items_by_category(self, items: List[Dict]) -> List[Dict]:
        """Select formal items by category"""
        selected = []
        categories = ["tops", "bottoms", "outerwear", "shoes"]

        for category in categories:
            category_items = [item for item in items if item.get("category") == category]
            if category_items:
                selected.append(category_items[0])

        return selected

    def _empty_outfit(self) -> Dict:
        return {
            "outfit_id": str(uuid.uuid4()),
            "agent_type": self.agent_type,
            "items": [],
            "score": 0,
            "reasoning": "クローゼットにフォーマルアイテムが見つかりませんでした。",
            "source": "closet",
        }


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

    async def generate_outfit(self, user_id: str, context: Dict) -> Dict:
        """Generate balanced outfit from closet with Rakuten supplementation"""
        weather = context.get("weather", {})
        tpo = context.get("tpo", {})
        user_preferences = context.get("user_preferences", {})

        # Get business casual items
        items = await get_closet_items(
            user_id=user_id,
            formality="business_casual",
        )

        if not items:
            # Mix casual and formal
            casual_items = await get_closet_items(user_id=user_id, formality="casual")
            formal_items = await get_closet_items(user_id=user_id, formality="formal")
            items = casual_items + formal_items

        if not items:
            logger.warning(f"No items found for user {user_id}")
            return self._empty_outfit()

        selected_items = self._select_items_by_category(items)

        if not selected_items:
            return self._empty_outfit()

        # Create initial outfit
        outfit = {
            "outfit_id": str(uuid.uuid4()),
            "agent_type": self.agent_type,
            "items": selected_items,
            "score": 0,
            "reasoning": "",
            "source": "closet",
        }

        # Detect missing categories and supplement with Rakuten
        required_categories = ["tops", "bottoms", "shoes"]
        present_categories = [item.get("category") for item in selected_items]
        missing_categories = [cat for cat in required_categories if cat not in present_categories]

        if missing_categories:
            gender = user_preferences.get("gender", "male")
            outfit = await supplement_outfit_with_rakuten(
                outfit,
                missing_categories,
                weather,
                gender,
            )
            selected_items = outfit["items"]

        # Score the outfit
        score = self._score_outfit(selected_items, weather, tpo, user_preferences)
        outfit["score"] = score

        # Generate reasoning
        reasoning = self._generate_reasoning(selected_items, weather, tpo, score)
        outfit["reasoning"] = reasoning

        return outfit

    def _select_items_by_category(self, items: List[Dict]) -> List[Dict]:
        """Select balanced items"""
        selected = []
        categories = ["tops", "bottoms", "shoes"]

        for category in categories:
            category_items = [item for item in items if item.get("category") == category]
            if category_items:
                selected.append(category_items[0])

        return selected

    def _empty_outfit(self) -> Dict:
        return {
            "outfit_id": str(uuid.uuid4()),
            "agent_type": self.agent_type,
            "items": [],
            "score": 0,
            "reasoning": "クローゼットにバランス型アイテムが見つかりませんでした。",
            "source": "closet",
        }


# ==================== ユニークエージェント（外部商品） ====================


class UniqueStyleAgent(BaseStyleAgent):
    """Unique style specialist agent using external products"""

    def __init__(self):
        super().__init__(
            agent_type="unique",
            style_instructions="Recommend bold, distinctive outfits using external products",
            color_palette=["bold_colors", "patterns", "statement_pieces"],
            formality_preference="casual",
        )

    async def generate_outfit(self, user_id: str, context: Dict) -> Dict:
        """Generate unique outfit using Rakuten products"""
        weather = context.get("weather", {})
        tpo = context.get("tpo", {})
        user_preferences = context.get("user_preferences", {})

        # Determine gender from user preferences
        gender = user_preferences.get("gender", "male")

        # Search for unique products from Rakuten
        external_products = []

        try:
            # Search for statement pieces
            categories = ["tops", "bottoms", "shoes"]
            for category in categories:
                products = await search_rakuten_products(
                    category=category,
                    style="トレンド",
                    gender=gender,
                    max_results=2,
                )
                if products:
                    external_products.extend(products[:1])  # Take 1 per category

        except Exception as e:
            logger.error(f"Rakuten search failed: {e}")
            return self._empty_outfit()

        if not external_products:
            logger.warning("No external products found")
            return self._empty_outfit()

        # Score based on trend relevance and price
        score = self._score_external_outfit(external_products, weather, tpo, user_preferences)

        reasoning = (
            f"Uniqueスタイルの外部商品提案（スコア: {score:.1f}）。"
            f"楽天から厳選したトレンドアイテムをご紹介。"
        )

        return {
            "outfit_id": str(uuid.uuid4()),
            "agent_type": self.agent_type,
            "items": [],  # No closet items
            "score": score,
            "reasoning": reasoning,
            "source": "external",
            "external_products": external_products,
        }

    def _score_external_outfit(
        self,
        products: List[Dict],
        weather: Dict,
        tpo: Dict,
        user_preferences: Dict,
    ) -> float:
        """Score external product outfit"""
        base_score = 60.0

        # Review-based scoring
        for product in products:
            review_avg = product.get("review_average", 0)
            if review_avg:
                base_score += (review_avg - 3) * 5  # Boost for high ratings

        # Price-based scoring (moderate price = higher score)
        for product in products:
            price = product.get("price", 5000)
            if 3000 <= price <= 15000:
                base_score += 5
            elif price > 30000:
                base_score -= 5

        return min(100, max(0, base_score))

    def _empty_outfit(self) -> Dict:
        return {
            "outfit_id": str(uuid.uuid4()),
            "agent_type": self.agent_type,
            "items": [],
            "score": 0,
            "reasoning": "外部商品が見つかりませんでした。",
            "source": "external",
            "external_products": [],
        }
