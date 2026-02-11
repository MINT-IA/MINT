"""
Tests for NextStepsService — Recommandations de simulateurs et evenements de vie.

Test categories:
    - TestNextStepsDebt: debt always first priority (3 tests)
    - TestNextStepsAge: age-based recommendations (5 tests)
    - TestNextStepsCivilStatus: marriage/concubinage/divorce (5 tests)
    - TestNextStepsEmployment: employee/independent/unemployed (5 tests)
    - TestNextStepsHousing: real estate recommendations (4 tests)
    - TestNextStepsCanton: high-tax canton recommendations (3 tests)
    - TestNextStepsCompliance: disclaimer, sources, max 5 steps (5 tests)
"""

import pytest

from app.services.next_steps_service import (
    NextStepsInput,
    NextStep,
    NextStepsResult,
    NextStepsService,
    DISCLAIMER,
    SOURCES,
    MAX_STEPS,
    ROUTE_MAP,
    ICON_MAP,
    HIGH_TAX_CANTONS,
    LIFE_EVENTS,
)


# ══════════════════════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def service():
    return NextStepsService()


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


def _event_names(result: NextStepsResult) -> list:
    """Extract life event names from result steps."""
    return [s.life_event for s in result.steps]


def _find_step(result: NextStepsResult, event: str) -> NextStep:
    """Find a step by life event name."""
    for s in result.steps:
        if s.life_event == event:
            return s
    return None


# ══════════════════════════════════════════════════════════════════════════════
# TestNextStepsDebt — debt always first priority (3 tests)
# ══════════════════════════════════════════════════════════════════════════════

class TestNextStepsDebt:
    """Debt-related recommendations must always be highest priority."""

    def test_debt_always_first_in_list(self, service):
        """When user has debt, debtCrisis must be the first step."""
        inp = _base_input(has_debt=True)
        result = service.calculate(inp)
        assert result.steps[0].life_event == "debtCrisis"
        assert result.steps[0].priority == 1

    def test_debt_first_even_with_unemployment(self, service):
        """Debt step appears before or at same priority as jobLoss."""
        inp = _base_input(has_debt=True, employment_status="unemployed")
        result = service.calculate(inp)
        events = _event_names(result)
        assert "debtCrisis" in events
        assert "jobLoss" in events
        # Both are priority 1, but debtCrisis is added first
        debt_step = _find_step(result, "debtCrisis")
        assert debt_step.priority == 1

    def test_debt_first_even_with_retirement_age(self, service):
        """Debt step appears even for 60-year-old near retirement."""
        inp = _base_input(has_debt=True, age=60)
        result = service.calculate(inp)
        events = _event_names(result)
        assert "debtCrisis" in events
        debt_step = _find_step(result, "debtCrisis")
        assert debt_step.priority == 1
        assert debt_step.route == "/check/debt"


# ══════════════════════════════════════════════════════════════════════════════
# TestNextStepsAge — age-based recommendations (5 tests)
# ══════════════════════════════════════════════════════════════════════════════

class TestNextStepsAge:
    """Age-based recommendation rules."""

    def test_young_employee_gets_first_job(self, service):
        """Age <= 28 employee should get firstJob recommendation."""
        inp = _base_input(age=24, employment_status="employee")
        result = service.calculate(inp)
        events = _event_names(result)
        assert "firstJob" in events
        step = _find_step(result, "firstJob")
        assert step.priority == 2
        assert step.route == "/first-job"

    def test_age_28_boundary_still_gets_first_job(self, service):
        """Age == 28 is the boundary, should still get firstJob."""
        inp = _base_input(age=28, employment_status="employee")
        result = service.calculate(inp)
        events = _event_names(result)
        assert "firstJob" in events

    def test_age_29_no_first_job(self, service):
        """Age > 28 should NOT get firstJob."""
        inp = _base_input(age=29, employment_status="employee")
        result = service.calculate(inp)
        events = _event_names(result)
        assert "firstJob" not in events

    def test_age_55_gets_retirement(self, service):
        """Age >= 55 should get retirement recommendation."""
        inp = _base_input(age=55)
        result = service.calculate(inp)
        events = _event_names(result)
        assert "retirement" in events
        step = _find_step(result, "retirement")
        assert step.priority == 1
        assert step.route == "/retirement"

    def test_age_54_no_retirement(self, service):
        """Age < 55 should NOT get retirement recommendation."""
        inp = _base_input(age=54)
        result = service.calculate(inp)
        events = _event_names(result)
        assert "retirement" not in events


# ══════════════════════════════════════════════════════════════════════════════
# TestNextStepsCivilStatus — marriage/concubinage/divorce (5 tests)
# ══════════════════════════════════════════════════════════════════════════════

class TestNextStepsCivilStatus:
    """Civil status-based recommendation rules."""

    def test_concubinage_gets_warning(self, service):
        """Concubinage status should generate concubinage step with priority 2."""
        inp = _base_input(civil_status="concubinage")
        result = service.calculate(inp)
        events = _event_names(result)
        assert "concubinage" in events
        step = _find_step(result, "concubinage")
        assert step.priority == 2
        assert step.route == "/concubinage"
        assert "protection legale" in step.reason.lower() or "protection" in step.reason.lower()

    def test_single_25_plus_gets_marriage_info(self, service):
        """Single person aged 25+ should get informational marriage step."""
        inp = _base_input(civil_status="single", age=30)
        result = service.calculate(inp)
        events = _event_names(result)
        assert "marriage" in events
        step = _find_step(result, "marriage")
        assert step.priority == 4
        assert step.route == "/mariage"

    def test_single_under_25_no_marriage(self, service):
        """Single person under 25 should NOT get marriage recommendation."""
        inp = _base_input(civil_status="single", age=23)
        result = service.calculate(inp)
        events = _event_names(result)
        assert "marriage" not in events

    def test_married_no_children_gets_birth(self, service):
        """Married couple without children should get birth recommendation."""
        inp = _base_input(civil_status="married", children_count=0)
        result = service.calculate(inp)
        events = _event_names(result)
        assert "birth" in events
        step = _find_step(result, "birth")
        assert step.priority == 4
        assert step.route == "/naissance"

    def test_married_with_children_no_birth(self, service):
        """Married couple with children should NOT get birth recommendation."""
        inp = _base_input(civil_status="married", children_count=2)
        result = service.calculate(inp)
        events = _event_names(result)
        assert "birth" not in events


# ══════════════════════════════════════════════════════════════════════════════
# TestNextStepsEmployment — employee/independent/unemployed (5 tests)
# ══════════════════════════════════════════════════════════════════════════════

class TestNextStepsEmployment:
    """Employment status-based recommendation rules."""

    def test_unemployed_gets_job_loss(self, service):
        """Unemployed user should get jobLoss with priority 1."""
        inp = _base_input(employment_status="unemployed")
        result = service.calculate(inp)
        events = _event_names(result)
        assert "jobLoss" in events
        step = _find_step(result, "jobLoss")
        assert step.priority == 1
        assert step.route == "/unemployment"

    def test_independent_gets_self_employment(self, service):
        """Independent worker should get selfEmployment with priority 2."""
        inp = _base_input(employment_status="independent")
        result = service.calculate(inp)
        events = _event_names(result)
        assert "selfEmployment" in events
        step = _find_step(result, "selfEmployment")
        assert step.priority == 2
        assert step.route == "/segments/independant"

    def test_employee_age_30_plus_gets_new_job(self, service):
        """Employee aged 30+ should get newJob recommendation."""
        inp = _base_input(age=35, employment_status="employee")
        result = service.calculate(inp)
        events = _event_names(result)
        assert "newJob" in events
        step = _find_step(result, "newJob")
        assert step.priority == 4
        assert step.route == "/simulator/job-comparison"

    def test_employee_under_30_no_new_job(self, service):
        """Employee under 30 should NOT get newJob recommendation."""
        inp = _base_input(age=25, employment_status="employee")
        result = service.calculate(inp)
        events = _event_names(result)
        assert "newJob" not in events

    def test_inactive_no_employment_recs(self, service):
        """Inactive user should not get employment-specific recommendations."""
        inp = _base_input(
            employment_status="inactive",
            monthly_net_income=0,
            children_count=0,
        )
        result = service.calculate(inp)
        events = _event_names(result)
        assert "firstJob" not in events
        assert "selfEmployment" not in events
        assert "jobLoss" not in events
        assert "newJob" not in events


# ══════════════════════════════════════════════════════════════════════════════
# TestNextStepsHousing — real estate recommendations (4 tests)
# ══════════════════════════════════════════════════════════════════════════════

class TestNextStepsHousing:
    """Real estate-based recommendation rules."""

    def test_no_real_estate_high_income_gets_purchase(self, service):
        """Non-owner with income >= 5000 should get housingPurchase."""
        inp = _base_input(has_real_estate=False, monthly_net_income=7000)
        result = service.calculate(inp)
        events = _event_names(result)
        assert "housingPurchase" in events
        step = _find_step(result, "housingPurchase")
        assert step.priority == 3
        assert step.route == "/mortgage/affordability"

    def test_no_real_estate_low_income_no_purchase(self, service):
        """Non-owner with income < 5000 should NOT get housingPurchase."""
        inp = _base_input(has_real_estate=False, monthly_net_income=4500)
        result = service.calculate(inp)
        events = _event_names(result)
        assert "housingPurchase" not in events

    def test_owner_gets_housing_sale(self, service):
        """Property owner should get housingSale recommendation."""
        inp = _base_input(has_real_estate=True)
        result = service.calculate(inp)
        events = _event_names(result)
        assert "housingSale" in events
        step = _find_step(result, "housingSale")
        assert step.priority == 4
        assert step.route == "/life-event/housing-sale"

    def test_owner_no_housing_purchase(self, service):
        """Property owner should NOT get housingPurchase."""
        inp = _base_input(has_real_estate=True, monthly_net_income=10000)
        result = service.calculate(inp)
        events = _event_names(result)
        assert "housingPurchase" not in events


# ══════════════════════════════════════════════════════════════════════════════
# TestNextStepsCanton — high-tax canton recommendations (3 tests)
# ══════════════════════════════════════════════════════════════════════════════

class TestNextStepsCanton:
    """Canton-based recommendation rules."""

    def test_high_tax_canton_ge_gets_canton_move(self, service):
        """Geneva (GE) resident should get cantonMove recommendation."""
        inp = _base_input(canton="GE")
        result = service.calculate(inp)
        events = _event_names(result)
        assert "cantonMove" in events
        step = _find_step(result, "cantonMove")
        assert step.priority == 4
        assert step.route == "/fiscal"
        assert "GE" in step.reason

    def test_all_high_tax_cantons_trigger(self, service):
        """All 6 high-tax cantons should trigger cantonMove."""
        for canton in HIGH_TAX_CANTONS:
            inp = _base_input(canton=canton)
            result = service.calculate(inp)
            events = _event_names(result)
            assert "cantonMove" in events, f"cantonMove missing for {canton}"

    def test_low_tax_canton_no_canton_move(self, service):
        """Low-tax cantons (ZG, SZ, NW, etc.) should NOT get cantonMove."""
        for canton in ["ZG", "SZ", "NW", "AI", "AR"]:
            inp = _base_input(canton=canton)
            result = service.calculate(inp)
            events = _event_names(result)
            assert "cantonMove" not in events, f"cantonMove should not appear for {canton}"


# ══════════════════════════════════════════════════════════════════════════════
# TestNextStepsCompliance — disclaimer, sources, max 5 steps (5 tests)
# ══════════════════════════════════════════════════════════════════════════════

class TestNextStepsCompliance:
    """Compliance and structural requirements."""

    def test_disclaimer_present(self, service):
        """Result must always include the correct disclaimer."""
        inp = _base_input()
        result = service.calculate(inp)
        assert result.disclaimer == DISCLAIMER
        assert "LSFin" in result.disclaimer
        assert "conseil financier" in result.disclaimer

    def test_sources_present(self, service):
        """Result must always include the correct sources."""
        inp = _base_input()
        result = service.calculate(inp)
        assert result.sources == SOURCES
        assert "LIFD" in result.sources
        assert "LPP" in result.sources
        assert "LAVS" in result.sources
        assert "CC art. 457ss" in result.sources
        assert "LSFin art. 3" in result.sources

    def test_max_five_steps(self, service):
        """Result must never contain more than 5 steps."""
        # Create a profile that triggers many rules
        inp = _base_input(
            age=56,
            civil_status="single",
            children_count=2,
            employment_status="employee",
            monthly_net_income=8000,
            canton="GE",
            has_debt=True,
            has_real_estate=True,
        )
        result = service.calculate(inp)
        assert len(result.steps) <= MAX_STEPS

    def test_steps_sorted_by_priority(self, service):
        """Steps must be sorted by priority (ascending: 1 first)."""
        inp = _base_input(
            has_debt=True,
            civil_status="concubinage",
            canton="GE",
        )
        result = service.calculate(inp)
        priorities = [s.priority for s in result.steps]
        assert priorities == sorted(priorities)

    def test_no_banned_words_in_output(self, service):
        """Output text must never contain banned words."""
        banned = [
            "garanti", "certain", "assure", "sans risque",
            "optimal", "meilleur", "parfait", "conseiller",
        ]
        # Test with a profile that generates many steps
        inp = _base_input(
            age=56,
            civil_status="concubinage",
            children_count=2,
            employment_status="employee",
            monthly_net_income=8000,
            canton="GE",
            has_debt=True,
            has_real_estate=True,
        )
        result = service.calculate(inp)
        all_text = result.disclaimer
        for step in result.steps:
            all_text += f" {step.title} {step.reason}"
        all_text_lower = all_text.lower()
        for word in banned:
            assert word not in all_text_lower, (
                f"Banned word '{word}' found in output text"
            )


# ══════════════════════════════════════════════════════════════════════════════
# Additional edge case tests (to reach 30+)
# ══════════════════════════════════════════════════════════════════════════════

class TestNextStepsEdgeCases:
    """Additional edge case tests."""

    def test_all_routes_are_valid(self, service):
        """All returned routes must exist in the ROUTE_MAP."""
        inp = _base_input(
            age=56,
            civil_status="concubinage",
            children_count=2,
            employment_status="employee",
            monthly_net_income=8000,
            canton="GE",
            has_debt=True,
        )
        result = service.calculate(inp)
        for step in result.steps:
            assert step.route in ROUTE_MAP.values(), (
                f"Route {step.route} not in ROUTE_MAP"
            )

    def test_all_life_events_are_valid(self, service):
        """All returned life_event values must be in LIFE_EVENTS."""
        inp = _base_input(
            age=56,
            civil_status="single",
            children_count=2,
            employment_status="employee",
            monthly_net_income=8000,
            canton="GE",
            has_debt=True,
            has_real_estate=True,
        )
        result = service.calculate(inp)
        for step in result.steps:
            assert step.life_event in LIFE_EVENTS, (
                f"life_event {step.life_event} not in LIFE_EVENTS"
            )

    def test_all_icons_are_valid(self, service):
        """All returned icon_name values must be in ICON_MAP."""
        inp = _base_input(
            age=56,
            civil_status="concubinage",
            employment_status="independent",
            canton="GE",
            has_debt=True,
        )
        result = service.calculate(inp)
        for step in result.steps:
            assert step.icon_name in ICON_MAP.values(), (
                f"icon {step.icon_name} not in ICON_MAP"
            )

    def test_disability_with_children(self, service):
        """User with children should get disability recommendation."""
        inp = _base_input(
            children_count=1,
            monthly_net_income=4000,  # Below 6000 threshold
        )
        result = service.calculate(inp)
        events = _event_names(result)
        assert "disability" in events
        step = _find_step(result, "disability")
        assert step.priority == 3
        assert step.route == "/simulator/disability-gap"

    def test_disability_with_high_income_no_children(self, service):
        """User with income > 6000 but no children should get disability."""
        inp = _base_input(
            children_count=0,
            monthly_net_income=7000,
        )
        result = service.calculate(inp)
        events = _event_names(result)
        assert "disability" in events

    def test_inheritance_age_50_with_children(self, service):
        """User aged 50+ with children should get inheritance."""
        inp = _base_input(age=52, children_count=2)
        result = service.calculate(inp)
        events = _event_names(result)
        assert "inheritance" in events
        step = _find_step(result, "inheritance")
        assert step.priority == 3

    def test_inheritance_under_50_no_recommendation(self, service):
        """User under 50 should NOT get inheritance recommendation."""
        inp = _base_input(age=49, children_count=3)
        result = service.calculate(inp)
        events = _event_names(result)
        assert "inheritance" not in events

    def test_priority_clamped_1_to_5(self, service):
        """All priorities must be between 1 and 5."""
        inp = _base_input(
            age=60,
            has_debt=True,
            employment_status="unemployed",
            canton="GE",
            children_count=3,
        )
        result = service.calculate(inp)
        for step in result.steps:
            assert 1 <= step.priority <= 5, (
                f"Priority {step.priority} out of range for {step.life_event}"
            )

    def test_no_duplicate_life_events(self, service):
        """Result should not contain duplicate life events."""
        inp = _base_input(
            age=56,
            civil_status="concubinage",
            children_count=2,
            employment_status="employee",
            monthly_net_income=8000,
            canton="GE",
            has_debt=True,
            has_real_estate=True,
        )
        result = service.calculate(inp)
        events = _event_names(result)
        assert len(events) == len(set(events)), (
            f"Duplicate events found: {events}"
        )

    def test_empty_profile_still_returns_result(self, service):
        """Minimal profile should still return a valid result."""
        inp = NextStepsInput(
            age=20,
            civil_status="single",
            children_count=0,
            employment_status="inactive",
            monthly_net_income=0,
            canton="ZG",
        )
        result = service.calculate(inp)
        assert isinstance(result, NextStepsResult)
        assert result.disclaimer == DISCLAIMER
        assert result.sources == SOURCES
        assert len(result.steps) <= MAX_STEPS

    def test_canton_case_insensitive(self, service):
        """Canton code should be case-insensitive for high-tax check."""
        inp = _base_input(canton="ge")
        result = service.calculate(inp)
        events = _event_names(result)
        assert "cantonMove" in events

    def test_income_boundary_5000_gets_housing(self, service):
        """Income exactly 5000 should trigger housingPurchase."""
        inp = _base_input(
            has_real_estate=False,
            monthly_net_income=5000,
        )
        result = service.calculate(inp)
        events = _event_names(result)
        assert "housingPurchase" in events

    def test_income_boundary_4999_no_housing(self, service):
        """Income below 5000 should NOT trigger housingPurchase."""
        inp = _base_input(
            has_real_estate=False,
            monthly_net_income=4999,
        )
        result = service.calculate(inp)
        events = _event_names(result)
        assert "housingPurchase" not in events
