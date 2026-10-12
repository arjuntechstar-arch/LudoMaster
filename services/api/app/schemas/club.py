from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field

class CreateClubRequest(BaseModel):
    name: str = Field(min_length=3, max_length=50)
    tag: str = Field(min_length=2, max_length=8)
    description: str = Field(default="Welcome to our club!", max_length=255)
    badge_icon: str = Field(default="shield_gold", max_length=50)
    min_level: int = Field(default=1, ge=1)
    is_open: bool = Field(default=True)

class ClubMemberResponse(BaseModel):
    id: str
    user_id: str
    role: str
    joined_at: datetime
    display_name: str = "Player"
    avatar_id: str = "avatar_0"
    level: int = 1

class ClubResponse(BaseModel):
    id: str
    name: str
    tag: str
    description: str
    badge_icon: str
    leader_user_id: str
    min_level: int
    is_open: bool
    member_count: int
    max_members: int
    created_at: datetime

class ClubDetailResponse(ClubResponse):
    members: List[ClubMemberResponse] = []

class VoiceTokenRequest(BaseModel):
    enable_mic: bool = True
    privacy_consent: bool = True

class VoiceTokenResponse(BaseModel):
    room_id: str
    user_id: str
    voice_session_id: str
    token: str
    server_url: str = "wss://voice.ludomaster.io/signaling"
    mic_enabled: bool
    privacy_notice: str = "Voice communications are protected under end-to-end user moderation policies."

class VoiceMuteRequest(BaseModel):
    is_muted: bool
    target_user_id: Optional[str] = None

class VoiceReportRequest(BaseModel):
    reported_user_id: str
    reason: str = Field(default="ABUSE", max_length=50)
    details: Optional[str] = Field(default=None, max_length=255)
