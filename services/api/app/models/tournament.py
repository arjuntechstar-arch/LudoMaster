import datetime
import uuid
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    JSON,
)
from sqlalchemy.orm import relationship
from app.db.base import Base

class Tournament(Base):
    __tablename__ = "tournaments"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String(100), nullable=False)
    description = Column(String(255), default="")
    entry_fee_coins = Column(Integer, default=500, nullable=False)
    prize_pool_coins = Column(Integer, default=3000, nullable=False)
    prize_pool_gems = Column(Integer, default=25, nullable=False)
    max_participants = Column(Integer, default=8, nullable=False)
    current_participants = Column(Integer, default=0, nullable=False)
    status = Column(String(20), default="REGISTRATION", nullable=False)  # REGISTRATION, IN_PROGRESS, COMPLETED, CANCELLED
    winner_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)

    participants = relationship("TournamentParticipant", back_populates="tournament", cascade="all, delete-orphan")
    matches = relationship("TournamentMatch", back_populates="tournament", cascade="all, delete-orphan")

class TournamentParticipant(Base):
    __tablename__ = "tournament_participants"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    tournament_id = Column(String(36), ForeignKey("tournaments.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    seed = Column(Integer, nullable=False, default=1)
    placement = Column(Integer, nullable=True)  # 1 = 1st place, 2 = 2nd place, etc.
    prize_coins = Column(Integer, default=0, nullable=False)
    prize_gems = Column(Integer, default=0, nullable=False)
    eliminated_round = Column(Integer, nullable=True)  # 1 = Semifinals, 2 = Finals
    joined_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)

    tournament = relationship("Tournament", back_populates="participants")
    user = relationship("User")

class TournamentMatch(Base):
    __tablename__ = "tournament_matches"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    tournament_id = Column(String(36), ForeignKey("tournaments.id", ondelete="CASCADE"), nullable=False)
    round_number = Column(Integer, nullable=False, default=1)  # 1 = Semifinals, 2 = Finals
    match_index = Column(Integer, nullable=False, default=0)    # 0 or 1 for Semifinals, 0 for Final
    status = Column(String(20), default="PENDING", nullable=False)  # PENDING, IN_PROGRESS, COMPLETED
    match_id = Column(String(36), nullable=True)
    participant_ids = Column(JSON, default=list, nullable=False)  # List of user IDs in this match
    winner_ids = Column(JSON, default=list, nullable=False)       # List of advancing/winning user IDs

    tournament = relationship("Tournament", back_populates="matches")
