from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict

class NotificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    title: str
    body: str
    category: str
    data_payload: Optional[str] = None
    is_read: bool
    read_at: Optional[datetime] = None
    created_at: datetime

class AdminBroadcastNotificationRequest(BaseModel):
    title: str
    body: str
    category: str = "ANNOUNCEMENT"
    target_user_ids: Optional[List[str]] = None
    data_payload: Optional[Dict[str, Any]] = None
