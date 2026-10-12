from datetime import datetime
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.profile import Profile
from app.models.social import Block, Friendship
from app.models.user import User
from app.schemas.social import BlockCreate, BlockResponse

router = APIRouter(prefix="/blocks", tags=["Safety & Blocking"])

@router.post("", response_model=BlockResponse, status_code=status.HTTP_201_CREATED)
async def block_user(
    payload: BlockCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    target_id = payload.blocked_user_id
    if target_id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot block yourself.")

    # Check existing block
    existing_q = await db.execute(
        select(Block).where(Block.blocker_id == current_user.id, Block.blocked_id == target_id)
    )
    existing = existing_q.scalar_one_or_none()
    if existing:
        return BlockResponse(
            id=existing.id,
            blocker_id=existing.blocker_id,
            blocked_id=existing.blocked_id,
            created_at=existing.created_at,
        )

    # Automatically sever any existing friendship
    f_q = await db.execute(
        select(Friendship).where(
            or_(
                (Friendship.user_id == current_user.id) & (Friendship.friend_user_id == target_id),
                (Friendship.user_id == target_id) & (Friendship.friend_user_id == current_user.id),
            )
        )
    )
    for f in f_q.scalars().all():
        await db.delete(f)

    block = Block(
        blocker_id=current_user.id,
        blocked_id=target_id,
        reason=payload.reason,
    )
    db.add(block)
    await db.commit()
    await db.refresh(block)

    return BlockResponse(
        id=block.id,
        blocker_id=block.blocker_id,
        blocked_id=block.blocked_id,
        created_at=block.created_at,
    )

@router.get("", response_model=List[BlockResponse])
async def list_blocks(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = await db.execute(
        select(Block)
        .options(selectinload(Block.blocked).selectinload(User.profile))
        .where(Block.blocker_id == current_user.id)
    )
    blocks = q.scalars().all()
    res = []
    for b in blocks:
        p = b.blocked.profile if b.blocked else None
        res.append(
            BlockResponse(
                id=b.id,
                blocker_id=b.blocker_id,
                blocked_id=b.blocked_id,
                blocked_display_name=p.display_name if p else "Player",
                created_at=b.created_at,
            )
        )
    return res

@router.delete("/{blocked_user_id}")
async def unblock_user(
    blocked_user_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = await db.execute(
        select(Block).where(Block.blocker_id == current_user.id, Block.blocked_id == blocked_user_id)
    )
    block = q.scalar_one_or_none()
    if not block:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Block record not found.")

    await db.delete(block)
    await db.commit()
    return {"message": "User unblocked."}
