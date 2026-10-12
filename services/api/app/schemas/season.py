from typing import List, Optional
from pydantic import BaseModel

class SeasonTierResponse(BaseModel):
    id: str
    tier_number: int
    xp_required: int
    free_reward_coins: int
    free_reward_gems: int
    free_reward_item_id: Optional[str] = None
    free_reward_item_name: Optional[str] = None
    premium_reward_coins: int
    premium_reward_gems: int
    premium_reward_item_id: Optional[str] = None
    premium_reward_item_name: Optional[str] = None
    is_unlocked: bool = False
    is_free_claimed: bool = False
    is_premium_claimed: bool = False

class SeasonDetailResponse(BaseModel):
    id: str
    season_number: int
    title: str
    theme_name: str
    starts_at: str
    ends_at: str
    is_active: bool
    current_xp: int
    current_tier: int
    has_premium_pass: bool
    premium_pass_cost_gems: int = 100
    tiers: List[SeasonTierResponse] = []

class ClaimSeasonRewardRequest(BaseModel):
    tier_number: int
    is_premium: bool = False

class ClaimSeasonRewardResponse(BaseModel):
    tier_number: int
    coins_awarded: int
    gems_awarded: int
    item_awarded: Optional[str] = None
    new_balance_coins: int
    new_balance_gems: int
