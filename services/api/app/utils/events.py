"""Real-time event broadcasting via async queue / Server-Sent Events (SSE)."""
import asyncio
import json
from datetime import datetime, timezone
from typing import Any, AsyncGenerator


class EventBroker:
    def __init__(self):
        self._subscribers: set[asyncio.Queue] = set()

    async def subscribe(self) -> AsyncGenerator[str, None]:
        """Subscribe to real-time events. Yields formatted SSE strings."""
        queue: asyncio.Queue = asyncio.Queue()
        self._subscribers.add(queue)
        try:
            # Send initial ping event
            yield f"event: connected\ndata: {json.dumps({'message': 'Connected to KalaSathi Live Stream'})}\n\n"
            while True:
                data = await queue.get()
                yield data
        except asyncio.CancelledError:
            pass
        finally:
            self._subscribers.remove(queue)

    async def publish(self, event_type: str, payload: dict[str, Any]):
        """Broadcast an event to all connected clients."""
        payload_with_meta = {
            **payload,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        sse_message = f"event: {event_type}\ndata: {json.dumps(payload_with_meta)}\n\n"
        for subscriber in list(self._subscribers):
            try:
                subscriber.put_nowait(sse_message)
            except Exception:
                pass


event_broker = EventBroker()
