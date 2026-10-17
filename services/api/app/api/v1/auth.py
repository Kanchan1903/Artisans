import time
from collections import defaultdict
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User, OTPCode, UserRole, Language
from app.models.artisan import ArtisanProfile
from app.schemas.auth import OTPRequest, OTPVerify, TokenResponse, UserOut, UserUpdate
from app.core.security import generate_otp, otp_expiry, create_access_token
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])

# In-memory sliding-window rate limiter per phone number
_OTP_SEND_HISTORY: dict[str, list[float]] = defaultdict(list)
_OTP_FAILED_ATTEMPTS: dict[str, list[float]] = defaultdict(list)

MAX_OTP_SEND_PER_WINDOW = 5
OTP_SEND_WINDOW_SECONDS = 600  # 10 minutes

MAX_FAILED_VERIFY_ATTEMPTS = 5
LOCKOUT_WINDOW_SECONDS = 300   # 5 minutes


@router.post("/otp/send")
async def send_otp_endpoint(payload: OTPRequest, db: AsyncSession = Depends(get_db)):
    """Generate and dispatch a 6-digit OTP for phone verification with rate limiting."""
    phone = payload.phone.strip()

    # Rate limiting check
    now = time.time()
    _OTP_SEND_HISTORY[phone] = [t for t in _OTP_SEND_HISTORY[phone] if now - t < OTP_SEND_WINDOW_SECONDS]
    if len(_OTP_SEND_HISTORY[phone]) >= MAX_OTP_SEND_PER_WINDOW:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many OTP requests for this phone number. Please wait a few minutes before trying again.",
        )
    _OTP_SEND_HISTORY[phone].append(now)
    # In development/mock mode, generate OTP (123456 is also always accepted for ease of testing)
    code = "123456" if phone.endswith("0000") else generate_otp(6)

    # Invalidate previous unused OTPs for this phone
    stmt = select(OTPCode).where(OTPCode.phone == phone, OTPCode.is_used == False)
    result = await db.execute(stmt)
    existing_otps = result.scalars().all()
    for otp in existing_otps:
        otp.is_used = True

    # Save new OTP
    otp_record = OTPCode(
        phone=phone,
        code=code,
        expires_at=otp_expiry(),
        is_used=False,
    )
    db.add(otp_record)
    await db.commit()

    return {
        "message": "OTP sent successfully",
        "phone": phone,
        "mock_code": code,  # Provided in response for easy local testing
    }


@router.post("/otp/verify", response_model=TokenResponse)
async def verify_otp_endpoint(payload: OTPVerify, db: AsyncSession = Depends(get_db)):
    """Verify phone OTP, create or retrieve user, and issue JWT access token."""
    phone = payload.phone.strip()
    code = payload.code.strip()

    # Lockout check for brute force attempts
    now = time.time()
    _OTP_FAILED_ATTEMPTS[phone] = [t for t in _OTP_FAILED_ATTEMPTS[phone] if now - t < LOCKOUT_WINDOW_SECONDS]
    if len(_OTP_FAILED_ATTEMPTS[phone]) >= MAX_FAILED_VERIFY_ATTEMPTS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many failed verification attempts. Please wait 5 minutes before trying again.",
        )

    # Verify code (accept 123456 as master test OTP or check database record)
    valid = False
    if code == "123456":
        valid = True
    else:
        stmt = (
            select(OTPCode)
            .where(
                OTPCode.phone == phone,
                OTPCode.code == code,
                OTPCode.is_used == False,
                OTPCode.expires_at > datetime.now(timezone.utc),
            )
            .order_by(OTPCode.id.desc())
        )
        result = await db.execute(stmt)
        otp_record = result.scalars().first()
        if otp_record:
            otp_record.is_used = True
            valid = True

    if not valid:
        _OTP_FAILED_ATTEMPTS[phone].append(now)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP code",
        )

    # Clear failed attempts on successful verification
    _OTP_FAILED_ATTEMPTS.pop(phone, None)

    # Check if user exists, else create
    stmt = select(User).where(User.phone == phone)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        requested_role = payload.role if hasattr(payload, "role") else UserRole.buyer
        user = User(
            phone=phone,
            name=payload.name or f"User {phone[-4:]}",
            role=requested_role,
            language=payload.language or Language.en,
            is_verified=True,
        )
        db.add(user)
        await db.flush()

        # Create artisan profile only for artisan role
        if requested_role == UserRole.artisan:
            artisan_profile = ArtisanProfile(
                user_id=user.id,
                is_approved=True,
            )
            db.add(artisan_profile)

        await db.commit()
        await db.refresh(user)
    else:
        user.is_verified = True
        if payload.name and not user.name:
            user.name = payload.name
        if payload.language:
            user.language = payload.language
        await db.commit()
        await db.refresh(user)

    # Query artisan profile if role is artisan
    artisan_id = None
    if user.role == UserRole.artisan:
        stmt = select(ArtisanProfile).where(ArtisanProfile.user_id == user.id)
        result = await db.execute(stmt)
        profile = result.scalar_one_or_none()
        if not profile:
            profile = ArtisanProfile(user_id=user.id, is_approved=True)
            db.add(profile)
            await db.commit()
            await db.refresh(profile)
        artisan_id = profile.id

    token = create_access_token(
        subject=user.id,
        extra={
            "role": user.role.value,
            "phone": user.phone,
            "artisan_id": artisan_id,
        },
    )

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        role=user.role,
        name=user.name,
        language=user.language,
        is_artisan=user.role == UserRole.artisan,
        artisan_id=artisan_id,
    )


@router.get("/me", response_model=UserOut)
async def get_my_profile(current_user: User = Depends(get_current_user)):
    """Get current authenticated user profile."""
    return current_user


@router.patch("/me", response_model=UserOut)
async def update_my_profile(
    payload: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update current user details (name, email, language, fcm_token)."""
    if payload.name is not None:
        current_user.name = payload.name
    if payload.email is not None:
        current_user.email = payload.email
    if payload.language is not None:
        current_user.language = payload.language
    if payload.fcm_token is not None:
        current_user.fcm_token = payload.fcm_token

    await db.commit()
    await db.refresh(current_user)
    return current_user
