from datetime import date, datetime
from typing import TYPE_CHECKING, Optional
from sqlalchemy import Date, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, generate_uuid

if TYPE_CHECKING:
    from app.models.user import User

class UserDailyReward(Base, TimestampMixin):
    __tablename__ = "user_daily_rewards"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    current_streak: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_claim_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    total_claims: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    user: Mapped["User"] = relationship("User")
