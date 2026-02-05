"""Style Advisor Tool - コーディネートの評価とスコアリング"""
from typing import Optional
from pydantic import BaseModel


class OutfitItem(BaseModel):
    """コーディネートのアイテム"""
    id: str
    name: str
    category: str
    color: str
    formality: str


class OutfitScore(BaseModel):
    """コーディネートのスコア"""
    total_score: int  # 0-100
    color_harmony: int  # 色の調和
    formality_match: int  # TPOとのマッチ
    season_match: int  # 季節との適合
    style_balance: int  # 全体のバランス
    feedback: str


# 色の相性マトリックス
COLOR_HARMONY = {
    ("navy", "white"): 95,
    ("navy", "gray"): 90,
    ("navy", "light_blue"): 85,
    ("navy", "beige"): 80,
    ("white", "gray"): 90,
    ("white", "black"): 95,
    ("white", "beige"): 85,
    ("gray", "black"): 90,
    ("gray", "white"): 90,
    ("dark_gray", "white"): 95,
    ("dark_gray", "light_blue"): 85,
    ("beige", "navy"): 80,
    ("beige", "white"): 85,
}


def calculate_color_harmony(colors: list[str]) -> int:
    """色の調和スコアを計算"""
    if len(colors) < 2:
        return 80

    total = 0
    pairs = 0
    for i, c1 in enumerate(colors):
        for c2 in colors[i+1:]:
            score = COLOR_HARMONY.get((c1, c2), 0) or COLOR_HARMONY.get((c2, c1), 70)
            total += score
            pairs += 1

    return total // pairs if pairs > 0 else 80


async def evaluate_outfit(
    items: list[dict],
    weather: dict,
    tpo: dict,
    current_season: str = "spring",
) -> dict:
    """
    コーディネートを評価してスコアとフィードバックを返します。

    Args:
        items: アイテムのリスト（各アイテムにはid, name, category, color, formalityが必要）
        weather: 天気情報
        tpo: TPO情報（formality_requiredを含む）
        current_season: 現在の季節

    Returns:
        評価結果
        {
            "total_score": 85,
            "color_harmony": 90,
            "formality_match": 85,
            "season_match": 80,
            "style_balance": 85,
            "feedback": "ネイビージャケットと白シャツの組み合わせは清潔感があり、商談に最適です。"
        }
    """
    colors = [item.get("color", "unknown") for item in items]
    formalities = [item.get("formality", "casual") for item in items]

    # 色の調和
    color_harmony = calculate_color_harmony(colors)

    # TPOマッチ
    required_formality = tpo.get("formality_required", "casual")
    formality_levels = {"casual": 1, "business_casual": 2, "formal": 3}
    required_level = formality_levels.get(required_formality, 2)

    outfit_formality_avg = sum(formality_levels.get(f, 2) for f in formalities) / len(formalities) if formalities else 2
    formality_diff = abs(required_level - outfit_formality_avg)
    formality_match = max(0, 100 - int(formality_diff * 30))

    # 季節マッチ（簡易版）
    temp = weather.get("temperature", 20)
    if 10 <= temp <= 25:
        season_match = 90  # 快適な気温
    elif 5 <= temp < 10 or 25 < temp <= 30:
        season_match = 75  # やや注意
    else:
        season_match = 60  # 要注意

    # スタイルバランス（アイテム数で判断）
    has_top = any(item.get("category") == "tops" for item in items)
    has_bottom = any(item.get("category") == "bottoms" for item in items)
    has_shoes = any(item.get("category") == "shoes" for item in items)

    style_balance = 70
    if has_top:
        style_balance += 10
    if has_bottom:
        style_balance += 10
    if has_shoes:
        style_balance += 10

    # 総合スコア
    total_score = (color_harmony + formality_match + season_match + style_balance) // 4

    # フィードバック生成
    item_names = [item.get("name", "アイテム") for item in items]
    main_event = tpo.get("main_event", "予定")

    if total_score >= 85:
        feedback = f"{item_names[0]}と{item_names[1] if len(item_names) > 1 else 'の組み合わせ'}は相性抜群。{main_event}にぴったりのスタイルです。"
    elif total_score >= 70:
        feedback = f"バランスの取れたコーディネートです。{main_event}に適しています。"
    else:
        feedback = f"もう少しTPOに合わせた調整をおすすめします。"

    return {
        "total_score": total_score,
        "color_harmony": color_harmony,
        "formality_match": formality_match,
        "season_match": season_match,
        "style_balance": style_balance,
        "feedback": feedback
    }


# ADK Tool として公開
style_advisor_tool = evaluate_outfit
