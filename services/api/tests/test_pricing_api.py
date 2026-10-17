"""Unit & Integration tests for Backend API Pricing endpoints."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_backend_pricing_calculation(client: AsyncClient):
    """Test /api/v1/ai/price returns 3 price tiers, itemized cost breakdown, and honest basis."""
    payload = {
        "craft_category": "pottery",
        "material_cost": 200.0,
        "labor_hours": 4.0,
        "hourly_rate": 90.0,
        "packaging_cost": 30.0,
        "shipping_cost": 60.0,
        "platform_fee_percent": 8.0,
        "material": "Terracotta Clay",
        "technique": "Wheel Throwing",
        "language": "mr",
    }
    res = await client.post("/api/v1/ai/price", json=payload)
    assert res.status_code == 200
    data = res.json()

    # Three understandable price tiers
    assert "cost_floor" in data
    assert "suggested_price" in data
    assert "premium_price" in data
    assert data["cost_floor"] > 0
    assert data["suggested_price"] >= data["cost_floor"]
    assert data["premium_price"] >= data["suggested_price"]

    # Transparent cost breakdown
    assert "cost_breakdown" in data
    bd = data["cost_breakdown"]
    assert bd["material_cost"] == 200.0
    assert bd["labor_hours"] == 4.0
    assert bd["hourly_rate"] == 90.0

    # Pricing basis and status label
    assert "is_verified_market_price" in data
    assert "pricing_basis" in data
    assert "status_label" in data


@pytest.mark.asyncio
async def test_backend_pricing_validation_errors(client: AsyncClient):
    """Test validation errors for invalid pricing parameters."""
    # Negative material cost
    res1 = await client.post(
        "/api/v1/ai/price",
        json={"material_cost": -100.0, "labor_hours": 3.0, "craft_category": "pottery"},
    )
    assert res1.status_code == 422

    # Zero labor hours
    res2 = await client.post(
        "/api/v1/ai/price",
        json={"material_cost": 150.0, "labor_hours": 0.0, "craft_category": "pottery"},
    )
    assert res2.status_code == 422


@pytest.mark.asyncio
async def test_backend_price_override_validation(client: AsyncClient):
    """Test artisan price override validation against cost floor."""
    # 1. Price above cost floor
    res_valid = await client.post(
        "/api/v1/ai/price/validate-override",
        json={"override_price": 950.0, "cost_floor": 800.0, "language": "mr"},
    )
    assert res_valid.status_code == 200
    data_valid = res_valid.json()
    assert data_valid["is_valid"] is True
    assert data_valid["warning"] is None

    # 2. Price below cost floor
    res_invalid = await client.post(
        "/api/v1/ai/price/validate-override",
        json={"override_price": 600.0, "cost_floor": 800.0, "language": "mr"},
    )
    assert res_invalid.status_code == 200
    data_invalid = res_invalid.json()
    assert data_invalid["is_valid"] is False
    assert data_invalid["warning"] is not None


@pytest.mark.asyncio
async def test_backend_pricing_model_evaluation(client: AsyncClient):
    """Test /api/v1/ai/price/evaluation returns verifiable ML model metrics."""
    res = await client.get("/api/v1/ai/price/evaluation")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "success"
    eval_data = data["evaluation"]
    assert eval_data["model_type"] == "RandomForestRegressor"
    assert eval_data["r2_score"] >= 0.85
    assert "mae" in eval_data
