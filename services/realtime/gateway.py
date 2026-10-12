from typing import Optional
from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status
from app.core.security import decode_access_token
from app.db.session import async_session_maker
from app.models.user import User
from app.models.match import MatchPlayer
from sqlalchemy import select
from services.realtime.engine.events import RealtimeEventType, create_event_envelope
from services.realtime.session_manager import session_manager

router = APIRouter(tags=["Realtime WebSocket"])


async def _can_play(user_id: str, match_id: str) -> bool:
    async with async_session_maker() as db:
        player = await db.execute(select(User.id).join(
            MatchPlayer, MatchPlayer.user_id == User.id
        ).where(User.id == user_id, User.status == "ACTIVE", MatchPlayer.match_id == match_id))
        return player.scalar_one_or_none() is not None


def _is_current_socket(session, user_id: str, websocket: WebSocket) -> bool:
    """Return True only when this socket is still the active socket for the user.

    A reconnect replaces the seat's socket in ``session.connections``. The old
    socket can close a moment later; without this identity check that stale
    disconnect would remove the newly connected socket and mark the player
    offline again.
    """
    seat_idx = session.user_to_seat.get(user_id)
    return seat_idx is not None and session.connections.get(seat_idx) is websocket


@router.websocket("/ws/match/{match_id}")
async def match_websocket_endpoint(
    websocket: WebSocket,
    match_id: str,
    token: str = Query(...),
    last_received_sequence: Optional[int] = Query(None, alias="lastReceivedSequence"),
):
    user_id = decode_access_token(token)
    if not user_id or not await _can_play(user_id, match_id):
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await websocket.accept()

    session = session_manager.get_session(match_id)
    if not session:
        async with async_session_maker() as db:
            try:
                session = await session_manager.get_or_create_session(match_id, db)
            except Exception as e:
                await websocket.send_json(
                    create_event_envelope(
                        RealtimeEventType.ERROR,
                        match_id,
                        0,
                        {"code": "MATCH_NOT_FOUND", "message": str(e)},
                    )
                )
                await websocket.close()
                return

    # Keep a reference to a superseded socket so it can be closed after the
    # new socket is registered. Its eventual disconnect is ignored by the
    # identity guard in the exception handlers below.
    existing_seat_idx = session.user_to_seat.get(user_id)
    previous_websocket = (
        session.connections.get(existing_seat_idx)
        if existing_seat_idx is not None
        else None
    )

    await session.handle_connect(
        user_id,
        websocket,
        last_received_seq=last_received_sequence,
    )

    if previous_websocket is not None and previous_websocket is not websocket:
        try:
            await previous_websocket.close(code=1000, reason="Replaced by newer connection")
        except Exception:
            pass

    try:
        while True:
            data = await websocket.receive_json()
            action = data.get("type") or data.get("action") or data.get("event")

            if action == "PING":
                await websocket.send_json({"type": "PONG"})
            elif action == "ROLL_REQUEST":
                await session.handle_roll_request(user_id)
            elif action == "MOVE_REQUEST":
                token_id = data.get("tokenId")
                if token_id is not None:
                    await session.handle_move_request(user_id, int(token_id))
            elif action == "RECONNECT":
                # Backward compatibility for older clients. New clients pass
                # lastReceivedSequence in the WebSocket URL so catch-up happens
                # during the initial connect, before the canonical snapshot.
                if not await _can_play(user_id, match_id):
                    await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
                    return

                # Never let a superseded socket reclaim the seat. For the
                # currently active legacy socket, a fresh canonical snapshot is
                # sufficient and avoids replaying stale events after a snapshot.
                if not _is_current_socket(session, user_id, websocket):
                    await websocket.close(code=1000, reason="Superseded connection")
                    return

                seat_idx = session.user_to_seat.get(user_id)
                if seat_idx is not None:
                    await session.send_to_seat(
                        seat_idx,
                        create_event_envelope(
                            RealtimeEventType.STATE_SNAPSHOT,
                            match_id,
                            session.sequence,
                            session.engine.to_snapshot(),
                        ),
                    )
            elif action == "CHAT":
                await session.handle_chat(user_id, str(data.get("message", "")))
            elif action == "EMOJI":
                await session.handle_emoji(user_id, str(data.get("emojiId", "")))
    except WebSocketDisconnect:
        if _is_current_socket(session, user_id, websocket):
            await session.handle_disconnect(user_id)
    except Exception:
        if _is_current_socket(session, user_id, websocket):
            await session.handle_disconnect(user_id)
