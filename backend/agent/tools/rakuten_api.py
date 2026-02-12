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


# ==================== ツール関数 ====================

# ADK Tool として公開
rakuten_search_tool = search_rakuten_products
