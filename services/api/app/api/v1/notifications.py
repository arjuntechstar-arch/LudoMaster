from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_admin, get_current_user, require_admin_role
from app.db.session import get_db
from app.models.admin import AdminUser
from app.models.user import User
from app.schemas.notification import AdminBroadcastNotificationRequest, NotificationResponse
from app.services.notification_service import notification_service

router = APIRouter(prefix="/notifications", tags=["Inbox & Push Notifications"])

@router.get("", response_model=List[NotificationResponse])
async def list_notifications(
    limit: int = Query(50, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Fetches user notifications inbox."""
    return await notification_service.list_user_notifications(
        db, user_id=current_user.id, limit=limit, offset=offset
    )

@router.post("/{notification_id}/read")
async def mark_notification_read(
    notification_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Marks a single notification as read."""
    success = await notification_service.mark_as_read(
        db, user_id=current_user.id, notification_id=notification_id
    )
    if not success:
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"status": "success", "notification_id": notification_id, "is_read": True}

@router.post("/read-all")
async def mark_all_notifications_read(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Marks all user notifications as read."""
    count = await notification_service.mark_all_read(db, user_id=current_user.id)
    return {"status": "success", "marked_read_count": count}

@router.post("/broadcast")
async def broadcast_push_notification(
    payload: AdminBroadcastNotificationRequest,
    current_admin: AdminUser = Depends(require_admin_role(["SUPER_ADMIN"])),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to broadcast notifications & push announcements."""
    count = await notification_service.broadcast_notification(
        db,
        title=payload.title,
        body=payload.body,
        category=payload.category,
        target_user_ids=payload.target_user_ids,
        data_payload=payload.data_payload,
    )
    return {"status": "success", "recipients_count": count}
