from typing import Any, Dict, Optional
from pydantic import BaseModel

class VersionCheckResponse(BaseModel):
    upgrade_required: bool
    maintenance_mode: bool
    latest_version: str
    min_version: str
    message: Optional[str] = None

class RemoteConfigResponse(BaseModel):
    configs: Dict[str, Any]
    feature_flags: Dict[str, bool]
