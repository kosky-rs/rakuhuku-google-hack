"""
Gemini LLM Outfit Composer

Uses Vertex AI Gemini to intelligently compose outfits from closet items
and suggest external items when the closet is lacking.
"""

import json
import logging
import os
import urllib.parse
from typing import Dict, List, Optional

import vertexai
from vertexai.generative_models import GenerativeModel, GenerationConfig

logger = logging.getLogger(__name__)

# Configuration (shared with nano_banana.py / adk_config.py)
PROJECT_ID = os.getenv("GCP_PROJECT_ID", "")
LOCATION = os.getenv("VERTEX_AI_LOCATION", "asia-northeast1")
MODEL_NAME = os.getenv("ADK_MODEL_NAME", "gemini-2.0-flash-001")

_VERTEX_AI_INITIALIZED = False


def _ensure_vertex_ai():
    """Initialize Vertex AI if not already done."""
    global _VERTEX_AI_INITIALIZED
    if not _VERTEX_AI_INITIALIZED:
        try:
            vertexai.init(project=PROJECT_ID, location=LOCATION)
            logger.info(f"Vertex AI initialized for Gemini: project={PROJECT_ID}, location={LOCATION}")
            _VERTEX_AI_INITIALIZED = True
        except Exception as e:
            logger.error(f"Failed to initialize Vertex AI for Gemini: {e}")
            raise


async def compose_outfit_with_gemini(
    closet_items: List[Dict],
    weather: Dict,
    tpo: Dict,
    user_preferences: Dict,
    agent_persona: str,
    gender: str = "male",
) -> Dict:
    """
    Use Gemini to compose an outfit from closet items + external suggestions.

    Args:
        closet_items: All items from user's closet
        weather: Weather context (temperature, condition, description)
        tpo: TPO context (formality_required, summary)
        user_preferences: User preferences (style_scores, color_preferences)
        agent_persona: Agent-specific system prompt (stylist persona)
        gender: User gender

    Returns:
        dict: {
            "selected_items": List[Dict],  # Each with item_source field
            "reasoning": str,
            "confidence_score": float
        }
    """
    _ensure_vertex_ai()

    # Build closet items summary for prompt (keep it concise)
    closet_summary = _build_closet_summary(closet_items)

    # Build user message
    user_message = _build_user_message(closet_summary, weather, tpo, user_preferences, gender)

    try:
        model = GenerativeModel(
            MODEL_NAME,
            system_instruction=agent_persona,
        )

        response = model.generate_content(
            contents=user_message,
            generation_config=GenerationConfig(
                temperature=0.7,
                max_output_tokens=2048,
                response_mime_type="application/json",
            ),
        )

        # Parse response
        result = _parse_gemini_response(response.text, closet_items)
        logger.info(f"Gemini composed outfit with {len(result['selected_items'])} items, score={result['confidence_score']}")
        return result

    except Exception as e:
        logger.error(f"Gemini outfit composition failed: {e}")
        raise


def _build_closet_summary(closet_items: List[Dict]) -> str:
    """Build a concise closet summary for the Gemini prompt."""
    if not closet_items:
        return "クローゼットにアイテムがありません。全て外部アイテムで提案してください。"

    lines = []
    for item in closet_items:
        item_id = item.get("id", "unknown")
        name = item.get("name", "不明")
        category = item.get("category", "")
        color = item.get("color", "")
        formality = item.get("formality", "")
        brand = item.get("brand", "")
        season = item.get("season", [])

        parts = [f"ID:{item_id}", name]
        if category:
            parts.append(f"カテゴリ:{category}")
        if color:
            parts.append(f"色:{color}")
        if formality:
            parts.append(f"フォーマル度:{formality}")
        if brand:
            parts.append(f"ブランド:{brand}")
        if season:
            parts.append(f"季節:{','.join(season)}")

        lines.append(" | ".join(parts))

    return "\n".join(lines)


def _build_user_message(
    closet_summary: str,
    weather: Dict,
    tpo: Dict,
    user_preferences: Dict,
    gender: str,
) -> str:
    """Build the user message for Gemini."""
    temp = weather.get("temperature", 20)
    condition = weather.get("condition", "晴れ")
    description = weather.get("description", "")

    formality_required = tpo.get("formality_required", "casual")
    tpo_summary = tpo.get("summary", "特になし")

    gender_jp = "男性" if gender == "male" else "女性"

    style_scores = user_preferences.get("style_scores", {})
    color_prefs = user_preferences.get("color_preferences", {})

    # Build preferred colors list (score > 60)
    preferred_colors = [c for c, s in color_prefs.items() if s > 60] if color_prefs else []
    color_info = f"好みの色: {', '.join(preferred_colors)}" if preferred_colors else "色の好み: 特になし"

    return f"""## あなたのクローゼット
{closet_summary}

## 今日の天気
気温: {temp}°C
天候: {condition}
{description}

## 今日の予定 (TPO)
フォーマル度: {formality_required}
概要: {tpo_summary}

## ユーザー情報
性別: {gender_jp}
{color_info}

## 指示
上記のクローゼットアイテムと天気・TPOを考慮して、最適なコーディネートを1つ提案してください。

ルール:
1. 必須カテゴリ: tops, bottoms, shoes（必ず各1つ選ぶ）
2. 任意カテゴリ: outerwear（気温15°C以下の場合は推奨）, accessories
3. クローゼットに適切なアイテムがある場合はそれを使う
4. クローゼットに適切なアイテムがない場合は、外部購入アイテムとして具体的な商品名・色を提案する
5. 色の調和、スタイルの統一感、天気への適切さを重視する
6. reasoningは日本語で、なぜこの組み合わせが良いか3-5文で説明する
7. image_prompt_enは英語で、選んだアイテムの色・素材・形状を具体的に描写する（画像生成AI用）

以下のJSON形式で回答してください:
{{
  "selected_items": [
    {{
      "id": "クローゼットアイテムのID（外部アイテムの場合はnull）",
      "name": "アイテム名",
      "category": "tops|bottoms|shoes|outerwear|accessories",
      "color": "色",
      "item_source": "closet または external",
      "search_keyword": "外部アイテムの場合の検索キーワード（日本語）。closetの場合はnull",
      "formality": "casual|business_casual|formal",
      "season": ["spring", "summer", "autumn", "winter"]
    }}
  ],
  "reasoning": "この組み合わせの理由（日本語）",
  "image_prompt_en": "English description of the complete outfit for image generation. Describe each clothing item with its color, material, and style in natural English. Example: 'a black wool turtleneck sweater, navy slim-fit denim jeans, and brown suede chelsea boots'",
  "confidence_score": 75
}}"""


def _parse_gemini_response(response_text: str, closet_items: List[Dict]) -> Dict:
    """
    Parse Gemini's JSON response and validate closet item IDs.

    Args:
        response_text: Raw Gemini response text
        closet_items: Original closet items for ID validation

    Returns:
        dict: Parsed and validated outfit composition
    """
    # Strip markdown code blocks if present
    text = response_text.strip()
    if text.startswith("```json"):
        text = text[7:]
    if text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    text = text.strip()

    result = json.loads(text)

    # Validate required fields
    if "selected_items" not in result:
        raise ValueError("Gemini response missing 'selected_items'")

    # Build valid closet ID set
    valid_ids = {item.get("id") for item in closet_items if item.get("id")}

    # Validate and enrich items
    validated_items = []
    for item in result["selected_items"]:
        # Validate closet item IDs
        if item.get("item_source") == "closet":
            if item.get("id") and item["id"] not in valid_ids:
                logger.warning(f"Gemini selected non-existent closet item: {item['id']}, converting to external")
                item["item_source"] = "external"
                item["search_keyword"] = item.get("name", "ファッションアイテム")
            elif item.get("id") and item["id"] in valid_ids:
                # Enrich with original closet item data
                original = next((ci for ci in closet_items if ci.get("id") == item["id"]), None)
                if original:
                    item["image_url"] = original.get("image_url", original.get("imageUrl"))
                    item["brand"] = original.get("brand")
                    if not item.get("season"):
                        item["season"] = original.get("season", [])
                    if not item.get("formality"):
                        item["formality"] = original.get("formality", "casual")

        # Add marketplace links for external items
        if item.get("item_source") == "external":
            keyword = item.get("search_keyword") or item.get("name", "")
            item["marketplace_links"] = generate_marketplace_links(keyword)

        # Ensure required fields
        item.setdefault("category", "tops")
        item.setdefault("color", "")
        item.setdefault("name", "")
        item.setdefault("item_source", "external")
        item.setdefault("formality", "casual")
        item.setdefault("season", [])

        validated_items.append(item)

    return {
        "selected_items": validated_items,
        "reasoning": result.get("reasoning", "AIによるコーディネート提案です。"),
        "confidence_score": float(result.get("confidence_score", 70)),
        "image_prompt_en": result.get("image_prompt_en", ""),
    }


def generate_marketplace_links(search_keyword: str) -> List[Dict]:
    """
    Generate marketplace search URLs for an external item.

    Args:
        search_keyword: Japanese search keyword for the item

    Returns:
        List[Dict]: Marketplace links for Rakuten, Amazon, ZOZOTOWN
    """
    if not search_keyword:
        return []

    encoded = urllib.parse.quote(search_keyword)

    return [
        {
            "platform": "楽天市場",
            "url": f"https://search.rakuten.co.jp/search/mall/{encoded}/",
            "search_query": search_keyword,
        },
        {
            "platform": "Amazon",
            "url": f"https://www.amazon.co.jp/s?k={encoded}",
            "search_query": search_keyword,
        },
        {
            "platform": "ZOZOTOWN",
            "url": f"https://zozo.jp/search/?p_keyv={encoded}",
            "search_query": search_keyword,
        },
    ]
