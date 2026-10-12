from typing import Optional
from pydantic import BaseModel, ConfigDict, Field

class ProfileResponse(BaseModel):
    user_id: str
    player_id: str
    username: Optional[str] = None
    display_name: str
    avatar_id: str
    level: int
    xp: int
    country_code: str
    is_guest: bool
    is_verified: bool

class ProfileUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    avatar_id: Optional[str] = Field(default=None, max_length=50)

class PasswordChangeRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=100)
    new_password: str = Field(min_length=6, max_length=100)

class PlayerStatsResponse(BaseModel):
    user_id: str
    matches_played: int
    matches_won: int
    win_rate_percent: float
    win_streak: int
    best_streak: int
    total_captures: int
    total_tokens_home: int

class WalletResponse(BaseModel):
    user_id: str
    coins: int
    gems: int

class UserMeResponse(BaseModel):
    id: str
    is_guest: bool
    is_verified: bool
    profile: ProfileResponse
    stats: PlayerStatsResponse
    wallet: WalletResponse
