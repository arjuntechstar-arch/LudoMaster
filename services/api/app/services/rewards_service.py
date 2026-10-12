from datetime import date, datetime, timedelta, timezone
from typing import List, Optional, Tuple
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.achievement import Achievement, UserAchievement
from app.models.daily_reward import UserDailyReward
from app.models.inventory import CatalogItem, UserInventory
from app.models.mission import Mission, UserMission
from app.models.profile import PlayerStats, Profile
from app.models.wallet import Wallet
from app.schemas.economy import DailyRewardDayResponse, DailyRewardStatusResponse
from app.services.economy import economy_service
from app.services.progression import progression_service

DAILY_REWARDS_SCHEDULE = [
    {"day": 1, "coins": 250, "gems": 0, "xp": 50},
    {"day": 2, "coins": 500, "gems": 0, "xp": 75},
    {"day": 3, "coins": 0, "gems": 5, "xp": 100},
    {"day": 4, "coins": 750, "gems": 0, "xp": 125},
    {"day": 5, "coins": 1000, "gems": 0, "xp": 150},
    {"day": 6, "coins": 0, "gems": 15, "xp": 200},
    {"day": 7, "coins": 2500, "gems": 25, "xp": 500},
]

DEFAULT_MISSIONS = [
    {
        "id": "m_daily_play_1",
        "title": "Ludo Initiate",
        "description": "Complete 1 online match",
        "category": "DAILY",
        "action_type": "MATCH_PLAY",
        "target_count": 1,
        "reward_coins": 150,
        "reward_gems": 0,
        "reward_xp": 50,
        "icon": "sports_esports",
    },
    {
        "id": "m_daily_win_1",
        "title": "Victory Call",
        "description": "Win 1 online match",
        "category": "DAILY",
        "action_type": "MATCH_WIN",
        "target_count": 1,
        "reward_coins": 300,
        "reward_gems": 2,
        "reward_xp": 100,
        "icon": "emoji_events",
    },
    {
        "id": "m_daily_cap_3",
        "title": "Token Hunter",
        "description": "Capture 3 opponent tokens on the track",
        "category": "DAILY",
        "action_type": "CAPTURE",
        "target_count": 3,
        "reward_coins": 250,
        "reward_gems": 1,
        "reward_xp": 75,
        "icon": "gps_fixed",
    },
    {
        "id": "m_weekly_play_10",
        "title": "Weekly Marathon",
        "description": "Complete 10 online matches this week",
        "category": "WEEKLY",
        "action_type": "MATCH_PLAY",
        "target_count": 10,
        "reward_coins": 1000,
        "reward_gems": 10,
        "reward_xp": 300,
        "icon": "calendar_month",
    },
    {
        "id": "m_weekly_cap_15",
        "title": "Relentless Striker",
        "description": "Capture 15 opponent tokens this week",
        "category": "WEEKLY",
        "action_type": "CAPTURE",
        "target_count": 15,
        "reward_coins": 1200,
        "reward_gems": 15,
        "reward_xp": 400,
        "icon": "military_tech",
    },
    {
        "id": "m_weekly_home_12",
        "title": "Home Runner",
        "description": "Guide 12 tokens safely into home",
        "category": "WEEKLY",
        "action_type": "TOKEN_HOME",
        "target_count": 12,
        "reward_coins": 1500,
        "reward_gems": 20,
        "reward_xp": 500,
        "icon": "home",
    },
]

DEFAULT_ACHIEVEMENTS = [
    {
        "id": "ach_first_win",
        "title": "First Victory",
        "description": "Win your first Ludo match",
        "action_type": "MATCH_WIN",
        "target_count": 1,
        "reward_coins": 500,
        "reward_gems": 5,
        "reward_xp": 200,
        "badge_key": "badge_bronze",
    },
    {
        "id": "ach_ten_wins",
        "title": "Rising Champion",
        "description": "Win 10 Ludo matches",
        "action_type": "MATCH_WIN",
        "target_count": 10,
        "reward_coins": 1500,
        "reward_gems": 20,
        "reward_xp": 500,
        "badge_key": "badge_silver",
    },
    {
        "id": "ach_fifty_wins",
        "title": "Ludo Master",
        "description": "Win 50 Ludo matches",
        "action_type": "MATCH_WIN",
        "target_count": 50,
        "reward_coins": 5000,
        "reward_gems": 100,
        "reward_xp": 1500,
        "badge_key": "badge_gold",
    },
    {
        "id": "ach_captures_20",
        "title": "Predator",
        "description": "Capture 20 opponent tokens",
        "action_type": "CAPTURE",
        "target_count": 20,
        "reward_coins": 1000,
        "reward_gems": 10,
        "reward_xp": 300,
        "badge_key": "badge_predator",
    },
    {
        "id": "ach_home_30",
        "title": "Grand Finish",
        "description": "Bring 30 tokens safely to home",
        "action_type": "TOKENS_HOME",
        "target_count": 30,
        "reward_coins": 1200,
        "reward_gems": 15,
        "reward_xp": 400,
        "badge_key": "badge_home",
    },
    {
        "id": "ach_reach_lvl_5",
        "title": "Seasoned Veteran",
        "description": "Reach player Level 5",
        "action_type": "LEVEL",
        "target_count": 5,
        "reward_coins": 2000,
        "reward_gems": 25,
        "reward_xp": 600,
        "badge_key": "badge_veteran",
    },
]

DEFAULT_CATALOG_ITEMS = [
    {
        "id": "theme_classic_wood",
        "name": "Classic Wood Board",
        "category": "BOARD_THEME",
        "description": "Traditional tournament-grade natural wood finish",
        "rarity": "COMMON",
        "price_coins": 0,
        "price_gems": 0,
        "asset_key": "board_classic_wood",
        "is_default": True,
    },
    {
        "id": "theme_neon_cyber",
        "name": "Neon Cyber Board",
        "category": "BOARD_THEME",
        "description": "Futuristic luminescent cyberpunk tracks and dark acrylic board",
        "rarity": "RARE",
        "price_coins": 1500,
        "price_gems": 0,
        "asset_key": "board_neon_cyber",
        "is_default": False,
    },
    {
        "id": "theme_royal_marble",
        "name": "Royal Marble Board",
        "category": "BOARD_THEME",
        "description": "Opulent white polished marble inlaid with pure gold geometric leaf",
        "rarity": "EPIC",
        "price_coins": 3500,
        "price_gems": 25,
        "asset_key": "board_royal_marble",
        "is_default": False,
    },
    {
        "id": "dice_classic_ivory",
        "name": "Ivory Dice",
        "category": "DICE_SKIN",
        "description": "Traditional balanced die carved from polished ivory",
        "rarity": "COMMON",
        "price_coins": 0,
        "price_gems": 0,
        "asset_key": "dice_ivory",
        "is_default": True,
    },
    {
        "id": "dice_golden_luxury",
        "name": "Golden Luxury Dice",
        "category": "DICE_SKIN",
        "description": "Solid gold die with diamond embedded pips",
        "rarity": "RARE",
        "price_coins": 1200,
        "price_gems": 10,
        "asset_key": "dice_gold",
        "is_default": False,
    },
    {
        "id": "dice_crystal_prism",
        "name": "Crystal Prism Dice",
        "category": "DICE_SKIN",
        "description": "Translucent quartz crystal with rainbow refractive light",
        "rarity": "EPIC",
        "price_coins": 2500,
        "price_gems": 30,
        "asset_key": "dice_crystal",
        "is_default": False,
    },
    {
        "id": "frame_standard",
        "name": "Standard Border",
        "category": "FRAME",
        "description": "Clean minimalist avatar boundary",
        "rarity": "COMMON",
        "price_coins": 0,
        "price_gems": 0,
        "asset_key": "frame_standard",
        "is_default": True,
    },
    {
        "id": "frame_gold_crown",
        "name": "Crown of Kings",
        "category": "FRAME",
        "description": "Gilded crown with laurel wreaths for true champions",
        "rarity": "RARE",
        "price_coins": 2000,
        "price_gems": 15,
        "asset_key": "frame_crown",
        "is_default": False,
    },
]

class RewardsService:
    @staticmethod
    def _mission_period_end(category: str, now: datetime) -> datetime:
        day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        if category == "WEEKLY":
            return day_start + timedelta(days=7 - now.weekday())
        return day_start + timedelta(days=1)

    # --- Daily Login Rewards ---
    async def get_or_create_daily_reward(self, db: AsyncSession, user_id: str) -> UserDailyReward:
        q = await db.execute(select(UserDailyReward).where(UserDailyReward.user_id == user_id))
        rec = q.scalar_one_or_none()
        if not rec:
            rec = UserDailyReward(user_id=user_id, current_streak=0, total_claims=0)
            db.add(rec)
            try:
                await db.commit()
                await db.refresh(rec)
            except IntegrityError:
                # Home and the rewards dialog can both create the first row.
                await db.rollback()
                rec = await db.scalar(select(UserDailyReward).where(UserDailyReward.user_id == user_id))
                if rec is None:
                    raise
        return rec

    async def get_daily_reward_status(self, db: AsyncSession, user_id: str) -> DailyRewardStatusResponse:
        rec = await self.get_or_create_daily_reward(db, user_id)
        today = datetime.now(timezone.utc).date()

        can_claim = False
        target_day = 1

        if rec.last_claim_date is None:
            can_claim = True
            target_day = 1
        elif rec.last_claim_date == today:
            can_claim = False
            target_day = rec.current_streak if rec.current_streak > 0 else 1
        elif rec.last_claim_date == today - timedelta(days=1):
            can_claim = True
            target_day = (rec.current_streak % 7) + 1
        else:
            # Streak broken
            can_claim = True
            target_day = 1

        days_response = []
        for item in DAILY_REWARDS_SCHEDULE:
            d = item["day"]
            is_claimed = (d <= rec.current_streak and rec.last_claim_date == today) or (d < target_day and rec.last_claim_date == today - timedelta(days=1))
            is_today = (d == target_day)
            days_response.append(
                DailyRewardDayResponse(
                    day=d,
                    coins=item["coins"],
                    gems=item["gems"],
                    xp=item["xp"],
                    is_claimed=is_claimed,
                    is_today=is_today,
                )
            )

        return DailyRewardStatusResponse(
            current_streak=rec.current_streak,
            can_claim=can_claim,
            last_claim_date=str(rec.last_claim_date) if rec.last_claim_date else None,
            days=days_response,
        )

    async def claim_daily_reward(self, db: AsyncSession, user_id: str) -> dict:
        await self.get_or_create_daily_reward(db, user_id)
        rec = await db.scalar(select(UserDailyReward).where(UserDailyReward.user_id == user_id).with_for_update().execution_options(populate_existing=True))
        today = datetime.now(timezone.utc).date()

        if rec.last_claim_date == today:
            raise ValueError("Today's reward has already been claimed.")

        if rec.last_claim_date == today - timedelta(days=1):
            new_streak = (rec.current_streak % 7) + 1
        else:
            new_streak = 1

        reward_conf = next((r for r in DAILY_REWARDS_SCHEDULE if r["day"] == new_streak), DAILY_REWARDS_SCHEDULE[0])

        # Record Coins
        new_coins = 0
        if reward_conf["coins"] > 0:
            ledger, wallet = await economy_service.record_transaction(
                db=db,
                user_id=user_id,
                amount=reward_conf["coins"],
                currency="COINS",
                reason="DAILY_LOGIN_REWARD",
                idempotency_key=f"daily_reward_coins_{user_id}_{today}",
                commit=False,
            )
            new_coins = wallet.coins

        # Record Gems
        new_gems = 0
        if reward_conf["gems"] > 0:
            ledger, wallet = await economy_service.record_transaction(
                db=db,
                user_id=user_id,
                amount=reward_conf["gems"],
                currency="GEMS",
                reason="DAILY_LOGIN_REWARD",
                idempotency_key=f"daily_reward_gems_{user_id}_{today}",
                commit=False,
            )
            new_gems = wallet.gems
        else:
            w = await economy_service.get_or_create_wallet(db, user_id, commit=False)
            new_gems = w.gems

        # Record XP
        new_level, new_xp, _ = await progression_service.award_xp(db, user_id, reward_conf["xp"], commit=False)

        rec.current_streak = new_streak
        rec.last_claim_date = today
        rec.total_claims += 1
        await db.commit()
        await db.refresh(rec)

        return {
            "message": f"Successfully claimed Day {new_streak} rewards!",
            "day": new_streak,
            "coins_awarded": reward_conf["coins"],
            "gems_awarded": reward_conf["gems"],
            "xp_awarded": reward_conf["xp"],
            "new_balance_coins": new_coins,
            "new_balance_gems": new_gems,
            "new_level": new_level,
            "new_xp": new_xp,
        }

    # --- Missions ---
    async def seed_missions(self, db: AsyncSession, *, commit: bool = True):
        for m in DEFAULT_MISSIONS:
            q = await db.execute(select(Mission).where(Mission.id == m["id"]))
            existing = q.scalar_one_or_none()
            if not existing:
                db.add(Mission(**m))
            else:
                existing.description = m["description"]
        if commit:
            await db.commit()
        else:
            await db.flush()

    async def ensure_user_missions(self, db: AsyncSession, user_id: str, *, commit: bool = True) -> List[UserMission]:
        await self.seed_missions(db, commit=commit)
        now = datetime.now(timezone.utc)
        m_q = await db.execute(select(Mission).where(Mission.is_active.is_(True)))
        missions = m_q.scalars().all()

        user_m_q = await db.execute(select(UserMission).where(UserMission.user_id == user_id))
        user_missions = {um.mission_id: um for um in user_m_q.scalars().all()}

        created_any = False
        for m in missions:
            if m.id not in user_missions:
                um = UserMission(
                    user_id=user_id,
                    mission_id=m.id,
                    current_count=0,
                    is_completed=False,
                    is_claimed=False,
                    expires_at=self._mission_period_end(m.category, now),
                )
                db.add(um)
                user_missions[m.id] = um
                created_any = True
            else:
                um = user_missions[m.id]
                expiry = um.expires_at
                if expiry is not None and expiry.tzinfo is None:
                    expiry = expiry.replace(tzinfo=timezone.utc)
                if expiry is None or expiry <= now:
                    um.current_count = 0
                    um.is_completed = False
                    um.is_claimed = False
                    um.expires_at = self._mission_period_end(m.category, now)
                    created_any = True

        if created_any and commit:
            await db.commit()

        # Re-fetch with loaded mission relations
        res = await db.execute(select(UserMission).where(UserMission.user_id == user_id))
        return list(res.scalars().all())

    async def claim_mission(self, db: AsyncSession, user_id: str, mission_id: str) -> dict:
        await self.ensure_user_missions(db, user_id)
        q = await db.execute(
            select(UserMission).where(
                UserMission.user_id == user_id,
                UserMission.mission_id == mission_id,
            )
        )
        um = q.scalar_one_or_none()
        if not um:
            raise ValueError("Mission not found for user.")
        if not um.is_completed:
            raise ValueError("Mission objective is not yet completed.")
        if um.is_claimed:
            raise ValueError("Mission reward has already been claimed.")

        mission = um.mission
        period_key = um.expires_at.strftime("%Y%m%d") if um.expires_at else "initial"
        new_coins = 0
        new_gems = 0

        if mission.reward_coins > 0:
            _, w = await economy_service.record_transaction(
                db=db,
                user_id=user_id,
                amount=mission.reward_coins,
                currency="COINS",
                reason=f"MISSION_REWARD_{mission.id}",
                idempotency_key=f"m_reward_c_{um.id}_{period_key}",
                commit=False,
            )
            new_coins = w.coins

        if mission.reward_gems > 0:
            _, w = await economy_service.record_transaction(
                db=db,
                user_id=user_id,
                amount=mission.reward_gems,
                currency="GEMS",
                reason=f"MISSION_REWARD_{mission.id}",
                idempotency_key=f"m_reward_g_{um.id}_{period_key}",
                commit=False,
            )
            new_gems = w.gems
        else:
            w = await economy_service.get_or_create_wallet(db, user_id, commit=False)
            new_gems = w.gems

        new_level, new_xp, _ = await progression_service.award_xp(db, user_id, mission.reward_xp, commit=False)

        um.is_claimed = True
        await db.commit()

        return {
            "mission_id": mission.id,
            "coins_awarded": mission.reward_coins,
            "gems_awarded": mission.reward_gems,
            "xp_awarded": mission.reward_xp,
            "new_balance_coins": new_coins,
            "new_balance_gems": new_gems,
            "new_level": new_level,
            "new_xp": new_xp,
        }

    # --- Achievements ---
    async def seed_achievements(self, db: AsyncSession, *, commit: bool = True):
        for a in DEFAULT_ACHIEVEMENTS:
            q = await db.execute(select(Achievement).where(Achievement.id == a["id"]))
            if not q.scalar_one_or_none():
                db.add(Achievement(**a))
        if commit:
            await db.commit()
        else:
            await db.flush()

    async def ensure_user_achievements(self, db: AsyncSession, user_id: str, *, commit: bool = True) -> List[UserAchievement]:
        await self.seed_achievements(db, commit=commit)
        a_q = await db.execute(select(Achievement))
        achievements = a_q.scalars().all()
        stats = (await db.execute(select(PlayerStats).where(PlayerStats.user_id == user_id))).scalar_one_or_none()
        profile = (await db.execute(select(Profile).where(Profile.user_id == user_id))).scalar_one_or_none()

        ua_q = await db.execute(select(UserAchievement).where(UserAchievement.user_id == user_id))
        user_achievements = {ua.achievement_id: ua for ua in ua_q.scalars().all()}

        created_any = False
        for a in achievements:
            progress = {
                "MATCH_WIN": stats.matches_won if stats else 0,
                "CAPTURE": stats.total_captures if stats else 0,
                "TOKENS_HOME": stats.total_tokens_home if stats else 0,
                "LEVEL": profile.level if profile else 1,
                "WIN_STREAK": stats.best_streak if stats else 0,
            }.get(a.action_type, 0)
            progress = min(progress, a.target_count)
            if a.id not in user_achievements:
                ua = UserAchievement(
                    user_id=user_id,
                    achievement_id=a.id,
                    current_count=progress,
                    is_unlocked=progress >= a.target_count,
                    is_claimed=False,
                )
                db.add(ua)
                user_achievements[a.id] = ua
                created_any = True
            else:
                ua = user_achievements[a.id]
                if progress > ua.current_count:
                    ua.current_count = progress
                    if progress >= a.target_count:
                        ua.is_unlocked = True
                        ua.unlocked_at = datetime.now(timezone.utc)
                    created_any = True

        if created_any and commit:
            await db.commit()

        res = await db.execute(select(UserAchievement).where(UserAchievement.user_id == user_id))
        return list(res.scalars().all())

    async def claim_achievement(self, db: AsyncSession, user_id: str, achievement_id: str) -> dict:
        q = await db.execute(
            select(UserAchievement).where(
                UserAchievement.user_id == user_id,
                UserAchievement.achievement_id == achievement_id,
            )
        )
        ua = q.scalar_one_or_none()
        if not ua:
            raise ValueError("Achievement not found for user.")
        if not ua.is_unlocked:
            raise ValueError("Achievement is not yet unlocked.")
        if ua.is_claimed:
            raise ValueError("Achievement reward has already been claimed.")

        achievement = ua.achievement
        new_coins = 0
        new_gems = 0

        if achievement.reward_coins > 0:
            _, w = await economy_service.record_transaction(
                db=db,
                user_id=user_id,
                amount=achievement.reward_coins,
                currency="COINS",
                reason=f"ACHIEVEMENT_REWARD_{achievement.id}",
                idempotency_key=f"ach_reward_c_{ua.id}",
                commit=False,
            )
            new_coins = w.coins

        if achievement.reward_gems > 0:
            _, w = await economy_service.record_transaction(
                db=db,
                user_id=user_id,
                amount=achievement.reward_gems,
                currency="GEMS",
                reason=f"ACHIEVEMENT_REWARD_{achievement.id}",
                idempotency_key=f"ach_reward_g_{ua.id}",
                commit=False,
            )
            new_gems = w.gems
        else:
            w = await economy_service.get_or_create_wallet(db, user_id, commit=False)
            new_gems = w.gems

        new_level, new_xp, _ = await progression_service.award_xp(db, user_id, achievement.reward_xp, commit=False)

        ua.is_claimed = True
        await db.commit()

        return {
            "achievement_id": achievement.id,
            "coins_awarded": achievement.reward_coins,
            "gems_awarded": achievement.reward_gems,
            "xp_awarded": achievement.reward_xp,
            "new_balance_coins": new_coins,
            "new_balance_gems": new_gems,
            "new_level": new_level,
            "new_xp": new_xp,
        }

    # --- Catalog & Inventory ---
    async def seed_catalog(self, db: AsyncSession):
        for item in DEFAULT_CATALOG_ITEMS:
            q = await db.execute(select(CatalogItem).where(CatalogItem.id == item["id"]))
            if not q.scalar_one_or_none():
                db.add(CatalogItem(**item, is_active=True))
        try:
            await db.commit()
        except Exception:
            await db.rollback()

    async def ensure_default_inventory(self, db: AsyncSession, user_id: str):
        await self.seed_catalog(db)
        # Grant default items if not owned
        defaults_q = await db.execute(select(CatalogItem).where(CatalogItem.is_default.is_(True)))
        defaults = defaults_q.scalars().all()

        owned_q = await db.execute(select(UserInventory).where(UserInventory.user_id == user_id))
        owned = {ui.item_id: ui for ui in owned_q.scalars().all()}

        equipped_categories = {ui.item.category for ui in owned.values() if ui.is_equipped}

        changed = False
        for d in defaults:
            if d.id not in owned:
                should_equip = d.category not in equipped_categories
                ui = UserInventory(
                    user_id=user_id,
                    item_id=d.id,
                    is_equipped=should_equip,
                )
                db.add(ui)
                if should_equip:
                    equipped_categories.add(d.category)
                changed = True

        if changed:
            await db.commit()

    async def get_catalog_with_user_state(self, db: AsyncSession, user_id: str) -> List[dict]:
        await self.ensure_default_inventory(db, user_id)
        items_q = await db.execute(select(CatalogItem).where(CatalogItem.is_active.is_(True)))
        items = items_q.scalars().all()

        owned_q = await db.execute(select(UserInventory).where(UserInventory.user_id == user_id))
        owned = {ui.item_id: ui for ui in owned_q.scalars().all()}

        result = []
        for it in items:
            inv = owned.get(it.id)
            result.append({
                "id": it.id,
                "name": it.name,
                "category": it.category,
                "description": it.description,
                "rarity": it.rarity,
                "price_coins": it.price_coins,
                "price_gems": it.price_gems,
                "asset_key": it.asset_key,
                "is_default": it.is_default,
                "is_owned": inv is not None,
                "is_equipped": inv.is_equipped if inv else False,
            })
        return result

    async def purchase_item(self, db: AsyncSession, user_id: str, item_id: str, currency: str = "COINS") -> dict:
        await self.ensure_default_inventory(db, user_id)
        item_q = await db.execute(select(CatalogItem).where(CatalogItem.id == item_id))
        item = item_q.scalar_one_or_none()
        if not item or not item.is_active:
            raise ValueError("Item is not available for purchase.")

        # Check if already owned
        owned_q = await db.execute(
            select(UserInventory).where(UserInventory.user_id == user_id, UserInventory.item_id == item_id)
        )
        if owned_q.scalar_one_or_none():
            raise ValueError("You already own this item.")

        if currency not in ("COINS", "GEMS"):
            raise ValueError("Select coins or gems for this purchase.")
        price = item.price_coins if currency == "COINS" else item.price_gems
        if price <= 0 and (item.price_coins > 0 or item.price_gems > 0):
            raise ValueError(f"This item is not available for purchase with {currency.lower()}.")
        if price > 0:
            await economy_service.record_transaction(
                db=db,
                user_id=user_id,
                amount=-price,
                currency=currency,
                reason=f"ITEM_PURCHASE_{item.id}",
                idempotency_key=f"item_purchase_{user_id}_{item_id}",
                commit=False,
            )

        ui = UserInventory(
            user_id=user_id,
            item_id=item.id,
            is_equipped=False,
        )
        db.add(ui)
        await db.commit()
        await db.refresh(ui)
        return {"message": f"Successfully purchased {item.name}!", "item_id": item.id}

    async def equip_item(self, db: AsyncSession, user_id: str, item_id: str) -> dict:
        await self.ensure_default_inventory(db, user_id)
        owned_q = await db.execute(
            select(UserInventory).where(UserInventory.user_id == user_id, UserInventory.item_id == item_id)
        )
        target = owned_q.scalar_one_or_none()
        if not target:
            raise ValueError("Cannot equip an item you do not own.")

        category = target.item.category
        # Unequip all items in the same category
        all_owned_q = await db.execute(select(UserInventory).where(UserInventory.user_id == user_id))
        for ui in all_owned_q.scalars().all():
            if ui.item.category == category:
                ui.is_equipped = (ui.item_id == item_id)

        await db.commit()
        return {"message": f"Equipped {target.item.name}", "item_id": item_id, "category": category}

rewards_service = RewardsService()
