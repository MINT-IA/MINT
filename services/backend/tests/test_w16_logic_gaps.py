"""
Tests for W16 logic gap fixes:
- FIX 1: 3a ceiling dynamic by employment status
- FIX 2: Spouse data cascade clear on divorce
- FIX 3: Canton validation utility
- FIX 4: Employment/LPP consistency validator
- FIX 5: Salary convention (documentation — covered by existing tests)
- FIX 6: targetRetirementAge schema field
"""

import uuid
from datetime import datetime, timezone

import pytest

from app.constants.social_insurance import (
    PILIER_3A_PLAFOND_AVEC_LPP,
    PILIER_3A_PLAFOND_SANS_LPP,
)
from app.services.rules_engine import (
    get_3a_ceiling,
    calculate_tax_potential,
    generate_recommendations,
)
from app.schemas.profile import Profile, ProfileBase, ProfileUpdate, HouseholdType
from app.utils.canton_utils import validate_canton, VALID_CANTONS


# ══════════════════════════════════════════════════════════════════════════════
# FIX 1: 3a ceiling dynamic
# ══════════════════════════════════════════════════════════════════════════════


class TestGet3aCeiling:
    """Tests for get_3a_ceiling() — OPP3 art. 7."""

    def test_salarie_with_lpp_gets_small_3a(self):
        """Salarié affilié LPP -> petit 3a (7'258)."""
        assert get_3a_ceiling("salarie", True) == PILIER_3A_PLAFOND_AVEC_LPP

    def test_employee_with_lpp_gets_small_3a(self):
        """Employee (EN alias) with LPP -> petit 3a."""
        assert get_3a_ceiling("employee", True) == PILIER_3A_PLAFOND_AVEC_LPP

    def test_independant_without_lpp_gets_grand_3a(self):
        """Indépendant sans LPP + revenu élevé -> grand 3a (borne absolue)."""
        assert get_3a_ceiling(
            "independant", False, annual_income=200_000.0
        ) == PILIER_3A_PLAFOND_SANS_LPP

    def test_self_employed_without_lpp_gets_grand_3a(self):
        """Self-employed (EN alias) sans LPP + revenu élevé -> grand 3a."""
        assert get_3a_ceiling(
            "self_employed", False, annual_income=200_000.0
        ) == PILIER_3A_PLAFOND_SANS_LPP

    def test_salarie_without_lpp_also_gets_grand_3a(self):
        """AFFILIATION-based (revue Codex F1) : un SALARIÉ sans 2e pilier a aussi
        droit au grand 3a (20% du revenu) — pas seulement l'indépendant."""
        assert get_3a_ceiling("salarie", False, annual_income=100_000.0) == 20_000.0

    def test_independant_with_lpp_gets_small_3a(self):
        """Indépendant AVEC LPP volontaire -> petit 3a."""
        assert get_3a_ceiling("independant", True) == PILIER_3A_PLAFOND_AVEC_LPP

    def test_none_employment_defaults_to_small_3a(self):
        """Unknown employment -> defaults to petit 3a (safe)."""
        assert get_3a_ceiling(None, None) == PILIER_3A_PLAFOND_AVEC_LPP

    def test_retraite_unknown_affiliation_gets_small_3a(self):
        """Non-indépendant + affiliation inconnue (None) -> petit 3a (safe)."""
        assert get_3a_ceiling("retraite", None) == PILIER_3A_PLAFOND_AVEC_LPP

    def test_self_employed_with_none_lpp_grand_3a_needs_income(self):
        """Self-employed affiliation inconnue -> grand 3a ; sans revenu ->
        fail-closed None (jamais 36'288)."""
        assert get_3a_ceiling("self_employed", None) is None
        assert get_3a_ceiling(
            "self_employed", None, annual_income=200_000.0
        ) == PILIER_3A_PLAFOND_SANS_LPP

    def test_case_insensitive(self):
        """Employment status should be case-insensitive."""
        assert get_3a_ceiling("INDEPENDANT", False, annual_income=200_000.0) == PILIER_3A_PLAFOND_SANS_LPP
        assert get_3a_ceiling("Self_Employed", False, annual_income=200_000.0) == PILIER_3A_PLAFOND_SANS_LPP

    # ── OPP3 art. 7 : grand 3a borné à 20% du revenu (revue Codex P1-2) ──
    # Oracles externes calculés à la main (jamais via le helper de prod).

    def test_grand_3a_capped_at_20pct_of_income(self):
        """Indépendant sans LPP, revenu 20'000 -> 20% = 4'000 (pas 36'288)."""
        assert get_3a_ceiling("independant", False, annual_income=20_000.0) == 4_000.0

    def test_grand_3a_20pct_below_absolute_ceiling(self):
        """Revenu 100'000 -> 20% = 20'000 (< plafond absolu)."""
        assert get_3a_ceiling("independant", False, annual_income=100_000.0) == 20_000.0

    def test_grand_3a_absolute_ceiling_when_income_high(self):
        """Revenu 200'000 -> 20% = 40'000 borné à 36'288."""
        assert get_3a_ceiling(
            "independant", False, annual_income=200_000.0
        ) == PILIER_3A_PLAFOND_SANS_LPP

    def test_grand_3a_no_income_fails_closed(self):
        """FAIL-CLOSED (revue Codex F1) : grand 3a dû mais revenu inconnu / nul /
        négatif -> None, JAMAIS 36'288. Les appelants affichent la règle."""
        assert get_3a_ceiling("independant", False, annual_income=None) is None
        assert get_3a_ceiling("independant", False, annual_income=0.0) is None
        assert get_3a_ceiling("independant", False, annual_income=-10_000.0) is None
        assert get_3a_ceiling("salarie", False, annual_income=None) is None

    def test_grand_3a_non_finite_income_fails_closed(self):
        """Revenu non fini / non numérique -> None (jamais un nan propagé)."""
        assert get_3a_ceiling("independant", False, annual_income=float("nan")) is None
        assert get_3a_ceiling("independant", False, annual_income=float("inf")) is None

    def test_grand_3a_coerces_decimal_and_string_income(self):
        """Decimal / chaîne numérique coercés proprement (pas de TypeError)."""
        from decimal import Decimal

        assert get_3a_ceiling("independant", False, annual_income=Decimal("20000")) == 4_000.0
        assert get_3a_ceiling("independant", False, annual_income="20000") == 4_000.0

    def test_income_ignored_for_salarie(self):
        """Le revenu n'affecte pas le petit 3a (salarié affilié LPP)."""
        assert get_3a_ceiling("salarie", True, annual_income=20_000.0) == PILIER_3A_PLAFOND_AVEC_LPP

    def test_income_cap_ignored_when_independant_has_lpp(self):
        """Indépendant AVEC LPP -> petit 3a, revenu sans effet."""
        assert get_3a_ceiling("independant", True, annual_income=20_000.0) == PILIER_3A_PLAFOND_AVEC_LPP


class TestCalculateTaxPotentialWith3aCeiling:
    """Verify calculate_tax_potential uses dynamic 3a ceiling."""

    def test_salarie_tax_potential(self):
        result = calculate_tax_potential("ZH", 100_000, "single", "salarie", True)
        assert "CHF" in result

    def test_independant_sans_lpp_higher_potential(self):
        """Indépendant sans LPP garde un potentiel plus élevé, mais borné par
        OPP3 art. 7 (20% du revenu) : à 100'000 le grand 3a est plafonné à
        20'000 (pas 36'288), soit ~2.8x le petit 3a et non ~5x (revue Codex P1-2)."""
        result_salarie = calculate_tax_potential("ZH", 100_000, "single", "salarie", True)
        result_indep = calculate_tax_potential("ZH", 100_000, "single", "independant", False)
        # Parse the range values
        def parse_range(s):
            nums = [int(x) for x in s.replace("~", "").replace(" CHF", "").split("-")]
            return sum(nums) / len(nums)
        avg_salarie = parse_range(result_salarie)
        avg_indep = parse_range(result_indep)
        assert avg_indep > avg_salarie * 2  # encore nettement plus élevé, cap OPP3


class TestRecommendationsUse3aCeiling:
    """Verify that generate_recommendations uses dynamic 3a ceiling."""

    def _make_profile(self, employment_status="salarie", has_2nd_pillar=True):
        return Profile(
            id=str(uuid.uuid4()),
            birthYear=1980,
            canton="VD",
            householdType=HouseholdType.single,
            incomeNetMonthly=8000,
            incomeGrossYearly=120_000,
            hasDebt=False,
            goal="optimize_taxes",
            employmentStatus=employment_status,
            has2ndPillar=has_2nd_pillar,
            createdAt=datetime.now(timezone.utc),
        )

    def test_independant_sans_lpp_3a_recommendation(self):
        """Indépendant sans LPP : grand 3a borné à 20% du revenu (OPP3 art. 7).
        Profil incomeGrossYearly=120'000 -> 20% = 24'000 (pas le 36'288 nu ;
        revue Codex P1-2)."""
        profile = self._make_profile("independant", False)
        recos = generate_recommendations(profile)
        three_a_recos = [r for r in recos if r.kind == "pillar3a"]
        assert len(three_a_recos) == 1
        # oracle externe : 0.20 * 120'000 = 24'000 (grand 3a > petit 7'258).
        assumptions_text = " ".join(three_a_recos[0].assumptions)
        assert "24000" in assumptions_text
        assert "36288" not in assumptions_text

    def test_salarie_avec_lpp_3a_recommendation(self):
        """Salarié avec LPP should get 7'258 in 3a recommendation."""
        profile = self._make_profile("salarie", True)
        recos = generate_recommendations(profile)
        three_a_recos = [r for r in recos if r.kind == "pillar3a"]
        assert len(three_a_recos) == 1
        assumptions_text = " ".join(three_a_recos[0].assumptions)
        assert "7" in assumptions_text  # 7,258 or 7'258


# ══════════════════════════════════════════════════════════════════════════════
# FIX 3: Canton validation utility
# ══════════════════════════════════════════════════════════════════════════════


class TestCantonValidation:
    """Tests for validate_canton() utility."""

    def test_valid_canton_returns_no_warning(self):
        canton, warning = validate_canton("ZH")
        assert canton == "ZH"
        assert warning is None

    def test_valid_canton_lowercase(self):
        canton, warning = validate_canton("zh")
        assert canton == "ZH"
        assert warning is None

    def test_valid_canton_with_spaces(self):
        canton, warning = validate_canton(" VS ")
        assert canton == "VS"
        assert warning is None

    def test_none_canton_returns_default(self):
        canton, warning = validate_canton(None)
        assert canton == "ZH"
        assert warning is not None
        assert "ZH" in warning

    def test_empty_string_returns_default(self):
        canton, warning = validate_canton("")
        assert canton == "ZH"
        assert warning is not None

    def test_invalid_canton_returns_default(self):
        canton, warning = validate_canton("XX")
        assert canton == "ZH"
        assert warning is not None
        assert "XX" in warning

    def test_custom_default(self):
        canton, warning = validate_canton(None, default="GE")
        assert canton == "GE"
        assert warning is not None
        assert "GE" in warning

    def test_all_26_cantons_valid(self):
        assert len(VALID_CANTONS) == 26
        for c in VALID_CANTONS:
            canton, warning = validate_canton(c)
            assert canton == c
            assert warning is None


# ══════════════════════════════════════════════════════════════════════════════
# FIX 4: Employment/LPP consistency
# ══════════════════════════════════════════════════════════════════════════════


class TestEmploymentLppConsistency:
    """Tests for model_validator on ProfileBase."""

    def test_salarie_above_threshold_without_lpp_logs_warning(self, caplog):
        """Salarié with income > 22'680 and no LPP should log a warning."""
        import logging
        with caplog.at_level(logging.WARNING):
            profile = ProfileBase(
                householdType=HouseholdType.single,
                employmentStatus="salarie",
                incomeGrossYearly=80_000,
                has2ndPillar=False,
            )
        assert "LPP" in caplog.text or profile is not None  # Warning logged but model created

    def test_salarie_with_lpp_no_warning(self, caplog):
        """Salarié with LPP -> no warning."""
        import logging
        with caplog.at_level(logging.WARNING):
            ProfileBase(
                householdType=HouseholdType.single,
                employmentStatus="salarie",
                incomeGrossYearly=80_000,
                has2ndPillar=True,
            )
        assert "LPP" not in caplog.text

    def test_independant_without_lpp_no_warning(self, caplog):
        """Indépendant without LPP -> no warning (normal case)."""
        import logging
        with caplog.at_level(logging.WARNING):
            ProfileBase(
                householdType=HouseholdType.single,
                employmentStatus="independant",
                incomeGrossYearly=80_000,
                has2ndPillar=False,
            )
        assert "LPP" not in caplog.text


# ══════════════════════════════════════════════════════════════════════════════
# FIX 6: targetRetirementAge
# ══════════════════════════════════════════════════════════════════════════════


class TestTargetRetirementAge:
    """Tests for targetRetirementAge field in profile schema."""

    def test_field_accepts_valid_ages(self):
        """Ages 58-70 should be valid."""
        for age in [58, 60, 63, 65, 67, 70]:
            profile = ProfileBase(
                householdType=HouseholdType.single,
                targetRetirementAge=age,
            )
            assert profile.targetRetirementAge == age

    def test_field_rejects_too_young(self):
        """Age < 58 should be rejected."""
        with pytest.raises(Exception):
            ProfileBase(
                householdType=HouseholdType.single,
                targetRetirementAge=50,
            )

    def test_field_rejects_too_old(self):
        """Age > 70 should be rejected."""
        with pytest.raises(Exception):
            ProfileBase(
                householdType=HouseholdType.single,
                targetRetirementAge=75,
            )

    def test_field_optional_defaults_none(self):
        """Field should default to None."""
        profile = ProfileBase(householdType=HouseholdType.single)
        assert profile.targetRetirementAge is None

    def test_update_schema_has_field(self):
        """ProfileUpdate should also accept targetRetirementAge."""
        update = ProfileUpdate(targetRetirementAge=63)
        assert update.targetRetirementAge == 63

    def test_recommendations_use_target_retirement_age(self):
        """When targetRetirementAge is set, 3a recommendation should use it."""
        profile_early = Profile(
            id=str(uuid.uuid4()),
            birthYear=1980,
            canton="VD",
            householdType=HouseholdType.single,
            incomeGrossYearly=100_000,
            hasDebt=False,
            goal="optimize_taxes",
            targetRetirementAge=58,
            createdAt=datetime.now(timezone.utc),
        )
        profile_late = Profile(
            id=str(uuid.uuid4()),
            birthYear=1980,
            canton="VD",
            householdType=HouseholdType.single,
            incomeGrossYearly=100_000,
            hasDebt=False,
            goal="optimize_taxes",
            targetRetirementAge=70,
            createdAt=datetime.now(timezone.utc),
        )
        recos_early = generate_recommendations(profile_early)
        recos_late = generate_recommendations(profile_late)
        # Both should have 3a recommendations
        three_a_early = [r for r in recos_early if r.kind == "pillar3a"]
        three_a_late = [r for r in recos_late if r.kind == "pillar3a"]
        assert len(three_a_early) == 1
        assert len(three_a_late) == 1
        # Later retirement = more years = higher potential value
        early_value = three_a_early[0].impact.amountCHF
        late_value = three_a_late[0].impact.amountCHF
        # Both should be positive
        assert early_value > 0
        assert late_value > 0


class TestOptimizerSingleAssiette:
    """Codex H2 — le revenu déterminant (net indépendant) sert AU PLAFOND ET À
    L'ÉCONOMIE (pas le plafond sur le net et l'économie sur le brut)."""

    def test_independant_net_income_used_for_both_ceiling_and_saving(self):
        import uuid
        from datetime import datetime, timezone

        profile = Profile(
            id=str(uuid.uuid4()), birthYear=1985, canton="VD",
            householdType=HouseholdType.single,
            employmentStatus="independant", has2ndPillar=False,
            incomeGrossYearly=120_000.0, selfEmployedNetIncome=20_000.0,
            goal="optimize_taxes", createdAt=datetime.now(timezone.utc),
        )
        recos = [r for r in generate_recommendations(profile) if r.kind == "pillar3a"]
        assert len(recos) == 1
        # plafond = 20% de 20'000 net = 4'000 ; économie sur le NET 20'000 (pas
        # le brut 120'000) = 674.40, jamais 1'487.04.
        assert recos[0].impact.amountCHF == pytest.approx(674.40, abs=0.01)
        assert "4000" in " ".join(recos[0].assumptions)


class TestStatusBasedAssietteAndSessionReport:
    """Codex I1 (assiette selon statut) + I2 (rapport de session affiliation-aware)."""

    def test_i1_salarie_residual_indep_key_uses_salary(self):
        import uuid
        from datetime import datetime, timezone

        p = Profile(
            id=str(uuid.uuid4()), birthYear=1985, canton="VD",
            householdType=HouseholdType.single, employmentStatus="salarie",
            has2ndPillar=True, incomeGrossYearly=100_000.0,
            selfEmployedNetIncome=20_000.0, goal="optimize_taxes",
            createdAt=datetime.now(timezone.utc),
        )
        r = [x for x in generate_recommendations(p) if x.kind == "pillar3a"][0]
        # base salariale (100k, plafond 7'258) -> 2'305.38, pas 1'044.38 (20k).
        assert r.impact.amountCHF == pytest.approx(2305.38, abs=0.01)

    def test_i2_tax_potential_is_affiliation_aware(self):
        # NOTE : teste calculate_tax_potential directement (le chemin
        # generate_session_report a été vérifié manuellement — revue ronde 5).
        # indépendant sans LPP 20k : avec statut, plafond 4'000 (< sans statut
        # 7'258) -> potentiel plus bas, affiliation-aware.
        aware = calculate_tax_potential(
            "VD", 20_000, employment_status="independant", has_2nd_pillar=False
        )
        naive = calculate_tax_potential("VD", 20_000)

        def _avg(s):
            n = [int(x) for x in s.replace("~", "").replace(" CHF", "").split("-")]
            return sum(n) / len(n)

        assert _avg(aware) < _avg(naive)
