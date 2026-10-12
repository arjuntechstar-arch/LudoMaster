from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field

class AdminLoginRequest(BaseModel):
    username: str
    password: str

class AdminUserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    username: str
    email: str
    role: str
    is_active: bool
    last_login_at: Optional[datetime] = None
    created_at: datetime

class AdminLoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    admin: AdminUserResponse

class AdminKpiOverview(BaseModel):
    total_users: int
    active_users_today: int
    active_rooms: int
    total_matches: int
    total_coins_in_circulation: int
    total_gems_in_circulation: int
    pending_reports_count: int
    active_tournaments_count: int

class AdminUserSummary(BaseModel):
    id: str
    player_id: str
    display_name: str
    level: int
    status: str
    is_guest: bool
    is_verified: bool
    coins: int
    gems: int
    matches_played: int
    matches_won: int
    created_at: datetime

class AdminUserDetailResponse(BaseModel):
    id: str
    status: str
    is_guest: bool
    is_verified: bool
    created_at: datetime
    updated_at: datetime
    profile: Optional[Dict[str, Any]] = None
    stats: Optional[Dict[str, Any]] = None
    wallet: Optional[Dict[str, Any]] = None
    devices: List[Dict[str, Any]] = Field(default_factory=list)
    identities: List[Dict[str, Any]] = Field(default_factory=list)

class AdminSuspendRequest(BaseModel):
    reason: str
    duration_days: Optional[int] = None

class AdminWalletAdjustRequest(BaseModel):
    amount: int
    currency: str = "COINS"  # COINS or GEMS
    reason: str
    idempotency_key: Optional[str] = None

class AdminReportActionRequest(BaseModel):
    action: str  # DISMISS, SUSPEND_USER, WARN
    notes: Optional[str] = None

class AdminCatalogItemRequest(BaseModel):
    id: str
    name: str
    category: str  # THEME, DICE, TOKEN, EMOTE, AVATAR_FRAME
    price_coins: int = 0
    price_gems: int = 0
    is_active: bool = True
    rarity: str = "COMMON"
    asset_path: Optional[str] = None

class AdminConfigUpdateRequest(BaseModel):
    key: str
    value: str
    description: Optional[str] = None

class AdminFeatureFlagToggleRequest(BaseModel):
    name: str
    enabled: bool
    description: Optional[str] = None

class AdminAuditLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    admin_id: str
    admin_username: str
    action: str
    target_type: str
    target_id: Optional[str] = None
    details: Optional[str] = None
    ip_address: Optional[str] = None
    created_at: datetime
