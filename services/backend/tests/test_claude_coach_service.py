"""Tests — Phase 91 Wave 0 prompt block decomposition (zero behavior change).

Pins the contract that the legacy single-LLM path (`_BASE_SYSTEM_PROMPT`)
recomposes from the 5 named module-level building blocks in their original
order, producing a byte-identical string. Also asserts the
`_NARRATOR_BASE_SYSTEM_PROMPT` constant (Wave 2 destination, not yet wired)
omits the two extraction-related blocks.

These invariants protect against:
  - Accidental drift when Wave 1/2 wires the dual-LLM path
  - Regression on the legacy single-LLM behavior during the migration
  - Silent removal of the i18n switch (`_LANGUAGE_NAMES`)

Spec source: `.planning/phases/91-mvp-extractor-v2/91-00-PLAN.md` Task 0.1.
"""

from app.services.coach.claude_coach_service import (
    _BASE_SYSTEM_PROMPT,
    _EXTRACTION_DIRECTIVES_FOR_SINGLE_LLM,
    _LANGUAGE_NAMES,
    _NARRATOR_BASE_SYSTEM_PROMPT,
    _PROMPT_PART_MIDDLE,
    _PROMPT_PART_PREFIX,
    _PROMPT_PART_SUFFIX,
    _SAVE_INSIGHT_RULE_FOR_SINGLE_LLM,
)


def test_base_system_prompt_blocks():
    """Pin the byte-identity of the recomposed `_BASE_SYSTEM_PROMPT`.

    The legacy single-LLM prompt MUST equal the concatenation of the 5
    named building blocks in their original order. Any drift here would
    silently change production system-prompt behavior.
    """
    expected = (
        _PROMPT_PART_PREFIX
        + _SAVE_INSIGHT_RULE_FOR_SINGLE_LLM
        + _PROMPT_PART_MIDDLE
        + _EXTRACTION_DIRECTIVES_FOR_SINGLE_LLM
        + _PROMPT_PART_SUFFIX
    )
    assert _BASE_SYSTEM_PROMPT == expected, (
        "Refactor drift: _BASE_SYSTEM_PROMPT no longer equals the recomposed "
        "5-part assembly. Wave 0 invariant violated."
    )


def test_extraction_block_only_in_legacy_prompt():
    """« EXTRACTION DE PROFIL » must live in the legacy prompt + named block,
    never in the narrator body (Wave 2 destination)."""
    assert "EXTRACTION DE PROFIL" in _EXTRACTION_DIRECTIVES_FOR_SINGLE_LLM
    assert "EXTRACTION DE PROFIL" in _BASE_SYSTEM_PROMPT
    assert "EXTRACTION DE PROFIL" not in _NARRATOR_BASE_SYSTEM_PROMPT


def test_save_insight_rule_only_in_legacy_prompt():
    """« TOUJOURS appeler save_insight » mandate must live in the legacy
    prompt + named block, never in the narrator body."""
    assert "TOUJOURS appeler save_insight" in _SAVE_INSIGHT_RULE_FOR_SINGLE_LLM
    assert "TOUJOURS appeler save_insight" in _BASE_SYSTEM_PROMPT
    assert "TOUJOURS appeler save_insight" not in _NARRATOR_BASE_SYSTEM_PROMPT


def test_language_names_unchanged():
    """The i18n switch is owned by the narrator path — must stay intact
    across the refactor (CLAUDE.md §1 #5 i18n required)."""
    assert _LANGUAGE_NAMES == {
        "fr": "français",
        "de": "Deutsch (Hochdeutsch)",
        "en": "English",
        "it": "italiano",
        "es": "español",
        "pt": "português",
    }


def test_narrator_prompt_preserves_format_slots():
    """The narrator body keeps the same `{regional_identity}` / `{routing_rules}`
    / `{banned_terms}` format slots as the legacy prompt so a future
    `.format(...)` call site (Wave 2) works identically.
    """
    for slot in (
        "{banned_terms}",
        "{regional_identity}",
        "{lifecycle_awareness}",
        "{plan_awareness}",
        "{check_in_protocol}",
        "{safe_mode_protocol}",
        "{routing_rules}",
    ):
        assert slot in _NARRATOR_BASE_SYSTEM_PROMPT, (
            f"Narrator prompt is missing format slot {slot!r} — "
            f"Wave 2 .format(...) call site will break."
        )
