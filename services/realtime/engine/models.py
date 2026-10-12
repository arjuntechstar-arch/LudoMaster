from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional

class TokenLocation(str, Enum):
    YARD = "YARD"
    TRACK = "TRACK"
    HOME_LANE = "HOME_LANE"
    HOME = "HOME"

class Color(str, Enum):
    RED = "RED"
    GREEN = "GREEN"
    YELLOW = "YELLOW"
    BLUE = "BLUE"
    ORANGE = "ORANGE"
    PURPLE = "PURPLE"

class TurnPhase(str, Enum):
    WAITING = "WAITING"
    ROLL_REQUIRED = "ROLL_REQUIRED"
    MOVE_REQUIRED = "MOVE_REQUIRED"
    RESOLVING = "RESOLVING"
    FINISHED = "FINISHED"

@dataclass
class Token:
    id: int
    seat_index: int
    color: Color
    location: TokenLocation = TokenLocation.YARD
    position: int = -1  # -1 in yard/home, 0..51 on track, 0..4 in home lane
    steps_taken: int = 0  # 0..56 (56 = home)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "seatIndex": self.seat_index,
            "color": self.color.value,
            "location": self.location.value,
            "position": self.position,
            "stepsTaken": self.steps_taken,
        }

@dataclass
class Seat:
    seat_index: int
    user_id: Optional[str]
    display_name: str
    avatar_id: str
    color: Color
    is_connected: bool = True
    is_bot: bool = False
    has_finished: bool = False
    placement: Optional[int] = None
    team_id: Optional[int] = None
    has_captured: bool = False
    tokens: List[Token] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "seatIndex": self.seat_index,
            "userId": self.user_id,
            "displayName": self.display_name,
            "avatarId": self.avatar_id,
            "color": self.color.value,
            "isConnected": self.is_connected,
            "isBot": self.is_bot,
            "hasFinished": self.has_finished,
            "placement": self.placement,
            "teamId": self.team_id,
            "hasCaptured": self.has_captured,
            "tokens": [t.to_dict() for t in self.tokens],
        }

@dataclass
class LegalMove:
    token_id: int
    from_location: TokenLocation
    from_position: int
    to_location: TokenLocation
    to_position: int
    steps_to_take: int
    is_capture: bool = False
    is_home_finish: bool = False

    def to_dict(self) -> dict:
        return {
            "tokenId": self.token_id,
            "fromLocation": self.from_location.value,
            "fromPosition": self.from_position,
            "toLocation": self.to_location.value,
            "toPosition": self.to_position,
            "stepsToTake": self.steps_to_take,
            "isCapture": self.is_capture,
            "isHomeFinish": self.is_home_finish,
        }
