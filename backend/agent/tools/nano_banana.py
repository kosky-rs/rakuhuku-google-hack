"""
Imagen 4 Fast (Vertex AI) Image Generation Tool

Generates outfit mannequin images using Vertex AI's Imagen 4 Fast model.
Images are uploaded to Cloud Storage for efficient caching.
"""

import os
import logging
import io
import uuid
from datetime import datetime
from typing import Dict, List
from google.cloud import aiplatform
import vertexai
from vertexai.preview.vision_models import ImageGenerationModel
from firebase_admin import storage

logger = logging.getLogger(__name__)

# Configure Vertex AI (環境変数名・デフォルト値はmain.pyと統一)
PROJECT_ID = os.getenv("GCP_PROJECT_ID", "")
LOCATION = os.getenv("VERTEX_AI_LOCATION", "asia-northeast1")
ENABLE_NANO_BANANA = os.getenv("ENABLE_NANO_BANANA", "false").lower() == "true"

# Initialize Vertex AI
_VERTEX_AI_INITIALIZED = False

def _initialize_vertex_ai():
    """Initialize Vertex AI (skip if already initialized by main.py lifespan)"""
    global _VERTEX_AI_INITIALIZED
    if not _VERTEX_AI_INITIALIZED:
        try:
            vertexai.init(project=PROJECT_ID, location=LOCATION)
            logger.info(f"Vertex AI initialized: project={PROJECT_ID}, location={LOCATION}")
            _VERTEX_AI_INITIALIZED = True
        except Exception as e:
            logger.error(f"Failed to initialize Vertex AI: {e}")
            raise


def generate_outfit_mannequin_image(
    items: List[Dict],
    weather: Dict,
    style: str = "casual",
    gender: str = "male",
    reasoning: str = "",
    image_prompt_en: str = "",
) -> str:
    """
    Generate a full-body mannequin outfit image using Vertex AI Imagen 4 Fast.

    Args:
        items: List of clothing items with name, category, color
        weather: Weather context
        style: Style type (casual, formal, balanced, unique)
        gender: Gender (male, female)
        reasoning: Natural language outfit description from the style agent
        image_prompt_en: English outfit description from Gemini for accurate image generation

    Returns:
        str: Image URL (or placeholder if generation disabled)
    """
    # If image generation is disabled, return placeholder
    if not ENABLE_NANO_BANANA:
        logger.info("ENABLE_NANO_BANANA=false, using placeholder")
        return _get_placeholder_image_url(style, gender)

    try:
        # Initialize Vertex AI
        _initialize_vertex_ai()

        # Build prompt from outfit description and items
        prompt = _build_mannequin_prompt(items, weather, style, gender, reasoning, image_prompt_en)
        logger.info(f"🎨 Generating image with Imagen 4 Fast: {prompt[:100]}...")

        # Load Imagen 4 Fast model (latest, faster generation with better quota)
        model = ImageGenerationModel.from_pretrained("imagen-4.0-fast-generate-001")

        # Generate image
        images = model.generate_images(
            prompt=prompt,
            number_of_images=1,
            aspect_ratio="9:16",  # Vertical for mannequin
            safety_filter_level="block_some",
            person_generation="allow_adult",
        )

        if images and len(images.images) > 0:
            image = images.images[0]

            # Convert image to bytes
            image_bytes = io.BytesIO()
            image._pil_image.save(image_bytes, format='PNG')
            image_bytes.seek(0)

            # Upload to Cloud Storage
            try:
                bucket = storage.bucket()

                # Generate unique filename
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"mannequins/{style}_{gender}_{timestamp}_{uuid.uuid4().hex[:8]}.png"

                blob = bucket.blob(filename)
                blob.upload_from_file(image_bytes, content_type='image/png')

                # Make public and get URL
                blob.make_public()
                public_url = blob.public_url

                logger.info(f"✅ Image uploaded to Cloud Storage: {public_url}")
                return public_url

            except Exception as upload_error:
                logger.error(f"Failed to upload to Cloud Storage: {upload_error}")
                # Fallback to placeholder if upload fails
                return _get_placeholder_image_url(style, gender)

        logger.warning("⚠️ No image generated. Using placeholder.")
        return _get_placeholder_image_url(style, gender)

    except Exception as e:
        logger.error(f"❌ Failed to generate mannequin image with Imagen 4 Fast: {e}")
        return _get_placeholder_image_url(style, gender)


def _build_mannequin_prompt(
    items: List[Dict],
    weather: Dict,
    style: str,
    gender: str,
    reasoning: str = "",
    image_prompt_en: str = "",
) -> str:
    """Build English prompt for Imagen 4 Fast mannequin image generation.

    Uses the Gemini-generated English outfit description (image_prompt_en)
    for accurate item representation. Falls back to item-based construction
    if image_prompt_en is not available.
    """

    gender_term = "male" if gender == "male" else "female"

    style_descriptions = {
        "casual": "casual and relaxed",
        "formal": "formal and elegant",
        "balanced": "smart casual and versatile",
        "unique": "trendy and fashion-forward",
    }
    style_desc = style_descriptions.get(style, "stylish")

    # Temperature context for seasonal appropriateness
    temp = weather.get("temperature", 20)
    if temp < 10:
        season_hint = "winter"
    elif temp < 18:
        season_hint = "autumn"
    elif temp < 26:
        season_hint = "spring"
    else:
        season_hint = "summer"

    # Use Gemini's English description if available (preferred - avoids Japanese in prompt)
    if image_prompt_en:
        outfit_sentence = image_prompt_en
    else:
        # Fallback: build from items (may contain Japanese text)
        outfit_parts = []
        for item in items:
            name = item.get("name", "")
            color = item.get("color", "")
            category = item.get("category", "")

            if color and name:
                outfit_parts.append(f"{color} {name}")
            elif name:
                outfit_parts.append(name)
            elif color and category:
                outfit_parts.append(f"{color} {category}")

        if outfit_parts:
            outfit_sentence = ", ".join(outfit_parts[:-1])
            if len(outfit_parts) > 1:
                outfit_sentence += f", and {outfit_parts[-1]}"
            else:
                outfit_sentence = outfit_parts[0]
        else:
            outfit_sentence = f"a {style_desc} outfit"

    prompt = f"""A single {gender_term} fashion mannequin wearing a complete {style_desc} {season_hint} outfit: {outfit_sentence}. The mannequin is dressed head-to-toe in this coordinated look, standing in a natural upright pose.

Clean white studio background. Full-body view from head to shoes. Professional fashion e-commerce product photography. Photorealistic rendering. Studio lighting.

CRITICAL: Show exactly ONE mannequin only. All clothing items must be worn ON the mannequin body. Do NOT place any separate clothing items, flat-lay items, or accessory displays beside or around the mannequin. No split-screen. No collage. No item grid. Just one single dressed mannequin."""

    return prompt


def _get_placeholder_image_url(style: str, gender: str) -> str:
    """
    Return empty string as placeholder when image generation fails.
    Frontend handles empty/null mannequin_image_url with a built-in placeholder widget.
    """
    return ""
