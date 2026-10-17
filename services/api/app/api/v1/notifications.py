"""Notifications router: In-app notifications for artisans and buyers."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.models.notification import Notification
from app.schemas.notification import NotificationOut
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("", response_model=list[NotificationOut])
async def list_notifications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get in-app notifications for the logged in user."""
    stmt = (
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.id.desc())
        .limit(50)
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.patch("/{notification_id}/read", response_model=NotificationOut)
async def mark_notification_read(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mark a specific notification as read."""
    stmt = select(Notification).where(
        Notification.id == notification_id,
        Notification.user_id == current_user.id,
    )
    result = await db.execute(stmt)
    notif = result.scalar_one_or_none()

    if not notif:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")

    notif.is_read = True
    await db.commit()
    await db.refresh(notif)
    return notif


@router.post("/read-all")
async def mark_all_notifications_read(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mark all notifications as read for current user."""
    stmt = (
        update(Notification)
        .where(Notification.user_id == current_user.id)
        .values(is_read=True)
    )
    await db.execute(stmt)
    await db.commit()
    return {"message": "All notifications marked as read"}
