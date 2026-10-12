from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field

class CreateRoomRequest(BaseModel):
    mode: str = Field(default="CLASSIC", pattern="^(CLASSIC|QUICK|TEAM)$")
    max_players: int = Field(default=4, ge=2, le=6)
    fill_with_bots: bool = True
    bet_coins: int = Field(default=0, ge=0)

class JoinRoomRequest(BaseModel):
    code: str = Field(min_length=4, max_length=10)

class RoomMemberResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    seat_index: int
    is_ready: bool
    is_host: bool
    display_name: str
    avatar_id: str
    level: int
    joined_at: datetime

class RoomResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    code: str
    host_user_id: str
    mode: str
    max_players: int
    fill_with_bots: bool = True
    status: str
    bet_coins: int
    members: List[RoomMemberResponse]
    match_id: Optional[str] = None
    created_at: datetime

class ToggleReadyRequest(BaseModel):
    is_ready: bool
