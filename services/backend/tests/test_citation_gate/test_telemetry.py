"""Phase 94 Wave 1 — D-18 Sentry breadcrumb hygiene + retry-budget invariant.

Pins :
- `_emit_gate_breadcrumb` payload keys are EXACTLY the 4 non-PII
  counts/labels (`verdict`, `retries`, `uncited_numbers_count`,
  `banned_claims_count`).
- No PII suspect key (`message`, `text`, `prompt`, `answer`, `body`,
  `user`, `content`) appears in the breadcrumb payload.
- The breadcrumb function is fail-open (telemetry must NEVER take
  down the request path).
- Source-level grep for the wrapper proves Karpathy #3 surgical
  contract: the wrapper exists, retries are bounded at 1.
"""
from __future__ import annotations

import pathlib
import re


def _coach_chat_src() -> str:
    src_path = (
        pathlib.Path(__file__).resolve().parent.parent.parent
        / "app" / "api" / "v1" / "endpoints" / "coach_chat.py"
    )
    return src_path.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# D-18 — payload key whitelist.
# ---------------------------------------------------------------------------


def test_breadcrumb_payload_only_whitelisted_keys():
    """The breadcrumb data dict must contain ONLY the 4 contract keys.
    """
    src = _coach_chat_src()
    match = re.search(
        r'_emit_gate_breadcrumb[\s\S]+?data=\{([\s\S]+?)\},',
        src,
    )
    assert match is not None
    payload = match.group(1)

    # Extract every quoted key.
    keys = set(re.findall(r'"(\w+)":', payload))
    expected = {
        "verdict",
        "retries",
        "uncited_numbers_count",
        "banned_claims_count",
    }
    assert keys == expected, (
        f"D-18 hygiene — payload keys must be exactly {expected!r} ; "
        f"found {keys!r}"
    )


def test_breadcrumb_does_not_leak_user_content():
    """No PII suspect key appears in the breadcrumb payload."""
    src = _coach_chat_src()
    match = re.search(
        r'_emit_gate_breadcrumb[\s\S]+?data=\{([\s\S]+?)\},',
        src,
    )
    assert match is not None
    payload = match.group(1)
    forbidden = [
        "message", "text", "prompt", "answer",
        "body", "user", "content", "narrator",
    ]
    for k in forbidden:
        assert f'"{k}"' not in payload, (
            f"D-18 — breadcrumb data MUST NOT carry key {k!r} "
            "(PII / user message content)"
        )


def test_breadcrumb_emitter_is_fail_open():
    """The emitter MUST wrap its body in `try/except` — telemetry can
    NEVER break the request path. Source-level grep receipt.
    """
    src = _coach_chat_src()
    # Locate the emitter and check its body has a try/except.
    pattern = re.compile(
        r"def _emit_gate_breadcrumb[\s\S]+?try:[\s\S]+?except Exception",
    )
    assert pattern.search(src) is not None, (
        "D-18 — the breadcrumb emitter must be wrapped in try/except "
        "so a Sentry init failure cannot break /api/v1/coach/chat"
    )


# ---------------------------------------------------------------------------
# D-08 retry-budget invariant — receipt for the « at most 2 calls »
# guarantee. The wrapper invokes `_run_agent_loop(question=...)`
# AT MOST twice : once initial, once on retry. The second call always
# uses `is_retry=True` which collapses any rejection to FALLBACK.
# ---------------------------------------------------------------------------


def test_max_one_retry_source_invariant():
    """The retry path must call `_run_agent_loop(question=...)` at most
    once more after the initial call. We grep for the literal `is_retry=True`
    on the second `_citation_gate(...)` call.
    """
    src = _coach_chat_src()
    # The second gate call uses is_retry=True (collapsing any rejection
    # to FALLBACK ; no third narrator call is ever scheduled).
    pattern = re.compile(
        r"retry_gated\s*=\s*_citation_gate\([\s\S]+?is_retry=True",
    )
    assert pattern.search(src) is not None, (
        "D-08 hard-cap=1 — second gate call must be invoked with "
        "`is_retry=True` to enforce the retry budget"
    )


def test_breadcrumb_emitted_for_both_passes():
    """Both gate runs (initial + retry) must emit a breadcrumb."""
    src = _coach_chat_src()
    # Two `_emit_gate_breadcrumb(...)` invocations — one initial
    # (retries=0), one on retry path (retries=1).
    occurrences = re.findall(r"_emit_gate_breadcrumb\(", src)
    assert len(occurrences) >= 2, (
        "Expected at least 2 breadcrumb invocations — initial gate run "
        "(retries=0) + retry-path gate run (retries=1)"
    )


def test_initial_breadcrumb_retries_zero():
    src = _coach_chat_src()
    assert "retries=0" in src, (
        "D-18 — initial breadcrumb must carry `retries=0`"
    )


def test_retry_breadcrumb_retries_one():
    src = _coach_chat_src()
    assert "retries=1" in src, (
        "D-18 — retry-path breadcrumb must carry `retries=1`"
    )


# ---------------------------------------------------------------------------
# Karpathy #3 — wrapper does NOT modify _run_agent_loop body.
# ---------------------------------------------------------------------------


def test_run_agent_loop_signature_and_body_intact():
    """The agent-loop body markers must still be present (no surgery
    inside the loop). We don't pin exact line numbers — those drift —
    but we sniff for stable marker fragments.
    """
    src = _coach_chat_src()
    assert "async def _run_agent_loop" in src
    # The agent-loop has its own internal reprompt strings — those must
    # remain (Karpathy #3 — the loop is unchanged).
    # Marker : the agent loop's main timeout symbol still exists.
    assert "AGENT_LOOP_DEADLINE_SECONDS" in src
