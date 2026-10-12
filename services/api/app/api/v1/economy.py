from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from app.core.config import settings
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.economy import (
    CatalogItemResponse,
    ClaimDailyRewardResponse,
    DailyRewardStatusResponse,
    PurchaseItemRequest,
)
from app.services.rewards_service import rewards_service

router = APIRouter(prefix="/economy", tags=["Economy & Progression"])

@router.get("/daily-reward", response_model=DailyRewardStatusResponse)
async def get_daily_reward_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await rewards_service.get_daily_reward_status(db, current_user.id)

@router.post("/daily-reward/claim", response_model=ClaimDailyRewardResponse)
async def claim_daily_reward(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        res = await rewards_service.claim_daily_reward(db, current_user.id)
        return ClaimDailyRewardResponse(**res)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.get("/catalog", response_model=List[CatalogItemResponse])
async def get_store_catalog(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    items = await rewards_service.get_catalog_with_user_state(db, current_user.id)
    return [CatalogItemResponse(**it) for it in items]

@router.post("/purchase")
async def purchase_store_item(
    payload: PurchaseItemRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await rewards_service.purchase_item(
            db=db,
            user_id=current_user.id,
            item_id=payload.item_id,
            currency=payload.currency,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

async def _ad_reward_status(db: AsyncSession, user_id: str) -> dict:
    from datetime import datetime, timezone
    from sqlalchemy import func, select
    from app.models.wallet import Wallet, WalletLedger

    day_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    claimed = (await db.execute(select(func.count(WalletLedger.id)).join(
        Wallet, Wallet.id == WalletLedger.wallet_id,
    ).where(
        Wallet.user_id == user_id, WalletLedger.reason == "WATCH_AD_REWARD",
        WalletLedger.currency == "COINS", WalletLedger.created_at >= day_start,
    ))).scalar_one()
    test_ads = settings.ALLOW_TEST_AD_REWARDS and settings.ENVIRONMENT.lower() != "production"
    remaining = max(0, settings.DAILY_AD_REWARD_LIMIT - claimed)
    return {
        "daily_limit": settings.DAILY_AD_REWARD_LIMIT,
        "claimed_today": claimed, "remaining_today": remaining,
        "can_watch": bool(test_ads and remaining > 0),
        "test_ads": bool(test_ads),
        "message": "All of today's ad rewards have been claimed" if remaining == 0 else
                   "Test ad rewards available" if test_ads else "Ads are currently unavailable",
    }

@router.get("/watch-ad/status")
async def get_ad_reward_status(
    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db),
):
    return await _ad_reward_status(db, current_user.id)

@router.post("/watch-ad/claim")
async def claim_watch_ad_reward(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if settings.ENVIRONMENT.lower() == "production" or not settings.ALLOW_TEST_AD_REWARDS:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Ad rewards are unavailable until server-side ad verification is configured.",
        )

    from app.services.economy import economy_service
    from app.models.wallet import Wallet
    from sqlalchemy import select
    from datetime import datetime, timezone

    await db.execute(select(Wallet).where(Wallet.user_id == current_user.id).with_for_update())
    ad_status = await _ad_reward_status(db, current_user.id)
    if not ad_status["can_watch"]:
        raise HTTPException(status_code=429, detail="Today's ad rewards are complete. You can buy coins in the Store.")
    claim_key = f"ad_{current_user.id}_{datetime.now(timezone.utc).date()}_{ad_status['claimed_today'] + 1}"

    # Credit 500 Coins
    _, wallet = await economy_service.record_transaction(
        db=db,
        user_id=current_user.id,
        amount=500,
        currency="COINS",
        reason="WATCH_AD_REWARD",
        idempotency_key=f"{claim_key}_coins", commit=False,
    )
    # Credit 2 Gems
    _, wallet = await economy_service.record_transaction(
        db=db,
        user_id=current_user.id,
        amount=2,
        currency="GEMS",
        reason="WATCH_AD_REWARD",
        idempotency_key=f"{claim_key}_gems", commit=False,
    )
    await db.commit()
    return {
        "coins_granted": 500,
        "gems_granted": 2,
        "new_coins": wallet.coins,
        "new_gems": wallet.gems,
        "message": "Extra reward claimed by watching ad!",
    }
