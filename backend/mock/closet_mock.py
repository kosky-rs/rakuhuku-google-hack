# MOCK: クローゼットデータ モック - 本番リリース前に削除必須
"""
Closet Data Mock Module

本番環境では絶対に使用しないこと。
全てのモックコードは `# MOCK:` でマークされています。
"""


# MOCK: クローゼットのモックデータ
MOCK_CLOSET_ITEMS = [
    # MOCK: トップス
    {
        "id": "mock_item_001",
        "name": "白シャツ",
        "category": "tops",
        "color": "ホワイト",
        "season": ["spring", "summer", "autumn"],
        "formality": "business_casual",
        "image_url": None,
        "tags": ["定番", "オフィス"]
    },
    {
        "id": "mock_item_002",
        "name": "ネイビーポロシャツ",
        "category": "tops",
        "color": "ネイビー",
        "season": ["spring", "summer"],
        "formality": "casual",
        "image_url": None,
        "tags": ["夏用", "カジュアル"]
    },
    {
        "id": "mock_item_003",
        "name": "グレーニット",
        "category": "tops",
        "color": "グレー",
        "season": ["autumn", "winter"],
        "formality": "casual",
        "image_url": None,
        "tags": ["秋冬", "暖かい"]
    },
    # MOCK: ボトムス
    {
        "id": "mock_item_004",
        "name": "ネイビーチノパン",
        "category": "bottoms",
        "color": "ネイビー",
        "season": ["spring", "summer", "autumn", "winter"],
        "formality": "business_casual",
        "image_url": None,
        "tags": ["定番", "万能"]
    },
    {
        "id": "mock_item_005",
        "name": "インディゴデニム",
        "category": "bottoms",
        "color": "インディゴ",
        "season": ["spring", "summer", "autumn", "winter"],
        "formality": "casual",
        "image_url": None,
        "tags": ["カジュアル", "定番"]
    },
    {
        "id": "mock_item_006",
        "name": "ベージュスラックス",
        "category": "bottoms",
        "color": "ベージュ",
        "season": ["spring", "summer", "autumn"],
        "formality": "business_casual",
        "image_url": None,
        "tags": ["オフィス", "きれいめ"]
    },
    # MOCK: アウター
    {
        "id": "mock_item_007",
        "name": "ネイビーテーラードジャケット",
        "category": "outerwear",
        "color": "ネイビー",
        "season": ["spring", "autumn"],
        "formality": "formal",
        "image_url": None,
        "tags": ["ビジネス", "定番"]
    },
    {
        "id": "mock_item_008",
        "name": "カーキブルゾン",
        "category": "outerwear",
        "color": "カーキ",
        "season": ["spring", "autumn"],
        "formality": "casual",
        "image_url": None,
        "tags": ["カジュアル", "アウトドア"]
    },
    # MOCK: シューズ
    {
        "id": "mock_item_009",
        "name": "ブラウンレザーローファー",
        "category": "shoes",
        "color": "ブラウン",
        "season": ["spring", "summer", "autumn", "winter"],
        "formality": "business_casual",
        "image_url": None,
        "tags": ["革靴", "きれいめ"]
    },
    {
        "id": "mock_item_010",
        "name": "ホワイトスニーカー",
        "category": "shoes",
        "color": "ホワイト",
        "season": ["spring", "summer", "autumn"],
        "formality": "casual",
        "image_url": None,
        "tags": ["スニーカー", "カジュアル"]
    },
    {
        "id": "mock_item_011",
        "name": "ブラックレザーシューズ",
        "category": "shoes",
        "color": "ブラック",
        "season": ["spring", "summer", "autumn", "winter"],
        "formality": "formal",
        "image_url": None,
        "tags": ["革靴", "フォーマル"]
    },
    # MOCK: アクセサリー
    {
        "id": "mock_item_012",
        "name": "シルバー腕時計",
        "category": "accessories",
        "color": "シルバー",
        "season": ["spring", "summer", "autumn", "winter"],
        "formality": "business_casual",
        "image_url": None,
        "tags": ["時計", "定番"]
    },
]


def mock_get_closet_items(
    user_id: str = "demo_user",
    category: str = None,
    formality: str = None,
    season: str = None,
) -> list[dict]:
    # MOCK: クローゼットアイテム取得モック関数
    """
    クローゼットアイテムのモックデータを返す

    Args:
        user_id: ユーザーID（実際には使用しない）
        category: カテゴリでフィルタ
        formality: フォーマル度でフィルタ
        season: 季節でフィルタ

    Returns:
        list[dict]: モックのクローゼットアイテム
    """
    # MOCK: フィルタリング
    items = MOCK_CLOSET_ITEMS.copy()

    if category:
        items = [item for item in items if item["category"] == category]

    if formality:
        # MOCK: フォーマル度でフィルタ（完全一致または緩めの条件）
        items = [item for item in items if item["formality"] == formality or
                 (formality == "business_casual" and item["formality"] in ["business_casual", "formal"])]

    if season:
        items = [item for item in items if season in item["season"]]

    return items


def mock_get_all_categories(user_id: str = "demo_user") -> dict:
    # MOCK: カテゴリ別アイテム数取得モック関数
    """
    カテゴリ別のアイテム数を返す

    Args:
        user_id: ユーザーID（実際には使用しない）

    Returns:
        dict: カテゴリ別アイテム数
    """
    # MOCK: カテゴリごとに集計
    categories = {}
    for item in MOCK_CLOSET_ITEMS:
        cat = item["category"]
        if cat not in categories:
            categories[cat] = {"count": 0, "items": []}
        categories[cat]["count"] += 1
        categories[cat]["items"].append(item["name"])

    return categories


def mock_add_closet_item(user_id: str, item: dict) -> dict:
    # MOCK: アイテム追加モック関数
    """
    アイテム追加のモック

    Args:
        user_id: ユーザーID
        item: 追加するアイテム

    Returns:
        dict: 追加されたアイテム（IDを付与）
    """
    # MOCK: 新しいIDを生成
    new_id = f"mock_item_{len(MOCK_CLOSET_ITEMS) + 1:03d}"
    new_item = {
        "id": new_id,
        **item
    }
    # MOCK: 実際には保存しない（メモリ上のみ）
    return new_item
