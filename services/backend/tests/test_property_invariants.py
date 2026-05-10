"""Hypothesis property tests on the Python calc parity surface — CALC-02.

Eight invariants, all rooted in established Swiss-financial truth:
  P1. get_lpp_bonification_rate is bounded in [0, 0.18]              (LPP art. 16)
  P2. get_lpp_bonification_rate is monotone non-decreasing in age    (LPP art. 16)
  P3. rente_from_ramd is non-negative everywhere                     (LAVS art. 34)
  P4. rente_from_ramd is bounded by AVS_RENTE_MAX_MENSUELLE          (LAVS art. 34)
  P5. rente_from_ramd is monotone non-decreasing in salary           (Echelle 44 concavity)
  P6. get_ai_rente_monthly is monotone non-decreasing in degree      (LAI art. 28)
  P7. calculate_progressive_capital_tax is non-negative              (LIFD art. 38)
  P8. calculate_progressive_capital_tax with rate=0 returns 0        (homogeneity)

Settings (per CONTEXT 92.5 D-17):
  default profile: max_examples=200, deadline=None
  ci profile     : max_examples=500, deadline=None (run via --hypothesis-profile=ci nightly)

Plan reference: .planning/phases/92.5-mvp-calc-rigor-foundations/92.5-02-property-suite-PLAN.md
"""

from __future__ import annotations

import hypothesis.strategies as st
from hypothesis import HealthCheck, given
from hypothesis import settings as hyp_settings

from app.constants.social_insurance import (
    AVS_RAMD_MAX,
    AVS_RENTE_MAX_MENSUELLE,
    calculate_progressive_capital_tax,
    get_ai_rente_monthly,
    get_lpp_bonification_rate,
    rente_from_ramd,
)

# ──────────────────────────────────────────────────────────────────────
# Hypothesis profiles per CONTEXT 92.5 D-17.
# ──────────────────────────────────────────────────────────────────────
hyp_settings.register_profile(
    "default",
    max_examples=200,
    deadline=None,
    suppress_health_check=[HealthCheck.too_slow],
)
hyp_settings.register_profile(
    "ci",
    max_examples=500,
    deadline=None,
    suppress_health_check=[HealthCheck.too_slow],
)
hyp_settings.load_profile("default")


# ──────────────────────────────────────────────────────────────────────
# P1, P2 — LPP bonification rate (LPP art. 16)
# ──────────────────────────────────────────────────────────────────────
@given(age=st.integers(min_value=0, max_value=100))
def test_p1_lpp_bonification_bounded(age: int) -> None:
    """LPP art. 16: bonification rate is in [0, 0.18]."""
    rate = get_lpp_bonification_rate(age)
    assert 0.0 <= rate <= 0.18, (
        f"age={age} rate={rate} out of LPP art. 16 bounds [0, 0.18]"
    )


@given(
    age_a=st.integers(min_value=0, max_value=100),
    age_b=st.integers(min_value=0, max_value=100),
)
def test_p2_lpp_bonification_monotone(age_a: int, age_b: int) -> None:
    """LPP art. 16: bonification rate is monotone non-decreasing in age."""
    if age_a > age_b:
        age_a, age_b = age_b, age_a
    rate_a = get_lpp_bonification_rate(age_a)
    rate_b = get_lpp_bonification_rate(age_b)
    assert rate_a <= rate_b, (
        f"non-monotone: age={age_a} rate={rate_a} > age={age_b} rate={rate_b}"
    )


# ──────────────────────────────────────────────────────────────────────
# P3, P4, P5 — AVS rente from RAMD (LAVS art. 34, Echelle 44)
# ──────────────────────────────────────────────────────────────────────
@given(
    salary=st.floats(
        min_value=0.0,
        max_value=AVS_RAMD_MAX * 2,
        allow_nan=False,
        allow_infinity=False,
    ),
)
def test_p3_rente_non_negative(salary: float) -> None:
    """LAVS art. 34: AVS rente is non-negative for any salary input."""
    rente = rente_from_ramd(salary)
    assert rente >= 0, f"salary={salary} produced negative rente={rente}"


@given(
    salary=st.floats(
        min_value=0.0,
        max_value=AVS_RAMD_MAX * 2,
        allow_nan=False,
        allow_infinity=False,
    ),
)
def test_p4_rente_bounded_by_max(salary: float) -> None:
    """LAVS art. 34: AVS rente is bounded above by AVS_RENTE_MAX_MENSUELLE."""
    rente = rente_from_ramd(salary)
    # +1 CHF tolerance for floating-point linear interpolation rounding at the
    # right edge of Echelle 44.
    assert rente <= AVS_RENTE_MAX_MENSUELLE + 1.0, (
        f"salary={salary} produced rente={rente} > AVS max {AVS_RENTE_MAX_MENSUELLE}"
    )


@given(
    s_low=st.floats(
        min_value=0.0,
        max_value=80_000.0,
        allow_nan=False,
        allow_infinity=False,
    ),
    delta=st.floats(
        min_value=0.0,
        max_value=80_000.0,
        allow_nan=False,
        allow_infinity=False,
    ),
)
def test_p5_rente_monotone(s_low: float, delta: float) -> None:
    """LAVS art. 34, Echelle 44: rente is monotone non-decreasing in salary."""
    s_high = s_low + delta
    r_low = rente_from_ramd(s_low)
    r_high = rente_from_ramd(s_high)
    # +0.01 CHF tolerance for FP comparison at flat regions of the table.
    assert r_low <= r_high + 0.01, (
        f"non-monotone: s_low={s_low} r_low={r_low} > "
        f"s_high={s_high} r_high={r_high}"
    )


# ──────────────────────────────────────────────────────────────────────
# P6 — AI rente monotone in disability degree (LAI art. 28)
# ──────────────────────────────────────────────────────────────────────
@given(
    deg_a=st.integers(min_value=0, max_value=100),
    deg_b=st.integers(min_value=0, max_value=100),
)
def test_p6_ai_rente_monotone(deg_a: int, deg_b: int) -> None:
    """LAI art. 28 al. 1: monthly AI rente is non-decreasing in disability degree."""
    if deg_a > deg_b:
        deg_a, deg_b = deg_b, deg_a
    r_a = get_ai_rente_monthly(deg_a)
    r_b = get_ai_rente_monthly(deg_b)
    assert r_a <= r_b, (
        f"non-monotone: deg={deg_a} rente={r_a} > deg={deg_b} rente={r_b}"
    )


# ──────────────────────────────────────────────────────────────────────
# P7, P8 — Progressive capital tax (LIFD art. 38)
# ──────────────────────────────────────────────────────────────────────
@given(
    amount=st.floats(
        min_value=0.0,
        max_value=2_000_000.0,
        allow_nan=False,
        allow_infinity=False,
    ),
    base_rate=st.floats(
        min_value=0.0,
        max_value=0.30,
        allow_nan=False,
        allow_infinity=False,
    ),
)
def test_p7_capital_tax_non_negative(amount: float, base_rate: float) -> None:
    """LIFD art. 38: progressive capital tax is always non-negative."""
    tax = calculate_progressive_capital_tax(amount, base_rate)
    assert tax >= 0, f"amount={amount} rate={base_rate} produced negative tax={tax}"


@given(
    amount=st.floats(
        min_value=0.0,
        max_value=2_000_000.0,
        allow_nan=False,
        allow_infinity=False,
    ),
)
def test_p8_capital_tax_zero_rate_is_zero(amount: float) -> None:
    """LIFD art. 38: zero base rate ⇒ zero tax (homogeneity)."""
    tax = calculate_progressive_capital_tax(amount, 0.0)
    assert tax == 0.0, f"rate=0 should give tax=0, got tax={tax} for amount={amount}"
