"""JWT authentication, OTP generation, and password utilities."""
import random
import string
from datetime import datetime, timedelta, timezone
from typing import Any

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ─── JWT ──────────────────────────────────────────────────────────────────────

def create_access_token(subject: int | str, extra: dict[str, Any] | None = None) -> str:
    """Create a signed JWT access token."""
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=settings.JWT_EXPIRE_MINUTES)
    payload: dict[str, Any] = {
        "sub": str(subject),
        "iat": now,
        "exp": expire,
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> dict[str, Any] | None:
    """Decode and verify a JWT. Returns payload dict or None on failure."""
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        return payload
    except JWTError:
        return None


# ─── OTP ──────────────────────────────────────────────────────────────────────

def generate_otp(length: int = 6) -> str:
    """Generate a numeric OTP of the given length."""
    return "".join(random.choices(string.digits, k=length))


def otp_expiry() -> datetime:
    """Return the expiry datetime for a new OTP."""
    return datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)


async def send_otp(phone: str, code: str) -> None:
    """Send OTP via the configured provider (mock just prints it)."""
    if settings.OTP_PROVIDER == "mock":
        print(f"[OTP MOCK] Phone: {phone}  Code: {code}")
        return
    # TODO: Integrate Twilio / MSG91 here
    raise NotImplementedError(f"OTP provider '{settings.OTP_PROVIDER}' not implemented yet.")
