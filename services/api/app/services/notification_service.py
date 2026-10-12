from datetime import datetime, timezone
import json
import logging
from typing import Any, Dict, List, Optional
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.notification import Notification
from app.models.user import Device, User

logger = logging.getLogger("notification.service")

class NotificationService:
    async def send_notification(
        self,
        db: AsyncSession,
        user_id: str,
        title: str,
        body: str,
        category: str = "ANNOUNCEMENT",
        data_payload: Optional[Dict[str, Any]] = None,
    ) -> Notification:
        payload_str = json.dumps(data_payload) if data_payload else None

        notif = Notification(
            user_id=user_id,
            title=title,
            body=body,
            category=category,
            data_payload=payload_str,
            is_read=False,
        )
        db.add(notif)
        await db.commit()
        await db.refresh(notif)

        # Dispatch push notification to player's active devices
        device_stmt = select(Device).where(
            Device.user_id == user_id,
            Device.push_token.isnot(None),
        )
        devices = (await db.execute(device_stmt)).scalars().all()
        for dev in devices:
            # FCM / APNs dispatch pipeline abstraction
            logger.info(
                f"[PUSH DISPATCH] Platform: {dev.platform} | Token: {dev.push_token[:12]}... | Title: '{title}'"
            )

        return notif

    async def broadcast_notification(
        self,
        db: AsyncSession,
        title: str,
        body: str,
        category: str = "ANNOUNCEMENT",
        target_user_ids: Optional[List[str]] = None,
        data_payload: Optional[Dict[str, Any]] = None,
    ) -> int:
        if target_user_ids is None:
            user_stmt = select(User.id).where(User.status == "ACTIVE")
            target_user_ids = list((await db.execute(user_stmt)).scalars().all())

        payload_str = json.dumps(data_payload) if data_payload else None
        created_count = 0

        for uid in target_user_ids:
            notif = Notification(
                user_id=uid,
                title=title,
                body=body,
                category=category,
                data_payload=payload_str,
                is_read=False,
            )
            db.add(notif)
            created_count += 1

        await db.commit()
        logger.info(f"Broadcasted '{title}' to {created_count} players.")
        return created_count

    async def list_user_notifications(
        self, db: AsyncSession, user_id: str, limit: int = 50, offset: int = 0
    ) -> List[Notification]:
        stmt = (
            select(Notification)
            .where(Notification.user_id == user_id)
            .order_by(Notification.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        result = await db.execute(stmt)
        return list(result.scalars().all())

    async def mark_as_read(
        self, db: AsyncSession, user_id: str, notification_id: str
    ) -> bool:
        stmt = select(Notification).where(
            Notification.id == notification_id, Notification.user_id == user_id
        )
        notif = (await db.execute(stmt)).scalar_one_or_none()
        if not notif:
            return False

        notif.is_read = True
        notif.read_at = datetime.now(timezone.utc)
        await db.commit()
        return True

    async def mark_all_read(self, db: AsyncSession, user_id: str) -> int:
        stmt = (
            update(Notification)
            .where(Notification.user_id == user_id, Notification.is_read == False)
            .values(is_read=True, read_at=datetime.now(timezone.utc))
        )
        res = await db.execute(stmt)
        await db.commit()
        return res.rowcount

notification_service = NotificationService()
