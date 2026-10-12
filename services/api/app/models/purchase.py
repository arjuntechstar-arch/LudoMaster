from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, generate_uuid

class PurchaseOrder(Base, TimestampMixin):
    __tablename__ = "purchase_orders"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    product_id: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    platform: Mapped[str] = mapped_column(String(30), nullable=False)  # GOOGLE_PLAY, APPLE_APP_STORE, WEB_STRIPE
    status: Mapped[str] = mapped_column(String(20), default="PENDING", nullable=False)  # PENDING, COMPLETED, FAILED, REFUNDED
    price_cents: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    currency_code: Mapped[str] = mapped_column(String(10), default="USD", nullable=False)
    idempotency_key: Mapped[Optional[str]] = mapped_column(String(100), unique=True, nullable=True)

    receipts: Mapped[list["PurchaseReceipt"]] = relationship(
        "PurchaseReceipt", back_populates="order", cascade="all, delete-orphan", lazy="selectin"
    )

class PurchaseReceipt(Base):
    __tablename__ = "purchase_receipts"
    __table_args__ = (
        UniqueConstraint("platform", "transaction_id", name="uq_platform_transaction"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    order_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("purchase_orders.id", ondelete="SET NULL"), nullable=True)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    platform: Mapped[str] = mapped_column(String(30), nullable=False)
    transaction_id: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    raw_receipt: Mapped[str] = mapped_column(Text, nullable=False)
    verification_status: Mapped[str] = mapped_column(String(20), default="VALID", nullable=False)  # VALID, INVALID, REVOKED
    granted_coins: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    granted_gems: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    verified_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    order: Mapped[Optional["PurchaseOrder"]] = relationship("PurchaseOrder", back_populates="receipts")
