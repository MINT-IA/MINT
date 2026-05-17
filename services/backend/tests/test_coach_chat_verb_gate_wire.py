"""Phase mint-calc-engine-v1 Plan 18 / W4 — D-CE-16(c) wire-up tests.

The runtime verb gate (Task 2) is wired into `_run_narrator_with_gate`
BEFORE the Phase 94 citation gate (Q5 = before, VALIDATION default,
orchestrator pre-decide).

These tests pin :
  1. The symbol `runtime_verb_gate` is imported in coach_chat.py.
  2. The call site precedes the `_citation_gate(` call (source-line ordering).
  3. Phase 9/10/17 baselines preserved (`art. ` count, `_maybe_wrap_v2` count,
     `inputs_provenance` count UNCHANGED from pre-Plan-18 baseline).
  4. The gate is wired inside `_run_narrator_with_gate`, NOT inside the
     turn-cap wrapper (`_run_narrator_with_gate_and_cap`) — so the legacy
     chat-tab path (Phase 94 byte-identity) hits the verb gate too.
  5. The Sentry breadcrumb `coach.verb_gate.fired` is emitted on fail.

The Phase 94 byte-identity tests (`tests/test_citation_gate/*`) MUST still
pass — Task 4 verifies via full-suite regression.
"""
from __future__ import annotations

import pathlib
import re

import pytest

_COACH_CHAT_PATH = (
    pathlib.Path(__file__).resolve().parent.parent
    / "app" / "api" / "v1" / "endpoints" / "coach_chat.py"
)


@pytest.fixture(scope="module")
def coach_chat_source() -> str:
    return _COACH_CHAT_PATH.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# 1 — symbol import present
# ---------------------------------------------------------------------------


def test_runtime_verb_gate_imported(coach_chat_source: str):
    """The wire-up imports `gate` from runtime_verb_gate."""
    assert "runtime_verb_gate" in coach_chat_source, (
        "D-CE-16(c) wire-up missing — `runtime_verb_gate` symbol not found "
        "in coach_chat.py"
    )


def test_runtime_verb_gate_alias_distinguishes_from_citation_gate(
    coach_chat_source: str,
):
    """Imported as `_runtime_verb_gate` (or alias) to avoid shadowing
    `_citation_gate`."""
    # Tolerant : either alias pattern is fine, just make sure both gates
    # coexist as distinct callables.
    assert "_citation_gate" in coach_chat_source
    assert (
        "runtime_verb_gate as _runtime_verb_gate" in coach_chat_source
        or "import runtime_verb_gate" in coach_chat_source
        or "from app.services.coach.runtime_verb_gate" in coach_chat_source
    )


# ---------------------------------------------------------------------------
# 2 — source-line ordering : verb gate BEFORE citation gate
# ---------------------------------------------------------------------------


def test_verb_gate_call_precedes_citation_gate_call(coach_chat_source: str):
    """Inside `_run_narrator_with_gate`, the verb-gate call appears BEFORE
    the first `_citation_gate(...)` call.

    Q5 = before. VALIDATION.md default + orchestrator pre-decide. Catches
    paraphrase BEFORE citation substitution to avoid double-template
    fallback chains.
    """
    # Locate the _run_narrator_with_gate function.
    func_re = re.compile(
        r"async def _run_narrator_with_gate\b[\s\S]*?"
        r"(?=async def _run_narrator_with_gate_and_cap)",
        re.MULTILINE,
    )
    match = func_re.search(coach_chat_source)
    assert match, "_run_narrator_with_gate not found in expected position"
    body = match.group(0)
    # Find offsets of the two calls.
    verb_match = re.search(r"_runtime_verb_gate\s*\(", body) or re.search(
        r"runtime_verb_gate\s*\(", body
    )
    citation_match = re.search(r"_citation_gate\s*\(", body)
    assert verb_match, "verb-gate call missing in _run_narrator_with_gate"
    assert citation_match, "citation-gate call missing in _run_narrator_with_gate"
    assert verb_match.start() < citation_match.start(), (
        f"Q5 = before violation : verb gate at offset {verb_match.start()} "
        f"appears AFTER citation gate at offset {citation_match.start()}"
    )


def test_verb_gate_short_circuits_on_fail(coach_chat_source: str):
    """On gate fail, the function returns BEFORE calling _citation_gate.

    Implementation contract : if `runtime_verb_gate` returns (False, fallback),
    the function returns immediately (no citation-gate call). Detected via a
    `return` statement between the verb-gate call and the citation-gate call.
    """
    func_re = re.compile(
        r"async def _run_narrator_with_gate\b[\s\S]*?"
        r"(?=async def _run_narrator_with_gate_and_cap)",
        re.MULTILINE,
    )
    body = func_re.search(coach_chat_source).group(0)
    # Find the verb-gate block — from the verb-gate call up to the
    # citation-gate call.
    verb_idx = (
        body.find("_runtime_verb_gate(")
        if "_runtime_verb_gate(" in body
        else body.find("runtime_verb_gate(")
    )
    citation_idx = body.find("_citation_gate(")
    between = body[verb_idx:citation_idx]
    assert "return" in between, (
        "Verb-gate fail branch must short-circuit (return loop_result) "
        "before reaching _citation_gate."
    )


# ---------------------------------------------------------------------------
# 3 — Sentry breadcrumb category emitted on fail
# ---------------------------------------------------------------------------


def test_verb_gate_breadcrumb_category_present(coach_chat_source: str):
    """Sentry breadcrumb category `coach.verb_gate.fired` is in source.

    Per Plan-18 STRIDE T-mint-calc-18-05 (audit trail) — every fire must
    leave a queryable trace. PII-safe : no narrator text in payload.
    """
    assert "coach.verb_gate.fired" in coach_chat_source, (
        "Sentry breadcrumb category `coach.verb_gate.fired` missing — "
        "violates Plan-18 STRIDE T-mint-calc-18-05 audit-trail mitigation."
    )


# ---------------------------------------------------------------------------
# 4 — pre-Plan-18 baselines preserved (Plans 9 / 10 / 17 surface)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "needle,min_count",
    [
        ("art. ", 5),         # Plan 9 baseline (article references)
        ("_maybe_wrap_v2", 6),  # Plan 10 baseline (CoachToolResponseV2 wrappers)
        # Plan 17 inputs_provenance lives in coach_tools_v2 helpers, not in
        # coach_chat.py itself ; baseline measured 0 in coach_chat.py pre-Plan-18,
        # so we just assert "no introduction of inputs_provenance string here".
        ("inputs_provenance", 0),
    ],
)
def test_baselines_preserved(coach_chat_source: str, needle: str, min_count: int):
    actual = coach_chat_source.count(needle)
    if min_count == 0:
        assert actual == 0, (
            f"Plan-18 wire-up introduced unexpected `{needle}` token "
            f"into coach_chat.py (actual={actual})."
        )
    else:
        assert actual >= min_count, (
            f"Baseline regression on `{needle}` — expected ≥{min_count}, "
            f"got {actual}. Plan-18 must not delete pre-existing wirings."
        )


# ---------------------------------------------------------------------------
# 5 — gate placement inside `_run_narrator_with_gate`, not the turn-cap wrapper
# ---------------------------------------------------------------------------


def test_verb_gate_inside_narrator_function_not_turn_cap(coach_chat_source: str):
    """The verb-gate call is inside `_run_narrator_with_gate`, NOT inside
    `_run_narrator_with_gate_and_cap` — so the legacy chat-tab path
    (Phase 94 byte-identity matrix) also runs through the gate."""
    cap_re = re.compile(
        r"async def _run_narrator_with_gate_and_cap\b[\s\S]*?(?=\Z|^async def |^def )",
        re.MULTILINE,
    )
    cap_match = cap_re.search(coach_chat_source)
    if cap_match:
        cap_body = cap_match.group(0)
        # The turn-cap wrapper may MENTION the verb gate only via delegation
        # to _run_narrator_with_gate ; it must not call it directly. Allow
        # zero direct calls in the cap body.
        direct_calls = re.findall(
            r"(?:^|\s)(?:_runtime_verb_gate|runtime_verb_gate)\s*\(", cap_body
        )
        assert not direct_calls, (
            f"Verb gate must NOT be called directly in "
            f"_run_narrator_with_gate_and_cap (delegate to "
            f"_run_narrator_with_gate). Found {len(direct_calls)} direct calls."
        )
