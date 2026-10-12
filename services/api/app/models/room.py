from datetime import datetime, timezone
from typing import TYPE_CHECKING, List, Optional
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, generate_uuid

if TYPE_CHECKING:
    from app.models.user import User

class Room(Base, TimestampMixin):
    __tablename__ = "rooms"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    code: Mapped[str] = mapped_column(String(10), unique=True, index=True, nullable=False)
    host_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    mode: Mapped[str] = mapped_column(String(20), default="CLASSIC", nullable=False)
    max_players: Mapped[int] = mapped_column(Integer, default=4, nullable=False)
    fill_with_bots: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="WAITING", nullable=False)  # WAITING, ACTIVE, COMPLETED, ABANDONED
    bet_coins: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    members: Mapped[List["RoomMember"]] = relationship(
        "RoomMember", back_populates="room", cascade="all, delete-orphan", lazy="selectin"
    )
    host: Mapped["User"] = relationship("User", foreign_keys=[host_user_id], lazy="selectin")


class RoomMember(Base):
    __tablename__ = "room_members"
    __table_args__ = (
        UniqueConstraint("room_id", "seat_index", name="uq_room_seat"),
        UniqueConstraint("room_id", "user_id", name="uq_room_user"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    room_id: Mapped[str] = mapped_column(String(36), ForeignKey("rooms.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    seat_index: Mapped[int] = mapped_column(Integer, nullable=False)
    is_ready: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_host: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    room: Mapped["Room"] = relationship("Room", back_populates="members")
    user: Mapped["User"] = relationship("User", lazy="selectin")
