"""User Preference Learning from Swipe Data"""
import logging
from datetime import datetime
from typing import Dict, List, Optional

from firebase_admin import firestore

# ロガー設定
logger = logging.getLogger(__name__)

# 学習パラメータ
STYLE_SCORE_ALPHA = 0.1  # 指数移動平均の学習率
COLOR_PREFERENCE_DELTA = 5  # 色嗜好の増減幅
ITEM_PREFERENCE_DELTA = 1  # アイテム嗜好の増減幅


# ==================== スワイプ記録 ====================

async def record_swipe(
    user_id: str,
    outfit_id: str,
    action: str,  # "approve" | "reject"
    outfit_details: Dict,
) -> None:
    """
    Record a swipe action and update user preferences

    Args:
        user_id: User ID
        outfit_id: Outfit ID
        action: "approve" or "reject"
        outfit_details: Outfit details including:
            - agent_type: str
            - items: List[dict]
            - score: float
            - source: str
    """
    if action not in ["approve", "reject"]:
        raise ValueError(f"Invalid action: {action}. Must be 'approve' or 'reject'")

    db = firestore.client()

    # スワイプ履歴を保存
    swipe_ref = db.collection("users").document(user_id).collection("swipe_history")
    await swipe_ref.add({
        "outfit_id": outfit_id,
        "date": datetime.now().date().isoformat(),
        "action": action,
        "agent_type": outfit_details.get("agent_type"),
        "outfit_details": outfit_details,
        "timestamp": firestore.SERVER_TIMESTAMP,
    })

    logger.info(f"Recorded {action} swipe for user {user_id}, outfit {outfit_id}")

    # 嗜好プロファイルを更新
    await update_preference_profile(db, user_id, action, outfit_details)


# ==================== 嗜好プロファイル更新 ====================

async def update_preference_profile(
    db,
    user_id: str,
    action: str,
    outfit_details: Dict,
) -> None:
    """
    Update user preference profile based on swipe action

    Args:
        db: Firestore client
        user_id: User ID
        action: "approve" or "reject"
        outfit_details: Outfit details
    """
    profile_ref = db.collection("users").document(user_id).collection("preference_profile").document("current")

    profile_doc = profile_ref.get()

    if not profile_doc.exists:
        # 初期化
        profile = _initialize_preference_profile()
    else:
        profile = profile_doc.to_dict()

    # スタイルスコアを更新（指数移動平均）
    agent_type = outfit_details.get("agent_type")
    if agent_type and agent_type in profile["style_scores"]:
        current_score = profile["style_scores"][agent_type]
        reward = 100 if action == "approve" else 0
        new_score = current_score * (1 - STYLE_SCORE_ALPHA) + reward * STYLE_SCORE_ALPHA
        profile["style_scores"][agent_type] = round(new_score, 2)

    # 色嗜好を更新
    items = outfit_details.get("items", [])
    for item in items:
        color = item.get("color")
        if color:
            current_pref = profile["color_preferences"].get(color, 50)
            delta = COLOR_PREFERENCE_DELTA if action == "approve" else -COLOR_PREFERENCE_DELTA
            new_pref = max(0, min(100, current_pref + delta))
            profile["color_preferences"][color] = round(new_pref, 2)

    # カテゴリアイテム嗜好を更新（クローゼットアイテムのみ）
    source = outfit_details.get("source")
    if source == "closet":
        for item in items:
            category = item.get("category")
            item_id = item.get("id")
            if category and item_id:
                if category not in profile["category_preferences"]:
                    profile["category_preferences"][category] = {}

                current_pref = profile["category_preferences"][category].get(item_id, 0)
                delta = ITEM_PREFERENCE_DELTA if action == "approve" else -ITEM_PREFERENCE_DELTA
                profile["category_preferences"][category][item_id] = current_pref + delta

    # フォーマリティ分布を更新
    formality = _infer_formality_from_agent(agent_type)
    if formality:
        current_count = profile["formality_distribution"].get(formality, 0)
        delta = 1 if action == "approve" else 0
        profile["formality_distribution"][formality] = current_count + delta

    # 統計を更新
    profile["total_swipes"] += 1
    total_approves = profile.get("total_approves", 0) + (1 if action == "approve" else 0)
    profile["total_approves"] = total_approves
    profile["approve_rate"] = round(total_approves / profile["total_swipes"], 4)
    profile["last_updated"] = firestore.SERVER_TIMESTAMP

    # 保存
    profile_ref.set(profile)

    logger.info(f"Updated preference profile for user {user_id}")


def _initialize_preference_profile() -> Dict:
    """Initialize a new preference profile"""
    return {
        "style_scores": {
            "casual": 50.0,
            "formal": 50.0,
            "balanced": 50.0,
            "unique": 50.0,
        },
        "color_preferences": {},
        "category_preferences": {
            "tops": {},
            "bottoms": {},
            "outerwear": {},
            "shoes": {},
            "accessories": {},
        },
        "formality_distribution": {
            "casual": 0,
            "business_casual": 0,
            "formal": 0,
        },
        "total_swipes": 0,
        "total_approves": 0,
        "approve_rate": 0.0,
        "last_updated": firestore.SERVER_TIMESTAMP,
    }


def _infer_formality_from_agent(agent_type: str) -> Optional[str]:
    """Infer formality level from agent type"""
    formality_map = {
        "casual": "casual",
        "formal": "formal",
        "balanced": "business_casual",
        "unique": "casual",
    }
    return formality_map.get(agent_type)


# ==================== 嗜好プロファイル取得 ====================

async def get_preference_profile(user_id: str) -> Dict:
    """
    Get user's preference profile

    Args:
        user_id: User ID

    Returns:
        dict: Preference profile
    """
    db = firestore.client()
    profile_ref = db.collection("users").document(user_id).collection("preference_profile").document("current")

    profile_doc = profile_ref.get()

    if not profile_doc.exists:
        logger.info(f"No preference profile found for user {user_id}, initializing default")
        return _initialize_preference_profile()

    return profile_doc.to_dict()


# ==================== 嗜好分析 ====================

def analyze_preferences(profile: Dict) -> Dict:
    """
    Analyze user preferences and return insights

    Args:
        profile: Preference profile

    Returns:
        dict: Analysis results with:
            - preferred_styles: List of preferred agent types
            - preferred_colors: List of preferred colors
            - preferred_formality: Most preferred formality level
    """
    # スタイル嗜好（上位2つ）
    style_scores = profile.get("style_scores", {})
    sorted_styles = sorted(style_scores.items(), key=lambda x: x[1], reverse=True)
    preferred_styles = [style for style, score in sorted_styles[:2]]

    # 色嗜好（スコア60以上）
    color_prefs = profile.get("color_preferences", {})
    preferred_colors = [color for color, score in color_prefs.items() if score >= 60]

    # フォーマリティ嗜好（最多）
    formality_dist = profile.get("formality_distribution", {})
    if formality_dist:
        preferred_formality = max(formality_dist.items(), key=lambda x: x[1])[0]
    else:
        preferred_formality = "casual"

    return {
        "preferred_styles": preferred_styles,
        "preferred_colors": preferred_colors,
        "preferred_formality": preferred_formality,
        "total_swipes": profile.get("total_swipes", 0),
        "approve_rate": profile.get("approve_rate", 0.0),
    }
