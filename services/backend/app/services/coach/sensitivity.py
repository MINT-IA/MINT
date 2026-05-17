"""Phase 95 DAG-INVALIDATION — uni-variate +/-10% sensitivity (D-11).

5 perturb keys (RESEARCH §D-11 — selected by impact on AVS/LPP/3a
projections + LSFin relevance) :
  - income_brut_annual    (drives AVS rente, 3a ceiling, marginal tax)
  - current_lpp_balance   (drives projected LPP at retirement)
  - current_age           (drives years-to-retirement compounding)
  - target_retirement_age (drives capital window + LPP conversion)
  - current_3a_balance    (drives 3a runway + tax-deduction recurrence)

Categorical inputs (marital_status, canton) are EXCLUDED — uni-variate
+/-10% doesn't apply. Full Sobol indices via Saltelli is backlog 999.x.

Returns a dict of exactly 5 GroundingPackEntry (matches the D-08
what_ifs field shape : dict[str, GroundingPackEntry] min=max=5).

LSFin compliance — narrator MUST annotate emitted intervals with
« selon le modèle simplifié actuel » verbatim when credible_low/high
are non-None (D-12 escape hatch enforced by
tools/checks/banned_terms_python.py extension in Task 6).
"""
from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Callable

from app.services.coach.grounding_pack import GroundingPackEntry


PERTURB_KEYS: tuple = (
    "income_brut_annual",
    "current_lpp_balance",
    "current_age",
    "target_retirement_age",
    "current_3a_balance",
)


def compute_what_ifs(
    base_inputs: dict,
    compute_fn: Callable[[dict], dict],
    perturb_keys: tuple = PERTURB_KEYS,
) -> dict:
    """Compute 5 uni-variate +/-10% sensitivity entries.

    Each entry value is the SIGNED delta between base outcome and the
    +10% perturbed outcome on the headline « retirement_income » figure.
    raw dict carries {baseline, plus10, minus10} for audit trail.
    credible_low = -10% delta, credible_high = +10% delta (NOT a
    statistical CI ; the bounds-as-range pattern is intentional MVP
    shorthand for what_ifs surfaces — bootstrap CIs live in entries
    via bootstrap_ci.py per D-12).

    Args:
        base_inputs: dict with at minimum the 5 PERTURB_KEYS as numerics.
        compute_fn: closure that takes inputs dict, returns dict with
            at minimum `{"retirement_income": <num>}` key.
        perturb_keys: which inputs to perturb (defaults to PERTURB_KEYS).

    Returns:
        dict of {f"sensitivity_{key}": GroundingPackEntry} — exactly 5 entries.
    """
    baseline_out = compute_fn(base_inputs)
    baseline_inc = Decimal(str(baseline_out["retirement_income"]))
    result: dict = {}
    ts = datetime.now(timezone.utc).isoformat()
    for k in perturb_keys:
        base_v = Decimal(str(base_inputs[k]))
        plus = {**base_inputs, k: float(base_v * Decimal("1.10"))}
        minus = {**base_inputs, k: float(base_v * Decimal("0.90"))}
        out_plus = compute_fn(plus)
        out_minus = compute_fn(minus)
        delta_plus = Decimal(str(out_plus["retirement_income"])) - baseline_inc
        delta_minus = Decimal(str(out_minus["retirement_income"])) - baseline_inc
        # Rule 1 fix : credible_low/high must hold min/max so the invariant
        # `credible_low <= credible_high` is preserved across non-monotone
        # inputs (e.g. `current_age` has NEGATIVE correlation with
        # retirement_income, so a +10% perturbation produces a negative
        # delta and a -10% perturbation produces a positive delta).
        lo = min(delta_plus, delta_minus)
        hi = max(delta_plus, delta_minus)
        result[f"sensitivity_{k}"] = GroundingPackEntry(
            value=delta_plus.quantize(Decimal("0.01")),
            raw={"baseline": baseline_out, "plus10": out_plus, "minus10": out_minus},
            source_ref=f"sensitivity.{k}",
            credible_low=lo.quantize(Decimal("0.01")),
            credible_high=hi.quantize(Decimal("0.01")),
            staleness_iso=ts,
        )
    return result


__all__ = ["PERTURB_KEYS", "compute_what_ifs"]
