# MOCK: Gemini Vision API モック - 本番リリース前に削除必須
"""
Gemini Vision API Mock Module

本番環境では絶対に使用しないこと。
全てのモックコードは `# MOCK:` でマークされています。
"""
import random
from typing import Optional


# MOCK: コーデ評価のモックレスポンス
MOCK_EVALUATION_TEMPLATES = [
    # MOCK: テンプレート1 - ビジネスカジュアル
    {
        "score": 7.5,
        "good_points": [
            "色の組み合わせがまとまっている",
            "シルエットがきれいで清潔感がある",
            "アイテムのサイズ感が良い"
        ],
        "improvement_suggestions": [
            {
                "point": "靴をレザーシューズに変えると、より洗練された印象になります",
                "category": "shoes",
                "suggested_color": "ブラック",
                "suggested_style": "レザーローファー"
            },
            {
                "point": "ベルトを追加すると全体が引き締まります",
                "category": "accessories",
                "suggested_color": "ブラウン",
                "suggested_style": "レザーベルト"
            }
        ],
        "overall_style": "ビジネスカジュアル",
        "color_harmony": "ネイビーとホワイトの組み合わせで清潔感があります"
    },
    # MOCK: テンプレート2 - カジュアル
    {
        "score": 6.8,
        "good_points": [
            "リラックス感のある着こなし",
            "季節に合った素材選び"
        ],
        "improvement_suggestions": [
            {
                "point": "トップスをもう少しフィット感のあるものに変えると、よりスタイリッシュになります",
                "category": "tops",
                "suggested_color": "ネイビー",
                "suggested_style": "スリムフィットシャツ"
            },
            {
                "point": "時計やブレスレットを追加するとアクセントになります",
                "category": "accessories",
                "suggested_color": "シルバー",
                "suggested_style": "腕時計"
            },
            {
                "point": "ボトムスをスラックスに変えると、きちんと感がアップします",
                "category": "bottoms",
                "suggested_color": "チャコール",
                "suggested_style": "テーパードパンツ"
            }
        ],
        "overall_style": "カジュアル",
        "color_harmony": "アースカラーでまとまっていますが、アクセントカラーが欲しいところ"
    },
    # MOCK: テンプレート3 - フォーマル
    {
        "score": 8.2,
        "good_points": [
            "フォーマルなシーンに適した装い",
            "色合わせが完璧",
            "サイズ感が素晴らしい"
        ],
        "improvement_suggestions": [
            {
                "point": "ポケットチーフを追加すると、さらにエレガントになります",
                "category": "accessories",
                "suggested_color": "ホワイト",
                "suggested_style": "シルクポケットチーフ"
            }
        ],
        "overall_style": "フォーマル",
        "color_harmony": "ダークトーンで統一され、品格があります"
    }
]

# MOCK: アイテム検出のモックレスポンス
MOCK_DETECTED_ITEMS = [
    # MOCK: トップス
    {
        "category": "tops",
        "name": "ライトブルーシャツ",
        "color": "ライトブルー",
        "position": {"x": 0.25, "y": 0.15, "width": 0.5, "height": 0.35}
    },
    # MOCK: ボトムス
    {
        "category": "bottoms",
        "name": "ネイビーチノパン",
        "color": "ネイビー",
        "position": {"x": 0.2, "y": 0.45, "width": 0.6, "height": 0.4}
    },
    # MOCK: シューズ
    {
        "category": "shoes",
        "name": "ブラウンローファー",
        "color": "ブラウン",
        "position": {"x": 0.25, "y": 0.85, "width": 0.5, "height": 0.12}
    }
]


def mock_evaluate_outfit(image_base64: str, context: Optional[dict] = None) -> dict:
    # MOCK: コーデ評価モック関数
    """
    コーデ評価のモックレスポンスを返す

    Args:
        image_base64: Base64エンコードされた画像（実際には使用しない）
        context: コンテキスト情報

    Returns:
        dict: モックの評価結果
    """
    # MOCK: ランダムにテンプレートを選択
    template = random.choice(MOCK_EVALUATION_TEMPLATES).copy()

    # MOCK: コンテキストに応じて若干スコアを変動
    if context:
        if context.get("event"):
            # MOCK: イベントがある場合は少しスコアを上げる
            template["score"] = min(10.0, template["score"] + 0.3)

    return template


def mock_detect_items(image_base64: str) -> list[dict]:
    # MOCK: アイテム検出モック関数
    """
    アイテム検出のモックレスポンスを返す

    Args:
        image_base64: Base64エンコードされた画像（実際には使用しない）

    Returns:
        list[dict]: モックの検出アイテム
    """
    # MOCK: 固定のモックアイテムを返す
    return [
        {
            "category": item["category"],
            "name": item["name"],
            "color": item["color"],
            "confidence": round(random.uniform(0.85, 0.98), 2),  # MOCK: ランダムな信頼度
            "bounding_box": {
                "x": item["position"]["x"],
                "y": item["position"]["y"],
                "width": item["position"]["width"],
                "height": item["position"]["height"]
            }
        }
        for item in MOCK_DETECTED_ITEMS
    ]


def mock_analyze_item_details(image_base64: str, detected_items: list[dict]) -> list[dict]:
    # MOCK: アイテム詳細分析モック関数
    """
    アイテム詳細分析のモックレスポンスを返す
    既に検出されたアイテムにそのまま詳細を付与

    Args:
        image_base64: Base64エンコードされた画像（実際には使用しない）
        detected_items: 検出されたアイテム

    Returns:
        list[dict]: 詳細が付与されたアイテム
    """
    # MOCK: 素材感をランダムに追加
    materials = ["コットン", "リネン", "ウール", "ポリエステル", "デニム", "レザー"]

    for item in detected_items:
        # MOCK: 素材情報を追加
        item["material_feel"] = random.choice(materials)

    return detected_items
