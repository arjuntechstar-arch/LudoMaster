from datetime import datetime, timezone
from typing import TYPE_CHECKING, List
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, generate_uuid

if TYPE_CHECKING:
    from app.models.user import User

class CatalogItem(Base, TimestampMixin):
    __tablename__ = "catalog_items"

    id: Mapped[str] = mapped_column(String(50), primary_key=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    category: Mapped[str] = mapped_column(String(30), nullable=False)  # BOARD_THEME, DICE_SKIN, TOKEN_SKIN, FRAME
    description: Mapped[str] = mapped_column(String(255), nullable=False)
    rarity: Mapped[str] = mapped_column(String(20), default="COMMON", nullable=False)  # COMMON, RARE, EPIC, LEGENDARY
    price_coins: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    price_gems: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    asset_key: Mapped[str] = mapped_column(String(100), nullable=False)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    inventory_entries: Mapped[List["UserInventory"]] = relationship(
        "UserInventory", back_populates="item", cascade="all, delete-orphan"
    )

class UserInventory(Base, TimestampMixin):
    __tablename__ = "user_inventory"
    __table_args__ = (UniqueConstraint("user_id", "item_id", name="uq_user_inventory_item"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    item_id: Mapped[str] = mapped_column(String(50), ForeignKey("catalog_items.id", ondelete="CASCADE"), nullable=False)
    is_equipped: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    acquired_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    item: Mapped["CatalogItem"] = relationship("CatalogItem", back_populates="inventory_entries", lazy="selectin")
    user: Mapped["User"] = relationship("User")
