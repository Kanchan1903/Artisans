"""Pricing Assistant router: returns 3 price tiers with fair wage guarantee, cost breakdown, comparable data, and audio explanation."""
from pydantic import BaseModel, Field
from fastapi import APIRouter, HTTPException, status
from app.pricing.service import calculate_intelligent_pricing, PriceRecommendation
from app.pricing.model import get_model_evaluation_metrics

router = APIRouter(prefix="/ai", tags=["Pricing Assistant"])


class PricingRequest(BaseModel):
    craft_category: str = Field(default="Pottery")
    material_cost: float = Field(..., ge=0.0, description="Artisan material expense")
    labor_hours: float = Field(..., ge=0.01, description="Hours spent crafting")
    hourly_rate: float = Field(default=85.0, ge=0.0, description="Artisan hourly wage rate")
    packaging_cost: float = Field(default=30.0, ge=0.0, description="Protective packaging cost")
    shipping_cost: float = Field(default=60.0, ge=0.0, description="Shipping cost")
    platform_fee_percent: float = Field(default=8.0, ge=0.0, le=50.0, description="Platform & transaction fee %")
    material: str | None = None
    technique: str | None = None
    dimensions: str | None = None
    experience_years: int = Field(default=10, ge=0)
    complexity_score: int = Field(default=6, ge=1, le=10)
    language: str = Field(default="en")


class PriceOverrideRequest(BaseModel):
    override_price: float = Field(..., ge=0.0)
    cost_floor: float = Field(..., ge=0.0)
    language: str = Field(default="en")


@router.get("/price/evaluation")
async def get_pricing_model_evaluation():
    """Returns genuine, empirical evaluation metrics for the active RandomForest pricing model."""
    try:
        metrics = get_model_evaluation_metrics()
        return {"status": "success", "evaluation": metrics}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Model evaluation error: {str(e)}")


@router.post("/price", response_model=PriceRecommendation)
async def recommend_pricing(payload: PricingRequest):
    """
    Calculates intelligent 3-tier handicraft pricing:
    1. Minimum cost-covering floor (Materials + Labor Hours x Rate + Packaging + Shipping + Platform Fee)
    2. Suggested competitive selling price (Based on verified comparable listings or empirical ML model)
    3. Optional premium price
    """
    try:
        recommendation = calculate_intelligent_pricing(
            craft_category=payload.craft_category,
            material_cost=payload.material_cost,
            labor_hours=payload.labor_hours,
            hourly_rate=payload.hourly_rate,
            packaging_cost=payload.packaging_cost,
            shipping_cost=payload.shipping_cost,
            platform_fee_percent=payload.platform_fee_percent,
            material=payload.material,
            technique=payload.technique,
            dimensions=payload.dimensions,
            experience_years=payload.experience_years,
            complexity_score=payload.complexity_score,
            language=payload.language,
        )
        return recommendation
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Pricing error: {str(e)}")


@router.post("/price/validate-override")
async def validate_price_override(payload: PriceOverrideRequest):
    """
    Validates artisan's custom price override:
    Ensures artisan never accidentally sells below material + fair labor cost.
    """
    is_valid = payload.override_price >= payload.cost_floor
    difference = round(payload.override_price - payload.cost_floor, 2)

    warning = None
    if not is_valid:
        loss = abs(difference)
        if payload.language == "mr":
            warning = f"सावधान: ही किंमत आधार मूल्यापेक्षा ₹{loss:.0f} कमी आहे. यामुळे तुमचे नुकसान होईल."
        elif payload.language == "hi":
            warning = f"चेतावनी: यह कीमत न्यूनतम आधार मूल्य से ₹{loss:.0f} कम है। इससे आपको घाटा हो सकता है।"
        else:
            warning = f"Warning: This price is ₹{loss:.0f} below your cost floor. Selling at this price results in a loss."

    return {
        "is_valid": is_valid,
        "override_price": payload.override_price,
        "cost_floor": payload.cost_floor,
        "difference": difference,
        "warning": warning,
    }
