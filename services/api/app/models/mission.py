from datetime import datetime, timezone
from typing import TYPE_CHECKING, List, Optional
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, generate_uuid

if TYPE_CHECKING:
    from app.models.user import User

class Mission(Base, TimestampMixin):
    __tablename__ = "missions"

    id: Mapped[str] = mapped_column(String(50), primary_key=True)
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str] = mapped_column(String(255), nullable=False)
    category: Mapped[str] = mapped_column(String(20), default="DAILY", nullable=False)  # DAILY, WEEKLY
    action_type: Mapped[str] = mapped_column(String(30), nullable=False)  # MATCH_PLAY, MATCH_WIN, CAPTURE, TOKEN_HOME
    target_count: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    reward_coins: Mapped[int] = mapped_column(Integer, default=100, nullable=False)
    reward_gems: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    reward_xp: Mapped[int] = mapped_column(Integer, default=50, nullable=False)
    icon: Mapped[str] = mapped_column(String(50), default="sports_esports", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    user_missions: Mapped[List["UserMission"]] = relationship(
        "UserMission", back_populates="mission", cascade="all, delete-orphan"
    )

class UserMission(Base, TimestampMixin):
    __tablename__ = "user_missions"
    __table_args__ = (UniqueConstraint("user_id", "mission_id", name="uq_user_mission"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    mission_id: Mapped[str] = mapped_column(String(50), ForeignKey("missions.id", ondelete="CASCADE"), nullable=False)
    current_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_claimed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    mission: Mapped["Mission"] = relationship("Mission", back_populates="user_missions", lazy="selectin")
    user: Mapped["User"] = relationship("User")
