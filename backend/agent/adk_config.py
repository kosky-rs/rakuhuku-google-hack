"""Google ADK Configuration"""
import os
from typing import Optional

# GCP Project Configuration
PROJECT_ID = os.getenv("GCP_PROJECT_ID", "rakufuku-pwa")
LOCATION = os.getenv("VERTEX_AI_LOCATION", "asia-northeast1")

# Model Configuration
BASE_MODEL = os.getenv("ADK_MODEL_NAME", "gemini-2.0-flash-001")
MAX_TOKENS = int(os.getenv("ADK_MAX_TOKENS", "2048"))
TEMPERATURE = float(os.getenv("ADK_TEMPERATURE", "0.7"))

# Agent Configuration
AGENT_CONFIG = {
    "model": BASE_MODEL,
    "generation_config": {
        "max_output_tokens": MAX_TOKENS,
        "temperature": TEMPERATURE,
    },
    "project": PROJECT_ID,
    "location": LOCATION,
}


def get_agent_config(
    model: Optional[str] = None,
    temperature: Optional[float] = None,
    max_tokens: Optional[int] = None
) -> dict:
    """
    Get agent configuration with optional overrides

    Args:
        model: Model name override
        temperature: Temperature override
        max_tokens: Max tokens override

    Returns:
        dict: Agent configuration
    """
    config = AGENT_CONFIG.copy()

    if model:
        config["model"] = model
    if temperature is not None:
        config["generation_config"]["temperature"] = temperature
    if max_tokens is not None:
        config["generation_config"]["max_output_tokens"] = max_tokens

    return config
