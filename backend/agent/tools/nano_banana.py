"""
Nano Banana (Gemini) Image Generation Tool

Generates outfit mannequin images using Google Gemini's Nano Banana image generation.
"""

import os
import logging
from typing import Dict, List
import google.generativeai as genai

logger = logging.getLogger(__name__)

# Configure Gemini API
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
ENABLE_NANO_BANANA = os.getenv("ENABLE_NANO_BANANA", "false").lower() == "true"

if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)


def generate_outfit_mannequin_image(
    items: List[Dict],
    weather: Dict,
    style: str = "casual",
    gender: str = "male",
) -> str:
    """
    Generate a full-body mannequin outfit image using Nano Banana.

    Args:
        items: List of clothing items with name, category, color
        weather: Weather context
        style: Style type (casual, formal, balanced, unique)
        gender: Gender (male, female)

    Returns:
        str: Image URL (or placeholder if generation disabled)
    """
    # If Nano Banana is disabled, return placeholder
    if not ENABLE_NANO_BANANA:
        return _get_placeholder_image_url(style, gender)

    # If API key is missing, return placeholder
    if not GEMINI_API_KEY:
        logger.warning("GEMINI_API_KEY not set. Using placeholder image.")
        return _get_placeholder_image_url(style, gender)

    try:
        # Build prompt from items
        prompt = _build_mannequin_prompt(items, weather, style, gender)

        # Generate image using Gemini
        model = genai.GenerativeModel("gemini-2.0-flash-exp")

        response = model.generate_content(
            prompt,
            generation_config=genai.types.GenerationConfig(
                # Image generation parameters
                temperature=0.7,
            )
        )

        # Extract image URL from response
        if response.candidates and len(response.candidates) > 0:
            candidate = response.candidates[0]
            if hasattr(candidate, 'content') and hasattr(candidate.content, 'parts'):
                for part in candidate.content.parts:
                    if hasattr(part, 'inline_data'):
                        # Image is returned as base64 inline data
                        # For production, upload to Firebase Storage and return URL
                        # For now, return placeholder
                        logger.info("Image generated successfully (inline data)")
                        return _get_placeholder_image_url(style, gender)

        logger.warning("No image generated. Using placeholder.")
        return _get_placeholder_image_url(style, gender)

    except Exception as e:
        logger.error(f"Failed to generate mannequin image: {e}")
        return _get_placeholder_image_url(style, gender)


def _build_mannequin_prompt(
    items: List[Dict],
    weather: Dict,
    style: str,
    gender: str,
) -> str:
    """Build prompt for mannequin image generation"""

    # Gender-specific terms
    gender_term = "男性" if gender == "male" else "女性"

    # Style descriptions
    style_descriptions = {
        "casual": "カジュアルでリラックスした",
        "formal": "フォーマルで洗練された",
        "balanced": "バランスの取れた万能な",
        "unique": "トレンド感のある個性的な",
    }
    style_desc = style_descriptions.get(style, "ベーシックな")

    # Build item list
    item_descriptions = []
    for item in items:
        name = item.get("name", "")
        color = item.get("color", "")
        category = item.get("category", "")

        if name:
            item_descriptions.append(f"- {name}")
        elif color and category:
            item_descriptions.append(f"- {color}の{category}")

    items_text = "\n".join(item_descriptions) if item_descriptions else "ベーシックなコーディネート"

    # Temperature context
    temp = weather.get("temperature", 20)
    temp_context = ""
    if temp < 10:
        temp_context = f"（気温{temp}°C：防寒重視）"
    elif temp > 25:
        temp_context = f"（気温{temp}°C：涼しげ）"

    # Build full prompt
    prompt = f"""
ファッションコーディネート用の全身マネキン画像を生成してください。

【スタイル】{style_desc}{gender_term}向けコーディネート{temp_context}

【着用アイテム】
{items_text}

【要件】
- 白背景の全身マネキン（顔なし）
- シンプルで清潔感のあるビジュアル
- アイテムの色・形が明確にわかる
- ファッション通販サイトのような商品写真風
- 余白は最小限に
"""

    return prompt.strip()


def _get_placeholder_image_url(style: str, gender: str) -> str:
    """
    Get placeholder image URL based on style and gender.

    For production, these should be actual hosted images.
    For now, returning placeholder service URLs.
    """
    # Use placeholder service with custom colors based on style
    style_colors = {
        "casual": "3498db",  # Blue
        "formal": "2c3e50",  # Dark gray
        "balanced": "27ae60",  # Green
        "unique": "e74c3c",  # Red
    }

    color = style_colors.get(style, "95a5a6")

    # Gender icon
    gender_icon = "👔" if gender == "male" else "👗"

    # Placeholder image URL (800x1200 for mannequin aspect ratio)
    placeholder_url = f"https://via.placeholder.com/800x1200/{color}/ffffff?text={gender_icon}+{style.upper()}"

    return placeholder_url
