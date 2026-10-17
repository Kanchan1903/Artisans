"""Aggregate all v1 API routers."""
from fastapi import APIRouter
from app.api.v1.auth import router as auth_router
from app.api.v1.artisans import router as artisans_router
from app.api.v1.products import router as products_router
from app.api.v1.orders import router as orders_router
from app.api.v1.inquiries import router as inquiries_router
from app.api.v1.earnings import router as earnings_router
from app.api.v1.notifications import router as notifications_router
from app.api.v1.admin import router as admin_router
from app.api.v1.events import router as events_router
from app.api.v1.ai import router as ai_router

api_router = APIRouter()
api_router.include_router(auth_router)
api_router.include_router(artisans_router)
api_router.include_router(products_router)
api_router.include_router(orders_router)
api_router.include_router(inquiries_router)
api_router.include_router(earnings_router)
api_router.include_router(notifications_router)
api_router.include_router(admin_router)
api_router.include_router(events_router)
api_router.include_router(ai_router)
