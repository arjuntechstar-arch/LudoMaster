from typing import TYPE_CHECKING, Optional
from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, generate_uuid

if TYPE_CHECKING:
    from app.models.user import User

class MatchmakingTicket(Base, TimestampMixin):
    __tablename__ = "matchmaking_tickets"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    mode: Mapped[str] = mapped_column(String(20), default="CLASSIC", nullable=False)
    player_count: Mapped[int] = mapped_column(Integer, default=4, nullable=False)
    rating: Mapped[int] = mapped_column(Integer, default=1000, nullable=False)
    region: Mapped[str] = mapped_column(String(10), default="GLOBAL", nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="QUEUED", nullable=False, index=True)  # QUEUED, MATCHED, CANCELLED, EXPIRED
    matched_match_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True)

    user: Mapped["User"] = relationship("User", lazy="selectin")
