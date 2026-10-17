"""Real-time SSE events router for live frontend sync."""
from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from app.utils.events import event_broker

router = APIRouter(prefix="/events", tags=["Real-time Events"])


@router.get("/stream")
async def events_stream():
    """Server-Sent Events (SSE) endpoint providing live platform updates."""
    return StreamingResponse(
        event_broker.subscribe(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
