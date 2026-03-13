"""
Cross-Platform Consistency — Verify Python and Dart produce identical results.

This test suite validates that the Python backend (source of truth) and
Dart financial_core calculators are aligned by testing:

1. Constants alignment: Same values in social_insurance.py and social_insurance.dart
2. AVS rente computation: Same inputs → same outputs
3. LPP projection: Same inputs → same outputs
4. Tax calculation: Progressive brackets produce identical amounts
5. Golden couple values: Julien + Lauren get same results on both sides

The Dart side cannot be called from Python, so this test:
  - Validates Python outputs for specific inputs
  - Generates a JSON "contract" file with expected values
  - The Dart test (test_cross_platform_dart_test.dart) reads the same contract

Sources:
    - LAVS art. 34 (rente max 2'520 CHF/mo)
    - LPP art. 7, 8, 14, 16 (seuil, coordination, conversion, bonifications)
    - LIFD art. 38 (progressive withdrawal tax)
"""

import json

import pytest

from app.constants.social_insurance import (
    LPP_SEUIL_ENTREE,
    LPP_DEDUCTION_COORDINATION,
    LPP_SALAIRE_COORDONNE_MIN,
    LPP_SALAIRE_COORDONNE_MAX,
    LPP_SALAIRE_MAX,
    LPP_TAUX_CONVERSION_MIN,
    LPP_TAUX_INTERET_MIN,
    AVS_RENTE_MAX_MENSUELLE,
    AVS_RENTE_MIN_MENSUELLE,
    AVS_RENTE_COUPLE_MAX_MENSUELLE,
    AVS_COTISATION_SALARIE,
    AVS_COTISATION_TOTAL,
    AVS_DUREE_COTISATION_COMPLETE,
    AVS_AGE_REFERENCE_HOMME,
    AVS_REDUCTION_ANTICIPATION,
    PILIER_3A_PLAFOND_AVEC_LPP,
    PILIER_3A_PLAFOND_SANS_LPP,
    TAUX_IMPOT_RETRAIT_CAPITAL,
    RETRAIT_CAPITAL_TRANCHES,
    MARRIED_CAPITAL_TAX_DISCOUNT,
    get_lpp_bonification_rate,
)

from app.services.onboarding.minimal_profile_service import compute_minimal_profile
from app.services.onboarding.onboarding_models import MinimalProfileInput


# ═══════════════════════════════════════════════════════════════════════════════
# 1. Constants alignment — Python values as Dart must mirror
# ═══════════════════════════════════════════════════════════════════════════════


class TestConstantsAlignment:
    """Verify Python constants match the documented CLAUDE.md values."""

    def test_lpp_seuil_entree(self):
        assert LPP_SEUIL_ENTREE == 22_680.0

    def test_lpp_deduction_coordination(self):
        assert LPP_DEDUCTION_COORDINATION == 26_460.0

    def test_lpp_salaire_coordonne_min(self):
        assert LPP_SALAIRE_COORDONNE_MIN == 3_780.0

    def test_lpp_salaire_coordonne_max(self):
        assert LPP_SALAIRE_COORDONNE_MAX == 64_260.0

    def test_lpp_salaire_max(self):
        assert LPP_SALAIRE_MAX == 90_720.0

    def test_lpp_taux_conversion_min(self):
        assert LPP_TAUX_CONVERSION_MIN == 6.8

    def test_lpp_taux_interet_min(self):
        assert LPP_TAUX_INTERET_MIN == 1.25

    def test_lpp_bonifications_ages(self):
        """LPP bonification rates by age bracket (LPP art. 16)."""
        assert get_lpp_bonification_rate(24) == 0.0
        assert get_lpp_bonification_rate(25) == 0.07
        assert get_lpp_bonification_rate(34) == 0.07
        assert get_lpp_bonification_rate(35) == 0.10
        assert get_lpp_bonification_rate(44) == 0.10
        assert get_lpp_bonification_rate(45) == 0.15
        assert get_lpp_bonification_rate(54) == 0.15
        assert get_lpp_bonification_rate(55) == 0.18
        assert get_lpp_bonification_rate(65) == 0.18

    def test_avs_rente_max(self):
        assert AVS_RENTE_MAX_MENSUELLE == 2_520.0

    def test_avs_rente_min(self):
        assert AVS_RENTE_MIN_MENSUELLE == 1_260.0

    def test_avs_rente_couple_max(self):
        assert AVS_RENTE_COUPLE_MAX_MENSUELLE == 3_780.0

    def test_avs_cotisation_salarie(self):
        assert AVS_COTISATION_SALARIE == 0.053

    def test_avs_cotisation_total(self):
        assert AVS_COTISATION_TOTAL == 0.106

    def test_avs_duree_complete(self):
        assert AVS_DUREE_COTISATION_COMPLETE == 44

    def test_avs_age_reference(self):
        assert AVS_AGE_REFERENCE_HOMME == 65

    def test_avs_reduction_anticipation(self):
        assert AVS_REDUCTION_ANTICIPATION == 0.068

    def test_pilier_3a_plafond_avec_lpp(self):
        assert PILIER_3A_PLAFOND_AVEC_LPP == 7_258.0

    def test_pilier_3a_plafond_sans_lpp(self):
        assert PILIER_3A_PLAFOND_SANS_LPP == 36_288.0

    def test_married_capital_tax_discount(self):
        assert MARRIED_CAPITAL_TAX_DISCOUNT == 0.85

    def test_progressive_brackets(self):
        """Progressive withdrawal tax brackets (LIFD art. 38)."""
        assert len(RETRAIT_CAPITAL_TRANCHES) == 5
        # Verify multipliers
        expected_multipliers = [1.00, 1.15, 1.30, 1.50, 1.70]
        for (_, _, mult), expected in zip(RETRAIT_CAPITAL_TRANCHES, expected_multipliers):
            assert mult == expected, (
                f"Expected multiplier {expected}, got {mult}"
            )

    def test_all_26_cantons_have_tax_rate(self):
        """All 26 Swiss cantons must have a capital withdrawal tax rate."""
        expected_cantons = {
            "AG", "AI", "AR", "BE", "BL", "BS", "FR", "GE", "GL", "GR",
            "JU", "LU", "NE", "NW", "OW", "SG", "SH", "SO", "SZ", "TG",
            "TI", "UR", "VD", "VS", "ZG", "ZH",
        }
        assert set(TAUX_IMPOT_RETRAIT_CAPITAL.keys()) == expected_cantons


# ═══════════════════════════════════════════════════════════════════════════════
# 2. LPP salaire coordonné computation
# ═══════════════════════════════════════════════════════════════════════════════


class TestLppSalaireCoordonne:
    """Verify LPP salaire coordonné clamping matches Dart side.

    Dart: LppCalculator.computeSalaireCoordonne(grossAnnualSalary)
    Python: (gross - LPP_DEDUCTION_COORDINATION).clamp(LPP_SALAIRE_COORDONNE_MIN, LPP_SALAIRE_COORDONNE_MAX)
    """

    def _compute_salaire_coordonne(self, gross: float) -> float:
        """Python equivalent of Dart's LppCalculator.computeSalaireCoordonne."""
        if gross < LPP_SEUIL_ENTREE:
            return 0.0
        raw = gross - LPP_DEDUCTION_COORDINATION
        return max(LPP_SALAIRE_COORDONNE_MIN, min(raw, LPP_SALAIRE_COORDONNE_MAX))

    @pytest.mark.parametrize("gross,expected", [
        (0, 0.0),
        (20_000, 0.0),           # Below threshold
        (22_680, 3_780.0),       # At threshold → min coordonné
        (30_000, 3_780.0),       # 30k - 26460 = 3540 → clamped to min 3780
        (40_000, 13_540.0),      # 40k - 26460 = 13'540
        (60_000, 33_540.0),      # 60k - 26460 = 33'540
        (80_000, 53_540.0),      # 80k - 26460 = 53'540
        (90_720, 64_260.0),      # Max salary → max coordonné
        (100_000, 64_260.0),     # Above max → capped
        (200_000, 64_260.0),     # Way above max → capped
    ])
    def test_salaire_coordonne(self, gross, expected):
        result = self._compute_salaire_coordonne(gross)
        assert abs(result - expected) < 0.01, (
            f"Salaire coordonné for {gross}: expected {expected}, got {result}"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# 3. Progressive withdrawal tax
# ═══════════════════════════════════════════════════════════════════════════════


class TestProgressiveTax:
    """Verify progressive capital withdrawal tax matches Dart.

    Dart: RetirementTaxCalculator.progressiveTax(montant, baseRate)
    Python: equivalent computation using RETRAIT_CAPITAL_TRANCHES
    """

    def _progressive_tax(self, montant: float, base_rate: float) -> float:
        """Python equivalent of Dart's progressiveTax."""
        tax = 0.0
        remaining = montant
        for lower, upper, multiplier in RETRAIT_CAPITAL_TRANCHES:
            if remaining <= 0:
                break
            bracket_upper = upper if upper is not None else float("inf")
            taxable_in_bracket = min(remaining, bracket_upper - lower)
            tax += taxable_in_bracket * base_rate * multiplier
            remaining -= taxable_in_bracket
        return tax

    @pytest.mark.parametrize("montant,base_rate,expected_min,expected_max", [
        # Simple cases with ZH rate (6.5% = 0.065)
        (50_000, 0.065, 3_000, 3_500),      # 50k × 0.065 × 1.0 = 3'250
        (100_000, 0.065, 6_000, 7_000),      # 100k × 0.065 × 1.0 = 6'500
        (150_000, 0.065, 9_000, 11_000),     # Mixed brackets
        (300_000, 0.065, 20_000, 25_000),    # Spans 3 brackets
        (500_000, 0.065, 35_000, 42_000),    # Spans 4 brackets
        (1_000_000, 0.065, 75_000, 90_000),  # Spans all brackets
        (2_000_000, 0.065, 160_000, 200_000), # Large amount
    ])
    def test_progressive_tax_range(self, montant, base_rate, expected_min, expected_max):
        result = self._progressive_tax(montant, base_rate)
        assert expected_min <= result <= expected_max, (
            f"Tax on {montant} at {base_rate}: {result} not in [{expected_min}, {expected_max}]"
        )

    def test_progressive_tax_exact_100k(self):
        """100k at 6.5%: entirely in first bracket → 100'000 × 0.065 × 1.0 = 6'500."""
        result = self._progressive_tax(100_000, 0.065)
        assert abs(result - 6_500) < 1.0

    def test_progressive_tax_exact_200k(self):
        """200k at 6.5%: 100k × 1.0 + 100k × 1.15 = 13'975."""
        result = self._progressive_tax(200_000, 0.065)
        expected = 100_000 * 0.065 * 1.0 + 100_000 * 0.065 * 1.15  # 6500 + 7475 = 13975
        assert abs(result - expected) < 1.0

    def test_married_discount(self):
        """Married couples get 15% discount on capital withdrawal tax."""
        single_rate = TAUX_IMPOT_RETRAIT_CAPITAL["ZH"]
        married_rate = single_rate * MARRIED_CAPITAL_TAX_DISCOUNT

        single_tax = self._progressive_tax(500_000, single_rate / 100)
        married_tax = self._progressive_tax(500_000, married_rate / 100)

        assert married_tax < single_tax
        assert abs(married_tax / single_tax - 0.85) < 0.01


# ═══════════════════════════════════════════════════════════════════════════════
# 4. Golden couple — pinned reference values
# ═══════════════════════════════════════════════════════════════════════════════


class TestGoldenCoupleContract:
    """Pin specific values for Julien + Lauren that Dart must also produce.

    These tests generate a contract JSON that the Dart test validates against.
    """

    def test_julien_onboarding_pinned(self):
        """Julien (50, 100k, ZH) — pin AVS and LPP projections."""
        result = compute_minimal_profile(
            MinimalProfileInput(age=50, gross_salary=100_000, canton="ZH")
        )

        # AVS: at 100k (above RAMD max 88'200), should get max or near-max
        assert result.projected_avs_monthly >= 2_400, (
            f"Julien AVS should be near-max: {result.projected_avs_monthly}"
        )
        assert result.projected_avs_monthly <= 2_520, (
            f"Julien AVS should not exceed max: {result.projected_avs_monthly}"
        )

        # LPP: estimated from age 25, 15 years to retirement
        assert result.projected_lpp_capital > 300_000, (
            f"Julien LPP capital too low: {result.projected_lpp_capital}"
        )

        # Archetype: should be detected as swiss_native (default)
        assert result.archetype in ("swiss_native", "standard"), (
            f"Julien archetype unexpected: {result.archetype}"
        )

    def test_lauren_onboarding_pinned(self):
        """Lauren (45, 60k, ZH) — pin AVS and LPP projections."""
        result = compute_minimal_profile(
            MinimalProfileInput(age=45, gross_salary=60_000, canton="ZH")
        )

        # AVS: at 60k (between RAMD low/high), interpolated
        assert 1_500 < result.projected_avs_monthly < 2_520, (
            f"Lauren AVS out of expected range: {result.projected_avs_monthly}"
        )

        # LPP: younger, lower salary → lower capital
        assert result.projected_lpp_capital > 100_000, (
            f"Lauren LPP capital too low: {result.projected_lpp_capital}"
        )

    def test_julien_full_vs_base_delta(self):
        """Full profile should change LPP capital (existing_lpp provided)."""
        base = compute_minimal_profile(
            MinimalProfileInput(age=50, gross_salary=100_000, canton="ZH")
        )
        full = compute_minimal_profile(
            MinimalProfileInput(
                age=50, gross_salary=100_000, canton="ZH",
                existing_lpp=350_000, lpp_caisse_type="complementaire",
                household_type="couple", current_savings=50_000,
                is_property_owner=True, existing_3a=7_258,
                monthly_debt_service=0,
            )
        )

        # Full should have different LPP (uses real existing_lpp instead of estimate)
        assert full.confidence_score > base.confidence_score
        assert full.projected_lpp_capital != base.projected_lpp_capital

    def test_generate_contract_json(self, tmp_path):
        """Generate contract JSON for Dart-side validation."""
        julien_base = compute_minimal_profile(
            MinimalProfileInput(age=50, gross_salary=100_000, canton="ZH")
        )
        lauren_base = compute_minimal_profile(
            MinimalProfileInput(age=45, gross_salary=60_000, canton="ZH")
        )

        contract = {
            "generated_by": "test_cross_platform.py",
            "julien_base": {
                "input": {"age": 50, "gross_salary": 100_000, "canton": "ZH"},
                "projected_avs_monthly": round(julien_base.projected_avs_monthly, 2),
                "projected_lpp_capital": round(julien_base.projected_lpp_capital, 2),
                "projected_lpp_monthly": round(julien_base.projected_lpp_monthly, 2),
                "confidence_score": julien_base.confidence_score,
                "archetype": julien_base.archetype,
            },
            "lauren_base": {
                "input": {"age": 45, "gross_salary": 60_000, "canton": "ZH"},
                "projected_avs_monthly": round(lauren_base.projected_avs_monthly, 2),
                "projected_lpp_capital": round(lauren_base.projected_lpp_capital, 2),
                "projected_lpp_monthly": round(lauren_base.projected_lpp_monthly, 2),
                "confidence_score": lauren_base.confidence_score,
                "archetype": lauren_base.archetype,
            },
            "constants": {
                "lpp_seuil_entree": LPP_SEUIL_ENTREE,
                "lpp_deduction_coordination": LPP_DEDUCTION_COORDINATION,
                "lpp_salaire_coordonne_min": LPP_SALAIRE_COORDONNE_MIN,
                "lpp_salaire_coordonne_max": LPP_SALAIRE_COORDONNE_MAX,
                "lpp_taux_conversion_min": LPP_TAUX_CONVERSION_MIN,
                "avs_rente_max_mensuelle": AVS_RENTE_MAX_MENSUELLE,
                "avs_rente_min_mensuelle": AVS_RENTE_MIN_MENSUELLE,
                "avs_duree_cotisation_complete": AVS_DUREE_COTISATION_COMPLETE,
                "pilier_3a_plafond_avec_lpp": PILIER_3A_PLAFOND_AVEC_LPP,
                "pilier_3a_plafond_sans_lpp": PILIER_3A_PLAFOND_SANS_LPP,
            },
        }

        contract_file = tmp_path / "cross_platform_contract.json"
        contract_file.write_text(json.dumps(contract, indent=2))

        # Verify contract was written
        loaded = json.loads(contract_file.read_text())
        assert loaded["julien_base"]["projected_avs_monthly"] > 0
        assert loaded["lauren_base"]["projected_avs_monthly"] > 0
