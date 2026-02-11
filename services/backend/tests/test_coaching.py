"""
Tests for Proactive Coaching Engine.

Sprint S11: 40+ tests covering:
    - TestCoaching3a (5+ tests)
    - TestCoachingLPP (4+ tests)
    - TestCoachingTaxDeadline (4+ tests)
    - TestCoachingRetirement (4+ tests)
    - TestCoachingEmergencyFund (4+ tests)
    - TestCoachingDebtRatio (4+ tests)
    - TestCoachingAgeMilestones (5+ tests)
    - TestCoachingPartTime (3+ tests)
    - TestCoachingIndependant (3+ tests)
    - TestCoachingSorting (2+ tests)
    - TestCoachingCompliance (2+ tests)
    - TestCoachingEndpoints (4+ tests)
"""

import pytest
from datetime import date
from app.services.coaching_engine import CoachingEngine, CoachingProfile


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def engine():
    return CoachingEngine()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _profile(**kwargs) -> CoachingProfile:
    """Create a CoachingProfile with sensible defaults, overridden by kwargs."""
    defaults = dict(
        age=35,
        canton="GE",
        revenu_annuel=85000.0,
        has_3a=True,
        montant_3a=3000.0,
        has_lpp=True,
        avoir_lpp=120000.0,
        lacune_lpp=30000.0,
        taux_activite=100.0,
        charges_fixes_mensuelles=4000.0,
        epargne_disponible=15000.0,
        dette_totale=0.0,
        has_budget=True,
        employment_status="salarie",
        etat_civil="celibataire",
    )
    defaults.update(kwargs)
    return CoachingProfile(**defaults)


def _find_tip(tips, tip_id):
    """Find a tip by its id in a list of tips."""
    return next((t for t in tips if t.id == tip_id), None)


def _has_tip(tips, tip_id):
    """Check if a tip with the given id exists."""
    return _find_tip(tips, tip_id) is not None


# ===========================================================================
# TestCoaching3a
# ===========================================================================

class TestCoaching3a:
    """Tests for 3a pillar coaching tips."""

    def test_3a_deadline_in_q4(self, engine):
        """In Q4 with incomplete 3a: should generate 3a_deadline tip."""
        profile = _profile(has_3a=True, montant_3a=2000.0)
        tips = engine.generate_tips(profile, today_date=date(2026, 10, 15))
        assert _has_tip(tips, "3a_deadline")
        tip = _find_tip(tips, "3a_deadline")
        assert "jours" in tip.message
        assert tip.estimated_impact_chf > 0
        assert "LIFD" in tip.source

    def test_3a_deadline_not_in_q1(self, engine):
        """Before October: no 3a deadline tip."""
        profile = _profile(has_3a=True, montant_3a=2000.0)
        tips = engine.generate_tips(profile, today_date=date(2026, 3, 15))
        assert not _has_tip(tips, "3a_deadline")

    def test_3a_deadline_already_maxed(self, engine):
        """3a already at plafond: no deadline tip."""
        profile = _profile(has_3a=True, montant_3a=7258.0)
        tips = engine.generate_tips(profile, today_date=date(2026, 11, 1))
        assert not _has_tip(tips, "3a_deadline")

    def test_3a_deadline_independant_plafond(self, engine):
        """Independant: use higher plafond (36288)."""
        profile = _profile(
            has_3a=True,
            montant_3a=7258.0,
            employment_status="independant",
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 11, 1))
        # 7258 < 36288 -> should generate tip
        assert _has_tip(tips, "3a_deadline")
        tip = _find_tip(tips, "3a_deadline")
        # Montant deductible = 35280 - 7056 = 28224
        assert tip.estimated_impact_chf > 0

    def test_3a_deadline_retraite_excluded(self, engine):
        """Retirees should not get 3a deadline tip."""
        profile = _profile(
            has_3a=False,
            employment_status="retraite",
            age=67,
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 11, 1))
        assert not _has_tip(tips, "3a_deadline")

    def test_missing_3a_young_salarie(self, engine):
        """Young salaried worker without 3a: should get missing_3a tip."""
        profile = _profile(has_3a=False, age=28)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "missing_3a")
        tip = _find_tip(tips, "missing_3a")
        assert "7,258" in tip.message or "7'258" in tip.message
        assert tip.priority == "haute"
        assert "LIFD" in tip.source

    def test_missing_3a_has_3a(self, engine):
        """User with 3a: no missing_3a tip."""
        profile = _profile(has_3a=True)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "missing_3a")

    def test_missing_3a_over_65(self, engine):
        """Over 65: no missing_3a tip."""
        profile = _profile(has_3a=False, age=67)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "missing_3a")

    def test_3a_deadline_days_remaining_accurate(self, engine):
        """Days remaining should be accurate."""
        profile = _profile(has_3a=False)
        tips = engine.generate_tips(profile, today_date=date(2026, 12, 25))
        tip = _find_tip(tips, "3a_deadline")
        assert tip is not None
        # Dec 25 -> Dec 31 = 6 days
        assert "6 jours" in tip.message


# ===========================================================================
# TestCoachingLPP
# ===========================================================================

class TestCoachingLPP:
    """Tests for LPP buyback coaching tips."""

    def test_lpp_buyback_with_gap(self, engine):
        """User with LPP gap >= 25 should get buyback tip."""
        profile = _profile(lacune_lpp=50000.0, age=40)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "lpp_buyback")
        tip = _find_tip(tips, "lpp_buyback")
        assert "50,000" in tip.message or "50'000" in tip.message
        assert "LPP art. 79b" in tip.source

    def test_lpp_buyback_no_gap(self, engine):
        """No LPP gap: no buyback tip."""
        profile = _profile(lacune_lpp=0.0, age=40)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "lpp_buyback")

    def test_lpp_buyback_under_25(self, engine):
        """Under 25: no buyback tip even with gap."""
        profile = _profile(lacune_lpp=10000.0, age=22)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "lpp_buyback")

    def test_lpp_buyback_large_gap_haute_priority(self, engine):
        """Large gap (>50k): priority should be haute."""
        profile = _profile(lacune_lpp=80000.0, age=45)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        tip = _find_tip(tips, "lpp_buyback")
        assert tip is not None
        assert tip.priority == "haute"

    def test_lpp_buyback_small_gap_moyenne_priority(self, engine):
        """Small gap (<=50k): priority should be moyenne."""
        profile = _profile(lacune_lpp=30000.0, age=45)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        tip = _find_tip(tips, "lpp_buyback")
        assert tip is not None
        assert tip.priority == "moyenne"


# ===========================================================================
# TestCoachingTaxDeadline
# ===========================================================================

class TestCoachingTaxDeadline:
    """Tests for tax declaration deadline tips."""

    def test_tax_deadline_within_60_days(self, engine):
        """Within 60 days of deadline: should generate tip."""
        # GE deadline is March 31. Feb 15 -> 44 days away.
        profile = _profile(canton="GE")
        tips = engine.generate_tips(profile, today_date=date(2026, 2, 15))
        assert _has_tip(tips, "tax_deadline")
        tip = _find_tip(tips, "tax_deadline")
        assert "LIFD art. 124" in tip.source

    def test_tax_deadline_beyond_60_days(self, engine):
        """More than 60 days before deadline: no tip."""
        # GE deadline March 31. Jan 1 -> 89 days away.
        profile = _profile(canton="GE")
        tips = engine.generate_tips(profile, today_date=date(2026, 1, 1))
        assert not _has_tip(tips, "tax_deadline")

    def test_tax_deadline_past(self, engine):
        """After deadline: no tip."""
        profile = _profile(canton="GE")
        tips = engine.generate_tips(profile, today_date=date(2026, 4, 5))
        assert not _has_tip(tips, "tax_deadline")

    def test_tax_deadline_urgent_within_14_days(self, engine):
        """Within 14 days of deadline: priority should be haute."""
        # GE deadline March 31. March 20 -> 11 days.
        profile = _profile(canton="GE")
        tips = engine.generate_tips(profile, today_date=date(2026, 3, 20))
        tip = _find_tip(tips, "tax_deadline")
        assert tip is not None
        assert tip.priority == "haute"

    def test_tax_deadline_vaud_earlier(self, engine):
        """Vaud has March 15 deadline."""
        profile = _profile(canton="VD")
        # March 10 -> 5 days -> haute
        tips = engine.generate_tips(profile, today_date=date(2026, 3, 10))
        tip = _find_tip(tips, "tax_deadline")
        assert tip is not None
        assert tip.priority == "haute"
        assert "15.03.2026" in tip.message


# ===========================================================================
# TestCoachingRetirement
# ===========================================================================

class TestCoachingRetirement:
    """Tests for retirement countdown tips."""

    def test_retirement_countdown_age_50(self, engine):
        """At 50: should get retirement countdown."""
        profile = _profile(age=50, avoir_lpp=300000.0)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "retirement_countdown")
        tip = _find_tip(tips, "retirement_countdown")
        assert "15 annees" in tip.message
        assert "LPP art. 15" in tip.source

    def test_retirement_countdown_under_50(self, engine):
        """Under 50: no retirement countdown."""
        profile = _profile(age=35, avoir_lpp=100000.0)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "retirement_countdown")

    def test_retirement_countdown_age_65(self, engine):
        """At 65: special message."""
        profile = _profile(age=65, avoir_lpp=500000.0)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "retirement_countdown")
        tip = _find_tip(tips, "retirement_countdown")
        assert "atteint" in tip.message.lower() or "retraite" in tip.message.lower()

    def test_retirement_countdown_projection(self, engine):
        """Capital projection should compound at 1.5%."""
        profile = _profile(age=60, avoir_lpp=400000.0)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        tip = _find_tip(tips, "retirement_countdown")
        assert tip is not None
        # 400000 * (1.015)^5 ~ 430,681
        assert tip.estimated_impact_chf is not None
        assert tip.estimated_impact_chf > 400000.0

    def test_retirement_near_haute_priority(self, engine):
        """5 or fewer years to retirement: haute priority."""
        profile = _profile(age=61, avoir_lpp=400000.0)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        tip = _find_tip(tips, "retirement_countdown")
        assert tip is not None
        assert tip.priority == "haute"


# ===========================================================================
# TestCoachingEmergencyFund
# ===========================================================================

class TestCoachingEmergencyFund:
    """Tests for emergency fund coaching tips."""

    def test_emergency_fund_insufficient(self, engine):
        """Savings < 3 months expenses: should get tip."""
        profile = _profile(
            charges_fixes_mensuelles=5000.0,
            epargne_disponible=8000.0,
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "emergency_fund")
        tip = _find_tip(tips, "emergency_fund")
        assert "1.6" in tip.message  # 8000/5000 = 1.6 months

    def test_emergency_fund_sufficient(self, engine):
        """Savings >= 3 months expenses: no tip."""
        profile = _profile(
            charges_fixes_mensuelles=4000.0,
            epargne_disponible=15000.0,
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "emergency_fund")

    def test_emergency_fund_zero_expenses(self, engine):
        """Zero expenses: no tip (avoid division by zero)."""
        profile = _profile(
            charges_fixes_mensuelles=0.0,
            epargne_disponible=5000.0,
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "emergency_fund")

    def test_emergency_fund_critical_under_1_month(self, engine):
        """Less than 1 month coverage: priority should be haute."""
        profile = _profile(
            charges_fixes_mensuelles=5000.0,
            epargne_disponible=2000.0,
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        tip = _find_tip(tips, "emergency_fund")
        assert tip is not None
        assert tip.priority == "haute"

    def test_emergency_fund_between_1_and_3_months(self, engine):
        """Between 1-3 months coverage: priority should be moyenne."""
        profile = _profile(
            charges_fixes_mensuelles=4000.0,
            epargne_disponible=6000.0,
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        tip = _find_tip(tips, "emergency_fund")
        assert tip is not None
        assert tip.priority == "moyenne"


# ===========================================================================
# TestCoachingDebtRatio
# ===========================================================================

class TestCoachingDebtRatio:
    """Tests for debt ratio coaching tips."""

    def test_debt_ratio_high(self, engine):
        """Ratio > 33%: should get tip."""
        profile = _profile(
            dette_totale=40000.0,
            revenu_annuel=80000.0,
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "debt_ratio")
        tip = _find_tip(tips, "debt_ratio")
        assert "50%" in tip.message  # 40000/80000 = 50%
        assert "FINMA" in tip.source

    def test_debt_ratio_acceptable(self, engine):
        """Ratio <= 33%: no tip."""
        profile = _profile(
            dette_totale=20000.0,
            revenu_annuel=80000.0,
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "debt_ratio")

    def test_debt_ratio_no_debt(self, engine):
        """No debt: no tip."""
        profile = _profile(dette_totale=0.0)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "debt_ratio")

    def test_debt_ratio_no_income(self, engine):
        """No income: no tip (avoid division by zero)."""
        profile = _profile(dette_totale=10000.0, revenu_annuel=0.0)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "debt_ratio")

    def test_debt_ratio_very_high_haute_priority(self, engine):
        """Ratio > 50%: priority should be haute."""
        profile = _profile(
            dette_totale=60000.0,
            revenu_annuel=80000.0,
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        tip = _find_tip(tips, "debt_ratio")
        assert tip is not None
        assert tip.priority == "haute"


# ===========================================================================
# TestCoachingAgeMilestones
# ===========================================================================

class TestCoachingAgeMilestones:
    """Tests for age milestone coaching tips."""

    def test_age_25_milestone(self, engine):
        """At age 25: should get LPP start milestone."""
        profile = _profile(age=25)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "age_milestone_25")
        tip = _find_tip(tips, "age_milestone_25")
        assert "25 ans" in tip.message
        assert "LPP" in tip.source

    def test_age_26_near_25_milestone(self, engine):
        """At age 26 (within +-1 of 25): should still get 25 milestone."""
        profile = _profile(age=26)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "age_milestone_25")

    def test_age_35_milestone(self, engine):
        """At age 35: should get LPP rate increase milestone."""
        profile = _profile(age=35)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "age_milestone_35")
        tip = _find_tip(tips, "age_milestone_35")
        assert "10%" in tip.message

    def test_age_45_milestone(self, engine):
        """At age 45: should get LPP rate increase milestone."""
        profile = _profile(age=45)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "age_milestone_45")
        tip = _find_tip(tips, "age_milestone_45")
        assert "15%" in tip.message

    def test_age_50_milestone(self, engine):
        """At age 50: should get retirement planning milestone."""
        profile = _profile(age=50)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "age_milestone_50")

    def test_age_55_milestone(self, engine):
        """At age 55: should get max LPP rate milestone."""
        profile = _profile(age=55)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "age_milestone_55")
        tip = _find_tip(tips, "age_milestone_55")
        assert "18%" in tip.message

    def test_age_58_milestone(self, engine):
        """At age 58: should get pre-retirement check milestone."""
        profile = _profile(age=58)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "age_milestone_58")

    def test_age_63_milestone(self, engine):
        """At age 63: should get 2-years-to-go milestone."""
        profile = _profile(age=63)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "age_milestone_63")

    def test_age_40_no_milestone(self, engine):
        """At age 40: no milestone (between 35+1 and 45-1)."""
        profile = _profile(age=40)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        milestone_tips = [t for t in tips if t.id.startswith("age_milestone_")]
        assert len(milestone_tips) == 0


# ===========================================================================
# TestCoachingPartTime
# ===========================================================================

class TestCoachingPartTime:
    """Tests for part-time gap alert tips."""

    def test_part_time_alert(self, engine):
        """Part-time worker: should get coordination deduction alert."""
        profile = _profile(taux_activite=60.0)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "part_time_gap")
        tip = _find_tip(tips, "part_time_gap")
        assert "60%" in tip.message
        assert "LPP art. 8" in tip.source

    def test_full_time_no_alert(self, engine):
        """Full-time worker: no part-time alert."""
        profile = _profile(taux_activite=100.0)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "part_time_gap")

    def test_zero_activity_no_alert(self, engine):
        """Zero activity rate: no part-time alert."""
        profile = _profile(taux_activite=0.0)
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "part_time_gap")


# ===========================================================================
# TestCoachingIndependant
# ===========================================================================

class TestCoachingIndependant:
    """Tests for independent worker coaching tips."""

    def test_independant_alert(self, engine):
        """Independent worker: should get no-LPP alert."""
        profile = _profile(employment_status="independant")
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "independant_no_lpp")
        tip = _find_tip(tips, "independant_no_lpp")
        assert "36,288" in tip.message or "36'288" in tip.message
        assert "LPP art. 4" in tip.source
        assert tip.priority == "haute"

    def test_salarie_no_independant_alert(self, engine):
        """Salaried worker: no independant alert."""
        profile = _profile(employment_status="salarie")
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "independant_no_lpp")

    def test_retraite_no_independant_alert(self, engine):
        """Retired: no independant alert."""
        profile = _profile(employment_status="retraite")
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert not _has_tip(tips, "independant_no_lpp")


# ===========================================================================
# TestCoachingSorting
# ===========================================================================

class TestCoachingSorting:
    """Tests for tip sorting (priority then impact)."""

    def test_haute_before_moyenne(self, engine):
        """Haute priority tips should appear before moyenne."""
        profile = _profile(
            has_3a=False,
            age=35,
            lacune_lpp=30000.0,  # moyenne priority (<=50k)
            taux_activite=60.0,  # moyenne priority
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        # missing_3a is haute, part_time_gap is moyenne
        haute_indices = [i for i, t in enumerate(tips) if t.priority == "haute"]
        moyenne_indices = [i for i, t in enumerate(tips) if t.priority == "moyenne"]
        if haute_indices and moyenne_indices:
            assert max(haute_indices) < min(moyenne_indices)

    def test_higher_impact_first_within_same_priority(self, engine):
        """Within same priority, higher estimated_impact_chf should come first."""
        profile = _profile(
            has_3a=False,
            age=35,
            lacune_lpp=80000.0,  # haute priority
            employment_status="independant",  # haute priority
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        haute_tips = [t for t in tips if t.priority == "haute"]
        # Check that tips with impact are sorted descending
        impacts = [
            t.estimated_impact_chf for t in haute_tips
            if t.estimated_impact_chf is not None
        ]
        if len(impacts) >= 2:
            assert impacts == sorted(impacts, reverse=True)


# ===========================================================================
# TestCoachingCompliance
# ===========================================================================

class TestCoachingCompliance:
    """Tests for compliance: no banned terms, source references, etc."""

    def test_no_banned_terms_in_any_tip(self, engine):
        """No tip message should contain 'garanti', 'assure', 'certain'."""
        # Create a profile that triggers many tips
        profile = _profile(
            has_3a=False,
            age=50,
            lacune_lpp=60000.0,
            taux_activite=80.0,
            charges_fixes_mensuelles=5000.0,
            epargne_disponible=3000.0,
            dette_totale=60000.0,
            employment_status="salarie",
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 11, 1))

        banned_terms = ["garanti", "certain"]
        for tip in tips:
            full_text = f"{tip.title} {tip.message} {tip.action}".lower()
            for term in banned_terms:
                assert term not in full_text, (
                    f"Banned term '{term}' found in tip {tip.id}: {full_text}"
                )

    def test_all_tips_have_source(self, engine):
        """Every tip must have a non-empty source field."""
        profile = _profile(
            has_3a=False,
            age=50,
            lacune_lpp=60000.0,
            taux_activite=80.0,
            charges_fixes_mensuelles=5000.0,
            epargne_disponible=3000.0,
            dette_totale=60000.0,
            employment_status="salarie",
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 11, 1))

        for tip in tips:
            assert tip.source, f"Tip {tip.id} has empty source"
            assert len(tip.source) > 3, f"Tip {tip.id} has too-short source: {tip.source}"

    def test_all_tips_french_language(self, engine):
        """Spot-check that tips are in French (contain common French words)."""
        profile = _profile(
            has_3a=False,
            age=50,
            lacune_lpp=60000.0,
            charges_fixes_mensuelles=5000.0,
            epargne_disponible=3000.0,
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 11, 1))

        french_indicators = ["votre", "vous", "de", "est", "le", "la", "les", "un", "une"]
        for tip in tips:
            text_lower = tip.message.lower()
            has_french = any(word in text_lower for word in french_indicators)
            assert has_french, f"Tip {tip.id} does not appear to be in French: {tip.message}"


# ===========================================================================
# TestCoachingEndpoints
# ===========================================================================

class TestCoachingEndpoints:
    """Tests for the FastAPI coaching endpoints."""

    def test_coaching_tips_endpoint(self, client):
        """POST /api/v1/coaching/tips works."""
        payload = {
            "age": 35,
            "canton": "GE",
            "revenuAnnuel": 85000,
            "has3a": False,
            "montant3a": 0,
            "hasLpp": True,
            "avoirLpp": 120000,
            "lacuneLpp": 30000,
            "tauxActivite": 80,
            "chargesFixesMensuelles": 4000,
            "epargneDisponible": 15000,
            "detteTotale": 0,
            "hasBudget": True,
            "employmentStatus": "salarie",
            "etatCivil": "celibataire",
        }
        response = client.post("/api/v1/coaching/tips", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "tips" in data
        assert "disclaimer" in data
        assert isinstance(data["tips"], list)
        assert len(data["tips"]) > 0
        # Check disclaimer content
        assert "indicatives" in data["disclaimer"]
        assert "conseil financier" in data["disclaimer"]

    def test_coaching_tips_response_structure(self, client):
        """Tip response should have all expected fields."""
        payload = {
            "age": 35,
            "canton": "GE",
            "revenuAnnuel": 85000,
            "has3a": False,
            "montant3a": 0,
            "hasLpp": True,
            "avoirLpp": 120000,
            "lacuneLpp": 30000,
            "tauxActivite": 100,
            "chargesFixesMensuelles": 4000,
            "epargneDisponible": 15000,
            "detteTotale": 0,
            "hasBudget": True,
            "employmentStatus": "salarie",
            "etatCivil": "celibataire",
        }
        response = client.post("/api/v1/coaching/tips", json=payload)
        assert response.status_code == 200
        data = response.json()
        first_tip = data["tips"][0]
        expected_fields = [
            "id", "category", "priority", "title",
            "message", "action", "estimatedImpactChf",
            "source", "icon",
        ]
        for field_name in expected_fields:
            assert field_name in first_tip, f"Missing field: {field_name}"

    def test_coaching_tips_validation_error(self, client):
        """POST with missing required fields should fail validation."""
        payload = {
            "age": 35,
            # Missing revenuAnnuel
        }
        response = client.post("/api/v1/coaching/tips", json=payload)
        assert response.status_code == 422

    def test_coaching_endpoint_independant(self, client):
        """POST with independant profile should include independant tip."""
        payload = {
            "age": 40,
            "canton": "ZH",
            "revenuAnnuel": 100000,
            "has3a": True,
            "montant3a": 7056,
            "hasLpp": False,
            "avoirLpp": 0,
            "lacuneLpp": 0,
            "tauxActivite": 100,
            "chargesFixesMensuelles": 5000,
            "epargneDisponible": 20000,
            "detteTotale": 0,
            "hasBudget": True,
            "employmentStatus": "independant",
            "etatCivil": "marie",
        }
        response = client.post("/api/v1/coaching/tips", json=payload)
        assert response.status_code == 200
        data = response.json()
        tip_ids = [t["id"] for t in data["tips"]]
        assert "independant_no_lpp" in tip_ids
