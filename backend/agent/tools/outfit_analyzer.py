"""Outfit Analyzer Tool - 全身写真の分析とアイテム検出"""
import base64
import io
import json
import logging
import os
from typing import Optional
from pydantic import BaseModel, Field
import httpx

# ロガー設定
logger = logging.getLogger(__name__)

# MOCK: モックモード判定のインポート
from mock import is_mock_mode  # MOCK: インポート - 本番リリース前に削除必須


# ==================== データモデル ====================

class BoundingBox(BaseModel):
    """アイテムのバウンディングボックス（正規化座標 0-1）"""
    x: float = Field(description="左上のX座標（0-1）")
    y: float = Field(description="左上のY座標（0-1）")
    width: float = Field(description="幅（0-1）")
    height: float = Field(description="高さ（0-1）")


class DetectedItem(BaseModel):
    """検出されたアイテム"""
    category: str = Field(description="カテゴリ（tops, bottoms, outerwear, shoes, accessories）")
    name: str = Field(description="アイテム名（例: ネイビージャケット）")
    color: str = Field(description="主要な色")
    confidence: float = Field(description="検出信頼度 0-1")
    bounding_box: BoundingBox = Field(description="バウンディングボックス")
    cropped_image_base64: Optional[str] = Field(default=None, description="クロップされた画像のBase64")


class ImprovementSuggestion(BaseModel):
    """改善提案"""
    point: str = Field(description="改善ポイントの説明")
    category: str = Field(description="改善対象のカテゴリ")
    suggested_color: Optional[str] = Field(default=None, description="提案される色")
    suggested_style: Optional[str] = Field(default=None, description="提案されるスタイル")


class OutfitEvaluation(BaseModel):
    """コーデ評価結果"""
    score: float = Field(description="総合スコア 0-10")
    good_points: list[str] = Field(description="良い点のリスト")
    improvement_suggestions: list[ImprovementSuggestion] = Field(description="改善提案（最大3つ）")
    overall_style: str = Field(description="全体のスタイル（カジュアル、ビジネスカジュアル等）")
    color_harmony: str = Field(description="色合わせの評価")


class OutfitAnalysisResult(BaseModel):
    """コーデ分析結果"""
    evaluation: OutfitEvaluation = Field(description="コーデ評価")
    detected_items: list[DetectedItem] = Field(description="検出されたアイテム")
    analysis_context: dict = Field(default_factory=dict, description="分析時のコンテキスト")


class OutfitAnalysisRequest(BaseModel):
    """コーデ分析リクエスト"""
    image_base64: Optional[str] = Field(default=None, description="Base64エンコードされた画像")
    image_url: Optional[str] = Field(default=None, description="画像URL")
    context: dict = Field(default_factory=dict, description="コンテキスト（日付、天気、イベント等）")


# ==================== Gemini Vision によるコーデ評価 ====================

async def evaluate_outfit_with_gemini(
    image_base64: str,
    context: dict = None
) -> OutfitEvaluation:
    """
    Gemini Vision APIを使用してコーデを評価

    Args:
        image_base64: Base64エンコードされた画像
        context: コンテキスト情報（天気、イベント等）

    Returns:
        OutfitEvaluation: 評価結果
    """
    # MOCK: モックモードの場合はモックデータを返す
    if is_mock_mode():  # MOCK: モードチェック - 本番リリース前に削除必須
        from mock.gemini_mock import mock_evaluate_outfit  # MOCK: モックインポート
        logger.info("MOCK: Using mock evaluation")  # MOCK: ログ
        mock_result = mock_evaluate_outfit(image_base64, context)  # MOCK: モック呼び出し
        # MOCK: モック結果をOutfitEvaluationに変換
        suggestions = []
        for s in mock_result.get("improvement_suggestions", []):
            suggestions.append(ImprovementSuggestion(
                point=s.get("point", ""),
                category=s.get("category", "general"),
                suggested_color=s.get("suggested_color"),
                suggested_style=s.get("suggested_style")
            ))
        return OutfitEvaluation(
            score=mock_result.get("score", 5.0),
            good_points=mock_result.get("good_points", []),
            improvement_suggestions=suggestions[:3],
            overall_style=mock_result.get("overall_style", "カジュアル"),
            color_harmony=mock_result.get("color_harmony", "")
        )
    # MOCK: ここまでモック処理 - 以下は本番用コード

    import google.generativeai as genai

    # API設定
    api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GOOGLE_API_KEY or GEMINI_API_KEY environment variable is required")

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.0-flash")

    # コンテキスト情報をプロンプトに組み込み
    context_str = ""
    if context:
        if context.get("weather"):
            context_str += f"天気: {context['weather']}\n"
        if context.get("temperature"):
            context_str += f"気温: {context['temperature']}°C\n"
        if context.get("event"):
            context_str += f"予定: {context['event']}\n"

    prompt = f"""
あなたはプロのファッションスタイリストです。
この全身コーディネート写真を分析して、以下の形式でJSON形式で評価してください。

{f"【今日の状況】{chr(10)}{context_str}" if context_str else ""}

必ず以下のJSON形式で回答してください。他の文章は不要です:

{{
    "score": 7.5,
    "good_points": [
        "色の組み合わせが良い",
        "シルエットがきれい"
    ],
    "improvement_suggestions": [
        {{
            "point": "靴をもう少しフォーマルなものに変えると全体が引き締まります",
            "category": "shoes",
            "suggested_color": "ブラック",
            "suggested_style": "レザーシューズ"
        }}
    ],
    "overall_style": "ビジネスカジュアル",
    "color_harmony": "ネイビーとホワイトの組み合わせで清潔感があります"
}}

評価のポイント:
- スコアは0-10で、7以上が良いコーデ
- good_pointsは最大3つ
- improvement_suggestionsは最大3つ
- 実用的で具体的なアドバイスを心がける
"""

    # 画像データを準備
    try:
        image_data = base64.b64decode(image_base64)
    except Exception as e:
        logger.error(f"Base64 decode error: {e}")
        return _get_default_evaluation()

    # Gemini APIを呼び出し
    try:
        response = model.generate_content([
            prompt,
            {"mime_type": "image/jpeg", "data": image_data}
        ])
    except Exception as e:
        logger.error(f"Gemini API error: {e}")
        return _get_default_evaluation()

    # レスポンスをパース
    try:
        response_text = response.text.strip()
    except Exception as e:
        logger.error(f"Failed to get response text: {e}")
        return _get_default_evaluation()

    # JSON部分を抽出
    if "```json" in response_text:
        response_text = response_text.split("```json")[1].split("```")[0].strip()
    elif "```" in response_text:
        response_text = response_text.split("```")[1].split("```")[0].strip()

    # JSONパース
    try:
        result_dict = json.loads(response_text)
    except json.JSONDecodeError as e:
        logger.error(f"JSON parse error: {e}, response: {response_text[:200]}")
        return _get_default_evaluation()

    # improvement_suggestionsをImprovementSuggestionオブジェクトに変換
    suggestions = []
    for s in result_dict.get("improvement_suggestions", []):
        suggestions.append(ImprovementSuggestion(
            point=s.get("point", ""),
            category=s.get("category", "general"),
            suggested_color=s.get("suggested_color"),
            suggested_style=s.get("suggested_style")
        ))

    return OutfitEvaluation(
        score=result_dict.get("score", 5.0),
        good_points=result_dict.get("good_points", []),
        improvement_suggestions=suggestions[:3],  # 最大3つ
        overall_style=result_dict.get("overall_style", "カジュアル"),
        color_harmony=result_dict.get("color_harmony", "")
    )


def _get_default_evaluation() -> OutfitEvaluation:
    """エラー時のデフォルト評価を返す"""
    return OutfitEvaluation(
        score=5.0,
        good_points=["分析中にエラーが発生しました"],
        improvement_suggestions=[],
        overall_style="不明",
        color_harmony="分析できませんでした"
    )


# ==================== Cloud Vision API によるアイテム検出 ====================

async def detect_items_with_cloud_vision(
    image_base64: str
) -> list[DetectedItem]:
    """
    Cloud Vision API Object Localizationでアイテムを検出

    Args:
        image_base64: Base64エンコードされた画像

    Returns:
        list[DetectedItem]: 検出されたアイテムのリスト
    """
    # MOCK: モックモードの場合はモックデータを返す
    if is_mock_mode():  # MOCK: モードチェック - 本番リリース前に削除必須
        from mock.vision_mock import mock_object_localization  # MOCK: モックインポート
        logger.info("MOCK: Using mock object localization")  # MOCK: ログ

        # MOCK: モック結果を本物のCloud Vision APIと同じ形式で処理
        mock_objects = mock_object_localization(image_base64)  # MOCK: モック呼び出し

        # MOCK: 服飾関連のオブジェクトマッピング（本番コードと同じ）
        clothing_labels = {
            "Shirt": ("tops", "シャツ"),
            "T-shirt": ("tops", "Tシャツ"),
            "Blouse": ("tops", "ブラウス"),
            "Pants": ("bottoms", "パンツ"),
            "Jeans": ("bottoms", "ジーンズ"),
            "Trousers": ("bottoms", "スラックス"),
            "Jacket": ("outerwear", "ジャケット"),
            "Coat": ("outerwear", "コート"),
            "Shoe": ("shoes", "シューズ"),
            "Sneakers": ("shoes", "スニーカー"),
        }

        detected_items = []
        for obj in mock_objects:
            label = obj.name
            if label in clothing_labels:
                category, japanese_name = clothing_labels[label]
                vertices = obj.bounding_poly.normalized_vertices
                if len(vertices) >= 4:
                    x_coords = [v.x for v in vertices]
                    y_coords = [v.y for v in vertices]
                    bbox = BoundingBox(
                        x=min(x_coords),
                        y=min(y_coords),
                        width=max(x_coords) - min(x_coords),
                        height=max(y_coords) - min(y_coords)
                    )
                    detected_items.append(DetectedItem(
                        category=category,
                        name=japanese_name,
                        color="",
                        confidence=obj.score,
                        bounding_box=bbox,
                        cropped_image_base64=None
                    ))
        return detected_items
    # MOCK: ここまでモック処理 - 以下は本番用コード

    from google.cloud import vision

    client = vision.ImageAnnotatorClient()

    # 画像データを準備
    image = vision.Image(content=base64.b64decode(image_base64))

    # Object Localization を実行
    response = client.object_localization(image=image)
    objects = response.localized_object_annotations

    # 服飾関連のオブジェクトをフィルタリング
    clothing_labels = {
        "Shirt": ("tops", "シャツ"),
        "T-shirt": ("tops", "Tシャツ"),
        "Dress shirt": ("tops", "ドレスシャツ"),
        "Blouse": ("tops", "ブラウス"),
        "Sweater": ("tops", "セーター"),
        "Polo shirt": ("tops", "ポロシャツ"),
        "Top": ("tops", "トップス"),
        "Pants": ("bottoms", "パンツ"),
        "Jeans": ("bottoms", "ジーンズ"),
        "Trousers": ("bottoms", "スラックス"),
        "Shorts": ("bottoms", "ショートパンツ"),
        "Skirt": ("bottoms", "スカート"),
        "Jacket": ("outerwear", "ジャケット"),
        "Coat": ("outerwear", "コート"),
        "Blazer": ("outerwear", "ブレザー"),
        "Cardigan": ("outerwear", "カーディガン"),
        "Hoodie": ("outerwear", "パーカー"),
        "Outerwear": ("outerwear", "アウター"),
        "Shoe": ("shoes", "シューズ"),
        "Sneakers": ("shoes", "スニーカー"),
        "Boot": ("shoes", "ブーツ"),
        "Footwear": ("shoes", "靴"),
        "Hat": ("accessories", "帽子"),
        "Watch": ("accessories", "時計"),
        "Bag": ("accessories", "バッグ"),
        "Belt": ("accessories", "ベルト"),
        "Glasses": ("accessories", "メガネ"),
        "Sunglasses": ("accessories", "サングラス"),
        "Tie": ("accessories", "ネクタイ"),
        "Scarf": ("accessories", "スカーフ"),
    }

    detected_items = []

    for obj in objects:
        label = obj.name
        if label in clothing_labels:
            category, japanese_name = clothing_labels[label]

            # バウンディングボックスを取得
            vertices = obj.bounding_poly.normalized_vertices
            if len(vertices) >= 4:
                x_coords = [v.x for v in vertices]
                y_coords = [v.y for v in vertices]

                bbox = BoundingBox(
                    x=min(x_coords),
                    y=min(y_coords),
                    width=max(x_coords) - min(x_coords),
                    height=max(y_coords) - min(y_coords)
                )

                detected_items.append(DetectedItem(
                    category=category,
                    name=japanese_name,
                    color="",  # 色は後で Gemini で分析
                    confidence=obj.score,
                    bounding_box=bbox,
                    cropped_image_base64=None
                ))

    return detected_items


# ==================== Gemini による詳細アイテム分析 ====================

async def analyze_item_details_with_gemini(
    image_base64: str,
    detected_items: list[DetectedItem]
) -> list[DetectedItem]:
    """
    Gemini Visionで各アイテムの詳細（色、素材感など）を分析

    Args:
        image_base64: Base64エンコードされた全身画像
        detected_items: 検出されたアイテムのリスト

    Returns:
        list[DetectedItem]: 詳細情報が追加されたアイテムリスト
    """
    # MOCK: モックモードの場合はモックデータを返す
    if is_mock_mode():  # MOCK: モードチェック - 本番リリース前に削除必須
        from mock.gemini_mock import mock_analyze_item_details  # MOCK: モックインポート
        logger.info("MOCK: Using mock item details analysis")  # MOCK: ログ
        # MOCK: detected_itemsをdict形式に変換してモック関数に渡す
        items_dict = [item.model_dump() for item in detected_items]
        mock_result = mock_analyze_item_details(image_base64, items_dict)  # MOCK: モック呼び出し
        # MOCK: モック結果を元のDetectedItemオブジェクトに反映
        for i, item_data in enumerate(mock_result):
            if i < len(detected_items):
                if "color" in item_data and item_data["color"]:
                    detected_items[i].color = item_data["color"]
        return detected_items
    # MOCK: ここまでモック処理 - 以下は本番用コード

    import google.generativeai as genai

    api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
    if not api_key:
        return detected_items

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.0-flash")

    # 検出アイテムの情報をまとめる
    items_info = []
    for i, item in enumerate(detected_items):
        items_info.append({
            "index": i,
            "category": item.category,
            "name": item.name
        })

    prompt = f"""
この全身写真から、以下の検出されたアイテムの詳細を分析してください。

検出されたアイテム:
{json.dumps(items_info, ensure_ascii=False, indent=2)}

各アイテムについて、以下のJSON形式で回答してください:

{{
    "items": [
        {{
            "index": 0,
            "name": "ネイビーテーラードジャケット",
            "color": "ネイビー",
            "material_feel": "コットン混"
        }}
    ]
}}

- nameは具体的な名前（色+アイテム名）
- colorは主要な色（日本語で）
- material_feelは素材感の推測
"""

    image_data = base64.b64decode(image_base64)

    try:
        response = model.generate_content([
            prompt,
            {"mime_type": "image/jpeg", "data": image_data}
        ])

        response_text = response.text.strip()
        if "```json" in response_text:
            response_text = response_text.split("```json")[1].split("```")[0].strip()
        elif "```" in response_text:
            response_text = response_text.split("```")[1].split("```")[0].strip()

        result = json.loads(response_text)

        for item_detail in result.get("items", []):
            idx = item_detail.get("index", -1)
            if 0 <= idx < len(detected_items):
                detected_items[idx].name = item_detail.get("name", detected_items[idx].name)
                detected_items[idx].color = item_detail.get("color", "")

    except Exception as e:
        logger.warning(f"Gemini item analysis error: {e}")

    return detected_items


# ==================== 画像クロップ処理 ====================

async def crop_detected_items(
    image_base64: str,
    detected_items: list[DetectedItem]
) -> list[DetectedItem]:
    """
    検出されたアイテムを画像からクロップ

    Args:
        image_base64: Base64エンコードされた画像
        detected_items: 検出されたアイテムのリスト

    Returns:
        list[DetectedItem]: クロップ画像が追加されたアイテムリスト
    """
    # MOCK: モックモードの場合はダミーのBase64を設定
    if is_mock_mode():  # MOCK: モードチェック - 本番リリース前に削除必須
        logger.info("MOCK: Skipping actual image cropping, using placeholder")  # MOCK: ログ
        # MOCK: 各アイテムにダミーのBase64を設定（1x1ピクセルの透明PNG）
        # MOCK: 実際の画像処理をスキップして処理時間を短縮
        dummy_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="  # MOCK: 1x1透明PNG
        for item in detected_items:
            item.cropped_image_base64 = dummy_base64  # MOCK: ダミー画像設定
        return detected_items
    # MOCK: ここまでモック処理 - 以下は本番用コード

    from PIL import Image

    # 画像を読み込み
    image_data = base64.b64decode(image_base64)
    image = Image.open(io.BytesIO(image_data))
    width, height = image.size

    for item in detected_items:
        bbox = item.bounding_box

        # 正規化座標をピクセル座標に変換
        left = int(bbox.x * width)
        top = int(bbox.y * height)
        right = int((bbox.x + bbox.width) * width)
        bottom = int((bbox.y + bbox.height) * height)

        # パディングを追加（5%）
        padding_x = int((right - left) * 0.05)
        padding_y = int((bottom - top) * 0.05)

        left = max(0, left - padding_x)
        top = max(0, top - padding_y)
        right = min(width, right + padding_x)
        bottom = min(height, bottom + padding_y)

        # クロップ
        cropped = image.crop((left, top, right, bottom))

        # Base64にエンコード
        buffer = io.BytesIO()
        cropped.save(buffer, format="JPEG", quality=85)
        item.cropped_image_base64 = base64.b64encode(buffer.getvalue()).decode()

    return detected_items


# ==================== メイン分析関数 ====================

async def analyze_outfit_photo(
    image_base64: str = None,
    image_url: str = None,
    context: dict = None,
) -> dict:
    """
    全身写真を分析してコーデ評価とアイテム検出を行う

    Args:
        image_base64: Base64エンコードされた画像（優先）
        image_url: 画像URL（image_base64がない場合に使用）
        context: コンテキスト情報（天気、イベント等）

    Returns:
        dict: 分析結果
        {
            "evaluation": OutfitEvaluation,
            "detected_items": list[DetectedItem],
            "analysis_context": dict
        }
    """
    # 画像URLからBase64を取得
    if not image_base64 and image_url:
        async with httpx.AsyncClient() as client:
            response = await client.get(image_url)
            response.raise_for_status()
            image_base64 = base64.b64encode(response.content).decode()

    if not image_base64:
        raise ValueError("image_base64 or image_url is required")

    context = context or {}

    # 1. Gemini Vision でコーデ評価
    evaluation = await evaluate_outfit_with_gemini(image_base64, context)

    # 2. Cloud Vision API でアイテム検出
    try:
        detected_items = await detect_items_with_cloud_vision(image_base64)
    except Exception as e:
        logger.warning(f"Cloud Vision API error: {e}")
        # フォールバック: Geminiでアイテムを推測
        detected_items = await fallback_detect_items_with_gemini(image_base64)

    # 3. Gemini で詳細分析（色など）
    if detected_items:
        detected_items = await analyze_item_details_with_gemini(image_base64, detected_items)

    # 4. 画像クロップ
    if detected_items:
        detected_items = await crop_detected_items(image_base64, detected_items)

    return OutfitAnalysisResult(
        evaluation=evaluation,
        detected_items=detected_items,
        analysis_context=context
    ).model_dump()


async def fallback_detect_items_with_gemini(image_base64: str) -> list[DetectedItem]:
    """
    Cloud Vision APIが使えない場合のフォールバック
    Gemini Visionでアイテムを検出
    """
    # MOCK: モックモードの場合はモックデータを返す
    if is_mock_mode():  # MOCK: モードチェック - 本番リリース前に削除必須
        from mock.gemini_mock import mock_detect_items  # MOCK: モックインポート
        logger.info("MOCK: Using mock fallback item detection")  # MOCK: ログ
        mock_result = mock_detect_items(image_base64)  # MOCK: モック呼び出し
        # MOCK: モック結果をDetectedItemオブジェクトに変換
        detected_items = []
        for item in mock_result:
            bbox = item.get("bounding_box", {})
            detected_items.append(DetectedItem(
                category=item.get("category", "tops"),
                name=item.get("name", "アイテム"),
                color=item.get("color", ""),
                confidence=item.get("confidence", 0.8),
                bounding_box=BoundingBox(
                    x=bbox.get("x", 0.0),
                    y=bbox.get("y", 0.0),
                    width=bbox.get("width", 0.3),
                    height=bbox.get("height", 0.3)
                )
            ))
        return detected_items
    # MOCK: ここまでモック処理 - 以下は本番用コード

    import google.generativeai as genai

    api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
    if not api_key:
        return []

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.0-flash")

    prompt = """
この全身写真に写っている服飾アイテムを検出してください。

以下のJSON形式で回答してください:

{
    "items": [
        {
            "category": "tops",
            "name": "白シャツ",
            "color": "ホワイト",
            "position": {
                "x": 0.3,
                "y": 0.2,
                "width": 0.4,
                "height": 0.3
            }
        }
    ]
}

カテゴリは: tops, bottoms, outerwear, shoes, accessories
位置は画像全体に対する正規化座標（0-1）で指定
"""

    image_data = base64.b64decode(image_base64)

    try:
        response = model.generate_content([
            prompt,
            {"mime_type": "image/jpeg", "data": image_data}
        ])

        response_text = response.text.strip()
        if "```json" in response_text:
            response_text = response_text.split("```json")[1].split("```")[0].strip()
        elif "```" in response_text:
            response_text = response_text.split("```")[1].split("```")[0].strip()

        result = json.loads(response_text)

        detected_items = []
        for item in result.get("items", []):
            pos = item.get("position", {})
            detected_items.append(DetectedItem(
                category=item.get("category", "tops"),
                name=item.get("name", "アイテム"),
                color=item.get("color", ""),
                confidence=0.8,  # Geminiの場合は固定
                bounding_box=BoundingBox(
                    x=pos.get("x", 0.0),
                    y=pos.get("y", 0.0),
                    width=pos.get("width", 0.3),
                    height=pos.get("height", 0.3)
                )
            ))

        return detected_items

    except Exception as e:
        logger.warning(f"Gemini fallback detection error: {e}")
        return []


# ADK Tool として公開
outfit_analyzer_tool = analyze_outfit_photo
