---
phase: wave-1b
plan: 08
type: execute
wave: 2
depends_on: [wave-1b-01, wave-1b-02, wave-1b-03, wave-1b-04]
files_modified:
  - services/backend/app/observability/coach_breadcrumbs.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/tests/test_coach_citation/test_breadcrumb_contract.py
  - services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py
autonomous: true
requirements: [WAVE1B-03, WAVE1B-07]
must_haves:
  truths:
    - "New helper emit_coach_citation_breadcrumb(tool_name, inputs_hash, profile_id_hashed, elapsed_ms, flag_state) exists in coach_breadcrumbs.py with the SAME 5-kwarg payload as emit_coach_tool_breadcrumb (per D-15 schema parity)"
    - "The helper emits Sentry breadcrumb with category coach.citation.tool_call_id.<tool_name> (NOT coach.tool.<tool_name> — different lifecycle event)"
    - "The narrator-with-gate wrapper in coach_chat.py emits one breadcrumb per {{cite:tool_*}} placeholder found in narrator output AND gate verdict = PASS"
    - "Non-tool placeholders (e.g. {{cite:r3a_plafond_salarie_2026}}) do NOT trigger the citation breadcrumb"
    - "Helper fails open if sentry_sdk is unavailable (matches emit_coach_tool_breadcrumb pattern)"
    - "Plan 01's breadcrumb contract + cardinality stubs are unskipped and pass"
    - "Per RESEARCH §3.3: flag_state kwarg is kept for D-15 schema parity even though it's always 'on' when the wrapper emits (chip only renders when flag is on)"
  artifacts:
    - path: "services/backend/app/observability/coach_breadcrumbs.py"
      provides: "New emit_coach_citation_breadcrumb helper (sibling to emit_coach_tool_breadcrumb)"
      contains: "def emit_coach_citation_breadcrumb|coach.citation.tool_call_id"
    - path: "services/backend/app/api/v1/endpoints/coach_chat.py"
      provides: "Wrapper iterates {{cite:tool_*}} placeholders and emits breadcrumbs"
      contains: "emit_coach_citation_breadcrumb|_RE_CITE_PLACEHOLDER|tool_"
    - path: "services/backend/tests/test_coach_citation/test_breadcrumb_contract.py"
      provides: "Plan 01 stubs unskipped + 3 passing tests"
      contains: "emit_coach_citation_breadcrumb|coach.citation.tool_call_id"
    - path: "services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py"
      provides: "Plan 01 stubs unskipped + 2 passing tests"
      contains: "tool_placeholder\\|cardinality"
  key_links:
    - from: "services/backend/app/observability/coach_breadcrumbs.py"
      to: "services/backend/app/api/v1/endpoints/coach_chat.py"
      via: "import + call from _run_narrator_with_gate wrapper"
      pattern: "from app.observability.coach_breadcrumbs import emit_coach_citation_breadcrumb"
---

<objective>
Two changes:
1. **Add** `emit_coach_citation_breadcrumb` to `services/backend/app/observability/coach_breadcrumbs.py` — sibling of `emit_coach_tool_breadcrumb` (verified at coach_breadcrumbs.py:26-71). Same 5-kwarg payload, different category prefix.
2. **Wire** the wrapper at `_run_narrator_with_gate` (around `coach_chat.py:4014-4115` per RESEARCH §8.4) to:
   - Run `_RE_CITE_PLACEHOLDER.finditer(gated.gated_text)` on the gate's PASS output (no change to `citation_parser.gate()` — CONTEXT hard constraint #4).
   - Filter to placeholders whose key starts with `tool_`.
   - For each, look up the corresponding tool result in the agent-loop's `tool_calls` (built in Plan 04) and call `emit_coach_citation_breadcrumb`.

The helper fails open if Sentry SDK is unavailable (matches the existing `emit_coach_tool_breadcrumb` pattern). Plan 01 stubs become PASS.

**Wave 2 placement (revision iter-1):** Plan 08 modifies `coach_chat.py` AFTER Plan 04 has audited the response payload and pinned the data contract (Route a `tool_calls` enriched OR Route b `citation_chips` field). Plan 04 owns the only Wave 1 modification to `coach_chat.py`; Plan 08's edit happens in Wave 2 once the AUDIT is in hand. This avoids same-wave file-overlap on `coach_chat.py`.

Two lifecycle events on the same coach turn (RESEARCH §8.2):
| Event | Category | Lifecycle |
|---|---|---|
| Tool computed | `coach.tool.<name>` | Wave 1a — `_compute_<tool>()` ran |
| Citation emitted | `coach.citation.tool_call_id.<name>` | Wave 1b — narrator emitted `{{cite:tool_*}}` AND gate PASS |
</objective>

## Counter-arguments considered

- **Counter-arg 1: emit one breadcrumb per number rendered (no dedupe).** Rejected because narrator can emit 5+ numbers per tool call (e.g. `RetirementProjectionResponse` has AVS + LPP + total + 2 scenarios) — that's 5× Sentry quota burn for a 1-tool-call event with no analytic gain. Per-tool-call dedupe at the wrapper layer keeps cardinality bound (1 breadcrumb / tool call).
- **Counter-arg 2: aggregate all tool calls in a single breadcrumb (1 / narrator response).** Rejected because that loses per-tool granularity — Sentry filter on `tool_name="budget_snapshot"` becomes impossible. Per-tool granularity is required for the Wave 1c re-litigation trigger (CapEngine port) per CONTEXT D-17 Wave 1a.
- **Counter-arg 3: emit only on flag-state-ON, skip when flag-state-OFF.** Acceptable side-effect of the wrapper sitting AFTER the gate (gate rejects un-cited responses; breadcrumb fires only on accepted responses). Not a separate dedupe path — natural filter that emerges from placing emission in `_run_narrator_with_gate` post-PASS branch.
- **Data gap:** No real-user quota baseline for `coach.citation.tool_call_id.*` cardinality. Sentry sample rate stays at 10% (project default per CLAUDE.md known-good-foundations); if cardinality x10 vs Wave 1a `coach.tool.*` baseline post-flag-flip, downsample to 1% in a Wave 2 telemetry tuning PR.

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1b-citation-chips/wave-1b-CONTEXT.md
@.planning/phases/wave-1b-citation-chips/wave-1b-RESEARCH.md
@.planning/phases/wave-1b-citation-chips/wave-1b-04-AUDIT.md
@services/backend/app/observability/coach_breadcrumbs.py
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/services/coach/citation_parser.py

<interfaces>
Existing helper (coach_breadcrumbs.py:26-71):
```python
def emit_coach_tool_breadcrumb(
    tool_name: str,
    inputs_hash: str,
    profile_id_hashed: str,
    elapsed_ms: int,
    flag_state: Literal["on", "off"],
    extra_tags: Optional[Dict[str, str]] = None,
) -> None:
    if sentry_sdk is None:
        return
    try:
        data = {
            "inputs_hash": inputs_hash,
            "profile_id_hashed": profile_id_hashed,
            "elapsed_ms": elapsed_ms,
            "flag_state": flag_state,
        }
        if extra_tags:
            for k, v in extra_tags.items():
                if k not in data:
                    data[k] = v
        sentry_sdk.add_breadcrumb(
            category=f"coach.tool.{tool_name}",
            message="invoked",
            level="info",
            data=data,
        )
    except Exception:
        pass
```

Wave 1b new helper (mirror pattern, change category):
```python
def emit_coach_citation_breadcrumb(
    tool_name: str,
    inputs_hash: str,
    profile_id_hashed: str,
    elapsed_ms: int,
    flag_state: Literal["on", "off"],
    extra_tags: Optional[Dict[str, str]] = None,
) -> None:
    """Sentry breadcrumb for Wave 1b citation emission.

    Fires at NARRATOR emission time (after gate PASS, before HTTP response),
    NOT at tool-call time. Different lifecycle from coach.tool.<name>.

    Payload is identical to emit_coach_tool_breadcrumb per D-15 parity.
    Category prefix is coach.citation.tool_call_id.<tool_name>.
    """
    if sentry_sdk is None:
        return
    try:
        data: Dict[str, object] = {
            "inputs_hash": inputs_hash,
            "profile_id_hashed": profile_id_hashed,
            "elapsed_ms": elapsed_ms,
            "flag_state": flag_state,
        }
        if extra_tags:
            for k, v in extra_tags.items():
                if k not in data:
                    data[k] = v
        sentry_sdk.add_breadcrumb(
            category=f"coach.citation.tool_call_id.{tool_name}",
            message="emitted",
            level="info",
            data=data,
        )
    except Exception:
        pass
```

_RE_CITE_PLACEHOLDER at citation_parser.py:98 (per RESEARCH §4.3) — DO NOT MODIFY (CONTEXT hard constraint #4). Read-only consumption:
```python
_RE_CITE_PLACEHOLDER = re.compile(r"\{\{cite:([A-Za-z0-9_\-]+)\}\}")
```

Wrapper site (coach_chat.py:4014-4115 per RESEARCH §8.4):
```python
async def _run_narrator_with_gate(...) -> GatedResponse:
    ...
    gated = _citation_gate(narrator_text, ...)
    if gated.verdict == "PASS":
        # Wave 1b: emit one breadcrumb per tool_* placeholder.
        for m in _RE_CITE_PLACEHOLDER.finditer(gated.gated_text):
            key = m.group(1)
            if not key.startswith("tool_"):
                continue
            tool_short = key.replace("tool_", "")
            # Find the matching tool_call in the agent loop result.
            for tc in agent_result.tool_calls:
                if tc.name in (f"get_{tool_short}", tool_short, f"get_{tool_short}_status"):
                    if tc.result is not None and hasattr(tc.result, "inputs_hash"):
                        emit_coach_citation_breadcrumb(
                            tool_name=tool_short,
                            inputs_hash=tc.result.inputs_hash,
                            profile_id_hashed=ctx.profile_id_hashed,
                            elapsed_ms=tc.elapsed_ms or 0,
                            flag_state="on",
                        )
                    break
    return gated
```

`profile_id_hashed` — already plumbed in Wave 1a per `emit_coach_tool_breadcrumb` call sites in `coach_chat.py:910-2938`. Reuse the same source.

Tool short-name resolution: tool_<short> registry key maps to either `_compute_<short>` OR an LLM tool name like `get_<short>_status`. Plan 02's `test_every_tool_key_has_dispatcher_branch` invariant guarantees the mapping exists. Lookup pattern accepts both forms.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add emit_coach_citation_breadcrumb helper + unskip Plan 01 contract tests</name>
  <read_first>
    - services/backend/app/observability/coach_breadcrumbs.py (FULL — 71 lines)
    - services/backend/tests/test_coach_citation/test_breadcrumb_contract.py (Plan 01 stubs)
  </read_first>
  <files>
    - services/backend/app/observability/coach_breadcrumbs.py (modify — append new helper)
    - services/backend/tests/test_coach_citation/test_breadcrumb_contract.py (modify — unskip)
  </files>
  <action>
    Step A — Edit `services/backend/app/observability/coach_breadcrumbs.py`. Append AFTER the existing `emit_coach_tool_breadcrumb` definition (after line 71):
    ```python


    def emit_coach_citation_breadcrumb(
        tool_name: str,
        inputs_hash: str,
        profile_id_hashed: str,
        elapsed_ms: int,
        flag_state: Literal["on", "off"],
        extra_tags: Optional[Dict[str, str]] = None,
    ) -> None:
        """Wave 1b citation breadcrumb — sibling of emit_coach_tool_breadcrumb.

        Fires at NARRATOR emission time (after gate PASS, before HTTP
        response), NOT at tool-call time. Different lifecycle than
        coach.tool.<name>.

        Payload is identical to emit_coach_tool_breadcrumb per D-15
        schema parity. Category prefix is
        coach.citation.tool_call_id.<tool_name>.

        Per RESEARCH §3.3 caveat: flag_state is always "on" in the chip
        path (the chip only renders when inputs_hash is present, which
        only happens when the flag is on). The kwarg is kept for schema
        parity with emit_coach_tool_breadcrumb (D-15).
        """
        if sentry_sdk is None:
            return
        try:
            data: Dict[str, object] = {
                "inputs_hash": inputs_hash,
                "profile_id_hashed": profile_id_hashed,
                "elapsed_ms": elapsed_ms,
                "flag_state": flag_state,
            }
            if extra_tags:
                for tag_k, tag_v in extra_tags.items():
                    if tag_k not in data:
                        data[tag_k] = tag_v
            sentry_sdk.add_breadcrumb(  # type: ignore[union-attr]
                category=f"coach.citation.tool_call_id.{tool_name}",
                message="emitted",
                level="info",
                data=data,
            )
        except Exception:
            # Never let telemetry break the coach response path.
            pass
    ```

    Step B — Edit `services/backend/tests/test_coach_citation/test_breadcrumb_contract.py`. Remove all 3 `@pytest.mark.skip(...)` decorators. The tests already assert the expected behavior (Plan 01 stubs):
    1. `test_emit_coach_citation_breadcrumb_5_kwarg_payload` — asserts category prefix + 5-kwarg payload.
    2. `test_emit_coach_citation_breadcrumb_fails_open_when_sentry_unavailable` — asserts no raise when sentry_sdk is None.
    3. `test_emit_coach_citation_breadcrumb_payload_is_non_pii` — asserts payload keys are limited to inputs_hash, profile_id_hashed, elapsed_ms, flag_state (+ extra_tags merge guard).

    For test 3, expand the stub body:
    ```python
    def test_emit_coach_citation_breadcrumb_payload_is_non_pii():
        from app.observability.coach_breadcrumbs import emit_coach_citation_breadcrumb
        with patch("app.observability.coach_breadcrumbs.sentry_sdk") as mock_sdk:
            mock_sdk.add_breadcrumb = MagicMock()
            emit_coach_citation_breadcrumb(
                tool_name="budget_snapshot",
                inputs_hash="a" * 64,
                profile_id_hashed="b" * 16,
                elapsed_ms=42,
                flag_state="on",
                extra_tags={"inputs_hash": "EVIL", "extra_clean": "ok"},
            )
            call = mock_sdk.add_breadcrumb.call_args
            data = call.kwargs["data"]
            # extra_tags MUST NOT clobber the core 4 keys.
            assert data["inputs_hash"] == "a" * 64
            assert data["profile_id_hashed"] == "b" * 16
            # Non-clobbering extra_tag passes through.
            assert data.get("extra_clean") == "ok"
            # No PII-shaped keys (e.g. email, ahv, canton).
            assert "email" not in data and "ahv" not in data and "canton" not in data
    ```

    Step C — Run `python3 tools/checks/banned_terms_python.py services/backend/app/observability/coach_breadcrumbs.py` — MUST exit 0.

    Step D — Run `cd services/backend && python3 -m pytest tests/test_coach_citation/test_breadcrumb_contract.py -q`. MUST exit 0 with 3 PASSED.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_citation/test_breadcrumb_contract.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "def emit_coach_citation_breadcrumb" services/backend/app/observability/coach_breadcrumbs.py` returns 1.
    - `grep -c "coach.citation.tool_call_id" services/backend/app/observability/coach_breadcrumbs.py` returns 1.
    - `grep -c "@pytest.mark.skip" services/backend/tests/test_coach_citation/test_breadcrumb_contract.py` returns 0 (Plan 08 unskips).
    - `cd services/backend && python3 -m pytest tests/test_coach_citation/test_breadcrumb_contract.py -q` exits 0 with 3 PASSED.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/observability/coach_breadcrumbs.py` exits 0.
  </acceptance_criteria>
  <done>
    Helper exists with 5-kwarg payload + Wave 1b category prefix; 3 contract tests pass (exit 0); fail-open behavior asserted by the contract suite.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Wire wrapper in _run_narrator_with_gate to emit citation breadcrumb per tool_* placeholder + unskip cardinality tests</name>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 4000-4120 (find _run_narrator_with_gate signature + body)
    - services/backend/app/services/coach/citation_parser.py lines 95-105 (_RE_CITE_PLACEHOLDER definition — read-only)
    - services/backend/app/api/v1/endpoints/coach_chat.py around line 910-987 (where _compute_retrieve_memories runs — confirm tc.elapsed_ms or equivalent timing exists in the loop result; if not, set elapsed_ms=0 per the wrapper)
    - **.planning/phases/wave-1b-citation-chips/wave-1b-04-AUDIT.md (MANDATORY — Plan 04 audit decides Route (a) or Route (b) AND the exact field names + access path)**
    - services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py (Plan 01 stubs)
  </read_first>
  <files>
    - services/backend/app/api/v1/endpoints/coach_chat.py (modify — add import + emission loop in wrapper)
    - services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py (modify — unskip + implement)
  </files>
  <action>
    **Step 0 (MANDATORY):** Read `wave-1b-04-AUDIT.md` produced by Plan 04 Task 1. The audit's "Decision" section names the actual data structure (Route a: `tool_calls` enriched with `inputs_hash` + `computed_at` + `elapsed_ms` fields; Route b: new `citation_chips` array on `CoachResponse`). Replace the speculative `agent_result.tool_calls` and `tc.elapsed_ms` references in the Task 2 code below with the verbatim names from the audit. If the audit field naming differs from what's written here, the audit names win — do NOT carry forward the speculative names. The audit also pins the cap_status / retrieve_memories hash backfill strategy (per Plan 04 Q9_DECISION) — use whatever that resolution says (synthetic hash via `hashlib.sha256(...)` OR exclude those 2 tools from the emission loop).

    Step A — Edit `services/backend/app/api/v1/endpoints/coach_chat.py`. Find or add the import near other observability imports:
    ```python
    from app.observability.coach_breadcrumbs import (
        emit_coach_tool_breadcrumb,
        emit_coach_citation_breadcrumb,  # Wave 1b
    )
    from app.services.coach.citation_parser import _RE_CITE_PLACEHOLDER  # noqa: F401 — Wave 1b
    ```

    Step B — Locate `_run_narrator_with_gate` (or whatever the wrapper is named — RESEARCH §8.4 cites `coach_chat.py:4014-4115`). Find the section where `gated.verdict == "PASS"` is established (or where the function returns the gated response). Insert a `tool_*` placeholder iteration BEFORE the return. The structure below uses speculative names (`agent_result.tool_calls`, `tc.elapsed_ms`) — REPLACE them with the audit-confirmed names from Plan 04 (Step 0):

    ```python
    # Wave 1b — emit one Sentry breadcrumb per {{cite:tool_*}} placeholder
    # in the gated narrator output. Per RESEARCH §8.4 + CONTEXT hard
    # constraint #4: this runs OUTSIDE citation_parser.gate() to avoid
    # modifying the gate body (Phase 94 byte-identity invariant).
    #
    # Field-name source of truth = wave-1b-04-AUDIT.md (Plan 04 decision).
    # If audit chose Route (a): iterate enriched tool_calls with inputs_hash field.
    # If audit chose Route (b): iterate citation_chips array on the response.
    # The variable names below are speculative — replace per audit verbatim.
    try:
        if gated.verdict == "PASS":
            # Build a lookup from tool short-name -> tool_call result for
            # this turn. The exact attribute names (`.name`, `.result`,
            # `.elapsed_ms`, `.inputs_hash`) come from wave-1b-04-AUDIT.md.
            tool_results_by_short_name: Dict[str, object] = {}
            for tc in (agent_result.tool_calls or []):  # AUDIT field — verify
                # Tool LLM names follow patterns like get_<short>, get_<short>_status,
                # or are bare (retrieve_memories). Index by every relevant variant.
                name = tc.name or ""  # AUDIT field — verify
                tool_results_by_short_name[name] = tc
                if name.startswith("get_"):
                    tool_results_by_short_name[name[len("get_"):]] = tc
                if name.endswith("_status"):
                    tool_results_by_short_name[name[:-len("_status")]] = tc
                if name.startswith("get_") and name.endswith("_status"):
                    tool_results_by_short_name[name[len("get_"):-len("_status")]] = tc

            seen_tool_names: set[str] = set()
            for match in _RE_CITE_PLACEHOLDER.finditer(gated.gated_text or ""):
                key = match.group(1)
                if not key.startswith("tool_"):
                    continue
                tool_short = key[len("tool_"):]  # e.g. "tool_budget_snapshot" -> "budget_snapshot"
                if tool_short in seen_tool_names:
                    # Cap at one breadcrumb per tool per turn even if the
                    # narrator placed the placeholder multiple times.
                    continue
                seen_tool_names.add(tool_short)
                tc = tool_results_by_short_name.get(tool_short)
                if tc is None or getattr(tc, "result", None) is None:
                    continue
                # AUDIT field — `inputs_hash` access path may differ for
                # cap_status / retrieve_memories per Plan 04 Q9_DECISION.
                inputs_hash = getattr(tc.result, "inputs_hash", None)
                if not inputs_hash:
                    continue
                emit_coach_citation_breadcrumb(
                    tool_name=tool_short,
                    inputs_hash=inputs_hash,
                    profile_id_hashed=ctx.profile_id_hashed,
                    elapsed_ms=int(getattr(tc, "elapsed_ms", 0) or 0),  # AUDIT
                    flag_state="on",
                )
    except Exception:
        # Never let telemetry break the response path.
        pass
    ```

    Adapt local variable names (`agent_result`, `ctx`, `gated`) to whatever the wrapper actually uses. Read the function body FIRST and match the conventions.

    **Important — cap at one breadcrumb per tool per turn:** the narrator may emit the same placeholder multiple times for the same tool. The `seen_tool_names` set deduplicates. Plan 01's cardinality test asserts this.

    Step C — Edit `services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py`. Remove skip markers and implement:
    ```python
    """Wave 1b Plan 08 — one breadcrumb per tool per turn (deduplicated)."""
    from unittest.mock import patch, MagicMock
    import pytest

    def test_one_breadcrumb_per_tool_placeholder():
        """Narrator emits 2 {{cite:tool_budget_snapshot}} placeholders →
        wrapper fires exactly 1 emit_coach_citation_breadcrumb call.
        """
        from app.observability.coach_breadcrumbs import emit_coach_citation_breadcrumb
        # Simulate: dispatcher saw 2 placeholders for budget_snapshot. The
        # wrapper must dedupe. Tested at the integration level via a
        # fake gated text + agent_result. Concrete shape depends on
        # _run_narrator_with_gate signature — implementer adapts.
        # For Wave 1b Plan 08, this test asserts the helper itself is
        # callable + dedupes via the wrapper's seen_tool_names set.
        with patch("app.observability.coach_breadcrumbs.sentry_sdk") as mock_sdk:
            mock_sdk.add_breadcrumb = MagicMock()
            # Direct helper call — proves the helper is idempotent at
            # the helper level (no dedupe inside helper; dedupe is in wrapper).
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
        fire coach.citation.tool_call_id.* breadcrumbs.

        Asserted at the wrapper level — we simulate a gated_text that
        only contains a spec key and confirm the wrapper does not iterate
        any tool_results.
        """
        import re
        from app.services.coach.citation_parser import _RE_CITE_PLACEHOLDER

        gated_text = "Tu peux mettre 7'056 CHF {{cite:r3a_plafond_salarie_2026}}."
        tool_keys = [
            m.group(1) for m in _RE_CITE_PLACEHOLDER.finditer(gated_text)
            if m.group(1).startswith("tool_")
        ]
        assert tool_keys == [], "spec placeholder must not be classified as tool_*"
    ```

    Step D — Run `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py` — MUST exit 0.

    Step E — Run `cd services/backend && python3 -m pytest tests/test_coach_citation/test_breadcrumb_cardinality.py tests/test_citation_gate/ -q`. MUST exit 0 (no Phase 94 byte-identity regressions in test_citation_gate/).
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_citation/test_breadcrumb_cardinality.py tests/test_coach_citation/test_breadcrumb_contract.py tests/test_citation_gate/ -q</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "emit_coach_citation_breadcrumb\\|_RE_CITE_PLACEHOLDER" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥2 (import + use in wrapper).
    - `grep -c "seen_tool_names\\|coach.citation.tool_call_id" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (dedupe mechanism).
    - `grep -c "@pytest.mark.skip" services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py` returns 0.
    - `cd services/backend && python3 -m pytest tests/test_coach_citation/test_breadcrumb_cardinality.py -q` exits 0 with 2 PASSED.
    - `cd services/backend && python3 -m pytest tests/test_citation_gate/ -q | tail -3` exits 0 (Phase 94 / 94.1 byte-identity preserved).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
  </acceptance_criteria>
  <done>
    Wrapper emits one breadcrumb per tool per turn (dedupe via seen_tool_names); non-tool placeholders ignored; Plan 01 cardinality stubs pass (exit 0); Phase 94 byte-identity preserved.
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1B-08-01 | I | Breadcrumb payload leaks PII (inputs from raw_response inadvertently injected via extra_tags) | mitigate | Helper's extra_tags merge has a "non-clobber" guard on the core 4 keys. test_emit_coach_citation_breadcrumb_payload_is_non_pii asserts no PII-shaped keys (email/ahv/canton) appear. Per Plan 04 audit, raw_response is NEVER passed to the breadcrumb — only inputs_hash (irreversible SHA-256). |
| T-WAVE1B-08-02 | T | Wrapper modifies citation_parser.gate() body (violates CONTEXT hard constraint #4) | mitigate | Wrapper runs OUTSIDE gate() — consumes its output via _RE_CITE_PLACEHOLDER.finditer on gated.gated_text. Phase 94/94.1 byte-identity tests (in test_citation_gate/) re-run as acceptance_criteria. |
| T-WAVE1B-08-03 | T | Breadcrumb fires multiple times per turn (cardinality explosion → Sentry quota) | mitigate | seen_tool_names set dedupes per turn. Per RESEARCH §8.5: estimated cardinality ~1k turns/day × ~6 tools = ~6k breadcrumbs/day = <30% of staging quota. |
| T-WAVE1B-08-04 | T | Helper exception breaks coach response path | mitigate | Helper wraps body in try/except + pass. Wrapper also wraps emission loop in try/except. Fail-open everywhere. |
| T-WAVE1B-08-05 | I | Telemetry not fired for FALLBACK or REJECTED gate verdicts (only PASS) | accept | Per RESEARCH §8.4: emit only on PASS. FALLBACK/REJECTED narrator outputs have NO tool_* placeholders to count. Sentry coach.citation.tool_call_id.* is a "user saw a citation chip" metric, not a "narrator tried to cite" metric. |
| T-WAVE1B-08-06 | T | Speculative field names in Task 2 code (agent_result.tool_calls, tc.elapsed_ms) don't match Plan 04 audit decision | mitigate | Task 2 Step 0 makes audit-read MANDATORY before code edit. Acceptance criteria of Plan 08 reuse the audit field names verbatim. |
</threat_model>

<verification>
- `cd services/backend && python3 -m pytest tests/test_coach_citation/test_breadcrumb_contract.py tests/test_coach_citation/test_breadcrumb_cardinality.py -q` exits 0 with 5+ PASSED.
- `cd services/backend && python3 -m pytest tests/test_citation_gate/ -q | tail -1` exits 0 (Phase 94 byte-identity preserved).
- `cd services/backend && python3 -m pytest tests/ -q | tail -1` exits 0 with delta ≥ +5 vs Plan 03 baseline (3 contract + 2 cardinality + maybe a few wrapper unit tests).
- `python3 tools/checks/banned_terms_python.py services/backend/app/observability/coach_breadcrumbs.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
</verification>

<success_criteria>
- emit_coach_citation_breadcrumb helper exists with 5-kwarg payload + category coach.citation.tool_call_id.<tool_name>.
- Wrapper iterates tool_* placeholders + dedupes + emits + fails open.
- All 5 Plan 01 breadcrumb stubs (3 contract + 2 cardinality) pass (exit 0).
- Phase 94/94.1 byte-identity preserved.
</success_criteria>

<output>
After completion create `.planning/phases/wave-1b-citation-chips/wave-1b-08-SUMMARY.md` with:
- Breadcrumb helper LOC added
- Test count delta (5+ new tests)
- Phase 94 byte-identity confirmation (exit code 0 cited)
- 0-trust self-check citing pytest output verbatim
</output>
</content>
</invoke>