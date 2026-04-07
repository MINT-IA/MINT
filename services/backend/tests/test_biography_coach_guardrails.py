"""Tests for BIOGRAPHY AWARENESS guardrails in coach system prompt.

Validates that the coach system prompt includes all required rules
for handling biography data: conditional language, source dating,
approximate amounts, stale data handling, and privacy constraints.

See: BIO-04, BIO-07, COMP-02, T-03-06 requirements.
"""


from app.services.coach.claude_coach_service import (
    _BIOGRAPHY_AWARENESS,
    build_system_prompt,
)


class TestBiographyAwarenessContent:
    """Verify _BIOGRAPHY_AWARENESS constant contains all required rules."""

    def test_max_one_biography_reference_rule(self):
        assert "Maximum 1 biography reference per response" in _BIOGRAPHY_AWARENESS

    def test_always_date_source_rule(self):
        assert "ALWAYS date your source" in _BIOGRAPHY_AWARENESS

    def test_conditional_language_rule(self):
        assert "CONDITIONAL language" in _BIOGRAPHY_AWARENESS

    def test_donnee_ancienne_handling(self):
        assert "DONNEE ANCIENNE" in _BIOGRAPHY_AWARENESS

    def test_never_cite_rule(self):
        assert "NEVER cite" in _BIOGRAPHY_AWARENESS
        # Must mention specific prohibited items
        assert "exact amounts" in _BIOGRAPHY_AWARENESS
        assert "employer names" in _BIOGRAPHY_AWARENESS

    def test_approximate_amounts_examples(self):
        """Verify the prompt shows correct vs incorrect amount examples."""
        assert "un peu moins de 100k" in _BIOGRAPHY_AWARENESS
        # Exact amounts shown as anti-patterns
        assert "122'207" in _BIOGRAPHY_AWARENESS or "95'000" in _BIOGRAPHY_AWARENESS


class TestBiographyAwarenessInPrompt:
    """Verify biography awareness is injected into the assembled system prompt."""

    def test_system_prompt_includes_biography_awareness(self):
        prompt = build_system_prompt(ctx=None, language="fr")
        assert "BIOGRAPHY AWARENESS" in prompt

    def test_system_prompt_includes_conditional_language_rule(self):
        prompt = build_system_prompt(ctx=None, language="fr")
        assert "CONDITIONAL language" in prompt

    def test_system_prompt_includes_donnee_ancienne(self):
        prompt = build_system_prompt(ctx=None, language="fr")
        assert "DONNEE ANCIENNE" in prompt

    def test_system_prompt_biography_after_anti_patterns(self):
        """Biography awareness should appear after anti-patterns section."""
        prompt = build_system_prompt(ctx=None, language="fr")
        anti_patterns_pos = prompt.find("ANTI-PATTERNS")
        biography_pos = prompt.find("BIOGRAPHY AWARENESS")
        assert anti_patterns_pos > 0
        assert biography_pos > 0
        assert biography_pos > anti_patterns_pos
