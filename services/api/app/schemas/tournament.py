from typing import List, Optional
from pydantic import BaseModel

class TournamentParticipantResponse(BaseModel):
    id: str
    user_id: str
    display_name: str
    avatar_id: str
    seed: int
    placement: Optional[int] = None
    prize_coins: int = 0
    prize_gems: int = 0
    eliminated_round: Optional[int] = None

class TournamentMatchResponse(BaseModel):
    id: str
    round_number: int
    match_index: int
    status: str
    match_id: Optional[str] = None
    participant_ids: List[str] = []
    winner_ids: List[str] = []

class TournamentResponse(BaseModel):
    id: str
    title: str
    description: str
    entry_fee_coins: int
    prize_pool_coins: int
    prize_pool_gems: int
    max_participants: int
    current_participants: int
    status: str
    winner_user_id: Optional[str] = None
    is_joined: bool = False

class TournamentDetailResponse(BaseModel):
    tournament: TournamentResponse
    participants: List[TournamentParticipantResponse] = []
    matches: List[TournamentMatchResponse] = []

class TournamentJoinResponse(BaseModel):
    message: str
    tournament_id: str
    current_participants: int
    status: str
    seed: int
