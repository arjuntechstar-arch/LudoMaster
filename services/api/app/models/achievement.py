from datetime import datetime
from typing import TYPE_CHECKING, List, Optional
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, generate_uuid

if TYPE_CHECKING:
    from app.models.user import User

class Achievement(Base, TimestampMixin):
    __tablename__ = "achievements"

    id: Mapped[str] = mapped_column(String(50), primary_key=True)
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str] = mapped_column(String(255), nullable=False)
    action_type: Mapped[str] = mapped_column(String(30), nullable=False)  # MATCH_WIN, CAPTURE, TOKENS_HOME, LEVEL, COINS_EARNED
    target_count: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    reward_coins: Mapped[int] = mapped_column(Integer, default=200, nullable=False)
    reward_gems: Mapped[int] = mapped_column(Integer, default=5, nullable=False)
    reward_xp: Mapped[int] = mapped_column(Integer, default=100, nullable=False)
    badge_key: Mapped[str] = mapped_column(String(50), default="badge_bronze", nullable=False)

    user_achievements: Mapped[List["UserAchievement"]] = relationship(
        "UserAchievement", back_populates="achievement", cascade="all, delete-orphan"
    )

class UserAchievement(Base, TimestampMixin):
    __tablename__ = "user_achievements"
    __table_args__ = (UniqueConstraint("user_id", "achievement_id", name="uq_user_achievement"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    achievement_id: Mapped[str] = mapped_column(String(50), ForeignKey("achievements.id", ondelete="CASCADE"), nullable=False)
    current_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_unlocked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_claimed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    unlocked_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    achievement: Mapped["Achievement"] = relationship("Achievement", back_populates="user_achievements", lazy="selectin")
    user: Mapped["User"] = relationship("User")
