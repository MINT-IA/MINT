"""
Tests for EducationalContentService — Contenu pedagogique pour les inserts du wizard.

Test categories:
    - TestGetInsert: get_insert() for all 16 question IDs (18 tests)
    - TestGetAllInserts: get_all_inserts() correctness (2 tests)
    - TestGetInsertsByPhase: filtering by phase (3 tests)
    - TestInsertCompleteness: all inserts have required fields (5 tests)
    - TestCompliance: no banned words, disclaimer, sources (5 tests)

Total: 33 tests
"""

import pytest

from app.services.educational_content_service import (
    InsertContent,
    EducationalContentService,
    DISCLAIMER,
    BANNED_TERMS,
)


# ══════════════════════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def service():
    return EducationalContentService()


# All 16 question IDs
ALL_QUESTION_IDS = [
    # Original 8
    "q_financial_stress_check",
    "q_has_pension_fund",
    "q_has_3a",
    "q_3a_annual_amount",
    "q_mortgage_type",
    "q_has_consumer_credit",
    "q_has_leasing",
    "q_emergency_fund",
    # New 8 (S25)
    "q_civil_status",
    "q_employment_status",
    "q_housing_status",
    "q_canton",
    "q_lpp_buyback_available",
    "q_3a_accounts_count",
    "q_has_investments",
    "q_real_estate_project",
]


# ══════════════════════════════════════════════════════════════════════════════
# TestGetInsert — get_insert() for each question ID
# ══════════════════════════════════════════════════════════════════════════════

class TestGetInsert:
    """Test get_insert() returns correct data for each of the 16 question IDs."""

    @pytest.mark.parametrize("question_id", ALL_QUESTION_IDS)
    def test_get_insert_returns_insert_for_each_id(self, service, question_id):
        """Each known question ID must return an InsertContent."""
        insert = service.get_insert(question_id)
        assert insert is not None
        assert isinstance(insert, InsertContent)
        assert insert.question_id == question_id

    def test_get_insert_returns_none_for_unknown_id(self, service):
        """Unknown question IDs must return None."""
        assert service.get_insert("q_does_not_exist") is None

    def test_get_insert_returns_none_for_empty_string(self, service):
        """Empty string must return None."""
        assert service.get_insert("") is None


# ══════════════════════════════════════════════════════════════════════════════
# TestGetAllInserts — get_all_inserts()
# ══════════════════════════════════════════════════════════════════════════════

class TestGetAllInserts:
    """Test get_all_inserts() returns all 16 inserts."""

    def test_all_inserts_count(self, service):
        """Must return exactly 16 inserts."""
        all_inserts = service.get_all_inserts()
        assert len(all_inserts) == 16

    def test_all_inserts_unique_ids(self, service):
        """All question IDs must be unique."""
        all_inserts = service.get_all_inserts()
        ids = [insert.question_id for insert in all_inserts]
        assert len(set(ids)) == len(ids)


# ══════════════════════════════════════════════════════════════════════════════
# TestGetInsertsByPhase — filtering by phase
# ══════════════════════════════════════════════════════════════════════════════

class TestGetInsertsByPhase:
    """Test get_inserts_by_phase() returns correct counts."""

    def test_niveau_0_count(self, service):
        """Niveau 0 should have exactly 1 insert (q_financial_stress_check)."""
        inserts = service.get_inserts_by_phase("Niveau 0")
        assert len(inserts) == 1
        assert inserts[0].question_id == "q_financial_stress_check"

    def test_niveau_1_count(self, service):
        """Niveau 1 should have exactly 11 inserts."""
        inserts = service.get_inserts_by_phase("Niveau 1")
        assert len(inserts) == 11

    def test_niveau_2_count(self, service):
        """Niveau 2 should have exactly 4 inserts."""
        inserts = service.get_inserts_by_phase("Niveau 2")
        assert len(inserts) == 4

    def test_unknown_phase_returns_empty(self, service):
        """Unknown phase must return empty list."""
        inserts = service.get_inserts_by_phase("Niveau 99")
        assert inserts == []


# ══════════════════════════════════════════════════════════════════════════════
# TestInsertCompleteness — all inserts have required fields
# ══════════════════════════════════════════════════════════════════════════════

class TestInsertCompleteness:
    """Test that all inserts have non-empty required fields."""

    @pytest.mark.parametrize("question_id", ALL_QUESTION_IDS)
    def test_insert_has_non_empty_disclaimer(self, service, question_id):
        """Every insert must have a non-empty disclaimer."""
        insert = service.get_insert(question_id)
        assert insert is not None
        assert len(insert.disclaimer) > 10

    @pytest.mark.parametrize("question_id", ALL_QUESTION_IDS)
    def test_insert_has_non_empty_sources(self, service, question_id):
        """Every insert must have at least 1 source."""
        insert = service.get_insert(question_id)
        assert insert is not None
        assert len(insert.sources) >= 1

    @pytest.mark.parametrize("question_id", ALL_QUESTION_IDS)
    def test_insert_has_non_empty_chiffre_choc(self, service, question_id):
        """Every insert must have a non-empty chiffre_choc."""
        insert = service.get_insert(question_id)
        assert insert is not None
        assert len(insert.chiffre_choc) > 10

    @pytest.mark.parametrize("question_id", ALL_QUESTION_IDS)
    def test_insert_has_at_least_2_learning_goals(self, service, question_id):
        """Every insert must have at least 2 learning goals."""
        insert = service.get_insert(question_id)
        assert insert is not None
        assert len(insert.learning_goals) >= 2, (
            f"{question_id} has only {len(insert.learning_goals)} learning goals"
        )

    @pytest.mark.parametrize("question_id", ALL_QUESTION_IDS)
    def test_insert_has_valid_action_route(self, service, question_id):
        """Every action_route must start with /."""
        insert = service.get_insert(question_id)
        assert insert is not None
        assert insert.action_route.startswith("/"), (
            f"{question_id} action_route '{insert.action_route}' does not start with /"
        )


# ══════════════════════════════════════════════════════════════════════════════
# TestCompliance — no banned words, disclaimer mentions educatif + LSFin
# ══════════════════════════════════════════════════════════════════════════════

class TestCompliance:
    """Test compliance with MINT rules: no banned terms, disclaimer, sources."""

    @pytest.mark.parametrize("question_id", ALL_QUESTION_IDS)
    def test_no_banned_words_in_chiffre_choc(self, service, question_id):
        """chiffre_choc must not contain any banned terms."""
        insert = service.get_insert(question_id)
        assert insert is not None
        text = insert.chiffre_choc.lower()
        for term in BANNED_TERMS:
            assert term not in text, (
                f"{question_id} chiffre_choc contains banned term '{term}'"
            )

    @pytest.mark.parametrize("question_id", ALL_QUESTION_IDS)
    def test_no_banned_words_in_learning_goals(self, service, question_id):
        """learning_goals must not contain any banned terms."""
        insert = service.get_insert(question_id)
        assert insert is not None
        for goal in insert.learning_goals:
            text = goal.lower()
            for term in BANNED_TERMS:
                assert term not in text, (
                    f"{question_id} learning goal contains banned term '{term}': {goal}"
                )

    @pytest.mark.parametrize("question_id", ALL_QUESTION_IDS)
    def test_no_banned_words_in_title(self, service, question_id):
        """title must not contain any banned terms."""
        insert = service.get_insert(question_id)
        assert insert is not None
        text = insert.title.lower()
        for term in BANNED_TERMS:
            assert term not in text, (
                f"{question_id} title contains banned term '{term}'"
            )

    def test_disclaimer_mentions_educatif(self, service):
        """The shared disclaimer must mention 'educatif'."""
        assert "educatif" in DISCLAIMER.lower()

    def test_disclaimer_mentions_lsfin(self, service):
        """The shared disclaimer must mention 'LSFin'."""
        assert "lsfin" in DISCLAIMER.lower()

    @pytest.mark.parametrize("question_id", ALL_QUESTION_IDS)
    def test_sources_are_swiss_law_references(self, service, question_id):
        """Each source must reference a known Swiss legal framework."""
        known_prefixes = [
            "LPP", "LAVS", "OPP", "LIFD", "LHID", "CC ", "CO ",
            "LSFin", "FINMA", "LAA", "LACI", "LCC", "LPart",
            "ASB", "Bonne pratique", "Lois cantonales", "OFS",
        ]
        insert = service.get_insert(question_id)
        assert insert is not None
        for source in insert.sources:
            matches = any(source.startswith(prefix) for prefix in known_prefixes)
            assert matches, (
                f"{question_id} source '{source}' does not match any known Swiss law prefix"
            )

    @pytest.mark.parametrize("question_id", ALL_QUESTION_IDS)
    def test_no_banned_words_in_action_label(self, service, question_id):
        """action_label must not contain any banned terms."""
        insert = service.get_insert(question_id)
        assert insert is not None
        text = insert.action_label.lower()
        for term in BANNED_TERMS:
            assert term not in text, (
                f"{question_id} action_label contains banned term '{term}'"
            )

    @pytest.mark.parametrize("question_id", ALL_QUESTION_IDS)
    def test_no_banned_words_in_safe_mode(self, service, question_id):
        """safe_mode must not contain any banned terms."""
        insert = service.get_insert(question_id)
        assert insert is not None
        text = insert.safe_mode.lower()
        for term in BANNED_TERMS:
            assert term not in text, (
                f"{question_id} safe_mode contains banned term '{term}'"
            )


# ══════════════════════════════════════════════════════════════════════════════
# TestPhaseValues — all phases are valid
# ══════════════════════════════════════════════════════════════════════════════

class TestPhaseValues:
    """Test that all inserts have valid phase values."""

    VALID_PHASES = {"Niveau 0", "Niveau 1", "Niveau 2"}

    @pytest.mark.parametrize("question_id", ALL_QUESTION_IDS)
    def test_insert_has_valid_phase(self, service, question_id):
        """Every insert must have a phase in the allowed set."""
        insert = service.get_insert(question_id)
        assert insert is not None
        assert insert.phase in self.VALID_PHASES, (
            f"{question_id} has unknown phase '{insert.phase}'"
        )

    def test_total_phase_distribution(self, service):
        """Phase distribution: 1 Niveau 0 + 11 Niveau 1 + 4 Niveau 2 = 16."""
        all_inserts = service.get_all_inserts()
        phase_counts = {}
        for insert in all_inserts:
            phase_counts[insert.phase] = phase_counts.get(insert.phase, 0) + 1
        assert phase_counts.get("Niveau 0", 0) == 1
        assert phase_counts.get("Niveau 1", 0) == 11
        assert phase_counts.get("Niveau 2", 0) == 4
