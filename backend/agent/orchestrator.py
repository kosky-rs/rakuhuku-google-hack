"""Orchestration Agent for Multi-Agent Outfit Recommendation System"""
import asyncio
import logging
from typing import Dict, List

from agent.style_agents import (
    CasualStyleAgent,
    FormalStyleAgent,
    BalancedStyleAgent,
    UniqueStyleAgent,
)

logger = logging.getLogger(__name__)


# ==================== オーケストレーター ====================


class OutfitOrchestrator:
    """
    Orchestrates multiple style agents to generate daily outfit recommendations

    Responsibilities:
    - Coordinate 4 specialized agents (Casual, Formal, Balanced, Unique)
    - Run agents in parallel for performance
    - Score and rank recommendations
    - Select top 2 closet-based + 1 external product outfit
    """

    def __init__(self):
        """Initialize orchestrator with all style agents"""
        self.agents = {
            "casual": CasualStyleAgent(),
            "formal": FormalStyleAgent(),
            "balanced": BalancedStyleAgent(),
            "unique": UniqueStyleAgent(),
        }
        logger.info("OutfitOrchestrator initialized with 4 agents")

    async def generate_daily_recommendations(
        self,
        user_id: str,
        weather: Dict,
        tpo: Dict,
        user_preferences: Dict,
    ) -> List[Dict]:
        """
        Generate 3 daily outfit recommendations

        Strategy:
        - 2 from closet (top-scored from Casual/Formal/Balanced agents)
        - 1 from external products (Unique agent)

        Args:
            user_id: User ID
            weather: Weather context
            tpo: TPO requirements
            user_preferences: User preference profile

        Returns:
            list: Top 3 outfit recommendations (sorted by score)
        """
        context = {
            "weather": weather,
            "tpo": tpo,
            "user_preferences": user_preferences,
        }

        logger.info(f"Starting multi-agent outfit generation for user {user_id}")

        # Run all agents in parallel
        tasks = [
            self.agents["casual"].generate_outfit(user_id, context),
            self.agents["formal"].generate_outfit(user_id, context),
            self.agents["balanced"].generate_outfit(user_id, context),
            self.agents["unique"].generate_outfit(user_id, context),
        ]

        try:
            results = await asyncio.gather(*tasks, return_exceptions=True)
        except Exception as e:
            logger.error(f"Agent execution failed: {e}")
            return []

        # Handle exceptions
        valid_results = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                logger.error(f"Agent {list(self.agents.keys())[i]} failed: {result}")
            else:
                valid_results.append(result)

        if not valid_results:
            logger.error("All agents failed to generate outfits")
            return []

        logger.info(f"Generated {len(valid_results)} outfits from agents")

        # Rank and select top 3
        top_3 = self._select_top_recommendations(valid_results, user_preferences, tpo, weather)

        logger.info(f"Selected top 3 recommendations with scores: {[r['score'] for r in top_3]}")

        return top_3

    def _select_top_recommendations(
        self,
        outfits: List[Dict],
        user_preferences: Dict,
        tpo: Dict,
        weather: Dict,
    ) -> List[Dict]:
        """
        Select top 3 recommendations: 2 closet + 1 external

        Args:
            outfits: All generated outfits
            user_preferences: User preferences
            tpo: TPO context
            weather: Weather context

        Returns:
            list: Top 3 outfits
        """
        # Separate closet and external outfits
        closet_outfits = [o for o in outfits if o.get("source") == "closet" and o.get("score", 0) > 0]
        external_outfits = [o for o in outfits if o.get("source") == "external" and o.get("score", 0) > 0]

        # Re-score with context weights
        for outfit in closet_outfits:
            outfit["final_score"] = self._calculate_final_score(outfit, user_preferences, tpo, weather)

        for outfit in external_outfits:
            outfit["final_score"] = self._calculate_final_score(outfit, user_preferences, tpo, weather)

        # Sort by final score
        closet_outfits.sort(key=lambda x: x["final_score"], reverse=True)
        external_outfits.sort(key=lambda x: x["final_score"], reverse=True)

        # Select top 2 from closet
        top_closet = closet_outfits[:2]

        # Select top 1 from external
        top_external = external_outfits[:1] if external_outfits else []

        # Combine and ensure we have 3
        selected = top_closet + top_external

        # If we don't have 3, fill with remaining closet outfits
        if len(selected) < 3 and len(closet_outfits) > 2:
            remaining_closet = closet_outfits[2:]
            selected.extend(remaining_closet[: 3 - len(selected)])

        # Sort final selection by score (highest first)
        selected.sort(key=lambda x: x["final_score"], reverse=True)

        return selected[:3]

    def _calculate_final_score(
        self,
        outfit: Dict,
        user_preferences: Dict,
        tpo: Dict,
        weather: Dict,
    ) -> float:
        """
        Calculate final score with lightweight adjustments to agent's base score

        Strategy:
        - Trust agent's base_score as primary evaluation
        - Apply minor adjustments based on orchestrator-level context:
          - TPO appropriateness: ±10%
          - User preference alignment: ±5%

        Args:
            outfit: Outfit data
            user_preferences: User preferences
            tpo: TPO context
            weather: Weather context

        Returns:
            float: Final score (0-100)
        """
        base_score = outfit.get("score", 0)

        # TPO adjustment (±10%)
        tpo_bonus = self._get_tpo_bonus(outfit, tpo)

        # Preference adjustment (±5%)
        pref_bonus = self._get_preference_bonus(outfit, user_preferences)

        # Calculate final score
        final = base_score + tpo_bonus + pref_bonus

        return round(min(100, max(0, final)), 2)

    def _get_tpo_bonus(self, outfit: Dict, tpo: Dict) -> float:
        """
        Calculate TPO appropriateness bonus (±10%)

        Returns:
            float: Bonus score (-10 to +10)
        """
        formality_required = tpo.get("formality_required", "casual")
        agent_type = outfit.get("agent_type", "casual")

        # Perfect match: +10, Good match: +5, Neutral: 0, Mismatch: -5, Poor: -10
        bonus_map = {
            ("formal", "formal"): 10,
            ("formal", "business_casual"): 5,
            ("balanced", "business_casual"): 10,
            ("balanced", "formal"): 5,
            ("balanced", "casual"): 5,
            ("casual", "casual"): 10,
            ("casual", "business_casual"): 0,
            ("casual", "formal"): -5,
            ("unique", "casual"): 5,
            ("unique", "business_casual"): 0,
            ("unique", "formal"): -5,
        }

        bonus = bonus_map.get((agent_type, formality_required), 0)
        return float(bonus)

    def _get_preference_bonus(self, outfit: Dict, user_preferences: Dict) -> float:
        """
        Calculate user preference alignment bonus (±5%)

        Returns:
            float: Bonus score (-5 to +5)
        """
        agent_type = outfit.get("agent_type", "casual")
        style_scores = user_preferences.get("style_scores", {})

        # Get user's preference for this agent type (0-100)
        agent_pref = style_scores.get(agent_type, 50)

        # Convert to bonus: 50 = 0, 100 = +5, 0 = -5
        bonus = (agent_pref - 50) / 10
        return round(bonus, 2)

    async def regenerate_recommendations(
        self,
        user_id: str,
        weather: Dict,
        tpo: Dict,
        user_preferences: Dict,
        excluded_outfit_ids: List[str] = None,
    ) -> List[Dict]:
        """
        Regenerate recommendations, optionally excluding previous ones

        Args:
            user_id: User ID
            weather: Weather context
            tpo: TPO context
            user_preferences: User preferences
            excluded_outfit_ids: List of outfit IDs to exclude

        Returns:
            list: New top 3 recommendations
        """
        excluded_outfit_ids = excluded_outfit_ids or []

        logger.info(f"Regenerating recommendations for user {user_id}, excluding {len(excluded_outfit_ids)} outfits")

        # Generate new recommendations
        recommendations = await self.generate_daily_recommendations(
            user_id, weather, tpo, user_preferences
        )

        # Filter out excluded outfits
        filtered = [
            r for r in recommendations if r.get("outfit_id") not in excluded_outfit_ids
        ]

        return filtered


# ==================== シングルトンインスタンス ====================

_orchestrator_instance = None


def get_orchestrator() -> OutfitOrchestrator:
    """
    Get singleton instance of orchestrator

    Returns:
        OutfitOrchestrator: Orchestrator instance
    """
    global _orchestrator_instance
    if _orchestrator_instance is None:
        _orchestrator_instance = OutfitOrchestrator()
    return _orchestrator_instance
