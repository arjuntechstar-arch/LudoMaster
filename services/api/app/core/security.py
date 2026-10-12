import hashlib
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Optional
import bcrypt
import jwt
from app.core.config import settings

def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8")[:72],
            hashed_password.encode("utf-8"),
        )
    except Exception:
        return False

def get_password_hash(password: str) -> str:
    # Bcrypt maximum password input length is 72 bytes
    pwd_bytes = password.encode("utf-8")[:72]
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(pwd_bytes, salt).decode("utf-8")

def create_access_token(subject: str | Any, expires_delta: Optional[timedelta] = None) -> str:
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {"exp": expire, "sub": str(subject), "iat": datetime.now(timezone.utc)}
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

def create_refresh_token() -> tuple[str, str]:
    """Generates an opaque cryptographic refresh token and its SHA256 hash for storage."""
    raw_token = f"lm_rt_{uuid.uuid4().hex}_{uuid.uuid4().hex}"
    token_hash = hash_token(raw_token)
    return raw_token, token_hash

def hash_token(raw_token: str) -> str:
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()

def decode_access_token(token: str) -> Optional[str]:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload.get("sub")
    except Exception:
        return None

# Simple in-memory sliding window rate limiter for security & abuse prevention
_RATE_LIMIT_BUCKETS: dict[str, list[float]] = {}

def check_rate_limit(key: str, max_requests: int = 60, window_seconds: int = 60) -> bool:
    """Returns True if request is allowed, False if limit exceeded."""
    import time
    now = time.time()
    cutoff = now - window_seconds
    timestamps = _RATE_LIMIT_BUCKETS.get(key, [])
    # Filter out old requests
    timestamps = [t for t in timestamps if t > cutoff]
    if len(timestamps) >= max_requests:
        _RATE_LIMIT_BUCKETS[key] = timestamps
        return False
    timestamps.append(now)
    _RATE_LIMIT_BUCKETS[key] = timestamps
    return True
