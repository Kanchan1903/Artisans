"""Validate CrewAI final JSON. Never invent URLs, keys, or success statuses."""
from __future__ import annotations

import json
import re
from typing import Any


RETAKE_SEGMENTATION = {
    "failed",
    "fail",
    "failure",
    "error",
    "retake",
    "retake_required",
    "needs_retake",
    "low_quality",
    "unsafe",
    "rejected",
}

SAFE_SEGMENTATION = {"ok", "success", "passed", "pass", "completed", "complete", "ready"}


class InvalidImageJobResult(ValueError):
    pass


def _as_dict(value: Any) -> dict[str, Any] | None:
    if isinstance(value, dict):
        return value
    if isinstance(value, str):
        extracted = _extract_json_object(value)
        if extracted is not None:
            return extracted
    return None


def _extract_json_object(text: str) -> dict[str, Any] | None:
    if not text or not text.strip():
        return None
    raw = text.strip()
    fenced = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", raw, re.DOTALL | re.IGNORECASE)
    if fenced:
        raw = fenced.group(1)
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            return parsed
        if isinstance(parsed, str):
            return _extract_json_object(parsed)
    except json.JSONDecodeError:
        start = raw.find("{")
        end = raw.rfind("}")
        if start >= 0 and end > start:
            try:
                parsed = json.loads(raw[start : end + 1])
                if isinstance(parsed, dict):
                    return parsed
            except json.JSONDecodeError:
                return None
    return None


def parse_crewai_status_payload(status_payload: dict[str, Any]) -> dict[str, Any]:
    """Turn a CrewAI /status response into a normalized processing snapshot."""
    status = str(status_payload.get("status") or "").lower()
    if status in ("running", "started", "pending", "queued", "in_progress"):
        return {
            "job_status": "running",
            "current_task": status_payload.get("current_task"),
            "progress": status_payload.get("progress"),
        }
    if status in ("error", "failed", "failure"):
        return {
            "job_status": "failed",
            "errors": [status_payload.get("error") or status_payload.get("message") or "CrewAI execution failed"],
        }
    if status not in ("completed", "complete", "success"):
        return {"job_status": "running"}

    result = status_payload.get("result", status_payload.get("output"))
    parsed = normalize_final_json(result)
    parsed["crewai_execution_id"] = (
        status_payload.get("kickoff_id")
        or status_payload.get("execution_id")
        or parsed.get("crewai_execution_id")
    )
    return parsed


def normalize_final_json(result: Any, expected_job_id: str | None = None) -> dict[str, Any]:
    """Validate the crew's final JSON and return a persistence-ready dict.

    A completed kickoff is not treated as successful processing unless this
    payload contains real image URLs (or an explicit retake/failure).
    """
    data = _as_dict(result)
    if data is None:
        raise InvalidImageJobResult("CrewAI completed without a JSON object result")

    # Nested common wrappers
    for key in ("final_json", "final_output", "output", "data", "result"):
        nested = data.get(key)
        nested_dict = _as_dict(nested)
        if nested_dict and (nested_dict.get("variants") or nested_dict.get("variations") or nested_dict.get("segmentation_status")):
            data = nested_dict
            break

    # Check job_id match if provided
    if expected_job_id and data.get("job_id"):
        if str(data["job_id"]).strip() != str(expected_job_id).strip():
            raise InvalidImageJobResult(
                f"CrewAI result job_id '{data['job_id']}' does not match expected '{expected_job_id}'"
            )

    segmentation = str(
        data.get("segmentation_status")
        or data.get("segment_status")
        or data.get("cutout_status")
        or ""
    ).lower()
    requires_review = bool(data.get("requires_review") or data.get("review_required"))
    warnings = _as_str_list(data.get("quality_warnings") or data.get("warnings"))
    errors = _as_str_list(data.get("errors") or data.get("error"))

    # Explicit success: false check
    if data.get("success") is False:
        return {
            "job_status": "failed",
            "segmentation_status": segmentation or "failed",
            "requires_review": True,
            "quality_warnings": warnings,
            "errors": errors or [data.get("error") or data.get("message") or "CrewAI returned success=false"],
            "cutout_url": None,
            "cutout_storage_key": None,
            "variants": [],
            "selected_variant_ids": [],
            "crewai_execution_id": data.get("crewai_execution_id") or data.get("execution_id"),
        }

    # Segmentation failure or explicit retake
    if segmentation in RETAKE_SEGMENTATION or data.get("retake_required") is True:
        return {
            "job_status": "retake_required",
            "segmentation_status": "retake_required",
            "requires_review": True,
            "quality_warnings": warnings,
            "errors": errors or ["Segmentation failed or requires a new photo"],
            "cutout_url": _http_url(data.get("cutout_url") or data.get("cutout")),
            "cutout_storage_key": _plain_key(data.get("cutout_storage_key")),
            "variants": [],
            "selected_variant_ids": [],
            "crewai_execution_id": data.get("crewai_execution_id") or data.get("execution_id"),
        }

    raw_variants = (
        data.get("variants")
        or data.get("variations")
        or data.get("generated_variants")
        or data.get("generated_images")
        or []
    )
    if not isinstance(raw_variants, list):
        raise InvalidImageJobResult("CrewAI result variants must be a list")

    variants: list[dict[str, Any]] = []
    for index, item in enumerate(raw_variants):
        if not isinstance(item, dict):
            continue
        variant_id = str(item.get("id") or item.get("variant_id") or "").strip()
        if not variant_id:
            raise InvalidImageJobResult(f"Variant at index {index} is missing an id")
        image_url = _http_url(
            item.get("image_url") or item.get("url") or item.get("secure_url")
        )
        data_uri = item.get("data_uri") or item.get("image_base64") or item.get("base64")
        status = str(item.get("status") or ("ready" if image_url or data_uri else "missing_image")).lower()
        background = item.get("background") or item.get("background_details") or {}
        if not isinstance(background, dict):
            background = {"name": str(background), "type": "solid_color"}
        variants.append(
            {
                "id": variant_id,
                "variant_id": variant_id,
                "background": background,
                "image_url": image_url,
                "data_uri": data_uri if isinstance(data_uri, str) and data_uri.startswith("data:") else None,
                "storage_key": _plain_key(item.get("storage_key") or item.get("public_id")),
                "saved": bool(image_url),
                "status": "missing_image" if not image_url and not data_uri else status,
            }
        )

    if segmentation not in SAFE_SEGMENTATION:
        requires_review = True

    valid_variants = [v for v in variants if v.get("image_url") or v.get("data_uri")]
    if not valid_variants and not errors:
        raise InvalidImageJobResult("CrewAI completed JSON contained no usable image URLs")

    selected = data.get("selected_variant_ids") or data.get("selected_variants") or []
    if isinstance(selected, list):
        selected_ids = [str(x) for x in selected]
    else:
        selected_ids = []

    job_status = "completed"
    if errors and not variants:
        job_status = "failed"

    return {
        "job_status": job_status,
        "segmentation_status": segmentation or "unknown",
        "requires_review": requires_review,
        "quality_warnings": warnings,
        "errors": errors,
        "cutout_url": _http_url(data.get("cutout_url") or data.get("cutout")),
        "cutout_storage_key": _plain_key(data.get("cutout_storage_key")),
        "original_photo_url": _http_url(data.get("original_photo_url") or data.get("photo_url")),
        "original_storage_key": _plain_key(data.get("original_storage_key")),
        "variants": variants,
        "selected_variant_ids": selected_ids,
        "crewai_execution_id": data.get("crewai_execution_id") or data.get("execution_id"),
        "product_name": data.get("product_name"),
        "product_category": data.get("product_category"),
    }


def _as_str_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value] if value else []
    if isinstance(value, list):
        return [str(v) for v in value if v]
    return [str(value)]


def _http_url(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    text = value.strip()
    if text.startswith("http://") or text.startswith("https://"):
        return text
    return None


def _plain_key(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    text = value.strip()
    if not text or text.startswith("data:"):
        return None
    return text
