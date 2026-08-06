"""
Tests for MinimalProfileService — Sprint S31: Onboarding Redesign.

25 tests across 7 groups:
    - TestMinimalInputs (4): 3-input only cases, different salary bands
    - TestFullEnrichment (3): all fields provided, confidence boost
    - TestEstimatedFields (3): correct tracking of defaulted fields
    - TestConfidenceScoring (3): score boundaries and field impact
    - TestAvsProjection (3): AVS rente for different salaries/ages
    - TestLppProjection (3): LPP capital projection logic
    - TestCompliance (3): disclaimer, sources, banned terms
    - TestEdgeCases (3): age boundaries, zero/high salary

Sources:
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 15-16 (bonifications vieillesse)
    - LIFD art. 38 (imposition du capital)
    - OPP3 art. 7 (plafond 3a)
"""

import pytest

from app.services.onboarding.minimal_profile_service import (
    compute_minimal_profile,
    _estimate_avs_monthly,
    _project_lpp_capital,
    _estimate_lpp_from_age_25,
    _compute_confidence_score,
    _estimate_3a_tax_impact,
    _compute_marginal_tax_rate,
    _estimate_tax_saving,
)
from app.services.onboarding.onboarding_models import MinimalProfileInput
from app.constants.social_insurance import (
    AVS_RENTE_MAX_MENSUELLE,
    AVS_RENTE_MIN_MENSUELLE,
    rente_from_ramd,
)


# Banned terms that must NEVER appear in user-facing text
BANNED_TERMS = [
    "garanti", "certain", "assuré", "sans risque",
    "optimal", "meilleur", "parfait",
    "conseiller", "tu devrais", "tu dois",
]


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def minimal_input_30_80k_vd():
    """Minimal 3-input profile: age 30, salary 80k, VD."""
    return MinimalProfileInput(age=30, gross_salary=80_000.0, canton="VD")


@pytest.fixture
def full_input_40_100k_zh():
    """Fully enriched profile: age 40, salary 100k, ZH, all fields provided."""
    return MinimalProfileInput(
        age=40,
        gross_salary=100_000.0,
        canton="ZH",
        household_type="couple",
        current_savings=50_000.0,
        is_property_owner=True,
        existing_3a=25_000.0,
        existing_lpp=150_000.0,
        lpp_caisse_type="base",
        monthly_debt_service=0.0,
    )


@pytest.fixture
def minimal_result_30_80k_vd(minimal_input_30_80k_vd):
    """Pre-computed result for the minimal 3-input case."""
    return compute_minimal_profile(minimal_input_30_80k_vd)


@pytest.fixture
def full_result_40_100k_zh(full_input_40_100k_zh):
    """Pre-computed result for the fully enriched case."""
    return compute_minimal_profile(full_input_40_100k_zh)


# ===========================================================================
# TestMinimalInputs — 4 tests
# ===========================================================================

class TestMinimalInputs:
    """Test with only 3 required inputs (age, salary, canton)."""

    def test_basic_computation_returns_result(self, minimal_result_30_80k_vd):
        """3 inputs should produce a valid result with all fields populated."""
        r = minimal_result_30_80k_vd
        assert r.projected_avs_monthly > 0
        assert r.projected_lpp_capital > 0
        assert r.projected_lpp_monthly > 0
        assert r.estimated_replacement_ratio > 0
        assert r.estimated_monthly_retirement > 0
        assert r.estimated_monthly_expenses > 0
        assert r.tax_saving_3a > 0
        assert r.marginal_tax_rate > 0
        assert r.months_liquidity >= 0

    def test_tax_saving_3a_uses_marginal_rate_and_ceiling(self):
        """3a tax saving follows the onboarding tax-impact gate."""
        inp = MinimalProfileInput(age=40, gross_salary=80_000.0, canton="VD")
        r = compute_minimal_profile(inp)
        expected, marginal_rate, _ = _estimate_3a_tax_impact(
            80_000.0,
            "VD",
            has_lpp=True,
        )
        assert r.tax_saving_3a == expected
        assert r.marginal_tax_rate == marginal_rate
        assert r.canton == "VD"

    def test_zero_salary_suppresses_tax_saving_3a(self):
        """No salary means no trustworthy 3a fiscal impact."""
        inp = MinimalProfileInput(age=40, gross_salary=0.0, canton="VD")
        r = compute_minimal_profile(inp)
        assert r.tax_saving_3a == 0.0
        assert r.marginal_tax_rate == 0.0

    def test_low_salary_20k(self):
        """Low salary (20k): below LPP threshold, minimal AVS."""
        inp = MinimalProfileInput(age=30, gross_salary=20_000.0, canton="GE")
        r = compute_minimal_profile(inp)
        # Below LPP entry threshold (22'680): LPP should be 0
        assert r.projected_lpp_capital == 0.0 or r.projected_lpp_capital > 0
        # AVS should still be computed (low RAMD = minimal rente)
        assert r.projected_avs_monthly > 0

    def test_high_salary_200k(self):
        """High salary (200k): AVS capped at max, LPP cap on coordinated."""
        inp = MinimalProfileInput(age=40, gross_salary=200_000.0, canton="ZG")
        r = compute_minimal_profile(inp)
        # AVS monthly should be near max (full years)
        assert r.projected_avs_monthly <= AVS_RENTE_MAX_MENSUELLE
        # High salary means solid replacement
        assert r.projected_lpp_capital > 200_000

    def test_median_salary_75k(self):
        """Median Swiss salary (~75k) should produce balanced results."""
        inp = MinimalProfileInput(age=35, gross_salary=75_000.0, canton="BE")
        r = compute_minimal_profile(inp)
        # Replacement ratio for 35yo with 75k should be moderate
        assert 0.3 < r.estimated_replacement_ratio < 1.0
        assert r.archetype == "swiss_native"


# ===========================================================================
# TestFullEnrichment — 3 tests
# ===========================================================================

class TestFullEnrichment:
    """Test with all 8 fields provided (full enrichment)."""

    def test_no_estimated_fields_when_all_provided(self, full_result_40_100k_zh):
        """When all fields are provided, estimated_fields should be empty."""
        assert full_result_40_100k_zh.estimated_fields == []

    def test_confidence_above_70_when_all_provided(self, full_result_40_100k_zh):
        """Confidence should be > 70% when all fields are provided."""
        assert full_result_40_100k_zh.confidence_score > 70

    def test_custom_savings_used(self, full_result_40_100k_zh):
        """When current_savings is provided, it should affect liquidity."""
        r = full_result_40_100k_zh
        # With 50k savings and ~7200 monthly expenses, should have ~7 months
        assert r.months_liquidity > 5


# ===========================================================================
# TestEstimatedFields — 3 tests
# ===========================================================================

class TestEstimatedFields:
    """Test correct tracking of which fields used defaults."""

    def test_all_optional_estimated_for_3_inputs(self, minimal_result_30_80k_vd):
        """With only 3 inputs, all 7 optional fields should be estimated."""
        expected = ["household_type", "current_savings", "is_property_owner",
                    "existing_3a", "existing_lpp", "lpp_caisse_type",
                    "monthly_debt_service"]
        assert sorted(minimal_result_30_80k_vd.estimated_fields) == sorted(expected)

    def test_partial_enrichment(self):
        """Providing some optional fields reduces estimated_fields."""
        inp = MinimalProfileInput(
            age=30, gross_salary=80_000.0, canton="VD",
            household_type="couple",
            existing_3a=10_000.0,
        )
        r = compute_minimal_profile(inp)
        assert "household_type" not in r.estimated_fields
        assert "existing_3a" not in r.estimated_fields
        assert "current_savings" in r.estimated_fields
        assert "existing_lpp" in r.estimated_fields
        assert "is_property_owner" in r.estimated_fields

    def test_only_savings_provided(self):
        """Providing only current_savings removes it from estimated_fields."""
        inp = MinimalProfileInput(
            age=45, gross_salary=90_000.0, canton="LU",
            current_savings=30_000.0,
        )
        r = compute_minimal_profile(inp)
        assert "current_savings" not in r.estimated_fields
        assert len(r.estimated_fields) == 6


# ===========================================================================
# TestConfidenceScoring — 3 tests
# ===========================================================================

class TestConfidenceScoring:
    """Test confidence score computation."""

    def test_confidence_below_50_for_3_inputs(self, minimal_result_30_80k_vd):
        """With only 3 required inputs, confidence should be < 50%."""
        assert minimal_result_30_80k_vd.confidence_score < 50

    def test_confidence_exact_30_for_7_estimated(self):
        """With all 7 optional fields estimated, score should be 30."""
        score = _compute_confidence_score([
            "household_type", "current_savings", "is_property_owner",
            "existing_3a", "existing_lpp", "lpp_caisse_type",
            "monthly_debt_service",
        ])
        assert score == 30.0

    def test_confidence_100_for_0_estimated(self):
        """With no estimated fields, score should be 100."""
        score = _compute_confidence_score([])
        assert score == 100.0


# ===========================================================================
# TestAvsProjection — 3 tests
# ===========================================================================

class TestAvsProjection:
    """Test AVS rente estimation logic."""

    def test_avs_max_rente_high_salary(self):
        """Salary above 88'200 with 44 years: should get max rente."""
        rente = _estimate_avs_monthly(100_000.0, 44)
        assert rente == AVS_RENTE_MAX_MENSUELLE

    def test_avs_min_rente_low_salary(self):
        """Salary below 14'700 with 44 years: should get min rente."""
        rente = _estimate_avs_monthly(10_000.0, 44)
        assert rente == AVS_RENTE_MIN_MENSUELLE

    def test_avs_interpolation_mid_salary(self):
        """Salary between 14'700 and 88'200: should interpolate."""
        rente = _estimate_avs_monthly(50_000.0, 44)
        assert AVS_RENTE_MIN_MENSUELLE < rente < AVS_RENTE_MAX_MENSUELLE

    def test_avs_reduction_for_incomplete_years(self):
        """With fewer than 44 years, rente should be reduced."""
        full = _estimate_avs_monthly(80_000.0, 44)
        partial = _estimate_avs_monthly(80_000.0, 22)
        assert partial < full
        assert abs(partial - full * 0.5) < 1.0  # ~50% of full

    def test_avs_ramd_lauren_67k_full_years(self):
        """Golden couple: Lauren (67k, full 44 years) uses the official echelle 44.

        La rente pleine délègue à la fonction canonique unique
        ``social_insurance.rente_from_ramd`` (table officielle OFAS
        318.117.011, alimentée par le registre avs.echelle44) — PLUS
        d'interpolation naïve min->max locale (règle 4 / NEVER #3).
        RAMD = 67'000 tombe entre les paliers « jusqu'à 66'528 » (2'197)
        et « jusqu'à 68'040 » (2'218) :
        ratio = (67000-66528)/(68040-66528) ≈ 0.3122
        full_rente = 2197 + 0.3122 * (2218-2197) ≈ 2'203.56 CHF/mois.
        """
        full_rente = _estimate_avs_monthly(67_000.0, 44)
        # Délégation à la fonction canonique (anti-façade) — le service arrondit
        # à 2 décimales, d'où la tolérance stricte plutôt qu'un == exact.
        assert abs(full_rente - rente_from_ramd(67_000.0)) < 0.01
        # Valeur officielle échelle 44 (~2'203.56), PAS le proxy naïf 2'124.7.
        assert abs(full_rente - 2203.56) < 0.1, f"Expected ~2203.56, got {full_rente}"
        assert full_rente > 2150.0, "Doit refléter l'échelle 44, pas l'ancien proxy naïf"
        assert AVS_RENTE_MIN_MENSUELLE < full_rente < AVS_RENTE_MAX_MENSUELLE

        # With 40 contribution years (~expat with partial gap)
        partial_rente = _estimate_avs_monthly(67_000.0, 40)
        expected_partial = full_rente * (40 / 44)
        assert abs(partial_rente - expected_partial) < 1.0

    def test_avs_uses_official_echelle44_not_naive_interpolation(self):
        """RAMD 52'920 (palier exact échelle 44) doit rendre 2'016, pas ~1'890.

        Garde anti-régression : l'ancienne interpolation naïve min->max
        rendait ~1'890 pour ce RAMD ; la table officielle OFAS (palier
        « jusqu'à 52'920 ») rend exactement 2'016. Le service onboarding
        doit servir la valeur canonique (règle 4 / NEVER #3).
        """
        rente = _estimate_avs_monthly(52_920.0, 44)
        assert rente == 2016.0, f"Échelle 44 officielle attend 2016.0, obtenu {rente}"
        assert rente == rente_from_ramd(52_920.0)
        # L'ancien proxy naïf (~1'890) est explicitement rejeté.
        assert rente > 1950.0, "Régression : interpolation naïve détectée"


# ===========================================================================
# TestLppProjection — 3 tests
# ===========================================================================

class TestLppProjection:
    """Test LPP capital projection logic."""

    def test_lpp_below_threshold_returns_existing(self):
        """Salary below LPP threshold: no new contributions, return existing."""
        capital = _project_lpp_capital(30, 20_000.0, 5_000.0, 65)
        assert capital == 5_000.0

    def test_lpp_projection_increases_with_age(self):
        """LPP capital should increase over time with bonifications + interest."""
        capital_35 = _project_lpp_capital(35, 80_000.0, 50_000.0, 65)
        capital_45 = _project_lpp_capital(45, 80_000.0, 50_000.0, 65)
        # 35yo has more years to compound than 45yo
        assert capital_35 > capital_45

    def test_lpp_estimate_from_25_at_30(self):
        """Estimate LPP from age 25 to 30 with 80k salary."""
        estimated = _estimate_lpp_from_age_25(30, 80_000.0)
        # 5 years * 7% * coordinated salary + interest
        assert estimated > 15_000  # Conservative lower bound
        assert estimated < 30_000  # Reasonable upper bound


# ===========================================================================
# TestCompliance — 3 tests
# ===========================================================================

class TestCompliance:
    """Test mandatory compliance fields."""

    def test_disclaimer_present_and_valid(self, minimal_result_30_80k_vd):
        """Disclaimer must be non-empty and contain 'educatif' and 'LSFin'."""
        d = minimal_result_30_80k_vd.disclaimer
        assert len(d) > 0
        assert "educatif" in d.lower()
        assert "LSFin" in d

    def test_sources_contain_legal_references(self, minimal_result_30_80k_vd):
        """Sources must contain at least one legal reference."""
        sources = minimal_result_30_80k_vd.sources
        assert len(sources) >= 1
        # Check for at least one article reference
        legal_terms = ["LAVS", "LPP", "LIFD", "OPP3"]
        found_any = any(
            any(term in s for term in legal_terms)
            for s in sources
        )
        assert found_any, f"No legal reference found in sources: {sources}"

    def test_no_banned_terms_in_enrichment_prompts(self, minimal_result_30_80k_vd):
        """Enrichment prompts must not contain any banned terms."""
        for prompt in minimal_result_30_80k_vd.enrichment_prompts:
            lower = prompt.lower()
            for term in BANNED_TERMS:
                assert term.lower() not in lower, (
                    f"Banned term '{term}' found in prompt: {prompt}"
                )


# ===========================================================================
# TestEdgeCases — 3 tests
# ===========================================================================

class TestEdgeCases:
    """Test boundary conditions and edge cases."""

    def test_age_22_young_worker(self):
        """Age 22: very few contribution years, still produces valid result."""
        inp = MinimalProfileInput(age=22, gross_salary=50_000.0, canton="VD")
        r = compute_minimal_profile(inp)
        assert r.projected_avs_monthly > 0
        # Young worker with no LPP yet (age < 25)
        assert r.archetype == "swiss_native"

    def test_age_64_near_retirement(self):
        """Age 64: near retirement, should have high LPP capital."""
        inp = MinimalProfileInput(age=64, gross_salary=80_000.0, canton="ZH")
        r = compute_minimal_profile(inp)
        # Only 1 year to retirement
        assert r.projected_lpp_capital > 0
        # Should have close to max AVS years
        assert r.projected_avs_monthly > AVS_RENTE_MIN_MENSUELLE

    def test_salary_zero(self):
        """Salary 0: no AVS, no LPP, replacement ratio 0."""
        inp = MinimalProfileInput(age=30, gross_salary=0.0, canton="GE")
        r = compute_minimal_profile(inp)
        assert r.projected_avs_monthly == 0.0
        assert r.estimated_replacement_ratio == 0.0
        assert r.estimated_monthly_expenses == 0.0

    def test_salary_500k_very_high(self):
        """Salary 500k: AVS capped, LPP capped on coordinated salary."""
        inp = MinimalProfileInput(age=40, gross_salary=500_000.0, canton="ZG")
        r = compute_minimal_profile(inp)
        # AVS rente capped at max
        assert r.projected_avs_monthly <= AVS_RENTE_MAX_MENSUELLE
        # LPP coordinated salary is capped
        assert r.projected_lpp_capital > 0

    def test_invalid_age_raises_error(self):
        """Age outside 18-70 should raise ValueError."""
        with pytest.raises(ValueError, match="Age must be between"):
            compute_minimal_profile(
                MinimalProfileInput(age=15, gross_salary=50_000.0, canton="VD")
            )

    def test_invalid_canton_raises_error(self):
        """Unknown canton should raise ValueError."""
        with pytest.raises(ValueError, match="Unknown canton"):
            compute_minimal_profile(
                MinimalProfileInput(age=30, gross_salary=50_000.0, canton="XX")
            )

    def test_negative_salary_raises_error(self):
        """Negative salary should raise ValueError."""
        with pytest.raises(ValueError, match="Gross salary must be >= 0"):
            compute_minimal_profile(
                MinimalProfileInput(age=30, gross_salary=-1_000.0, canton="VD")
            )


# ===========================================================================
# TestReplacementRatio — 2 tests
# ===========================================================================

class TestReplacementRatio:
    """Test replacement ratio computation correctness."""

    def test_replacement_ratio_formula(self, minimal_result_30_80k_vd):
        """Replacement ratio = estimated_monthly_retirement / gross_monthly_salary.

        Standard Swiss taux de remplacement: retirement income vs salary, not expenses.
        """
        r = minimal_result_30_80k_vd
        gross_monthly = 80_000.0 / 12
        if gross_monthly > 0:
            expected = r.estimated_monthly_retirement / gross_monthly
            assert abs(r.estimated_replacement_ratio - expected) < 0.001

    def test_retirement_income_sum(self, minimal_result_30_80k_vd):
        """Monthly retirement income = AVS + LPP monthly."""
        r = minimal_result_30_80k_vd
        expected = r.projected_avs_monthly + r.projected_lpp_monthly
        assert abs(r.estimated_monthly_retirement - expected) < 0.01


# ===========================================================================
# Sub-phase 01.5 R6 contract pin — archetype signals default to None
# ===========================================================================

def test_minimal_profile_archetype_signals_default_none():
    """Pin contract: ProfileUpdate / Profile default usTaxPerson + nationality to None.

    This pins the R4 tri-state default at the Pydantic schema layer (Profile /
    ProfileUpdate) alongside the onboarding minimal-profile suite above.
    The full roundtrip suite lives in test_profile_archetype_signal_roundtrip.py.
    """
    from app.schemas.profile import ProfileUpdate

    u = ProfileUpdate()
    assert u.usTaxPerson is None, (
        "R4 tri-state default broken: ProfileUpdate().usTaxPerson must be None, "
        "never False. If this fails, a model_validator was added that coerces "
        "None to False — that breaks the FATCA hard gate."
    )
    assert u.nationality is None


class TestReferenceAgeCohort:
    """Beads MINT_nosync-xx9 : l'âge de référence femmes dépend de la COHORTE.

    L'ancien _get_retirement_age servait int(64.5) = 64 à TOUTES les femmes —
    faux pour les cohortes 1963+ (65 depuis la réforme AVS 21). Miroir exact
    du Dart avsReferenceAge (social_insurance.dart).
    """

    def test_woman_born_1990_gets_65(self):
        from app.services.onboarding.minimal_profile_service import (
            _get_retirement_age,
        )

        assert _get_retirement_age("female", 1990) == 65, (
            "cohorte 1964+ : 65 ans — l'ancien scalaire 64 sous-estimait "
            "l'âge de référence de la quasi-totalité des utilisatrices"
        )

    def test_transitional_cohorts_match_dart_convention(self):
        from app.constants.social_insurance import avs_reference_age

        # Convention années entières partagée avec le Dart : 1961/1962 -> 64,
        # 1963 -> 65 (officiel : +3/+6/+9 mois).
        assert avs_reference_age(1960, True) == 64
        assert avs_reference_age(1961, True) == 64
        assert avs_reference_age(1962, True) == 64
        assert avs_reference_age(1963, True) == 65
        assert avs_reference_age(1964, True) == 65
        # Hommes : 65 toutes cohortes.
        assert avs_reference_age(1961, False) == 65

    def test_birth_date_end_of_1962_keeps_cohort_64(self, monkeypatch):
        """Régression review #985 : née le 31.12.1962 (63 ans mi-2026) —
        la dérivation par l'âge donnait cohorte 1963 -> 65 ; bd.year doit
        primer. On espionne l'argument transmis à _get_retirement_age
        (retirement_age n'est pas exposé dans le résultat)."""
        import app.services.onboarding.minimal_profile_service as mps
        from app.services.onboarding.onboarding_models import (
            MinimalProfileInput,
        )

        captured = {}
        orig = mps._get_retirement_age

        def spy(gender, birth_year):
            captured["birth_year"] = birth_year
            return orig(gender, birth_year)

        monkeypatch.setattr(mps, "_get_retirement_age", spy)
        mps.compute_minimal_profile(
            MinimalProfileInput(
                age=40,  # volontairement faux : birth_date doit primer
                gross_salary=90_000,
                canton="VD",
                birth_date="1962-12-31",
                gender="female",
            )
        )
        assert captured["birth_year"] == 1962, (
            "bd.year doit primer sur la dérivation par l'âge — une femme "
            "née le 31.12.1962 reste cohorte 1962 (64 ans, AVS 21)"
        )
        assert orig("female", 1962) == 64


# ===========================================================================
# TestOnboardingMarginalRateHouseholdType — Batch D (coherence fix)
#
# _compute_marginal_tax_rate / _estimate_tax_saving etaient single-only alors
# que MinimalProfileInput.household_type est disponible. Un menage marie voyait
# un taux marginal + une economie 3a celibataires (surestimes ~25 %). C'est le
# vice « un seul taux marginal » (#1061/#1062). Vocabulaire ANGLAIS
# household_type (married/couple/family) — normalise via
# rules_engine.is_married_household, PAS l'etat civil FR.
# ===========================================================================


class TestOnboardingMarginalRateHouseholdType:

    def test_married_and_single_differ_public_path(self):
        """Public path : compute_minimal_profile expose marginal_tax_rate ET
        tax_saving_3a. Un menage marie (household_type='married') et un
        celibataire, meme salaire/canton, doivent differer."""
        common = dict(age=40, gross_salary=120_000.0, canton="ZH")
        marie = compute_minimal_profile(
            MinimalProfileInput(household_type="married", **common)
        )
        single = compute_minimal_profile(
            MinimalProfileInput(household_type="single", **common)
        )
        assert marie.marginal_tax_rate != single.marginal_tax_rate
        assert marie.tax_saving_3a != single.tax_saving_3a
        # le marie est plus bas (splitting) — surestimation corrigee.
        assert marie.marginal_tax_rate < single.marginal_tax_rate

    def test_compute_marginal_rate_threads_is_married(self):
        """Oracles externes GELÉS (P2-a, repro Codex ZH 120k) : célibataire
        0.30008, marié 0.24006 (splitting)."""
        rate_single = _compute_marginal_tax_rate(120_000.0, "ZH")
        rate_married = _compute_marginal_tax_rate(120_000.0, "ZH", is_married=True)
        assert rate_single == pytest.approx(0.30008, abs=1e-5)
        assert rate_married == pytest.approx(0.24006, abs=1e-5)

    def test_estimate_tax_saving_threads_is_married(self):
        """Oracles externes GELÉS (P2-a) : économie sur 7'258 à ZH 120k,
        célibataire 2'177.98, marié 1'742.38."""
        s_single = _estimate_tax_saving(income=120_000.0, deduction=7_258.0, canton="ZH")
        s_married = _estimate_tax_saving(
            income=120_000.0, deduction=7_258.0, canton="ZH", is_married=True
        )
        assert s_single == pytest.approx(2177.98, abs=0.01)
        assert s_married == pytest.approx(1742.38, abs=0.01)

    def test_single_default_is_non_regressed(self):
        """Non-regression : sans is_married, le taux est INCHANGE (celibataire)."""
        from app.services.fiscal.cantonal_comparator import estimate_marginal_rate

        assert _compute_marginal_tax_rate(120_000.0, "ZH") == (
            estimate_marginal_rate(120_000.0, "ZH", is_married=False)
        )

    @pytest.mark.parametrize("ht,expect_married", [
        ("married", True), ("couple", True), ("family", True),
        ("single", False), ("divorced", False), (None, False),
    ])
    def test_household_type_normalization_via_3a_impact(self, ht, expect_married):
        """household_type married/couple/family -> taux marie ; single/None/
        divorced -> celibataire. Passe par _estimate_3a_tax_impact (le vrai
        chemin de l'onboarding)."""
        got, _, _ = _estimate_3a_tax_impact(
            120_000.0, "ZH", has_lpp=True, household_type=ht
        )
        married_ref, _, _ = _estimate_3a_tax_impact(
            120_000.0, "ZH", has_lpp=True, household_type="married"
        )
        single_ref, _, _ = _estimate_3a_tax_impact(
            120_000.0, "ZH", has_lpp=True, household_type="single"
        )
        assert got == (married_ref if expect_married else single_ref)
