import asyncio
import re
import secrets

import httpx
from fastapi import HTTPException
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2 import id_token
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.profile import PlayerStats, Profile
from app.models.user import User, UserIdentity
from app.models.wallet import Wallet, WalletLedger


class SocialAuthService:
    async def verify_google(self, token: str) -> dict:
        audiences = set(settings.GOOGLE_CLIENT_IDS)
        if settings.GOOGLE_WEB_CLIENT_ID:
            audiences.add(settings.GOOGLE_WEB_CLIENT_ID)
        if not audiences:
            raise HTTPException(503, "Google sign-in is currently unavailable")
        try:
            claims = await asyncio.to_thread(
                id_token.verify_oauth2_token, token, GoogleRequest(), None,
            )
        except Exception as exc:
            raise HTTPException(401, "Invalid Google sign-in token") from exc
        if claims.get("aud") not in audiences or not claims.get("sub"):
            raise HTTPException(401, "Google token was issued for another application")
        return {"id": claims["sub"], "name": claims.get("name") or "Player"}

    async def verify_play_games(self, code: str) -> dict:
        if not settings.GOOGLE_PLAY_GAMES_CLIENT_ID or not settings.GOOGLE_PLAY_GAMES_CLIENT_SECRET:
            raise HTTPException(503, "Google Play Games sign-in is currently unavailable")
        try:
            return await self._exchange_play_games_code(code)
        except httpx.HTTPError as exc:
            raise HTTPException(503, "Google Play Games is temporarily unavailable") from exc

    async def _exchange_play_games_code(self, code: str) -> dict:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.post("https://oauth2.googleapis.com/token", data={
                "client_id": settings.GOOGLE_PLAY_GAMES_CLIENT_ID,
                "client_secret": settings.GOOGLE_PLAY_GAMES_CLIENT_SECRET,
                "code": code,
                "grant_type": "authorization_code",
                "redirect_uri": "",
            })
            if response.status_code != 200:
                raise HTTPException(401, "Invalid Google Play Games authorization")
            access_token = response.json().get("access_token")
            if not access_token:
                raise HTTPException(401, "Google Play Games authorization failed")
            player_response = await client.get(
                "https://games.googleapis.com/games/v1/players/me",
                headers={"Authorization": f"Bearer {access_token}"},
            )
            if player_response.status_code != 200:
                raise HTTPException(401, "Could not verify Google Play Games player")
            player = player_response.json()
            if not player.get("playerId"):
                raise HTTPException(401, "Google Play Games player identity is missing")
            return {"id": player["playerId"], "name": player.get("displayName") or "Player"}

    async def resolve_account(
        self, db: AsyncSession, provider: str, identity: dict,
        current_user: User | None, *, link: bool,
        profile_setup: dict | None = None,
    ) -> User:
        existing = (await db.execute(select(UserIdentity).where(
            UserIdentity.provider == provider,
            UserIdentity.provider_user_id == identity["id"],
        ))).scalar_one_or_none()
        if existing:
            if link and current_user and existing.user_id != current_user.id:
                raise HTTPException(409, "This social account is already linked to another player")
            user = (await db.execute(select(User).where(User.id == existing.user_id))).scalar_one()
            if user.status != "ACTIVE":
                raise HTTPException(403, "Player account is inactive")
            return user

        user = current_user if link else None
        if user is None or user.is_guest:
            if not profile_setup:
                raise HTTPException(
                    422,
                    "Choose a display name, username, and avatar in Sign Up before creating your account",
                )
            display_name = str(profile_setup.get("display_name", "")).strip()
            username = str(profile_setup.get("username", "")).strip().removeprefix("@").lower()
            avatar_id = str(profile_setup.get("avatar_id", ""))
            if not 2 <= len(display_name) <= 30:
                raise HTTPException(422, "Display name must be 2 to 30 characters")
            if not re.fullmatch(r"[a-z][a-z0-9_]{2,19}", username):
                raise HTTPException(422, "Use a valid username: 3 to 20 characters, starting with a letter")
            if avatar_id not in {f"avatar_{index}" for index in range(8)}:
                raise HTTPException(422, "Choose one of the available avatars")
            owner = await db.scalar(select(Profile.user_id).where(Profile.username == username))
            if owner is not None and (user is None or owner != user.id):
                raise HTTPException(409, "This username is already taken.")

        if user:
            if any(i.provider == provider for i in user.identities):
                raise HTTPException(409, "A different Google account is already connected")
            if user.is_guest:
                if not user.profile:
                    raise HTTPException(404, "Profile not found")
                user.profile.display_name = display_name
                user.profile.username = username
                user.profile.avatar_id = avatar_id
            user.is_guest = False
            user.is_verified = True
            # Device IDs are not credentials for the connected Google account.
            for guest_identity in list(user.identities):
                if guest_identity.provider == "GUEST":
                    await db.delete(guest_identity)
        else:
            user = User(is_guest=False, is_verified=True, status="ACTIVE")
            db.add(user)
            await db.flush()
            while True:
                player_id = f"LP-{secrets.randbelow(900000) + 100000}"
                if not (await db.execute(select(Profile.id).where(Profile.player_id == player_id))).scalar_one_or_none():
                    break
            db.add(Profile(
                user_id=user.id,
                player_id=player_id,
                display_name=display_name,
                username=username,
                avatar_id=avatar_id,
            ))
            db.add(PlayerStats(user_id=user.id))
            wallet = Wallet(user_id=user.id, coins=1000, gems=10)
            db.add(wallet)
            await db.flush()
            db.add(WalletLedger(
                wallet_id=wallet.id, amount=1000, currency="COINS", balance_after=1000,
                reason="WELCOME_BONUS", idempotency_key=f"welcome_{user.id}",
            ))
        db.add(UserIdentity(user_id=user.id, provider=provider, provider_user_id=identity["id"]))
        await db.commit()
        await db.refresh(user)
        return user


social_auth_service = SocialAuthService()
