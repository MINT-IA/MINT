"""Tests for the explain_concept tool + registry-backed handler (WS-B, Plan 05).

Phase: mint-grounded-coach-m1 / Plan 05 (Task 1).

The explain_concept tool is the grounded-retrieval entry point for definitions:
the LLM is no longer allowed to define a regulated Swiss concept from its weights.
When invoked, the BACKEND resolves concept_key → ConceptPage in CONCEPT_REGISTRY
(Plan 04) and returns the curated canonical_fr + source as the tool_result — there
is no LLM paraphrase of the definition itself (audit 04 §3.b).

These tests pin:
    - the tool is advertised to the LLM (present in get_llm_tools()),
    - its input_schema constrains concept_key to the registry keys (enum, closed-world),
    - the handler returns the canonical rachat_lpp page text + its source,
    - an unknown concept_key returns a structured "not in registry" result
      (never invents a definition),
    - the returned page text carries no banned LSFin term (CLAUDE.md TOP rule 1).
"""

from __future__ import annotations

from app.services.coach.coach_tools import (
    COACH_TOOLS,
    get_llm_tools,
    handle_explain_concept,
)
from app.services.coach.concept_registry import CONCEPT_REGISTRY


# Banned LSFin terms (CLAUDE.md TOP rule 1) — the registry page the handler
# returns is read verbatim by the user, so it must be clean.
_BANNED_TERMS = (
    "garanti",
    "optimal",
    "meilleur",
    "certain",
    "assuré",
    "sans risque",
    "parfait",
)


class TestExplainConceptToolDefinition:
    """The tool is advertised and closed-world over the registry keys."""

    def test_explain_concept_present_in_llm_tools(self):
        names = {t.get("name") for t in get_llm_tools()}
        assert "explain_concept" in names

    def test_explain_concept_present_in_coach_tools(self):
        names = {t.get("name") for t in COACH_TOOLS}
        assert "explain_concept" in names

    def test_input_schema_requires_concept_key(self):
        tool = next(t for t in COACH_TOOLS if t.get("name") == "explain_concept")
        schema = tool["input_schema"]
        assert "concept_key" in schema["properties"]
        assert schema["required"] == ["concept_key"]

    def test_concept_key_enum_is_the_registry_keys(self):
        """The enum is the closed world — exactly the registry keys, no more."""
        tool = next(t for t in COACH_TOOLS if t.get("name") == "explain_concept")
        enum = tool["input_schema"]["properties"]["concept_key"].get("enum")
        assert enum is not None, "concept_key must be an enum over the registry keys"
        assert set(enum) == set(CONCEPT_REGISTRY.keys())

    def test_description_forces_grounded_definition(self):
        tool = next(t for t in COACH_TOOLS if t.get("name") == "explain_concept")
        desc = tool["description"].lower()
        # The description must steer the LLM to use this for definitions of
        # regulated concepts rather than defining from memory.
        assert "defin" in desc or "définir" in desc or "concept" in desc


class TestExplainConceptHandler:
    """The handler returns the curated page text — no LLM paraphrase."""

    def test_returns_canonical_rachat_lpp_page(self):
        result = handle_explain_concept({"concept_key": "rachat_lpp"})
        page = CONCEPT_REGISTRY["rachat_lpp"]
        # The handler returns the canonical definition verbatim and its source.
        assert page.canonical_fr in result
        assert page.source_title in result

    def test_returns_source_for_every_registry_concept(self):
        for key, page in CONCEPT_REGISTRY.items():
            result = handle_explain_concept({"concept_key": key})
            assert page.canonical_fr in result, f"{key}: canonical text missing"
            assert page.source_title in result, f"{key}: source missing"

    def test_unknown_key_returns_not_found_shape(self):
        result = handle_explain_concept({"concept_key": "definitely_not_a_concept"})
        lowered = result.lower()
        # Structured "not in registry" — never invents a definition.
        assert "registre" in lowered or "registry" in lowered or "pas" in lowered
        # It must NOT leak a fabricated definition (no canonical of any page).
        for page in CONCEPT_REGISTRY.values():
            assert page.canonical_fr not in result

    def test_missing_concept_key_returns_not_found_shape(self):
        result = handle_explain_concept({})
        lowered = result.lower()
        assert "registre" in lowered or "registry" in lowered or "pas" in lowered

    def test_returned_text_has_no_banned_term(self):
        for key in CONCEPT_REGISTRY:
            result = handle_explain_concept({"concept_key": key})
            lowered = result.lower()
            for term in _BANNED_TERMS:
                assert term not in lowered, f"{key}: banned term '{term}' in page text"
