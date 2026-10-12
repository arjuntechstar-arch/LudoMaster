from typing import Optional
from pydantic import BaseModel, ConfigDict, Field

class EnqueueRequest(BaseModel):
    mode: str = Field(default="CLASSIC", pattern="^(CLASSIC|QUICK|TEAM)$")
    player_count: int = Field(default=4, ge=2, le=6)
    region: str = Field(default="GLOBAL", max_length=10)

class TicketResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    ticket_id: str
    status: str
    matched_match_id: Optional[str] = None
    player_count: int
    rating: int
    queue_time_seconds: int = 0
