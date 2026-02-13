"""Daily Recommendation Caching and Tier Limit Management"""
import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

from firebase_admin import firestore

# ロガー設定
logger = logging.getLogger(__name__)

# Tier設定
FREE_TIER_DAILY_LIMIT = int(os.getenv("FREE_TIER_DAILY_LIMIT", "1"))
PREMIUM_TIER_DAILY_LIMIT = int(os.getenv("PREMIUM_TIER_DAILY_LIMIT", "999"))


# ==================== 例外クラス ====================

class TierLimitExceeded(Exception):
    """Tier制限超過エラー"""
    pass


# ==================== Tier管理 ====================

async def get_tier_usage(user_id: str, today: str) -> Dict:
    """
    Get user's tier usage information

    Args:
        user_id: User ID
        today: Today's date (ISO format: YYYY-MM-DD)

    Returns:
        dict: {
            "tier": "free" | "premium",
            "daily_limit": int,
            "today_generations": int,
            "reset_at": datetime
        }
    """
    db = firestore.client()
    tier_ref = db.collection("users").document(user_id).collection("tier_usage").document("current")

    tier_doc = tier_ref.get()

    if not tier_doc.exists:
        # 初期化: Free tierで作成
        tier_data = {
            "tier": "free",
            "daily_limit": FREE_TIER_DAILY_LIMIT,
            "today_date": today,
            "today_generations": 0,
            "reset_at": _get_next_midnight(),
        }
        tier_ref.set(tier_data)
        return tier_data

    tier_data = tier_doc.to_dict()

    # 日付が変わったらリセット
    if tier_data.get("today_date") != today:
        tier_data["today_date"] = today
        tier_data["today_generations"] = 0
        tier_data["reset_at"] = _get_next_midnight()
        tier_ref.update({
            "today_date": today,
            "today_generations": 0,
            "reset_at": tier_data["reset_at"],
        })

    return tier_data


async def increment_tier_usage(user_id: str, today: str) -> None:
    """
    Increment today's generation count

    Args:
        user_id: User ID
        today: Today's date (ISO format: YYYY-MM-DD)
    """
    db = firestore.client()
    tier_ref = db.collection("users").document(user_id).collection("tier_usage").document("current")

    tier_ref.update({
        "today_generations": firestore.Increment(1),
    })

    logger.info(f"Incremented tier usage for user {user_id}")


def _get_next_midnight() -> datetime:
    """Get next midnight timestamp (JST)"""
    jst = timezone(timedelta(hours=9))
    now = datetime.now(jst)
    next_midnight = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
    return next_midnight


# ==================== 推奨キャッシュ ====================

async def get_cached_recommendations(user_id: str, today: str) -> Optional[Dict]:
    """
    Get cached daily recommendations

    Args:
        user_id: User ID
        today: Today's date (ISO format: YYYY-MM-DD)

    Returns:
        Optional[dict]: Cached recommendations or None
    """
    db = firestore.client()
    rec_ref = db.collection("users").document(user_id).collection("daily_recommendations").document(today)

    rec_doc = rec_ref.get()

    if not rec_doc.exists:
        logger.info(f"No cached recommendations for user {user_id} on {today}")
        return None

    rec_data = rec_doc.to_dict()

    # 有効期限チェック
    expires_at = rec_data.get("expires_at")
    if expires_at and datetime.now(timezone.utc) > expires_at:
        logger.info(f"Cached recommendations expired for user {user_id}")
        return None

    logger.info(f"Found cached recommendations for user {user_id}")
    return rec_data


async def cache_recommendations(
    user_id: str,
    today: str,
    recommendations: List[Dict],
    weather: Dict,
    tpo: Dict,
    user_preferences: Dict,
) -> None:
    """
    Cache daily recommendations

    Args:
        user_id: User ID
        today: Today's date (ISO format: YYYY-MM-DD)
        recommendations: List of outfit recommendations
        weather: Weather context
        tpo: TPO context
        user_preferences: User preferences
    """
    db = firestore.client()
    rec_ref = db.collection("users").document(user_id).collection("daily_recommendations").document(today)

    # 翌日0時まで有効
    expires_at = _get_next_midnight()

    rec_data = {
        "date": today,
        "recommendations": recommendations,
        "context": {
            "weather": weather,
            "tpo": tpo,
            "user_preferences": user_preferences,
        },
        "generation_count": 1,
        "tier_limit_reached": False,
        "created_at": firestore.SERVER_TIMESTAMP,
        "expires_at": expires_at,
    }

    rec_ref.set(rec_data)
    logger.info(f"Cached recommendations for user {user_id} on {today}")


async def increment_generation_count(user_id: str, today: str) -> None:
    """
    Increment generation count in cached recommendations

    Args:
        user_id: User ID
        today: Today's date (ISO format: YYYY-MM-DD)
    """
    db = firestore.client()
    rec_ref = db.collection("users").document(user_id).collection("daily_recommendations").document(today)

    rec_ref.update({
        "generation_count": firestore.Increment(1),
    })


# ==================== メイン関数 ====================

async def get_or_generate_daily_recommendations(
    user_id: str,
    weather: Dict,
    tpo: Dict,
    user_preferences: Dict,
    force_regenerate: bool = False,
    generator_func = None,  # async function to generate recommendations
) -> Dict:
    """
    Get cached recommendations or generate new ones

    Args:
        user_id: User ID
        weather: Weather context
        tpo: TPO context
        user_preferences: User preferences
        force_regenerate: Force regeneration even if cached
        generator_func: Async function to generate recommendations
            Should have signature: async def generate(user_id, weather, tpo, prefs) -> List[dict]

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
    today = datetime.now().date().isoformat()

    # Tier使用状況チェック
    tier_usage = await get_tier_usage(user_id, today)

    # キャッシュチェック（force_regenerateでない場合）
    if not force_regenerate:
        cached = await get_cached_recommendations(user_id, today)
        if cached:
            # generations_remaining = tier_usage["daily_limit"] - tier_usage["today_generations"]
            return {
                "date": today,
                "recommendations": cached["recommendations"],
                "weather": cached["context"]["weather"],
                "tpo": cached["context"]["tpo"],
                "generations_remaining": 999,  # 無制限
                "can_regenerate": True,  # 常に再生成可能
            }

    # Tier制限チェック（一時的に無効化）
    # if tier_usage["today_generations"] >= tier_usage["daily_limit"]:
    #     logger.warning(f"Tier limit exceeded for user {user_id}")
    #     raise TierLimitExceeded(
    #         f"Daily generation limit reached ({tier_usage['daily_limit']} generations per day)"
    #     )

    # 新規生成
    if generator_func is None:
        raise ValueError("generator_func is required for generating recommendations")

    logger.info(f"Generating new recommendations for user {user_id}")
    recommendations = await generator_func(user_id, weather, tpo, user_preferences)

    # キャッシュ保存（常に更新）
    await cache_recommendations(
        user_id, today, recommendations, weather, tpo, user_preferences
    )

    # 再生成の場合はgeneration_countをインクリメント
    if force_regenerate:
        await increment_generation_count(user_id, today)

    # Tier使用カウント増加
    await increment_tier_usage(user_id, today)

    # 残り生成回数計算（制限なし設定）
    tier_usage = await get_tier_usage(user_id, today)
    # generations_remaining = tier_usage["daily_limit"] - tier_usage["today_generations"]

    return {
        "date": today,
        "recommendations": recommendations,
        "weather": weather,
        "tpo": tpo,
        "generations_remaining": 999,  # 無制限
        "can_regenerate": True,  # 常に再生成可能
    }
