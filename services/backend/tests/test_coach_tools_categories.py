"""
Tests for coach_tools.py — ToolCategory, access_level metadata, write tools,
and access-control helpers.

Covers:
    - Every tool has a 'category' field matching a valid ToolCategory value
    - Every tool has an 'access_level' field
    - get_tools_by_category() filters correctly for each category
    - get_read_only_tools() excludes write tools
    - The 3 new write tools (set_goal, mark_step_completed, save_insight) exist
      with correct schemas, required fields, and user_scoped access
    - All write tools have 'user_scoped' access_level
    - Tool names are unique across COACH_TOOLS
    - ToolCategory enum has exactly the 4 expected values

Run: cd services/backend && python3 -m pytest tests/test_coach_tools_categories.py -v
"""

from typing import Optional

from app.services.coach.coach_tools import (
    COACH_TOOLS,
    ToolCategory,
    get_read_only_tools,
    get_tools_by_category,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _find_tool(name: str) -> Optional[dict]:
    """Return the tool definition with the given name, or None."""
    return next((t for t in COACH_TOOLS if t["name"] == name), None)


VALID_CATEGORIES = {c.value for c in ToolCategory}
VALID_ACCESS_LEVELS = {"user_scoped", "admin_scoped", "internal"}


# ===========================================================================
# TestToolCategoryEnum
# ===========================================================================


class TestToolCategoryEnum:
    """Validate the ToolCategory enum itself."""

    def test_navigate_value(self):
        assert ToolCategory.NAVIGATE.value == "navigate"

    def test_read_value(self):
        assert ToolCategory.READ.value == "read"

    def test_write_value(self):
        assert ToolCategory.WRITE.value == "write"

    def test_search_value(self):
        assert ToolCategory.SEARCH.value == "search"

    def test_exactly_four_categories(self):
        assert len(list(ToolCategory)) == 4

    def test_is_str_enum(self):
        # ToolCategory must be a str subclass so it JSON-serialises cleanly
        assert isinstance(ToolCategory.READ, str)


# ===========================================================================
# TestToolMetadataFields — every tool carries category + access_level
# ===========================================================================


class TestToolMetadataFields:
    """Every tool in COACH_TOOLS must carry category and access_level."""

    def test_every_tool_has_category(self):
        for tool in COACH_TOOLS:
            assert "category" in tool, (
                f"Tool '{tool.get('name')}' is missing 'category'"
            )

    def test_every_tool_category_is_valid(self):
        for tool in COACH_TOOLS:
            assert tool["category"] in VALID_CATEGORIES, (
                f"Tool '{tool.get('name')}' has unknown category '{tool['category']}'"
            )

    def test_every_tool_has_access_level(self):
        for tool in COACH_TOOLS:
            assert "access_level" in tool, (
                f"Tool '{tool.get('name')}' is missing 'access_level'"
            )

    def test_every_tool_access_level_is_valid(self):
        for tool in COACH_TOOLS:
            assert tool["access_level"] in VALID_ACCESS_LEVELS, (
                f"Tool '{tool.get('name')}' has unknown access_level "
                f"'{tool['access_level']}'"
            )

    def test_tool_names_are_unique(self):
        names = [t["name"] for t in COACH_TOOLS]
        assert len(names) == len(set(names)), (
            f"Duplicate tool names: {[n for n in names if names.count(n) > 1]}"
        )


# ===========================================================================
# TestGetToolsByCategory — filtering helper
# ===========================================================================


class TestGetToolsByCategory:
    """Validate get_tools_by_category() for each category."""

    def test_navigate_category_returns_route_to_screen(self):
        tools = get_tools_by_category(ToolCategory.NAVIGATE)
        names = [t["name"] for t in tools]
        assert "route_to_screen" in names

    def test_read_category_returns_show_tools(self):
        tools = get_tools_by_category(ToolCategory.READ)
        names = [t["name"] for t in tools]
        assert "show_fact_card" in names
        assert "show_budget_snapshot" in names
        assert "show_score_gauge" in names
        assert "ask_user_input" in names

    def test_write_category_returns_write_tools(self):
        tools = get_tools_by_category(ToolCategory.WRITE)
        names = [t["name"] for t in tools]
        assert "set_goal" in names
        assert "mark_step_completed" in names
        assert "save_insight" in names

    def test_search_category_returns_retrieve_memories(self):
        tools = get_tools_by_category(ToolCategory.SEARCH)
        names = [t["name"] for t in tools]
        assert "retrieve_memories" in names

    def test_every_result_matches_requested_category(self):
        for cat in ToolCategory:
            for tool in get_tools_by_category(cat):
                assert tool["category"] == cat.value, (
                    f"Tool '{tool['name']}' returned for {cat} but has "
                    f"category '{tool['category']}'"
                )

    def test_write_category_excludes_navigate(self):
        tools = get_tools_by_category(ToolCategory.WRITE)
        names = [t["name"] for t in tools]
        assert "route_to_screen" not in names

    def test_navigate_category_excludes_write_tools(self):
        tools = get_tools_by_category(ToolCategory.NAVIGATE)
        names = [t["name"] for t in tools]
        assert "set_goal" not in names
        assert "save_insight" not in names


# ===========================================================================
# TestGetReadOnlyTools — access control helper
# ===========================================================================


class TestGetReadOnlyTools:
    """Validate get_read_only_tools() excludes all write tools."""

    def test_excludes_set_goal(self):
        names = [t["name"] for t in get_read_only_tools()]
        assert "set_goal" not in names

    def test_excludes_mark_step_completed(self):
        names = [t["name"] for t in get_read_only_tools()]
        assert "mark_step_completed" not in names

    def test_excludes_save_insight(self):
        names = [t["name"] for t in get_read_only_tools()]
        assert "save_insight" not in names

    def test_includes_show_fact_card(self):
        names = [t["name"] for t in get_read_only_tools()]
        assert "show_fact_card" in names

    def test_includes_route_to_screen(self):
        names = [t["name"] for t in get_read_only_tools()]
        assert "route_to_screen" in names

    def test_includes_retrieve_memories(self):
        names = [t["name"] for t in get_read_only_tools()]
        assert "retrieve_memories" in names

    def test_no_write_tool_in_result(self):
        for tool in get_read_only_tools():
            assert tool.get("category") != "write", (
                f"Write tool '{tool['name']}' leaked into read-only set"
            )

    def test_count_less_than_total(self):
        assert len(get_read_only_tools()) < len(COACH_TOOLS)


# ===========================================================================
# TestWriteTools — the 3 new write tools in detail
# ===========================================================================


class TestSetGoalTool:
    """Validate set_goal tool definition."""

    def test_set_goal_exists(self):
        assert _find_tool("set_goal") is not None

    def test_set_goal_category_is_write(self):
        assert _find_tool("set_goal")["category"] == "write"

    def test_set_goal_access_level_is_user_scoped(self):
        assert _find_tool("set_goal")["access_level"] == "user_scoped"

    def test_set_goal_has_goal_intent_tag_property(self):
        props = _find_tool("set_goal")["input_schema"]["properties"]
        assert "goal_intent_tag" in props
        assert props["goal_intent_tag"]["type"] == "string"

    def test_set_goal_has_reason_property(self):
        props = _find_tool("set_goal")["input_schema"]["properties"]
        assert "reason" in props
        assert props["reason"]["type"] == "string"

    def test_set_goal_required_fields(self):
        required = _find_tool("set_goal")["input_schema"]["required"]
        assert "goal_intent_tag" in required

    def test_set_goal_reason_is_not_required(self):
        required = _find_tool("set_goal")["input_schema"]["required"]
        assert "reason" not in required

    def test_set_goal_description_non_empty(self):
        assert len(_find_tool("set_goal")["description"]) > 20


class TestMarkStepCompletedTool:
    """Validate mark_step_completed tool definition."""

    def test_mark_step_completed_exists(self):
        assert _find_tool("mark_step_completed") is not None

    def test_mark_step_completed_category_is_write(self):
        assert _find_tool("mark_step_completed")["category"] == "write"

    def test_mark_step_completed_access_level_is_user_scoped(self):
        assert _find_tool("mark_step_completed")["access_level"] == "user_scoped"

    def test_mark_step_completed_has_step_id_property(self):
        props = _find_tool("mark_step_completed")["input_schema"]["properties"]
        assert "step_id" in props
        assert props["step_id"]["type"] == "string"

    def test_mark_step_completed_has_outcome_property(self):
        props = _find_tool("mark_step_completed")["input_schema"]["properties"]
        assert "outcome" in props
        assert "enum" in props["outcome"]

    def test_mark_step_completed_outcome_enum_values(self):
        props = _find_tool("mark_step_completed")["input_schema"]["properties"]
        enum_vals = props["outcome"]["enum"]
        assert "completed" in enum_vals
        assert "skipped" in enum_vals

    def test_mark_step_completed_required_fields(self):
        required = _find_tool("mark_step_completed")["input_schema"]["required"]
        assert "step_id" in required
        assert "outcome" in required

    def test_mark_step_completed_description_non_empty(self):
        assert len(_find_tool("mark_step_completed")["description"]) > 20


class TestSaveInsightTool:
    """Validate save_insight tool definition."""

    def test_save_insight_exists(self):
        assert _find_tool("save_insight") is not None

    def test_save_insight_category_is_write(self):
        assert _find_tool("save_insight")["category"] == "write"

    def test_save_insight_access_level_is_user_scoped(self):
        assert _find_tool("save_insight")["access_level"] == "user_scoped"

    def test_save_insight_has_topic_property(self):
        props = _find_tool("save_insight")["input_schema"]["properties"]
        assert "topic" in props
        assert props["topic"]["type"] == "string"

    def test_save_insight_has_summary_property(self):
        props = _find_tool("save_insight")["input_schema"]["properties"]
        assert "summary" in props
        assert props["summary"]["type"] == "string"

    def test_save_insight_has_type_property_with_enum(self):
        props = _find_tool("save_insight")["input_schema"]["properties"]
        assert "type" in props
        assert "enum" in props["type"]

    def test_save_insight_type_enum_values(self):
        props = _find_tool("save_insight")["input_schema"]["properties"]
        enum_vals = props["type"]["enum"]
        assert "goal" in enum_vals
        assert "decision" in enum_vals
        assert "concern" in enum_vals
        assert "fact" in enum_vals
        # Wave A-MINIMAL (2026-04-18): "event" added for durable anchors
        # (scan, life event, major financial action) the coach can reference
        # later. Backend CoachInsightRecord.insight_type is Column(String)
        # so no migration needed; Anthropic tool_use schema must allow it
        # or calls from Flutter are rejected at the API level.
        assert "event" in enum_vals

    def test_save_insight_required_fields(self):
        required = _find_tool("save_insight")["input_schema"]["required"]
        assert "topic" in required
        assert "summary" in required
        assert "type" in required

    def test_save_insight_summary_description_mentions_max_chars(self):
        props = _find_tool("save_insight")["input_schema"]["properties"]
        summary_desc = props["summary"]["description"]
        assert "200" in summary_desc

    def test_save_insight_description_mentions_no_pii(self):
        desc = _find_tool("save_insight")["description"].lower()
        assert "pii" in desc or "iban" in desc or "employer" in desc
