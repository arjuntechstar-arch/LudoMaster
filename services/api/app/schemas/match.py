from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict

class MatchPlayerHistoryItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: Optional[str]
    seat_index: int
    display_name: str
    avatar_id: str
    color: str
    placement: Optional[int]
    is_bot: bool

class MatchHistoryItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    mode: str
    status: str
    my_placement: Optional[int]
    my_color: str
    coins_delta: int
    xp_gained: int
    started_at: datetime
    finished_at: Optional[datetime]
    players: List[MatchPlayerHistoryItem]

class MatchHistoryResponse(BaseModel):
    matches: List[MatchHistoryItem]
