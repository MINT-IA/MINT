"""
Tests for coach_tools.py — route_to_screen and COACH_TOOLS definitions.

Sprint S56+: route_to_screen tool addition.

Covers:
    - COACH_TOOLS list integrity (structure, required fields)
    - route_to_screen tool presence and schema correctness
    - Intent tag completeness
    - Compliance: no banned terms in descriptions

Run: cd services/backend && python3 -m pytest tests/test_coach_tools.py -v
"""

from collections import Counter
from pathlib import Path
import re
from typing import Optional

from app.services.coach.coach_tools import (
    COACH_TOOLS,
    ROUTE_TO_SCREEN_INTENT_TAGS,
    get_llm_tools,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _find_tool(name: str) -> Optional[dict]:
    """Return the tool definition with the given name, or None."""
    return next((t for t in COACH_TOOLS if t["name"] == name), None)


def _find_llm_tool(name: str) -> Optional[dict]:
    """Return the exact tool surface sent to the LLM."""
    return next((t for t in get_llm_tools() if t["name"] == name), None)


BANNED_TERMS = [
    "garanti", "certain", "assuré", "sans risque",
    "optimal", "meilleur", "parfait",
    "tu devrais", "tu dois", "il faut que",
]

REPO_ROOT = Path(__file__).resolve().parents[3]
SCREEN_REGISTRY_PATH = (
    REPO_ROOT
    / "apps"
    / "mobile"
    / "lib"
    / "services"
    / "navigation"
    / "screen_registry.dart"
)


def _flutter_registry_intent_tags() -> list[str]:
    """Read exact intent literals declared by MintScreenRegistry."""
    source = SCREEN_REGISTRY_PATH.read_text(encoding="utf-8")
    registry_start = source.index("class MintScreenRegistry extends ScreenRegistry")
    registry_source = source[registry_start:]
    return re.findall(
        r"^\s*intentTag:\s*'([a-z0-9_]+)',\s*$",
        registry_source,
        flags=re.MULTILINE,
    )


# ===========================================================================
# TestCoachToolsStructure — COACH_TOOLS list integrity
# ===========================================================================

class TestCoachToolsStructure:
    """Validate the top-level COACH_TOOLS list."""

    def test_coach_tools_is_list(self):
        assert isinstance(COACH_TOOLS, list)

    def test_coach_tools_not_empty(self):
        assert len(COACH_TOOLS) > 0

    def test_every_tool_has_name(self):
        for tool in COACH_TOOLS:
            assert "name" in tool, f"Tool missing 'name': {tool}"
            assert isinstance(tool["name"], str)
            assert len(tool["name"]) > 0

    def test_every_tool_has_description(self):
        for tool in COACH_TOOLS:
            assert "description" in tool, f"Tool '{tool.get('name')}' missing 'description'"
            assert isinstance(tool["description"], str)
            assert len(tool["description"]) > 10

    def test_every_tool_has_input_schema(self):
        for tool in COACH_TOOLS:
            assert "input_schema" in tool, f"Tool '{tool.get('name')}' missing 'input_schema'"
            schema = tool["input_schema"]
            assert schema.get("type") == "object"
            assert "properties" in schema
            assert "required" in schema

    def test_tool_names_are_unique(self):
        names = [t["name"] for t in COACH_TOOLS]
        assert len(names) == len(set(names)), "Duplicate tool names found"

    def test_required_fields_are_subset_of_properties(self):
        for tool in COACH_TOOLS:
            schema = tool["input_schema"]
            required = schema.get("required", [])
            properties = schema.get("properties", {})
            for field in required:
                assert field in properties, (
                    f"Tool '{tool['name']}': required field '{field}' "
                    f"not in properties"
                )


# ===========================================================================
# TestRouteToScreenTool — route_to_screen specific tests
# ===========================================================================

class TestRouteToScreenTool:
    """Validate the route_to_screen tool definition in detail."""

    def test_route_to_screen_exists_in_coach_tools(self):
        tool = _find_tool("route_to_screen")
        assert tool is not None, "route_to_screen not found in COACH_TOOLS"

    def test_route_to_screen_description_is_non_empty(self):
        tool = _find_tool("route_to_screen")
        assert len(tool["description"]) > 20

    def test_route_to_screen_has_intent_property(self):
        tool = _find_tool("route_to_screen")
        props = tool["input_schema"]["properties"]
        assert "intent" in props
        assert props["intent"]["type"] == "string"

    def test_route_to_screen_has_confidence_property(self):
        tool = _find_tool("route_to_screen")
        props = tool["input_schema"]["properties"]
        assert "confidence" in props
        assert props["confidence"]["type"] == "number"

    def test_route_to_screen_confidence_is_bounded(self):
        """The LLM contract rejects confidence values outside [0, 1]."""
        tool = _find_llm_tool("route_to_screen")
        confidence_schema = tool["input_schema"]["properties"]["confidence"]

        assert confidence_schema["minimum"] == 0
        assert confidence_schema["maximum"] == 1

    def test_route_to_screen_has_context_message_property(self):
        tool = _find_tool("route_to_screen")
        props = tool["input_schema"]["properties"]
        assert "context_message" in props
        assert props["context_message"]["type"] == "string"

    def test_route_to_screen_required_fields(self):
        tool = _find_tool("route_to_screen")
        required = tool["input_schema"]["required"]
        assert "intent" in required
        assert "confidence" in required
        assert "context_message" in required

    def test_route_to_screen_exactly_three_required_fields(self):
        tool = _find_tool("route_to_screen")
        required = tool["input_schema"]["required"]
        assert len(required) == 3

    def test_route_to_screen_llm_schema_is_identifier_only(self):
        """Navigation accepts intent metadata, never profile or financial payloads."""
        tool = _find_llm_tool("route_to_screen")
        schema = tool["input_schema"]
        expected_fields = {"intent", "confidence", "context_message"}

        assert set(schema["properties"]) == expected_fields
        assert set(schema["required"]) == expected_fields

    def test_route_to_screen_llm_schema_rejects_unknown_fields(self):
        """Unknown keys must fail closed instead of recreating a data channel."""
        tool = _find_llm_tool("route_to_screen")
        schema = tool["input_schema"]

        assert schema.get("additionalProperties") is False

    def test_route_to_screen_intent_description_lists_tags(self):
        """Intent description must mention that tags are registered."""
        tool = _find_tool("route_to_screen")
        intent_desc = tool["input_schema"]["properties"]["intent"]["description"]
        # The description should reference the intent tags concept
        assert "intent" in intent_desc.lower() or "tag" in intent_desc.lower()

    def test_route_to_screen_confidence_description_mentions_threshold(self):
        """Confidence description should guide the LLM on threshold values."""
        tool = _find_tool("route_to_screen")
        conf_desc = tool["input_schema"]["properties"]["confidence"]["description"]
        # Should mention at least one threshold value
        assert "0." in conf_desc or "0.5" in conf_desc or "0.8" in conf_desc

    def test_route_to_screen_context_message_mentions_educational(self):
        """context_message description must mention educational/non-prescriptive."""
        tool = _find_tool("route_to_screen")
        cm_desc = tool["input_schema"]["properties"]["context_message"]["description"]
        keywords = ["educational", "non-prescriptive", "educatif", "conditionnel"]
        has_keyword = any(kw.lower() in cm_desc.lower() for kw in keywords)
        assert has_keyword, (
            f"context_message description should mention educational/non-prescriptive "
            f"guidance, got: {cm_desc}"
        )

    def test_route_to_screen_description_mentions_readiness(self):
        """Tool description should mention that Flutter verifies readiness."""
        tool = _find_tool("route_to_screen")
        desc = tool["description"].lower()
        assert "readiness" in desc or "verify" in desc or "check" in desc

    def test_route_to_screen_description_no_banned_terms(self):
        """Tool description must not contain banned MINT compliance terms."""
        tool = _find_tool("route_to_screen")
        desc = tool["description"].lower()
        for term in BANNED_TERMS:
            assert term.lower() not in desc, (
                f"Banned term '{term}' found in route_to_screen description"
            )


# ===========================================================================
# TestIntentTags — ROUTE_TO_SCREEN_INTENT_TAGS completeness
# ===========================================================================

class TestIntentTags:
    """Validate the canonical intent tag list."""

    def test_intent_tags_is_list(self):
        assert isinstance(ROUTE_TO_SCREEN_INTENT_TAGS, list)

    def test_intent_tags_not_empty(self):
        assert len(ROUTE_TO_SCREEN_INTENT_TAGS) > 0

    def test_intent_tags_minimum_count(self):
        """At least 20 tags for the core MINT surfaces."""
        assert len(ROUTE_TO_SCREEN_INTENT_TAGS) >= 20

    def test_intent_tags_are_strings(self):
        for tag in ROUTE_TO_SCREEN_INTENT_TAGS:
            assert isinstance(tag, str), f"Tag is not a string: {tag!r}"

    def test_intent_tags_are_unique(self):
        assert len(ROUTE_TO_SCREEN_INTENT_TAGS) == len(set(ROUTE_TO_SCREEN_INTENT_TAGS))

    def test_intent_tags_no_spaces(self):
        """Tags use underscores, never spaces."""
        for tag in ROUTE_TO_SCREEN_INTENT_TAGS:
            assert " " not in tag, f"Tag contains a space: {tag!r}"

    def test_intent_tags_snake_case(self):
        """Tags must be lowercase snake_case."""
        for tag in ROUTE_TO_SCREEN_INTENT_TAGS:
            assert tag == tag.lower(), f"Tag is not lowercase: {tag!r}"

    def test_core_retirement_tag_present(self):
        assert "retirement_choice" in ROUTE_TO_SCREEN_INTENT_TAGS

    def test_core_life_event_tags_present(self):
        life_event_tags = [
            "life_event_divorce",
            "life_event_birth",
            "life_event_marriage",
            "life_event_job_loss",
            "life_event_first_job",
        ]
        for tag in life_event_tags:
            assert tag in ROUTE_TO_SCREEN_INTENT_TAGS, (
                f"Expected life event tag not found: {tag}"
            )

    def test_core_financial_tags_present(self):
        financial_tags = [
            "budget_overview",
            "tax_optimization_3a",
            "lpp_buyback",
            "disability_gap",
            "housing_purchase",
        ]
        for tag in financial_tags:
            assert tag in ROUTE_TO_SCREEN_INTENT_TAGS, (
                f"Expected financial tag not found: {tag}"
            )

    def test_every_route_intent_exists_exactly_once_in_flutter_registry(self):
        """Backend navigation intents must resolve to one canonical Flutter entry."""
        registry_counts = Counter(_flutter_registry_intent_tags())

        assert SCREEN_REGISTRY_PATH.is_file()
        for tag in ROUTE_TO_SCREEN_INTENT_TAGS:
            assert registry_counts[tag] == 1, (
                f"Backend route intent {tag!r} has {registry_counts[tag]} exact "
                "MintScreenRegistry entries"
            )

    def test_legacy_route_intent_aliases_are_absent(self):
        """Do not reintroduce backend-only aliases that Flutter cannot resolve."""
        legacy_tags = {
            "life_event_unemployment",
            "debt_check",
            "compound_interest",
            "leasing_simulation",
            "expert_consultation",
            "patrimoine_overview",
            "pillar_3a_overview",
        }

        assert legacy_tags.isdisjoint(ROUTE_TO_SCREEN_INTENT_TAGS)

    def test_intent_tags_referenced_in_tool_description(self):
        """The route_to_screen intent property description should list the tags."""
        tool = _find_tool("route_to_screen")
        intent_desc = tool["input_schema"]["properties"]["intent"]["description"]
        # At least some canonical tags should appear in the description
        tags_in_desc = [
            tag for tag in ROUTE_TO_SCREEN_INTENT_TAGS
            if tag in intent_desc
        ]
        assert len(tags_in_desc) >= 5, (
            f"Expected at least 5 intent tags to appear in the intent "
            f"property description, found {len(tags_in_desc)}: {tags_in_desc}"
        )


# ===========================================================================
# TestOtherTools — spot-checks for the other tools in COACH_TOOLS
# ===========================================================================

class TestOtherTools:
    """Spot-check the other tools shipped alongside route_to_screen."""

    def test_show_fact_card_exists(self):
        assert _find_tool("show_fact_card") is not None

    def test_show_budget_snapshot_exists(self):
        assert _find_tool("show_budget_snapshot") is not None

    def test_show_score_gauge_exists(self):
        assert _find_tool("show_score_gauge") is not None

    def test_ask_user_input_exists(self):
        assert _find_tool("ask_user_input") is not None

    def test_show_fact_card_has_source_field(self):
        tool = _find_tool("show_fact_card")
        assert "source" in tool["input_schema"]["properties"]

    def test_ask_user_input_requires_field_key(self):
        tool = _find_tool("ask_user_input")
        assert "field_key" in tool["input_schema"]["required"]


# ===========================================================================
# TestGenerateFinancialPlanTool — generate_financial_plan tool definition
# ===========================================================================

class TestGenerateFinancialPlanTool:
    """Validate the generate_financial_plan tool definition."""

    def test_generate_financial_plan_exists(self):
        tool = _find_tool("generate_financial_plan")
        assert tool is not None, "generate_financial_plan not found in COACH_TOOLS"

    def test_generate_financial_plan_category_is_write(self):
        tool = _find_tool("generate_financial_plan")
        assert tool["category"] == "write"

    def test_generate_financial_plan_has_goal_property(self):
        tool = _find_tool("generate_financial_plan")
        props = tool["input_schema"]["properties"]
        assert "goal" in props
        assert props["goal"]["type"] == "string"

    def test_generate_financial_plan_has_monthly_amount_property(self):
        tool = _find_tool("generate_financial_plan")
        props = tool["input_schema"]["properties"]
        assert "monthly_amount" in props
        assert props["monthly_amount"]["type"] == "number"

    def test_generate_financial_plan_has_milestones_property(self):
        tool = _find_tool("generate_financial_plan")
        props = tool["input_schema"]["properties"]
        assert "milestones" in props
        assert props["milestones"]["type"] == "array"

    def test_generate_financial_plan_has_projected_outcome_property(self):
        tool = _find_tool("generate_financial_plan")
        props = tool["input_schema"]["properties"]
        assert "projected_outcome" in props
        assert props["projected_outcome"]["type"] == "string"

    def test_generate_financial_plan_has_narrative_property(self):
        tool = _find_tool("generate_financial_plan")
        props = tool["input_schema"]["properties"]
        assert "narrative" in props
        assert props["narrative"]["type"] == "string"

    def test_generate_financial_plan_required_fields(self):
        tool = _find_tool("generate_financial_plan")
        required = tool["input_schema"]["required"]
        assert "goal" in required
        assert "narrative" in required

    def test_generate_financial_plan_not_internal(self):
        """generate_financial_plan is Flutter-bound, NOT in INTERNAL_TOOL_NAMES."""
        from app.services.coach.coach_tools import INTERNAL_TOOL_NAMES
        assert "generate_financial_plan" not in INTERNAL_TOOL_NAMES

    def test_generate_financial_plan_description_no_banned_terms(self):
        tool = _find_tool("generate_financial_plan")
        desc = tool["description"].lower()
        for term in BANNED_TERMS:
            assert term.lower() not in desc, (
                f"Banned term '{term}' found in generate_financial_plan description"
            )
