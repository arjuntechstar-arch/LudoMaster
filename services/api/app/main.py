import time
import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.api.v1.auth import router as auth_router
from app.api.v1.blocks import router as blocks_router
from app.api.v1.config import router as config_router
from app.api.v1.friends import router as friends_router
from app.api.v1.matches import router as matches_router
from app.api.v1.matchmaking import router as matchmaking_router
from app.api.v1.reports import router as reports_router
from app.api.v1.rooms import router as rooms_router
from app.api.v1.users import players_router, router as users_router
from app.api.v1.economy import router as economy_router
from app.api.v1.inventory import router as inventory_router
from app.api.v1.missions import router as missions_router
from app.api.v1.achievements import router as achievements_router
from app.api.v1.tournaments import router as tournaments_router
from app.api.v1.seasons import router as seasons_router
from app.api.v1.leaderboards import router as leaderboards_router
from app.api.v1.admin import router as admin_router
from app.api.v1.purchases import router as purchases_router
from app.api.v1.notifications import router as notifications_router
from app.api.v1.clubs import router as clubs_router
from app.api.v1.voice import router as voice_router
from services.realtime.gateway import router as ws_router
from app.core.config import settings
from app.db.base import Base
from app.db.session import engine
import app.models

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Auto-create tables for local development and tests. Production schema
    # changes are applied explicitly with Alembic before service startup.
    if settings.ENVIRONMENT.lower() != "production":
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

    yield
    await engine.dispose()

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan,
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS or ([] if settings.ENVIRONMENT.lower() == "production" else ["*"]),
    allow_credentials=bool(settings.CORS_ORIGINS),
    allow_methods=["*"],
    allow_headers=["*"],
)

# Observability Middleware: Correlation ID & Process Time
@app.middleware("http")
async def add_process_time_and_correlation_id(request: Request, call_next):
    correlation_id = request.headers.get("X-Correlation-ID", str(uuid.uuid4()))
    start_time = time.perf_counter()

    response = await call_next(request)

    process_time = (time.perf_counter() - start_time) * 1000.0
    response.headers["X-Correlation-ID"] = correlation_id
    response.headers["X-Process-Time-Ms"] = f"{process_time:.2f}"
    return response

# Mount API Routers
app.include_router(auth_router, prefix=settings.API_V1_STR)
app.include_router(users_router, prefix=settings.API_V1_STR)
app.include_router(players_router, prefix=settings.API_V1_STR)
app.include_router(config_router, prefix=settings.API_V1_STR)
app.include_router(rooms_router, prefix=settings.API_V1_STR)
app.include_router(matchmaking_router, prefix=settings.API_V1_STR)
app.include_router(matches_router, prefix=settings.API_V1_STR)
app.include_router(friends_router, prefix=settings.API_V1_STR)
app.include_router(blocks_router, prefix=settings.API_V1_STR)
app.include_router(reports_router, prefix=settings.API_V1_STR)
app.include_router(economy_router, prefix=settings.API_V1_STR)
app.include_router(inventory_router, prefix=settings.API_V1_STR)
app.include_router(missions_router, prefix=settings.API_V1_STR)
app.include_router(achievements_router, prefix=settings.API_V1_STR)
app.include_router(tournaments_router, prefix=settings.API_V1_STR)
app.include_router(seasons_router, prefix=settings.API_V1_STR)
app.include_router(leaderboards_router, prefix=settings.API_V1_STR)
app.include_router(admin_router, prefix=settings.API_V1_STR)
app.include_router(purchases_router, prefix=settings.API_V1_STR)
app.include_router(notifications_router, prefix=settings.API_V1_STR)
app.include_router(clubs_router, prefix=settings.API_V1_STR)
app.include_router(voice_router, prefix=settings.API_V1_STR)
app.include_router(ws_router)

@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "service": "ludomaster-api",
        "version": "1.0.0",
    }
