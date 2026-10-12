from datetime import datetime, timezone
from typing import TYPE_CHECKING, List, Optional
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, generate_uuid

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.room import Room

class Match(Base, TimestampMixin):
    __tablename__ = "matches"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    room_id: Mapped[Optional[str]] = mapped_column(
        String(36), ForeignKey("rooms.id", ondelete="SET NULL"), nullable=True
    )
    mode: Mapped[str] = mapped_column(String(20), default="CLASSIC", nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="ACTIVE", nullable=False)  # ACTIVE, COMPLETED, ABANDONED
    winner_user_id: Mapped[Optional[str]] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
    finished_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    sequence: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    ruleset_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    players: Mapped[List["MatchPlayer"]] = relationship(
        "MatchPlayer", back_populates="match", cascade="all, delete-orphan", lazy="selectin"
    )
    snapshots: Mapped[List["GameSnapshot"]] = relationship(
        "GameSnapshot", back_populates="match", cascade="all, delete-orphan"
    )
    events: Mapped[List["GameEvent"]] = relationship(
        "GameEvent", back_populates="match", cascade="all, delete-orphan"
    )


class MatchPlayer(Base):
    __tablename__ = "match_players"
    __table_args__ = (
        UniqueConstraint("match_id", "seat_index", name="uq_match_seat"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    match_id: Mapped[str] = mapped_column(String(36), ForeignKey("matches.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[Optional[str]] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    seat_index: Mapped[int] = mapped_column(Integer, nullable=False)
    color: Mapped[str] = mapped_column(String(10), nullable=False)  # RED, GREEN, YELLOW, BLUE
    placement: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # 1, 2, 3, 4
    coins_delta: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    xp_gained: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_bot: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    disconnected_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    match: Mapped["Match"] = relationship("Match", back_populates="players")
    user: Mapped[Optional["User"]] = relationship("User", lazy="selectin")


class GameSnapshot(Base):
    __tablename__ = "game_snapshots"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    match_id: Mapped[str] = mapped_column(String(36), ForeignKey("matches.id", ondelete="CASCADE"), index=True, nullable=False)
    sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    state_json: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    match: Mapped["Match"] = relationship("Match", back_populates="snapshots")


class GameEvent(Base):
    __tablename__ = "game_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    match_id: Mapped[str] = mapped_column(String(36), ForeignKey("matches.id", ondelete="CASCADE"), index=True, nullable=False)
    sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    event_type: Mapped[str] = mapped_column(String(50), nullable=False)
    payload: Mapped[str] = mapped_column(Text, nullable=False)
    server_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    match: Mapped["Match"] = relationship("Match", back_populates="events")
