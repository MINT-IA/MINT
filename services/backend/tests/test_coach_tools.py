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

from typing import Optional

from app.services.coach.coach_tools import (
    COACH_TOOLS,
    ROUTE_TO_SCREEN_INTENT_TAGS,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _find_tool(name: str) -> Optional[dict]:
    """Return the tool definition with the given name, or None."""
    return next((t for t in COACH_TOOLS if t["name"] == name), None)


BANNED_TERMS = [
    "garanti", "certain", "assuré", "sans risque",
    "optimal", "meilleur", "parfait",
    "tu devrais", "tu dois", "il faut que",
]


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

    def test_route_to_screen_has_optional_prefill_property(self):
        """prefill must be in properties but NOT in required — it is optional."""
        tool = _find_tool("route_to_screen")
        props = tool["input_schema"]["properties"]
        required = tool["input_schema"]["required"]
        # prefill must exist as a property
        assert "prefill" in props, "prefill property missing from route_to_screen schema"
        # prefill must be of type "object"
        assert props["prefill"]["type"] == "object", (
            "prefill property must be type 'object'"
        )
        # prefill must NOT be in required — it is optional
        assert "prefill" not in required, (
            "prefill must be optional (not in required list)"
        )
        # prefill must allow additional properties (open-ended key-value map)
        assert props["prefill"].get("additionalProperties") is True, (
            "prefill must have additionalProperties: true for open-ended maps"
        )

    def test_route_to_screen_prefill_description_mentions_profile_fields(self):
        """prefill description must mention CoachProfile field names."""
        tool = _find_tool("route_to_screen")
        desc = tool["input_schema"]["properties"]["prefill"]["description"]
        # Must mention at least one known CoachProfile field key
        profile_fields = ["avoirLppTotal", "salaireBrutMensuel", "canton"]
        has_field = any(f in desc for f in profile_fields)
        assert has_field, (
            f"prefill description should mention CoachProfile fields, got: {desc}"
        )

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
            "life_event_unemployment",
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
