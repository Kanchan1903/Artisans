"""Storage utility supporting Cloudinary, MinIO / S3, and local filesystem fallback."""
import io
import json
import os
import uuid
from pathlib import Path
from urllib.parse import urlparse
from app.config import settings

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


class StorageService:
    def __init__(self):
        self._client = None
        self._checked = False
        self._available = False

    def _has_cloudinary(self) -> bool:
        return bool(
            settings.CLOUDINARY_CLOUD_NAME
            and settings.CLOUDINARY_API_KEY
            and settings.CLOUDINARY_API_SECRET
        )

    def _get_client(self):
        if not self._checked:
            self._checked = True
            try:
                import socket
                host = settings.MINIO_ENDPOINT.split(":")[0]
                port = int(settings.MINIO_ENDPOINT.split(":")[1]) if ":" in settings.MINIO_ENDPOINT else 9000
                with socket.create_connection((host, port), timeout=0.5):
                    pass
                from minio import Minio
                self._client = Minio(
                    settings.MINIO_ENDPOINT,
                    access_key=settings.MINIO_ACCESS_KEY,
                    secret_key=settings.MINIO_SECRET_KEY,
                    secure=settings.MINIO_USE_SSL,
                )
                self._available = True
            except Exception:
                self._client = None
                self._available = False
        return self._client if self._available else None

    async def upload_file(self, file_bytes: bytes, filename: str, content_type: str = "image/jpeg") -> str:
        """Upload a file to Cloudinary if configured, else MinIO if available, otherwise local filesystem."""
        ext = os.path.splitext(filename)[1] or ".jpg"
        unique_name = f"{uuid.uuid4().hex}{ext}"

        # 1. Cloudinary upload if configured
        if self._has_cloudinary():
            try:
                import cloudinary
                import cloudinary.uploader
                cloudinary.config(
                    cloud_name=settings.CLOUDINARY_CLOUD_NAME,
                    api_key=settings.CLOUDINARY_API_KEY,
                    api_secret=settings.CLOUDINARY_API_SECRET,
                    secure=True,
                )
                res = cloudinary.uploader.upload(
                    file_bytes,
                    public_id=os.path.splitext(unique_name)[0],
                    resource_type="image",
                    folder="kalasathi",
                )
                if res and res.get("secure_url"):
                    return res["secure_url"]
            except Exception:
                pass

        # 2. MinIO / S3 upload if available
        client = self._get_client()
        if client:
            try:
                data_stream = io.BytesIO(file_bytes)
                if not client.bucket_exists(settings.MINIO_BUCKET):
                    client.make_bucket(settings.MINIO_BUCKET)
                client.set_bucket_policy(
                    settings.MINIO_BUCKET,
                    json.dumps({
                        "Version": "2012-10-17",
                        "Statement": [{
                            "Effect": "Allow",
                            "Principal": {"AWS": ["*"]},
                            "Action": ["s3:GetObject"],
                            "Resource": [f"arn:aws:s3:::{settings.MINIO_BUCKET}/*"],
                        }],
                    }),
                )
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
                self._available = False

        # 3. Local storage fallback - fast and reliable
        if settings.ENVIRONMENT.lower() == "production":
            raise RuntimeError("Configured image storage is unavailable in production")
        file_path = UPLOAD_DIR / unique_name
        with open(file_path, "wb") as f:
            f.write(file_bytes)
        api_base = settings.PUBLIC_API_URL.rstrip("/")
        return f"{api_base}/uploads/{unique_name}"

    async def delete_file(self, url: str) -> None:
        """Best-effort deletion for an image removed from a draft."""
        parsed = urlparse(url)
        path_parts = [part for part in parsed.path.split("/") if part]

        if "res.cloudinary.com" in (parsed.hostname or "") and self._has_cloudinary():
            try:
                import cloudinary
                import cloudinary.uploader
                cloudinary.config(
                    cloud_name=settings.CLOUDINARY_CLOUD_NAME,
                    api_key=settings.CLOUDINARY_API_KEY,
                    api_secret=settings.CLOUDINARY_API_SECRET,
                    secure=True,
                )
                upload_index = path_parts.index("upload")
                public_parts = path_parts[upload_index + 1:]
                if public_parts and public_parts[0].startswith("v") and public_parts[0][1:].isdigit():
                    public_parts = public_parts[1:]
                if public_parts:
                    public_id = "/".join(public_parts)
                    public_id = os.path.splitext(public_id)[0]
                    cloudinary.uploader.destroy(public_id, resource_type="image")
            except Exception:
                pass
            return

        if path_parts and path_parts[0] == settings.MINIO_BUCKET:
            client = self._get_client()
            if client and len(path_parts) > 1:
                try:
                    client.remove_object(settings.MINIO_BUCKET, "/".join(path_parts[1:]))
                except Exception:
                    pass
            return

        if len(path_parts) == 2 and path_parts[0] == "uploads":
            filename = Path(path_parts[1]).name
            target = (UPLOAD_DIR / filename).resolve()
            if target.parent == UPLOAD_DIR.resolve():
                try:
                    target.unlink(missing_ok=True)
                except OSError:
                    pass


storage = StorageService()
