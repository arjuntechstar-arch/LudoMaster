from typing import TYPE_CHECKING
from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, generate_uuid

if TYPE_CHECKING:
    from app.models.user import User

class Profile(Base, TimestampMixin):
    __tablename__ = "profiles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    player_id: Mapped[str] = mapped_column(String(20), unique=True, index=True, nullable=False)
    username: Mapped[str | None] = mapped_column(String(20), unique=True, index=True, nullable=True)
    display_name: Mapped[str] = mapped_column(String(50), nullable=False)
    avatar_id: Mapped[str] = mapped_column(String(50), default="avatar_0", nullable=False)
    level: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    xp: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    country_code: Mapped[str] = mapped_column(String(3), default="GLB", nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="profile", lazy="selectin")

class PlayerStats(Base, TimestampMixin):
    __tablename__ = "player_stats"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    matches_played: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    matches_won: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    win_streak: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    best_streak: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_captures: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_tokens_home: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="stats")
