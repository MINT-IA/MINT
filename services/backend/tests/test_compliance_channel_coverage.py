"""Tests for ComplianceGuard coverage on all v2.0 output channels (backend).

Validates that the assembled system prompt:
  - Contains BIOGRAPHY_AWARENESS rules
  - Does NOT contain PII placeholders
  - Contains conditional language instructions
  - Contains never-cite-exact-amounts instructions

See: COMP-01, QA-06, QA-10, T-06-07 requirements.
"""

import pytest

from app.services.coach.claude_coach_service import (
    _BIOGRAPHY_AWARENESS,
    build_system_prompt,
)


class TestBiographyAwarenessInSystemPrompt:
    """Verify BIOGRAPHY_AWARENESS is present and correct in assembled prompt."""

    def test_assembled_prompt_contains_biography_awareness(self):
        prompt = build_system_prompt(ctx=None, language="fr")
        assert "BIOGRAPHY AWARENESS" in prompt

    def test_biography_awareness_contains_conditional_language(self):
        assert "conditionnel" in _BIOGRAPHY_AWARENESS.lower() or \
               "CONDITIONAL" in _BIOGRAPHY_AWARENESS

    def test_biography_awareness_contains_never_cite_instruction(self):
        assert "NEVER cite" in _BIOGRAPHY_AWARENESS or \
               "jamais citer" in _BIOGRAPHY_AWARENESS.lower()


class TestNoPiiInSystemPrompt:
    """Verify assembled system prompt contains zero PII placeholders."""

    def test_no_user_name_placeholder(self):
        prompt = build_system_prompt(ctx=None, language="fr")
        assert "{user_name}" not in prompt
        assert "{nom}" not in prompt

    def test_no_exact_salary_placeholder(self):
        prompt = build_system_prompt(ctx=None, language="fr")
        assert "{exact_salary}" not in prompt
        assert "{salaire_exact}" not in prompt

    def test_no_iban_placeholder(self):
        prompt = build_system_prompt(ctx=None, language="fr")
        assert "{iban}" not in prompt
        assert "{IBAN}" not in prompt

    def test_no_employer_placeholder(self):
        prompt = build_system_prompt(ctx=None, language="fr")
        assert "{employer}" not in prompt
        assert "{employeur}" not in prompt


class TestConditionalLanguageInstructions:
    """Verify system prompt mandates conditional language."""

    def test_prompt_contains_conditionnel_or_pourrait(self):
        prompt = build_system_prompt(ctx=None, language="fr")
        has_conditionnel = "conditionnel" in prompt.lower()
        has_pourrait = "pourrait" in prompt.lower()
        assert has_conditionnel or has_pourrait, (
            "System prompt must instruct coach to use conditional language"
        )

    def test_prompt_contains_never_cite_exact_amounts(self):
        prompt = build_system_prompt(ctx=None, language="fr")
        has_jamais = "jamais" in prompt.lower()
        has_never = "NEVER" in prompt
        assert has_jamais or has_never, (
            "System prompt must instruct coach to never cite exact amounts"
        )


class TestBannedTermsInPrompt:
    """Verify banned terms reminder is in system prompt."""

    def test_prompt_contains_banned_terms_list(self):
        prompt = build_system_prompt(ctx=None, language="fr")
        assert "garanti" in prompt.lower()
        assert "optimal" in prompt.lower()

    def test_prompt_contains_banned_prescriptive_language(self):
        prompt = build_system_prompt(ctx=None, language="fr")
        assert "tu devrais" in prompt.lower() or "tu dois" in prompt.lower()
