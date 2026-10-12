from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict
from app.schemas.user import ProfileResponse

class FriendRequestCreate(BaseModel):
    target_user_id: Optional[str] = None
    player_id: Optional[str] = None
    username: Optional[str] = None

class FriendshipResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    friend_user_id: str
    status: str
    created_at: datetime
    friend_profile: Optional[ProfileResponse] = None

class FriendItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: str
    player_id: str
    username: Optional[str] = None
    display_name: str
    avatar_id: str
    level: int
    country_code: str
    is_online: bool = True

class BlockCreate(BaseModel):
    blocked_user_id: str
    reason: Optional[str] = None

class BlockResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    blocker_id: str
    blocked_id: str
    blocked_display_name: Optional[str] = None
    created_at: datetime

class ReportCreate(BaseModel):
    reported_user_id: str
    category: str  # HARASSMENT, CHEATING, INAPPROPRIATE_NAME, SPAM, OTHER
    description: Optional[str] = None
    match_id: Optional[str] = None

class ReportResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    reported_user_id: str
    category: str
    status: str
    created_at: datetime

class RoomInviteCreate(BaseModel):
    recipient_id: str

class RoomInviteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    room_id: str
    room_code: Optional[str] = None
    sender_id: str
    sender_name: Optional[str] = None
    recipient_id: str
    status: str
    created_at: datetime
