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

class Season(Base):
    __tablename__ = "seasons"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    season_number = Column(Integer, nullable=False, unique=True)
    title = Column(String(100), nullable=False)
    theme_name = Column(String(50), default="Classic Ludo")
    starts_at = Column(DateTime, nullable=False, default=datetime.datetime.utcnow)
    ends_at = Column(DateTime, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    tiers = relationship("SeasonTier", back_populates="season", cascade="all, delete-orphan", order_by="SeasonTier.tier_number")
    user_progress = relationship("UserSeasonProgress", back_populates="season", cascade="all, delete-orphan")

class SeasonTier(Base):
    __tablename__ = "season_tiers"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    season_id = Column(String(36), ForeignKey("seasons.id", ondelete="CASCADE"), nullable=False)
    tier_number = Column(Integer, nullable=False)
    xp_required = Column(Integer, nullable=False)
    free_reward_coins = Column(Integer, default=0, nullable=False)
    free_reward_gems = Column(Integer, default=0, nullable=False)
    free_reward_item_id = Column(String(36), ForeignKey("catalog_items.id"), nullable=True)
    premium_reward_coins = Column(Integer, default=0, nullable=False)
    premium_reward_gems = Column(Integer, default=0, nullable=False)
    premium_reward_item_id = Column(String(36), ForeignKey("catalog_items.id"), nullable=True)

    season = relationship("Season", back_populates="tiers")
    free_item = relationship("CatalogItem", foreign_keys=[free_reward_item_id])
    premium_item = relationship("CatalogItem", foreign_keys=[premium_reward_item_id])

class UserSeasonProgress(Base):
    __tablename__ = "user_season_progress"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    season_id = Column(String(36), ForeignKey("seasons.id", ondelete="CASCADE"), nullable=False)
    current_xp = Column(Integer, default=0, nullable=False)
    current_tier = Column(Integer, default=1, nullable=False)
    has_premium_pass = Column(Boolean, default=False, nullable=False)
    claimed_free_tiers = Column(JSON, default=list, nullable=False)      # List of tier numbers claimed
    claimed_premium_tiers = Column(JSON, default=list, nullable=False)   # List of premium tier numbers claimed
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    season = relationship("Season", back_populates="user_progress")
    user = relationship("User")
