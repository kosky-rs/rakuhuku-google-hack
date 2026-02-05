"""API Routes - FastAPI エンドポイント定義"""
import logging
from datetime import date
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from agent.tools.weather import weather_tool
from agent.tools.closet import closet_tool, get_all_categories
from agent.tools.calendar import calendar_tool
from agent.tools.style_advisor import style_advisor_tool
from agent.tools.outfit_analyzer import outfit_analyzer_tool
from agent.tools.product_search import product_search_tool

logger = logging.getLogger(__name__)

router = APIRouter()


# ==================== リクエスト/レスポンスモデル ====================

class OutfitRequest(BaseModel):
    """コーディネート提案リクエスト"""
    user_id: str = "demo_user"
    target_date: Optional[str] = None
    latitude: float = 35.6762
    longitude: float = 139.6503


class ClosetItemCreate(BaseModel):
    """服アイテム登録リクエスト"""
    name: str
    category: str
    color: str
    season: list[str]
    formality: str
    image_url: Optional[str] = None
    tags: list[str] = []


class DiagnoseContext(BaseModel):
    """診断時のコンテキスト"""
    weather: Optional[str] = None
    temperature: Optional[float] = None
    event: Optional[str] = None
    date: Optional[str] = None


class DiagnoseRequest(BaseModel):
    """コーデ診断リクエスト"""
    image_base64: Optional[str] = Field(default=None, description="Base64エンコードされた画像")
    image_url: Optional[str] = Field(default=None, description="画像URL")
    context: DiagnoseContext = Field(default_factory=DiagnoseContext, description="コンテキスト情報")
    user_id: str = "demo_user"
    include_closet_suggestions: bool = Field(default=True, description="クローゼットからの提案を含めるか")


class BulkClosetItem(BaseModel):
    """一括登録用アイテム"""
    name: str
    category: str
    color: str
    image_base64: Optional[str] = None
    source: str = "diagnosis"  # diagnosis, manual
    source_diagnosis_id: Optional[str] = None


class BulkClosetItemsRequest(BaseModel):
    """一括登録リクエスト"""
    items: list[BulkClosetItem]
    user_id: str = "demo_user"


# ==================== ヘルスチェック ====================

@router.get("/health")
async def health_check():
    """ヘルスチェックエンドポイント"""
    return {"status": "healthy", "service": "poltan-api"}


# ==================== コーディネート提案 ====================

@router.post("/outfit/recommend")
async def recommend_outfit(request: OutfitRequest):
    """
    コーディネートを提案する

    1. 天気を取得
    2. カレンダーからTPOを判定
    3. クローゼットから服を取得
    4. 最適な組み合わせを評価・提案
    """
    # 天気取得
    weather = await weather_tool(
        latitude=request.latitude,
        longitude=request.longitude
    )

    # カレンダーからTPO取得
    calendar_data = await calendar_tool(
        user_id=request.user_id,
        target_date=request.target_date
    )
    tpo = calendar_data["tpo"]

    # クローゼットから服を取得
    formality = tpo["formality_required"]
    current_season = get_current_season()

    # 各カテゴリから適切な服を取得
    tops = await closet_tool(
        user_id=request.user_id,
        category="tops",
        formality=formality,
        season=current_season
    )
    bottoms = await closet_tool(
        user_id=request.user_id,
        category="bottoms",
        formality=formality,
        season=current_season
    )
    outerwear = await closet_tool(
        user_id=request.user_id,
        category="outerwear",
        season=current_season
    )
    shoes = await closet_tool(
        user_id=request.user_id,
        category="shoes",
        formality=formality
    )

    # 候補がない場合はフィルタを緩める
    if not tops:
        tops = await closet_tool(user_id=request.user_id, category="tops")
    if not bottoms:
        bottoms = await closet_tool(user_id=request.user_id, category="bottoms")
    if not shoes:
        shoes = await closet_tool(user_id=request.user_id, category="shoes")

    # 最適な組み合わせを選択（最初のアイテムを選択）
    selected_items = []
    if tops:
        selected_items.append(tops[0])
    if bottoms:
        selected_items.append(bottoms[0])
    if weather["temperature"] < 20 and outerwear:
        selected_items.append(outerwear[0])
    if shoes:
        selected_items.append(shoes[0])

    # コーディネートを評価
    evaluation = await style_advisor_tool(
        items=selected_items,
        weather=weather,
        tpo=tpo,
        current_season=current_season
    )

    # 代替案を生成
    alternatives = generate_alternatives(tops, bottoms, outerwear, shoes, weather, tpo)

    return {
        "weather": weather,
        "tpo": tpo,
        "recommendation": {
            "items": selected_items,
            "score": evaluation["total_score"],
            "feedback": evaluation["feedback"],
        },
        "alternatives": alternatives[:2],  # 最大2つ
        "evaluation_details": evaluation,
    }


def get_current_season() -> str:
    """現在の季節を取得"""
    month = date.today().month
    if month in [3, 4, 5]:
        return "spring"
    elif month in [6, 7, 8]:
        return "summer"
    elif month in [9, 10, 11]:
        return "autumn"
    else:
        return "winter"


def generate_alternatives(
    tops: list, bottoms: list, outerwear: list, shoes: list,
    weather: dict, tpo: dict
) -> list[dict]:
    """代替案を生成"""
    alternatives = []

    # 代替案1: 2番目のトップスを使用
    if len(tops) > 1:
        alt_items = []
        alt_items.append(tops[1])
        if bottoms:
            alt_items.append(bottoms[0])
        if shoes:
            alt_items.append(shoes[0])
        alternatives.append({
            "items": alt_items,
            "description": f"{tops[1]['name']}を使ったバリエーション"
        })

    # 代替案2: カジュアル寄りにする
    if len(bottoms) > 1:
        alt_items = []
        if tops:
            alt_items.append(tops[0])
        alt_items.append(bottoms[1])
        if shoes:
            alt_items.append(shoes[0])
        alternatives.append({
            "items": alt_items,
            "description": f"{bottoms[1]['name']}でカジュアルダウン"
        })

    return alternatives


# ==================== クローゼット管理 ====================

@router.get("/closet")
async def get_closet(user_id: str = "demo_user"):
    """クローゼットのアイテム一覧を取得"""
    items = await closet_tool(user_id=user_id)
    categories = await get_all_categories(user_id=user_id)

    return {
        "items": items,
        "categories": categories,
        "total_count": len(items),
    }


@router.get("/closet/categories")
async def get_closet_categories(user_id: str = "demo_user"):
    """カテゴリ別のアイテム数を取得"""
    categories = await get_all_categories(user_id=user_id)
    return {"categories": categories}


@router.post("/closet/items")
async def add_closet_item(item: ClosetItemCreate, user_id: str = "demo_user"):
    """クローゼットにアイテムを追加"""
    # TODO: Firestoreに保存
    return {
        "message": "アイテムを追加しました",
        "item": item.model_dump(),
    }


# ==================== 天気・カレンダー ====================

@router.get("/weather")
async def get_weather(latitude: float = 35.6762, longitude: float = 139.6503):
    """天気情報を取得"""
    weather = await weather_tool(latitude=latitude, longitude=longitude)
    return weather


@router.get("/calendar")
async def get_calendar(user_id: str = "demo_user", target_date: Optional[str] = None):
    """カレンダー情報とTPOを取得"""
    calendar_data = await calendar_tool(user_id=user_id, target_date=target_date)
    return calendar_data


# ==================== コーデ診断 ====================

@router.post("/outfit/diagnose")
async def diagnose_outfit(request: DiagnoseRequest):
    """
    全身写真からコーデを診断

    1. 画像を分析してスコア・改善点を取得
    2. 着用アイテムを検出・クロップ
    3. 改善提案に基づく商品を検索
    4. クローゼットから代替アイテムを提案（オプション）

    Returns:
        {
            "evaluation": { score, good_points, improvement_suggestions, ... },
            "detected_items": [ { category, name, color, cropped_image_base64, ... } ],
            "product_suggestions": [ { category, affiliate_links, ... } ],
            "closet_suggestions": [ { ... } ]  # クローゼットからの提案
        }
    """
    # 画像がない場合はエラー
    if not request.image_base64 and not request.image_url:
        raise HTTPException(status_code=400, detail="image_base64 or image_url is required")

    try:
        # 1. 画像分析（コーデ評価 + アイテム検出）
        context_dict = request.context.model_dump() if request.context else {}
        analysis_result = await outfit_analyzer_tool(
            image_base64=request.image_base64,
            image_url=request.image_url,
            context=context_dict
        )

        evaluation = analysis_result.get("evaluation", {})
        detected_items = analysis_result.get("detected_items", [])

        # 2. 改善提案から商品を検索
        improvement_suggestions = evaluation.get("improvement_suggestions", [])
        product_result = await product_search_tool(
            improvement_suggestions=improvement_suggestions,
            max_results=3
        )
        product_suggestions = product_result.get("suggestions", [])

        # 3. クローゼットからの代替提案（オプション）
        closet_suggestions = []
        if request.include_closet_suggestions:
            closet_suggestions = await _get_closet_suggestions(
                request.user_id,
                improvement_suggestions
            )

        return {
            "evaluation": evaluation,
            "detected_items": detected_items,
            "product_suggestions": product_suggestions,
            "closet_suggestions": closet_suggestions,
            "diagnosis_id": f"diag_{date.today().isoformat()}_{id(request) % 10000}",
        }

    except Exception as e:
        logger.error(f"Diagnosis error: {e}")
        raise HTTPException(status_code=500, detail=f"診断中にエラーが発生しました: {str(e)}")


async def _get_closet_suggestions(user_id: str, improvements: list[dict]) -> list[dict]:
    """
    クローゼットから改善提案に合うアイテムを検索

    Args:
        user_id: ユーザーID
        improvements: 改善提案リスト

    Returns:
        マッチするクローゼットアイテムのリスト
    """
    suggestions = []

    for imp in improvements[:3]:  # 最大3つ
        category = imp.get("category", "")
        suggested_color = imp.get("suggested_color", "")

        if not category or category == "general":
            continue

        # クローゼットから該当カテゴリのアイテムを検索
        closet_items = await closet_tool(user_id=user_id, category=category)

        # 色が近いアイテムを優先
        matching_items = []
        for item in closet_items:
            item_color = item.get("color", "").lower()
            if suggested_color and suggested_color.lower() in item_color:
                matching_items.insert(0, item)  # 色マッチは先頭に
            else:
                matching_items.append(item)

        if matching_items:
            suggestions.append({
                "improvement_point": imp.get("point", ""),
                "category": category,
                "suggested_item": matching_items[0],
                "alternative_items": matching_items[1:3],  # 最大2つの代替
            })

    return suggestions


# ==================== 一括登録 ====================

@router.post("/closet/items/bulk")
async def add_closet_items_bulk(request: BulkClosetItemsRequest):
    """
    複数のアイテムを一括でクローゼットに登録

    診断結果から検出されたアイテムを一度に登録する際に使用
    """
    if not request.items:
        raise HTTPException(status_code=400, detail="items is required")

    registered_items = []
    errors = []

    for i, item in enumerate(request.items):
        try:
            # TODO: Firestoreに保存
            # ここではモック実装
            registered_item = {
                "id": f"item_{date.today().isoformat()}_{i}",
                "name": item.name,
                "category": item.category,
                "color": item.color,
                "source": item.source,
                "source_diagnosis_id": item.source_diagnosis_id,
                "image_url": None,  # TODO: Cloud Storageにアップロード後のURL
                "season": _estimate_season(item.category),
                "formality": _estimate_formality(item.name),
                "tags": [],
            }
            registered_items.append(registered_item)

        except Exception as e:
            errors.append({
                "index": i,
                "item_name": item.name,
                "error": str(e)
            })

    return {
        "message": f"{len(registered_items)}件のアイテムを登録しました",
        "registered_items": registered_items,
        "errors": errors if errors else None,
        "total_registered": len(registered_items),
        "total_errors": len(errors),
    }


def _estimate_season(category: str) -> list[str]:
    """カテゴリから季節を推定"""
    # 簡易推定（実際はAIで判断）
    if category == "outerwear":
        return ["autumn", "winter"]
    elif category == "tops":
        return ["spring", "summer", "autumn"]
    else:
        return ["spring", "summer", "autumn", "winter"]


def _estimate_formality(name: str) -> str:
    """アイテム名からフォーマル度を推定"""
    name_lower = name.lower()
    if any(word in name_lower for word in ["スーツ", "ジャケット", "ドレス", "フォーマル"]):
        return "formal"
    elif any(word in name_lower for word in ["シャツ", "スラックス", "ブレザー"]):
        return "business_casual"
    else:
        return "casual"
