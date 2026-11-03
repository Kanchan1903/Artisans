"""Input mapping and structured-result validation for the catalog-builder crew."""
from __future__ import annotations

import json
import re
from typing import Any


class CatalogBuilderContractError(ValueError):
    pass


def _normalized_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def build_catalog_inputs(
    product: Any,
    artisan: Any,
    category: Any,
    image_urls: list[str],
    required_names: list[str],
) -> dict[str, str]:
    """Map CrewAI's discovered input names to real product data, never dummy values."""
    full_product = {
        "id": product.id,
        "name": product.title_en,
        "description": product.description_en or "",
        "category": category.name if category else "",
        "category_slug": category.slug if category else "",
        "material": product.material or "",
        "technique": product.technique or "",
        "dimensions": product.dimensions or "",
        "weight_grams": product.weight_grams,
        "additional_details": product.additional_details or {},
        "care_instructions": product.care_instructions or "",
        "price": product.price,
        "stock": product.stock,
        "seo_keywords": product.seo_keywords or [],
        "images": image_urls,
        "artisan_name": getattr(getattr(artisan, "user", None), "name", "") or "",
        "artisan_state": getattr(artisan, "state", "") or "",
        "voice_transcript": product.voice_transcript or "",
    }
    prompt = (
        "Create professional, accurate catalog content for this artisan product. "
        "Preserve the artisan's factual details and do not invent provenance, materials, or certifications.\n"
        + json.dumps(full_product, ensure_ascii=False, separators=(",", ":"))
    )
    values: dict[str, Any] = {}
    aliases = {
        "productname": full_product["name"],
        "producttitle": full_product["name"],
        "title": full_product["name"],
        "name": full_product["name"],
        "description": full_product["description"],
        "productdescription": full_product["description"],
        "descriptionen": full_product["description"],
        "category": full_product["category"],
        "categoryname": full_product["category"],
        "productcategory": full_product["category"],
        "craftcategory": full_product["category"],
        "categoryslug": full_product["category_slug"],
        "material": full_product["material"],
        "materials": full_product["material"],
        "technique": full_product["technique"],
        "crafttechnique": full_product["technique"],
        "dimensions": full_product["dimensions"],
        "weight": full_product["weight_grams"],
        "weightgrams": full_product["weight_grams"],
        "price": full_product["price"],
        "stock": full_product["stock"],
        "quantity": full_product["stock"],
        "artisan": full_product["artisan_name"],
        "artisanname": full_product["artisan_name"],
        "artisanstate": full_product["artisan_state"],
        "state": full_product["artisan_state"],
        "imageurl": image_urls[0] if image_urls else "",
        "photourl": image_urls[0] if image_urls else "",
        "primaryimageurl": image_urls[0] if image_urls else "",
        "imageurls": image_urls,
        "photourls": image_urls,
        "images": image_urls,
        "seokeywords": full_product["seo_keywords"],
        "tags": full_product["seo_keywords"],
        "additionaldetails": full_product["additional_details"],
        "careinstructions": full_product["care_instructions"],
        "voicetranscript": full_product["voice_transcript"],
        "productdata": full_product,
        "productjson": full_product,
        "productinfo": full_product,
        "productdetails": full_product,
        "input": prompt,
        "prompt": prompt,
        "query": prompt,
        "request": prompt,
    }
    by_normalized = {_normalized_key(key): value for key, value in aliases.items()}
    mapped: dict[str, str] = {}
    unsupported: list[str] = []
    for name in required_names:
        key = _normalized_key(name)
        if key not in by_normalized:
            unsupported.append(name)
            continue
        value = by_normalized[key]
        mapped[name] = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)
    if unsupported:
        raise CatalogBuilderContractError(
            "Catalog builder requires unmapped inputs: " + ", ".join(unsupported)
        )
    return mapped


def normalize_catalog_output(value: Any) -> dict[str, Any]:
    """Require a JSON object with a usable title and description before READY."""
    data = value
    if isinstance(data, str):
        raw = data.strip()
        if raw.startswith("```"):
            raw = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw, flags=re.IGNORECASE)
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise CatalogBuilderContractError("Catalog builder output was not valid JSON") from exc
    if not isinstance(data, dict):
        raise CatalogBuilderContractError("Catalog builder output must be a JSON object")

    for wrapper in ("catalog", "product", "data", "output", "result"):
        nested = data.get(wrapper)
        if isinstance(nested, dict):
            data = nested
            break
        if isinstance(nested, str):
            try:
                parsed = json.loads(nested)
            except json.JSONDecodeError:
                continue
            if isinstance(parsed, dict):
                data = parsed
                break

    def first_string(*keys: str) -> str | None:
        for key in keys:
            candidate = data.get(key)
            if isinstance(candidate, str) and candidate.strip():
                return candidate.strip()
        return None

    title = first_string("title_en", "improved_title", "product_title", "title", "name")
    description = first_string(
        "description_en", "professional_description", "improved_description", "product_description", "description"
    )
    if not title or not description:
        raise CatalogBuilderContractError(
            "Catalog builder completed without a title and professional description"
        )
    if len(title) > 255:
        raise CatalogBuilderContractError("Catalog builder title exceeds 255 characters")

    result: dict[str, Any] = {
        "title_en": title,
        "description_en": description,
        "raw": data,
    }
    keywords = data.get("seo_keywords", data.get("search_keywords", data.get("tags")))
    if isinstance(keywords, list):
        result["seo_keywords"] = [str(item).strip() for item in keywords if str(item).strip()][:50]
    for key in ("highlights", "features", "image_quality_feedback", "presentation_improvements", "suggested_category"):
        if key in data:
            result[key] = data[key]
    return result


def parse_catalog_builder_status(payload: dict[str, Any]) -> dict[str, Any]:
    """Interpret CrewAI AMP terminal states without treating kickoff as success."""
    raw_state = str(
        payload.get("state") or payload.get("status") or payload.get("execution_status") or ""
    ).strip().lower()
    if raw_state in {"success", "succeeded", "complete", "completed"}:
        raw_result = payload.get("result", payload.get("output"))
        if raw_result is None and isinstance(payload.get("tasks_output"), list):
            task_outputs = payload["tasks_output"]
            raw_result = task_outputs[-1] if task_outputs else None
            if isinstance(raw_result, dict):
                raw_result = raw_result.get("raw", raw_result.get("output", raw_result))
        return {"state": "completed", "output": normalize_catalog_output(raw_result)}
    if raw_state in {"failed", "failure", "error", "errored"}:
        return {
            "state": "failed",
            "error": str(payload.get("error") or payload.get("message") or "Catalog builder execution failed"),
        }
    if raw_state in {"not found", "not_found"}:
        return {"state": "failed", "error": "CrewAI could not find this catalog-builder execution."}
    return {
        "state": "processing",
        "progress": payload.get("progress"),
        "current_task": payload.get("current_task"),
    }
