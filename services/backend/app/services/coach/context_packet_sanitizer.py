"""Strict sanitizer for mobile CoachContextPacket payloads.

The mobile packet is already privacy-scoped, but the backend boundary must not
trust arbitrary nested dicts just because the top-level key is whitelisted.
"""

from __future__ import annotations

import re
from typing import Any


_INJECTION_PATTERNS = [
    re.compile(r"ignore\s+(previous|all)\s+instructions", re.I),
    re.compile(r"system\s*:", re.I),
    re.compile(r"developer\s*:", re.I),
]

_TOP_KEYS = {"computed_at", "facts", "missing_fields", "trajectory", "next_questions"}
_FACT_KEYS = {
    "id",
    "domain",
    "field_path",
    "value",
    "source",
    "confidence",
    "freshness",
    "state",
    "updated_at",
}
_MISSING_KEYS = {"field_path", "domain", "reason"}
_TRAJECTORY_KEYS = {
    "status",
    "current_monthly_free",
    "current_monthly_capacity",
    "target_amount",
    "months_to_target",
    "monthly_required",
    "monthly_gap",
    "next_lever_id",
}
_QUESTION_KEYS = {"id", "domain", "field_path"}

_ALLOWED_IDS = {
    "profile.canton",
    "profile.birth_year",
    "situation.gross_annual_income",
    "situation.monthly_housing_cost",
    "situation.lamal_premium_monthly",
    "situation.liquid_savings",
    "situation.investments",
    "situation.total_debt",
    "budget.monthly_net",
    "budget.monthly_free",
    "budget.monthly_capacity",
    "budget.monthly_charges",
    "pillar.avs.contribution_years",
    "pillar.avs.gaps",
    "pillar.avs.estimated_monthly_pension",
    "pillar.lpp.total_balance",
    "pillar.lpp.insured_salary",
    "pillar.lpp.buyback_max",
    "pillar.3a.total_balance",
    "pillar.3a.accounts_count",
    "pillar.3a.annual_contribution",
    "trajectory.status",
    "trajectory.monthly_required",
    "trajectory.monthly_gap",
}
_ALLOWED_PATHS = {
    "situation.canton",
    "situation.birthYear",
    "situation.grossAnnualIncome",
    "situation.monthlyHousingCost",
    "situation.lamalPremiumMonthly",
    "situation.liquidSavings",
    "situation.investments",
    "situation.totalDebt",
    "budget.present.monthlyNet",
    "budget.present.monthlyFree",
    "budget.present.monthlyCapacity",
    "budget.present.monthlyCharges",
    "pillars.avs.contributionYears",
    "pillars.avs.gaps",
    "pillars.avs.estimatedMonthlyPension",
    "pillars.lpp.totalBalance",
    "pillars.lpp.insuredSalary",
    "pillars.lpp.buybackMax",
    "pillars.pillar3a.totalBalance",
    "pillars.pillar3a.accountsCount",
    "pillars.pillar3a.annualContribution",
    "trajectory.status",
    "trajectory.targetAmount",
    "trajectory.monthlyRequired",
    "trajectory.monthlyGap",
    "trajectory.currentMonthlyCapacity",
}
_ALLOWED_QUESTION_IDS = {
    "define_target_amount",
    "review_fixed_charges",
    "increase_monthly_capacity",
    "confirm_plan_tracking",
}
_ALLOWED_TRAJECTORY_STATUS = {
    "insufficientData",
    "blocked",
    "drifting",
    "onTrack",
}
_ALLOWED_DOMAINS = {
    "profile",
    "situation",
    "budget",
    "pillar_avs",
    "pillar_lpp",
    "pillar_3a",
    "trajectory",
}
_ALLOWED_SOURCES = {"wizard", "calculated", "estimated", "certificate", "unknown"}
_ALLOWED_FRESHNESS = {"fresh", "stale", "unknown"}
_ALLOWED_STATES = {"known", "estimated", "missing"}


def _sanitize_string(value: Any, *, max_len: int = 96, allowed: set[str] | None = None):
    if not isinstance(value, str):
        return None
    sanitized = value[:max_len]
    for pattern in _INJECTION_PATTERNS:
        sanitized = pattern.sub("[FILTERED]", sanitized)
    if allowed is not None and sanitized not in allowed:
        return None
    return sanitized


def _number(value: Any):
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return value
    return None


def sanitize_coach_context_packet(value: Any) -> dict[str, Any]:
    """Return a strict, bounded, non-PII CoachContextPacket shape."""
    if not isinstance(value, dict):
        return {}

    packet = {k: v for k, v in value.items() if k in _TOP_KEYS and v is not None}
    safe: dict[str, Any] = {}

    computed_at = _sanitize_string(packet.get("computed_at"), max_len=40)
    if computed_at:
        safe["computed_at"] = computed_at

    facts = []
    for item in packet.get("facts") or []:
        if not isinstance(item, dict):
            continue
        fact_id = _sanitize_string(item.get("id"), allowed=_ALLOWED_IDS)
        field_path = _sanitize_string(item.get("field_path"), allowed=_ALLOWED_PATHS)
        domain = _sanitize_string(item.get("domain"), allowed=_ALLOWED_DOMAINS)
        if not fact_id or not field_path or not domain:
            continue
        fact: dict[str, Any] = {
            "id": fact_id,
            "domain": domain,
            "field_path": field_path,
        }
        for key in sorted(_FACT_KEYS - {"id", "domain", "field_path"}):
            if key not in item or item[key] is None:
                continue
            if key in {"value", "confidence"}:
                number = _number(item[key])
                if number is not None:
                    fact[key] = number
            elif key == "source":
                source = _sanitize_string(item[key], allowed=_ALLOWED_SOURCES)
                if source:
                    fact[key] = source
            elif key == "freshness":
                freshness = _sanitize_string(item[key], allowed=_ALLOWED_FRESHNESS)
                if freshness:
                    fact[key] = freshness
            elif key == "state":
                state = _sanitize_string(item[key], allowed=_ALLOWED_STATES)
                if state:
                    fact[key] = state
            elif key == "updated_at":
                updated_at = _sanitize_string(item[key], max_len=40)
                if updated_at:
                    fact[key] = updated_at
        facts.append(fact)
    safe["facts"] = facts[:24]

    missing_fields = []
    for item in packet.get("missing_fields") or []:
        if not isinstance(item, dict):
            continue
        field_path = _sanitize_string(item.get("field_path"), allowed=_ALLOWED_PATHS)
        domain = _sanitize_string(item.get("domain"), allowed=_ALLOWED_DOMAINS)
        reason = _sanitize_string(item.get("reason"), max_len=48)
        if field_path and domain and reason:
            missing_fields.append(
                {"field_path": field_path, "domain": domain, "reason": reason}
            )
    safe["missing_fields"] = missing_fields[:24]

    trajectory = packet.get("trajectory") or {}
    safe_trajectory: dict[str, Any] = {}
    if isinstance(trajectory, dict):
        for key in _TRAJECTORY_KEYS:
            raw = trajectory.get(key)
            if raw is None:
                continue
            if key == "status":
                status = _sanitize_string(raw, allowed=_ALLOWED_TRAJECTORY_STATUS)
                if status:
                    safe_trajectory[key] = status
            elif key == "next_lever_id":
                lever = _sanitize_string(raw, allowed=_ALLOWED_QUESTION_IDS)
                if lever:
                    safe_trajectory[key] = lever
            else:
                number = _number(raw)
                if number is not None:
                    safe_trajectory[key] = number
    safe["trajectory"] = safe_trajectory

    questions = []
    for item in packet.get("next_questions") or []:
        if not isinstance(item, dict):
            continue
        question_id = _sanitize_string(item.get("id"), allowed=_ALLOWED_QUESTION_IDS)
        field_path = _sanitize_string(item.get("field_path"), allowed=_ALLOWED_PATHS)
        domain = _sanitize_string(item.get("domain"), allowed=_ALLOWED_DOMAINS)
        if question_id and field_path and domain:
            questions.append(
                {"id": question_id, "domain": domain, "field_path": field_path}
            )
    safe["next_questions"] = questions[:8]

    return safe


def summarize_coach_context_packet(value: Any) -> str:
    """Build a short prompt-safe summary from the strict packet shape."""
    packet = sanitize_coach_context_packet(value)
    if not packet:
        return ""

    lines = ["--- DATA SPINE MINT ---"]
    trajectory = packet.get("trajectory") or {}
    if isinstance(trajectory, dict) and trajectory.get("status"):
        lines.append(f"Trajectoire: {trajectory['status']}")
        if trajectory.get("monthly_gap") is not None:
            lines.append(f"Ecart mensuel: {trajectory['monthly_gap']}")

    facts = packet.get("facts") or []
    fact_ids = [f["id"] for f in facts[:8] if isinstance(f, dict) and f.get("id")]
    if fact_ids:
        lines.append("Faits disponibles: " + ", ".join(fact_ids))

    missing = packet.get("missing_fields") or []
    missing_paths = [
        f["field_path"]
        for f in missing[:6]
        if isinstance(f, dict) and f.get("field_path")
    ]
    if missing_paths:
        lines.append("Donnees manquantes: " + ", ".join(missing_paths))

    questions = packet.get("next_questions") or []
    question_ids = [
        q["id"] for q in questions[:4] if isinstance(q, dict) and q.get("id")
    ]
    if question_ids:
        lines.append("Prochaines questions: " + ", ".join(question_ids))

    lines.append("--- FIN DATA SPINE ---")
    return "\n".join(lines)
