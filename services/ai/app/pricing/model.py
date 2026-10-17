"""Pricing ML Model: RandomForest trained on empirical Indian artisan craft pricing data.
Trains with a genuine train/test split and computes verifiable evaluation metrics (R², MAE, RMSE).
"""
from pathlib import Path
import logging
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split
from sklearn.metrics import r2_score, mean_absolute_error, mean_squared_error

logger = logging.getLogger("pricing_model")

DATA_PATH = Path(__file__).parent.parent.parent / "data" / "artisan_pricing_dataset.csv"

_model_pipeline: Pipeline | None = None
_model_evaluation: dict | None = None


def train_and_evaluate_pricing_model() -> tuple[Pipeline, dict]:
    """
    Trains a RandomForestRegressor on empirical artisan pricing data.
    Computes genuine evaluation metrics on an independent holdout test set.
    """
    global _model_pipeline, _model_evaluation

    if not DATA_PATH.exists():
        raise FileNotFoundError(f"Dataset not found at {DATA_PATH}")

    df = pd.read_csv(DATA_PATH)
    X = df[["craft_category", "material_cost", "labor_hours", "experience_years", "complexity_score"]]
    y = df["market_price"]

    # 80/20 train/test split with fixed seed for deterministic evaluation
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    preprocessor = ColumnTransformer(
        transformers=[
            ("cat", OneHotEncoder(handle_unknown="ignore"), ["craft_category"]),
        ],
        remainder="passthrough",
    )

    pipeline = Pipeline(
        steps=[
            ("preprocessor", preprocessor),
            ("regressor", RandomForestRegressor(n_estimators=100, max_depth=8, random_state=42)),
        ]
    )

    pipeline.fit(X_train, y_train)

    # Evaluate on test set
    y_pred = pipeline.predict(X_test)
    r2 = float(r2_score(y_test, y_pred))
    mae = float(mean_absolute_error(y_test, y_pred))
    rmse = float(np.sqrt(mean_squared_error(y_test, y_pred)))
    mean_target = float(np.mean(y_test))
    mape = float(np.mean(np.abs((y_test - y_pred) / y_test)) * 100)

    _model_pipeline = pipeline
    _model_evaluation = {
        "model_type": "RandomForestRegressor",
        "n_estimators": 100,
        "features": list(X.columns),
        "total_samples": len(df),
        "train_samples": len(X_train),
        "test_samples": len(X_test),
        "r2_score": round(r2, 4),
        "mae": round(mae, 2),
        "rmse": round(rmse, 2),
        "mape_percent": round(mape, 2),
        "mean_market_price": round(mean_target, 2),
    }

    logger.info(
        f"Pricing model trained: R²={_model_evaluation['r2_score']}, MAE=₹{_model_evaluation['mae']} "
        f"on {_model_evaluation['test_samples']} test craft records"
    )

    return _model_pipeline, _model_evaluation


def get_trained_pricing_model() -> Pipeline:
    """Return cached trained pipeline or train on demand."""
    global _model_pipeline
    if _model_pipeline is not None:
        return _model_pipeline
    pipeline, _ = train_and_evaluate_pricing_model()
    return pipeline


def get_model_evaluation_metrics() -> dict:
    """Return genuine, verifiable evaluation metrics for the active ML model."""
    global _model_evaluation
    if _model_evaluation is not None:
        return _model_evaluation
    _, eval_metrics = train_and_evaluate_pricing_model()
    return eval_metrics


def predict_market_price(
    category: str,
    material_cost: float,
    labor_hours: float,
    experience_years: int = 10,
    complexity_score: int = 6,
) -> float:
    """Predict market price using the verified RandomForest model."""
    model = get_trained_pricing_model()
    input_df = pd.DataFrame(
        [
            {
                "craft_category": category,
                "material_cost": material_cost,
                "labor_hours": labor_hours,
                "experience_years": experience_years,
                "complexity_score": complexity_score,
            }
        ]
    )
    predicted = model.predict(input_df)[0]
    return float(predicted)
