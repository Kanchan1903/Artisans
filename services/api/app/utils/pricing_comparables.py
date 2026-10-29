"""Deterministic product matching over the published storefront catalog."""
import math
import re
from statistics import median
from typing import Any, Iterable


PRICING_VERSION = "storefront-comparable-v1"
_STOP_WORDS = {
    "a", "an", "and", "are", "as", "at", "by", "for", "from", "in",
    "is", "it", "made", "of", "on", "or", "the", "this", "to", "with",
    "handmade", "handcrafted", "traditional", "product", "item",
}


def _tokens(value: str | None) -> set[str]:
    if not value:
        return set()
    return {
        token for token in re.findall(r"[a-z0-9]+", value.casefold())
        if len(token) > 1 and token not in _STOP_WORDS
    }


def _similarity(left: str | None, right: str | None) -> float | None:
    a, b = _tokens(left), _tokens(right)
    if not a or not b:
        return None
    return len(a & b) / len(a | b)


def _category_slug(product: Any) -> str | None:
    return getattr(getattr(product, "category", None), "slug", None)


def _score(target: Any, candidate: Any) -> float:
    # Category is mandatory in SQL; the remaining signals are only used when
    # the corresponding fields exist on both actual product records.
    parts: list[tuple[float, float]] = [(1.0, 0.35)]
    for attr, weight in (("material", 0.25), ("technique", 0.20)):
        left, right = getattr(target, attr, None), getattr(candidate, attr, None)
        if left and right:
            parts.append((_similarity(left, right) or 0.0, weight))
    text_similarity = _similarity(
        " ".join(filter(None, [target.title_en, target.description_en])),
        " ".join(filter(None, [candidate.title_en, candidate.description_en])),
    )
    if text_similarity is not None:
        parts.append((text_similarity, 0.20))
    weighted = sum(score * weight for score, weight in parts)
    weights = sum(weight for _, weight in parts)
    return round(weighted / weights, 4)


def _quartile(sorted_prices: list[float], fraction: float) -> float:
    # Deterministic nearest-rank interpolation-free quartile, stable for small n.
    index = math.floor((len(sorted_prices) - 1) * fraction)
    return round(sorted_prices[index], 2)


def build_storefront_recommendation(
    target: Any,
    candidates: Iterable[Any],
    *,
    currency: str,
    costs: dict[str, float | None] | None = None,
) -> dict[str, Any]:
    target_category = _category_slug(target)
    ranked: list[tuple[float, Any]] = []
    seen_duplicates: set[tuple[int, str, float]] = set()

    for candidate in candidates:
        if candidate.id == target.id:
            continue
        if getattr(getattr(candidate, "status", None), "value", getattr(candidate, "status", None)) != "published":
            continue
        price = getattr(candidate, "price", None)
        if price is None or not math.isfinite(float(price)) or float(price) <= 0:
            continue
        category = _category_slug(candidate)
        if not target_category or category != target_category:
            continue

        normalized_title = " ".join(sorted(_tokens(candidate.title_en)))
        duplicate_key = (candidate.artisan_id, normalized_title, round(float(price), 2))
        if duplicate_key in seen_duplicates:
            continue
        seen_duplicates.add(duplicate_key)
        ranked.append((_score(target, candidate), candidate))

    ranked.sort(key=lambda row: (-row[0], row[1].id))
    matches = ranked[:10]
    snapshots = [
        {
            "product_id": int(product.id),
            "title": product.title_en,
            "price": round(float(product.price), 2),
            "currency": currency,
            "category": _category_slug(product),
            "material": product.material,
            "technique": product.technique,
            "similarity_score": score,
            "product_url": f"/products/{product.id}",
        }
        for score, product in matches
    ]

    prices = sorted(item["price"] for item in snapshots)
    count = len(prices)
    confidence = "none" if count == 0 else "low" if count < 3 else "medium" if count < 6 else "high"
    factors = [
        f"Matched published listings in the same storefront category ({target_category}).",
        "Comparable prices come from current published KarigarAI product records.",
    ]
    for attr, label in (("material", "Material"), ("technique", "Technique")):
        value = getattr(target, attr, None)
        if value:
            factors.append(f"{label} was considered from the artisan's product record: {value}.")
    provided_costs = costs or {}
    for key, label in (
        ("material_cost", "Artisan-provided material cost"),
        ("labor_hours", "Artisan-provided labor hours"),
        ("hourly_rate", "Artisan-provided hourly labor rate"),
        ("packaging_cost", "Artisan-provided packaging cost"),
        ("shipping_cost", "Artisan-provided shipping cost"),
    ):
        value = provided_costs.get(key)
        if value is not None:
            unit = "hours" if key == "labor_hours" else currency
            factors.append(f"{label}: {value:g} {unit}.")

    if not prices:
        summary = (
            "No valid published storefront listings matched this product category and available details. "
            "There is not enough storefront evidence to recommend a price."
        )
        return {
            "suggested_price": None,
            "price_range_min": None,
            "price_range_max": None,
            "comparable_products": [],
            "comparison_summary": summary,
            "pricing_factors": factors,
            "confidence": confidence,
            "requires_review": True,
            "error": "insufficient_comparable_data",
        }

    suggested = round(float(median(prices)), 2)
    low = _quartile(prices, 0.25)
    high = round(prices[math.ceil((count - 1) * 0.75)], 2)
    summary = (
        f"Compared {count} current published listing(s) in {target_category}. "
        f"The observed median is {currency} {suggested:.2f}; the middle price range is "
        f"{currency} {low:.2f}–{currency} {high:.2f}."
    )
    if count < 3:
        summary += " Fewer than three listings matched, so this evidence is limited and needs artisan review."
    factors.append(f"Suggested price is the deterministic median of the {count} matched listing prices.")
    factors.append("The displayed range is the observed interquartile range (25th–75th percentile).")

    return {
        "suggested_price": suggested,
        "price_range_min": low,
        "price_range_max": high,
        "comparable_products": snapshots,
        "comparison_summary": summary,
        "pricing_factors": factors,
        "confidence": confidence,
        "requires_review": count < 3,
        "error": None,
    }
