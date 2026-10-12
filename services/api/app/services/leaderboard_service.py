from datetime import datetime, timedelta, timezone
from sqlalchemy import case, desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.profile import Profile, PlayerStats
from app.models.season import UserSeasonProgress, Season
from app.models.user import User
from app.models.match import Match, MatchPlayer
from app.services.season_service import SeasonService

class LeaderboardService:
    @staticmethod
    async def get_leaderboard(
        db: AsyncSession,
        scope: str = "ALL_TIME",
        limit: int = 50,
        offset: int = 0,
    ) -> dict:
        scope = scope.upper()

        if scope == "SEASONAL":
            season = await SeasonService.seed_default_season(db)
            # Order by UserSeasonProgress.current_xp DESC
            stmt = (
                select(UserSeasonProgress, Profile, PlayerStats)
                .join(User, User.id == UserSeasonProgress.user_id)
                .join(Profile, Profile.user_id == User.id)
                .join(PlayerStats, PlayerStats.user_id == User.id)
                .where(UserSeasonProgress.season_id == season.id)
                .order_by(
                    desc(UserSeasonProgress.current_xp),
                    desc(PlayerStats.matches_won),
                    desc(PlayerStats.total_captures),
                    User.id.asc(),
                )
                .limit(limit)
                .offset(offset)
            )
            res = await db.execute(stmt)
            rows = res.all()

            entries = []
            for rank_idx, (prog, prof, stats) in enumerate(rows, start=offset + 1):
                win_rate = (stats.matches_won / stats.matches_played * 100.0) if stats.matches_played > 0 else 0.0
                entries.append({
                    "rank": rank_idx,
                    "user_id": prof.user_id,
                    "player_id": prof.player_id,
                    "display_name": prof.display_name,
                    "avatar_id": prof.avatar_id,
                    "country_code": prof.country_code,
                    "level": prof.level,
                    "score": prog.current_xp,
                    "matches_played": stats.matches_played,
                    "matches_won": stats.matches_won,
                    "win_rate": round(win_rate, 1),
                })

            total = (await db.execute(
                select(func.count(UserSeasonProgress.id))
                .where(UserSeasonProgress.season_id == season.id)
            )).scalar_one()
            return {"scope": scope, "total_players": total, "entries": entries}

        if scope == "WEEKLY":
            now = datetime.now(timezone.utc)
            week_start = (now - timedelta(days=now.weekday())).replace(
                hour=0, minute=0, second=0, microsecond=0,
            )
            weekly = (
                select(
                    MatchPlayer.user_id.label("user_id"),
                    func.count(MatchPlayer.id).label("played"),
                    func.sum(case((MatchPlayer.placement == 1, 1), else_=0)).label("won"),
                )
                .join(Match, Match.id == MatchPlayer.match_id)
                .where(
                    Match.status == "COMPLETED",
                    Match.finished_at >= week_start,
                    MatchPlayer.user_id.is_not(None),
                )
                .group_by(MatchPlayer.user_id)
                .subquery()
            )
            rows = (await db.execute(
                select(Profile, weekly.c.played, weekly.c.won)
                .join(weekly, weekly.c.user_id == Profile.user_id)
                .order_by(desc(weekly.c.won), desc(weekly.c.played), Profile.user_id)
                .limit(limit).offset(offset)
            )).all()
            entries = [
                {
                    "rank": rank,
                    "user_id": profile.user_id,
                    "player_id": profile.player_id,
                    "display_name": profile.display_name,
                    "avatar_id": profile.avatar_id,
                    "country_code": profile.country_code,
                    "level": profile.level,
                    "score": int(won) * 100 + int(played) * 10,
                    "matches_played": int(played),
                    "matches_won": int(won),
                    "win_rate": round(won / played * 100, 1),
                }
                for rank, (profile, played, won) in enumerate(rows, start=offset + 1)
            ]
            total = (await db.execute(select(func.count()).select_from(weekly))).scalar_one()
            return {"scope": scope, "total_players": total, "entries": entries}

        else:
            # ALL_TIME and WEEKLY based on PlayerStats
            stmt = (
                select(Profile, PlayerStats)
                .join(PlayerStats, PlayerStats.user_id == Profile.user_id)
                .order_by(
                    desc(PlayerStats.matches_won),
                    desc(PlayerStats.total_captures),
                    desc(PlayerStats.total_tokens_home),
                    Profile.user_id.asc(),
                )
                .limit(limit)
                .offset(offset)
            )
            res = await db.execute(stmt)
            rows = res.all()

            entries = []
            for rank_idx, (prof, stats) in enumerate(rows, start=offset + 1):
                win_rate = (stats.matches_won / stats.matches_played * 100.0) if stats.matches_played > 0 else 0.0
                # Computed ranking points
                score = (stats.matches_won * 100) + (stats.total_captures * 15)
                entries.append({
                    "rank": rank_idx,
                    "user_id": prof.user_id,
                    "player_id": prof.player_id,
                    "display_name": prof.display_name,
                    "avatar_id": prof.avatar_id,
                    "country_code": prof.country_code,
                    "level": prof.level,
                    "score": score,
                    "matches_played": stats.matches_played,
                    "matches_won": stats.matches_won,
                    "win_rate": round(win_rate, 1),
                })

            total = (await db.execute(select(func.count(PlayerStats.user_id)))).scalar_one()
            return {"scope": scope, "total_players": total, "entries": entries}

    @staticmethod
    async def get_my_rank(db: AsyncSession, user_id: str, scope: str = "ALL_TIME") -> dict:
        offset = 0
        while True:
            lb = await LeaderboardService.get_leaderboard(db, scope=scope, limit=1000, offset=offset)
            for entry in lb["entries"]:
                if entry["user_id"] == user_id:
                    return {
                        "scope": scope,
                        "rank": entry["rank"],
                        "score": entry["score"],
                        "matches_played": entry["matches_played"],
                        "matches_won": entry["matches_won"],
                    }
            offset += len(lb["entries"])
            if not lb["entries"] or offset >= lb["total_players"]:
                break

        # No completed matches/progress in this scope.
        return {
            "scope": scope,
            "rank": 0,
            "score": 0,
            "matches_played": 0,
            "matches_won": 0,
        }
