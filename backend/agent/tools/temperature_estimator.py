"""Temperature Range Estimator - Estimate temperature range for clothing items"""
import logging
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)


# ==================== 温度範囲推定 ====================

def estimate_temperature_range(
    category: str,
    season: List[str],
    formality: str,
    material: Optional[str] = None,
) -> Dict[str, float]:
    """
    カテゴリと季節から適切な温度範囲を推定

    Args:
        category: Category (tops, bottoms, outerwear, shoes, accessories)
        season: List of seasons (spring, summer, autumn, winter, all_season)
        formality: Formality level (casual, business_casual, formal)
        material: Material type (optional)

    Returns:
        dict: {"min": float, "max": float} in Celsius
    """
    # ベース温度範囲（カテゴリ別）
    category_ranges = {
        "tops": {"min": 10, "max": 35},
        "bottoms": {"min": 5, "max": 40},
        "outerwear": {"min": -5, "max": 20},
        "shoes": {"min": 0, "max": 40},
        "accessories": {"min": -10, "max": 40},
    }

    base_range = category_ranges.get(category, {"min": 0, "max": 40})

    # 季節による調整
    season_adjustments = _get_season_adjustments(season)

    # マテリアルによる調整
    material_adjustments = _get_material_adjustments(material) if material else {"min": 0, "max": 0}

    # カテゴリ特有の調整
    category_adjustments = _get_category_adjustments(category, season)

    # 最終的な温度範囲を計算
    min_temp = (
        base_range["min"]
        + season_adjustments["min"]
        + material_adjustments["min"]
        + category_adjustments["min"]
    )

    max_temp = (
        base_range["max"]
        + season_adjustments["max"]
        + material_adjustments["max"]
        + category_adjustments["max"]
    )

    # 常識的な範囲にクランプ
    min_temp = max(-20, min(30, min_temp))
    max_temp = max(min_temp + 5, min(45, max_temp))

    return {"min": round(min_temp, 1), "max": round(max_temp, 1)}


def _get_season_adjustments(seasons: List[str]) -> Dict[str, float]:
    """季節による温度範囲調整"""
    if not seasons:
        return {"min": 0, "max": 0}

    # all_seasonがある場合は幅広い範囲
    if "all_season" in seasons:
        return {"min": -5, "max": 5}

    # 最も寒い季節と最も暑い季節を判定
    season_temps = {
        "winter": {"min": -10, "max": -5},
        "autumn": {"min": -5, "max": 0},
        "spring": {"min": 0, "max": 5},
        "summer": {"min": 5, "max": 10},
    }

    min_adjustment = min(season_temps.get(s, {"min": 0})["min"] for s in seasons)
    max_adjustment = max(season_temps.get(s, {"max": 0})["max"] for s in seasons)

    return {"min": min_adjustment, "max": max_adjustment}


def _get_material_adjustments(material: str) -> Dict[str, float]:
    """素材による温度範囲調整"""
    material_lower = material.lower() if material else ""

    # 暖かい素材
    if any(warm in material_lower for warm in ["wool", "ウール", "fleece", "フリース", "down", "ダウン"]):
        return {"min": -10, "max": -5}

    # 涼しい素材
    if any(cool in material_lower for cool in ["linen", "リネン", "麻", "cotton", "コットン"]):
        return {"min": 5, "max": 10}

    # ニュートラル
    return {"min": 0, "max": 0}


def _get_category_adjustments(category: str, seasons: List[str]) -> Dict[str, float]:
    """カテゴリ特有の調整"""
    adjustments = {"min": 0, "max": 0}

    # アウターは寒い時期専用
    if category == "outerwear":
        if "summer" not in seasons:
            adjustments["min"] = -5
            adjustments["max"] = -10

    # トップスは季節によって大きく変わる
    if category == "tops":
        if "winter" in seasons:
            adjustments["min"] = -5
            adjustments["max"] = -5
        elif "summer" in seasons:
            adjustments["min"] = 5
            adjustments["max"] = 5

    return adjustments


# ==================== バッチ処理 ====================

def add_temperature_ranges_to_items(items: List[Dict]) -> List[Dict]:
    """
    アイテムリストに温度範囲を追加

    Args:
        items: List of clothing items

    Returns:
        List[Dict]: Items with temperature_range added
    """
    enriched_items = []

    for item in items:
        # 既に temperature_range がある場合はスキップ
        if "temperature_range" in item:
            enriched_items.append(item)
            continue

        # 温度範囲を推定
        temp_range = estimate_temperature_range(
            category=item.get("category", "tops"),
            season=item.get("season", ["all_season"]),
            formality=item.get("formality", "casual"),
            material=item.get("material"),
        )

        # アイテムに追加
        enriched_item = item.copy()
        enriched_item["temperature_range"] = temp_range

        enriched_items.append(enriched_item)

    logger.info(f"Enriched {len(enriched_items)} items with temperature ranges")

    return enriched_items


# ==================== ユーティリティ ====================

def is_temperature_appropriate(item: Dict, temperature: float) -> bool:
    """
    アイテムが指定温度に適切かチェック

    Args:
        item: Clothing item with temperature_range
        temperature: Current temperature in Celsius

    Returns:
        bool: True if appropriate
    """
    temp_range = item.get("temperature_range")
    if not temp_range:
        # 温度範囲がない場合は推定
        temp_range = estimate_temperature_range(
            category=item.get("category", "tops"),
            season=item.get("season", ["all_season"]),
            formality=item.get("formality", "casual"),
            material=item.get("material"),
        )

    min_temp = temp_range.get("min", 0)
    max_temp = temp_range.get("max", 40)

    return min_temp <= temperature <= max_temp
