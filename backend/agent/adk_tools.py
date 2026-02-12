"""ADK Tool Registration - Register agent tools for Google ADK"""
import logging
from typing import Callable, Dict, List

logger = logging.getLogger(__name__)

# ==================== ツールインポート ====================

from agent.tools.recommendation_cache import (
    get_or_generate_daily_recommendations,
    get_tier_usage,
    TierLimitExceeded,
)
from agent.tools.preference_learner import (
    record_swipe,
    get_preference_profile,
    analyze_preferences,
)
from agent.tools.rakuten_api import search_rakuten_products
from agent.tools.product_search import search_real_products, search_products_with_fallback
from agent.tools.weather import weather_tool
from agent.tools.calendar import calendar_tool
from agent.tools.closet import (
    get_closet_items,
    add_closet_item,
    save_outfit_history,
)
from agent.tools.style_advisor import style_advisor_tool


# ==================== ツール定義 ====================

class ToolDefinition:
    """ADK Tool Definition"""

    def __init__(
        self,
        name: str,
        description: str,
        func: Callable,
        parameters_schema: Dict = None,
    ):
        self.name = name
        self.description = description
        self.func = func
        self.parameters_schema = parameters_schema or {}


# ==================== 登録済みツール ====================

REGISTERED_TOOLS = {
    # 推奨管理
    "get_daily_recommendations": ToolDefinition(
        name="get_daily_recommendations",
        description="Get or generate daily outfit recommendations with tier limit enforcement",
        func=get_or_generate_daily_recommendations,
        parameters_schema={
            "user_id": {"type": "string", "description": "User ID"},
            "weather": {"type": "object", "description": "Weather context"},
            "tpo": {"type": "object", "description": "TPO context"},
            "user_preferences": {"type": "object", "description": "User preferences"},
            "force_regenerate": {"type": "boolean", "description": "Force regeneration"},
            "generator_func": {"type": "function", "description": "Generator function"},
        },
    ),
    "get_tier_usage": ToolDefinition(
        name="get_tier_usage",
        description="Get user's tier usage and daily limits",
        func=get_tier_usage,
        parameters_schema={
            "user_id": {"type": "string", "description": "User ID"},
            "today": {"type": "string", "description": "Today's date (YYYY-MM-DD)"},
        },
    ),
    # 嗜好学習
    "record_swipe": ToolDefinition(
        name="record_swipe",
        description="Record user swipe action (approve/reject) and update preferences",
        func=record_swipe,
        parameters_schema={
            "user_id": {"type": "string", "description": "User ID"},
            "outfit_id": {"type": "string", "description": "Outfit ID"},
            "action": {"type": "string", "description": "Action: approve or reject"},
            "outfit_details": {"type": "object", "description": "Outfit details"},
        },
    ),
    "get_preference_profile": ToolDefinition(
        name="get_preference_profile",
        description="Get user's preference profile learned from swipe history",
        func=get_preference_profile,
        parameters_schema={
            "user_id": {"type": "string", "description": "User ID"},
        },
    ),
    "analyze_preferences": ToolDefinition(
        name="analyze_preferences",
        description="Analyze user preferences and extract insights",
        func=analyze_preferences,
        parameters_schema={
            "profile": {"type": "object", "description": "Preference profile"},
        },
    ),
    # 商品検索
    "search_rakuten_products": ToolDefinition(
        name="search_rakuten_products",
        description="Search fashion products from Rakuten Ichiba API",
        func=search_rakuten_products,
        parameters_schema={
            "category": {"type": "string", "description": "Category"},
            "color": {"type": "string", "description": "Color filter"},
            "style": {"type": "string", "description": "Style filter"},
            "gender": {"type": "string", "description": "Gender: male or female"},
            "max_results": {"type": "integer", "description": "Max results"},
        },
    ),
    "search_real_products": ToolDefinition(
        name="search_real_products",
        description="Search real products with affiliate links",
        func=search_real_products,
        parameters_schema={
            "category": {"type": "string", "description": "Category"},
            "color": {"type": "string", "description": "Color filter"},
            "style": {"type": "string", "description": "Style filter"},
            "gender": {"type": "string", "description": "Gender: male or female"},
            "max_results": {"type": "integer", "description": "Max results"},
        },
    ),
    # 既存ツール
    "weather_tool": ToolDefinition(
        name="weather_tool",
        description="Get current weather for location",
        func=weather_tool,
    ),
    "calendar_tool": ToolDefinition(
        name="calendar_tool",
        description="Get calendar events and TPO recommendations",
        func=calendar_tool,
    ),
    "get_closet_items": ToolDefinition(
        name="get_closet_items",
        description="Get items from user's closet with filters",
        func=get_closet_items,
    ),
    "add_closet_item": ToolDefinition(
        name="add_closet_item",
        description="Add item to user's closet",
        func=add_closet_item,
    ),
    "save_outfit_history": ToolDefinition(
        name="save_outfit_history",
        description="Save worn outfit to history",
        func=save_outfit_history,
    ),
    "style_advisor_tool": ToolDefinition(
        name="style_advisor_tool",
        description="Evaluate outfit style, color harmony, and appropriateness",
        func=style_advisor_tool,
    ),
}


# ==================== ツール取得 ====================

def get_tool(name: str) -> ToolDefinition:
    """
    Get tool by name

    Args:
        name: Tool name

    Returns:
        ToolDefinition: Tool definition

    Raises:
        KeyError: If tool not found
    """
    if name not in REGISTERED_TOOLS:
        raise KeyError(f"Tool '{name}' not found. Available tools: {list(REGISTERED_TOOLS.keys())}")

    return REGISTERED_TOOLS[name]


def get_all_tools() -> Dict[str, ToolDefinition]:
    """
    Get all registered tools

    Returns:
        dict: All tools
    """
    return REGISTERED_TOOLS.copy()


def get_tool_names() -> List[str]:
    """
    Get list of all tool names

    Returns:
        list: Tool names
    """
    return list(REGISTERED_TOOLS.keys())


def get_tools_for_agent(tool_names: List[str]) -> List[ToolDefinition]:
    """
    Get specific tools for an agent

    Args:
        tool_names: List of tool names

    Returns:
        list: List of tool definitions
    """
    tools = []
    for name in tool_names:
        try:
            tools.append(get_tool(name))
        except KeyError:
            logger.warning(f"Tool '{name}' not found, skipping")

    return tools


# ==================== ADK統合用ヘルパー ====================

def convert_to_adk_tool(tool_def: ToolDefinition):
    """
    Convert ToolDefinition to Google ADK FunctionTool

    Args:
        tool_def: ToolDefinition instance

    Returns:
        FunctionTool: ADK FunctionTool instance

    Note:
        Requires google-adk package to be installed
    """
    try:
        from google.adk.tools import FunctionTool

        return FunctionTool(
            func=tool_def.func,
            name=tool_def.name,
            description=tool_def.description,
        )
    except ImportError:
        logger.error("google-adk not installed. Cannot convert to ADK tool.")
        return None


def get_adk_tools(tool_names: List[str] = None):
    """
    Get ADK FunctionTool instances

    Args:
        tool_names: List of tool names (None = all tools)

    Returns:
        list: List of ADK FunctionTool instances
    """
    if tool_names is None:
        tool_names = get_tool_names()

    tool_defs = get_tools_for_agent(tool_names)
    adk_tools = []

    for tool_def in tool_defs:
        adk_tool = convert_to_adk_tool(tool_def)
        if adk_tool:
            adk_tools.append(adk_tool)

    return adk_tools


# ==================== ロギング ====================

logger.info(f"ADK Tools registered: {len(REGISTERED_TOOLS)} tools available")
