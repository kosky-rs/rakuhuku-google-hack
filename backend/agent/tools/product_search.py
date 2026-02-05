"""Product Search Tool - アフィリエイト商品検索"""
import logging
import urllib.parse
from typing import Optional
from pydantic import BaseModel, Field

# ロガー設定
logger = logging.getLogger(__name__)


# ==================== データモデル ====================

class AffiliateLink(BaseModel):
    """アフィリエイトリンク"""
    provider: str = Field(description="プロバイダー名（zozotown, rakuten, amazon）")
    url: str = Field(description="検索URL")
    display_name: str = Field(description="表示名")


class ProductSuggestion(BaseModel):
    """商品提案"""
    category: str = Field(description="カテゴリ（tops, bottoms, shoes等）")
    suggestion_reason: str = Field(description="提案理由")
    search_keywords: list[str] = Field(description="検索キーワード")
    suggested_color: Optional[str] = Field(default=None, description="提案される色")
    suggested_style: Optional[str] = Field(default=None, description="提案されるスタイル")
    affiliate_links: list[AffiliateLink] = Field(default_factory=list, description="アフィリエイトリンク")
    price_range: Optional[str] = Field(default=None, description="価格帯目安")


class ProductSearchResult(BaseModel):
    """商品検索結果"""
    suggestions: list[ProductSuggestion] = Field(description="商品提案リスト")
    total_count: int = Field(description="提案数")


# ==================== アフィリエイトリンク生成 ====================

def generate_zozotown_link(keywords: list[str], category: Optional[str] = None) -> AffiliateLink:
    """
    ZOZOTOWN検索リンクを生成

    Args:
        keywords: 検索キーワード
        category: カテゴリ

    Returns:
        AffiliateLink: ZOZOTOWNリンク
    """
    base_url = "https://zozo.jp/search/"
    query = " ".join(keywords)
    params = {"p_keyv": query}

    # カテゴリIDマッピング（ZOZOTOWN固有）
    category_ids = {
        "tops": "1",
        "bottoms": "2",
        "outerwear": "3",
        "shoes": "4",
        "accessories": "6",
    }

    if category and category in category_ids:
        params["p_gid"] = category_ids[category]

    url = base_url + "?" + urllib.parse.urlencode(params)

    return AffiliateLink(
        provider="zozotown",
        url=url,
        display_name="ZOZOTOWNで探す"
    )


def generate_rakuten_link(keywords: list[str], category: Optional[str] = None) -> AffiliateLink:
    """
    楽天市場検索リンクを生成

    Args:
        keywords: 検索キーワード
        category: カテゴリ

    Returns:
        AffiliateLink: 楽天リンク
    """
    base_url = "https://search.rakuten.co.jp/search/mall/"
    query = " ".join(keywords)
    encoded_query = urllib.parse.quote(query)

    # カテゴリIDマッピング（楽天ジャンル）
    genre_ids = {
        "tops": "100371",      # トップス
        "bottoms": "100372",   # ボトムス
        "outerwear": "100373", # アウター
        "shoes": "558929",     # シューズ
        "accessories": "216131", # アクセサリー
    }

    if category and category in genre_ids:
        url = f"{base_url}{encoded_query}/?g={genre_ids[category]}"
    else:
        url = f"{base_url}{encoded_query}/"

    return AffiliateLink(
        provider="rakuten",
        url=url,
        display_name="楽天市場で探す"
    )


def generate_amazon_link(keywords: list[str], category: Optional[str] = None) -> AffiliateLink:
    """
    Amazon検索リンクを生成

    Args:
        keywords: 検索キーワード
        category: カテゴリ

    Returns:
        AffiliateLink: Amazonリンク
    """
    base_url = "https://www.amazon.co.jp/s"
    query = " ".join(keywords)

    # カテゴリノードマッピング（Amazon）
    node_ids = {
        "tops": "352484011",      # トップス
        "bottoms": "352492011",   # ボトムス
        "outerwear": "352502011", # アウター
        "shoes": "2016926051",    # シューズ
        "accessories": "86731051", # アクセサリー
    }

    params = {"k": query}
    if category and category in node_ids:
        params["rh"] = f"n:{node_ids[category]}"

    url = base_url + "?" + urllib.parse.urlencode(params)

    return AffiliateLink(
        provider="amazon",
        url=url,
        display_name="Amazonで探す"
    )


def generate_all_affiliate_links(
    keywords: list[str],
    category: Optional[str] = None
) -> list[AffiliateLink]:
    """
    全プロバイダーのアフィリエイトリンクを生成

    Args:
        keywords: 検索キーワード
        category: カテゴリ

    Returns:
        list[AffiliateLink]: 全プロバイダーのリンク
    """
    return [
        generate_zozotown_link(keywords, category),
        generate_rakuten_link(keywords, category),
        generate_amazon_link(keywords, category),
    ]


# ==================== 商品検索メイン関数 ====================

async def search_affiliate_products(
    improvement_suggestions: list[dict] = None,
    category: Optional[str] = None,
    color: Optional[str] = None,
    style: Optional[str] = None,
    max_results: int = 5,
) -> dict:
    """
    アフィリエイト商品を検索

    Args:
        improvement_suggestions: OutfitAnalyzerからの改善提案リスト
        category: カテゴリでフィルタ
        color: 色でフィルタ
        style: スタイルでフィルタ
        max_results: 最大結果数

    Returns:
        dict: 商品検索結果
        {
            "suggestions": [ProductSuggestion, ...],
            "total_count": int
        }
    """
    suggestions = []

    # 改善提案から商品を生成
    if improvement_suggestions:
        for imp in improvement_suggestions[:max_results]:
            suggestion = _create_suggestion_from_improvement(imp)
            if suggestion:
                suggestions.append(suggestion)

    # 追加のフィルタ条件があれば直接検索
    if category and not suggestions:
        keywords = []
        if color:
            keywords.append(color)
        if style:
            keywords.append(style)
        keywords.append(_get_category_japanese(category))

        suggestion = ProductSuggestion(
            category=category,
            suggestion_reason="お探しの条件に合う商品",
            search_keywords=keywords,
            suggested_color=color,
            suggested_style=style,
            affiliate_links=generate_all_affiliate_links(keywords, category),
            price_range=None
        )
        suggestions.append(suggestion)

    return ProductSearchResult(
        suggestions=suggestions[:max_results],
        total_count=len(suggestions)
    ).model_dump()


def _create_suggestion_from_improvement(improvement: dict) -> Optional[ProductSuggestion]:
    """
    改善提案から商品提案を生成

    Args:
        improvement: 改善提案（ImprovementSuggestionのdict形式）

    Returns:
        ProductSuggestion or None
    """
    try:
        category = improvement.get("category", "general")
        point = improvement.get("point", "")
        suggested_color = improvement.get("suggested_color")
        suggested_style = improvement.get("suggested_style")

        # 検索キーワードを構築
        keywords = []
        if suggested_color:
            keywords.append(suggested_color)
        if suggested_style:
            keywords.append(suggested_style)

        # カテゴリの日本語名を追加
        category_japanese = _get_category_japanese(category)
        if category_japanese:
            keywords.append(category_japanese)

        # キーワードが空の場合はスキップ
        if not keywords:
            keywords = [category_japanese or "ファッション"]

        # 価格帯を推定
        price_range = _estimate_price_range(category, suggested_style)

        return ProductSuggestion(
            category=category,
            suggestion_reason=point,
            search_keywords=keywords,
            suggested_color=suggested_color,
            suggested_style=suggested_style,
            affiliate_links=generate_all_affiliate_links(keywords, category),
            price_range=price_range
        )

    except Exception as e:
        logger.warning(f"Failed to create suggestion: {e}")
        return None


def _get_category_japanese(category: str) -> str:
    """カテゴリの日本語名を取得"""
    category_map = {
        "tops": "トップス",
        "bottoms": "ボトムス",
        "outerwear": "アウター",
        "shoes": "シューズ",
        "accessories": "アクセサリー",
        "general": "ファッション",
    }
    return category_map.get(category, "ファッション")


def _estimate_price_range(category: str, style: Optional[str] = None) -> str:
    """カテゴリとスタイルから価格帯を推定"""
    base_ranges = {
        "tops": "3,000円〜15,000円",
        "bottoms": "5,000円〜20,000円",
        "outerwear": "10,000円〜50,000円",
        "shoes": "5,000円〜30,000円",
        "accessories": "2,000円〜10,000円",
    }

    # フォーマルなスタイルは高め
    if style and any(word in style.lower() for word in ["フォーマル", "ビジネス", "レザー", "スーツ"]):
        formal_ranges = {
            "tops": "8,000円〜30,000円",
            "bottoms": "10,000円〜40,000円",
            "outerwear": "20,000円〜100,000円",
            "shoes": "15,000円〜50,000円",
            "accessories": "5,000円〜30,000円",
        }
        return formal_ranges.get(category, base_ranges.get(category, "5,000円〜20,000円"))

    return base_ranges.get(category, "5,000円〜20,000円")


# ADK Tool として公開
product_search_tool = search_affiliate_products
