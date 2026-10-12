from typing import TYPE_CHECKING, List, Optional
from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, generate_uuid

if TYPE_CHECKING:
    from app.models.user import User

class Wallet(Base, TimestampMixin):
    __tablename__ = "wallets"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    coins: Mapped[int] = mapped_column(Integer, default=1000, nullable=False)
    gems: Mapped[int] = mapped_column(Integer, default=10, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="wallet")
    ledger_entries: Mapped[List["WalletLedger"]] = relationship(
        "WalletLedger", back_populates="wallet", cascade="all, delete-orphan"
    )

class WalletLedger(Base, TimestampMixin):
    __tablename__ = "wallet_ledger"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    wallet_id: Mapped[str] = mapped_column(String(36), ForeignKey("wallets.id", ondelete="CASCADE"), nullable=False)
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="COINS", nullable=False)  # COINS, GEMS
    balance_after: Mapped[int] = mapped_column(Integer, nullable=False)
    reason: Mapped[str] = mapped_column(String(50), nullable=False)
    idempotency_key: Mapped[Optional[str]] = mapped_column(String(100), unique=True, nullable=True)

    wallet: Mapped["Wallet"] = relationship("Wallet", back_populates="ledger_entries")
