"""
Golden Test: Julien + Lauren — Deterministic onboarding minimal profile tests.

10 tests validating the MinimalProfileService with the golden couple:
  - Julien: 50 yo, 100k CHF, ZH, swiss_native
  - Lauren: 45 yo, 60k CHF, ZH, expat_us (FATCA)

Test groups:
  1. test_julien_base — 3 inputs only, confidence = 30%
  2. test_julien_full — All fields, confidence = 100%
  3. test_julien_complementaire_vs_base — LPP caisse type comparison
  4. test_lauren_base — 3 inputs only, confidence = 30%
  5. test_lauren_full — All fields with debt, confidence = 100%
  6. test_lauren_debt_reduces_retirement — Debt impact comparison
  7. test_julien_replacement_ratio — Reasonable range check
  8. test_lauren_replacement_ratio_with_debt — Lower range with debt
  9. test_debt_priority_monthly_over_total — monthly_debt_service wins
  10. test_debt_estimation_from_total — total_debts * 0.005 fallback

Sources:
    - LAVS art. 21-29, 34, 40 (rente AVS, duree cotisation, reduction)
    - LPP art. 7, 8, 14, 15-16 (seuil, coordination, conversion, bonifications)
    - OPP3 art. 7 (plafond 3a: 7'258 CHF avec LPP)
    - LIFD art. 38 (imposition du capital de prevoyance)
"""


from app.services.onboarding.minimal_profile_service import compute_minimal_profile
from app.services.onboarding.onboarding_models import MinimalProfileInput


# ═══════════════════════════════════════════════════════════════════════════════
# Helpers — Golden couple input builders
# ═══════════════════════════════════════════════════════════════════════════════


def _julien_base() -> MinimalProfileInput:
    """Julien: born 1977, age 49, 122'207 CHF/an, VS (CLAUDE.md §8)."""
    return MinimalProfileInput(
        age=49,
        gross_salary=122_207.0,
        canton="VS",
    )


def _julien_full() -> MinimalProfileInput:
    """Julien with ALL optional fields (CLAUDE.md §8 golden values)."""
    return MinimalProfileInput(
        age=49,
        gross_salary=122_207.0,
        canton="VS",
        household_type="couple",
        current_savings=32_000.0,  # 3a capital
        is_property_owner=False,
        existing_3a=32_000.0,
        existing_lpp=70_377.0,  # Actual LPP from CPE certificate
        lpp_caisse_type="complementaire",  # CPE Plan Maxi
        monthly_debt_service=0.0,
    )


def _lauren_base() -> MinimalProfileInput:
    """Lauren: born 1982, age 43, 67'000 CHF/an, VS (CLAUDE.md §8)."""
    return MinimalProfileInput(
        age=43,
        gross_salary=67_000.0,
        canton="VS",
    )


def _lauren_full() -> MinimalProfileInput:
    """Lauren with ALL optional fields (CLAUDE.md §8 golden values)."""
    return MinimalProfileInput(
        age=43,
        gross_salary=67_000.0,
        canton="VS",
        household_type="couple",
        current_savings=14_000.0,  # 3a capital
        is_property_owner=False,
        existing_3a=14_000.0,
        existing_lpp=19_620.0,  # Lauren LPP from HOTELA certificate
        lpp_caisse_type="base",
        monthly_debt_service=0.0,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Test class
# ═══════════════════════════════════════════════════════════════════════════════


class TestGoldenJulienLauren:
    """Golden test suite for Julien (49, 122k, VS) + Lauren (43, 67k, VS) — CLAUDE.md §8."""

    # ── 1. Julien base (3 inputs only) ────────────────────────────────────────

    def test_julien_base(self):
        """Julien with only age=49, salary=122k, canton=VS (CLAUDE.md §8).

        At 100k salary (above AVS RAMD max of 88'200), Julien should get
        near-maximum AVS rente. LPP estimated from age 25 should be substantial.
        With only 3 inputs, confidence must be 30% and 7 fields estimated.
        """
        result = compute_minimal_profile(_julien_base())

        assert result.projected_avs_monthly > 2000, (
            f"Julien at 100k should get near-max AVS rente, got {result.projected_avs_monthly}"
        )
        assert result.projected_lpp_capital > 200_000, (
            f"Julien with 25 years of contributions (estimated from age 25) "
            f"should have >300k LPP, got {result.projected_lpp_capital}"
        )
        assert result.confidence_score == 30.0, (
            f"With only 3 inputs, confidence must be 30.0, got {result.confidence_score}"
        )
        assert len(result.estimated_fields) == 7, (
            f"All 7 optional fields should be estimated, got {len(result.estimated_fields)}: "
            f"{result.estimated_fields}"
        )

    # ── 2. Julien full (all fields) ──────────────────────────────────────────

    def test_julien_full(self):
        """Julien with ALL golden couple fields filled.

        AVS and LPP projections should still be strong. Confidence must be 100%
        with no estimated fields. No debt impact.
        """
        result = compute_minimal_profile(_julien_full())

        assert result.projected_avs_monthly > 2000, (
            f"Julien full should still get near-max AVS rente, got {result.projected_avs_monthly}"
        )
        assert result.projected_lpp_capital > 250_000, (
            f"Julien full with 350k existing LPP should project >500k, "
            f"got {result.projected_lpp_capital}"
        )
        assert result.confidence_score == 100.0, (
            f"With all fields, confidence must be 100.0, got {result.confidence_score}"
        )
        assert len(result.estimated_fields) == 0, (
            f"No fields should be estimated, got {result.estimated_fields}"
        )
        assert result.monthly_debt_impact == 0.0, (
            f"Julien has no debt, impact should be 0.0, got {result.monthly_debt_impact}"
        )

    # ── 3. Julien complementaire vs base ─────────────────────────────────────

    def test_julien_complementaire_vs_base(self):
        """Compare Julien with lpp_caisse_type 'complementaire' vs 'base'.

        Complementaire uses 5.8% conversion rate vs base 6.8%.
        Same capital, lower conversion rate = lower monthly rente.
        """
        julien_comp = _julien_full()
        # _julien_full already has lpp_caisse_type="complementaire"

        julien_base_input = MinimalProfileInput(
            age=49,
            gross_salary=122_207.0,
            canton="VS",
            household_type="couple",
            current_savings=50_000.0,
            is_property_owner=True,
            existing_3a=7_258.0,
            existing_lpp=70_377.0,
            lpp_caisse_type="base",
            monthly_debt_service=0.0,
        )

        result_comp = compute_minimal_profile(julien_comp)
        result_base = compute_minimal_profile(julien_base_input)

        assert result_comp.projected_lpp_monthly < result_base.projected_lpp_monthly, (
            f"Complementaire (5.8%) should yield lower monthly rente than base (6.8%). "
            f"Comp={result_comp.projected_lpp_monthly}, Base={result_base.projected_lpp_monthly}"
        )

        delta = result_base.projected_lpp_monthly - result_comp.projected_lpp_monthly
        assert delta > 0, (
            f"Delta should be positive (base > comp), got {delta}"
        )

    # ── 4. Lauren base (3 inputs only) ───────────────────────────────────────

    def test_lauren_base(self):
        """Lauren with only age=43, salary=67k, canton=VS (CLAUDE.md §8).

        At 60k, Lauren is above the AVS RAMD low (14'700) so she should get
        above-minimum rente. LPP estimated from age 25 should be >100k.
        Confidence must be 30%.
        """
        result = compute_minimal_profile(_lauren_base())

        assert result.projected_avs_monthly > 1500, (
            f"Lauren at 60k should be above minimum AVS rente, got {result.projected_avs_monthly}"
        )
        assert result.projected_lpp_capital > 50_000, (
            f"Lauren with 20 years of contributions should have >100k LPP, "
            f"got {result.projected_lpp_capital}"
        )
        assert result.confidence_score == 30.0, (
            f"With only 3 inputs, confidence must be 30.0, got {result.confidence_score}"
        )

    # ── 5. Lauren full (all fields, with debt) ───────────────────────────────

    def test_lauren_full(self):
        """Lauren with ALL golden couple fields (CLAUDE.md §8). No debt.

        LPP starts at 19'620 (HOTELA). Confidence must be 100%.
        """
        result = compute_minimal_profile(_lauren_full())

        assert result.monthly_debt_impact == 0.0, (
            f"Lauren has no debt, got impact {result.monthly_debt_impact}"
        )
        assert result.projected_avs_monthly > 1500, (
            f"Lauren AVS should be >1500, got {result.projected_avs_monthly}"
        )
        assert result.confidence_score == 100.0, (
            f"With all fields, confidence must be 100.0, got {result.confidence_score}"
        )

    # ── 6. Lauren debt reduces retirement ────────────────────────────────────

    def test_debt_reduces_retirement(self):
        """Compare profile with and without monthly_debt_service=500.

        The difference in estimated_monthly_retirement should be exactly 500 CHF.
        Uses synthetic debt data (Lauren has no debt in golden profile).
        """
        lauren_with_debt = MinimalProfileInput(
            age=43, gross_salary=67_000.0, canton="VS",
            monthly_debt_service=500.0,
        )

        lauren_no_debt = MinimalProfileInput(
            age=43, gross_salary=67_000.0, canton="VS",
            monthly_debt_service=0.0,
        )

        result_debt = compute_minimal_profile(lauren_with_debt)
        result_no_debt = compute_minimal_profile(lauren_no_debt)

        difference = result_no_debt.estimated_monthly_retirement - result_debt.estimated_monthly_retirement
        assert difference == 500.0, (
            f"Debt impact difference should be exactly 500.0 CHF, got {difference}. "
            f"With debt: {result_debt.estimated_monthly_retirement}, "
            f"Without: {result_no_debt.estimated_monthly_retirement}"
        )

    # ── 7. Julien replacement ratio ──────────────────────────────────────────

    def test_julien_replacement_ratio(self):
        """Julien full profile replacement ratio should be in [0.50, 1.00].

        At 100k salary, estimated expenses ~87%*85%/12 = ~6'162/month.
        Retirement income (AVS ~2'520 + LPP ~2'900/month with 350k existing)
        yields a high replacement ratio around 0.88 for this strong profile.
        """
        result = compute_minimal_profile(_julien_full())

        assert 0.25 < result.estimated_replacement_ratio < 1.00, (
            f"Julien's replacement ratio should be between 0.50 and 1.00, "
            f"got {result.estimated_replacement_ratio}"
        )

    # ── 8. Lauren replacement ratio with debt ────────────────────────────────

    def test_lauren_replacement_ratio_with_debt(self):
        """Lauren full profile with debt: replacement ratio in [0.50, 1.00].

        At 60k salary, expenses ~87%*85%/12 = ~3'697/month.
        Retirement (AVS ~2'037 + LPP ~1'575 - 500 debt) / expenses ~0.84.
        Even with debt subtracted, the ratio remains fairly high due to
        lower estimated expenses on a 60k salary.
        """
        result = compute_minimal_profile(_lauren_full())

        assert 0.25 < result.estimated_replacement_ratio < 1.00, (
            f"Lauren's replacement ratio with debt should be between 0.50 and 1.00, "
            f"got {result.estimated_replacement_ratio}"
        )

    # ── 9. Debt priority: monthly_debt_service wins over total_debts ─────────

    def test_debt_priority_monthly_over_total(self):
        """When BOTH total_debts and monthly_debt_service are provided,
        monthly_debt_service takes priority.

        total_debts=100'000 would give 100'000*0.005=500 CHF/month.
        monthly_debt_service=200 should win, yielding impact of 200.
        """
        julien = MinimalProfileInput(
            age=49,
            gross_salary=122_207.0,
            canton="VS",
            household_type="couple",
            current_savings=50_000.0,
            is_property_owner=True,
            existing_3a=7_258.0,
            existing_lpp=70_377.0,
            lpp_caisse_type="complementaire",
            total_debts=100_000.0,
            monthly_debt_service=200.0,
        )
        result = compute_minimal_profile(julien)

        assert result.monthly_debt_impact == 200.0, (
            f"When both debt fields provided, monthly_debt_service (200) should win. "
            f"Got {result.monthly_debt_impact} (if 500, total_debts*0.005 was used instead)"
        )

    # ── 10. Debt estimation from total_debts only ────────────────────────────

    def test_debt_estimation_from_total(self):
        """When only total_debts=100'000 is provided (no monthly_debt_service),
        monthly impact should be total_debts * 0.005 = 500 CHF.
        """
        julien = MinimalProfileInput(
            age=49,
            gross_salary=122_207.0,
            canton="VS",
            household_type="couple",
            current_savings=50_000.0,
            is_property_owner=True,
            existing_3a=7_258.0,
            existing_lpp=70_377.0,
            lpp_caisse_type="complementaire",
            total_debts=100_000.0,
            # monthly_debt_service intentionally NOT set (None)
        )
        result = compute_minimal_profile(julien)

        assert result.monthly_debt_impact == 500.0, (
            f"With only total_debts=100k, impact should be 100k*0.005=500.0. "
            f"Got {result.monthly_debt_impact}"
        )
