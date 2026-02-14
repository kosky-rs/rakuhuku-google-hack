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
from agent.tools.closet import get_closet_items

logger = logging.getLogger(__name__)

# Import nano_banana with fallback
try:
    from agent.tools.nano_banana import generate_outfit_mannequin_image
    NANO_BANANA_AVAILABLE = True
except ImportError as e:
    logger.warning(f"Failed to import nano_banana: {e}. Using fallback placeholder generation.")
    NANO_BANANA_AVAILABLE = False


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
        Generate 5 daily outfit recommendations

        Strategy:
        - Ensure at least 1 recommendation from each agent type (diversity guarantee)
        - Fill remaining slots with highest-scored recommendations
        - Total of 5 recommendations

        Args:
            user_id: User ID
            weather: Weather context
            tpo: TPO requirements
            user_preferences: User preference profile

        Returns:
            list: Top 5 outfit recommendations (sorted by score)
        """
        # Pre-fetch closet items once for all agents (optimization)
        try:
            closet_items = await get_closet_items(user_id=user_id)
            logger.info(f"Pre-fetched {len(closet_items)} closet items for user {user_id}")
        except Exception as e:
            logger.error(f"Failed to fetch closet items: {e}")
            closet_items = []

        context = {
            "weather": weather,
            "tpo": tpo,
            "user_preferences": user_preferences,
            "closet_items": closet_items,
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

        # Rank and select top 5 with agent diversity guarantee
        top_5 = self._select_top_recommendations(valid_results, user_preferences, tpo, weather)

        logger.info(f"Selected top 5 recommendations with scores: {[r['score'] for r in top_5]}")

        # Generate mannequin images for each outfit
        for outfit in top_5:
            try:
                agent_type = outfit.get("agent_type", "casual")
                gender = user_preferences.get("gender", "male")

                logger.info(f"Generating mannequin image for outfit {outfit['outfit_id']} (agent: {agent_type}, gender: {gender})")

                if NANO_BANANA_AVAILABLE:
                    items = outfit.get("items", [])
                    reasoning = outfit.get("reasoning", "")
                    image_prompt_en = outfit.get("image_prompt_en", "")
                    # Generate image from outfit description
                    image_url = generate_outfit_mannequin_image(
                        items=items,
                        weather=weather,
                        style=agent_type,
                        gender=gender,
                        reasoning=reasoning,
                        image_prompt_en=image_prompt_en,
                    )
                else:
                    # Fallback: generate placeholder directly
                    image_url = self._get_placeholder_image_url(agent_type, gender)

                if image_url:
                    outfit["mannequin_image_url"] = image_url
                    logger.info(f"Successfully set mannequin image URL for outfit {outfit['outfit_id']}: {image_url[:50]}...")
                else:
                    logger.warning(f"Image generation returned None for outfit {outfit['outfit_id']}")
                    outfit["mannequin_image_url"] = self._get_placeholder_image_url(agent_type, gender)

            except Exception as e:
                logger.error(f"Failed to generate mannequin image for outfit {outfit['outfit_id']}: {e}", exc_info=True)
                # Add placeholder on failure
                outfit["mannequin_image_url"] = self._get_placeholder_image_url(agent_type, gender)

        # Final guarantee: ensure every outfit has mannequin_image_url
        for outfit in top_5:
            if not outfit.get("mannequin_image_url"):
                outfit["mannequin_image_url"] = self._get_placeholder_image_url(
                    outfit.get("agent_type", "casual"),
                    user_preferences.get("gender", "male"),
                )

        return top_5

    def _select_top_recommendations(
        self,
        outfits: List[Dict],
        user_preferences: Dict,
        tpo: Dict,
        weather: Dict,
    ) -> List[Dict]:
        """
        Select top 5 recommendations with agent diversity guarantee

        Strategy:
        - Ensure at least 1 from each agent type (diversity guarantee)
        - Fill remaining slots with highest-scored recommendations
        - Return 5 total recommendations

        Args:
            outfits: All generated outfits
            user_preferences: User preferences
            tpo: TPO context
            weather: Weather context

        Returns:
            list: Top 5 outfits with agent diversity
        """
        # Re-score all outfits with context weights
        for outfit in outfits:
            if outfit.get("score", 0) > 0:
                outfit["final_score"] = self._calculate_final_score(outfit, user_preferences, tpo, weather)
            else:
                outfit["final_score"] = 0

        # Ensure agent diversity - select at least 1 from each agent type
        guaranteed = self._ensure_agent_diversity(outfits)

        # Get remaining outfits (not in guaranteed list)
        guaranteed_ids = {o["outfit_id"] for o in guaranteed}
        remaining = [o for o in outfits if o["outfit_id"] not in guaranteed_ids and o["final_score"] > 0]

        # Sort remaining by score
        remaining.sort(key=lambda x: x["final_score"], reverse=True)

        # Combine: guaranteed + top remaining to reach at least 5 total
        selected = guaranteed + remaining

        # Ensure we have at least 5 recommendations
        # If we have less than 5, duplicate the highest-scored ones with slight variations
        if len(selected) < 5:
            logger.warning(f"Only {len(selected)} outfits generated, padding to 5")
            while len(selected) < 5 and guaranteed:
                # Add duplicates of high-scoring outfits
                selected.append(guaranteed[len(selected) % len(guaranteed)])

        # Take top 5 (or more if available)
        selected = selected[:max(5, len(guaranteed))]

        # Final sort by score (highest first)
        selected.sort(key=lambda x: x["final_score"], reverse=True)

        # Mark the highest-scored outfit as recommended
        if selected:
            selected[0]["is_recommended"] = True
            logger.info(f"Marked outfit {selected[0]['outfit_id']} as recommended with score {selected[0]['final_score']}")

        return selected

    def _get_placeholder_image_url(self, style: str, gender: str) -> str:
        """
        Return empty string as placeholder when image generation fails.
        Frontend handles empty/null mannequin_image_url with a built-in placeholder widget.
        """
        return ""

    def _ensure_agent_diversity(self, outfits: List[Dict]) -> List[Dict]:
        """
        Ensure at least one recommendation from each agent type

        Args:
            outfits: All generated outfits

        Returns:
            list: One outfit from each agent type (up to 4)
        """
        agent_types = ['casual', 'formal', 'balanced', 'unique']
        guaranteed = []

        for agent_type in agent_types:
            # Find all outfits from this agent type
            candidates = [o for o in outfits if o.get('agent_type') == agent_type and o.get('final_score', 0) > 0]

            if candidates:
                # Pick the highest scored one from this agent
                best = max(candidates, key=lambda x: x.get('final_score', 0))
                guaranteed.append(best)

        return guaranteed

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
