"""Tests for the Claude Coach Service — S57."""

from app.services.coach.claude_coach_service import build_system_prompt


class TestBuildSystemPrompt:
    """Test system prompt construction with budget data."""

    def test_basic_prompt_has_voice_pillars(self):
        prompt = build_system_prompt(first_name="Julien", age=49, canton="VS")
        assert "CALME" in prompt
        assert "PRECIS" in prompt
        assert "FIN" in prompt
        assert "RASSURANT" in prompt
        assert "NET" in prompt

    def test_prompt_includes_user_context(self):
        prompt = build_system_prompt(
            first_name="Julien", age=49, canton="VS",
            salary_annual=122207,
        )
        assert "Age : 49" in prompt
        assert "Canton : VS" in prompt

    def test_budget_vivant_section_present(self):
        prompt = build_system_prompt(
            first_name="Julien", age=49, canton="VS",
            present_free=2480, retirement_free=1340,
            budget_gap=1140, budget_confidence=67,
        )
        assert "BUDGET VIVANT" in prompt
        assert "2,480" in prompt or "2'480" in prompt or "2480" in prompt
        assert "1,340" in prompt or "1'340" in prompt or "1340" in prompt
        assert "1,140" in prompt or "1'140" in prompt or "1140" in prompt
        assert "67%" in prompt
        assert "CHF/mois" in prompt

    def test_budget_vivant_absent_when_no_data(self):
        prompt = build_system_prompt(first_name="Julien", age=49, canton="VS")
        assert "BUDGET VIVANT" not in prompt

    def test_missing_fields_detected(self):
        prompt = build_system_prompt()
        assert "DONNEES MANQUANTES" in prompt
        assert "name" in prompt
        assert "salary" in prompt
        assert "canton" in prompt

    def test_name_missing_when_default(self):
        prompt = build_system_prompt(first_name="utilisateur", age=49, canton="VS")
        assert "name" in prompt.lower()
        assert "DONNEES MANQUANTES" in prompt

    def test_no_missing_when_complete(self):
        prompt = build_system_prompt(
            first_name="Julien", age=49, canton="VS",
            salary_annual=122207,
        )
        assert "DONNEES MANQUANTES" not in prompt

    def test_financial_literacy_beginner(self):
        prompt = build_system_prompt(
            first_name="Julien", age=25,
            financial_literacy_level="beginner",
        )
        assert "NOVICE" in prompt

    def test_financial_literacy_advanced(self):
        prompt = build_system_prompt(
            first_name="Julien", age=55,
            financial_literacy_level="advanced",
        )
        assert "EXPERT" in prompt

    def test_coach_memory_injected(self):
        prompt = build_system_prompt(
            first_name="Julien", age=49, canton="VS",
            completed_actions=["pillar_3a"],
            declared_goals=["retraite"],
            last_cap_served="replacement_rate",
        )
        assert "pillar_3a" in prompt
        assert "retraite" in prompt
        assert "replacement_rate" in prompt
