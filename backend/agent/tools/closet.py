"""Closet Tool - クローゼット内の服を検索・取得（Firestore版）"""
import logging
from typing import Optional
from pydantic import BaseModel

from firebase_admin import firestore
from agent.tools.temperature_estimator import add_temperature_ranges_to_items

logger = logging.getLogger(__name__)


class ClosetItem(BaseModel):
    """クローゼット内のアイテム"""
    id: str
    name: str
    category: str  # tops, bottoms, outerwear, shoes, accessories
    color: str
    season: list[str]  # spring, summer, autumn, winter
    formality: str  # casual, business_casual, formal
    image_url: Optional[str] = None
    tags: list[str] = []
    brand: Optional[str] = None
    usage_score: int = 0
    last_worn_at: Optional[str] = None
    created_at: Optional[str] = None


def _get_db():
    """Firestoreクライアントを取得"""
    import firebase_admin
    if not firebase_admin._apps:
        raise RuntimeError("Firebase Admin SDK is not initialized. Check your credentials.")
    return firestore.client()


async def get_closet_items(
    user_id: str = "demo_user",
    category: Optional[str] = None,
    season: Optional[str] = None,
    formality: Optional[str] = None,
) -> list[dict]:
    """
    ユーザーのクローゼットからアイテムを検索します。

    Args:
        user_id: ユーザーID
        category: カテゴリでフィルタ（tops, bottoms, outerwear, shoes, accessories）
        season: 季節でフィルタ（spring, summer, autumn, winter）
        formality: フォーマル度でフィルタ（casual, business_casual, formal）

    Returns:
        条件に合致するアイテムのリスト
    """
    db = _get_db()
    items_ref = db.collection("users").document(user_id).collection("closet_items")

    # Firestoreクエリ構築
    query = items_ref

    if category:
        query = query.where("category", "==", category)

    if formality:
        query = query.where("formality", "==", formality)

    # クエリ実行
    docs = query.stream()

    items = []
    for doc in docs:
        item_data = doc.to_dict()
        item_data["id"] = doc.id

        # seasonフィルタ（array-contains は1つしか使えないため、Pythonでフィルタ）
        if season and season not in item_data.get("season", []):
            continue

        # Ensure frontend-expected fields have defaults
        item_data.setdefault("brand", None)
        item_data.setdefault("usage_score", 0)
        item_data.setdefault("last_worn_at", None)
        item_data.setdefault("created_at", None)
        item_data.setdefault("material", None)

        items.append(item_data)

    # Enrich items with temperature ranges
    items = add_temperature_ranges_to_items(items)

    return items


async def get_all_categories(user_id: str = "demo_user") -> dict:
    """
    ユーザーのクローゼット内のカテゴリ別アイテム数を取得します。

    Returns:
        カテゴリ別のアイテム数
    """
    db = _get_db()
    items_ref = db.collection("users").document(user_id).collection("closet_items")

    docs = items_ref.stream()

    categories = {}
    for doc in docs:
        item_data = doc.to_dict()
        cat = item_data.get("category", "other")
        if cat not in categories:
            categories[cat] = 0
        categories[cat] += 1

    return categories


async def add_closet_item(user_id: str, item_data: dict) -> dict:
    """
    クローゼットにアイテムを追加します。

    Args:
        user_id: ユーザーID
        item_data: アイテムデータ

    Returns:
        追加されたアイテム（IDを含む）
    """
    db = _get_db()
    items_ref = db.collection("users").document(user_id).collection("closet_items")

    # Ensure required fields for frontend model alignment
    from datetime import datetime as _dt
    item_data.setdefault("created_at", _dt.utcnow().isoformat())
    item_data.setdefault("brand", None)
    item_data.setdefault("usage_score", 0)
    item_data.setdefault("last_worn_at", None)

    # Firestoreに保存
    _, doc_ref = items_ref.add(item_data)
    item_data["id"] = doc_ref.id

    return item_data


async def add_closet_items_bulk(user_id: str, items: list[dict]) -> list[dict]:
    """
    複数アイテムを一括でクローゼットに追加します。

    Args:
        user_id: ユーザーID
        items: アイテムデータのリスト

    Returns:
        追加されたアイテムのリスト
    """
    db = _get_db()
    batch = db.batch()
    items_ref = db.collection("users").document(user_id).collection("closet_items")

    from datetime import datetime as _dt

    registered = []
    for item_data in items:
        item_data.setdefault("created_at", _dt.utcnow().isoformat())
        item_data.setdefault("brand", None)
        item_data.setdefault("usage_score", 0)
        item_data.setdefault("last_worn_at", None)

        doc_ref = items_ref.document()
        batch.set(doc_ref, item_data)
        item_data["id"] = doc_ref.id
        registered.append(item_data)

    batch.commit()
    return registered


async def delete_closet_item(user_id: str, item_id: str) -> bool:
    """
    クローゼットからアイテムを削除します。

    Args:
        user_id: ユーザーID
        item_id: アイテムID

    Returns:
        削除に成功したかどうか
    """
    db = _get_db()
    doc_ref = db.collection("users").document(user_id).collection("closet_items").document(item_id)

    doc = doc_ref.get()
    if not doc.exists:
        return False

    doc_ref.delete()
    return True


async def save_outfit_history(user_id: str, history_data: dict) -> dict:
    """
    コーデ履歴を保存します。

    Args:
        user_id: ユーザーID
        history_data: 履歴データ

    Returns:
        保存された履歴（IDを含む）
    """
    db = _get_db()
    history_ref = db.collection("users").document(user_id).collection("outfit_history")

    # Use server timestamp for reliable Firestore sorting
    history_data["created_at"] = firestore.SERVER_TIMESTAMP

    _, doc_ref = history_ref.add(history_data)
    history_data["id"] = doc_ref.id
    # Replace SERVER_TIMESTAMP sentinel with ISO string for the response
    from datetime import datetime as _dt
    history_data["created_at"] = _dt.utcnow().isoformat()

    return history_data


async def get_outfit_history(user_id: str, limit: int = 30) -> list[dict]:
    """
    コーデ履歴を取得します。

    Args:
        user_id: ユーザーID
        limit: 取得件数

    Returns:
        履歴のリスト（新しい順）
    """
    db = _get_db()
    history_ref = db.collection("users").document(user_id).collection("outfit_history")

    query = history_ref.order_by("created_at", direction=firestore.Query.DESCENDING).limit(limit)
    docs = query.stream()

    from datetime import datetime as _dt

    history = []
    for doc in docs:
        data = doc.to_dict()
        data["id"] = doc.id
        # Convert Firestore timestamps to ISO strings for JSON serialization
        for key in ("created_at",):
            val = data.get(key)
            if val is not None and not isinstance(val, str):
                try:
                    data[key] = val.isoformat()
                except AttributeError:
                    data[key] = str(val)
        history.append(data)

    return history


# ADK Tools として公開
closet_tool = get_closet_items
