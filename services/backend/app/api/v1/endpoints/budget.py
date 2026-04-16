"""
Budget endpoints — CRUD + anomaly detection.

GET    /api/v1/budget/me             — Read user's persisted budget
PUT    /api/v1/budget/me             — Upsert full budget (income + lines + targets)
POST   /api/v1/budget/me/lines       — Add or update one fixed line
DELETE /api/v1/budget/me/lines/{id}  — Remove one fixed line
POST   /api/v1/budget/anomalies      — Detect spending anomalies (existing JITAI)

Storage: budget lives under ProfileModel.data["budget"] — no new table,
no migration. Computed fields (freeMargin, savingsRate, riskLevel,
premierEclairage) are derived on read so the client never has to
recompute them and never gets stale derived state.
"""

import logging
import uuid
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel
from sqlalchemy.orm import Session

from app.core.auth import User, require_current_user
from app.core.database import get_db
from app.core.rate_limit import limiter
from app.models.profile_model import ProfileModel
from app.services.anomaly_detection_service import AnomalyDetectionService

logger = logging.getLogger(__name__)

router = APIRouter()


# ── Budget CRUD schemas ──────────────────────────────────────────────────────


_ALLOWED_CATEGORIES = {
    "housing", "insurance", "transport", "food", "utilities",
    "subscription", "leasing", "credit", "education", "health",
    "leisure", "savings", "other",
}


class BudgetLine(BaseModel):
    """A single recurring monthly budget line (rent, insurance, leasing…)."""
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    id: Optional[str] = Field(None, description="Stable id; auto-generated on POST.")
    label: str = Field(..., min_length=1, max_length=80)
    amount: float = Field(..., gt=0, le=1_000_000)
    category: str = Field("other")

    def normalised_category(self) -> str:
        return self.category if self.category in _ALLOWED_CATEGORIES else "other"


class BudgetUpsert(BaseModel):
    """Full budget upsert payload."""
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    income_monthly: Optional[float] = Field(
        None, ge=0, le=1_000_000,
        description=(
            "Override monthly income. If omitted, profile.incomeNetMonthly "
            "is used."
        ),
    )
    fixed_lines: List[BudgetLine] = Field(default_factory=list, max_length=80)
    variable_target_monthly: float = Field(0, ge=0, le=100_000)
    savings_target_monthly: float = Field(0, ge=0, le=100_000)


class BudgetResponse(BaseModel):
    """Budget as exposed to the client — includes computed signals."""
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    income_monthly: float
    income_source: str = Field(
        ..., description="'override' if user-set, 'profile' if from profile, 'unknown' otherwise."
    )
    fixed_lines: List[BudgetLine]
    total_fixed_monthly: float
    variable_target_monthly: float
    savings_target_monthly: float
    free_margin_monthly: float
    savings_rate: float = Field(..., description="0.0–1.0 of monthly income.")
    risk_level: str = Field(..., description="green | amber | red")
    premier_eclairage: str
    alertes: List[str]
    updated_at: Optional[datetime] = None


# ── Helpers ──────────────────────────────────────────────────────────────────


def _load_profile(db: Session, user_id: str) -> ProfileModel:
    profile = (
        db.query(ProfileModel)
        .filter(ProfileModel.user_id == user_id)
        .order_by(ProfileModel.updated_at.desc())
        .first()
    )
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    return profile


def _empty_budget() -> dict:
    return {
        "income_monthly": None,
        "fixed_lines": [],
        "variable_target_monthly": 0.0,
        "savings_target_monthly": 0.0,
        "updated_at": None,
    }


def _build_response(
    profile_data: dict, budget_data: dict
) -> BudgetResponse:
    income_override = budget_data.get("income_monthly")
    profile_income = profile_data.get("incomeNetMonthly")
    if income_override is not None:
        income = float(income_override)
        income_source = "override"
    elif profile_income is not None:
        income = float(profile_income)
        income_source = "profile"
    else:
        income = 0.0
        income_source = "unknown"

    raw_lines = budget_data.get("fixed_lines") or []
    lines = [
        BudgetLine(
            id=ln.get("id"),
            label=ln.get("label", ""),
            amount=float(ln.get("amount", 0)),
            category=ln.get("category", "other"),
        )
        for ln in raw_lines
    ]
    total_fixed = round(sum(ln.amount for ln in lines), 2)
    var_target = float(budget_data.get("variable_target_monthly") or 0)
    sav_target = float(budget_data.get("savings_target_monthly") or 0)
    free_margin = round(income - total_fixed - var_target - sav_target, 2)
    savings_rate = round(sav_target / income, 4) if income > 0 else 0.0

    if income == 0:
        risk = "red"
    elif free_margin < 0:
        risk = "red"
    elif savings_rate < 0.10:
        risk = "amber"
    else:
        risk = "green"

    alertes: list[str] = []
    if income == 0:
        alertes.append(
            "Aucun revenu mensuel renseigné — partage ton salaire net pour "
            "que MINT puisse calculer ta marge."
        )
    if free_margin < 0:
        alertes.append(
            f"Tes engagements dépassent ton revenu de "
            f"{abs(free_margin):.0f} CHF/mois. Identifie une ligne à "
            "réduire ou une recette à augmenter."
        )
    if 0 < savings_rate < 0.10 and free_margin >= 0:
        alertes.append(
            "Taux d'épargne sous 10% — règle de prudence FRC: viser 10–20% "
            "pour absorber un imprévu."
        )

    if income == 0:
        eclairage = (
            "On ne peut pas tracer ta marge sans revenu connu. "
            "Dis-moi ton salaire net mensuel pour démarrer."
        )
    elif free_margin < 0:
        eclairage = (
            f"Tu vis à crédit à hauteur de {abs(free_margin):.0f} CHF/mois — "
            "on regarde quelles dépenses sont compressibles ?"
        )
    elif savings_rate >= 0.20:
        eclairage = (
            f"Taux d'épargne {savings_rate*100:.0f}% — solide. "
            "On peut réfléchir à où placer ce flux (3a max ? rachat LPP ?)."
        )
    else:
        eclairage = (
            f"Marge libre {free_margin:.0f} CHF/mois pour {income:.0f} de "
            f"revenu. Cible savings rate ≥10% (actuellement "
            f"{savings_rate*100:.0f}%)."
        )

    updated_iso = budget_data.get("updated_at")
    updated_dt = (
        datetime.fromisoformat(updated_iso) if updated_iso else None
    )

    return BudgetResponse(
        income_monthly=income,
        income_source=income_source,
        fixed_lines=lines,
        total_fixed_monthly=total_fixed,
        variable_target_monthly=var_target,
        savings_target_monthly=sav_target,
        free_margin_monthly=free_margin,
        savings_rate=savings_rate,
        risk_level=risk,
        premier_eclairage=eclairage,
        alertes=alertes,
        updated_at=updated_dt,
    )


def _persist_budget(profile: ProfileModel, budget: dict) -> None:
    data = dict(profile.data or {})
    budget["updated_at"] = datetime.now(timezone.utc).isoformat()
    data["budget"] = budget
    profile.data = data
    profile.updated_at = datetime.now(timezone.utc)


# ── Endpoints ────────────────────────────────────────────────────────────────


@router.get("/me", response_model=BudgetResponse)
@limiter.limit("60/minute")
def get_my_budget(
    request: Request,
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> BudgetResponse:
    profile = _load_profile(db, current_user.id)
    data = dict(profile.data or {})
    budget = dict(data.get("budget") or _empty_budget())
    return _build_response(data, budget)


@router.put("/me", response_model=BudgetResponse)
@limiter.limit("30/minute")
def upsert_my_budget(
    request: Request,
    payload: BudgetUpsert,
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> BudgetResponse:
    profile = _load_profile(db, current_user.id)
    # Assign stable ids to lines that don't have one.
    lines = []
    for ln in payload.fixed_lines:
        ln_id = ln.id or uuid.uuid4().hex[:8]
        lines.append(
            {
                "id": ln_id,
                "label": ln.label.strip(),
                "amount": float(ln.amount),
                "category": ln.normalised_category(),
            }
        )
    budget = {
        "income_monthly": payload.income_monthly,
        "fixed_lines": lines,
        "variable_target_monthly": float(payload.variable_target_monthly),
        "savings_target_monthly": float(payload.savings_target_monthly),
    }
    _persist_budget(profile, budget)
    db.add(profile)
    db.commit()
    db.refresh(profile)
    data = dict(profile.data or {})
    return _build_response(data, dict(data.get("budget") or _empty_budget()))


@router.post(
    "/me/lines",
    response_model=BudgetResponse,
    status_code=status.HTTP_201_CREATED,
)
@limiter.limit("60/minute")
def add_or_update_line(
    request: Request,
    line: BudgetLine,
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> BudgetResponse:
    profile = _load_profile(db, current_user.id)
    data = dict(profile.data or {})
    budget = dict(data.get("budget") or _empty_budget())
    raw_lines = list(budget.get("fixed_lines") or [])
    line_id = line.id or uuid.uuid4().hex[:8]
    new_entry = {
        "id": line_id,
        "label": line.label.strip(),
        "amount": float(line.amount),
        "category": line.normalised_category(),
    }
    # Replace existing id if present, else append.
    replaced = False
    for i, existing in enumerate(raw_lines):
        if existing.get("id") == line_id:
            raw_lines[i] = new_entry
            replaced = True
            break
    if not replaced:
        if len(raw_lines) >= 80:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Maximum 80 lignes de budget atteint.",
            )
        raw_lines.append(new_entry)
    budget["fixed_lines"] = raw_lines
    _persist_budget(profile, budget)
    db.add(profile)
    db.commit()
    db.refresh(profile)
    data = dict(profile.data or {})
    return _build_response(data, dict(data.get("budget") or _empty_budget()))


@router.delete("/me/lines/{line_id}", response_model=BudgetResponse)
@limiter.limit("60/minute")
def delete_line(
    request: Request,
    line_id: str,
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> BudgetResponse:
    profile = _load_profile(db, current_user.id)
    data = dict(profile.data or {})
    budget = dict(data.get("budget") or _empty_budget())
    raw_lines = list(budget.get("fixed_lines") or [])
    new_lines = [ln for ln in raw_lines if ln.get("id") != line_id]
    if len(new_lines) == len(raw_lines):
        raise HTTPException(
            status_code=404, detail=f"Ligne '{line_id}' introuvable."
        )
    budget["fixed_lines"] = new_lines
    _persist_budget(profile, budget)
    db.add(profile)
    db.commit()
    db.refresh(profile)
    data = dict(profile.data or {})
    return _build_response(data, dict(data.get("budget") or _empty_budget()))


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
