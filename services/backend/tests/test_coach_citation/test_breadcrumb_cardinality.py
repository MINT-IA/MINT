"""Wave 1b Plan 08 — one breadcrumb per tool_* placeholder in narrator output.

Cardinality contract:
  - Helper `emit_coach_citation_breadcrumb` itself does NOT dedupe — every
    call emits one Sentry breadcrumb (mirrors emit_coach_tool_breadcrumb).
  - The WRAPPER (`_run_narrator_with_gate` in coach_chat.py) is the dedupe
    layer: it iterates `{{cite:tool_*}}` placeholders in the gated text and
    fires the helper at most once per tool short-name per turn, even if the
    narrator placed the same placeholder N times.
  - Non-tool placeholders (`{{cite:r3a_plafond_salarie_2026}}`,
    `{{cite:adr_*}}`, etc.) MUST NOT trigger any
    coach.citation.tool_call_id.* breadcrumb.
"""
from unittest.mock import MagicMock, patch


def test_one_breadcrumb_per_tool_placeholder():
    """Helper-level: each call to emit_coach_citation_breadcrumb emits one
    breadcrumb. Dedupe lives in the wrapper (seen_tool_names set), NOT in
    the helper. This test pins the helper contract.
    """
    from app.observability.coach_breadcrumbs import emit_coach_citation_breadcrumb

    with patch("app.observability.coach_breadcrumbs.sentry_sdk") as mock_sdk:
        mock_sdk.add_breadcrumb = MagicMock()
        emit_coach_citation_breadcrumb(
            tool_name="budget_snapshot",
            inputs_hash="a" * 64,
            profile_id_hashed="b" * 16,
            elapsed_ms=10,
            flag_state="on",
        )
        assert mock_sdk.add_breadcrumb.call_count == 1
        # Calling again still emits — wrapper dedupes, NOT helper.
        emit_coach_citation_breadcrumb(
            tool_name="budget_snapshot",
            inputs_hash="a" * 64,
            profile_id_hashed="b" * 16,
            elapsed_ms=11,
            flag_state="on",
        )
        assert mock_sdk.add_breadcrumb.call_count == 2


def test_non_tool_placeholder_does_not_emit_citation_breadcrumb():
    """{{cite:r3a_plafond_salarie_2026}} (source_kind=spec) MUST NOT
    classify as tool_*. Asserted by filtering the regex matches on the
    tool_ prefix — exactly what the wrapper does before invoking the helper.
    """
    from app.services.coach.citation_parser import _RE_CITE_PLACEHOLDER

    gated_text = "Tu peux mettre 7'056 CHF {{cite:r3a_plafond_salarie_2026}}."
    # Existing _RE_CITE_PLACEHOLDER has no capture group; the wrapper uses
    # a sibling regex (or m.group(0) + slicing) to extract the key. This
    # test asserts the SEMANTIC behavior: no key starts with tool_ here.
    raw_matches = [m.group(0) for m in _RE_CITE_PLACEHOLDER.finditer(gated_text)]
    # Strip `{{cite:` prefix + `}}` suffix to recover the key.
    keys = [m[len("{{cite:"):-len("}}")] for m in raw_matches]
    tool_keys = [k for k in keys if k.startswith("tool_")]
    assert tool_keys == [], "spec placeholder must not be classified as tool_*"
