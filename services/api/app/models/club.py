from datetime import datetime, timezone
from typing import TYPE_CHECKING, List, Optional
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, generate_uuid

if TYPE_CHECKING:
    from app.models.user import User

class Club(Base, TimestampMixin):
    __tablename__ = "clubs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    name: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
    tag: Mapped[str] = mapped_column(String(8), unique=True, index=True, nullable=False)  # e.g., "LUDOKING"
    description: Mapped[str] = mapped_column(String(255), default="Welcome to our club!", nullable=False)
    badge_icon: Mapped[str] = mapped_column(String(50), default="shield_gold", nullable=False)
    leader_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    min_level: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_open: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    member_count: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    max_members: Mapped[int] = mapped_column(Integer, default=30, nullable=False)

    members: Mapped[List["ClubMember"]] = relationship(
        "ClubMember", back_populates="club", cascade="all, delete-orphan", lazy="selectin"
    )

class ClubMember(Base, TimestampMixin):
    __tablename__ = "club_members"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    club_id: Mapped[str] = mapped_column(String(36), ForeignKey("clubs.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role: Mapped[str] = mapped_column(String(20), default="MEMBER", nullable=False)  # LEADER, CO_LEADER, MEMBER
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    club: Mapped["Club"] = relationship("Club", back_populates="members")
    user: Mapped["User"] = relationship("User", lazy="selectin")
