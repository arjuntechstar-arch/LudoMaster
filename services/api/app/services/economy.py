from typing import Optional, Tuple
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.wallet import Wallet, WalletLedger

class EconomyService:
    @classmethod
    async def get_or_create_wallet(cls, db: AsyncSession, user_id: str, *, commit: bool = True) -> Wallet:
        q = await db.execute(select(Wallet).where(Wallet.user_id == user_id))
        wallet = q.scalar_one_or_none()
        if not wallet:
            wallet = Wallet(user_id=user_id, coins=1000, gems=10)
            db.add(wallet)
            await db.flush()
            # Initial grant ledger
            ledger = WalletLedger(
                wallet_id=wallet.id,
                amount=1000,
                currency="COINS",
                balance_after=1000,
                reason="STARTING_BONUS",
                idempotency_key=f"start_bonus_{user_id}",
            )
            db.add(ledger)
            if commit:
                await db.commit()
                await db.refresh(wallet)
        return wallet

    @classmethod
    async def get_wallet_balance(cls, db: AsyncSession, user_id: str) -> dict:
        wallet = await cls.get_or_create_wallet(db, user_id)
        return {"coins": wallet.coins, "gems": wallet.gems}

    @classmethod
    async def record_transaction(
        cls,
        db: AsyncSession,
        user_id: str,
        amount: int,
        currency: str,
        reason: str,
        idempotency_key: Optional[str] = None,
        commit: bool = True,
    ) -> Tuple[WalletLedger, Wallet]:
        """
        Server-authoritative currency balance adjustment with an immutable ledger.
        Ensures balances are never modified without a ledger reconciliation row.
        """
        wallet = await cls.get_or_create_wallet(db, user_id, commit=commit)

        # Check idempotency
        if idempotency_key:
            existing_q = await db.execute(
                select(WalletLedger).where(WalletLedger.idempotency_key == idempotency_key)
            )
            existing_ledger = existing_q.scalar_one_or_none()
            if existing_ledger:
                return existing_ledger, wallet

        curr = currency.upper()
        if curr not in ("COINS", "GEMS"):
            raise ValueError(f"Invalid currency: {curr}")

        current_balance = wallet.coins if curr == "COINS" else wallet.gems
        new_balance = current_balance + amount

        if new_balance < 0:
            raise ValueError(f"Insufficient {curr.lower()}: balance {current_balance}, required {-amount}")

        # Update wallet balance
        if curr == "COINS":
            wallet.coins = new_balance
        else:
            wallet.gems = new_balance

        ledger = WalletLedger(
            wallet_id=wallet.id,
            amount=amount,
            currency=curr,
            balance_after=new_balance,
            reason=reason,
            idempotency_key=idempotency_key,
        )
        db.add(ledger)
        if commit:
            await db.commit()
            await db.refresh(wallet)
            await db.refresh(ledger)
        else:
            await db.flush()
        return ledger, wallet

economy_service = EconomyService()
