from pydantic_settings import BaseSettings, SettingsConfigDict

_DEVELOPMENT_SECRET_KEY = "dev_secret_key_change_in_production_894729384729"

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    PROJECT_NAME: str = "Ludo Play API"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"
    SECRET_KEY: str = _DEVELOPMENT_SECRET_KEY
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    DATABASE_URL: str = "sqlite+aiosqlite:///./ludomaster.db"
    REDIS_URL: str = "redis://localhost:6379/0"
    CORS_ORIGINS: list[str] = []
    GOOGLE_CLIENT_IDS: list[str] = []
    GOOGLE_WEB_CLIENT_ID: str = ""
    GOOGLE_PLAY_GAMES_CLIENT_ID: str = ""
    GOOGLE_PLAY_GAMES_CLIENT_SECRET: str = ""
    GOOGLE_PLAY_PACKAGE_NAME: str = "com.ludomaster.app.mobile"
    GOOGLE_PLAY_SERVICE_ACCOUNT_FILE: str = ""
    GOOGLE_PLAY_BILLING_ENABLED: bool = False
    ALLOW_TEST_PURCHASES: bool = False
    ALLOW_TEST_AD_REWARDS: bool = False
    DAILY_AD_REWARD_LIMIT: int = 5

    MIN_ANDROID_VERSION: str = "1.0.0"
    MIN_IOS_VERSION: str = "1.0.0"
    LATEST_APP_VERSION: str = "1.0.0"
    MAINTENANCE_MODE: bool = False

settings = Settings()

if settings.ENVIRONMENT.lower() == "production":
    if settings.SECRET_KEY == _DEVELOPMENT_SECRET_KEY:
        raise ValueError("SECRET_KEY must be set to a unique value in production.")
    if not settings.DATABASE_URL.startswith("postgresql+asyncpg://"):
        raise ValueError("Production DATABASE_URL must use PostgreSQL with asyncpg.")
