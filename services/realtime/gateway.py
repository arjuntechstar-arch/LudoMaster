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

@router.websocket("/ws/match/{match_id}")
async def match_websocket_endpoint(
    websocket: WebSocket,
    match_id: str,
    token: str = Query(...),
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

    await session.handle_connect(user_id, websocket)

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
                if not await _can_play(user_id, match_id):
                    await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
                    return
                last_seq = data.get("lastReceivedSequence")
                await session.handle_connect(user_id, websocket, last_received_seq=last_seq)
            elif action == "CHAT":
                await session.handle_chat(user_id, str(data.get("message", "")))
            elif action == "EMOJI":
                await session.handle_emoji(user_id, str(data.get("emojiId", "")))
    except WebSocketDisconnect:
        await session.handle_disconnect(user_id)
    except Exception:
        await session.handle_disconnect(user_id)
