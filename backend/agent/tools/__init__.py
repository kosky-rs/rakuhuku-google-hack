# Agent Tools Package
from .weather import weather_tool
from .closet import (
    closet_tool, get_all_categories, add_closet_item, add_closet_items_bulk,
    delete_closet_item, save_outfit_history, get_outfit_history,
)
from .calendar import calendar_tool
from .style_advisor import style_advisor_tool
from .outfit_analyzer import outfit_analyzer_tool
from .product_search import product_search_tool

__all__ = [
    "weather_tool",
    "closet_tool",
    "get_all_categories",
    "add_closet_item",
    "add_closet_items_bulk",
    "delete_closet_item",
    "save_outfit_history",
    "get_outfit_history",
    "calendar_tool",
    "style_advisor_tool",
    "outfit_analyzer_tool",
    "product_search_tool",
]
