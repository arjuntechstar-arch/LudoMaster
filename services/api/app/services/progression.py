from datetime import datetime, timezone
from typing import Tuple
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.achievement import Achievement, UserAchievement
from app.models.mission import Mission, UserMission
from app.models.profile import Profile, PlayerStats
from app.services.economy import economy_service

def calculate_xp_for_level(level: int) -> int:
    """XP required to advance from current level to the next."""
    if level < 1:
        return 100
    return 100 * level + 50 * ((level - 1) ** 2)

class ProgressionService:
    async def award_xp(
        self, db: AsyncSession, user_id: str, xp_amount: int, *, commit: bool = True
    ) -> Tuple[int, int, bool]:
        """Awards XP to user profile and evaluates level ups with rewards."""
        q = await db.execute(select(Profile).where(Profile.user_id == user_id))
        profile = q.scalar_one_or_none()
        if not profile:
            return 1, 0, False

        profile.xp += xp_amount
        leveled_up = False

        while True:
            required = calculate_xp_for_level(profile.level)
            if profile.xp >= required:
                profile.xp -= required
                profile.level += 1
                leveled_up = True
                # Level up reward: Coins proportional to new level
                await economy_service.record_transaction(
                    db=db,
                    user_id=user_id,
                    amount=profile.level * 250,
                    currency="COINS",
                    reason="LEVEL_UP_REWARD",
                    idempotency_key=f"lvlup_{user_id}_{profile.level}",
                    commit=commit,
                )
            else:
                break

        if commit:
            await db.commit()
            await db.refresh(profile)
        else:
            await db.flush()
        return profile.level, profile.xp, leveled_up

    async def record_match_progress(
        self,
        db: AsyncSession,
        user_id: str,
        placement: int,
        captures: int,
        tokens_home: int,
        mode: str = "CLASSIC",
        *,
        commit: bool = True,
        prepared: bool = False,
    ) -> dict:
        """
        Server-authoritative update of match statistics, XP gain,
        mission objectives progression, and lifetime achievement unlocks.
        """
        if not prepared:
            from app.services.rewards_service import rewards_service

            await rewards_service.ensure_user_missions(db, user_id)
            await rewards_service.ensure_user_achievements(db, user_id)

        # 1. Update PlayerStats
        q = await db.execute(select(PlayerStats).where(PlayerStats.user_id == user_id))
        stats = q.scalar_one_or_none()
        if not stats:
            stats = PlayerStats(user_id=user_id)
            db.add(stats)
            await db.flush()

        stats.matches_played += 1
        is_win = (placement == 1)
        if is_win:
            stats.matches_won += 1
            stats.win_streak += 1
            if stats.win_streak > stats.best_streak:
                stats.best_streak = stats.win_streak
        else:
            stats.win_streak = 0

        stats.total_captures += captures
        stats.total_tokens_home += tokens_home

        # 2. Calculate and Award XP
        base_xp = 120 if placement == 1 else (70 if placement == 2 else 35)
        earned_xp = base_xp + (captures * 10) + (tokens_home * 15)
        new_level, new_xp, leveled_up = await self.award_xp(db, user_id, earned_xp, commit=False)

        # 3. Progress User Missions
        now = datetime.now(timezone.utc)
        m_q = await db.execute(
            select(UserMission)
            .join(Mission)
            .where(
                UserMission.user_id == user_id,
                UserMission.is_completed.is_(False),
            )
        )
        user_missions = m_q.scalars().all()
        for um in user_missions:
            action = um.mission.action_type
            inc = 0
            if action == "MATCH_PLAY":
                inc = 1
            elif action == "MATCH_WIN" and is_win:
                inc = 1
            elif action == "CAPTURE":
                inc = captures
            elif action == "TOKEN_HOME":
                inc = tokens_home

            if inc > 0:
                um.current_count += inc
                if um.current_count >= um.mission.target_count:
                    um.current_count = um.mission.target_count
                    um.is_completed = True

        # 4. Progress User Achievements
        a_q = await db.execute(
            select(UserAchievement)
            .join(Achievement)
            .where(
                UserAchievement.user_id == user_id,
                UserAchievement.is_unlocked.is_(False),
            )
        )
        user_achievements = a_q.scalars().all()
        for ua in user_achievements:
            action = ua.achievement.action_type
            val = 0
            if action == "MATCH_WIN":
                val = stats.matches_won
            elif action == "CAPTURE":
                val = stats.total_captures
            elif action == "TOKENS_HOME":
                val = stats.total_tokens_home
            elif action == "LEVEL":
                val = new_level
            elif action == "WIN_STREAK":
                val = stats.best_streak

            if val > ua.current_count:
                ua.current_count = val
                if ua.current_count >= ua.achievement.target_count:
                    ua.current_count = ua.achievement.target_count
                    ua.is_unlocked = True
                    ua.unlocked_at = now

        if commit:
            await db.commit()
        else:
            await db.flush()
        return {
            "earned_xp": earned_xp,
            "new_level": new_level,
            "new_xp": new_xp,
            "leveled_up": leveled_up,
            "matches_won": stats.matches_won,
            "win_streak": stats.win_streak,
        }

progression_service = ProgressionService()
