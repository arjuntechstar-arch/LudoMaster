from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict

class IapProduct(BaseModel):
    id: str
    name: str
    description: str
    price_cents: int
    currency_code: str = "USD"
    coins: int = 0
    gems: int = 0
    badge: Optional[str] = None
    icon: str = "coins"
    item_id: Optional[str] = None
    consumable: bool = True

class CreateOrderRequest(BaseModel):
    product_id: str
    platform: str = "GOOGLE_PLAY"  # GOOGLE_PLAY, APPLE_APP_STORE

class CreateOrderResponse(BaseModel):
    order_id: str
    product_id: str
    platform: str
    price_cents: int
    currency_code: str
    status: str

class VerifyReceiptRequest(BaseModel):
    order_id: Optional[str] = None
    platform: str = "GOOGLE_PLAY"
    transaction_id: str
    product_id: str
    raw_receipt: str

class VerifyReceiptResponse(BaseModel):
    status: str  # SUCCESS, FAILED
    transaction_id: str
    product_id: str
    granted_coins: int
    granted_gems: int
    new_coins_balance: int
    new_gems_balance: int
    message: str
    granted_item_id: Optional[str] = None

class PurchaseHistoryItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    product_id: str
    platform: str
    status: str
    price_cents: int
    currency_code: str
    created_at: datetime
