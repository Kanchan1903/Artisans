"""Intelligent Handicraft Pricing Engine.
Calculates 3 understandable prices:
1. Minimum cost-covering price (Transparent breakdown: material, hours x rate, packaging, shipping, platform fee).
2. Suggested competitive selling price (Based on verified comparable listings or empirical ML benchmark).
3. Optional premium price (Gallery, export, and boutique gifts).

Adheres to:
- Never scrapes marketplaces in violation of terms; retrieves from configured legitimate benchmark registry.
- Clearly labels as 'estimate' when comparable market data is unavailable.
- Reports genuine ML model evaluation metrics.
- Provides explainable factors and multi-language audio explanations.
"""
from pathlib import Path
import json
import logging
from typing import Any
import numpy as np
from pydantic import BaseModel, Field
from app.pricing.model import predict_market_price, get_model_evaluation_metrics

logger = logging.getLogger("pricing_service")

DATA_DIR = Path(__file__).parent.parent.parent / "data"
COMPARABLE_PRODUCTS_FILE = DATA_DIR / "comparable_market_products.json"

DEFAULT_FAIR_HOURLY_WAGE = 85.0   # ₹85/hr fair living wage for skilled rural artisans
DEFAULT_PACKAGING_COST = 30.0     # Standard eco-friendly protective packaging
DEFAULT_SHIPPING_COST = 60.0      # Regional logistics allocation
DEFAULT_PLATFORM_FEE_PCT = 8.0    # 8% platform maintenance + payment gateway fee


class ComparableProduct(BaseModel):
    id: str
    title: str
    price: float
    source_name: str
    source_url: str
    retrieval_date: str
    match_score: float
    similarity_factors: list[str]


class CostBreakdown(BaseModel):
    material_cost: float
    labor_hours: float
    hourly_rate: float
    labor_cost: float
    packaging_cost: float
    shipping_cost: float
    platform_fee: float
    platform_fee_percent: float
    total_direct_cost: float
    cost_floor: float


class PriceRecommendation(BaseModel):
    cost_floor: float
    suggested_price: float
    premium_price: float
    is_verified_market_price: bool
    pricing_basis: str  # "verified_market_data" | "empirical_ml_model" | "cost_plus_estimate"
    status_label: str   # "Verified Market Benchmark" | "Unverified Cost-Based Estimate"
    cost_breakdown: CostBreakdown
    comparable_products: list[ComparableProduct] = []
    influencing_factors: list[str] = []
    explanation: str
    language: str
    model_evaluation: dict | None = None


# ─── Legitimate Comparable Product Retrieval & Matcher ───────────────────────

def load_comparable_products_registry() -> list[dict]:
    """Load curated verified benchmark products from legitimate repository."""
    if not COMPARABLE_PRODUCTS_FILE.exists():
        return []
    try:
        with open(COMPARABLE_PRODUCTS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        logger.warning(f"Error loading comparable products: {e}")
        return []


def find_comparable_products(
    category_slug: str,
    material: str | None = None,
    technique: str | None = None,
    dimensions: str | None = None,
) -> list[ComparableProduct]:
    """
    Compares relevant characteristics (category, material, technique) against legitimate benchmark data.
    Strictly filters out unrelated products to avoid arbitrary or falsely elevated pricing.
    """
    registry = load_comparable_products_registry()
    matches = []

    cat_clean = category_slug.lower().strip()
    mat_clean = (material or "").lower()
    tech_clean = (technique or "").lower()

    for item in registry:
        score = 0.0
        factors = []

        # 1. Category relevance (mandatory high weight)
        item_cat = item.get("category_slug", "").lower()
        if item_cat == cat_clean:
            score += 0.40
            factors.append(f"Category match: {item_cat}")
        elif cat_clean in item_cat or item_cat in cat_clean:
            score += 0.25
            factors.append("Sub-category relevance")
        else:
            # Unrelated category items are strictly rejected
            continue

        # 2. Material similarity
        item_mat = item.get("material", "").lower()
        if mat_clean:
            # Check key material tokens (clay, canvas, wood, brass, cotton, rice)
            mat_tokens = [w for w in ["clay", "terracotta", "canvas", "wood", "brass", "cotton", "rice", "sheesham", "lacquer"] if w in mat_clean]
            matched_mat = [t for t in mat_tokens if t in item_mat]
            if matched_mat:
                score += 0.30
                factors.append(f"Material alignment: {', '.join(matched_mat)}")

        # 3. Craftsmanship technique similarity
        item_tech = item.get("technique", "").lower()
        if tech_clean:
            tech_tokens = [w for w in ["warli", "painting", "wheel", "carving", "weaving", "lacquer", "casting", "dhokra"] if w in tech_clean]
            matched_tech = [t for t in tech_tokens if t in item_tech]
            if matched_tech:
                score += 0.30
                factors.append(f"Technique alignment: {', '.join(matched_tech)}")

        # Only retain genuinely relevant matches with score >= 0.50
        if score >= 0.50:
            matches.append(
                ComparableProduct(
                    id=item["id"],
                    title=item["title"],
                    price=float(item["price"]),
                    source_name=item["source_name"],
                    source_url=item["source_url"],
                    retrieval_date=item["retrieval_date"],
                    match_score=round(score, 2),
                    similarity_factors=factors,
                )
            )

    # Sort highest match score first
    matches.sort(key=lambda m: m.match_score, reverse=True)
    return matches


# ─── Multi-Language Explanations ─────────────────────────────────────────────

def generate_plain_language_explanation(
    cost_floor: float,
    suggested: float,
    premium: float,
    cost_breakdown: CostBreakdown,
    comparable_count: int,
    is_verified: bool,
    language: str = "en",
) -> str:
    """Produces clear, accessible audio explanation for artisans in their native language."""
    lang = language.lower()
    mat = cost_breakdown.material_cost
    hrs = cost_breakdown.labor_hours
    wage = cost_breakdown.labor_cost
    pkg = cost_breakdown.packaging_cost
    ship = cost_breakdown.shipping_cost

    if lang == "mr":
        basis_text = f"आम्हाला सरकारी व अधिकृत बाजारपेठेत {comparable_count} तुलनात्मक वस्तूंची खात्रीशीर किंमत मिळाली." if is_verified else "अद्याप बाजारातील थेट माहिती उपलब्ध नसल्याने ही किंमत खर्चाच्या आधारावर अंदाजित केली आहे."
        return (
            f"किमान किंमत ₹{cost_floor:.0f}: साहित्याचा खर्च ₹{mat:.0f}, {hrs:.1f} तासांचे मोल ₹{wage:.0f}, "
            f"पॅकेजिंग व वाहतूक ₹{pkg + ship:.0f}. "
            f"{basis_text} "
            f"सुचवलेली योग्य विक्री किंमत ₹{suggested:.0f} आहे, आणि प्रदर्शन अथवा भेटवस्तूसाठी प्रीमियम किंमत ₹{premium:.0f} आहे. "
            f"आपण ही किंमत बदलू शकता."
        )
    elif lang == "hi":
        basis_text = f"हमें सत्यापित हस्तशिल्प मंचों पर {comparable_count} समतुल्य उत्पादों की प्रमाणित कीमतें मिली हैं।" if is_verified else "बाजार का प्रमाणित डेटा उपलब्ध न होने के कारण यह सिफारिश लागत-आधारित अनुमान है।"
        return (
            f"न्यूनतम आधार मूल्य ₹{cost_floor:.0f}: कच्ची सामग्री ₹{mat:.0f}, {hrs:.1f} घंटे की मजदूरी ₹{wage:.0f}, "
            f"पैकेजिंग व ढुलाई ₹{pkg + ship:.0f}। "
            f"{basis_text} "
            f"सुझाई गई बाजार कीमत ₹{suggested:.0f} है, और प्रीमियम मूल्य ₹{premium:.0f} है। "
            f"आप अपनी इच्छानुसार अंतिम कीमत तय कर सकते हैं।"
        )
    else:
        basis_text = f"We retrieved {comparable_count} comparable listings from verified artisan registries (TRIFED / CCIC)." if is_verified else "Comparable market listings were not found; this recommendation is an unverified cost-based estimate."
        return (
            f"Minimum Cost Floor is ₹{cost_floor:.0f} (Materials: ₹{mat:.0f}, {hrs:.1f} hrs skilled labor: ₹{wage:.0f}, Packaging & Shipping: ₹{pkg + ship:.0f}). "
            f"{basis_text} "
            f"Suggested selling price is ₹{suggested:.0f} giving you a fair profit margin, with an optional premium price of ₹{premium:.0f}. "
            f"You may edit and approve the final price before publishing."
        )


# ─── Core Transparent Pricing Calculator ─────────────────────────────────────

def calculate_intelligent_pricing(
    craft_category: str,
    material_cost: float,
    labor_hours: float,
    hourly_rate: float = DEFAULT_FAIR_HOURLY_WAGE,
    packaging_cost: float = DEFAULT_PACKAGING_COST,
    shipping_cost: float = DEFAULT_SHIPPING_COST,
    platform_fee_percent: float = DEFAULT_PLATFORM_FEE_PCT,
    material: str | None = None,
    technique: str | None = None,
    dimensions: str | None = None,
    experience_years: int = 10,
    complexity_score: int = 6,
    language: str = "en",
) -> PriceRecommendation:
    """
    Executes transparent 3-tier pricing with cost breakdown, comparable matching, and ML evaluation.
    """
    # ─── Input Validation ───────────────────────────────────────────────────
    if material_cost < 0.0:
        raise ValueError("Material cost cannot be negative")
    if labor_hours <= 0.0:
        raise ValueError("Labor hours must be strictly greater than zero")
    if hourly_rate < 0.0:
        raise ValueError("Hourly wage rate cannot be negative")
    if packaging_cost < 0.0:
        raise ValueError("Packaging cost cannot be negative")
    if shipping_cost < 0.0:
        raise ValueError("Shipping cost cannot be negative")
    if platform_fee_percent < 0.0 or platform_fee_percent >= 50.0:
        raise ValueError("Platform fee percent must be between 0 and 50%")

    # ─── 1. Transparent Cost-Covering Minimum ────────────────────────────────
    labor_cost = round(labor_hours * hourly_rate, 2)
    total_direct_cost = round(material_cost + labor_cost + packaging_cost + shipping_cost, 2)

    # Cost floor accounts for direct costs plus platform & transaction fees
    fee_factor = 1.0 - (platform_fee_percent / 100.0)
    cost_floor = round(total_direct_cost / fee_factor, 2)
    platform_fee = round(cost_floor - total_direct_cost, 2)

    cost_breakdown = CostBreakdown(
        material_cost=material_cost,
        labor_hours=labor_hours,
        hourly_rate=hourly_rate,
        labor_cost=labor_cost,
        packaging_cost=packaging_cost,
        shipping_cost=shipping_cost,
        platform_fee=platform_fee,
        platform_fee_percent=platform_fee_percent,
        total_direct_cost=total_direct_cost,
        cost_floor=cost_floor,
    )

    # ─── 2. Search for Legitimate Comparable Benchmark Products ─────────────
    # Normalize category slug
    cat_slug = craft_category.lower().replace("&", "").replace("  ", " ").replace(" ", "-")
    comparables = find_comparable_products(
        category_slug=cat_slug,
        material=material,
        technique=technique,
        dimensions=dimensions,
    )

    influencing_factors = [
        f"Direct cost baseline: ₹{total_direct_cost:.0f} (Raw materials ₹{material_cost:.0f} + {labor_hours:.1f} hrs @ ₹{hourly_rate:.0f}/hr)",
        f"Packaging & delivery: Protective packaging ₹{packaging_cost:.0f} + Regional shipping ₹{shipping_cost:.0f}",
        f"Transaction & platform fee allowance: {platform_fee_percent:.1f}% (₹{platform_fee:.0f})",
    ]

    model_eval = None

    if comparables:
        # Grounded in genuine comparable market data
        is_verified = True
        pricing_basis = "verified_market_data"
        status_label = "Verified Market Benchmark"

        comp_prices = [p.price for p in comparables]
        median_comp_price = float(np.median(comp_prices))

        # Suggested price respects market median while strictly guaranteeing >= 25% profit over cost floor
        suggested_raw = max(cost_floor * 1.25, median_comp_price)
        suggested_price = round(round(suggested_raw / 10.0) * 10.0, 2)

        influencing_factors.append(
            f"Market evidence: Matched {len(comparables)} verified handicraft listings (Median price: ₹{median_comp_price:.0f})"
        )
    else:
        # Comparable market data not available -> Clearly label as unverified estimate!
        is_verified = False
        pricing_basis = "cost_plus_estimate"
        status_label = "Unverified Cost-Based Estimate"

        # Try empirical trained ML prediction
        try:
            ml_pred = predict_market_price(
                category=craft_category,
                material_cost=material_cost,
                labor_hours=labor_hours,
                experience_years=experience_years,
                complexity_score=complexity_score,
            )
            suggested_raw = max(cost_floor * 1.30, ml_pred)
            model_eval = get_model_evaluation_metrics()
            influencing_factors.append(
                f"Empirical pricing estimate: Trained Random Forest model (R²={model_eval['r2_score']}, MAE=₹{model_eval['mae']})"
            )
        except Exception:
            suggested_raw = cost_floor * 1.35
            influencing_factors.append("Standard artisan cost-plus estimate (+35% sustainable margin)")

        suggested_price = round(round(suggested_raw / 10.0) * 10.0, 2)
        influencing_factors.append("Notice: No live comparable listings verified; labeled as unverified estimate")

    # ─── 3. Optional Premium Price Tier (~35% above suggested) ──────────────
    premium_raw = suggested_price * 1.35
    premium_price = round(round(premium_raw / 10.0) * 10.0, 2)

    # ─── 4. Plain-Language Audio Explanation ─────────────────────────────────
    explanation = generate_plain_language_explanation(
        cost_floor=cost_floor,
        suggested=suggested_price,
        premium=premium_price,
        cost_breakdown=cost_breakdown,
        comparable_count=len(comparables),
        is_verified=is_verified,
        language=language,
    )

    return PriceRecommendation(
        cost_floor=cost_floor,
        suggested_price=suggested_price,
        premium_price=premium_price,
        is_verified_market_price=is_verified,
        pricing_basis=pricing_basis,
        status_label=status_label,
        cost_breakdown=cost_breakdown,
        comparable_products=comparables,
        influencing_factors=influencing_factors,
        explanation=explanation,
        language=language,
        model_evaluation=model_eval,
    )


# Backwards compatibility alias for existing code
def calculate_pricing(
    craft_category: str,
    material_cost: float,
    labor_hours: float,
    experience_years: int = 10,
    complexity_score: int = 6,
    language: str = "en",
) -> PriceRecommendation:
    return calculate_intelligent_pricing(
        craft_category=craft_category,
        material_cost=material_cost,
        labor_hours=labor_hours,
        experience_years=experience_years,
        complexity_score=complexity_score,
        language=language,
    )


def validate_price_override(
    override_price: float,
    cost_floor: float,
    language: str = "en",
) -> dict:
    """Validates artisan's custom price override against the cost floor."""
    is_valid = override_price >= cost_floor
    difference = round(override_price - cost_floor, 2)

    warning = None
    if not is_valid:
        loss = abs(difference)
        if language == "mr":
            warning = f"सावधान: ही किंमत आधार मूल्यापेक्षा ₹{loss:.0f} कमी आहे. यामुळे तुमचे नुकसान होईल."
        elif language == "hi":
            warning = f"चेतावनी: यह कीमत न्यूनतम आधार मूल्य से ₹{loss:.0f} कम है। इससे आपको घाटा हो सकता है।"
        else:
            warning = f"Warning: This price is ₹{loss:.0f} below your cost floor. Selling at this price results in a loss."

    return {
        "is_valid": is_valid,
        "override_price": override_price,
        "cost_floor": cost_floor,
        "difference": difference,
        "warning": warning,
    }

