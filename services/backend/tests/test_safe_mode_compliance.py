"""
Tests for Safe Mode compliance — Debt gating across services.

Verifies that when a user has active debt (has_debt=True), the system
correctly prioritizes debt resolution and gates optimization features.

Test categories:
    - TestSafeModeNextSteps: NextStepsService debt prioritization (5 tests)
    - TestSafeModeEducationalContent: Educational inserts safe_mode field (5 tests)
    - TestSafeModeRecommendations: No optimization when debt detected (5 tests)

Sources:
    - LSFin art. 3 (distinction conseil / information)
    - LPP art. 79b al. 3 (blocage EPL apres rachat)
    - OPP3 art. 7 (plafond 3a)
    - LCC art. 17 (remboursement anticipe credit conso)

Ethical requirements:
    - Educational tone, never prescriptive
    - Gender-neutral language (un-e specialiste)
    - No banned terms: garanti, certain, assure, sans risque, optimal, meilleur, parfait
"""

import pytest

from app.services.next_steps_service import (
    NextStepsInput,
    NextStepsResult,
    NextStepsService,
    DISCLAIMER,
    SOURCES,
)

from app.services.educational_content_service import (
    EducationalContentService,
    InsertContent,
    BANNED_TERMS,
)


# ══════════════════════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def next_steps_service():
    return NextStepsService()


@pytest.fixture
def edu_service():
    return EducationalContentService()


def _base_input(**overrides) -> NextStepsInput:
    """Create a base NextStepsInput with sensible defaults, overriding fields."""
    defaults = dict(
        age=35,
        civil_status="single",
        children_count=0,
        employment_status="employee",
        monthly_net_income=6500.0,
        canton="ZH",
        has_3a=True,
        has_pension_fund=True,
        has_debt=False,
        has_real_estate=False,
        has_investments=False,
    )
    defaults.update(overrides)
    return NextStepsInput(**defaults)


# ══════════════════════════════════════════════════════════════════════════════
# TestSafeModeNextSteps — debt always first priority (5 tests)
# ══════════════════════════════════════════════════════════════════════════════

class TestSafeModeNextSteps:
    """NextStepsService must prioritize debt when has_debt=True."""

    def test_debt_always_first_priority(self, next_steps_service):
        """When has_debt=True, debtCrisis must be first with priority=1."""
        result = next_steps_service.calculate(_base_input(
            age=30, civil_status="single", children_count=0,
            employment_status="employee", monthly_net_income=6000,
            canton="VD", has_debt=True,
        ))
        assert result.steps[0].life_event == "debtCrisis"
        assert result.steps[0].priority == 1

    def test_debt_priority_over_retirement(self, next_steps_service):
        """Debt must appear before retirement even for a 60-year-old."""
        result = next_steps_service.calculate(_base_input(
            age=60, has_debt=True,
        ))
        debt_idx = None
        retirement_idx = None
        for i, step in enumerate(result.steps):
            if step.life_event == "debtCrisis":
                debt_idx = i
            if step.life_event == "retirement":
                retirement_idx = i
        assert debt_idx is not None, "debtCrisis step missing"
        # Both have priority 1, but debt is added first so appears first
        assert debt_idx <= (retirement_idx if retirement_idx is not None else 999)

    def test_debt_priority_over_concubinage(self, next_steps_service):
        """Debt must have higher priority than concubinage protection."""
        result = next_steps_service.calculate(_base_input(
            civil_status="concubinage", has_debt=True,
        ))
        debt_step = None
        concubinage_step = None
        for step in result.steps:
            if step.life_event == "debtCrisis":
                debt_step = step
            if step.life_event == "concubinage":
                concubinage_step = step
        assert debt_step is not None
        assert debt_step.priority <= concubinage_step.priority

    def test_debt_route_is_check_debt(self, next_steps_service):
        """Debt step must route to /check/debt."""
        result = next_steps_service.calculate(_base_input(has_debt=True))
        debt_step = next(s for s in result.steps if s.life_event == "debtCrisis")
        assert debt_step.route == "/check/debt"

    def test_no_debt_no_debt_crisis_step(self, next_steps_service):
        """When has_debt=False, no debtCrisis step should appear."""
        result = next_steps_service.calculate(_base_input(has_debt=False))
        events = [s.life_event for s in result.steps]
        assert "debtCrisis" not in events


# ══════════════════════════════════════════════════════════════════════════════
# TestSafeModeEducationalContent — safe_mode field validation (5 tests)
# ══════════════════════════════════════════════════════════════════════════════

class TestSafeModeEducationalContent:
    """Educational inserts must all have safe_mode field populated."""

    def test_all_16_inserts_have_safe_mode(self, edu_service):
        """All 16 educational inserts must have a non-empty safe_mode field."""
        inserts = edu_service.get_all_inserts()
        assert len(inserts) == 16, f"Expected 16 inserts, got {len(inserts)}"
        for insert in inserts:
            assert insert.safe_mode is not None, (
                f"Insert {insert.question_id} has None safe_mode"
            )
            assert len(insert.safe_mode.strip()) > 0, (
                f"Insert {insert.question_id} has empty safe_mode"
            )

    def test_debt_related_inserts_mention_desendettement(self, edu_service):
        """Inserts about credit/leasing should mention desendettement in safe_mode."""
        debt_inserts = [
            "q_has_consumer_credit",
            "q_has_leasing",
        ]
        for qid in debt_inserts:
            insert = edu_service.get_insert(qid)
            assert insert is not None, f"Insert {qid} not found"
            safe_lower = insert.safe_mode.lower()
            assert "dette" in safe_lower or "safe mode" in safe_lower or "remboursement" in safe_lower, (
                f"Insert {qid} safe_mode should mention debt: {insert.safe_mode}"
            )

    def test_optimization_inserts_gated_when_debt(self, edu_service):
        """Optimization inserts (3a, buyback, investments) should indicate gating."""
        optimization_inserts = [
            "q_has_3a",
            "q_3a_annual_amount",
            "q_lpp_buyback_available",
            "q_has_investments",
            "q_real_estate_project",
        ]
        for qid in optimization_inserts:
            insert = edu_service.get_insert(qid)
            assert insert is not None, f"Insert {qid} not found"
            safe_lower = insert.safe_mode.lower()
            # Must mention desactivation, desendettement, or priorite
            assert any(term in safe_lower for term in [
                "desactiv", "desendettement", "priorite", "dette",
                "bloque", "masque",
            ]), (
                f"Insert {qid} safe_mode should indicate gating: {insert.safe_mode}"
            )

    def test_emergency_fund_always_active(self, edu_service):
        """Emergency fund insert should always be active (even in safe mode)."""
        insert = edu_service.get_insert("q_emergency_fund")
        assert insert is not None
        safe_lower = insert.safe_mode.lower()
        assert "toujours" in safe_lower or "actif" in safe_lower, (
            f"Emergency fund should be always active: {insert.safe_mode}"
        )

    def test_stress_check_always_active(self, edu_service):
        """Financial stress check insert should always be active."""
        insert = edu_service.get_insert("q_financial_stress_check")
        assert insert is not None
        safe_lower = insert.safe_mode.lower()
        assert "toujours" in safe_lower or "actif" in safe_lower or "point d'entree" in safe_lower, (
            f"Stress check should be always active: {insert.safe_mode}"
        )


# ══════════════════════════════════════════════════════════════════════════════
# TestSafeModeRecommendations — no optimization when debt (5 tests)
# ══════════════════════════════════════════════════════════════════════════════

class TestSafeModeRecommendations:
    """When debt is active, optimization recommendations must be suppressed."""

    def test_debt_user_gets_max_5_steps(self, next_steps_service):
        """Even with debt + many triggers, max 5 steps returned."""
        result = next_steps_service.calculate(_base_input(
            age=56,
            civil_status="concubinage",
            children_count=2,
            employment_status="employee",
            monthly_net_income=8000,
            canton="GE",
            has_debt=True,
            has_real_estate=True,
        ))
        assert len(result.steps) <= 5

    def test_debt_user_debt_is_always_first(self, next_steps_service):
        """Debt must always be the first step regardless of other triggers."""
        result = next_steps_service.calculate(_base_input(
            age=56,
            civil_status="concubinage",
            children_count=2,
            employment_status="unemployed",
            monthly_net_income=8000,
            canton="GE",
            has_debt=True,
        ))
        assert result.steps[0].life_event == "debtCrisis"
        assert result.steps[0].priority == 1

    def test_debt_step_has_educational_reason(self, next_steps_service):
        """Debt step reason must be educational and mention understanding."""
        result = next_steps_service.calculate(_base_input(has_debt=True))
        debt_step = next(s for s in result.steps if s.life_event == "debtCrisis")
        reason_lower = debt_step.reason.lower()
        assert "dette" in reason_lower or "endettement" in reason_lower

    def test_debt_step_icon_is_warning(self, next_steps_service):
        """Debt step icon must be 'warning'."""
        result = next_steps_service.calculate(_base_input(has_debt=True))
        debt_step = next(s for s in result.steps if s.life_event == "debtCrisis")
        assert debt_step.icon_name == "warning"

    def test_debt_disclaimer_always_present(self, next_steps_service):
        """Disclaimer must always be present, even for debt users."""
        result = next_steps_service.calculate(_base_input(has_debt=True))
        assert result.disclaimer == DISCLAIMER
        assert "LSFin" in result.disclaimer
        assert "educati" in result.disclaimer.lower()


# ══════════════════════════════════════════════════════════════════════════════
# TestSafeModeComplianceBannedTerms — no banned terms (3 tests)
# ══════════════════════════════════════════════════════════════════════════════

class TestSafeModeComplianceBannedTerms:
    """Safe mode outputs must not contain banned terms."""

    def test_no_banned_terms_in_educational_safe_mode(self, edu_service):
        """safe_mode field in all inserts must not contain banned terms."""
        inserts = edu_service.get_all_inserts()
        for insert in inserts:
            text_lower = insert.safe_mode.lower()
            for term in BANNED_TERMS:
                assert term not in text_lower, (
                    f"Banned term '{term}' found in safe_mode of {insert.question_id}"
                )

    def test_no_banned_terms_in_debt_step_output(self, next_steps_service):
        """Debt step title and reason must not contain banned terms."""
        result = next_steps_service.calculate(_base_input(has_debt=True))
        debt_step = next(s for s in result.steps if s.life_event == "debtCrisis")
        text_lower = f"{debt_step.title} {debt_step.reason}".lower()
        for term in BANNED_TERMS:
            assert term not in text_lower, (
                f"Banned term '{term}' found in debt step output"
            )

    def test_no_banned_terms_in_all_insert_content(self, edu_service):
        """All insert fields must be free of banned terms."""
        inserts = edu_service.get_all_inserts()
        for insert in inserts:
            all_text = " ".join([
                insert.title,
                insert.chiffre_choc,
                insert.safe_mode,
                insert.action_label,
                " ".join(insert.learning_goals),
            ]).lower()
            for term in BANNED_TERMS:
                assert term not in all_text, (
                    f"Banned term '{term}' in insert {insert.question_id}"
                )


# ══════════════════════════════════════════════════════════════════════════════
# TestSafeModeInsertStructure — structural validation (2 tests)
# ══════════════════════════════════════════════════════════════════════════════

class TestSafeModeInsertStructure:
    """Structural integrity of educational inserts for safe mode."""

    def test_all_inserts_have_disclaimer_with_lsfin(self, edu_service):
        """Every insert must have a disclaimer mentioning LSFin."""
        inserts = edu_service.get_all_inserts()
        for insert in inserts:
            assert "LSFin" in insert.disclaimer, (
                f"Insert {insert.question_id} missing LSFin in disclaimer"
            )
            assert "educatif" in insert.disclaimer.lower(), (
                f"Insert {insert.question_id} missing 'educatif' in disclaimer"
            )

    def test_all_inserts_have_sources(self, edu_service):
        """Every insert must have at least one Swiss law source."""
        inserts = edu_service.get_all_inserts()
        for insert in inserts:
            assert len(insert.sources) > 0, (
                f"Insert {insert.question_id} has no sources"
            )
