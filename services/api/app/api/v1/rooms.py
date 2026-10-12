import secrets
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.match import Match, MatchPlayer
from app.models.room import Room, RoomMember
from app.models.social import Block, RoomInvite
from app.models.user import User
from app.services.notification_service import notification_service
from app.schemas.room import (
    CreateRoomRequest,
    JoinRoomRequest,
    RoomMemberResponse,
    RoomResponse,
    ToggleReadyRequest,
)
from app.schemas.social import RoomInviteCreate, RoomInviteResponse

router = APIRouter(prefix="/rooms", tags=["Rooms"])

def generate_room_code() -> str:
    chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return "".join(secrets.choice(chars) for _ in range(6))

async def fetch_room_by_id(db: AsyncSession, room_id: str) -> Optional[Room]:
    stmt = (
        select(Room)
        .options(
            selectinload(Room.members).selectinload(RoomMember.user).selectinload(User.profile)
        )
        .where(Room.id == room_id)
        .execution_options(populate_existing=True)
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()

async def fetch_room_by_code(db: AsyncSession, code: str) -> Optional[Room]:
    stmt = (
        select(Room)
        .options(
            selectinload(Room.members).selectinload(RoomMember.user).selectinload(User.profile)
        )
        .where(Room.code == code, Room.status == "WAITING")
        .execution_options(populate_existing=True)
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()

def map_member_response(m: RoomMember) -> RoomMemberResponse:
    profile = m.user.profile if m.user else None
    return RoomMemberResponse(
        id=m.id,
        user_id=m.user_id,
        seat_index=m.seat_index,
        is_ready=m.is_ready,
        is_host=m.is_host,
        display_name=profile.display_name if profile else f"Player_{m.seat_index + 1}",
        avatar_id=profile.avatar_id if profile else "avatar_0",
        level=profile.level if profile else 1,
        joined_at=m.joined_at,
    )

def map_room_response(room: Room, match_id: Optional[str] = None) -> RoomResponse:
    sorted_members = sorted(room.members, key=lambda x: x.seat_index)
    return RoomResponse(
        id=room.id,
        code=room.code,
        host_user_id=room.host_user_id,
        mode=room.mode,
        max_players=room.max_players,
        fill_with_bots=room.fill_with_bots,
        status=room.status,
        bet_coins=room.bet_coins,
        members=[map_member_response(m) for m in sorted_members],
        match_id=match_id,
        created_at=room.created_at,
    )

@router.post("", response_model=RoomResponse, status_code=status.HTTP_201_CREATED)
async def create_room(
    payload: CreateRoomRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if payload.mode == "TEAM" and payload.max_players != 4:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Team rooms require exactly four player seats.",
        )

    for _ in range(10):
        code = generate_room_code()
        existing = await db.execute(select(Room).where(Room.code == code, Room.status == "WAITING"))
        if not existing.scalar_one_or_none():
            break
    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate unique room code.",
        )

    room = Room(
        code=code,
        host_user_id=current_user.id,
        mode=payload.mode,
        max_players=payload.max_players,
        fill_with_bots=payload.fill_with_bots,
        bet_coins=payload.bet_coins,
        status="WAITING",
    )
    db.add(room)
    await db.flush()
    room_id = room.id

    host_member = RoomMember(
        room_id=room_id,
        user_id=current_user.id,
        seat_index=0,
        is_ready=True,
        is_host=True,
    )
    db.add(host_member)
    await db.commit()

    loaded_room = await fetch_room_by_id(db, room_id)
    return map_room_response(loaded_room)

@router.post("/join", response_model=RoomResponse)
async def join_room_by_code(
    payload: JoinRoomRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    code = payload.code.strip().upper()
    room = await fetch_room_by_code(db, code)

    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found or no longer waiting.")

    room_id = room.id

    # Check if already joined
    for m in room.members:
        if m.user_id == current_user.id:
            return map_room_response(room)

    # Check capacity
    if len(room.members) >= room.max_players:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Room is full.")

    # Find first available seat
    occupied_seats = {m.seat_index for m in room.members}
    available_seat = None
    for s in range(room.max_players):
        if s not in occupied_seats:
            available_seat = s
            break

    if available_seat is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No available seats in room.")

    new_member = RoomMember(
        room_id=room_id,
        user_id=current_user.id,
        seat_index=available_seat,
        is_ready=False,
        is_host=False,
    )
    db.add(new_member)
    await db.commit()

    loaded_room = await fetch_room_by_id(db, room_id)
    return map_room_response(loaded_room)

@router.get("/invites/my-invites", response_model=List[RoomInviteResponse])
async def get_my_invites(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = await db.execute(
        select(RoomInvite)
        .options(
            selectinload(RoomInvite.sender).selectinload(User.profile)
        )
        .where(
            RoomInvite.recipient_id == current_user.id,
            RoomInvite.status == "PENDING",
        )
        .order_by(RoomInvite.created_at.desc())
    )
    invites = q.scalars().all()
    results = []
    for inv in invites:
        room_q = await db.execute(select(Room).where(Room.id == inv.room_id))
        room = room_q.scalar_one_or_none()
        if room and room.status == "WAITING":
            sp = inv.sender.profile if inv.sender else None
            results.append(
                RoomInviteResponse(
                    id=inv.id,
                    room_id=inv.room_id,
                    room_code=room.code,
                    sender_id=inv.sender_id,
                    sender_name=sp.display_name if sp else "Friend",
                    recipient_id=inv.recipient_id,
                    status=inv.status,
                    created_at=inv.created_at,
                )
            )
    return results

@router.post("/invites/{invite_id}/respond")
async def respond_to_invite(
    invite_id: str,
    accept: bool = True,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = await db.execute(
        select(RoomInvite).where(
            RoomInvite.id == invite_id,
            RoomInvite.recipient_id == current_user.id,
            RoomInvite.status == "PENDING",
        )
    )
    invite = q.scalar_one_or_none()
    if not invite:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invite not found.")

    room = await fetch_room_by_id(db, invite.room_id)
    if not room:
        invite.status = "EXPIRED"
        await db.commit()
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room no longer exists.")

    if accept:
        if room.status != "WAITING":
            invite.status = "EXPIRED"
            await db.commit()
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This room has already started.")

        member = next((m for m in room.members if m.user_id == current_user.id), None)
        if member is None:
            if len(room.members) >= room.max_players:
                invite.status = "EXPIRED"
                await db.commit()
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This room is full.")

            occupied_seats = {m.seat_index for m in room.members}
            seat_index = next(
                (seat for seat in range(room.max_players) if seat not in occupied_seats),
                None,
            )
            if seat_index is None:
                invite.status = "EXPIRED"
                await db.commit()
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This room has no open seats.")

            db.add(
                RoomMember(
                    room_id=room.id,
                    user_id=current_user.id,
                    seat_index=seat_index,
                    is_ready=False,
                    is_host=False,
                )
            )

        invite.status = "ACCEPTED"
    else:
        invite.status = "DECLINED"

    await db.commit()
    return {
        "message": f"Invite {'accepted' if accept else 'declined'}.",
        "room_id": room.id if accept else None,
        "room_code": room.code if accept else None,
    }

@router.get("/{room_id}", response_model=RoomResponse)
async def get_room(
    room_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    room = await fetch_room_by_id(db, room_id)
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found.")

    match_id = None
    if room.status == "ACTIVE":
        match_q = await db.execute(
            select(Match.id)
            .where(Match.room_id == room.id)
            .order_by(Match.started_at.desc())
            .limit(1)
        )
        match_id = match_q.scalar_one_or_none()

    return map_room_response(room, match_id=match_id)

@router.post("/{room_id}/ready", response_model=RoomResponse)
async def toggle_ready(
    room_id: str,
    payload: ToggleReadyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    room = await fetch_room_by_id(db, room_id)
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found.")

    member = next((m for m in room.members if m.user_id == current_user.id), None)
    if not member:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not a member of this room.")

    member.is_ready = payload.is_ready
    await db.commit()

    loaded_room = await fetch_room_by_id(db, room_id)
    return map_room_response(loaded_room)

@router.post("/{room_id}/leave")
async def leave_room(
    room_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    room = await fetch_room_by_id(db, room_id)
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found.")

    member = next((m for m in room.members if m.user_id == current_user.id), None)
    if not member:
        return {"message": "Not in room"}

    was_host = member.is_host
    await db.delete(member)
    await db.flush()

    remaining_members = [m for m in room.members if m.id != member.id]
    if not remaining_members:
        room.status = "ABANDONED"
    elif was_host:
        new_host = min(remaining_members, key=lambda m: m.joined_at)
        new_host.is_host = True
        new_host.is_ready = True
        room.host_user_id = new_host.user_id

    await db.commit()
    return {"message": "Left room successfully"}

@router.post("/{room_id}/start", response_model=RoomResponse)
async def start_room_match(
    room_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    room = await fetch_room_by_id(db, room_id)
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found.")

    if room.host_user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only host can start the match.")

    if room.status == "ACTIVE":
        match_q = await db.execute(
            select(Match.id)
            .where(Match.room_id == room.id)
            .order_by(Match.started_at.desc())
            .limit(1)
        )
        match_id = match_q.scalar_one_or_none()
        if match_id:
            return map_room_response(room, match_id=match_id)

    if room.status != "WAITING":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Room is not in WAITING state.")

    if len(room.members) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least two players must join before starting.",
        )
    if any(not member.is_ready for member in room.members):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Wait until every player is ready before starting.",
        )

    if not room.fill_with_bots and len(room.members) < room.max_players:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Waiting for all {room.max_players} player seats to fill.",
        )

    seat_colors = (
        ["RED", "YELLOW"]
        if room.max_players == 2
        else ["RED", "GREEN", "YELLOW", "BLUE", "ORANGE", "PURPLE"]
    )

    match = Match(
        room_id=room.id,
        mode=room.mode,
        status="ACTIVE",
        ruleset_version=1,
    )
    db.add(match)
    await db.flush()
    match_id = match.id

    for m in room.members:
        mp = MatchPlayer(
            match_id=match_id,
            user_id=m.user_id,
            seat_index=m.seat_index,
            color=seat_colors[m.seat_index % len(seat_colors)],
            is_bot=False,
        )
        db.add(mp)

    occupied_seats = {m.seat_index for m in room.members}
    for seat in range(room.max_players):
        if room.fill_with_bots and seat not in occupied_seats:
            bot_player = MatchPlayer(
                match_id=match_id,
                user_id=None,
                seat_index=seat,
                color=seat_colors[seat % len(seat_colors)],
                is_bot=True,
            )
            db.add(bot_player)

    room.status = "ACTIVE"
    await db.commit()

    loaded_room = await fetch_room_by_id(db, room_id)
    return map_room_response(loaded_room, match_id=match_id)

@router.post("/{room_id}/invite", response_model=RoomInviteResponse, status_code=status.HTTP_201_CREATED)
async def invite_to_room(
    room_id: str,
    payload: RoomInviteCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    room = await fetch_room_by_id(db, room_id)
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found.")
    if room.status != "WAITING":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Room is not in waiting state.")

    if not any(member.user_id == current_user.id for member in room.members):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Join the room before inviting players.")
    if any(member.user_id == payload.recipient_id for member in room.members):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="This player is already in the room.")
    if len(room.members) >= room.max_players:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Room is full.")

    # Check if recipient is blocked
    b_q = await db.execute(
        select(Block).where(
            or_(
                (Block.blocker_id == current_user.id) & (Block.blocked_id == payload.recipient_id),
                (Block.blocker_id == payload.recipient_id) & (Block.blocked_id == current_user.id),
            )
        )
    )
    if b_q.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot invite this user.")

    invite = RoomInvite(
        room_id=room.id,
        sender_id=current_user.id,
        recipient_id=payload.recipient_id,
        status="PENDING",
    )
    db.add(invite)
    await db.commit()
    await db.refresh(invite)

    profile = current_user.profile
    sender_name = profile.display_name if profile else "Friend"
    await notification_service.send_notification(
        db,
        user_id=payload.recipient_id,
        title="Ludo room invitation",
        body=f"{sender_name} invited you to join a game.",
        category="INVITE",
        data_payload={
            "type": "ROOM_INVITE",
            "invite_id": invite.id,
            "room_id": room.id,
            "room_code": room.code,
        },
    )

    return RoomInviteResponse(
        id=invite.id,
        room_id=room.id,
        room_code=room.code,
        sender_id=current_user.id,
        sender_name=sender_name,
        recipient_id=payload.recipient_id,
        status=invite.status,
        created_at=invite.created_at,
    )
