from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.inventory import UserInventory
from app.models.user import User
from app.schemas.economy import CatalogItemResponse, EquipItemRequest
from app.services.rewards_service import rewards_service

router = APIRouter(prefix="/inventory", tags=["Inventory & Cosmetics"])

@router.get("", response_model=List[CatalogItemResponse])
async def get_my_inventory(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await rewards_service.ensure_default_inventory(db, current_user.id)
    q = await db.execute(select(UserInventory).where(UserInventory.user_id == current_user.id))
    user_invs = q.scalars().all()

    return [
        CatalogItemResponse(
            id=ui.item.id,
            name=ui.item.name,
            category=ui.item.category,
            description=ui.item.description,
            rarity=ui.item.rarity,
            price_coins=ui.item.price_coins,
            price_gems=ui.item.price_gems,
            asset_key=ui.item.asset_key,
            is_default=ui.item.is_default,
            is_owned=True,
            is_equipped=ui.is_equipped,
        )
        for ui in user_invs
    ]

@router.post("/equip")
async def equip_cosmetic_item(
    payload: EquipItemRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await rewards_service.equip_item(
            db=db,
            user_id=current_user.id,
            item_id=payload.item_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
