"""Automated tests for KalaSathi Intelligent Product Pricing Engine.

Covers:
- Transparent cost breakdown calculations (materials, artisan labor, packaging, shipping, platform fee)
- Missing costs and living wage defaults (₹85/hr fair artisan wage)
- Input validation (rejects negative costs and non-positive labor hours)
- Legitimate benchmark retrieval with source URLs and retrieval dates
- Estimate disclosure rules when market data is unavailable (no invented prices)
- Price override validation (warnings when below cost floor)
- Real Machine Learning model evaluation metrics (R², MAE, RMSE)
"""
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.pricing.service import (
    calculate_intelligent_pricing,
    validate_price_override,
    find_comparable_products,
)
from app.pricing.model import get_model_evaluation_metrics


@pytest.fixture
async def ai_client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


@pytest.mark.asyncio
async def test_pricing_calculations_and_breakdown():
    """Verify transparent cost breakdown and correct 3-tier pricing."""
    mat_cost = 250.0
    hours = 4.0
    rate = 100.0  # ₹400 labor
    pack = 35.0
    ship = 65.0
    fee_pct = 8.0  # 8%

    # Direct costs = 250 + 400 + 35 + 65 = 750
    # Cost floor = 750 / (1 - 0.08) = 750 / 0.92 = 815.22 -> ~₹815
    res_obj = calculate_intelligent_pricing(
        craft_category="pottery",
        material_cost=mat_cost,
        labor_hours=hours,
        hourly_rate=rate,
        packaging_cost=pack,
        shipping_cost=ship,
        platform_fee_percent=fee_pct,
        material="terracotta clay",
        technique="wheel-thrown",
        language="en",
    )
    result = res_obj.model_dump()

    cost_floor = result["cost_floor"]
    suggested = result["suggested_price"]
    premium = result["premium_price"]

    # 1. Floor must equal or exceed all direct costs + fees
    assert cost_floor >= 750.0
    assert 810.0 <= cost_floor <= 820.0

    # 2. Suggested price must be strictly greater than or equal to floor
    assert suggested >= cost_floor

    # 3. Premium price must be strictly greater than or equal to suggested price
    assert premium >= suggested

    # 4. Breakdown verification
    bd = result["cost_breakdown"]
    assert bd["material_cost"] == 250.0
    assert bd["labor_hours"] == 4.0
    assert bd["hourly_rate"] == 100.0
    assert bd["labor_cost"] == 400.0
    assert bd["packaging_cost"] == 35.0
    assert bd["shipping_cost"] == 65.0
    assert bd["total_direct_cost"] == 750.0
    assert bd["cost_floor"] == cost_floor


@pytest.mark.asyncio
async def test_pricing_defaults_and_fair_artisan_wage():
    """Verify sensible defaults are applied, including the fair artisan living wage (₹85/hr)."""
    # Using defaults for hourly rate, packaging, shipping, platform fee
    res_obj = calculate_intelligent_pricing(
        craft_category="woodcraft",
        material_cost=300.0,
        labor_hours=5.0,
        material="sheesham wood",
        language="mr",
    )
    result = res_obj.model_dump()

    bd = result["cost_breakdown"]
    assert bd["hourly_rate"] == 85.0  # Fair artisan living wage
    assert bd["labor_cost"] == 5.0 * 85.0  # ₹425
    assert bd["packaging_cost"] == 30.0
    assert bd["shipping_cost"] == 60.0

    # Direct costs = 300 + 425 + 30 + 60 = 815
    # Cost floor = 815 / 0.92 = ~886
    assert result["cost_floor"] >= 880.0
    assert result["suggested_price"] >= result["cost_floor"]


@pytest.mark.asyncio
async def test_pricing_invalid_costs_validation(ai_client: AsyncClient):
    """Verify negative costs or non-positive labor hours are rejected with validation errors."""
    # Negative material cost
    res1 = await ai_client.post(
        "/ai/price",
        json={"material_cost": -50.0, "labor_hours": 4.0, "craft_category": "pottery"},
    )
    assert res1.status_code == 422

    # Zero labor hours
    res2 = await ai_client.post(
        "/ai/price",
        json={"material_cost": 200.0, "labor_hours": 0.0, "craft_category": "pottery"},
    )
    assert res2.status_code == 422

    # Negative labor hours
    res3 = await ai_client.post(
        "/ai/price",
        json={"material_cost": 200.0, "labor_hours": -3.0, "craft_category": "pottery"},
    )
    assert res3.status_code == 422

    # Negative packaging
    res4 = await ai_client.post(
        "/ai/price",
        json={"material_cost": 200.0, "labor_hours": 2.0, "packaging_cost": -20.0},
    )
    assert res4.status_code == 422


@pytest.mark.asyncio
async def test_legitimate_comparable_market_data_retrieval():
    """Verify that legitimate comparable products are retrieved with source platforms, dates, and URLs."""
    res_obj = calculate_intelligent_pricing(
        craft_category="pottery",
        material_cost=150.0,
        labor_hours=3.0,
        material="terracotta clay",
        technique="wheel-thrown",
        language="en",
    )
    result = res_obj.model_dump()

    assert result["is_verified_market_price"] is True
    assert result["pricing_basis"] == "verified_market_data"
    assert result["status_label"] == "Verified Market Benchmark"
    assert len(result["comparable_products"]) > 0

    for item in result["comparable_products"]:
        assert "title" in item
        assert "price" in item
        assert item["price"] > 0
        assert "source_name" in item
        assert any(k in item["source_name"] for k in ["TRIFED", "Central Cottage", "Craftroots", "ONDC"])
        assert "retrieval_date" in item
        assert "source_url" in item
        assert item["source_url"].startswith("https://")
        assert item["match_score"] >= 0.50


@pytest.mark.asyncio
async def test_unavailable_market_data_estimate_disclosure():
    """Verify that when no comparable listings match, the system explicitly marks the price as an estimate
    and never invents false market prices."""
    # Searching for an obscure product with no comparable match in the handicraft registry
    res_obj = calculate_intelligent_pricing(
        craft_category="exotic-aerospace-craft",
        material_cost=500.0,
        labor_hours=4.0,
        material="titanium honeycomb",
        technique="vacuum deposition",
        language="mr",
    )
    result = res_obj.model_dump()

    # Must be marked strictly as an unverified estimate
    assert result["is_verified_market_price"] is False
    assert result["pricing_basis"] == "cost_plus_estimate"
    assert result["status_label"] == "Unverified Cost-Based Estimate"
    assert len(result["comparable_products"]) == 0
    # Explanation must make clear it is cost-based
    assert "अंदाजित" in result["explanation"] or "किमान" in result["explanation"]


@pytest.mark.asyncio
async def test_price_override_validation():
    """Verify custom price overrides are validated against the cost floor with multilingual warnings."""
    cost_floor = 850.0

    # 1. Price above cost floor is valid with no warning
    valid_res = validate_price_override(override_price=950.0, cost_floor=cost_floor, language="mr")
    assert valid_res["is_valid"] is True
    assert valid_res["warning"] is None

    # 2. Price below cost floor returns an alert warning in Marathi
    invalid_mr = validate_price_override(override_price=600.0, cost_floor=cost_floor, language="mr")
    assert invalid_mr["is_valid"] is False
    assert invalid_mr["warning"] is not None
    assert "सावधान" in invalid_mr["warning"] or "नुकसान" in invalid_mr["warning"]

    # 3. Price below cost floor in Hindi
    invalid_hi = validate_price_override(override_price=700.0, cost_floor=cost_floor, language="hi")
    assert invalid_hi["is_valid"] is False
    assert invalid_hi["warning"] is not None
    assert "चेतावनी" in invalid_hi["warning"] or "घाटा" in invalid_hi["warning"]

    # 4. Price below cost floor in English
    invalid_en = validate_price_override(override_price=500.0, cost_floor=cost_floor, language="en")
    assert invalid_en["is_valid"] is False
    assert "loss" in invalid_en["warning"].lower()


@pytest.mark.asyncio
async def test_ml_model_evaluation_metrics(ai_client: AsyncClient):
    """Verify that a genuine ML pricing model is trained, evaluated with standard metrics, and exposed via API."""
    res = await ai_client.get("/ai/price/evaluation")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "success"
    metrics = data["evaluation"]

    assert metrics["model_type"] == "RandomForestRegressor"
    assert metrics["r2_score"] >= 0.85
    assert metrics["mae"] < 200.0
    assert metrics["rmse"] < 250.0
    assert metrics["test_samples"] >= 3
    assert metrics["train_samples"] >= 10
    assert "features" in metrics
    assert "material_cost" in metrics["features"]
    assert "labor_hours" in metrics["features"]
