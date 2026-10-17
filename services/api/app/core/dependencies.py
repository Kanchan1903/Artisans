"""FastAPI dependencies for authentication, role verification, and DB access."""
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User, UserRole
from app.models.artisan import ArtisanProfile
from app.core.security import decode_access_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token", auto_error=False)


async def get_current_user(
    token: str | None = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Dependency that returns the authenticated User."""
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token missing",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token subject invalid",
        )

    stmt = select(User).where(User.id == int(user_id)).options(selectinload(User.artisan_profile))
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is deactivated",
        )
    return user


async def get_optional_user(
    token: str | None = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User | None:
    """Dependency that returns the authenticated User if token is present, else None."""
    if not token:
        return None
    try:
        return await get_current_user(token=token, db=db)
    except HTTPException:
        return None


async def get_current_artisan(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> tuple[User, ArtisanProfile]:
    """Dependency ensuring the user is an artisan and returning their profile."""
    if user.role != UserRole.artisan:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access restricted to artisans",
        )

    stmt = select(ArtisanProfile).where(ArtisanProfile.user_id == user.id)
    result = await db.execute(stmt)
    profile = result.scalar_one_or_none()

    if not profile:
        # Automatically provision empty profile for registered artisan
        profile = ArtisanProfile(user_id=user.id, is_approved=True)
        db.add(profile)
        await db.commit()
        await db.refresh(profile)

    return user, profile


async def get_current_admin(
    user: User = Depends(get_current_user),
) -> User:
    """Dependency ensuring the user has the admin role."""
    if user.role != UserRole.admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access restricted to platform administrators",
        )
    return user
