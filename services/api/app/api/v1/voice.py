import time
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.room import Room, RoomMember
from app.models.social import Report
from app.models.user import User
from app.schemas.club import (
    VoiceMuteRequest,
    VoiceReportRequest,
    VoiceTokenRequest,
    VoiceTokenResponse,
)

router = APIRouter(prefix="/rooms", tags=["Voice Chat & Safety"])

@router.post("/{room_id}/voice/token", response_model=VoiceTokenResponse)
async def generate_voice_token(
    room_id: str,
    payload: VoiceTokenRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Verify user is member of room
    stmt = select(RoomMember).where(RoomMember.room_id == room_id, RoomMember.user_id == current_user.id)
    res = await db.execute(stmt)
    if not res.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You must be an active member of this room to connect to voice chat.",
        )

    voice_session_id = f"voice_session_{room_id}"
    ephemeral_token = f"vt_{uuid.uuid4().hex}_{int(time.time())}"

    return VoiceTokenResponse(
        room_id=room_id,
        user_id=current_user.id,
        voice_session_id=voice_session_id,
        token=ephemeral_token,
        mic_enabled=payload.enable_mic and payload.privacy_consent,
    )

@router.post("/{room_id}/voice/mute")
async def set_voice_mute(
    room_id: str,
    payload: VoiceMuteRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(RoomMember).where(RoomMember.room_id == room_id, RoomMember.user_id == current_user.id)
    res = await db.execute(stmt)
    if not res.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not in this room.")

    target = payload.target_user_id or current_user.id
    return {
        "room_id": room_id,
        "target_user_id": target,
        "is_muted": payload.is_muted,
        "status": "MUTED" if payload.is_muted else "UNMUTED",
    }

@router.post("/{room_id}/voice/report")
async def report_voice_chat(
    room_id: str,
    payload: VoiceReportRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(RoomMember).where(RoomMember.room_id == room_id, RoomMember.user_id == current_user.id)
    res = await db.execute(stmt)
    if not res.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not in this room.")

    report = Report(
        reporter_id=current_user.id,
        reported_user_id=payload.reported_user_id,
        category="VOICE_HARASSMENT",
        description=f"Voice abuse in room {room_id}: {payload.reason} ({payload.details or ''})",
        status="OPEN",
    )
    db.add(report)
    await db.commit()

    return {
        "status": "REPORTED",
        "message": "Voice abuse report submitted for automated moderation review.",
        "report_id": report.id,
    }
