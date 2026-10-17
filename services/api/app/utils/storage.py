"""Storage utility supporting MinIO / S3 and local filesystem fallback."""
import io
import os
import uuid
from pathlib import Path
from app.config import settings

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


class StorageService:
    def __init__(self):
        self._client = None
        self._checked = False

    def _get_client(self):
        if not self._checked:
            self._checked = True
            try:
                from minio import Minio
                client = Minio(
                    settings.MINIO_ENDPOINT,
                    access_key=settings.MINIO_ACCESS_KEY,
                    secret_key=settings.MINIO_SECRET_KEY,
                    secure=settings.MINIO_USE_SSL,
                )
                self._client = client
            except Exception:
                self._client = None
        return self._client

    async def upload_file(self, file_bytes: bytes, filename: str, content_type: str = "image/jpeg") -> str:
        """Upload a file to MinIO if available, otherwise save to local filesystem."""
        ext = os.path.splitext(filename)[1] or ".jpg"
        unique_name = f"{uuid.uuid4().hex}{ext}"

        client = self._get_client()
        if client:
            try:
                data_stream = io.BytesIO(file_bytes)
                # Ensure bucket exists
                if not client.bucket_exists(settings.MINIO_BUCKET):
                    client.make_bucket(settings.MINIO_BUCKET)
                client.put_object(
                    settings.MINIO_BUCKET,
                    unique_name,
                    data_stream,
                    length=len(file_bytes),
                    content_type=content_type,
                )
                public_base = settings.MINIO_PUBLIC_URL.rstrip("/")
                if not public_base:
                    protocol = "https" if settings.MINIO_USE_SSL else "http"
                    endpoint = "localhost:9000" if settings.MINIO_ENDPOINT.startswith("minio:") else settings.MINIO_ENDPOINT
                    public_base = f"{protocol}://{endpoint}"
                return f"{public_base}/{settings.MINIO_BUCKET}/{unique_name}"
            except Exception:
                # MinIO connection failed or timed out, fall back to local disk
                pass

        # Local storage fallback
        file_path = UPLOAD_DIR / unique_name
        with open(file_path, "wb") as f:
            f.write(file_bytes)
        api_base = settings.PUBLIC_API_URL.rstrip("/")
        return f"{api_base}/uploads/{unique_name}"


storage = StorageService()
