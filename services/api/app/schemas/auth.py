from typing import Optional
from pydantic import BaseModel, EmailStr, Field, field_validator

class GuestLoginRequest(BaseModel):
    device_id: str = Field(..., min_length=4, max_length=100)
    platform: str = Field(default="ANDROID", max_length=20)
    app_version: Optional[str] = Field(default="1.0.0", max_length=50)
    push_token: Optional[str] = Field(default=None, max_length=255)

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=100)
    display_name: str = Field(..., min_length=2, max_length=30)
    username: str = Field(..., min_length=3, max_length=20, pattern=r"^[a-z][a-z0-9_]{2,19}$")
    avatar_id: str = Field(..., pattern=r"^avatar_[0-7]$")
    device_id: str = Field(..., min_length=4, max_length=100)
    platform: str = Field(default="ANDROID", max_length=20)
    app_version: Optional[str] = Field(default="1.0.0", max_length=50)

    @field_validator("display_name", mode="before")
    @classmethod
    def normalize_display_name(cls, value):
        return value.strip() if isinstance(value, str) else value

    @field_validator("username", mode="before")
    @classmethod
    def normalize_username(cls, value):
        return value.strip().removeprefix("@").lower() if isinstance(value, str) else value

class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=100)
    device_id: Optional[str] = Field(default=None, max_length=100)
    platform: str = Field(default="ANDROID", max_length=20)
    app_version: Optional[str] = Field(default="1.0.0", max_length=50)

class GuestUpgradeRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=100)
    display_name: str = Field(..., min_length=2, max_length=30)
    username: str = Field(..., min_length=3, max_length=20, pattern=r"^[a-z][a-z0-9_]{2,19}$")
    avatar_id: str = Field(..., pattern=r"^avatar_[0-7]$")

    @field_validator("display_name", mode="before")
    @classmethod
    def normalize_display_name(cls, value):
        return value.strip() if isinstance(value, str) else value

    @field_validator("username", mode="before")
    @classmethod
    def normalize_username(cls, value):
        return value.strip().removeprefix("@").lower() if isinstance(value, str) else value

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class GoogleLoginRequest(BaseModel):
    id_token: str = Field(min_length=8, max_length=10000)
    link_to_current_user: bool = False
    display_name: Optional[str] = Field(default=None, min_length=2, max_length=30)
    username: Optional[str] = Field(default=None, min_length=3, max_length=20, pattern=r"^[a-z][a-z0-9_]{2,19}$")
    avatar_id: Optional[str] = Field(default=None, pattern=r"^avatar_[0-7]$")

    @field_validator("display_name", mode="before")
    @classmethod
    def normalize_display_name(cls, value):
        return value.strip() if isinstance(value, str) else value

    @field_validator("username", mode="before")
    @classmethod
    def normalize_username(cls, value):
        return value.strip().removeprefix("@").lower() if isinstance(value, str) else value

class PlayGamesLoginRequest(BaseModel):
    server_auth_code: str = Field(min_length=8, max_length=10000)
    link_to_current_user: bool = False
    display_name: Optional[str] = Field(default=None, min_length=2, max_length=30)
    username: Optional[str] = Field(default=None, min_length=3, max_length=20, pattern=r"^[a-z][a-z0-9_]{2,19}$")
    avatar_id: Optional[str] = Field(default=None, pattern=r"^avatar_[0-7]$")

    @field_validator("display_name", mode="before")
    @classmethod
    def normalize_display_name(cls, value):
        return value.strip() if isinstance(value, str) else value

    @field_validator("username", mode="before")
    @classmethod
    def normalize_username(cls, value):
        return value.strip().removeprefix("@").lower() if isinstance(value, str) else value

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int
    user_id: str
    player_id: str
    display_name: str
    is_guest: bool
