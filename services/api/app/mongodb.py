"""MongoDB connection, collection definitions, and index management."""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone
from typing import Any
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from pymongo import ASCENDING, DESCENDING, IndexModel

from app.config import settings

logger = logging.getLogger("kalasathi.mongodb")

_mongo_client: AsyncIOMotorClient | None = None
_mongo_client_loop: asyncio.AbstractEventLoop | None = None


def get_mongo_client() -> AsyncIOMotorClient:
    global _mongo_client, _mongo_client_loop
    try:
        current_loop = asyncio.get_running_loop()
    except RuntimeError:
        current_loop = None

    if _mongo_client is not None and _mongo_client_loop is not None:
        if _mongo_client_loop.is_closed() or _mongo_client_loop is not current_loop:
            _mongo_client = None
            _mongo_client_loop = None

    if _mongo_client is None:
        uri = getattr(settings, "MONGODB_URI", "mongodb://localhost:27017/kalasathi")
        _mongo_client = AsyncIOMotorClient(uri, serverSelectionTimeoutMS=2000)
        _mongo_client_loop = current_loop
    return _mongo_client


def get_mongo_database() -> AsyncIOMotorDatabase:
    client = get_mongo_client()
    uri = getattr(settings, "MONGODB_URI", "mongodb://localhost:27017/kalasathi")
    db_name = getattr(settings, "MONGODB_DB_NAME", None)
    if not db_name:
        if "/" in uri.split("?")[0]:
            part = uri.split("?")[0].rsplit("/", 1)[-1]
            db_name = part if part and not part.startswith(":") else "kalasathi"
        else:
            db_name = "kalasathi"
    return client[db_name]


async def init_mongo_indexes() -> bool:
    """Ensure required unique and query indexes exist in MongoDB."""
    try:
        db = get_mongo_database()

        # 1. image_jobs collection
        image_jobs = db["image_jobs"]
        job_indexes = [
            IndexModel([("job_id", ASCENDING)], unique=True, name="idx_job_id_unique"),
            IndexModel([("artisan_id", ASCENDING)], name="idx_artisan_id"),
            IndexModel([("status", ASCENDING)], name="idx_status"),
            IndexModel([("created_at", DESCENDING)], name="idx_created_at_desc"),
            IndexModel([("crewai_execution_id", ASCENDING)], name="idx_crewai_exec_id"),
            IndexModel([("output_json.status", ASCENDING)], name="idx_image_output_status"),
        ]
        await image_jobs.create_indexes(job_indexes)

        # 2. products collection
        products = db["products"]
        product_indexes = [
            IndexModel([("product_id", ASCENDING)], unique=True, name="idx_product_id_unique"),
            IndexModel([("artisan_id", ASCENDING)], name="idx_product_artisan_id"),
            IndexModel([("status", ASCENDING)], name="idx_product_status"),
            IndexModel([("image_job_id", ASCENDING)], name="idx_product_image_job_id"),
            IndexModel([("created_at", DESCENDING)], name="idx_product_created_at_desc"),
        ]
        await products.create_indexes(product_indexes)
        logger.info("MongoDB indexes successfully created for image_jobs and products")
        return True
    except Exception as exc:
        logger.warning(f"MongoDB index setup encountered: {exc}. Proceeding with dynamic operation.")
        return False


# ─── Data Access Helpers ──────────────────────────────────────────────────────

async def save_image_job_mongo(job_doc: dict[str, Any]) -> dict[str, Any]:
    """Persist or update an image job document in MongoDB idempotently."""
    db = get_mongo_database()
    now = datetime.now(timezone.utc)
    job_id = str(job_doc["job_id"])

    payload = dict(job_doc)
    created_at = payload.pop("created_at", None) or now
    payload["job_id"] = job_id
    payload["artisan_id"] = str(job_doc.get("artisan_id", ""))
    payload["updated_at"] = now

    await db["image_jobs"].update_one(
        {"job_id": job_id},
        {"$set": payload, "$setOnInsert": {"created_at": created_at}},
        upsert=True,
    )
    saved = await db["image_jobs"].find_one({"job_id": job_id}, {"_id": 0})
    return saved or payload


async def get_image_job_mongo(job_id: str, artisan_id: str | int | None = None) -> dict[str, Any] | None:
    db = get_mongo_database()
    query: dict[str, Any] = {"job_id": str(job_id)}
    if artisan_id is not None:
        query["artisan_id"] = str(artisan_id)
    doc = await db["image_jobs"].find_one(query, {"_id": 0})
    return doc


async def list_artisan_jobs_mongo(artisan_id: str | int, limit: int = 50) -> list[dict[str, Any]]:
    db = get_mongo_database()
    cursor = db["image_jobs"].find(
        {"artisan_id": str(artisan_id)},
        {"_id": 0},
    ).sort("created_at", DESCENDING).limit(limit)
    return await cursor.to_list(length=limit)


async def update_job_selection_mongo(job_id: str, artisan_id: str | int, selected_ids: list[str]) -> dict[str, Any] | None:
    db = get_mongo_database()
    now = datetime.now(timezone.utc)
    res = await db["image_jobs"].find_one_and_update(
        {"job_id": str(job_id), "artisan_id": str(artisan_id)},
        {"$set": {
            "selected_variant_ids": selected_ids,
            "output_json.selected_variant_ids": selected_ids,
            "output_json.agent_output.selected_variant_ids": selected_ids,
            "updated_at": now,
        }},
        return_document=True,
        projection={"_id": 0},
    )
    return res


async def save_product_mongo(product_doc: dict[str, Any]) -> dict[str, Any]:
    db = get_mongo_database()
    now = datetime.now(timezone.utc)
    prod_id = str(product_doc["product_id"])

    payload = dict(product_doc)
    created_at = payload.pop("created_at", None) or now
    payload["product_id"] = prod_id
    payload["artisan_id"] = str(product_doc.get("artisan_id", ""))
    payload["updated_at"] = now

    await db["products"].update_one(
        {"product_id": prod_id},
        {"$set": payload, "$setOnInsert": {"created_at": created_at}},
        upsert=True,
    )
    saved = await db["products"].find_one({"product_id": prod_id}, {"_id": 0})
    return saved or payload


async def get_product_mongo(product_id: str | int) -> dict[str, Any] | None:
    db = get_mongo_database()
    return await db["products"].find_one({"product_id": str(product_id)}, {"_id": 0})


async def publish_product_mongo(product_id: str | int, artisan_id: str | int) -> dict[str, Any] | None:
    db = get_mongo_database()
    now = datetime.now(timezone.utc)
    res = await db["products"].find_one_and_update(
        {"product_id": str(product_id), "artisan_id": str(artisan_id)},
        {"$set": {"status": "published", "published_at": now, "updated_at": now}},
        return_document=True,
        projection={"_id": 0},
    )
    return res
