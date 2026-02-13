"""Rakuten Ichiba API Integration for Product Search"""
import logging
import os
from typing import Dict, List, Optional

import httpx
from pydantic import BaseModel, Field

# ロガー設定
logger = logging.getLogger(__name__)

# 楽天API設定
RAKUTEN_APP_ID = os.getenv("RAKUTEN_APPLICATION_ID")
RAKUTEN_AFFILIATE_ID = os.getenv("RAKUTEN_AFFILIATE_ID")
RAKUTEN_API_BASE = "https://app.rakuten.co.jp/services/api"

# ジャンルIDマッピング
RAKUTEN_GENRES = {
    # メンズファッション
    "mens_tops": "100371",
    "mens_bottoms": "100372",
    "mens_outerwear": "100373",
    "mens_shoes": "558929",
    "mens_accessories": "216131",
    # レディースファッション
    "womens_tops": "110371",
    "womens_bottoms": "110372",
    "womens_outerwear": "110373",
    "womens_shoes": "559887",
    "womens_accessories": "216132",
}


# ==================== データモデル ====================

class RakutenProduct(BaseModel):
    """楽天商品モデル"""
    id: str = Field(description="商品ID")
    name: str = Field(description="商品名")
    price: int = Field(description="価格")
    image_url: str = Field(description="画像URL")
    shop_name: str = Field(description="ショップ名")
    product_url: str = Field(description="商品URL")
    review_average: Optional[float] = Field(default=None, description="レビュー平均")
    review_count: Optional[int] = Field(default=None, description="レビュー件数")
    genre_id: Optional[str] = Field(default=None, description="ジャンルID")
    source: str = Field(default="rakuten", description="ソース")


# ==================== 楽天APIクライアント ====================

class RakutenAPIClient:
    """Rakuten Ichiba Item Search API v20220601"""

    def __init__(self, application_id: Optional[str] = None):
        """
        Initialize Rakuten API Client

        Args:
            application_id: Rakuten Application ID (defaults to env var)
        """
        self.application_id = application_id or RAKUTEN_APP_ID
        if not self.application_id:
            logger.warning("RAKUTEN_APPLICATION_ID not set. API calls will fail.")

    async def search_fashion_items(
        self,
        keyword: str,
        genre_id: Optional[str] = None,
        min_price: Optional[int] = None,
        max_price: Optional[int] = None,
        sort: str = "-reviewCount",
        hits: int = 10,
    ) -> List[RakutenProduct]:
        """
        Search fashion items on Rakuten Ichiba

        Args:
            keyword: Search keyword
            genre_id: Genre ID for filtering
            min_price: Minimum price
            max_price: Maximum price
            sort: Sort order (-reviewCount: popular, +itemPrice: price ascending)
            hits: Number of results (max 30)

        Returns:
            List[RakutenProduct]: List of products

        API Reference:
            https://webservice.rakuten.co.jp/documentation/ichiba-item-search
        """
        if not self.application_id:
            logger.error("Cannot search: RAKUTEN_APPLICATION_ID not configured")
            return []

        endpoint = f"{RAKUTEN_API_BASE}/IchibaItem/Search/20220601"

        params = {
            "applicationId": self.application_id,
            "keyword": keyword,
            "formatVersion": 2,
            "hits": min(hits, 30),
            "sort": sort,
        }

        if genre_id:
            params["genreId"] = genre_id
        if min_price:
            params["minPrice"] = min_price
        if max_price:
            params["maxPrice"] = max_price

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(endpoint, params=params)
                response.raise_for_status()
                data = response.json()

            products = self._parse_items(data)
            logger.info(f"Rakuten API: Found {len(products)} products for keyword '{keyword}'")
            return products

        except httpx.HTTPStatusError as e:
            logger.error(f"Rakuten API HTTP error: {e.response.status_code} - {e.response.text}")
            return []
        except httpx.RequestError as e:
            logger.error(f"Rakuten API request error: {e}")
            return []
        except Exception as e:
            logger.error(f"Rakuten API unexpected error: {e}")
            return []

    def _parse_items(self, response_data: dict) -> List[RakutenProduct]:
        """
        Parse Rakuten API response into RakutenProduct models

        Args:
            response_data: Raw API response

        Returns:
            List[RakutenProduct]: Parsed products
        """
        products = []

        for item_data in response_data.get("Items", []):
            try:
                item = item_data.get("Item", {})

                # 画像URLを取得（mediumImageUrls優先、なければsmallImageUrls）
                image_urls = item.get("mediumImageUrls", item.get("smallImageUrls", []))
                image_url = image_urls[0].get("imageUrl") if image_urls else ""

                product = RakutenProduct(
                    id=f"rakuten_{item.get('itemCode', '')}",
                    name=item.get("itemName", ""),
                    price=item.get("itemPrice", 0),
                    image_url=image_url,
                    shop_name=item.get("shopName", ""),
                    product_url=item.get("itemUrl", ""),
                    review_average=item.get("reviewAverage"),
                    review_count=item.get("reviewCount"),
                    genre_id=item.get("genreId"),
                    source="rakuten",
                )

                products.append(product)

            except Exception as e:
                logger.warning(f"Failed to parse Rakuten item: {e}")
                continue

        return products


# ==================== ヘルパー関数 ====================

def get_genre_id(category: str, gender: str = "male") -> Optional[str]:
    """
    Get Rakuten genre ID from category and gender

    Args:
        category: Category (tops, bottoms, outerwear, shoes, accessories)
        gender: Gender (male, female)

    Returns:
        Optional[str]: Genre ID or None
    """
    prefix = "mens" if gender.lower() in ["male", "men", "mens"] else "womens"
    genre_key = f"{prefix}_{category}"
    return RAKUTEN_GENRES.get(genre_key)


async def search_rakuten_products(
    category: str,
    color: Optional[str] = None,
    style: Optional[str] = None,
    gender: str = "male",
    max_results: int = 5,
) -> List[Dict]:
    """
    Search Rakuten products by category, color, and style

    Args:
        category: Category (tops, bottoms, outerwear, shoes, accessories)
        color: Color filter
        style: Style filter
        gender: Gender (male, female)
        max_results: Maximum number of results

    Returns:
        List[Dict]: List of product dictionaries
    """
    client = RakutenAPIClient()

    # Build search keyword
    keywords = []
    if color:
        keywords.append(color)
    if style:
        keywords.append(style)

    # Add category Japanese name
    category_japanese = _get_category_japanese(category)
    keywords.append(category_japanese)

    keyword_str = " ".join(keywords)

    # Get genre ID
    genre_id = get_genre_id(category, gender)

    # Search products
    products = await client.search_fashion_items(
        keyword=keyword_str,
        genre_id=genre_id,
        hits=max_results,
    )

    # Convert to dict for compatibility
    return [product.model_dump() for product in products]


def _get_category_japanese(category: str) -> str:
    """Get Japanese name for category"""
    category_map = {
        "tops": "トップス",
        "bottoms": "ボトムス",
        "outerwear": "アウター",
        "shoes": "シューズ",
        "accessories": "アクセサリー",
    }
    return category_map.get(category, "ファッション")


def generate_natural_language_item(
    category: str,
    weather: Dict,
    agent_style: str = "casual",
    gender: str = "male",
) -> Dict:
    """
    Generate natural language outfit item recommendation

    Args:
        category: Category (tops, bottoms, outerwear, shoes, accessories)
        weather: Weather context
        agent_style: Agent style (casual, formal, balanced, unique)
        gender: Gender (male, female)

    Returns:
        Dict: Natural language item with generic marketplace links
    """
    temp = weather.get("temperature", 20)
    condition = weather.get("condition", "晴れ")

    # Style-based item recommendations
    style_recommendations = {
        "casual": {
            "tops": {
                "male": ["白のカジュアルシャツ", "グレーのTシャツ", "ネイビーのポロシャツ"],
                "female": ["白のブラウス", "ベージュのニット", "ストライプのシャツ"],
            },
            "bottoms": {
                "male": ["デニムパンツ", "ベージュのチノパン", "グレーのスラックス"],
                "female": ["デニムスカート", "ベージュのワイドパンツ", "カーキのチノパン"],
            },
            "outerwear": {
                "male": ["ネイビーのジャケット", "グレーのカーディガン", "ベージュのブルゾン"],
                "female": ["ベージュのトレンチコート", "グレーのカーディガン", "ネイビーのジャケット"],
            },
            "shoes": {
                "male": ["白のスニーカー", "ブラウンのローファー", "グレーのスリッポン"],
                "female": ["白のスニーカー", "ベージュのパンプス", "ブラウンのローファー"],
            },
            "accessories": {
                "male": ["シンプルな腕時計", "ベージュのトートバッグ", "ブラウンのベルト"],
                "female": ["ゴールドのネックレス", "ベージュのトートバッグ", "シンプルなピアス"],
            },
        },
        "formal": {
            "tops": {
                "male": ["白のドレスシャツ", "ライトブルーのワイシャツ", "グレーのニットベスト"],
                "female": ["白のブラウス", "ネイビーのシャツ", "ベージュのカシミアニット"],
            },
            "bottoms": {
                "male": ["ネイビーのスラックス", "チャコールグレーのパンツ", "黒のドレスパンツ"],
                "female": ["黒のタイトスカート", "ネイビーのスラックス", "グレーのフレアパンツ"],
            },
            "outerwear": {
                "male": ["ネイビーのテーラードジャケット", "チャコールグレーのブレザー", "黒のスーツジャケット"],
                "female": ["ネイビーのテーラードジャケット", "ベージュのジャケット", "黒のブレザー"],
            },
            "shoes": {
                "male": ["黒の革靴", "ブラウンのストレートチップ", "ネイビーのローファー"],
                "female": ["黒のパンプス", "ベージュのヒール", "ネイビーのローファー"],
            },
            "accessories": {
                "male": ["シルバーの腕時計", "黒のレザーバッグ", "ネイビーのネクタイ"],
                "female": ["パールのネックレス", "黒のレザーバッグ", "シルバーのピアス"],
            },
        },
        "balanced": {
            "tops": {
                "male": ["白のオックスフォードシャツ", "ライトグレーのニット", "ネイビーのポロシャツ"],
                "female": ["白のシャツブラウス", "グレーのカーディガン", "ベージュのニット"],
            },
            "bottoms": {
                "male": ["ネイビーのチノパン", "グレーのスラックス", "ダークデニム"],
                "female": ["ネイビーのパンツ", "ベージュのスカート", "グレーのワイドパンツ"],
            },
            "outerwear": {
                "male": ["ネイビーのジャケット", "グレーのブレザー", "ベージュのコート"],
                "female": ["ベージュのジャケット", "グレーのカーディガン", "ネイビーのコート"],
            },
            "shoes": {
                "male": ["ブラウンの革靴", "ネイビーのローファー", "ダークグレーのスニーカー"],
                "female": ["ベージュのパンプス", "ブラウンのローファー", "白のスニーカー"],
            },
            "accessories": {
                "male": ["シンプルな腕時計", "ブラウンのレザーバッグ", "ネイビーのベルト"],
                "female": ["ゴールドのネックレス", "ベージュのバッグ", "シンプルなピアス"],
            },
        },
        "unique": {
            "tops": {
                "male": ["トレンドカラーのシャツ", "柄物のニット", "個性的なデザインのTシャツ"],
                "female": ["トレンドカラーのブラウス", "柄物のニット", "個性的なデザインのトップス"],
            },
            "bottoms": {
                "male": ["カラーパンツ", "柄物のスラックス", "デザイン性のあるデニム"],
                "female": ["カラースカート", "柄物のパンツ", "デザイン性のあるデニム"],
            },
            "outerwear": {
                "male": ["トレンドカラーのジャケット", "デザイン性のあるコート", "個性的なブルゾン"],
                "female": ["トレンドカラーのコート", "デザイン性のあるジャケット", "個性的なカーディガン"],
            },
            "shoes": {
                "male": ["カラースニーカー", "デザイン性のあるローファー", "トレンドのブーツ"],
                "female": ["カラーパンプス", "デザイン性のあるブーツ", "トレンドのスニーカー"],
            },
            "accessories": {
                "male": ["個性的な腕時計", "デザイナーズバッグ", "トレンドのアクセサリー"],
                "female": ["トレンドのネックレス", "デザイナーズバッグ", "個性的なピアス"],
            },
        },
    }

    # Temperature-based adjustments
    if temp < 10:
        # Cold weather - add warmth descriptors
        warmth_descriptors = {
            "tops": "厚手の",
            "outerwear": "防寒性の高い",
            "bottoms": "裏起毛の",
        }
    elif temp > 25:
        # Hot weather - add breathability descriptors
        warmth_descriptors = {
            "tops": "通気性の良い",
            "outerwear": "軽量な",
            "bottoms": "薄手の",
        }
    else:
        warmth_descriptors = {}

    # Get base recommendation
    style_category = style_recommendations.get(agent_style, style_recommendations["casual"])
    category_items = style_category.get(category, {})
    gender_items = category_items.get(gender, category_items.get("male", []))

    # Select item (rotate based on temperature for variety)
    item_index = int(temp) % len(gender_items) if gender_items else 0
    base_item_name = gender_items[item_index] if gender_items else "ベーシックなアイテム"

    # Add temperature descriptor if applicable
    descriptor = warmth_descriptors.get(category, "")
    if descriptor:
        item_name = f"{descriptor}{base_item_name}"
    else:
        item_name = base_item_name

    # Generate item with generic marketplace links
    return {
        "id": f"nl_{category}_{agent_style}",
        "name": item_name,
        "category": category,
        "color": _extract_color_from_name(item_name),
        "description": f"{item_name}（{agent_style}スタイル）",
        "source": "natural_language",
        "marketplace_links": [
            {
                "platform": "楽天市場",
                "url": "https://www.rakuten.co.jp/",
                "search_query": item_name,
            },
            {
                "platform": "Amazon",
                "url": "https://www.amazon.co.jp/",
                "search_query": item_name,
            },
        ],
    }


def _extract_color_from_name(item_name: str) -> str:
    """Extract color from item name"""
    colors = ["白", "黒", "グレー", "ネイビー", "ベージュ", "ブラウン", "カーキ", "ライトブルー", "チャコールグレー", "ダーク"]
    for color in colors:
        if color in item_name:
            return color
    return "ベーシック"


async def supplement_outfit_with_rakuten(
    outfit: Dict,
    missing_categories: List[str],
    weather: Dict,
    gender: str = "male",
) -> Dict:
    """
    Supplement outfit with natural language item recommendations

    Generates descriptive outfit items with generic marketplace links
    instead of calling Rakuten API.

    Args:
        outfit: Existing outfit dictionary
        missing_categories: List of missing categories (e.g., ['shoes', 'tops'])
        weather: Weather context for appropriate selection
        gender: Gender for product filtering (male/female)

    Returns:
        Dict: Updated outfit with natural language items supplemented
    """
    if not missing_categories:
        return outfit

    logger.info(f"Generating natural language items for missing categories: {missing_categories}")

    # Get agent style from outfit
    agent_style = outfit.get("agent_type", "casual")

    # Initialize items list if not exists
    if 'items' not in outfit:
        outfit['items'] = []

    # Generate natural language item for each missing category
    for category in missing_categories:
        try:
            item = generate_natural_language_item(
                category=category,
                weather=weather,
                agent_style=agent_style,
                gender=gender,
            )

            outfit['items'].append(item)
            logger.info(f"Added natural language item for {category}: {item['name']}")

        except Exception as e:
            logger.error(f"Failed to generate item for category {category}: {e}")
            continue

    # Update source to natural_language
    if outfit['items']:
        outfit['source'] = 'natural_language'

    return outfit


# ==================== ツール関数 ====================

# ADK Tool として公開
rakuten_search_tool = search_rakuten_products
