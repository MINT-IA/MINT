"""
Budget anomaly detection endpoints — JITAI nudges.

POST /api/v1/budget/anomalies  — Detect spending anomalies in transactions
"""

from typing import List, Optional

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

from app.core.auth import User, require_current_user
from app.core.rate_limit import limiter
from app.services.anomaly_detection_service import AnomalyDetectionService

router = APIRouter()


# ── Schemas ──────────────────────────────────────────────────────────────────


class TransactionItem(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    amount: float = Field(..., description="Transaction amount (positive or negative)")
    category: str = Field("other", description="Spending category")
    date: Optional[str] = Field(None, description="ISO date string")
    description: Optional[str] = Field(None, description="Transaction description")


class AnomalyRequest(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    transactions: List[TransactionItem] = Field(
        ..., description="List of transactions to analyse", max_length=5000
    )
    mad_threshold: float = Field(
        3.5, description="Modified Z-score threshold for global detection",
        gt=0.1, lt=10.0,
    )
    zscore_threshold: float = Field(
        2.5, description="Z-score threshold for per-category detection",
        gt=0.1, lt=10.0,
    )


class AnomalyItem(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    amount: float
    category: str
    date: Optional[str] = None
    description: Optional[str] = None
    anomaly_score: float = Field(..., alias="anomalyScore")
    anomaly_type: str = Field(..., alias="anomalyType")
    insight: Optional[str] = None


class AnomalyResponse(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    anomalies: List[AnomalyItem]
    total_transactions: int = Field(..., alias="totalTransactions")
    anomaly_count: int = Field(..., alias="anomalyCount")
    disclaimer: str = (
        "Outil \u00e9ducatif \u2014 ne constitue pas un conseil financier "
        "au sens de la LSFin."
    )
    sources: List[str] = ["Analyse statistique (Z-score, MAD)"]


# ── Endpoint ─────────────────────────────────────────────────────────────────


@router.post("/anomalies", response_model=AnomalyResponse)
@limiter.limit("30/minute")
def detect_anomalies(
    http_request: Request,
    request: AnomalyRequest,
    _user: User = Depends(require_current_user),
) -> AnomalyResponse:
    """Detect spending anomalies using statistical methods.

    Returns transactions flagged as unusual based on global (Modified Z-score)
    and per-category (Z-score) analysis.
    """
    raw_transactions = [t.model_dump() for t in request.transactions]

    anomalies = AnomalyDetectionService.detect_spending_anomalies(
        transactions=raw_transactions,
        mad_threshold=request.mad_threshold,
        zscore_threshold=request.zscore_threshold,
    )

    # Compute category averages for insights
    from statistics import mean as _mean

    cat_avgs: dict[str, float] = {}
    for t in raw_transactions:
        cat = t.get("category", "other")
        cat_avgs.setdefault(cat, []).append(abs(t["amount"]))
    cat_avgs = {k: _mean(v) for k, v in cat_avgs.items()}

    anomaly_items = []
    for a in anomalies:
        cat = a.get("category", "other")
        insight = AnomalyDetectionService.generate_anomaly_insight(
            anomaly=a,
            category_avg=cat_avgs.get(cat, 0),
        )
        anomaly_items.append(
            AnomalyItem(
                amount=a["amount"],
                category=a.get("category", "other"),
                date=a.get("date"),
                description=a.get("description"),
                anomaly_score=a["anomaly_score"],
                anomaly_type=a["anomaly_type"],
                insight=insight,
            )
        )

    return AnomalyResponse(
        anomalies=anomaly_items,
        total_transactions=len(raw_transactions),
        anomaly_count=len(anomaly_items),
    )
