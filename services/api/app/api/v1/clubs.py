from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.club import Club, ClubMember
from app.models.profile import Profile
from app.models.user import User
from app.schemas.club import (
    ClubDetailResponse,
    ClubMemberResponse,
    ClubResponse,
    CreateClubRequest,
)

router = APIRouter(prefix="/clubs", tags=["Clubs & Social Rooms"])

def _map_club_response(club: Club) -> ClubResponse:
    return ClubResponse(
        id=club.id,
        name=club.name,
        tag=club.tag,
        description=club.description,
        badge_icon=club.badge_icon,
        leader_user_id=club.leader_user_id,
        min_level=club.min_level,
        is_open=club.is_open,
        member_count=club.member_count,
        max_members=club.max_members,
        created_at=club.created_at,
    )

@router.post("", response_model=ClubResponse, status_code=status.HTTP_201_CREATED)
async def create_club(
    payload: CreateClubRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Check if user is already in a club
    stmt_member = select(ClubMember).where(ClubMember.user_id == current_user.id)
    res_member = await db.execute(stmt_member)
    if res_member.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are already a member of a club. Leave your current club first.",
        )

    # Check unique name & tag
    clean_name = payload.name.strip()
    clean_tag = payload.tag.strip().upper()

    stmt_exists = select(Club).where((Club.name == clean_name) | (Club.tag == clean_tag))
    res_exists = await db.execute(stmt_exists)
    if res_exists.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A club with this name or tag already exists.",
        )

    club = Club(
        name=clean_name,
        tag=clean_tag,
        description=payload.description.strip(),
        badge_icon=payload.badge_icon,
        leader_user_id=current_user.id,
        min_level=payload.min_level,
        is_open=payload.is_open,
        member_count=1,
    )
    db.add(club)
    await db.flush()

    leader_member = ClubMember(
        club_id=club.id,
        user_id=current_user.id,
        role="LEADER",
    )
    db.add(leader_member)
    await db.commit()
    await db.refresh(club)

    return _map_club_response(club)

@router.get("", response_model=List[ClubResponse])
async def list_clubs(
    query: Optional[str] = Query(default=None),
    limit: int = Query(default=20, le=50),
    offset: int = Query(default=0, ge=0),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Club).order_by(Club.member_count.desc()).limit(limit).offset(offset)
    if query:
        clean_q = f"%{query.strip()}%"
        stmt = stmt.where((Club.name.ilike(clean_q)) | (Club.tag.ilike(clean_q)))

    res = await db.execute(stmt)
    clubs = res.scalars().all()
    return [_map_club_response(c) for c in clubs]

@router.get("/my-club", response_model=Optional[ClubDetailResponse])
async def get_my_club(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(ClubMember).where(ClubMember.user_id == current_user.id)
    res = await db.execute(stmt)
    membership = res.scalar_one_or_none()
    if not membership:
        return None

    return await get_club_details(membership.club_id, db=db)

@router.get("/{club_id}", response_model=ClubDetailResponse)
async def get_club_details(
    club_id: str,
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Club).where(Club.id == club_id)
    res = await db.execute(stmt)
    club = res.scalar_one_or_none()
    if not club:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Club not found.")

    stmt_members = select(ClubMember).where(ClubMember.club_id == club_id).order_by(ClubMember.joined_at.asc())
    res_members = await db.execute(stmt_members)
    club_members = res_members.scalars().all()

    members_resp = []
    for m in club_members:
        prof = m.user.profile if m.user and m.user.profile else None
        members_resp.append(
            ClubMemberResponse(
                id=m.id,
                user_id=m.user_id,
                role=m.role,
                joined_at=m.joined_at,
                display_name=prof.display_name if prof else "Player",
                avatar_id=prof.avatar_id if prof else "avatar_0",
                level=prof.level if prof else 1,
            )
        )

    base_resp = _map_club_response(club)
    return ClubDetailResponse(
        **base_resp.model_dump(),
        members=members_resp,
    )

@router.post("/{club_id}/join", response_model=ClubDetailResponse)
async def join_club(
    club_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt_member = select(ClubMember).where(ClubMember.user_id == current_user.id)
    res_member = await db.execute(stmt_member)
    if res_member.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are already in a club. Leave your current club before joining another.",
        )

    stmt_club = select(Club).where(Club.id == club_id)
    res_club = await db.execute(stmt_club)
    club = res_club.scalar_one_or_none()
    if not club:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Club not found.")

    if not club.is_open:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="This club is invite-only.")

    user_level = current_user.profile.level if current_user.profile else 1
    if user_level < club.min_level:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Minimum level required to join this club is Level {club.min_level}.",
        )

    if club.member_count >= club.max_members:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Club is currently full.")

    new_member = ClubMember(
        club_id=club.id,
        user_id=current_user.id,
        role="MEMBER",
    )
    db.add(new_member)
    club.member_count += 1
    await db.commit()

    return await get_club_details(club_id, db=db)

@router.post("/{club_id}/leave")
async def leave_club(
    club_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt_member = select(ClubMember).where(
        ClubMember.club_id == club_id, ClubMember.user_id == current_user.id
    )
    res_member = await db.execute(stmt_member)
    member = res_member.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You are not a member of this club.")

    stmt_club = select(Club).where(Club.id == club_id)
    res_club = await db.execute(stmt_club)
    club = res_club.scalar_one_or_none()

    if member.role == "LEADER" and club and club.member_count > 1:
        # Transfer leadership to next longest-standing member
        stmt_next = select(ClubMember).where(ClubMember.club_id == club_id, ClubMember.user_id != current_user.id).order_by(ClubMember.joined_at.asc())
        res_next = await db.execute(stmt_next)
        next_leader = res_next.scalars().first()
        if next_leader:
            next_leader.role = "LEADER"
            club.leader_user_id = next_leader.user_id

    if club and club.member_count <= 1:
        await db.delete(club)
    else:
        await db.delete(member)
        if club:
            club.member_count = max(0, club.member_count - 1)

    await db.commit()
    return {"message": "Successfully left the club.", "status": "LEFT"}
