import asyncio

import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool
from starlette.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.db.base import Base
from app.db.session import get_db
from app.main import app


client = TestClient(app)


@pytest.fixture(scope="module", autouse=True)
def isolated_security_database():
    """Provide the standalone security suite with an isolated SQLite schema."""
    test_engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        echo=False,
        poolclass=StaticPool,
    )
    session_maker = async_sessionmaker(
        bind=test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async def create_schema():
        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

    async def drop_schema():
        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.drop_all)
        await test_engine.dispose()

    async def override_get_db():
        async with session_maker() as session:
            try:
                yield session
            except Exception:
                await session.rollback()
                raise

    asyncio.run(create_schema())
    app.dependency_overrides[get_db] = override_get_db
    try:
        yield
    finally:
        app.dependency_overrides.pop(get_db, None)
        asyncio.run(drop_schema())


@pytest.mark.parametrize(
    "path",
    [
        "/api/v1/auth/export-data",
        "/api/v1/friends",
    ],
)
def test_protected_endpoints_do_not_accept_anonymous_requests(path):
    response = client.get(path)
    assert response.status_code in (401, 403), (path, response.status_code, response.text)


def test_protected_endpoint_rejects_malformed_bearer_token():
    response = client.get(
        "/api/v1/auth/export-data",
        headers={"Authorization": "Bearer definitely-not-a-jwt"},
    )
    assert response.status_code in (401, 403)


def test_realtime_socket_rejects_invalid_token():
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect(
            "/ws/match/non-existent-match?token=definitely-not-a-jwt"
        ):
            pass


def test_guest_auth_does_not_echo_sensitive_token_in_headers():
    response = client.post(
        "/api/v1/auth/guest",
        json={"device_id": "security-regression-device"},
    )
    assert response.status_code == 200
    token = response.json().get("access_token")
    assert token
    serialized_headers = "\n".join(f"{k}:{v}" for k, v in response.headers.items())
    assert token not in serialized_headers


def test_common_security_headers_are_not_dangerously_permissive():
    response = client.get("/health")
    allow_origin = response.headers.get("access-control-allow-origin")
    allow_credentials = response.headers.get("access-control-allow-credentials")
    assert not (allow_origin == "*" and allow_credentials == "true")
