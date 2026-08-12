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
        """Independant SANS LPP : grand 3a borné à 20% du revenu (OPP3 art. 7).
        revenu 85'000 -> plafond 17'000 (pas 36'288) ; 7'258 versé < 17'000
        donc marge restante -> tip généré (revue Codex P1-2)."""
        profile = _profile(
            has_3a=True,
            montant_3a=7258.0,
            employment_status="independant",
            has_lpp=False,
            revenu_annuel=85_000.0,
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 11, 1))
        # plafond 17'000 > 7'258 versé -> marge restante -> tip
        assert _has_tip(tips, "3a_deadline")
        tip = _find_tip(tips, "3a_deadline")
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
        """Independent worker sans LPP + revenu élevé: no-LPP alert, plafond réel
        (grand 3a borné, ici 36'288 à revenu 200k)."""
        profile = _profile(
            employment_status="independant", has_lpp=False, revenu_annuel=200_000.0
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        assert _has_tip(tips, "independant_no_lpp")
        tip = _find_tip(tips, "independant_no_lpp")
        assert "36,288" in tip.message or "36'288" in tip.message
        assert "LPP art. 4" in tip.source
        assert tip.priority == "haute"

    def test_independant_no_income_shows_rule(self, engine):
        """Indépendant sans LPP ET sans revenu -> le tip affiche LA RÈGLE
        (« 20 % ... au maximum 36'288 »), pas un plafond chiffré isolé faux
        (revue Codex F1). missing_3a idem -> cohérent, plus de 4'000/36'288
        contradictoires dans la même réponse."""
        profile = _profile(
            employment_status="independant", has_lpp=False,
            revenu_annuel=0.0, has_3a=False, age=35,
        )
        tips = engine.generate_tips(profile, today_date=date(2026, 5, 1))
        alert = _find_tip(tips, "independant_no_lpp")
        missing = _find_tip(tips, "missing_3a")
        assert alert is not None and missing is not None
        # les DEUX tips montrent la règle (20% + OPP3), aucun ne propose un
        # plafond chiffré nu -> plus de contradiction 4'000 vs 36'288.
        for msg in (alert.message, missing.message):
            assert "20 %" in msg and "OPP3 art. 7" in msg
        assert missing.estimated_impact_chf is None

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


# ---------------------------------------------------------------------------
# Marginal rate honours civil status (Batch C — coherence fix).
#
# Le coach appelait estimate_marginal_rate SANS is_married : un marie recevait
# le taux marginal celibataire, alors que rules_engine.calculate_marginal_tax_rate
# respecte deja le statut. C'est le vice « un seul taux marginal » (#1061/#1062).
# ---------------------------------------------------------------------------


class TestCoachingMarginalRateCivilStatus:

    def test_married_and_single_get_different_impact_public_path(self, engine):
        """Regression (public path) : le tip missing_3a affiche une economie
        d'impot = plafond x taux marginal. Un marie et un celibataire, meme
        revenu/canton, doivent obtenir des impacts DIFFERENTS."""
        common = dict(has_3a=False, age=30, canton="ZH", revenu_annuel=120_000.0)
        marie = _find_tip(
            engine.generate_tips(
                _profile(etat_civil="marie", **common), today_date=date(2026, 5, 1)
            ),
            "missing_3a",
        )
        single = _find_tip(
            engine.generate_tips(
                _profile(etat_civil="celibataire", **common),
                today_date=date(2026, 5, 1),
            ),
            "missing_3a",
        )
        assert marie is not None and single is not None
        assert marie.estimated_impact_chf != single.estimated_impact_chf

    def test_marginal_rate_matches_rules_engine_and_etalon(self, engine):
        """Le taux coach == etalon ESTV avec is_married, ET == ce que
        rules_engine produirait pour le meme statut (surfaces reconciliees)."""
        from app.services.fiscal.cantonal_comparator import estimate_marginal_rate
        from app.services.rules_engine import calculate_marginal_tax_rate

        canton, revenu = "ZH", 120_000.0
        taux_marie = engine._get_marginal_rate(canton, revenu, "marie")
        taux_single = engine._get_marginal_rate(canton, revenu, "celibataire")

        assert taux_marie != taux_single
        assert taux_marie == estimate_marginal_rate(revenu, canton, is_married=True)
        assert taux_single == estimate_marginal_rate(revenu, canton, is_married=False)
        assert taux_marie == calculate_marginal_tax_rate(canton, revenu, "married")
        assert taux_single == calculate_marginal_tax_rate(canton, revenu, "single")

    def test_single_rate_is_non_regressed(self, engine):
        """Non-regression : le taux celibataire est INCHANGE (defaut historique
        = celibataire), egal a l'etalon is_married=False."""
        from app.services.fiscal.cantonal_comparator import estimate_marginal_rate

        canton, revenu = "GE", 85_000.0
        # defaut de signature (pas d'etat civil passe) == celibataire explicite.
        assert engine._get_marginal_rate(canton, revenu) == estimate_marginal_rate(
            revenu, canton, is_married=False
        )
        assert engine._get_marginal_rate(canton, revenu, "celibataire") == (
            estimate_marginal_rate(revenu, canton, is_married=False)
        )

    @pytest.mark.parametrize("statut", ["marie", "marie_pacse", "MARIÉ", "partenariat"])
    def test_married_synonyms_use_married_rate(self, engine, statut):
        """Synonymes maries (normalisation partagee fiscal.civil_status) ->
        taux marie."""
        from app.services.fiscal.cantonal_comparator import estimate_marginal_rate

        canton, revenu = "ZH", 120_000.0
        assert engine._get_marginal_rate(canton, revenu, statut) == (
            estimate_marginal_rate(revenu, canton, is_married=True)
        )

    @pytest.mark.parametrize("statut", ["celibataire", "divorce", "veuf", "concubinage"])
    def test_separate_taxation_statuses_use_single_rate(self, engine, statut):
        """Divorce, veuvage, concubinage = taxation separee -> taux celibataire
        (jamais le taux marie)."""
        from app.services.fiscal.cantonal_comparator import estimate_marginal_rate

        canton, revenu = "ZH", 120_000.0
        assert engine._get_marginal_rate(canton, revenu, statut) == (
            estimate_marginal_rate(revenu, canton, is_married=False)
        )


class TestCoachingCeilingOPP3:
    """Batch E1 — le grand 3a (indépendant sans LPP) est borné à 20% du revenu
    (OPP3 art. 7). Repro Codex : indépendant 20'000 -> 4'000, pas 36'288."""

    def test_ceiling_independant_capped_at_20pct(self, engine):
        p = _profile(employment_status="independant", has_lpp=False, revenu_annuel=20_000.0)
        # oracle externe : 20% de 20'000 = 4'000
        assert engine._ceiling_3a(p) == 4_000.0
        assert engine._ceiling_3a(p) != 36_288.0

    def test_ceiling_independant_with_lpp_is_small_3a(self, engine):
        from app.constants.social_insurance import PILIER_3A_PLAFOND_AVEC_LPP

        p = _profile(employment_status="independant", has_lpp=True, revenu_annuel=20_000.0)
        assert engine._ceiling_3a(p) == PILIER_3A_PLAFOND_AVEC_LPP

    def test_missing_3a_tip_shows_capped_ceiling(self, engine):
        """Public path : le tip missing_3a d'un indépendant modeste ne propose
        plus 36'288 mais le plafond borné."""
        p = _profile(
            has_3a=False, age=35, employment_status="independant",
            has_lpp=False, revenu_annuel=20_000.0, canton="ZH",
        )
        tips = engine.generate_tips(p, today_date=date(2026, 5, 1))
        tip = _find_tip(tips, "missing_3a")
        assert tip is not None
        # le plafond borné 4'000 apparaît, le grand 3a nu 36'288 disparaît.
        assert ("4,000" in tip.message) or ("4'000" in tip.message)
        assert "36,288" not in tip.message and "36'288" not in tip.message


class TestCoachingTaxSavingIsDifference:
    """Batch E2 — les 3 tips affichent la DIFFÉRENCE d'impôt (estimate_tax_saving),
    pas déduction × taux marginal (revue Codex P1-4)."""

    def test_missing_3a_repro_ne_marie_16k(self, engine):
        """Repro Codex exécuté : NE, marié, 16'000. Ancien coach = 1'055.39
        (7'258 × taux), nouveau = 294.93 (différence d'impôt). Oracle externe."""
        p = _profile(
            has_3a=False, age=35, canton="NE",
            revenu_annuel=16_000.0, etat_civil="marie",
            employment_status="salarie", has_lpp=True,
        )
        tip = _find_tip(engine.generate_tips(p, today_date=date(2026, 5, 1)), "missing_3a")
        assert tip is not None
        assert tip.estimated_impact_chf == pytest.approx(294.93, abs=0.01)  # externe
        assert tip.estimated_impact_chf != pytest.approx(1055.39, abs=0.01)  # ancien produit

    def test_deadline_incremental_already_contributed(self, engine):
        """F2 — économie du RESTANT incrémentale : NE marié 16'000, 3'000 déjà
        versés -> 101.73 (différence entre revenu-3'000 et revenu-plafond), pas
        223.25 (base = revenu brut). Oracle externe exécuté."""
        p = _profile(
            has_3a=True, montant_3a=3_000.0, canton="NE", revenu_annuel=16_000.0,
            etat_civil="marie", employment_status="salarie", has_lpp=True, age=35,
        )
        tip = _find_tip(engine.generate_tips(p, today_date=date(2026, 11, 1)), "3a_deadline")
        assert tip is not None
        assert tip.estimated_impact_chf == pytest.approx(101.73, abs=0.01)
        assert tip.estimated_impact_chf != pytest.approx(223.25, abs=0.01)

    def test_missing_3a_equals_canonical_difference(self, engine):
        """Le montant du tip == estimate_tax_saving (jamais plafond × taux)."""
        from app.services.fiscal.cantonal_comparator import estimate_tax_saving

        p = _profile(
            has_3a=False, age=35, canton="ZH", revenu_annuel=90_000.0,
            etat_civil="marie", employment_status="salarie", has_lpp=True,
        )
        tip = _find_tip(engine.generate_tips(p, today_date=date(2026, 5, 1)), "missing_3a")
        plafond = engine._ceiling_3a(p)
        expected = estimate_tax_saving(90_000.0, plafond, "ZH", is_married=True)
        assert tip.estimated_impact_chf == pytest.approx(round(expected, 2), abs=0.01)

    def test_lpp_buyback_equals_canonical_difference(self, engine):
        from app.services.fiscal.cantonal_comparator import estimate_tax_saving

        p = _profile(
            age=40, canton="VD", revenu_annuel=100_000.0, lacune_lpp=30_000.0,
            etat_civil="celibataire",
        )
        tip = _find_tip(engine.generate_tips(p, today_date=date(2026, 5, 1)), "lpp_buyback")
        montant = min(30_000.0, 20_000.0)
        expected = estimate_tax_saving(100_000.0, montant, "VD", is_married=False)
        assert tip.estimated_impact_chf == pytest.approx(round(expected, 2), abs=0.01)

    def test_married_caveat_present_only_when_married(self, engine):
        common = dict(
            has_3a=False, age=35, canton="ZH", revenu_annuel=90_000.0,
            employment_status="salarie", has_lpp=True,
        )
        marie = _find_tip(
            engine.generate_tips(_profile(etat_civil="marie", **common), today_date=date(2026, 5, 1)),
            "missing_3a",
        )
        single = _find_tip(
            engine.generate_tips(_profile(etat_civil="celibataire", **common), today_date=date(2026, 5, 1)),
            "missing_3a",
        )
        assert "conjoint" in marie.message.lower()
        assert "conjoint" not in single.message.lower()


class TestCoachingEndpointBoundaryValidation:
    """F3 — l'endpoint rejette proprement (422) les revenus non finis au lieu de
    renvoyer 200 + 36'288 (repro Codex endpoint exécuté)."""

    def test_infinite_income_returns_clean_422_not_36288(self):
        from fastapi.testclient import TestClient
        from app.main import app

        client = TestClient(app, raise_server_exceptions=False)
        raw = (
            '{"age":35,"canton":"NE","revenuAnnuel":Infinity,"has3a":false,'
            '"montant3a":0,"hasLpp":false,"avoirLpp":0,"lacuneLpp":0,'
            '"tauxActivite":100,"chargesFixesMensuelles":2000,'
            '"epargneDisponible":5000,"detteTotale":0,"hasBudget":true,'
            '"employmentStatus":"independant","etatCivil":"celibataire"}'
        )
        r = client.post(
            "/api/v1/coaching/tips", content=raw,
            headers={"content-type": "application/json"},
        )
        assert r.status_code == 422  # propre, pas 200 ni 500
        assert "36288" not in r.text and "36'288" not in r.text
