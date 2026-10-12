from datetime import datetime, timezone
from typing import TYPE_CHECKING, List, Optional
from sqlalchemy import Boolean, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, generate_uuid

if TYPE_CHECKING:
    from app.models.profile import Profile, PlayerStats
    from app.models.wallet import Wallet

class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    status: Mapped[str] = mapped_column(String(20), default="ACTIVE", nullable=False)
    is_guest: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    identities: Mapped[List["UserIdentity"]] = relationship(
        "UserIdentity", back_populates="user", cascade="all, delete-orphan", lazy="selectin"
    )
    devices: Mapped[List["Device"]] = relationship(
        "Device", back_populates="user", cascade="all, delete-orphan", lazy="selectin"
    )
    refresh_sessions: Mapped[List["RefreshSession"]] = relationship(
        "RefreshSession", back_populates="user", cascade="all, delete-orphan"
    )
    profile: Mapped[Optional["Profile"]] = relationship(
        "Profile", back_populates="user", uselist=False, cascade="all, delete-orphan", lazy="selectin"
    )
    stats: Mapped[Optional["PlayerStats"]] = relationship(
        "PlayerStats", back_populates="user", uselist=False, cascade="all, delete-orphan", lazy="selectin"
    )
    wallet: Mapped[Optional["Wallet"]] = relationship(
        "Wallet", back_populates="user", uselist=False, cascade="all, delete-orphan", lazy="selectin"
    )

class UserIdentity(Base, TimestampMixin):
    __tablename__ = "user_identities"
    __table_args__ = (UniqueConstraint("provider", "provider_user_id", name="uq_provider_user"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    provider: Mapped[str] = mapped_column(String(20), nullable=False)  # GUEST, EMAIL, GOOGLE, APPLE
    provider_user_id: Mapped[str] = mapped_column(String(255), nullable=False)
    credential_hash: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="identities")

class Device(Base, TimestampMixin):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    device_id: Mapped[str] = mapped_column(String(100), nullable=False)
    platform: Mapped[str] = mapped_column(String(20), default="ANDROID", nullable=False)
    app_version: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    push_token: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    last_active_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    user: Mapped["User"] = relationship("User", back_populates="devices")

class RefreshSession(Base, TimestampMixin):
    __tablename__ = "refresh_sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    device_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    refresh_token_hash: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="refresh_sessions")
