"""Closet Tool - クローゼット内の服を検索・取得"""
import logging
from typing import Optional
from pydantic import BaseModel

# MOCK: モックモード判定のインポート
from mock import is_mock_mode  # MOCK: インポート - 本番リリース前に削除必須

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


# MOCK: デモ用のモックデータ - 本番リリース前にFirestoreに移行必須
MOCK_CLOSET = [  # MOCK: モックデータ定義開始
    ClosetItem(
        id="1",
        name="ネイビージャケット",
        category="outerwear",
        color="navy",
        season=["spring", "autumn", "winter"],
        formality="formal",
        tags=["定番", "商談向け"]
    ),
    ClosetItem(
        id="2",
        name="白シャツ",
        category="tops",
        color="white",
        season=["spring", "summer", "autumn", "winter"],
        formality="formal",
        tags=["清潔感", "万能"]
    ),
    ClosetItem(
        id="3",
        name="グレースラックス",
        category="bottoms",
        color="gray",
        season=["spring", "autumn", "winter"],
        formality="formal",
        tags=["定番"]
    ),
    ClosetItem(
        id="4",
        name="黒革靴",
        category="shoes",
        color="black",
        season=["spring", "summer", "autumn", "winter"],
        formality="formal",
        tags=["ビジネス"]
    ),
    ClosetItem(
        id="5",
        name="ライトブルーシャツ",
        category="tops",
        color="light_blue",
        season=["spring", "summer"],
        formality="business_casual",
        tags=["爽やか"]
    ),
    ClosetItem(
        id="6",
        name="チノパン（ベージュ）",
        category="bottoms",
        color="beige",
        season=["spring", "summer", "autumn"],
        formality="business_casual",
        tags=["カジュアル"]
    ),
    ClosetItem(
        id="7",
        name="ネイビーポロシャツ",
        category="tops",
        color="navy",
        season=["summer"],
        formality="casual",
        tags=["夏向け"]
    ),
    ClosetItem(
        id="8",
        name="グレーカーディガン",
        category="outerwear",
        color="gray",
        season=["spring", "autumn"],
        formality="business_casual",
        tags=["オフィスカジュアル"]
    ),
    ClosetItem(
        id="9",
        name="白スニーカー",
        category="shoes",
        color="white",
        season=["spring", "summer", "autumn"],
        formality="casual",
        tags=["きれいめ"]
    ),
    ClosetItem(
        id="10",
        name="ダークグレースーツ上下",
        category="outerwear",
        color="dark_gray",
        season=["spring", "autumn", "winter"],
        formality="formal",
        tags=["フォーマル", "重要会議"]
    ),
]


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
    # MOCK: モックモードの場合はモックデータを使用
    if is_mock_mode():  # MOCK: モードチェック - 本番リリース前に削除必須
        logger.info("MOCK: Using mock closet data")  # MOCK: ログ
        items = MOCK_CLOSET  # MOCK: モックデータ使用

        if category:
            items = [item for item in items if item.category == category]

        if season:
            items = [item for item in items if season in item.season]

        if formality:
            items = [item for item in items if item.formality == formality]

        return [item.model_dump() for item in items]
    # MOCK: ここまでモック処理 - 以下は本番用コード

    # TODO: Firestoreから実際のデータを取得
    # 本番環境では以下のようにFirestoreからデータを取得する:
    # from google.cloud import firestore
    # db = firestore.Client()
    # items_ref = db.collection('users').document(user_id).collection('closet')
    # ...

    # 暫定的にモックデータを返す（本番リリース前に実装必須）
    items = MOCK_CLOSET  # MOCK: TODO - Firestoreに置き換え

    if category:
        items = [item for item in items if item.category == category]

    if season:
        items = [item for item in items if season in item.season]

    if formality:
        items = [item for item in items if item.formality == formality]

    return [item.model_dump() for item in items]


async def get_all_categories(user_id: str = "demo_user") -> dict:
    """
    ユーザーのクローゼット内のカテゴリ別アイテム数を取得します。

    Returns:
        カテゴリ別のアイテム数
    """
    # MOCK: モックモードの場合はモックデータを使用
    if is_mock_mode():  # MOCK: モードチェック - 本番リリース前に削除必須
        logger.info("MOCK: Using mock categories data")  # MOCK: ログ
        items = MOCK_CLOSET  # MOCK: モックデータ使用
        categories = {}
        for item in items:
            if item.category not in categories:
                categories[item.category] = 0
            categories[item.category] += 1
        return categories
    # MOCK: ここまでモック処理 - 以下は本番用コード

    # TODO: Firestoreから実際のデータを取得
    items = MOCK_CLOSET  # MOCK: TODO - Firestoreに置き換え
    categories = {}
    for item in items:
        if item.category not in categories:
            categories[item.category] = 0
        categories[item.category] += 1

    return categories


# ADK Tools として公開
closet_tool = get_closet_items
