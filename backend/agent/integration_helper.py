"""Integration Helper - Connect agents with existing tools and recommendation cache"""
import logging
from datetime import datetime
from typing import Dict, List, Optional

from agent.orchestrator import get_orchestrator
from agent.tools.recommendation_cache import (
    get_or_generate_daily_recommendations,
    TierLimitExceeded,
)
from agent.tools.preference_learner import get_preference_profile
from agent.tools.weather import weather_tool
from agent.tools.calendar import calendar_tool
from firebase_admin import firestore

logger = logging.getLogger(__name__)


# ==================== 統合関数 ====================


async def generate_daily_outfits_with_cache(
    user_id: str,
    latitude: float = 35.6762,
    longitude: float = 139.6503,
    force_regenerate: bool = False,
    access_token: Optional[str] = None,
) -> Dict:
    """
    Generate daily outfits using orchestrator and cache

    This is the main entry point that connects:
    - Weather API
    - Calendar API
    - User preference profile
    - Multi-agent orchestrator
    - Recommendation cache and tier limits

    Args:
        user_id: User ID
        latitude: Location latitude
        longitude: Location longitude
        force_regenerate: Force new generation (skip cache)
        access_token: Google Calendar access token

    Returns:
        dict: {
            "recommendations": List[dict],
            "weather": dict,
            "tpo": dict,
            "generations_remaining": int,
            "can_regenerate": bool
        }

    Raises:
        TierLimitExceeded: If daily generation limit exceeded
    """
    logger.info(f"Generating daily outfits for user {user_id}")

    # 1. Get weather
    try:
        weather = await weather_tool(latitude=latitude, longitude=longitude)
    except Exception as e:
        logger.error(f"Weather fetch failed: {e}")
        # Fallback to default weather
        weather = {
            "temperature": 20,
            "condition": "晴れ",
            "description": "天気データ取得失敗",
        }

    # 2. Get calendar events and TPO
    try:
        calendar_data = await calendar_tool(
            user_id=user_id,
            access_token=access_token,
            target_date=datetime.now().date().isoformat(),
        )
        tpo = calendar_data.get("tpo", {})
    except Exception as e:
        logger.error(f"Calendar fetch failed: {e}")
        # Fallback to default TPO
        tpo = {
            "formality_required": "casual",
            "summary": "カレンダー情報取得失敗",
        }

    # 3. Get user preferences
    try:
        user_preferences = await get_preference_profile(user_id)
    except Exception as e:
        logger.error(f"Preference fetch failed: {e}")
        # Fallback to default preferences
        user_preferences = {
            "style_scores": {
                "casual": 50,
                "formal": 50,
                "balanced": 50,
                "unique": 50,
            },
            "color_preferences": {},
            "category_preferences": {},
            "formality_distribution": {},
            "total_swipes": 0,
            "approve_rate": 0.0,
        }

    # 3.5. Fetch gender from user profile document
    try:
        db = firestore.client()
        user_doc = db.collection("users").document(user_id).get()
        if user_doc.exists:
            user_data = user_doc.to_dict()
            gender = user_data.get("gender", "male")
            user_preferences["gender"] = gender
            logger.info(f"User gender from profile: {gender}")
        else:
            user_preferences["gender"] = "male"
    except Exception as e:
        logger.error(f"User profile gender fetch failed: {e}")
        user_preferences["gender"] = "male"

    # 4. Generator function for orchestrator
    async def outfit_generator(uid, w, t, prefs):
        orchestrator = get_orchestrator()
        return await orchestrator.generate_daily_recommendations(uid, w, t, prefs)

    # 5. Get or generate with cache and tier limits
    try:
        result = await get_or_generate_daily_recommendations(
            user_id=user_id,
            weather=weather,
            tpo=tpo,
            user_preferences=user_preferences,
            force_regenerate=force_regenerate,
            generator_func=outfit_generator,
        )

        logger.info(
            f"Successfully generated {len(result['recommendations'])} recommendations, "
            f"{result['generations_remaining']} generations remaining"
        )

        return result

    except TierLimitExceeded as e:
        logger.warning(f"Tier limit exceeded for user {user_id}: {e}")
        raise


async def get_outfit_context(
    user_id: str,
    latitude: float = 35.6762,
    longitude: float = 139.6503,
    access_token: Optional[str] = None,
) -> Dict:
    """
    Get context for outfit generation without generating outfits

    Useful for preview or debugging

    Args:
        user_id: User ID
        latitude: Location latitude
        longitude: Location longitude
        access_token: Google Calendar access token

    Returns:
        dict: {
            "weather": dict,
            "tpo": dict,
            "user_preferences": dict
        }
    """
    weather = await weather_tool(latitude=latitude, longitude=longitude)

    calendar_data = await calendar_tool(
        user_id=user_id,
        access_token=access_token,
        target_date=datetime.now().date().isoformat(),
    )
    tpo = calendar_data.get("tpo", {})

    user_preferences = await get_preference_profile(user_id)

    return {
        "weather": weather,
        "tpo": tpo,
        "user_preferences": user_preferences,
    }


async def test_agent_generation(
    user_id: str,
    agent_type: str = "casual",
) -> Dict:
    """
    Test individual agent generation

    Args:
        user_id: User ID
        agent_type: Agent type (casual, formal, balanced, unique)

    Returns:
        dict: Agent's outfit recommendation
    """
    from agent.style_agents import (
        CasualStyleAgent,
        FormalStyleAgent,
        BalancedStyleAgent,
        UniqueStyleAgent,
    )

    agent_map = {
        "casual": CasualStyleAgent(),
        "formal": FormalStyleAgent(),
        "balanced": BalancedStyleAgent(),
        "unique": UniqueStyleAgent(),
    }

    if agent_type not in agent_map:
        raise ValueError(f"Invalid agent_type: {agent_type}")

    agent = agent_map[agent_type]

    # Mock context
    context = {
        "weather": {"temperature": 20, "condition": "晴れ"},
        "tpo": {"formality_required": "casual"},
        "user_preferences": {
            "style_scores": {"casual": 70, "formal": 50, "balanced": 60, "unique": 40},
            "gender": "male",
        },
    }

    outfit = await agent.generate_outfit(user_id, context)

    logger.info(f"Test agent {agent_type} generated outfit with score {outfit.get('score')}")

    return outfit


# ==================== ヘルスチェック ====================


async def health_check() -> Dict:
    """
    Health check for multi-agent system

    Returns:
        dict: {
            "status": "healthy" | "degraded" | "unhealthy",
            "agents": dict,
            "tools": dict
        }
    """
    status = {
        "status": "healthy",
        "agents": {},
        "tools": {},
    }

    # Check agents
    try:
        orchestrator = get_orchestrator()
        status["agents"]["orchestrator"] = "ok"
        status["agents"]["agent_count"] = len(orchestrator.agents)
    except Exception as e:
        status["agents"]["orchestrator"] = f"error: {e}"
        status["status"] = "unhealthy"

    # Check tools
    try:
        # Test weather tool
        await weather_tool(latitude=35.6762, longitude=139.6503)
        status["tools"]["weather"] = "ok"
    except Exception as e:
        status["tools"]["weather"] = f"error: {e}"
        status["status"] = "degraded"

    # Check Rakuten API
    try:
        from agent.tools.rakuten_api import RakutenAPIClient

        client = RakutenAPIClient()
        if client.application_id:
            status["tools"]["rakuten"] = "ok"
        else:
            status["tools"]["rakuten"] = "not_configured"
            status["status"] = "degraded"
    except Exception as e:
        status["tools"]["rakuten"] = f"error: {e}"
        status["status"] = "degraded"

    return status
