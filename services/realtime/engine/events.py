from datetime import datetime, timezone
from enum import Enum
from typing import Any, Dict

class RealtimeEventType(str, Enum):
    CONNECTED = "CONNECTED"
    AUTHENTICATED = "AUTHENTICATED"
    ROOM_STATE = "ROOM_STATE"
    PLAYER_JOINED = "PLAYER_JOINED"
    PLAYER_LEFT = "PLAYER_LEFT"
    READY_CHANGED = "READY_CHANGED"
    MATCH_STARTED = "MATCH_STARTED"
    TURN_STARTED = "TURN_STARTED"
    DICE_ROLLED = "DICE_ROLLED"
    LEGAL_MOVES = "LEGAL_MOVES"
    MOVE_APPLIED = "MOVE_APPLIED"
    TOKEN_CAPTURED = "TOKEN_CAPTURED"
    TOKEN_HOME = "TOKEN_HOME"
    BONUS_TURN = "BONUS_TURN"
    TURN_TIMEOUT = "TURN_TIMEOUT"
    PLAYER_DISCONNECTED = "PLAYER_DISCONNECTED"
    PLAYER_RECONNECTED = "PLAYER_RECONNECTED"
    PLAYER_FORFEITED = "PLAYER_FORFEITED"
    STATE_SNAPSHOT = "STATE_SNAPSHOT"
    MATCH_FINISHED = "MATCH_FINISHED"
    CHAT_MESSAGE = "CHAT_MESSAGE"
    EMOJI_SENT = "EMOJI_SENT"
    ERROR = "ERROR"

def create_event_envelope(
    event_type: RealtimeEventType | str,
    match_id: str,
    sequence: int,
    payload: Dict[str, Any],
) -> Dict[str, Any]:
    """Generates canonical realtime event envelope conforming to packages/contracts/realtime_events.json."""
    event_str = event_type.value if isinstance(event_type, RealtimeEventType) else str(event_type)
    return {
        "event": event_str,
        "version": 1,
        "matchId": match_id,
        "sequence": sequence,
        "serverTime": datetime.now(timezone.utc).isoformat(),
        "payload": payload,
    }
