from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.purchase import PurchaseOrder, PurchaseReceipt
from app.models.user import User
from app.schemas.purchase import (
    CreateOrderRequest,
    CreateOrderResponse,
    IapProduct,
    PurchaseHistoryItem,
    VerifyReceiptRequest,
    VerifyReceiptResponse,
)
from app.services.purchase_service import purchase_service

router = APIRouter(prefix="/purchases", tags=["In-App Purchases & Receipts"])

@router.get("/config")
async def purchase_configuration():
    return {"google_play_enabled": purchase_service.billing_enabled(), "web_payments_enabled": False}

@router.get("/products", response_model=List[IapProduct])
async def list_iap_products():
    """Lists all available real-money In-App Purchase packages."""
    return purchase_service.get_catalog_products()

@router.post("/create-order", response_model=CreateOrderResponse)
async def create_purchase_order(
    payload: CreateOrderRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Initializes a new order before opening the platform payment sheet."""
    if payload.platform == "MOCK" and settings.ENVIRONMENT.lower() == "production":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="In-app purchases are unavailable until store receipt verification is configured.",
        )
    try:
        order = await purchase_service.create_order(
            db,
            user_id=current_user.id,
            product_id=payload.product_id,
            platform=payload.platform,
        )
        return CreateOrderResponse(
            order_id=order.id,
            product_id=order.product_id,
            platform=order.platform,
            price_cents=order.price_cents,
            currency_code=order.currency_code,
            status=order.status,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.post("/verify-receipt", response_model=VerifyReceiptResponse)
async def verify_purchase_receipt(
    payload: VerifyReceiptRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Server-authoritative receipt validation and balance fulfillment."""
    if payload.platform == "MOCK" and settings.ENVIRONMENT.lower() == "production":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Receipt verification is not configured for production.",
        )
    try:
        from app.services.rewards_service import rewards_service
        await rewards_service.seed_catalog(db)
        return await purchase_service.verify_and_fulfill_receipt(
            db,
            user_id=current_user.id,
            product_id=payload.product_id,
            platform=payload.platform,
            transaction_id=payload.transaction_id,
            raw_receipt=payload.raw_receipt,
            order_id=payload.order_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.get("/history", response_model=List[PurchaseHistoryItem])
async def get_purchase_history(
    limit: int = Query(20, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Fetches user order and receipt history."""
    stmt = (
        select(PurchaseOrder)
        .where(PurchaseOrder.user_id == current_user.id)
        .order_by(PurchaseOrder.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())
