from fastapi import APIRouter, Query
from app.core.config import settings
from app.schemas.config import RemoteConfigResponse, VersionCheckResponse

router = APIRouter(prefix="/config", tags=["Remote Configuration"])

@router.get("/version-check", response_model=VersionCheckResponse)
async def check_version(
    platform: str = Query(default="ANDROID"),
    app_version: str = Query(default="1.0.0"),
):
    min_version = settings.MIN_IOS_VERSION if platform.upper() == "IOS" else settings.MIN_ANDROID_VERSION

    # Simple semver comparison helper
    def is_older(v1: str, v2: str) -> bool:
        try:
            parts1 = [int(p) for p in v1.split(".")]
            parts2 = [int(p) for p in v2.split(".")]
            return parts1 < parts2
        except Exception:
            return False

    upgrade_required = is_older(app_version, min_version)

    return VersionCheckResponse(
        upgrade_required=upgrade_required,
        maintenance_mode=settings.MAINTENANCE_MODE,
        latest_version=settings.LATEST_APP_VERSION,
        min_version=min_version,
        message="Please update to the latest version to continue playing." if upgrade_required else None,
    )

@router.get("/app", response_model=RemoteConfigResponse)
async def get_app_config():
    return RemoteConfigResponse(
        configs={
            "classic_tokens_per_player": 4,
            "quick_tokens_per_player": 2,
            "turn_timeout_seconds": 15,
            "max_consecutive_sixes": 3,
            "capture_bonus_enabled": True,
            "home_bonus_enabled": True,
            "safe_cells": [0, 8, 13, 21, 26, 34, 39, 47],
        },
        feature_flags={
            "online_multiplayer": True,
            "quick_mode": True,
            "tournaments": False,
            "in_game_voice": False,
            "moderated_chat": True,
        },
    )
