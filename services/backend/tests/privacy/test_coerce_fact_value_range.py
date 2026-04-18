"""Tests for _coerce_fact_value birth-year range check — Wave B-minimal B6.

Context: the save_fact tool in coach_chat.py accepts a `birthYear` /
`spouseBirthYear` key and persists the coerced value directly into
ProfileModel.data. Before B6-minimal, there was NO range check — an LLM
hallucination (`birthYear=2099`) or user typo persisted silently. The
mobile `profile.age` getter then clamped to 0 for downstream logic,
which silently corrupted every age-dependent calculation.

Panel adversaire BUG 4 + panel archi A3 mandated a range check in
_coerce_fact_value itself so invalid values are rejected BEFORE they
reach the DB.

Range: [1900, currentYear+1]. currentYear+1 tolerates a late-year
timezone edge (January first-of-year submission from a previous-year
birthday).
"""
from datetime import datetime

from app.api.v1.endpoints.coach_chat import _coerce_fact_value


class TestBirthYearRange:
    def test_valid_working_age_birth_year_accepted(self):
        assert _coerce_fact_value("birthYear", 1977) == 1977.0
        assert _coerce_fact_value("birthYear", 1982) == 1982.0

    def test_future_birth_year_rejected(self):
        # Adversarial scenario: Claude hallucinates or user types a
        # future year. Must be rejected, not silently clamped downstream.
        current_year = datetime.now().year
        assert _coerce_fact_value("birthYear", current_year + 5) is None
        assert _coerce_fact_value("birthYear", 2099) is None
        assert _coerce_fact_value("birthYear", 3000) is None

    def test_near_future_tolerance(self):
        # currentYear + 1 is accepted (timezone edge + late-year
        # reporting of January birthdays).
        current_year = datetime.now().year
        assert _coerce_fact_value("birthYear", current_year + 1) is not None

    def test_too_old_birth_year_rejected(self):
        # No living user was born before 1900 for our fintech purposes.
        assert _coerce_fact_value("birthYear", 1800) is None
        assert _coerce_fact_value("birthYear", 1899) is None

    def test_boundary_1900_accepted(self):
        # 1900 is the inclusive lower bound.
        assert _coerce_fact_value("birthYear", 1900) == 1900.0

    def test_spouse_birth_year_same_range(self):
        # spouseBirthYear must apply the same range check.
        assert _coerce_fact_value("spouseBirthYear", 2099) is None
        assert _coerce_fact_value("spouseBirthYear", 1800) is None
        assert _coerce_fact_value("spouseBirthYear", 1982) == 1982.0

    def test_string_birth_year_with_thousand_separator_rejected(self):
        # '2099 is a year typo with Swiss apostrophe — range check still
        # fires after numeric coercion.
        result = _coerce_fact_value("birthYear", "'2099")
        assert result is None

    def test_non_year_numeric_keys_unchanged(self):
        # The range check is scoped to birthYear / spouseBirthYear.
        # Other numeric keys (income, LPP, 3a) must not be range-checked
        # by this specific helper — their own validation lives elsewhere.
        assert _coerce_fact_value("incomeNetMonthly", 7600) == 7600.0
        assert _coerce_fact_value("avoirLpp", 70377) == 70377.0
        assert _coerce_fact_value("pillar3aBalance", 32000) == 32000.0
        # Sanity: very large salary is not rejected by birthYear check
        # (it's not a year key).
        assert _coerce_fact_value("incomeGrossYearly", 2099) == 2099.0
