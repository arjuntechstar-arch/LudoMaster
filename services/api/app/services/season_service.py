import datetime
import uuid
from typing import Dict, List, Optional
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException
from app.models.season import Season, SeasonTier, UserSeasonProgress
from app.models.inventory import CatalogItem, UserInventory
from app.services.economy import EconomyService

class SeasonService:
    PREMIUM_PASS_COST_GEMS = 100

    @staticmethod
    async def seed_default_season(db: AsyncSession, *, commit: bool = True) -> Season:
        now = datetime.datetime.utcnow()
        stmt = select(Season).where(Season.is_active == True).order_by(Season.season_number.desc())
        res = await db.execute(stmt)
        season = res.scalars().first()
        if season and season.ends_at <= now:
            season.is_active = False
            season = None
        if not season:
            latest = (await db.execute(
                select(Season.season_number).order_by(Season.season_number.desc()).limit(1)
            )).scalar_one_or_none()
            season_number = (latest or 0) + 1
            season = Season(
                id=f"season_{season_number}",
                season_number=season_number,
                title=f"Season {season_number}: Royal Arena",
                theme_name="Royal Gold",
                starts_at=now,
                ends_at=now + datetime.timedelta(days=30),
                is_active=True,
            )
            db.add(season)
            await db.flush()

            # Seed 10 progression tiers
            tiers = []
            xp_curve = [100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700, 3300]
            for i in range(10):
                tier_num = i + 1
                req_xp = xp_curve[i]
                tiers.append(
                    SeasonTier(
                        id=f"season_{season_number}_tier_{tier_num}",
                        season_id=season.id,
                        tier_number=tier_num,
                        xp_required=req_xp,
                        free_reward_coins=tier_num * 200,
                        free_reward_gems=tier_num * 2,
                        premium_reward_coins=tier_num * 500,
                        premium_reward_gems=tier_num * 10,
                    )
                )
            db.add_all(tiers)
            if commit:
                await db.commit()
            else:
                await db.flush()

        return season

    @staticmethod
    async def get_or_create_user_progress(db: AsyncSession, user_id: str, season_id: str, *, commit: bool = True) -> UserSeasonProgress:
        stmt = select(UserSeasonProgress).where(
            UserSeasonProgress.user_id == user_id,
            UserSeasonProgress.season_id == season_id,
        )
        res = await db.execute(stmt)
        prog = res.scalars().first()
        if not prog:
            prog = UserSeasonProgress(
                id=str(uuid.uuid4()),
                user_id=user_id,
                season_id=season_id,
                current_xp=0,
                current_tier=1,
                has_premium_pass=False,
                claimed_free_tiers=[],
                claimed_premium_tiers=[],
            )
            db.add(prog)
            if commit:
                await db.commit()
                await db.refresh(prog)
            else:
                await db.flush()
        return prog

    @staticmethod
    async def get_current_season_details(db: AsyncSession, user_id: str) -> dict:
        season = await SeasonService.seed_default_season(db)

        # Load tiers
        tiers_stmt = (
            select(SeasonTier)
            .options(selectinload(SeasonTier.free_item), selectinload(SeasonTier.premium_item))
            .where(SeasonTier.season_id == season.id)
            .order_by(SeasonTier.tier_number)
        )
        tiers_res = await db.execute(tiers_stmt)
        tiers = tiers_res.scalars().all()

        user_prog = await SeasonService.get_or_create_user_progress(db, user_id, season.id)

        tiers_data = []
        for t in tiers:
            is_unlocked = user_prog.current_xp >= t.xp_required
            is_free_claimed = t.tier_number in (user_prog.claimed_free_tiers or [])
            is_premium_claimed = t.tier_number in (user_prog.claimed_premium_tiers or [])

            tiers_data.append({
                "id": t.id,
                "tier_number": t.tier_number,
                "xp_required": t.xp_required,
                "free_reward_coins": t.free_reward_coins,
                "free_reward_gems": t.free_reward_gems,
                "free_reward_item_id": t.free_reward_item_id,
                "free_reward_item_name": t.free_item.name if t.free_item else None,
                "premium_reward_coins": t.premium_reward_coins,
                "premium_reward_gems": t.premium_reward_gems,
                "premium_reward_item_id": t.premium_reward_item_id,
                "premium_reward_item_name": t.premium_item.name if t.premium_item else None,
                "is_unlocked": is_unlocked,
                "is_free_claimed": is_free_claimed,
                "is_premium_claimed": is_premium_claimed,
            })

        return {
            "id": season.id,
            "season_number": season.season_number,
            "title": season.title,
            "theme_name": season.theme_name,
            "starts_at": season.starts_at.isoformat(),
            "ends_at": season.ends_at.isoformat(),
            "is_active": season.is_active,
            "current_xp": user_prog.current_xp,
            "current_tier": user_prog.current_tier,
            "has_premium_pass": user_prog.has_premium_pass,
            "premium_pass_cost_gems": SeasonService.PREMIUM_PASS_COST_GEMS,
            "tiers": tiers_data,
        }

    @staticmethod
    async def unlock_premium_pass(db: AsyncSession, user_id: str) -> dict:
        season = await SeasonService.seed_default_season(db)
        progress = await SeasonService.get_or_create_user_progress(db, user_id, season.id)
        if progress.has_premium_pass:
            raise HTTPException(status_code=400, detail="Royal Pass already unlocked")
        try:
            await EconomyService.record_transaction(
                db, user_id, -SeasonService.PREMIUM_PASS_COST_GEMS, "GEMS",
                "SEASON_PASS_UNLOCK",
                idempotency_key=f"season_pass_{season.id}_{user_id}",
                commit=False,
            )
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        progress.has_premium_pass = True
        await db.commit()
        return {"season_id": season.id, "has_premium_pass": True}

    @staticmethod
    async def add_season_xp(db: AsyncSession, user_id: str, xp_amount: int, *, commit: bool = True) -> None:
        season = await SeasonService.seed_default_season(db)
        user_prog = await SeasonService.get_or_create_user_progress(db, user_id, season.id)
        user_prog.current_xp += xp_amount

        # Check unlocked tier
        tiers_stmt = select(SeasonTier).where(SeasonTier.season_id == season.id).order_by(SeasonTier.tier_number)
        tiers_res = await db.execute(tiers_stmt)
        tiers = tiers_res.scalars().all()

        max_unlocked = 1
        for t in tiers:
            if user_prog.current_xp >= t.xp_required:
                max_unlocked = t.tier_number
        user_prog.current_tier = max_unlocked

        if commit:
            await db.commit()
        else:
            await db.flush()

    @staticmethod
    async def claim_tier_reward(db: AsyncSession, user_id: str, tier_number: int, is_premium: bool = False) -> dict:
        season = await SeasonService.seed_default_season(db)
        user_prog = await SeasonService.get_or_create_user_progress(db, user_id, season.id)

        tier_stmt = select(SeasonTier).where(
            SeasonTier.season_id == season.id,
            SeasonTier.tier_number == tier_number,
        )
        tier_res = await db.execute(tier_stmt)
        tier = tier_res.scalars().first()
        if not tier:
            raise HTTPException(status_code=404, detail="Season tier not found")

        if user_prog.current_xp < tier.xp_required:
            raise HTTPException(status_code=400, detail="Tier requirement not yet reached")

        claimed_list = list(user_prog.claimed_premium_tiers if is_premium else user_prog.claimed_free_tiers or [])
        if tier_number in claimed_list:
            raise HTTPException(status_code=400, detail="Reward for this tier already claimed")

        if is_premium and not user_prog.has_premium_pass:
            raise HTTPException(status_code=400, detail="Premium pass required to claim this track")

        coins_awarded = tier.premium_reward_coins if is_premium else tier.free_reward_coins
        gems_awarded = tier.premium_reward_gems if is_premium else tier.free_reward_gems
        item_id = tier.premium_reward_item_id if is_premium else tier.free_reward_item_id

        # Award currency via immutable ledger
        if coins_awarded > 0:
            await EconomyService.record_transaction(
                db=db,
                user_id=user_id,
                amount=coins_awarded,
                currency="COINS",
                reason=f"SEASON_TIER_REWARD:S{season.season_number}_T{tier_number}",
                idempotency_key=f"season_claim_coins_{season.id}_{tier_number}_{is_premium}_{user_id}",
                commit=False,
            )
        if gems_awarded > 0:
            await EconomyService.record_transaction(
                db=db,
                user_id=user_id,
                amount=gems_awarded,
                currency="GEMS",
                reason=f"SEASON_TIER_REWARD:S{season.season_number}_T{tier_number}",
                idempotency_key=f"season_claim_gems_{season.id}_{tier_number}_{is_premium}_{user_id}",
                commit=False,
            )

        # Award cosmetic item if present
        if item_id:
            inv_check = await db.execute(
                select(UserInventory).where(UserInventory.user_id == user_id, UserInventory.item_id == item_id)
            )
            if not inv_check.scalars().first():
                db.add(UserInventory(id=str(uuid.uuid4()), user_id=user_id, item_id=item_id))

        claimed_list.append(tier_number)
        if is_premium:
            user_prog.claimed_premium_tiers = claimed_list
        else:
            user_prog.claimed_free_tiers = claimed_list

        await db.commit()
        wallet = await EconomyService.get_wallet_balance(db, user_id)

        return {
            "tier_number": tier_number,
            "coins_awarded": coins_awarded,
            "gems_awarded": gems_awarded,
            "item_awarded": item_id,
            "new_balance_coins": wallet["coins"],
            "new_balance_gems": wallet["gems"],
        }
