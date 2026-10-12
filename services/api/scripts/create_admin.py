"""Create an initial admin account from an interactive terminal."""

import asyncio
import getpass
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select

from app.core.security import get_password_hash
from app.db.session import async_session_maker, engine
from app.models.admin import AdminUser


async def create_admin() -> None:
    username = input("Admin username: ").strip()
    email = input("Admin email: ").strip().lower()
    password = getpass.getpass("Admin password (16+ characters): ")
    confirmation = getpass.getpass("Confirm admin password: ")

    if not username or not email:
        raise SystemExit("Username and email are required.")
    if len(password) < 16:
        raise SystemExit("Use an admin password with at least 16 characters.")
    if password != confirmation:
        raise SystemExit("Passwords do not match.")

    async with async_session_maker() as session:
        existing = await session.execute(
            select(AdminUser).where(
                (AdminUser.username == username) | (AdminUser.email == email)
            )
        )
        if existing.scalar_one_or_none() is not None:
            raise SystemExit("An admin with that username or email already exists.")

        session.add(
            AdminUser(
                username=username,
                email=email,
                hashed_password=get_password_hash(password),
                role="SUPER_ADMIN",
                is_active=True,
            )
        )
        await session.commit()

    print(f"Created super admin {username!r}.")


async def main() -> None:
    try:
        await create_admin()
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
