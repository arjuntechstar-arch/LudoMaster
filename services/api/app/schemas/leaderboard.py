from typing import List, Optional
from pydantic import BaseModel

class LeaderboardEntryResponse(BaseModel):
    rank: int
    user_id: str
    player_id: str
    display_name: str
    avatar_id: str
    country_code: str
    level: int
    score: int          # Rating / MMR / Seasonal XP
    matches_played: int
    matches_won: int
    win_rate: float

class LeaderboardResponse(BaseModel):
    scope: str  # ALL_TIME, WEEKLY, SEASONAL
    total_players: int
    entries: List[LeaderboardEntryResponse] = []

class MyLeaderboardRankResponse(BaseModel):
    scope: str
    rank: int
    score: int
    matches_played: int
    matches_won: int
