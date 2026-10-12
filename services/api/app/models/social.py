from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import DateTime, ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, generate_uuid
from app.models.user import User

class Friendship(Base, TimestampMixin):
    __tablename__ = "friendships"
    __table_args__ = (
        UniqueConstraint("user_id", "friend_user_id", name="uq_friendship_pair"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    friend_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(20), default="PENDING", nullable=False)  # PENDING, ACCEPTED, DECLINED

    requester: Mapped["User"] = relationship("User", foreign_keys=[user_id], lazy="selectin")
    addressee: Mapped["User"] = relationship("User", foreign_keys=[friend_user_id], lazy="selectin")

class Block(Base):
    __tablename__ = "blocks"
    __table_args__ = (
        UniqueConstraint("blocker_id", "blocked_id", name="uq_block_pair"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    blocker_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    blocked_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    reason: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    blocker: Mapped["User"] = relationship("User", foreign_keys=[blocker_id], lazy="selectin")
    blocked: Mapped["User"] = relationship("User", foreign_keys=[blocked_id], lazy="selectin")

class Report(Base):
    __tablename__ = "reports"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    reporter_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    reported_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    category: Mapped[str] = mapped_column(String(30), nullable=False)  # HARASSMENT, CHEATING, INAPPROPRIATE_NAME, SPAM, OTHER
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    match_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="OPEN", nullable=False)  # OPEN, RESOLVED, DISMISSED
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    reporter: Mapped["User"] = relationship("User", foreign_keys=[reporter_id], lazy="selectin")
    reported_user: Mapped["User"] = relationship("User", foreign_keys=[reported_user_id], lazy="selectin")

class RoomInvite(Base):
    __tablename__ = "room_invites"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    room_id: Mapped[str] = mapped_column(String(36), ForeignKey("rooms.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    recipient_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(20), default="PENDING", nullable=False)  # PENDING, ACCEPTED, DECLINED, EXPIRED
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    sender: Mapped["User"] = relationship("User", foreign_keys=[sender_id], lazy="selectin")
    recipient: Mapped["User"] = relationship("User", foreign_keys=[recipient_id], lazy="selectin")
