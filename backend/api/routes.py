"""API Routes - FastAPI エンドポイント定義"""
import logging
from datetime import date
from typing import Optional

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel, Field

from agent.tools.weather import weather_tool
from agent.tools.closet import (
    closet_tool, get_all_categories, add_closet_item, add_closet_items_bulk,
    delete_closet_item, save_outfit_history, get_outfit_history,
)
from agent.tools.calendar import calendar_tool
from agent.tools.style_advisor import style_advisor_tool
from agent.tools.outfit_analyzer import outfit_analyzer_tool
from agent.tools.product_search import product_search_tool
from agent.integration_helper import (
    generate_daily_outfits_with_cache,
    health_check as agent_health_check,
)
from agent.tools.recommendation_cache import TierLimitExceeded
from agent.tools.preference_learner import record_swipe

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


class OutfitHistorySave(BaseModel):
    """コーデ履歴保存リクエスト"""
    user_id: str = "demo_user"
    items: list[dict] = []
    weather: Optional[dict] = None
    tpo: Optional[dict] = None
    score: Optional[float] = None
    feedback: Optional[str] = None
    worn_date: Optional[str] = None


# ==================== ヘルスチェック ====================

@router.get("/health")
async def health_check():
    """ヘルスチェックエンドポイント"""
    return {"status": "healthy", "service": "poltan-api"}


# ==================== コーディネート提案 ====================

@router.post("/outfit/recommend")
async def recommend_outfit(
    request: OutfitRequest,
    authorization: Optional[str] = Header(default=None),
):
    """
    コーディネートを提案する（マルチエージェント版）

    **注意**: このエンドポイントはマルチエージェントシステムを使用するように更新されました。
    レガシークライアント互換性のため、レスポンス形式は維持されています。

    新しいクライアントは `/outfit/daily` を使用してください。

    1. 天気を取得
    2. カレンダーからTPOを判定
    3. マルチエージェントでコーデ生成
    4. 最適な組み合わせを評価・提案
    """
    # マルチエージェントシステムで生成
    try:
        result = await generate_daily_outfits_with_cache(
            user_id=request.user_id,
            latitude=request.latitude,
            longitude=request.longitude,
            force_regenerate=False,
            access_token=authorization[7:] if authorization and authorization.startswith("Bearer ") else None,
        )

        recommendations = result.get("recommendations", [])
        weather = result.get("weather", {})
        tpo = result.get("tpo", {})

        # レガシー形式に変換
        if recommendations:
            # トップ推奨を main recommendation として返す
            top_rec = recommendations[0]
            main_recommendation = {
                "items": top_rec.get("items", []),
                "score": top_rec.get("score", 0),
                "feedback": top_rec.get("reasoning", ""),
            }

            # 残りを alternatives として返す
            alternatives = []
            for alt in recommendations[1:3]:
                alternatives.append({
                    "items": alt.get("items", []),
                    "description": alt.get("reasoning", ""),
                })

            return {
                "weather": weather,
                "tpo": tpo,
                "recommendation": main_recommendation,
                "alternatives": alternatives,
                "evaluation_details": {
                    "total_score": top_rec.get("score", 0),
                    "feedback": top_rec.get("reasoning", ""),
                    "agent_type": top_rec.get("agent_type", "unknown"),
                    "source": top_rec.get("source", "closet"),
                },
                "_multi_agent": True,  # 新システムを使用していることを示すフラグ
            }
        else:
            # フォールバック: 空の推奨を返す
            return {
                "weather": weather,
                "tpo": tpo,
                "recommendation": {
                    "items": [],
                    "score": 0,
                    "feedback": "推奨が生成できませんでした。クローゼットにアイテムを追加してください。",
                },
                "alternatives": [],
                "evaluation_details": {},
            }

    except TierLimitExceeded as e:
        # Tier制限の場合でも、エラーではなく情報を返す
        logger.warning(f"Tier limit for legacy endpoint: {e}")
        raise HTTPException(
            status_code=429,
            detail={
                "message": "本日の推奨生成回数上限に達しました",
                "upgrade_required": True,
            }
        )
    except Exception as e:
        logger.error(f"Failed in legacy endpoint: {e}")
        # 旧ロジックにフォールバックせず、エラーを返す
        raise HTTPException(
            status_code=500,
            detail={"message": "推奨生成に失敗しました", "error": str(e)}
        )


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
async def add_closet_item_endpoint(item: ClosetItemCreate, user_id: str = "demo_user"):
    """クローゼットにアイテムを追加"""
    item_data = item.model_dump()
    saved_item = await add_closet_item(user_id=user_id, item_data=item_data)

    return {
        "message": "アイテムを追加しました",
        "item": saved_item,
    }


# ==================== 天気・カレンダー ====================

@router.get("/weather")
async def get_weather(latitude: float = 35.6762, longitude: float = 139.6503):
    """天気情報を取得"""
    weather = await weather_tool(latitude=latitude, longitude=longitude)
    return weather


@router.get("/calendar")
async def get_calendar(
    user_id: str = "demo_user",
    target_date: Optional[str] = None,
    authorization: Optional[str] = Header(default=None),
):
    """カレンダー情報とTPOを取得"""
    access_token = None
    if authorization and authorization.startswith("Bearer "):
        access_token = authorization[7:]

    calendar_data = await calendar_tool(
        user_id=user_id,
        target_date=target_date,
        access_token=access_token,
    )
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
    """クローゼットから改善提案に合うアイテムを検索"""
    suggestions = []

    for imp in improvements[:3]:
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
                matching_items.insert(0, item)
            else:
                matching_items.append(item)

        if matching_items:
            suggestions.append({
                "improvement_point": imp.get("point", ""),
                "category": category,
                "suggested_item": matching_items[0],
                "alternative_items": matching_items[1:3],
            })

    return suggestions


# ==================== 一括登録 ====================

@router.post("/closet/items/bulk")
async def add_closet_items_bulk_endpoint(request: BulkClosetItemsRequest):
    """
    複数のアイテムを一括でクローゼットに登録

    診断結果から検出されたアイテムを一度に登録する際に使用
    """
    if not request.items:
        raise HTTPException(status_code=400, detail="items is required")

    items_data = []
    for item in request.items:
        items_data.append({
            "name": item.name,
            "category": item.category,
            "color": item.color,
            "source": item.source,
            "source_diagnosis_id": item.source_diagnosis_id,
            "image_url": None,  # TODO: Firebase Storageにアップロード後のURLを設定
            "season": _estimate_season(item.category),
            "formality": _estimate_formality(item.name),
            "tags": [],
        })

    registered_items = await add_closet_items_bulk(
        user_id=request.user_id,
        items=items_data,
    )

    return {
        "message": f"{len(registered_items)}件のアイテムを登録しました",
        "registered_items": registered_items,
        "total_registered": len(registered_items),
    }


# ==================== コーデ履歴 ====================

@router.post("/outfit/history")
async def save_outfit_history_endpoint(request: OutfitHistorySave):
    """コーデ履歴を保存"""
    history_data = {
        "items": request.items,
        "weather": request.weather,
        "tpo": request.tpo,
        "score": request.score,
        "feedback": request.feedback,
        "worn_date": request.worn_date or date.today().isoformat(),
    }
    saved = await save_outfit_history(user_id=request.user_id, history_data=history_data)
    return {"message": "履歴を保存しました", "history": saved}


@router.get("/outfit/history")
async def get_outfit_history_endpoint(
    user_id: str = "demo_user",
    limit: int = 30,
):
    """コーデ履歴を取得"""
    history = await get_outfit_history(user_id=user_id, limit=limit)
    return {"history": history, "total_count": len(history)}


# ==================== クローゼットアイテム削除 ====================

@router.delete("/closet/items/{item_id}")
async def delete_closet_item_endpoint(item_id: str, user_id: str = "demo_user"):
    """クローゼットからアイテムを削除"""
    success = await delete_closet_item(user_id=user_id, item_id=item_id)
    if not success:
        raise HTTPException(status_code=404, detail="アイテムが見つかりません")
    return {"message": "アイテムを削除しました", "item_id": item_id}


def _estimate_season(category: str) -> list[str]:
    """カテゴリから季節を推定"""
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


# ==================== マルチエージェント推奨（NEW） ====================

@router.post("/outfit/daily")
async def get_daily_outfit_recommendations(
    request: OutfitRequest,
    force_regenerate: bool = False,
    authorization: Optional[str] = Header(default=None),
):
    """
    日次コーディネート推奨を取得（マルチエージェント方式）

    - 3つの推奨を返す（クローゼット2 + 外部商品1）
    - キャッシュを使用し、1日1回の生成制限あり
    - force_regenerate=True で強制再生成（制限回数消費）

    Args:
        request: OutfitRequest
        force_regenerate: 強制再生成フラグ
        authorization: Bearer token

    Returns:
        {
            "recommendations": List[dict],  # 3つの推奨
            "weather": dict,
            "tpo": dict,
            "generations_remaining": int,
            "can_regenerate": bool
        }

    Raises:
        HTTPException 429: Tier制限超過
    """
    # access_tokenを抽出
    access_token = None
    if authorization and authorization.startswith("Bearer "):
        access_token = authorization[7:]

    try:
        result = await generate_daily_outfits_with_cache(
            user_id=request.user_id,
            latitude=request.latitude,
            longitude=request.longitude,
            force_regenerate=force_regenerate,
            access_token=access_token,
        )

        logger.info(
            f"Daily outfits generated for user {request.user_id}, "
            f"{result['generations_remaining']} generations remaining"
        )

        return result

    except TierLimitExceeded as e:
        logger.warning(f"Tier limit exceeded for user {request.user_id}: {e}")
        raise HTTPException(
            status_code=429,
            detail={
                "message": str(e),
                "error_code": "TIER_LIMIT_EXCEEDED",
                "upgrade_required": True,
            }
        )
    except Exception as e:
        logger.error(f"Failed to generate daily outfits: {e}")
        raise HTTPException(
            status_code=500,
            detail={"message": "推奨生成に失敗しました", "error": str(e)}
        )


@router.post("/outfit/regenerate")
async def regenerate_daily_outfits(
    request: OutfitRequest,
    authorization: Optional[str] = Header(default=None),
):
    """
    日次コーディネート推奨を強制再生成

    - 世代カウントを消費して新しい推奨を生成
    - Tier制限をチェック

    Args:
        request: OutfitRequest
        authorization: Bearer token

    Returns:
        同じ形式で新しい推奨を返す

    Raises:
        HTTPException 429: Tier制限超過
    """
    return await get_daily_outfit_recommendations(
        request=request,
        force_regenerate=True,
        authorization=authorization,
    )


@router.post("/outfit/swipe")
async def record_outfit_swipe(
    outfit_id: str,
    action: str,  # "approve" or "reject"
    outfit_details: dict,
    user_id: str = "demo_user",
):
    """
    スワイプアクション（承認/拒否）を記録

    - ユーザー嗜好プロファイルを自動更新
    - swipe_historyに記録

    Args:
        outfit_id: Outfit ID
        action: "approve" または "reject"
        outfit_details: コーデ詳細（agent_type, items, score, source）
        user_id: User ID

    Returns:
        {"message": "記録しました", "action": action}
    """
    if action not in ["approve", "reject"]:
        raise HTTPException(
            status_code=400,
            detail={"message": "Invalid action. Must be 'approve' or 'reject'"}
        )

    try:
        await record_swipe(
            user_id=user_id,
            outfit_id=outfit_id,
            action=action,
            outfit_details=outfit_details,
        )

        logger.info(f"Recorded {action} swipe for user {user_id}, outfit {outfit_id}")

        return {
            "message": "スワイプを記録しました",
            "action": action,
            "outfit_id": outfit_id,
        }

    except Exception as e:
        logger.error(f"Failed to record swipe: {e}")
        raise HTTPException(
            status_code=500,
            detail={"message": "スワイプ記録に失敗しました", "error": str(e)}
        )


@router.get("/agent/health")
async def multi_agent_health_check():
    """
    マルチエージェントシステムのヘルスチェック

    Returns:
        {
            "status": "healthy" | "degraded" | "unhealthy",
            "agents": dict,
            "tools": dict
        }
    """
    try:
        health_status = await agent_health_check()
        return health_status
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {
            "status": "unhealthy",
            "error": str(e)
        }


@router.delete("/outfit/cache")
async def clear_recommendation_cache(
    user_id: str = "demo_user",
    date: Optional[str] = None,
):
    """
    日次推奨キャッシュをクリア（開発・テスト用）

    Args:
        user_id: User ID
        date: Date to clear (YYYY-MM-DD). Defaults to today.

    Returns:
        {"message": "Cache cleared", "date": str}
    """
    from datetime import datetime as _dt
    from firebase_admin import firestore

    target_date = date or _dt.now().date().isoformat()

    try:
        db = firestore.client()

        # Delete daily_recommendations cache
        cache_ref = db.collection("users").document(user_id).collection("daily_recommendations").document(target_date)
        cache_doc = cache_ref.get()

        if cache_doc.exists:
            cache_ref.delete()
            logger.info(f"Cleared cache for user {user_id} on {target_date}")

        # Reset tier usage counter for today
        if target_date == _dt.now().date().isoformat():
            tier_ref = db.collection("users").document(user_id).collection("tier_usage").document("current")
            tier_doc = tier_ref.get()

            if tier_doc.exists:
                tier_ref.update({
                    "today_date": target_date,
                    "today_generations": 0,
                })
                logger.info(f"Reset tier usage for user {user_id}")

        return {
            "message": "Cache cleared successfully",
            "user_id": user_id,
            "date": target_date,
            "cache_existed": cache_doc.exists,
        }

    except Exception as e:
        logger.error(f"Failed to clear cache: {e}")
        raise HTTPException(
            status_code=500,
            detail={"message": "キャッシュのクリアに失敗しました", "error": str(e)}
        )
