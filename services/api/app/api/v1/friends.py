from datetime import datetime, timezone
from typing import Dict, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.profile import Profile
from app.models.social import Block, Friendship
from app.models.user import User
from app.schemas.social import FriendItem, FriendRequestCreate, FriendshipResponse

router = APIRouter(prefix="/friends", tags=["Friends & Social"])

@router.post("/request", response_model=FriendshipResponse, status_code=status.HTTP_201_CREATED)
async def send_friend_request(
    payload: FriendRequestCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    target_user_id = payload.target_user_id

    if not target_user_id and payload.username:
        name = payload.username.strip().removeprefix("@").lower()
        target_profile = await db.scalar(select(Profile).where(Profile.username == name))
        if not target_profile:
            raise HTTPException(status_code=404, detail="Username not found.")
        target_user_id = target_profile.user_id

    # Legacy IDs are retained internally for older releases.
    if not target_user_id and payload.player_id:
        p_q = await db.execute(select(Profile).where(Profile.player_id == payload.player_id.strip().upper()))
        target_profile = p_q.scalar_one_or_none()
        if not target_profile:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Player ID not found.")
        target_user_id = target_profile.user_id

    if not target_user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Enter a username.")

    if target_user_id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot send friend request to yourself.")

    # Check if blocked
    block_q = await db.execute(
        select(Block).where(
            or_(
                (Block.blocker_id == current_user.id) & (Block.blocked_id == target_user_id),
                (Block.blocker_id == target_user_id) & (Block.blocked_id == current_user.id),
            )
        )
    )
    if block_q.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot connect with this user.")

    # Check existing friendship or request
    existing_q = await db.execute(
        select(Friendship).where(
            or_(
                (Friendship.user_id == current_user.id) & (Friendship.friend_user_id == target_user_id),
                (Friendship.user_id == target_user_id) & (Friendship.friend_user_id == current_user.id),
            )
        )
    )
    existing = existing_q.scalar_one_or_none()
    if existing:
        if existing.status == "ACCEPTED":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Already friends.")
        elif existing.status == "PENDING":
            if existing.user_id == current_user.id:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Friend request already pending.")
            else:
                # Other user already sent request -> automatically accept!
                existing.status = "ACCEPTED"
                await db.commit()
                await db.refresh(existing)
                return FriendshipResponse(
                    id=existing.id,
                    user_id=existing.user_id,
                    friend_user_id=existing.friend_user_id,
                    status=existing.status,
                    created_at=existing.created_at,
                )

    friendship = Friendship(
        user_id=current_user.id,
        friend_user_id=target_user_id,
        status="PENDING",
    )
    db.add(friendship)
    await db.commit()
    await db.refresh(friendship)

    return FriendshipResponse(
        id=friendship.id,
        user_id=friendship.user_id,
        friend_user_id=friendship.friend_user_id,
        status=friendship.status,
        created_at=friendship.created_at,
    )

@router.get("/requests")
async def get_friend_requests(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Incoming
    inc_q = await db.execute(
        select(Friendship)
        .options(selectinload(Friendship.requester).selectinload(User.profile))
        .where(
            Friendship.friend_user_id == current_user.id,
            Friendship.status == "PENDING",
        )
    )
    incoming = []
    for f in inc_q.scalars().all():
        p = f.requester.profile if f.requester else None
        incoming.append({
            "id": f.id,
            "user_id": f.user_id,
            "display_name": p.display_name if p else "Player",
            "avatar_id": p.avatar_id if p else "avatar_0",
            "username": p.username if p else None,
            "player_id": p.player_id if p else "LM-00000",
            "created_at": f.created_at,
        })

    # Outgoing
    out_q = await db.execute(
        select(Friendship)
        .options(selectinload(Friendship.addressee).selectinload(User.profile))
        .where(
            Friendship.user_id == current_user.id,
            Friendship.status == "PENDING",
        )
    )
    outgoing = []
    for f in out_q.scalars().all():
        p = f.addressee.profile if f.addressee else None
        outgoing.append({
            "id": f.id,
            "friend_user_id": f.friend_user_id,
            "display_name": p.display_name if p else "Player",
            "avatar_id": p.avatar_id if p else "avatar_0",
            "username": p.username if p else None,
            "player_id": p.player_id if p else "LM-00000",
            "created_at": f.created_at,
        })

    return {"incoming": incoming, "outgoing": outgoing}

@router.post("/requests/{request_id}/accept", response_model=FriendshipResponse)
async def accept_friend_request(
    request_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = await db.execute(
        select(Friendship).where(
            Friendship.id == request_id,
            Friendship.friend_user_id == current_user.id,
            Friendship.status == "PENDING",
        )
    )
    f = q.scalar_one_or_none()
    if not f:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Friend request not found.")

    f.status = "ACCEPTED"
    await db.commit()
    await db.refresh(f)
    return FriendshipResponse(
        id=f.id,
        user_id=f.user_id,
        friend_user_id=f.friend_user_id,
        status=f.status,
        created_at=f.created_at,
    )

@router.post("/requests/{request_id}/decline")
async def decline_friend_request(
    request_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = await db.execute(
        select(Friendship).where(
            Friendship.id == request_id,
            Friendship.friend_user_id == current_user.id,
            Friendship.status == "PENDING",
        )
    )
    f = q.scalar_one_or_none()
    if not f:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Friend request not found.")

    f.status = "DECLINED"
    await db.commit()
    return {"message": "Friend request declined."}

@router.get("", response_model=List[FriendItem])
async def list_friends(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = await db.execute(
        select(Friendship).where(
            or_(
                Friendship.user_id == current_user.id,
                Friendship.friend_user_id == current_user.id,
            ),
            Friendship.status == "ACCEPTED",
        )
    )
    friendships = q.scalars().all()
    friend_user_ids = []
    for f in friendships:
        fid = f.friend_user_id if f.user_id == current_user.id else f.user_id
        friend_user_ids.append(fid)

    if not friend_user_ids:
        return []

    profiles_q = await db.execute(
        select(Profile).where(Profile.user_id.in_(friend_user_ids))
    )
    profiles = profiles_q.scalars().all()

    items = []
    for p in profiles:
        items.append(
            FriendItem(
                user_id=p.user_id,
                player_id=p.player_id,
                username=p.username,
                display_name=p.display_name,
                avatar_id=p.avatar_id,
                level=p.level,
                country_code=p.country_code,
                is_online=True,
            )
        )
    return items

@router.delete("/{friend_user_id}")
async def remove_friend(
    friend_user_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = await db.execute(
        select(Friendship).where(
            or_(
                (Friendship.user_id == current_user.id) & (Friendship.friend_user_id == friend_user_id),
                (Friendship.user_id == friend_user_id) & (Friendship.friend_user_id == current_user.id),
            )
        )
    )
    f = q.scalar_one_or_none()
    if not f:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Friendship not found.")

    await db.delete(f)
    await db.commit()
    return {"message": "Friend removed."}
