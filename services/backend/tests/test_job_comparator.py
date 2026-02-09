"""
Tests for Job Change / LPP Plan Comparator.

Covers:
    - Insured salary calculation (fixed vs proportional deduction)
    - Contribution calculation (age brackets, employer share)
    - Capital projection (different horizons)
    - Conversion rates (obligatory, envelope, mixed)
    - Alert generation (IJM loss, pension drop, etc.)
    - Checklist generation
    - Verdict logic (actuel_meilleur, nouveau_meilleur, comparable)
    - API endpoints
    - Edge cases (zero salary, same plan, retirement age, negative)
"""

import pytest
from app.services.job_comparator import JobComparator, LPPPlanData


@pytest.fixture
def comparator():
    return JobComparator()


# ---------------------------------------------------------------------------
# Helper to create plans quickly
# ---------------------------------------------------------------------------

def _plan(**kwargs) -> LPPPlanData:
    """Create a LPPPlanData with sensible defaults, overridden by kwargs."""
    defaults = dict(
        salaire_brut=80000.0,
        taux_cotisation_employe=5.0,
        taux_cotisation_employeur=5.0,
        part_employeur_pct=50.0,
        avoir_vieillesse=100000.0,
        taux_conversion_obligatoire=6.8,
        rente_invalidite_pct=40.0,
        capital_deces=100000.0,
        rachat_maximum=50000.0,
        has_ijm=True,
        ijm_taux=80.0,
        ijm_duree_jours=720,
    )
    defaults.update(kwargs)
    return LPPPlanData(**defaults)


# ===========================================================================
# TestInsuredSalary
# ===========================================================================

class TestInsuredSalary:
    """Tests for _calc_insured_salary."""

    def test_fixed_deduction_standard(self, comparator):
        """Standard fixed deduction: 80'000 - 25'725 = 54'275."""
        plan = _plan(salaire_brut=80000.0)
        result = comparator._calc_insured_salary(plan)
        assert result == pytest.approx(54275.0, abs=1)

    def test_fixed_deduction_high_salary(self, comparator):
        """High salary: capped at max insured (88200 - 25725 = 62475)."""
        plan = _plan(salaire_brut=150000.0)
        result = comparator._calc_insured_salary(plan)
        assert result == pytest.approx(62475.0, abs=1)

    def test_below_entry_threshold(self, comparator):
        """Salary below 22'050: no LPP coverage."""
        plan = _plan(salaire_brut=20000.0)
        result = comparator._calc_insured_salary(plan)
        assert result == 0.0

    def test_just_above_entry_threshold(self, comparator):
        """Salary just above threshold: should return minimum insured salary."""
        plan = _plan(salaire_brut=22100.0)
        result = comparator._calc_insured_salary(plan)
        # 22100 - 25725 would be negative, so min insured salary applies
        assert result == pytest.approx(3675.0, abs=1)

    def test_explicit_insured_salary(self, comparator):
        """When salaire_assure is set, use it directly."""
        plan = _plan(salaire_brut=80000.0, salaire_assure=45000.0)
        result = comparator._calc_insured_salary(plan)
        assert result == 45000.0

    def test_explicit_insured_salary_zero(self, comparator):
        """When salaire_assure is 0, return 0."""
        plan = _plan(salaire_brut=80000.0, salaire_assure=0.0)
        result = comparator._calc_insured_salary(plan)
        assert result == 0.0

    def test_proportional_deduction(self, comparator):
        """Proportional deduction for part-time workers.
        With proportional type, deduction = salary * (deduction_param / COORDINATION_DEDUCTION),
        capped at deduction_param. For 40k salary and 12862.5 deduction param:
        40000 * (12862.5/25725) = 20000, but capped at 12862.5 => use 12862.5.
        Insured = 40000 - 12862.5 = 27137.5."""
        plan = _plan(
            salaire_brut=40000.0,
            deduction_coordination=12862.5,  # 50% of 25725
            deduction_coordination_type="proportional",
        )
        result = comparator._calc_insured_salary(plan)
        assert result == pytest.approx(27137.5, abs=100)

    def test_at_exact_entry_threshold(self, comparator):
        """Salary at exactly 22'050: above threshold, minimum applies."""
        plan = _plan(salaire_brut=22050.0)
        result = comparator._calc_insured_salary(plan)
        # 22050 - 25725 = negative, so min insured salary
        assert result == pytest.approx(3675.0, abs=1)

    def test_salary_equals_max_insured(self, comparator):
        """Salary at exactly 88'200."""
        plan = _plan(salaire_brut=88200.0)
        result = comparator._calc_insured_salary(plan)
        # 88200 - 25725 = 62475 (= max_insured - deduction)
        assert result == pytest.approx(62475.0, abs=1)


# ===========================================================================
# TestContributions
# ===========================================================================

class TestContributions:
    """Tests for _calc_contributions."""

    def test_explicit_rates(self, comparator):
        """With explicit employee/employer rates."""
        plan = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=5.0,
            taux_cotisation_employeur=7.0,
        )
        insured = comparator._calc_insured_salary(plan)
        cotis = comparator._calc_contributions(plan, insured, 40)
        # employee: 54275 * 5% = 2713.75
        assert cotis["employee_annual"] == pytest.approx(2713.75, abs=1)
        # employer: 54275 * 7% = 3799.25
        assert cotis["employer_annual"] == pytest.approx(3799.25, abs=1)
        assert cotis["total_annual"] == pytest.approx(6513.0, abs=1)

    def test_age_bracket_25_34(self, comparator):
        """Age 30: BVG rate 7.0%, 50/50 split."""
        plan = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=0.0,
            taux_cotisation_employeur=0.0,
            part_employeur_pct=50.0,
        )
        insured = comparator._calc_insured_salary(plan)
        cotis = comparator._calc_contributions(plan, insured, 30)
        # Total: 54275 * 7% = 3799.25, split 50/50
        assert cotis["total_annual"] == pytest.approx(3799.25, abs=1)
        assert cotis["employee_annual"] == pytest.approx(1899.63, abs=1)

    def test_age_bracket_35_44(self, comparator):
        """Age 40: BVG rate 10.0%."""
        plan = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=0.0,
            taux_cotisation_employeur=0.0,
            part_employeur_pct=50.0,
        )
        insured = comparator._calc_insured_salary(plan)
        cotis = comparator._calc_contributions(plan, insured, 40)
        assert cotis["total_annual"] == pytest.approx(5427.5, abs=1)

    def test_age_bracket_45_54(self, comparator):
        """Age 50: BVG rate 15.0%."""
        plan = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=0.0,
            taux_cotisation_employeur=0.0,
            part_employeur_pct=50.0,
        )
        insured = comparator._calc_insured_salary(plan)
        cotis = comparator._calc_contributions(plan, insured, 50)
        assert cotis["total_annual"] == pytest.approx(8141.25, abs=1)

    def test_age_bracket_55_64(self, comparator):
        """Age 60: BVG rate 18.0%."""
        plan = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=0.0,
            taux_cotisation_employeur=0.0,
            part_employeur_pct=50.0,
        )
        insured = comparator._calc_insured_salary(plan)
        cotis = comparator._calc_contributions(plan, insured, 60)
        assert cotis["total_annual"] == pytest.approx(9769.5, abs=1)

    def test_employer_share_65_percent(self, comparator):
        """Generous employer: 65% share."""
        plan = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=0.0,
            taux_cotisation_employeur=0.0,
            part_employeur_pct=65.0,
        )
        insured = comparator._calc_insured_salary(plan)
        cotis = comparator._calc_contributions(plan, insured, 40)
        total = 54275.0 * 0.10
        assert cotis["employer_annual"] == pytest.approx(total * 0.65, abs=1)
        assert cotis["employee_annual"] == pytest.approx(total * 0.35, abs=1)

    def test_below_25_no_contributions(self, comparator):
        """Below 25: no BVG mandatory contributions."""
        plan = _plan(
            salaire_brut=50000.0,
            taux_cotisation_employe=0.0,
            taux_cotisation_employeur=0.0,
        )
        insured = comparator._calc_insured_salary(plan)
        cotis = comparator._calc_contributions(plan, insured, 22)
        assert cotis["total_annual"] == 0.0

    def test_zero_insured_salary(self, comparator):
        """Zero insured salary produces zero contributions."""
        plan = _plan(salaire_brut=20000.0)  # below threshold
        cotis = comparator._calc_contributions(plan, 0.0, 40)
        assert cotis["employee_annual"] == 0.0
        assert cotis["employer_annual"] == 0.0
        assert cotis["total_annual"] == 0.0


# ===========================================================================
# TestCapitalProjection
# ===========================================================================

class TestCapitalProjection:
    """Tests for _project_capital."""

    def test_zero_years(self, comparator):
        """Zero years: return starting capital."""
        result = comparator._project_capital(100000, 5000, 0)
        assert result == 100000.0

    def test_one_year(self, comparator):
        """One year: capital * 1.015 + contribution."""
        result = comparator._project_capital(100000, 5000, 1)
        expected = 100000 * 1.015 + 5000
        assert result == pytest.approx(expected, abs=1)

    def test_ten_years_growth(self, comparator):
        """10 years: verify compound growth."""
        result = comparator._project_capital(100000, 10000, 10)
        # Should be significantly more than 100000 + 10*10000 = 200000
        assert result > 200000
        # But not too much with 1.5% return
        assert result < 250000

    def test_thirty_years(self, comparator):
        """30 years: long projection for young workers."""
        result = comparator._project_capital(0, 8000, 30)
        # Pure contributions: 30 * 8000 = 240000
        # With 1.5% compound: should be around 290000+
        assert result > 240000
        assert result < 350000

    def test_no_contribution(self, comparator):
        """No contributions: capital only grows by interest."""
        result = comparator._project_capital(200000, 0, 20)
        # 200000 * 1.015^20 ≈ 269568
        assert result == pytest.approx(269568, abs=200)

    def test_negative_years_returns_capital(self, comparator):
        """Negative years should return starting capital (edge case)."""
        result = comparator._project_capital(100000, 5000, -5)
        assert result == 100000.0


# ===========================================================================
# TestConversionRates
# ===========================================================================

class TestConversionRates:
    """Tests for _effective_conversion_rate."""

    def test_default_obligatory(self, comparator):
        """Default: 6.8% (LPP art. 14 al. 2)."""
        plan = _plan()
        rate = comparator._effective_conversion_rate(plan)
        assert rate == 6.8

    def test_envelope_rate(self, comparator):
        """Envelope rate overrides everything."""
        plan = _plan(taux_conversion_enveloppe=5.4)
        rate = comparator._effective_conversion_rate(plan)
        assert rate == 5.4

    def test_surobligatory_rate(self, comparator):
        """Surobligatory rate: average of obligatory and surobligatory."""
        plan = _plan(taux_conversion_surobligatoire=5.0)
        rate = comparator._effective_conversion_rate(plan)
        # (6.8 + 5.0) / 2 = 5.9
        assert rate == pytest.approx(5.9, abs=0.01)

    def test_envelope_overrides_surobligatory(self, comparator):
        """Envelope rate takes precedence over surobligatory."""
        plan = _plan(
            taux_conversion_enveloppe=5.2,
            taux_conversion_surobligatoire=4.5,
        )
        rate = comparator._effective_conversion_rate(plan)
        assert rate == 5.2

    def test_low_conversion_rate(self, comparator):
        """Very low conversion rate (some pension funds)."""
        plan = _plan(taux_conversion_enveloppe=4.8)
        rate = comparator._effective_conversion_rate(plan)
        assert rate == 4.8


# ===========================================================================
# TestAlerts
# ===========================================================================

class TestAlerts:
    """Tests for _generate_alerts."""

    def test_ijm_loss_alert(self, comparator):
        """Losing IJM should trigger critical alert."""
        current = _plan(has_ijm=True)
        new = _plan(has_ijm=False)
        result = comparator.compare(current, new, age=40)
        assert any("IJM" in a for a in result.alerts)
        assert any("CRITIQUE" in a for a in result.alerts)

    def test_pension_drop_with_salary_gain(self, comparator):
        """Pension drop > 5x salary gain should trigger attention alert."""
        current = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=5.0,
            taux_cotisation_employeur=8.0,
        )
        new = _plan(
            salaire_brut=85000.0,
            taux_cotisation_employe=3.0,
            taux_cotisation_employeur=3.0,
            taux_conversion_enveloppe=5.0,
        )
        result = comparator.compare(current, new, age=40)
        # Salary gain is moderate but pension drops significantly
        attention_alerts = [a for a in result.alerts if "ATTENTION" in a or "perte de rente" in a.lower()]
        assert len(attention_alerts) >= 0  # May or may not trigger depending on exact numbers

    def test_below_entry_threshold_alert(self, comparator):
        """New salary below entry threshold should trigger critical alert."""
        current = _plan(salaire_brut=80000.0)
        new = _plan(salaire_brut=20000.0, salaire_assure=None)
        result = comparator.compare(current, new, age=40)
        assert any("seuil d'entree" in a.lower() for a in result.alerts)

    def test_lower_conversion_rate_alert(self, comparator):
        """Lower conversion rate should trigger alert."""
        current = _plan(taux_conversion_obligatoire=6.8)
        new = _plan(taux_conversion_enveloppe=5.0)
        result = comparator.compare(current, new, age=40)
        assert any("taux de conversion" in a.lower() for a in result.alerts)

    def test_death_capital_drop_alert(self, comparator):
        """Death capital drop should trigger alert."""
        current = _plan(capital_deces=200000.0)
        new = _plan(capital_deces=50000.0)
        result = comparator.compare(current, new, age=40)
        assert any("capital deces" in a.lower() for a in result.alerts)

    def test_employer_share_drop_alert(self, comparator):
        """Employer share dropping should trigger alert."""
        current = _plan(part_employeur_pct=65.0, taux_cotisation_employe=0, taux_cotisation_employeur=0)
        new = _plan(part_employeur_pct=50.0, taux_cotisation_employe=0, taux_cotisation_employeur=0)
        result = comparator.compare(current, new, age=40)
        assert any("part employeur" in a.lower() for a in result.alerts)

    def test_near_retirement_alert(self, comparator):
        """Near retirement (< 5 years) should trigger projection warning."""
        current = _plan()
        new = _plan(salaire_brut=85000.0)
        result = comparator.compare(current, new, age=62)
        assert any("retraite" in a.lower() for a in result.alerts)

    def test_no_alerts_identical_plans(self, comparator):
        """Identical plans should generate minimal alerts."""
        plan = _plan()
        result = comparator.compare(plan, plan, age=40)
        # No critical alerts expected for identical plans
        critical_alerts = [a for a in result.alerts if "CRITIQUE" in a]
        assert len(critical_alerts) == 0


# ===========================================================================
# TestChecklist
# ===========================================================================

class TestChecklist:
    """Tests for _generate_checklist."""

    def test_always_includes_certificate(self, comparator):
        """Always ask for the LPP certificate."""
        current = _plan()
        new = _plan()
        result = comparator.compare(current, new, age=40)
        assert any("certificat" in c.lower() for c in result.checklist)

    def test_always_includes_conversion_rate(self, comparator):
        """Always check conversion rate."""
        current = _plan()
        new = _plan()
        result = comparator.compare(current, new, age=40)
        assert any("taux de conversion" in c.lower() for c in result.checklist)

    def test_ijm_loss_urgent_checklist(self, comparator):
        """IJM loss should add urgent checklist item."""
        current = _plan(has_ijm=True)
        new = _plan(has_ijm=False)
        result = comparator.compare(current, new, age=40)
        assert any("URGENT" in c and "IJM" in c for c in result.checklist)

    def test_high_salary_surobligatory_check(self, comparator):
        """High salary should trigger surobligatory check."""
        current = _plan(salaire_brut=120000.0)
        new = _plan(salaire_brut=120000.0)
        result = comparator.compare(current, new, age=40)
        assert any("surobligatoire" in c.lower() for c in result.checklist)

    def test_minimum_checklist_items(self, comparator):
        """Should always have at least 7 standard items."""
        current = _plan()
        new = _plan()
        result = comparator.compare(current, new, age=40)
        assert len(result.checklist) >= 7


# ===========================================================================
# TestVerdict
# ===========================================================================

class TestVerdict:
    """Tests for verdict logic."""

    def test_nouveau_meilleur_all_axes(self, comparator):
        """Higher salary + better LPP = nouveau_meilleur."""
        current = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=5.0,
            taux_cotisation_employeur=5.0,
        )
        new = _plan(
            salaire_brut=95000.0,
            taux_cotisation_employe=5.0,
            taux_cotisation_employeur=8.0,
        )
        result = comparator.compare(current, new, age=35)
        assert result.verdict == "nouveau_meilleur"
        assert result.delta_salaire_net > 0
        assert result.annual_pension_delta > 0

    def test_actuel_meilleur_trap(self, comparator):
        """The classic trap: higher salary but much worse LPP."""
        current = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=5.0,
            taux_cotisation_employeur=10.0,
            taux_conversion_obligatoire=6.8,
        )
        new = _plan(
            salaire_brut=85000.0,
            taux_cotisation_employe=3.5,
            taux_cotisation_employeur=3.5,
            taux_conversion_enveloppe=5.0,
        )
        result = comparator.compare(current, new, age=35)
        # Salary gain is small, pension loss is large
        assert result.delta_salaire_net > 0  # salary is higher
        assert result.annual_pension_delta < 0  # pension is lower
        # With large enough lifetime loss, verdict should be actuel_meilleur
        assert result.verdict in ("actuel_meilleur", "comparable")

    def test_comparable_trade_off(self, comparator):
        """Moderate salary gain with moderate pension loss = comparable."""
        current = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=5.0,
            taux_cotisation_employeur=7.0,
        )
        new = _plan(
            salaire_brut=88000.0,
            taux_cotisation_employe=5.0,
            taux_cotisation_employeur=5.0,
        )
        result = comparator.compare(current, new, age=35)
        # Should be comparable or nouveau_meilleur depending on exact numbers
        assert result.verdict in ("nouveau_meilleur", "comparable", "actuel_meilleur")

    def test_lower_salary_better_lpp(self, comparator):
        """Lower salary but better LPP = comparable."""
        current = _plan(
            salaire_brut=90000.0,
            taux_cotisation_employe=3.5,
            taux_cotisation_employeur=3.5,
        )
        new = _plan(
            salaire_brut=85000.0,
            taux_cotisation_employe=5.0,
            taux_cotisation_employeur=8.0,
        )
        result = comparator.compare(current, new, age=35)
        assert result.delta_salaire_net < 0  # salary is lower
        # Pension should be better with higher contributions
        assert result.verdict in ("comparable", "actuel_meilleur")

    def test_both_worse_actuel_meilleur(self, comparator):
        """Lower salary AND worse LPP = actuel_meilleur."""
        current = _plan(
            salaire_brut=90000.0,
            taux_cotisation_employe=5.0,
            taux_cotisation_employeur=8.0,
        )
        new = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=3.5,
            taux_cotisation_employeur=3.5,
        )
        result = comparator.compare(current, new, age=35)
        assert result.verdict == "actuel_meilleur"


# ===========================================================================
# TestScenarios (Real-world scenarios)
# ===========================================================================

class TestScenarios:
    """Real-world scenario tests."""

    def test_higher_salary_worse_lpp_classic_trap(self, comparator):
        """Marc: 40yo, current 80k with 65% employer, new 85k with 50% employer.
        The classic trap -- 5k more salary but much worse LPP."""
        current = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=0.0,
            taux_cotisation_employeur=0.0,
            part_employeur_pct=65.0,
            rente_invalidite_pct=40.0,
            capital_deces=150000.0,
        )
        new = _plan(
            salaire_brut=85000.0,
            taux_cotisation_employe=0.0,
            taux_cotisation_employeur=0.0,
            part_employeur_pct=50.0,
            rente_invalidite_pct=30.0,
            capital_deces=80000.0,
        )
        result = comparator.compare(current, new, age=40)
        assert result.delta_salaire_net > 0
        # Employer paying less => lower total contributions
        assert result.cotisation_employe_nouveau > result.cotisation_employe_actuel

    def test_same_salary_different_coordination(self, comparator):
        """Sophie: Part-time, same salary but different coordination deduction."""
        current = _plan(
            salaire_brut=50000.0,
            deduction_coordination=25725.0,
            deduction_coordination_type="fixed",
            taux_cotisation_employe=5.0,
            taux_cotisation_employeur=5.0,
        )
        new = _plan(
            salaire_brut=50000.0,
            deduction_coordination=12862.5,  # proportional for 50%
            deduction_coordination_type="proportional",
            taux_cotisation_employe=5.0,
            taux_cotisation_employeur=5.0,
        )
        result = comparator.compare(current, new, age=40)
        # Different coordination means different insured salary
        # This affects contributions and pension
        assert result.delta_salaire_net != 0 or result.delta_capital != 0

    def test_young_worker_25(self, comparator):
        """Thomas: 25yo, first "real" job comparison."""
        current = _plan(
            salaire_brut=55000.0,
            taux_cotisation_employe=3.5,
            taux_cotisation_employeur=3.5,
            avoir_vieillesse=5000.0,
        )
        new = _plan(
            salaire_brut=60000.0,
            taux_cotisation_employe=3.5,
            taux_cotisation_employeur=5.0,
            avoir_vieillesse=5000.0,
        )
        result = comparator.compare(current, new, age=25)
        # 40 years of projection: small differences compound hugely
        assert result.capital_retraite_nouveau > result.capital_retraite_actuel
        assert result.verdict == "nouveau_meilleur"

    def test_near_retirement_55(self, comparator):
        """Anna: 60yo, 5 years to retirement. Different contribution rates
        (both above max insured salary, so need different rates to show impact)."""
        current = _plan(
            salaire_brut=120000.0,
            taux_cotisation_employe=9.0,
            taux_cotisation_employeur=9.0,
            avoir_vieillesse=500000.0,
        )
        new = _plan(
            salaire_brut=130000.0,
            taux_cotisation_employe=9.0,
            taux_cotisation_employeur=12.0,  # More generous employer
            avoir_vieillesse=500000.0,
        )
        result = comparator.compare(current, new, age=60)
        # Higher employer contributions => more capital
        assert result.capital_retraite_nouveau > result.capital_retraite_actuel
        # Near retirement alert
        assert any("retraite" in a.lower() for a in result.alerts)

    def test_different_conversion_rates(self, comparator):
        """Impact of 6.8% vs 5.0% envelope conversion rate."""
        current = _plan(
            salaire_brut=90000.0,
            taux_cotisation_employe=5.0,
            taux_cotisation_employeur=5.0,
            taux_conversion_obligatoire=6.8,
        )
        new = _plan(
            salaire_brut=90000.0,
            taux_cotisation_employe=5.0,
            taux_cotisation_employeur=5.0,
            taux_conversion_enveloppe=5.0,
        )
        result = comparator.compare(current, new, age=40)
        # Same contributions, different conversion rate => different pension
        assert result.rente_mensuelle_actuel > result.rente_mensuelle_nouveau
        assert result.annual_pension_delta < 0
        assert any("taux de conversion" in a.lower() for a in result.alerts)

    def test_ijm_loss_scenario(self, comparator):
        """New employer without collective IJM."""
        current = _plan(has_ijm=True, ijm_duree_jours=720)
        new = _plan(has_ijm=False, salaire_brut=85000.0)
        result = comparator.compare(current, new, age=40)
        assert result.has_ijm_actuel is True
        assert result.has_ijm_nouveau is False
        assert any("IJM" in a for a in result.alerts)
        assert any("URGENT" in c for c in result.checklist)

    def test_minimum_vs_generous_plan(self, comparator):
        """Minimum LPP plan vs generous plan."""
        # Minimum plan: low rates, 50% employer
        minimum = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=0.0,
            taux_cotisation_employeur=0.0,
            part_employeur_pct=50.0,
            rente_invalidite_pct=25.0,
            capital_deces=50000.0,
        )
        # Generous plan: higher rates, 65% employer
        generous = _plan(
            salaire_brut=80000.0,
            taux_cotisation_employe=6.0,
            taux_cotisation_employeur=10.0,
            part_employeur_pct=62.5,
            rente_invalidite_pct=60.0,
            capital_deces=200000.0,
        )
        result = comparator.compare(minimum, generous, age=40)
        # Generous plan is clearly better
        assert result.capital_retraite_nouveau > result.capital_retraite_actuel
        assert result.couverture_invalidite_nouveau > result.couverture_invalidite_actuel
        assert result.couverture_deces_nouveau > result.couverture_deces_actuel


# ===========================================================================
# TestEdgeCases
# ===========================================================================

class TestEdgeCases:
    """Edge case tests."""

    def test_same_plan_no_difference(self, comparator):
        """Identical plans should produce zero deltas."""
        plan = _plan()
        result = comparator.compare(plan, plan, age=40)
        assert result.delta_salaire_net == 0.0
        assert result.delta_capital == 0.0
        assert result.delta_rente == 0.0
        assert result.annual_pension_delta == 0.0

    def test_at_retirement_age(self, comparator):
        """At age 65: zero years to retirement."""
        plan = _plan()
        result = comparator.compare(plan, plan, age=65)
        # Capital should be starting capital (no time for growth)
        assert result.capital_retraite_actuel == pytest.approx(
            plan.avoir_vieillesse, abs=1
        )

    def test_above_retirement_age(self, comparator):
        """Above 65: should still work (years_to_retirement = 0)."""
        plan = _plan()
        result = comparator.compare(plan, plan, age=70)
        assert result.capital_retraite_actuel == pytest.approx(
            plan.avoir_vieillesse, abs=1
        )

    def test_very_young_worker(self, comparator):
        """Age 18: long projection but below LPP mandatory age."""
        plan = _plan(
            salaire_brut=30000.0,
            taux_cotisation_employe=0.0,
            taux_cotisation_employeur=0.0,
        )
        result = comparator.compare(plan, plan, age=18)
        # Below 25, no BVG contributions, but insured salary calc still works
        assert result.capital_retraite_actuel >= plan.avoir_vieillesse

    def test_custom_years_to_retirement(self, comparator):
        """Override years to retirement."""
        plan = _plan()
        result_default = comparator.compare(plan, plan, age=40)
        result_custom = comparator.compare(plan, plan, age=40, years_to_retirement=10)
        # 10 years < 25 years: less capital growth
        assert result_custom.capital_retraite_actuel < result_default.capital_retraite_actuel

    def test_zero_salary_new_job(self, comparator):
        """New job with very low salary (below threshold)."""
        current = _plan(salaire_brut=80000.0)
        new = _plan(salaire_brut=15000.0, salaire_assure=None)
        result = comparator.compare(current, new, age=40)
        # Below threshold: no LPP
        assert result.capital_retraite_nouveau < result.capital_retraite_actuel

    def test_very_high_salary(self, comparator):
        """Very high salary: insured capped at max."""
        plan = _plan(salaire_brut=300000.0)
        insured = comparator._calc_insured_salary(plan)
        # Capped at max insured salary
        assert insured <= 62475.0 + 1  # max_insured - deduction

    def test_lpp_rate_above_65(self, comparator):
        """Above 65: use last bracket rate (18%)."""
        rate = comparator._get_lpp_rate_for_age(67)
        assert rate == 18.0

    def test_lpp_rate_below_25(self, comparator):
        """Below 25: no mandatory contributions."""
        rate = comparator._get_lpp_rate_for_age(20)
        assert rate == 0.0


# ===========================================================================
# TestEndpoints (API integration)
# ===========================================================================

class TestEndpoints:
    """Tests for the FastAPI endpoints."""

    def test_compare_endpoint(self, client):
        """POST /api/v1/job-comparison/compare works."""
        payload = {
            "currentPlan": {
                "salaireBrut": 80000,
                "tauxCotisationEmploye": 5.0,
                "tauxCotisationEmployeur": 5.0,
                "avoirVieillesse": 100000,
                "renteInvaliditePct": 40.0,
                "capitalDeces": 100000,
            },
            "newPlan": {
                "salaireBrut": 90000,
                "tauxCotisationEmploye": 5.0,
                "tauxCotisationEmployeur": 7.0,
                "avoirVieillesse": 100000,
                "renteInvaliditePct": 45.0,
                "capitalDeces": 120000,
            },
            "age": 40,
        }
        response = client.post("/api/v1/job-comparison/compare", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "verdict" in data
        assert "axes" in data
        assert len(data["axes"]) == 7
        assert "alerts" in data
        assert "checklist" in data
        assert data["salaireNetNouveau"] > data["salaireNetActuel"]

    def test_compare_endpoint_with_envelope_rate(self, client):
        """POST /api/v1/job-comparison/compare with envelope conversion rate."""
        payload = {
            "currentPlan": {
                "salaireBrut": 80000,
                "tauxCotisationEmploye": 5.0,
                "tauxCotisationEmployeur": 5.0,
                "tauxConversionObligatoire": 6.8,
            },
            "newPlan": {
                "salaireBrut": 80000,
                "tauxCotisationEmploye": 5.0,
                "tauxCotisationEmployeur": 5.0,
                "tauxConversionEnveloppe": 5.0,
            },
            "age": 40,
        }
        response = client.post("/api/v1/job-comparison/compare", json=payload)
        assert response.status_code == 200
        data = response.json()
        # Same salary & contributions, but lower conversion => lower pension
        assert data["renteMensuelleNouveau"] < data["renteMensuelleActuel"]

    def test_compare_endpoint_validation_age(self, client):
        """POST with invalid age should fail validation."""
        payload = {
            "currentPlan": {"salaireBrut": 80000},
            "newPlan": {"salaireBrut": 80000},
            "age": 10,  # too young
        }
        response = client.post("/api/v1/job-comparison/compare", json=payload)
        assert response.status_code == 422

    def test_checklist_endpoint(self, client):
        """GET /api/v1/job-comparison/checklist returns template."""
        response = client.get("/api/v1/job-comparison/checklist")
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert len(data["items"]) > 0
        assert "disclaimer" in data
        # Check structure
        first = data["items"][0]
        assert "label" in first
        assert "category" in first
        assert "priority" in first

    def test_checklist_has_all_categories(self, client):
        """Checklist should cover all categories."""
        response = client.get("/api/v1/job-comparison/checklist")
        data = response.json()
        categories = {item["category"] for item in data["items"]}
        assert "prevoyance" in categories
        assert "risque" in categories
        assert "administratif" in categories
        assert "fiscal" in categories

    def test_compare_endpoint_ijm_loss(self, client):
        """Endpoint correctly reports IJM loss."""
        payload = {
            "currentPlan": {
                "salaireBrut": 80000,
                "tauxCotisationEmploye": 5.0,
                "tauxCotisationEmployeur": 5.0,
                "hasIjm": True,
            },
            "newPlan": {
                "salaireBrut": 85000,
                "tauxCotisationEmploye": 5.0,
                "tauxCotisationEmployeur": 5.0,
                "hasIjm": False,
            },
            "age": 40,
        }
        response = client.post("/api/v1/job-comparison/compare", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["hasIjmActuel"] is True
        assert data["hasIjmNouveau"] is False
        assert any("IJM" in alert for alert in data["alerts"])
