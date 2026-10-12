from typing import List, Optional
from pydantic import BaseModel, ConfigDict

class MissionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    description: str
    category: str
    action_type: str
    current_count: int
    target_count: int
    reward_coins: int
    reward_gems: int
    reward_xp: int
    icon: str
    is_completed: bool
    is_claimed: bool

class ClaimMissionResponse(BaseModel):
    mission_id: str
    coins_awarded: int
    gems_awarded: int
    xp_awarded: int
    new_balance_coins: int
    new_balance_gems: int
    new_level: int
    new_xp: int
