from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field

class DailyRewardDayResponse(BaseModel):
    day: int
    coins: int
    gems: int
    xp: int
    is_claimed: bool
    is_today: bool

class DailyRewardStatusResponse(BaseModel):
    current_streak: int
    can_claim: bool
    last_claim_date: Optional[str] = None
    days: List[DailyRewardDayResponse]

class ClaimDailyRewardResponse(BaseModel):
    message: str
    day: int
    coins_awarded: int
    gems_awarded: int
    xp_awarded: int
    new_balance_coins: int
    new_balance_gems: int
    new_level: int
    new_xp: int

class CatalogItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    category: str
    description: str
    rarity: str
    price_coins: int
    price_gems: int
    asset_key: str
    is_default: bool
    is_owned: bool = False
    is_equipped: bool = False

class PurchaseItemRequest(BaseModel):
    item_id: str
    currency: str = Field(default="COINS", pattern="^(COINS|GEMS)$")

class EquipItemRequest(BaseModel):
    item_id: str

class InventoryResponse(BaseModel):
    items: List[CatalogItemResponse]
