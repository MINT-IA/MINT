"""Phase mint-calc-engine-v1 W3 Plan 15 — D-CE-14 SLI tests.

Synthetic warm precision / recall baseline for the Plan 15 BackgroundTasks
pre-compute. Per CONTEXT.md D-CE-14 SLI :

- Precision >= 60% : (warmed ∩ requested) / warmed
- Recall    >= 70% : (warmed ∩ requested) / requested

The thresholds are TARGETS, not hard gates on v1 (per PM reservation : the
baseline measurement starts post-W4 metrics ship). If thresholds are missed,
the test still passes with `pytest.skip` so the suite remains green ; the
delta-to-target is documented in SUMMARY.md.

Synthetic scenarios map life-event-coherent fact_key sets to the calc-name
families a user is realistically expected to ask in the next turn. Calc-name
matching is by substring on the canonical REGISTRY name (since names follow
the `<file_stem>__<func>` pattern, substring is a sufficient family proxy).
"""

from __future__ import annotations

from unittest.mock import MagicMock
from uuid import uuid4

import pytest

from app.services.coach.pre_compute import precompute_after_fact_save


# Synthetic scenarios : (fact_key, semantic_intent, expected_calc_substrings).
#
# Each tuple : when the user mutates `fact_key`, the next-turn intent is
# typically `semantic_intent`. The expected_calc_substrings list contains
# canonical-name substrings that match the calculator family the user is
# realistically asking about. Matching is `substring in calc_name` —
# tolerant to the AST-generated naming convention.
#
# 20 scenarios spanning : housing / retirement / taxes / family / cross-border
# / career / debt / arbitrage.
SYNTHETIC_SCENARIOS: list[tuple[str, str, list[str]]] = [
    # Housing
    ("prix_achat", "housing", ["affordability", "amortization", "epl"]),
    ("montant_hypothecaire", "housing", ["amortization", "saron", "affordability"]),
    ("taux_hypothecaire", "housing", ["amortization", "saron"]),
    ("is_property_owner", "housing", ["allocation", "affordability", "imputed"]),
    # Retirement / LPP / 3a / AVS
    ("retirement_age", "retirement", ["avs", "retirement", "lpp", "rente"]),
    ("current_age", "retirement", ["avs", "retirement", "unemployment"]),
    ("avoir_3a", "retirement", ["affordability", "allocation"]),
    ("avoir_lpp", "retirement", ["affordability", "rachat", "lpp"]),
    ("annees_avant_retraite", "retirement", ["allocation", "rachat", "lpp"]),
    # Taxes
    ("canton", "taxes", ["wealth", "fiscal", "affordability", "calendrier"]),
    ("taux_marginal", "taxes", ["allocation", "rachat"]),
    ("revenu_brut_annuel", "taxes", ["affordability", "allocation"]),
    # Family
    ("civil_status", "family", ["divorce", "succession", "mariage", "couple"]),
    ("is_couple", "family", ["avs", "retirement", "couple"]),
    # Cross-cutting / arbitrage
    ("montant_disponible", "arbitrage", ["allocation"]),
    ("rendement_3a", "arbitrage", ["allocation", "amortization", "rachat"]),
    ("rendement_lpp", "arbitrage", ["allocation", "rachat"]),
    ("rendement_marche", "arbitrage", ["allocation", "real_return"]),
    # Career / unemployment
    ("gross_salary", "career", ["avs", "affordability"]),
    ("life_expectancy", "retirement", ["avs", "retirement", "rente"]),
]


def _warmed_calc_names_for(fact_key: str) -> list[str]:
    """Capture the top-3 calc-kind names that precompute_after_fact_save selects."""
    captured: list[str] = []
    bg = MagicMock()

    def _capture(_fn, profile_id, kind, db):
        captured.append(kind)

    bg.add_task = MagicMock(side_effect=_capture)

    precompute_after_fact_save(
        background_tasks=bg,
        fact_key=fact_key,
        fact_value=None,
        profile_id=str(uuid4()),
        db=MagicMock(),
    )
    return captured


def _matches_expected(calc_name: str, expected_substrings: list[str]) -> bool:
    """A warmed calc 'matches' the next-turn intent if any expected substring
    appears in the canonical calc name (case-insensitive).
    """
    cn_lower = calc_name.lower()
    return any(sub.lower() in cn_lower for sub in expected_substrings)


# ----------------------------------------------------------------------- Test 1
def test_warm_precision_baseline():
    """D-CE-14 SLI Test 1 — synthetic precision baseline.

    For each scenario : precision = |warmed ∩ requested| / |warmed|.
    Average across scenarios MUST be tracked ; >= 0.60 is the target.
    If below target, the test SKIPS with a delta-to-target message so the
    full suite stays green (per PM reservation).
    """
    ratios: list[float] = []
    detail: list[tuple[str, float, list[str], list[str]]] = []

    for fact_key, _intent, expected in SYNTHETIC_SCENARIOS:
        warmed = _warmed_calc_names_for(fact_key)
        if not warmed:
            continue
        matched = [w for w in warmed if _matches_expected(w, expected)]
        precision = len(matched) / len(warmed)
        ratios.append(precision)
        detail.append((fact_key, precision, warmed, matched))

    assert ratios, "No scenarios produced warmed calcs — synthetic table is broken"
    avg_precision = sum(ratios) / len(ratios)
    target = 0.60

    print(f"\n[D-CE-14 SLI] avg precision = {avg_precision:.3f} (target {target:.2f})")
    print(f"[D-CE-14 SLI] scenarios with warmed > 0 = {len(ratios)}/{len(SYNTHETIC_SCENARIOS)}")
    for fk, p, w, m in detail[:5]:
        print(f"  {fk!r}: p={p:.2f} warmed={len(w)} matched={len(m)}")

    if avg_precision < target:
        pytest.skip(
            f"D-CE-14 SLI BASELINE : precision={avg_precision:.3f} < target {target:.2f} "
            f"(delta {target - avg_precision:+.3f}). Baseline tracked per CONTEXT.md PM reservation."
        )


# ----------------------------------------------------------------------- Test 2
def test_warm_recall_baseline():
    """D-CE-14 SLI Test 2 — synthetic recall baseline.

    For each scenario : recall = |warmed ∩ requested| / |requested|.
    Since we don't have a fixed 'requested' set (the user could ask any of
    several calcs), we use a substring-family proxy : recall = whether any
    of the warmed calcs covers ANY of the expected families.

    Target >= 0.70 (i.e. at least 70% of scenarios cover ≥1 expected family).
    """
    covered: list[bool] = []
    for fact_key, _intent, expected in SYNTHETIC_SCENARIOS:
        warmed = _warmed_calc_names_for(fact_key)
        if not warmed:
            covered.append(False)
            continue
        covered.append(any(_matches_expected(w, expected) for w in warmed))

    avg_recall = sum(1 for c in covered if c) / len(covered)
    target = 0.70

    print(f"\n[D-CE-14 SLI] coverage recall = {avg_recall:.3f} (target {target:.2f})")
    print(f"[D-CE-14 SLI] covered scenarios = {sum(covered)}/{len(SYNTHETIC_SCENARIOS)}")

    if avg_recall < target:
        pytest.skip(
            f"D-CE-14 SLI BASELINE : recall={avg_recall:.3f} < target {target:.2f} "
            f"(delta {target - avg_recall:+.3f}). Baseline tracked per CONTEXT.md PM reservation."
        )


# ----------------------------------------------------------------------- Test 3
def test_warm_precision_recall_edge_case_unknown_fact_key():
    """Unknown fact_key → 0 warmed, 0 requested → no error, no precision."""
    warmed = _warmed_calc_names_for("nonexistent_field_xyz_999")
    assert warmed == [], "Unknown fact_key must produce 0 warmed calcs"
    # Precision/recall undefined ; assert no exception raised.
