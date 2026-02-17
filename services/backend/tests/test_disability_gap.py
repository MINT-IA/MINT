"""
Tests for DisabilityGapService — Simulation du gap financier en cas d'invalidite.

24 tests across 6 groups:
    - TestEmployerCoverage (5): coverage weeks by scale and years of service
    - TestAiRente (5): rente by disability degree (0%, 45%, 55%, 65%, 70%, 100%)
    - TestPhaseCalculation (5): phase 1/2/3 for different employment statuses
    - TestRiskLevel (4): critical, high, medium, low
    - TestCompliance (3): disclaimer, sources, chiffre_choc, no banned terms
    - TestEdgeCases (3): very high income, zero income, student status

Sources:
    - CO art. 324a (employer salary continuation)
    - LAI art. 28 (AI disability rente)
    - LPP art. 23-26 (LPP disability benefits)
"""

import pytest

from app.services.disability_gap_service import (
    compute_disability_gap,
    get_employer_coverage_weeks,
    get_ai_rente_mensuelle,
    EmploymentStatus,
    SUPPORTED_CANTONS,
)
from app.constants.social_insurance import (
    AI_RENTE_ENTIERE,
    AI_RENTE_DEMI,
)


# Banned terms that must NEVER appear in user-facing text
BANNED_TERMS = [
    "garanti", "certain", "assuré", "sans risque",
    "optimal", "meilleur", "parfait",
]


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def employee_vd_result():
    """Employee in VD, 5 years seniority, with IJM, 70% disability."""
    return compute_disability_gap(
        revenu_mensuel_net=7000.0,
        statut_professionnel=EmploymentStatus.EMPLOYEE,
        canton="VD",
        annees_anciennete=5,
        has_ijm_collective=True,
        degre_invalidite=70,
        lpp_disability_benefit=1500.0,
    )


@pytest.fixture
def self_employed_no_ijm_result():
    """Self-employed in GE, no IJM, 60% disability."""
    return compute_disability_gap(
        revenu_mensuel_net=8000.0,
        statut_professionnel=EmploymentStatus.SELF_EMPLOYED,
        canton="GE",
        annees_anciennete=0,
        has_ijm_collective=False,
        degre_invalidite=60,
        lpp_disability_benefit=0.0,
    )


# ===========================================================================
# TestEmployerCoverage — 5 tests
# ===========================================================================

class TestEmployerCoverage:
    """Test employer coverage duration by cantonal scale and seniority."""

    def test_bernoise_year1(self):
        """Echelle bernoise: 1st year = 3 weeks (CO art. 324a)."""
        assert get_employer_coverage_weeks("VD", 1) == 3

    def test_bernoise_year2(self):
        """Echelle bernoise: 2nd year = 4 weeks."""
        assert get_employer_coverage_weeks("BE", 2) == 4

    def test_bernoise_year10(self):
        """Echelle bernoise: 10+ years = 17 weeks."""
        assert get_employer_coverage_weeks("GE", 10) == 17

    def test_zurichoise_year2(self):
        """Echelle zurichoise: 2nd year = 8 weeks (more generous early)."""
        assert get_employer_coverage_weeks("ZH", 2) == 8

    def test_baloise_year6(self):
        """Echelle baloise: 6+ years = 13 weeks."""
        assert get_employer_coverage_weeks("BS", 6) == 13

    def test_bernoise_year20_plus(self):
        """Echelle bernoise: 20+ years = 26 weeks (max)."""
        assert get_employer_coverage_weeks("LU", 25) == 26

    def test_unsupported_canton_raises(self):
        """Unsupported canton should raise ValueError."""
        with pytest.raises(ValueError, match="Canton non supporte"):
            get_employer_coverage_weeks("XX", 5)

    def test_zero_seniority_default(self):
        """0 years seniority should return default 3 weeks (bernoise)."""
        # Year 0 means less than 1 year completed; threshold 1 not met
        assert get_employer_coverage_weeks("VD", 0) == 3

    def test_all_26_cantons_supported(self):
        """All 26 Swiss cantons should be mapped to a scale."""
        assert len(SUPPORTED_CANTONS) == 26


# ===========================================================================
# TestAiRente — 5 tests
# ===========================================================================

class TestAiRente:
    """Test AI rente mensuelle by disability degree (LAI art. 28)."""

    def test_below_40_no_rente(self):
        """Degree < 40%: no AI rente."""
        assert get_ai_rente_mensuelle(39) == 0.0
        assert get_ai_rente_mensuelle(0) == 0.0

    def test_degree_45_quarter_rente(self):
        """Degree 40-49%: 1/4 rente = 630 CHF."""
        rente = get_ai_rente_mensuelle(45)
        assert rente == pytest.approx(AI_RENTE_ENTIERE * 0.25, rel=1e-2)
        assert rente == pytest.approx(630.0, rel=1e-2)

    def test_degree_55_half_rente(self):
        """Degree 50-59%: 1/2 rente = 1260 CHF."""
        rente = get_ai_rente_mensuelle(55)
        assert rente == pytest.approx(AI_RENTE_DEMI, rel=1e-2)
        assert rente == pytest.approx(1260.0, rel=1e-2)

    def test_degree_65_three_quarter_rente(self):
        """Degree 60-69%: 3/4 rente = 1890 CHF."""
        rente = get_ai_rente_mensuelle(65)
        assert rente == pytest.approx(AI_RENTE_ENTIERE * 0.75, rel=1e-2)
        assert rente == pytest.approx(1890.0, rel=1e-2)

    def test_degree_70_full_rente(self):
        """Degree >= 70%: full rente = 2520 CHF."""
        assert get_ai_rente_mensuelle(70) == pytest.approx(AI_RENTE_ENTIERE, rel=1e-2)
        assert get_ai_rente_mensuelle(100) == pytest.approx(AI_RENTE_ENTIERE, rel=1e-2)


# ===========================================================================
# TestPhaseCalculation — 5 tests
# ===========================================================================

class TestPhaseCalculation:
    """Test phase 1/2/3 calculations for different employment statuses."""

    def test_employee_phase1_full_salary(self, employee_vd_result):
        """Employee phase 1: 100% salary, duration from cantonal scale."""
        r = employee_vd_result
        assert r.phase1_monthly_benefit == 7000.0
        assert r.phase1_gap == 0.0
        # VD bernoise, 5 years -> 13 weeks
        assert r.phase1_duration_weeks == 13.0

    def test_employee_phase2_ijm_80pct(self, employee_vd_result):
        """Employee with IJM phase 2: 80% of salary for 24 months."""
        r = employee_vd_result
        assert r.phase2_monthly_benefit == pytest.approx(7000.0 * 0.80, rel=1e-2)
        assert r.phase2_duration_months == 24.0
        assert r.phase2_gap == pytest.approx(7000.0 * 0.20, rel=1e-2)

    def test_employee_phase3_ai_plus_lpp(self, employee_vd_result):
        """Employee phase 3: AI rente + LPP disability benefit."""
        r = employee_vd_result
        # 70% disability = full AI rente (2520) + LPP (1500) = 4020
        assert r.ai_rente_mensuelle == pytest.approx(2520.0, rel=1e-2)
        assert r.phase3_monthly_benefit == pytest.approx(2520.0 + 1500.0, rel=1e-2)
        assert r.phase3_gap == pytest.approx(7000.0 - 4020.0, rel=1e-2)

    def test_self_employed_phase1_no_coverage(self, self_employed_no_ijm_result):
        """Self-employed: no employer coverage in phase 1."""
        r = self_employed_no_ijm_result
        assert r.phase1_duration_weeks == 0.0
        assert r.phase1_monthly_benefit == 0.0
        assert r.phase1_gap == 8000.0

    def test_self_employed_no_ijm_phase2_zero(self, self_employed_no_ijm_result):
        """Self-employed without IJM: zero coverage in phase 2."""
        r = self_employed_no_ijm_result
        assert r.phase2_monthly_benefit == 0.0
        assert r.phase2_gap == 8000.0


# ===========================================================================
# TestRiskLevel — 4 tests
# ===========================================================================

class TestRiskLevel:
    """Test risk level determination."""

    def test_critical_self_employed_no_ijm(self):
        """Self-employed without IJM -> critical risk."""
        r = compute_disability_gap(
            revenu_mensuel_net=8000.0,
            statut_professionnel=EmploymentStatus.SELF_EMPLOYED,
            canton="GE",
            annees_anciennete=0,
            has_ijm_collective=False,
            degre_invalidite=70,
            lpp_disability_benefit=0.0,
        )
        assert r.risk_level == "critical"
        assert any("CRITIQUE" in a for a in r.alerts)

    def test_high_employee_no_ijm(self):
        """Employee without IJM -> high risk."""
        r = compute_disability_gap(
            revenu_mensuel_net=6000.0,
            statut_professionnel=EmploymentStatus.EMPLOYEE,
            canton="ZH",
            annees_anciennete=3,
            has_ijm_collective=False,
            degre_invalidite=70,
            lpp_disability_benefit=1000.0,
        )
        assert r.risk_level == "high"
        assert any("HAUT RISQUE" in a for a in r.alerts)

    def test_medium_large_phase3_gap(self):
        """Large phase 3 gap (> 3000 CHF) -> medium risk."""
        r = compute_disability_gap(
            revenu_mensuel_net=10000.0,
            statut_professionnel=EmploymentStatus.EMPLOYEE,
            canton="BE",
            annees_anciennete=10,
            has_ijm_collective=True,
            degre_invalidite=70,
            lpp_disability_benefit=1000.0,
        )
        # Phase 3: AI (2520) + LPP (1000) = 3520 -> gap = 6480 > 3000
        assert r.risk_level == "medium"
        assert any("Gap important" in a for a in r.alerts)

    def test_low_good_coverage(self):
        """Good overall coverage -> low risk."""
        r = compute_disability_gap(
            revenu_mensuel_net=4000.0,
            statut_professionnel=EmploymentStatus.EMPLOYEE,
            canton="VD",
            annees_anciennete=5,
            has_ijm_collective=True,
            degre_invalidite=70,
            lpp_disability_benefit=2000.0,
        )
        # Phase 3: AI (2520) + LPP (2000) = 4520 -> gap = -520 (no gap)
        assert r.risk_level == "low"


# ===========================================================================
# TestCompliance — 3 tests
# ===========================================================================

class TestCompliance:
    """Test compliance: disclaimer, sources, chiffre_choc, no banned terms."""

    def test_disclaimer_present(self, employee_vd_result):
        """Result must contain required disclaimer text."""
        r = employee_vd_result
        assert "Outil educatif" in r.disclaimer
        assert "ne constitue pas un conseil" in r.disclaimer
        assert "specialiste" in r.disclaimer

    def test_sources_present(self, employee_vd_result):
        """Result must contain required legal sources."""
        r = employee_vd_result
        sources_text = " ".join(r.sources)
        assert "CO art. 324a" in sources_text
        assert "LAI art. 28" in sources_text
        assert "LPP art. 23-26" in sources_text

    def test_no_banned_terms(self, employee_vd_result):
        """No banned terms in disclaimer, chiffre_choc, or alerts."""
        r = employee_vd_result
        all_text = (
            r.disclaimer + " "
            + r.chiffre_choc + " "
            + " ".join(r.alerts) + " "
            + " ".join(r.sources)
        ).lower()
        for term in BANNED_TERMS:
            assert term not in all_text, f"Banned term '{term}' found in output"

    def test_chiffre_choc_present(self, employee_vd_result):
        """Chiffre choc must be a non-empty string with a CHF amount."""
        r = employee_vd_result
        assert len(r.chiffre_choc) > 0
        assert "CHF" in r.chiffre_choc


# ===========================================================================
# TestEdgeCases — 3+ tests
# ===========================================================================

class TestEdgeCases:
    """Test edge cases: extreme incomes, student, max disability."""

    def test_very_high_income(self):
        """Very high income (30'000 CHF/month) — large gaps expected."""
        r = compute_disability_gap(
            revenu_mensuel_net=30000.0,
            statut_professionnel=EmploymentStatus.EMPLOYEE,
            canton="ZH",
            annees_anciennete=15,
            has_ijm_collective=True,
            degre_invalidite=100,
            lpp_disability_benefit=3000.0,
        )
        # Phase 3: AI (2520) + LPP (3000) = 5520 -> gap = 24480
        assert r.phase3_gap == pytest.approx(30000.0 - 5520.0, rel=1e-2)
        assert r.risk_level == "medium"  # gap > 3000

    def test_zero_income(self):
        """Zero income: all gaps should be zero."""
        r = compute_disability_gap(
            revenu_mensuel_net=0.0,
            statut_professionnel=EmploymentStatus.STUDENT,
            canton="BE",
            annees_anciennete=0,
            has_ijm_collective=False,
            degre_invalidite=50,
        )
        assert r.phase1_gap == 0.0
        assert r.phase2_gap == 0.0
        assert r.phase3_gap == pytest.approx(0.0 - 1260.0, rel=1e-2)
        assert r.revenu_actuel == 0.0

    def test_student_no_employer_coverage(self):
        """Student: no employer coverage, alerts generated."""
        r = compute_disability_gap(
            revenu_mensuel_net=1500.0,
            statut_professionnel=EmploymentStatus.STUDENT,
            canton="VD",
            annees_anciennete=0,
            has_ijm_collective=False,
            degre_invalidite=70,
        )
        assert r.phase1_duration_weeks == 0.0
        assert r.phase1_monthly_benefit == 0.0
        # Student is not employee or self-employed, so no specific risk override
        # but has IJM alert
        assert any("IJM" in a for a in r.alerts)

    def test_max_disability_degree(self):
        """100% disability should yield full AI rente."""
        r = compute_disability_gap(
            revenu_mensuel_net=5000.0,
            statut_professionnel=EmploymentStatus.EMPLOYEE,
            canton="AG",
            annees_anciennete=3,
            has_ijm_collective=True,
            degre_invalidite=100,
            lpp_disability_benefit=800.0,
        )
        assert r.ai_rente_mensuelle == pytest.approx(AI_RENTE_ENTIERE, rel=1e-2)

    def test_invalid_canton_raises(self):
        """Passing an invalid canton should raise ValueError."""
        with pytest.raises(ValueError, match="Canton non supporte"):
            compute_disability_gap(
                revenu_mensuel_net=5000.0,
                statut_professionnel=EmploymentStatus.EMPLOYEE,
                canton="XX",
                annees_anciennete=5,
                has_ijm_collective=True,
                degre_invalidite=70,
            )

    def test_self_employed_with_ijm(self):
        """Self-employed WITH IJM should have phase 2 coverage."""
        r = compute_disability_gap(
            revenu_mensuel_net=6000.0,
            statut_professionnel=EmploymentStatus.SELF_EMPLOYED,
            canton="GE",
            annees_anciennete=0,
            has_ijm_collective=True,
            degre_invalidite=70,
            lpp_disability_benefit=0.0,
        )
        assert r.phase2_monthly_benefit == pytest.approx(6000.0 * 0.80, rel=1e-2)
        # Self-employed with IJM is not critical
        assert r.risk_level != "critical"
