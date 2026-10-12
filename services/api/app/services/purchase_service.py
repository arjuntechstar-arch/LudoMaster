import asyncio
import hashlib
from datetime import datetime, timezone
import logging
from typing import Dict, List, Optional
from pathlib import Path
from urllib.parse import quote
import httpx
from fastapi import HTTPException
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2 import service_account
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.purchase import PurchaseOrder, PurchaseReceipt
from app.models.wallet import Wallet, WalletLedger
from app.models.inventory import UserInventory
from app.core.config import settings
from app.schemas.purchase import IapProduct, VerifyReceiptResponse

logger = logging.getLogger("purchase.service")

IAP_CATALOG: Dict[str, IapProduct] = {
    "coin_pouch_5k": IapProduct(
        id="coin_pouch_5k",
        name="Handful of Coins",
        description="5,000 Ludo Coins to jump into matches",
        price_cents=99,
        currency_code="USD",
        coins=5000,
        gems=0,
        icon="coins",
    ),
    "coin_sack_30k": IapProduct(
        id="coin_sack_30k",
        name="Sack of Gold Coins",
        description="30,000 Coins with a 20% bonus",
        price_cents=499,
        currency_code="USD",
        coins=30000,
        gems=0,
        badge="POPULAR",
        icon="coins_sack",
    ),
    "coin_chest_100k": IapProduct(
        id="coin_chest_100k",
        name="Royal Treasure Chest",
        description="100,000 Coins for high-stakes tournaments",
        price_cents=1499,
        currency_code="USD",
        coins=100000,
        gems=0,
        badge="BEST VALUE",
        icon="chest",
    ),
    "gem_handful_50": IapProduct(
        id="gem_handful_50",
        name="Pouch of Gems",
        description="50 Premium Gems for exclusive skins",
        price_cents=99,
        currency_code="USD",
        coins=0,
        gems=50,
        icon="gem",
    ),
    "gem_bag_300": IapProduct(
        id="gem_bag_300",
        name="Bag of Fine Gems",
        description="300 Premium Gems",
        price_cents=499,
        currency_code="USD",
        coins=0,
        gems=300,
        badge="POPULAR",
        icon="gem_bag",
    ),
    "gem_vault_1000": IapProduct(
        id="gem_vault_1000",
        name="Vault of Flawless Gems",
        description="1,000 Premium Gems for VIP pass and luxury themes",
        price_cents=1499,
        currency_code="USD",
        coins=0,
        gems=1000,
        badge="ELITE",
        icon="gem_vault",
    ),
    "starter_bundle": IapProduct(
        id="starter_bundle",
        name="Ludo Play Starter Bundle",
        description="20,000 Coins + 100 Gems",
        price_cents=299,
        currency_code="USD",
        coins=20000,
        gems=100,
        badge="NEW PLAYER",
        icon="bundle",
    ),
}

for product_id, item_id, name, price in [
    ("cosmetic_neon_board", "theme_neon_cyber", "Neon Cyber Board", 199),
    ("cosmetic_marble_board", "theme_royal_marble", "Royal Marble Board", 399),
    ("cosmetic_gold_dice", "dice_golden_luxury", "Golden Luxury Dice", 199),
    ("cosmetic_crystal_dice", "dice_crystal_prism", "Crystal Prism Dice", 299),
    ("cosmetic_crown_frame", "frame_gold_crown", "Crown of Kings", 199),
]:
    IAP_CATALOG[product_id] = IapProduct(
        id=product_id, name=name, description=f"Permanently unlock {name}",
        price_cents=price, item_id=item_id, consumable=False, icon="cosmetic",
    )

class PurchaseService:
    def billing_enabled(self) -> bool:
        return bool(settings.GOOGLE_PLAY_BILLING_ENABLED and
                    settings.GOOGLE_PLAY_SERVICE_ACCOUNT_FILE and
                    Path(settings.GOOGLE_PLAY_SERVICE_ACCOUNT_FILE).is_file())

    async def _verify_google_purchase(self, user_id: str, product_id: str, token: str) -> dict:
        if not self.billing_enabled():
            raise HTTPException(503, "Google Play purchases are currently unavailable")
        def access_token():
            credentials = service_account.Credentials.from_service_account_file(
                settings.GOOGLE_PLAY_SERVICE_ACCOUNT_FILE,
                scopes=["https://www.googleapis.com/auth/androidpublisher"],
            )
            credentials.refresh(GoogleRequest())
            return credentials.token
        try:
            bearer = await asyncio.to_thread(access_token)
            url = (
                "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
                f"{quote(settings.GOOGLE_PLAY_PACKAGE_NAME, safe='')}/purchases/products/"
                f"{quote(product_id, safe='')}/tokens/{quote(token, safe='')}"
            )
            async with httpx.AsyncClient(timeout=15) as client:
                response = await client.get(url, headers={"Authorization": f"Bearer {bearer}"})
        except Exception as exc:
            raise HTTPException(503, "Could not contact Google Play to verify this purchase") from exc
        if response.status_code in (401, 403) or response.status_code >= 500:
            raise HTTPException(503, "Google Play purchase verification is temporarily unavailable")
        if response.status_code != 200:
            raise ValueError("Google Play could not verify this purchase token")
        purchase = response.json()
        if purchase.get("purchaseState") != 0:
            raise ValueError("Payment is pending or was cancelled; no items have been granted")
        if purchase.get("quantity", 1) != 1:
            raise ValueError("Multi-quantity purchases are not enabled for this game")
        expected_account = hashlib.sha256(user_id.encode()).hexdigest()
        if purchase.get("obfuscatedExternalAccountId") != expected_account:
            raise ValueError("This purchase belongs to a different player account")
        return purchase

    def get_catalog_products(self) -> List[IapProduct]:
        return list(IAP_CATALOG.values())

    async def create_order(
        self, db: AsyncSession, user_id: str, product_id: str, platform: str
    ) -> PurchaseOrder:
        product = IAP_CATALOG.get(product_id)
        if not product:
            raise ValueError(f"Unknown IAP product: {product_id}")
        if platform == "GOOGLE_PLAY":
            if not self.billing_enabled():
                raise HTTPException(503, "Google Play purchases are currently unavailable")
        elif not (platform == "MOCK" and settings.ALLOW_TEST_PURCHASES and settings.ENVIRONMENT.lower() != "production"):
            raise ValueError("Unsupported payment platform")

        order = PurchaseOrder(
            user_id=user_id,
            product_id=product_id,
            platform=platform,
            status="PENDING",
            price_cents=product.price_cents,
            currency_code=product.currency_code,
            idempotency_key=f"order_{user_id}_{product_id}_{datetime.now(timezone.utc).timestamp()}",
        )
        db.add(order)
        await db.commit()
        await db.refresh(order)
        return order

    async def verify_and_fulfill_receipt(
        self,
        db: AsyncSession,
        user_id: str,
        product_id: str,
        platform: str,
        transaction_id: str,
        raw_receipt: str,
        order_id: Optional[str] = None,
    ) -> VerifyReceiptResponse:
        product = IAP_CATALOG.get(product_id)
        if not product:
            raise ValueError(f"Unknown product {product_id}")

        if platform == "GOOGLE_PLAY":
            await self._verify_google_purchase(user_id, product_id, raw_receipt)
            transaction_id = hashlib.sha256(raw_receipt.encode()).hexdigest()
        elif not (platform == "MOCK" and settings.ALLOW_TEST_PURCHASES and settings.ENVIRONMENT.lower() != "production"):
            raise ValueError("Unsupported payment platform")
        elif not raw_receipt or len(raw_receipt) < 8:
            raise ValueError("Invalid test receipt payload")

        # Serialize wallet and entitlement updates for this player.
        wallet = (await db.execute(
            select(Wallet).where(Wallet.user_id == user_id).with_for_update()
        )).scalar_one_or_none()
        if not wallet:
            raise ValueError("Player wallet is unavailable")

        # Never trust an order supplied by another player or for another product.
        order = None
        if order_id:
            order = (await db.execute(select(PurchaseOrder).where(
                PurchaseOrder.id == order_id,
                PurchaseOrder.user_id == user_id,
                PurchaseOrder.product_id == product_id,
                PurchaseOrder.platform == platform,
            ))).scalar_one_or_none()
            if not order:
                raise ValueError("Purchase order does not match this player and product")

        # 1. Anti-Replay Check: the verified purchase token identifies the transaction.
        stmt = select(PurchaseReceipt).where(
            PurchaseReceipt.platform == platform,
            PurchaseReceipt.transaction_id == transaction_id,
        )
        existing_receipt = (await db.execute(stmt)).scalar_one_or_none()
        if existing_receipt:
            if existing_receipt.user_id != user_id:
                raise ValueError("This purchase is already linked to another player")
            if existing_receipt.verification_status != "VALID":
                raise ValueError("This purchase is no longer valid")
            return VerifyReceiptResponse(
                status="SUCCESS", transaction_id=transaction_id, product_id=product_id,
                granted_coins=existing_receipt.granted_coins, granted_gems=existing_receipt.granted_gems,
                new_coins_balance=wallet.coins, new_gems_balance=wallet.gems,
                granted_item_id=product.item_id, message="Purchase already fulfilled; balance unchanged.",
            )

        # 3. Fulfill into player's wallet
        wallet.coins += product.coins
        wallet.gems += product.gems

        if product.item_id:
            # Seed before fulfillment is called from the route; avoid intermediate commits here.
            existing_item = (await db.execute(select(UserInventory).where(
                UserInventory.user_id == user_id, UserInventory.item_id == product.item_id,
            ))).scalar_one_or_none()
            if not existing_item:
                db.add(UserInventory(user_id=user_id, item_id=product.item_id, is_equipped=False))

        # 4. Immutable Wallet Ledger Entry
        if product.coins > 0:
            ledger_coins = WalletLedger(
                wallet_id=wallet.id,
                amount=product.coins,
                currency="COINS",
                balance_after=wallet.coins,
                reason=f"IAP_PURCHASE_{product_id}",
                idempotency_key=f"iap_{platform}_{transaction_id}_coins",
            )
            db.add(ledger_coins)

        if product.gems > 0:
            ledger_gems = WalletLedger(
                wallet_id=wallet.id,
                amount=product.gems,
                currency="GEMS",
                balance_after=wallet.gems,
                reason=f"IAP_PURCHASE_{product_id}",
                idempotency_key=f"iap_{platform}_{transaction_id}_gems",
            )
            db.add(ledger_gems)

        # 5. Record verified receipt
        receipt_record = PurchaseReceipt(
            order_id=order_id,
            user_id=user_id,
            platform=platform,
            transaction_id=transaction_id,
            raw_receipt=raw_receipt,
            verification_status="VALID",
            granted_coins=product.coins,
            granted_gems=product.gems,
        )
        db.add(receipt_record)

        # 6. Update order if order_id provided
        if order:
            order.status = "COMPLETED"

        await db.commit()

        logger.info(
            f"Fulfillment complete for user {user_id}: +{product.coins} Coins, +{product.gems} Gems (tx: {transaction_id})"
        )

        return VerifyReceiptResponse(
            status="SUCCESS",
            transaction_id=transaction_id,
            product_id=product_id,
            granted_coins=product.coins,
            granted_gems=product.gems,
            new_coins_balance=wallet.coins,
            new_gems_balance=wallet.gems,
            message=f"Purchase validated! Granted {product.coins:,} Coins and {product.gems:,} Gems.",
            granted_item_id=product.item_id,
        )

purchase_service = PurchaseService()
