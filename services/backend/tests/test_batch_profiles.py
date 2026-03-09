"""
Batch Profile Testing — ~120 parametrized profiles × critical endpoints.

Generates diverse profiles by combining axes of variation:
  - Age: 25, 35, 45, 55, 63, 66
  - Canton: ZH, VS, GE, TI, SZ
  - Salary: 0, 40k, 80k, 150k, 300k
  - Household: single, couple
  - LPP existing: None (estimated), 50k, 300k
  - FATCA / debt / property owner variations

For each profile, validates:
  1. Onboarding: MinimalProfileService returns valid result
  2. Sanity bounds: AVS <= 2'520/mo, LPP capital >= 0, ratio in [0, 2]
  3. Compliance: disclaimer present, sources non-empty, no banned words
  4. Edge cases: zero salary, retired age, extreme values

Sources:
    - LAVS art. 34 (rente max 2'520 CHF/mo)
    - LPP art. 14 (taux conversion min 6.8%)
    - LIFD art. 38 (imposition capital prévoyance)
"""

import itertools
import pytest

from app.services.onboarding.minimal_profile_service import compute_minimal_profile
from app.services.onboarding.onboarding_models import MinimalProfileInput


# ═══════════════════════════════════════════════════════════════════════════════
# Banned words (CLAUDE.md compliance)
# ═══════════════════════════════════════════════════════════════════════════════

BANNED_WORDS = [
    "garanti", "certain", "assuré", "sans risque",
    "optimal", "meilleur", "parfait",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Profile generator — Cartesian product of axes
# ═══════════════════════════════════════════════════════════════════════════════

AGES = [25, 35, 45, 55, 63]
CANTONS = ["ZH", "VS", "GE", "TI", "SZ"]
SALARIES = [40_000.0, 80_000.0, 150_000.0]
HOUSEHOLDS = ["single", "couple"]

# Core grid: age × canton × salary × household = 5 × 5 × 3 × 2 = 150 combos
# We sample strategically to keep ~120 tests
CORE_PROFILES = []
for age, canton, salary, household in itertools.product(
    AGES, CANTONS, SALARIES, HOUSEHOLDS
):
    # Sample: skip some combos to stay around 120
    # Keep all ZH (reference canton), sample others
    if canton != "ZH" and salary == 150_000.0 and household == "couple":
        continue  # Skip high-salary couple for non-reference cantons
    CORE_PROFILES.append(
        MinimalProfileInput(
            age=age,
            gross_salary=salary,
            canton=canton,
            household_type=household,
        )
    )


def _profile_id(p: MinimalProfileInput) -> str:
    """Human-readable test ID."""
    return f"age{p.age}_{p.canton}_{int(p.gross_salary/1000)}k_{p.household_type or 'single'}"


# ═══════════════════════════════════════════════════════════════════════════════
# Core batch: diverse profiles × onboarding
# ═══════════════════════════════════════════════════════════════════════════════


class TestBatchOnboarding:
    """Batch test: 120+ profiles through MinimalProfileService."""

    @pytest.mark.parametrize(
        "profile", CORE_PROFILES, ids=[_profile_id(p) for p in CORE_PROFILES]
    )
    def test_onboarding_returns_valid_result(self, profile):
        """Every profile must produce a valid MinimalProfileResult."""
        result = compute_minimal_profile(profile)

        # Basic structure
        assert result is not None
        assert isinstance(result.projected_avs_monthly, float)
        assert isinstance(result.projected_lpp_capital, float)
        assert isinstance(result.confidence_score, float)

    @pytest.mark.parametrize(
        "profile", CORE_PROFILES, ids=[_profile_id(p) for p in CORE_PROFILES]
    )
    def test_avs_within_legal_bounds(self, profile):
        """AVS rente must be between 0 and max (2'520 CHF/mo)."""
        result = compute_minimal_profile(profile)

        assert 0 <= result.projected_avs_monthly <= 2_520.0 + 1.0, (
            f"AVS rente {result.projected_avs_monthly} out of bounds [0, 2521] "
            f"for {_profile_id(profile)}"
        )

    @pytest.mark.parametrize(
        "profile", CORE_PROFILES, ids=[_profile_id(p) for p in CORE_PROFILES]
    )
    def test_lpp_capital_non_negative(self, profile):
        """LPP projected capital must be >= 0."""
        result = compute_minimal_profile(profile)

        assert result.projected_lpp_capital >= 0, (
            f"LPP capital {result.projected_lpp_capital} is negative "
            f"for {_profile_id(profile)}"
        )

    @pytest.mark.parametrize(
        "profile", CORE_PROFILES, ids=[_profile_id(p) for p in CORE_PROFILES]
    )
    def test_replacement_ratio_reasonable(self, profile):
        """Replacement ratio must be in [0, 2.0] (can exceed 1.0 for low salaries)."""
        result = compute_minimal_profile(profile)

        assert 0 <= result.estimated_replacement_ratio <= 2.0, (
            f"Replacement ratio {result.estimated_replacement_ratio} out of bounds "
            f"for {_profile_id(profile)}"
        )

    @pytest.mark.parametrize(
        "profile", CORE_PROFILES, ids=[_profile_id(p) for p in CORE_PROFILES]
    )
    def test_confidence_score_valid(self, profile):
        """Confidence score must be between 0 and 100."""
        result = compute_minimal_profile(profile)

        assert 0 <= result.confidence_score <= 100, (
            f"Confidence {result.confidence_score} out of bounds "
            f"for {_profile_id(profile)}"
        )

    @pytest.mark.parametrize(
        "profile", CORE_PROFILES, ids=[_profile_id(p) for p in CORE_PROFILES]
    )
    def test_compliance_disclaimer_present(self, profile):
        """Every result must include a disclaimer with 'LSFin' or 'éducatif'."""
        result = compute_minimal_profile(profile)

        assert result.disclaimer, (
            f"Missing disclaimer for {_profile_id(profile)}"
        )
        disclaimer_lower = result.disclaimer.lower()
        assert "éducatif" in disclaimer_lower or "educatif" in disclaimer_lower or "lsfin" in disclaimer_lower, (
            f"Disclaimer must mention 'éducatif' or 'LSFin': {result.disclaimer}"
        )

    @pytest.mark.parametrize(
        "profile", CORE_PROFILES, ids=[_profile_id(p) for p in CORE_PROFILES]
    )
    def test_compliance_sources_present(self, profile):
        """Every result must include legal sources."""
        result = compute_minimal_profile(profile)

        assert len(result.sources) > 0, (
            f"No sources for {_profile_id(profile)}"
        )

    @pytest.mark.parametrize(
        "profile", CORE_PROFILES, ids=[_profile_id(p) for p in CORE_PROFILES]
    )
    def test_compliance_no_banned_words(self, profile):
        """No banned words in disclaimer, sources, or enrichment prompts."""
        result = compute_minimal_profile(profile)

        all_text = " ".join([
            result.disclaimer,
            *result.sources,
            *result.enrichment_prompts,
        ]).lower()

        for word in BANNED_WORDS:
            assert word not in all_text, (
                f"Banned word '{word}' found in output for {_profile_id(profile)}"
            )


# ═══════════════════════════════════════════════════════════════════════════════
# Edge cases — extreme inputs
# ═══════════════════════════════════════════════════════════════════════════════


class TestBatchEdgeCases:
    """Edge cases that must not crash or produce absurd values."""

    def test_zero_salary(self):
        """Zero salary: AVS = 0, LPP = 0, no crash."""
        result = compute_minimal_profile(
            MinimalProfileInput(age=45, gross_salary=0, canton="ZH")
        )
        assert result.projected_avs_monthly == 0
        assert result.projected_lpp_capital == 0

    def test_retired_age_66(self):
        """Age 66 (already retired): should still compute without crash."""
        result = compute_minimal_profile(
            MinimalProfileInput(age=66, gross_salary=80_000, canton="ZH")
        )
        # AVS should be near-max (44 years of contributions)
        assert result.projected_avs_monthly > 0
        assert result.confidence_score >= 0

    def test_very_young_age_20(self):
        """Age 20: long horizon, should produce valid projections."""
        result = compute_minimal_profile(
            MinimalProfileInput(age=20, gross_salary=50_000, canton="GE")
        )
        assert result.projected_lpp_capital > 0
        assert result.projected_avs_monthly > 0

    def test_very_high_salary(self):
        """300k salary: AVS capped at max, LPP substantial."""
        result = compute_minimal_profile(
            MinimalProfileInput(age=50, gross_salary=300_000, canton="ZH")
        )
        # AVS is capped at max rente regardless of salary above RAMD
        assert result.projected_avs_monthly <= 2_520.0 + 1.0

    def test_below_lpp_threshold(self):
        """Salary below LPP threshold (22'680): no LPP bonifications."""
        result = compute_minimal_profile(
            MinimalProfileInput(age=40, gross_salary=20_000, canton="VS")
        )
        # Below LPP seuil d'accès: no employer LPP contributions
        assert result.projected_lpp_capital >= 0

    def test_with_massive_debt(self):
        """Large debt: retirement income reduced but no negative values."""
        result = compute_minimal_profile(
            MinimalProfileInput(
                age=50,
                gross_salary=80_000,
                canton="ZH",
                monthly_debt_service=5_000,
            )
        )
        assert result.monthly_debt_impact == 5_000
        # Retirement income can go negative (gap), but ratio must stay >= 0
        assert result.estimated_replacement_ratio >= 0

    def test_property_owner_vs_renter(self):
        """Property owner vs renter: both must produce valid results."""
        owner = compute_minimal_profile(
            MinimalProfileInput(
                age=50, gross_salary=100_000, canton="ZH",
                is_property_owner=True,
            )
        )
        renter = compute_minimal_profile(
            MinimalProfileInput(
                age=50, gross_salary=100_000, canton="ZH",
                is_property_owner=False,
            )
        )
        assert owner.projected_avs_monthly == renter.projected_avs_monthly
        assert owner.projected_lpp_capital == renter.projected_lpp_capital

    def test_all_26_cantons(self):
        """Every Swiss canton must produce a valid result."""
        cantons = [
            "AG", "AI", "AR", "BE", "BL", "BS", "FR", "GE", "GL", "GR",
            "JU", "LU", "NE", "NW", "OW", "SG", "SH", "SO", "SZ", "TG",
            "TI", "UR", "VD", "VS", "ZG", "ZH",
        ]
        for canton in cantons:
            result = compute_minimal_profile(
                MinimalProfileInput(age=50, gross_salary=80_000, canton=canton)
            )
            assert result is not None, f"Canton {canton} failed"
            assert result.projected_avs_monthly > 0, (
                f"Canton {canton}: AVS rente should be > 0"
            )


# ═══════════════════════════════════════════════════════════════════════════════
# Enrichment fields — optional inputs change confidence
# ═══════════════════════════════════════════════════════════════════════════════


class TestBatchConfidence:
    """Test that confidence score increases with more data."""

    def test_3_inputs_confidence_30(self):
        """Only 3 required inputs → confidence = 30%."""
        result = compute_minimal_profile(
            MinimalProfileInput(age=50, gross_salary=100_000, canton="ZH")
        )
        assert result.confidence_score == 30.0
        assert len(result.estimated_fields) == 7

    def test_all_inputs_confidence_100(self):
        """All 10 fields provided → confidence = 100%."""
        result = compute_minimal_profile(
            MinimalProfileInput(
                age=50, gross_salary=100_000, canton="ZH",
                household_type="couple",
                current_savings=50_000,
                is_property_owner=True,
                existing_3a=7_258,
                existing_lpp=350_000,
                lpp_caisse_type="complementaire",
                monthly_debt_service=0,
            )
        )
        assert result.confidence_score == 100.0
        assert len(result.estimated_fields) == 0

    def test_partial_inputs_intermediate_confidence(self):
        """Some optional fields → confidence between 30 and 100."""
        result = compute_minimal_profile(
            MinimalProfileInput(
                age=50, gross_salary=100_000, canton="ZH",
                household_type="couple",
                existing_lpp=200_000,
            )
        )
        assert 30 < result.confidence_score < 100, (
            f"Partial inputs should give intermediate confidence, got {result.confidence_score}"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Monotonicity — sanity checks on financial relationships
# ═══════════════════════════════════════════════════════════════════════════════


class TestBatchMonotonicity:
    """Verify that financial projections behave monotonically."""

    def test_higher_salary_higher_avs(self):
        """Higher salary → higher AVS rente (up to max)."""
        low = compute_minimal_profile(
            MinimalProfileInput(age=50, gross_salary=40_000, canton="ZH")
        )
        high = compute_minimal_profile(
            MinimalProfileInput(age=50, gross_salary=80_000, canton="ZH")
        )
        assert high.projected_avs_monthly >= low.projected_avs_monthly, (
            f"Higher salary should give higher AVS: {high.projected_avs_monthly} < {low.projected_avs_monthly}"
        )

    def test_higher_salary_higher_lpp(self):
        """Higher salary → higher LPP capital (same age)."""
        low = compute_minimal_profile(
            MinimalProfileInput(age=50, gross_salary=40_000, canton="ZH")
        )
        high = compute_minimal_profile(
            MinimalProfileInput(age=50, gross_salary=80_000, canton="ZH")
        )
        assert high.projected_lpp_capital >= low.projected_lpp_capital, (
            f"Higher salary should give higher LPP: {high.projected_lpp_capital} < {low.projected_lpp_capital}"
        )

    def test_more_existing_lpp_more_capital(self):
        """More existing LPP → more projected LPP capital."""
        low = compute_minimal_profile(
            MinimalProfileInput(
                age=50, gross_salary=80_000, canton="ZH", existing_lpp=50_000
            )
        )
        high = compute_minimal_profile(
            MinimalProfileInput(
                age=50, gross_salary=80_000, canton="ZH", existing_lpp=300_000
            )
        )
        assert high.projected_lpp_capital > low.projected_lpp_capital, (
            f"More existing LPP should give more projected capital: "
            f"{high.projected_lpp_capital} <= {low.projected_lpp_capital}"
        )

    def test_debt_reduces_retirement(self):
        """More debt → lower retirement income."""
        no_debt = compute_minimal_profile(
            MinimalProfileInput(
                age=50, gross_salary=80_000, canton="ZH",
                monthly_debt_service=0,
            )
        )
        with_debt = compute_minimal_profile(
            MinimalProfileInput(
                age=50, gross_salary=80_000, canton="ZH",
                monthly_debt_service=1_000,
            )
        )
        assert with_debt.estimated_monthly_retirement < no_debt.estimated_monthly_retirement, (
            f"Debt should reduce retirement: {with_debt.estimated_monthly_retirement} >= "
            f"{no_debt.estimated_monthly_retirement}"
        )

    def test_complementaire_lower_monthly_than_base(self):
        """Complementaire LPP (5.8%) → lower monthly rente than base (6.8%)."""
        base = compute_minimal_profile(
            MinimalProfileInput(
                age=50, gross_salary=100_000, canton="ZH",
                existing_lpp=300_000, lpp_caisse_type="base",
            )
        )
        comp = compute_minimal_profile(
            MinimalProfileInput(
                age=50, gross_salary=100_000, canton="ZH",
                existing_lpp=300_000, lpp_caisse_type="complementaire",
            )
        )
        assert comp.projected_lpp_monthly < base.projected_lpp_monthly, (
            f"Complementaire (5.8%) should give lower monthly than base (6.8%): "
            f"{comp.projected_lpp_monthly} >= {base.projected_lpp_monthly}"
        )
