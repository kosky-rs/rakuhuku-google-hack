# MOCK: Cloud Vision API モック - 本番リリース前に削除必須
"""
Cloud Vision API Mock Module

本番環境では絶対に使用しないこと。
全てのモックコードは `# MOCK:` でマークされています。
"""
import random


# MOCK: 服飾関連のオブジェクトラベル
MOCK_CLOTHING_OBJECTS = [
    # MOCK: トップス系
    {"name": "Shirt", "category": "tops", "japanese_name": "シャツ"},
    {"name": "T-shirt", "category": "tops", "japanese_name": "Tシャツ"},
    {"name": "Blouse", "category": "tops", "japanese_name": "ブラウス"},
    # MOCK: ボトムス系
    {"name": "Pants", "category": "bottoms", "japanese_name": "パンツ"},
    {"name": "Jeans", "category": "bottoms", "japanese_name": "ジーンズ"},
    {"name": "Trousers", "category": "bottoms", "japanese_name": "スラックス"},
    # MOCK: アウター系
    {"name": "Jacket", "category": "outerwear", "japanese_name": "ジャケット"},
    {"name": "Coat", "category": "outerwear", "japanese_name": "コート"},
    # MOCK: シューズ系
    {"name": "Shoe", "category": "shoes", "japanese_name": "シューズ"},
    {"name": "Sneakers", "category": "shoes", "japanese_name": "スニーカー"},
    # MOCK: アクセサリー系
    {"name": "Watch", "category": "accessories", "japanese_name": "時計"},
    {"name": "Bag", "category": "accessories", "japanese_name": "バッグ"},
]


class MockBoundingPoly:
    # MOCK: バウンディングポリゴンモッククラス
    """Cloud Vision APIのbounding_polyをモック"""

    def __init__(self, x: float, y: float, width: float, height: float):
        # MOCK: 正規化座標を保持
        self.normalized_vertices = [
            MockVertex(x, y),
            MockVertex(x + width, y),
            MockVertex(x + width, y + height),
            MockVertex(x, y + height),
        ]


class MockVertex:
    # MOCK: 頂点モッククラス
    """Cloud Vision APIのvertexをモック"""

    def __init__(self, x: float, y: float):
        # MOCK: 座標を保持
        self.x = x
        self.y = y


class MockLocalizedObjectAnnotation:
    # MOCK: オブジェクトアノテーションモッククラス
    """Cloud Vision APIのlocalized_object_annotationをモック"""

    def __init__(self, name: str, score: float, bounding_poly: MockBoundingPoly):
        # MOCK: アノテーション情報を保持
        self.name = name
        self.score = score
        self.bounding_poly = bounding_poly


def mock_object_localization(image_base64: str) -> list[MockLocalizedObjectAnnotation]:
    # MOCK: オブジェクト検出モック関数
    """
    Cloud Vision APIのobject_localizationをモック

    Args:
        image_base64: Base64エンコードされた画像（実際には使用しない）

    Returns:
        list[MockLocalizedObjectAnnotation]: モックのアノテーション結果
    """
    # MOCK: 基本的な服装構成（トップス、ボトムス、シューズ）を返す
    annotations = []

    # MOCK: トップス
    top = random.choice([obj for obj in MOCK_CLOTHING_OBJECTS if obj["category"] == "tops"])
    annotations.append(MockLocalizedObjectAnnotation(
        name=top["name"],
        score=round(random.uniform(0.85, 0.98), 2),  # MOCK: ランダムスコア
        bounding_poly=MockBoundingPoly(
            x=0.25, y=0.15, width=0.5, height=0.35
        )
    ))

    # MOCK: ボトムス
    bottom = random.choice([obj for obj in MOCK_CLOTHING_OBJECTS if obj["category"] == "bottoms"])
    annotations.append(MockLocalizedObjectAnnotation(
        name=bottom["name"],
        score=round(random.uniform(0.85, 0.98), 2),  # MOCK: ランダムスコア
        bounding_poly=MockBoundingPoly(
            x=0.2, y=0.45, width=0.6, height=0.4
        )
    ))

    # MOCK: シューズ
    shoe = random.choice([obj for obj in MOCK_CLOTHING_OBJECTS if obj["category"] == "shoes"])
    annotations.append(MockLocalizedObjectAnnotation(
        name=shoe["name"],
        score=round(random.uniform(0.85, 0.98), 2),  # MOCK: ランダムスコア
        bounding_poly=MockBoundingPoly(
            x=0.25, y=0.85, width=0.5, height=0.12
        )
    ))

    # MOCK: アウター（ランダムに50%の確率で追加）
    if random.random() > 0.5:
        outer = random.choice([obj for obj in MOCK_CLOTHING_OBJECTS if obj["category"] == "outerwear"])
        annotations.append(MockLocalizedObjectAnnotation(
            name=outer["name"],
            score=round(random.uniform(0.80, 0.95), 2),  # MOCK: ランダムスコア
            bounding_poly=MockBoundingPoly(
                x=0.2, y=0.1, width=0.6, height=0.45
            )
        ))

    return annotations
