"""Phase 95 DAG-INVALIDATION — 3-point Pareto scalarisation MVP.

Per CONTEXT D-10 + RESEARCH §D-10 :
- 3 fixed weight sets across (tax_saving, liquidity, ruin_red).
- NOT a real Pareto front — NSGA-II via pymoo is backlog 999.2.
- Backend Python is a CONSUMER of Dart arbitrage_engine outputs
  (per CLAUDE.md #4 — financial_core/ is SOURCE OF TRUTH). Do NOT
  re-implement allocation logic here ; this module scores serialised
  trajectoires (dicts arrived via API or pre-computed by the wrapper).

Phase 95 ships this as a pure-Python compute layer with synthetic
trajectoire dict inputs. Phase 96 W2 wires arbitrage_engine outputs
to this consumer (see 95-02-PLAN.md frontmatter `deferred:` block).
"""
from __future__ import annotations

from decimal import Decimal

from app.services.coach.grounding_pack import ParetoPoint


# CONTEXT D-10 — 3 fixed weight sets, locked at planning time.
PARETO_WEIGHT_SETS: tuple = (
    {
        "label": "fiscal_pure",
        "weights": {
            "tax_saving": Decimal("1.00"),
            "liquidity":  Decimal("0.00"),
            "ruin_red":   Decimal("0.00"),
        },
    },
    {
        "label": "liquidity_prioritized",
        "weights": {
            "tax_saving": Decimal("0.50"),
            "liquidity":  Decimal("0.50"),
            "ruin_red":   Decimal("0.00"),
        },
    },
    {
        "label": "ruin_reduction_prioritized",
        "weights": {
            "tax_saving": Decimal("0.40"),
            "liquidity":  Decimal("0.00"),
            "ruin_red":   Decimal("0.60"),
        },
    },
)


def compute_pareto_points(
    profile: dict,
    trajectoires: list,
) -> list:
    """For each weight set, score the trajectoires and pick the winning allocation.

    Args:
        profile: User profile (unused at MVP — held for Phase 96 ext).
        trajectoires: List of dicts with keys
            {tax_saving_chf, liquidity_score, ruin_prob_reduction, allocation}.
            `allocation` is a dict[str, float] CHF amounts per levier.

    Returns:
        Exactly 3 ParetoPoint in canonical order (fiscal_pure,
        liquidity_prioritized, ruin_reduction_prioritized).
    """
    points: list = []
    for spec in PARETO_WEIGHT_SETS:
        scored = []
        for t in trajectoires:
            weighted = (
                spec["weights"]["tax_saving"] * Decimal(str(t["tax_saving_chf"]))
                + spec["weights"]["liquidity"] * Decimal(str(t["liquidity_score"]))
                + spec["weights"]["ruin_red"] * Decimal(str(t["ruin_prob_reduction"]))
            )
            scored.append((weighted, t))
        # Sort by weighted score descending — stable for ties.
        scored.sort(key=lambda x: x[0], reverse=True)
        winner = scored[0][1]
        points.append(
            ParetoPoint(
                label=spec["label"],
                weights={k: Decimal(str(v)) for k, v in spec["weights"].items()},
                allocation={k: Decimal(str(v)) for k, v in winner["allocation"].items()},
                projected_outcomes={
                    "tax_saving_chf":  Decimal(str(winner["tax_saving_chf"])),
                    "liquidity_score": Decimal(str(winner["liquidity_score"])),
                    "ruin_prob_red":   Decimal(str(winner["ruin_prob_reduction"])),
                },
            )
        )
    return points


__all__ = ["PARETO_WEIGHT_SETS", "compute_pareto_points"]
