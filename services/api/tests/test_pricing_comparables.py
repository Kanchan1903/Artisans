"""Unit tests for storefront comparable filtering and median calculations."""
from types import SimpleNamespace

from app.utils.pricing_comparables import build_storefront_recommendation


def product(product_id, title, price, *, status="published", category="pottery", artisan=1):
    return SimpleNamespace(
        id=product_id,
        title_en=title,
        description_en="Hand thrown clay craft vessel",
        price=price,
        status=status,
        artisan_id=artisan,
        material="terracotta clay",
        technique="wheel throwing",
        category=SimpleNamespace(slug=category),
    )


def test_recommendation_uses_only_real_published_same_category_products():
    target = product(10, "Clay craft bowl", 0)
    result = build_storefront_recommendation(
        target,
        [
            product(1, "Terracotta Jar", 100),
            product(2, "Clay Water Pot", 200),
            product(3, "Handmade Clay Pitcher", 300),
            product(4, "Unpublished", 999, status="draft"),
            product(5, "Different category", 900, category="handloom"),
            product(6, "Invalid zero price", 0),
            product(10, "Target itself", 700),
        ],
        currency="INR",
    )

    assert result["suggested_price"] == 200
    assert result["price_range_min"] == 100
    assert result["price_range_max"] == 300
    assert {row["product_id"] for row in result["comparable_products"]} == {1, 2, 3}
    assert result["confidence"] == "medium"
    assert result["requires_review"] is False


def test_no_comparable_evidence_never_generates_a_price():
    target = product(10, "Clay craft bowl", 0)
    result = build_storefront_recommendation(target, [], currency="INR")

    assert result["suggested_price"] is None
    assert result["price_range_min"] is None
    assert result["comparable_products"] == []
    assert result["error"] == "insufficient_comparable_data"
    assert result["requires_review"] is True
