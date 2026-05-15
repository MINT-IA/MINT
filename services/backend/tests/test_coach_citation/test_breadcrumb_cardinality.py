"""Wave 1b Plan 08 — one breadcrumb per tool_* placeholder in narrator output."""
import pytest


@pytest.mark.skip(reason="Wave 1b — wrapper emission logic lands in Plan 08")
def test_one_breadcrumb_per_tool_placeholder():
    # When narrator emits text with N placeholders matching {{cite:tool_*}},
    # the wrapper calls emit_coach_citation_breadcrumb N times — one per placeholder.
    assert False, "Plan 08 implements + unskips"


@pytest.mark.skip(reason="Wave 1b — non-tool keys do NOT trigger emission")
def test_non_tool_placeholder_does_not_emit_citation_breadcrumb():
    # {{cite:r3a_plafond_salarie_2026}} (source_kind=spec) MUST NOT fire coach.citation.tool_call_id.*.
    assert False, "Plan 08 implements + unskips"
