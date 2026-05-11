---
phase: 96
plan: 02
subsystem: backend/coach-chat
type: summary
wave: 2
status: shipped
tags:
  - backend
  - pydantic
  - fastapi
  - coach-chat
  - turn-cap
  - sentry-breadcrumb
  - chat-as-verb
  - phase-95-gate
dependency_graph:
  requires:
    - phase: 95-mvp-dag-invalidation
      provides: "ProjectionGroundingPack + double-lookup in citation_parser._substitute_placeholders(pack=) (commits fb2b13aa + e6a4a12f + 29bb08de — gate-checked at T1 step 0)"
    - phase: 96-mvp-chat-as-verb/Plan-01
      provides: "SerializedCardContext Dart mirror (apps/mobile/lib/models/serialized_card_context.dart) — backend Pydantic v2 mirror MUST emit camelCase JSON (cardId, cardType, computedFacts, …) to round-trip cleanly with the Dart side."
  provides:
    - services/backend/app/schemas/card_context.py (SerializedCardContext Pydantic v2, D-12)
    - services/backend/app/schemas/narrative_sleeve.py (NarrativeSleeve Pydantic v2, D-14)
    - services/backend/app/schemas/coach_chat.py +source_card/turn_count/intent on Request + narrative_sleeve on Response (D-13/D-15)
    - services/backend/app/services/coach/turn_cap.py (TURN_COUNTER + TURN_CAP_TERMINAL_TEMPLATE + Sentry breadcrumb helper, D-08..D-11)
    - services/backend/app/services/coach/claude_coach_service.py + _render_source_card_block + source_card kwarg on build_narrator_system_prompt (D-13)
    - services/backend/app/api/v1/endpoints/coach_chat.py +_run_narrator_with_gate_and_cap wrapper + source_card prompt injection
    - tools/checks/pii_fixture_scan.py +structural scan of SerializedCardContext.computed_facts for banned keys (D-12 PII gate extension)
  affects:
    - Plan 96-03 (Wave 3 cross-stack) consumes NarrativeSleeve schema for the hook digit-free linter middleware + metaphor TOML library
    - Plan 96-03 G1 Maestro flow exercises the 3-turn cap end-to-end against staging
tech-stack:
  added:
    - "(no new runtime deps — uuid_utils + rfc8785 already installed in venv for Phase 95 W1 compatibility)"
  patterns:
    - "Pydantic v2 mode='before' field_validator to reject bool/None pre-Union-coercion on dict-of-scalar fields (computed_facts)"
    - "TYPE_CHECKING import for Pydantic schemas in service-layer modules — avoids early-load circular import via app.core.config"
    - "Additive optional CoachChatRequest/Response fields with documented threat-model anchors in field description (T-96-W2-TurnCountTamper noted on turn_count)"
    - "In-memory module-level Dict[(session_id, source_card_id), int] counter — Redis backing deferred to Phase 97 per CONTEXT §Deferred §7"
    - "Sentry breadcrumb category convention `coach.chat_overflow.turn_4` (matches Phase 94 `coach.citation_gate` + Phase 95 `coach.grounding_pack.fallback`)"
    - "Surgical endpoint wrapper composition — _run_narrator_with_gate_and_cap wraps _run_narrator_with_gate without modifying the inner signature (preserves Phase 94/95 213-test byte-identity)"
key-files:
  created:
    - services/backend/app/schemas/card_context.py
    - services/backend/app/schemas/narrative_sleeve.py
    - services/backend/app/services/coach/turn_cap.py
    - services/backend/tests/test_chat_as_verb/__init__.py
    - services/backend/tests/test_chat_as_verb/conftest.py
    - services/backend/tests/test_chat_as_verb/test_serialized_card_context.py
    - services/backend/tests/test_chat_as_verb/test_narrative_sleeve_schema.py
    - services/backend/tests/test_chat_as_verb/test_turn_cap.py
    - services/backend/tests/test_chat_as_verb/test_terminal_template.py
    - services/backend/tests/test_chat_as_verb/test_narrator_source_card_block.py
    - services/backend/tests/test_chat_as_verb/test_sentry_overflow_breadcrumb.py
    - tools/checks/fixtures/pii_scan/computed_facts_clean.jsonl
    - tools/checks/fixtures/pii_scan/computed_facts_dirty.jsonl
  modified:
    - services/backend/app/schemas/coach_chat.py (additive — source_card + turn_count + intent on Request, narrative_sleeve on Response)
    - services/backend/app/services/coach/claude_coach_service.py (source_card kwarg + _render_source_card_block + TYPE_CHECKING import)
    - services/backend/app/api/v1/endpoints/coach_chat.py (turn_cap imports + source_card block injection + _run_narrator_with_gate_and_cap wrapper + call-site swap)
    - tools/checks/pii_fixture_scan.py (structural walker for computed_facts banned keys + scan_json_file for non-JSONL fixtures)
decisions:
  - D-08 / D-11 — TURN_CAP_THRESHOLD=3 hard ; OVERFLOW_BREADCRUMB_CATEGORY=coach.chat_overflow.turn_4
  - D-09 — session_id derived from str(_user.id) (the only stable per-app-session anchor available in CoachChatRequest scope) ; anonymous fallback for safety
  - D-10 — verbatim FR terminal template carries « exploré » + « hypothèses » accents ; zero LSFin banned terms ; snapshot-tested
  - D-12 — SerializedCardContext frozen=True + extra="forbid" + scalar-only computed_facts validator in mode='before' (bool subclass-of-int + None coercion both rejected explicitly)
  - D-13 — <source_card> block appended to narrator system prompt AFTER memory blocks + reasoning block + citation_grammar fragment ; only when body.source_card is non-None (byte-identity guard for legacy path)
  - D-14 — NarrativeSleeve schema lands here ; the hook digit-free linter + next_step word-count linter lands in Plan 96-03 W3 per D-16
  - D-15 — CoachChatResponse.narrative_sleeve optional default None ; populated only when source_card non-None on request
  - T-96-W2-TurnCountTamper — server reads TURN_COUNTER as source of truth ; client-supplied turn_count accepted on the wire for UX transparency only (informational)
  - T-96-W2-MultiProcessDrift — accepted ; documented in turn_cap.py module docstring (workers=1 staging default ; Redis is the Phase 97 patch path)
requirements-completed:
  - VERB-02
  - VERB-03
  - VERB-05
metrics:
  duration_minutes: 42
  tasks_completed: 3
  files_created: 13
  files_modified: 4
  tests_added: 46
  pytest_test_total_pre_w2: 6521
  pytest_test_total_post_w2: 6567
  pytest_test_regressions: 0
  phase_94_byte_identity_count: 181
  phase_95_byte_identity_count: 74
  commits:
    - b81172a3  # T1 Phase 95 gate-check + SerializedCardContext + pii_fixture_scan
    - 54fee7cd  # T2 NarrativeSleeve schema + CoachChat additive extensions
    - bbcf0853  # T3 turn_cap + narrator <source_card> block + _run_narrator_with_gate_and_cap + Sentry breadcrumb
  completed_date: 2026-05-11
---

# Phase 96 Plan 02: MVP-CHAT-AS-VERB Wave 2 (Backend) — Summary

**SerializedCardContext + NarrativeSleeve Pydantic v2 schemas, additive CoachChatRequest/Response fields, in-memory 3-turn cap with verbatim FR terminal template + Sentry breadcrumb, narrator system-prompt `<source_card>` injection. Phase 94/95 byte-identity preserved (255 tests still green).**

## Performance

- **Duration:** ~42 min execution
- **Started:** 2026-05-11 (after Plan 96-01 close at 02:08:00Z)
- **Completed:** 2026-05-11
- **Tasks:** 3 / 3
- **Files created:** 13
- **Files modified:** 4
- **Tests added:** 46 (+ 0 regressions)

## What shipped

**T1 — SerializedCardContext + pii_fixture_scan extension** (`b81172a3`)

- Phase 95 W2 gate-check : `git log --oneline | grep -E "fb2b13aa|e6a4a12f|29bb08de"` returned 3 matches at task start — all 3 required commits present on `feature/S94-mvp-citation-gate`. Gate passed before any W2 code-edit.
- `services/backend/app/schemas/card_context.py` — Pydantic v2 model with 7 fields per D-12 :
  - Required : `card_id: str` (min 1, max 128), `card_type: str` (min 1, max 64)
  - Defaulted : `computed_facts: Dict[str, Decimal|int|str]` (validator in mode='before' rejects nested dicts / lists / bool / None — bool explicitly because bool is a subclass of int and would silently coerce to 0/1), `grounding_keys: List[str]`
  - Optional : `life_event: str|None` (max 64), `canton: str|None` (exact 2 chars), `archetype: str|None` (max 32)
  - `model_config = ConfigDict(frozen=True, extra="forbid", populate_by_name=True, alias_generator=to_camel)` — camelCase JSON aliases match the Dart mirror at `apps/mobile/lib/models/serialized_card_context.dart` (Plan 96-01)
- `services/backend/tests/test_chat_as_verb/test_serialized_card_context.py` — 12 tests covering : full instantiation, minimal-required-only, frozen mutation rejection, extra-fields rejection, scalar-only validator (positive + 4 negative cases for nested dict / list / bool / None), length bounds (card_id min, canton max), camelCase JSON round-trip via `model_dump(by_alias=True)` + `model_validate`.
- `tools/checks/pii_fixture_scan.py` — extended with `_walk_computed_facts` recursive JSON walker. Scans `computed_facts` / `computedFacts` mapping values for banned substring keys (email/phone/ahv/iban/npa/employer/name/surname/address). Backward-compatible : Phase 95 D-14 regex scan for AHV13 + Swiss-phone preserved. New `scan_json_file()` handles non-JSONL fixtures.
- 2 lint fixtures (`tools/checks/fixtures/pii_scan/computed_facts_{clean,dirty}.jsonl`) — clean exits 0, dirty exits 1 with 3 hits cited (1 banned key on line 1 + 1 SWISS_PHONE + 1 banned key on line 2).

**T2 — NarrativeSleeve + CoachChat additive extensions** (`54fee7cd`)

- `services/backend/app/schemas/narrative_sleeve.py` — Pydantic v2 model per D-14, 4 fields : `hook` (min 1, max 200), `caption` (min 1, max 2000), `next_step` (min 1, max 120), `metaphor` (default "", max 200). `frozen=True, extra="forbid"`. The hook digit-free + next_step word-count linters land in Plan 96-03 W3 per D-16 — this schema enforces only byte-length caps so Pydantic can never 500 on the response (the middleware swap is the chosen safety surface).
- `services/backend/app/schemas/coach_chat.py` — additive optional fields, no Karpathy #3 reformat :
  - `CoachChatRequest.source_card: Optional[SerializedCardContext] = None` (D-13)
  - `CoachChatRequest.turn_count: int = 0` (`ge=0`, D-08, informational with T-96-W2-TurnCountTamper note in description)
  - `CoachChatRequest.intent: Optional[Literal["explain", "reassure"]] = None` (D-06)
  - `CoachChatResponse.narrative_sleeve: Optional[NarrativeSleeve] = None` (D-15)
- `services/backend/tests/test_chat_as_verb/test_narrative_sleeve_schema.py` — 14 tests : 4 NarrativeSleeve core invariants (full, defaults, model_copy, extra-forbid), 4 length bounds (hook 200, caption 2000, next_step 120, metaphor 200), 3 CoachChatRequest extensions (all-fields, backward-compat, intent literal rejection), 1 CoachChatResponse optional, 2 JSON round-trips.

**T3 — turn_cap + narrator block + wrapper + Sentry breadcrumb** (`bbcf0853`)

- `services/backend/app/services/coach/turn_cap.py` — D-08..D-11 contract module :
  - `TURN_COUNTER: Dict[(session_id, source_card_id), int]` — module-level dict, empty on app boot, resets on process restart per D-09 ("per session, not per day").
  - `TURN_CAP_TERMINAL_TEMPLATE` — verbatim FR D-10 string : « Tu as exploré 3 angles sur cette carte. Pour aller plus loin, ouvre le simulateur depuis [Explorer →](/explorer?id={card_id}) — tu pourras y modifier les hypothèses en direct. » accent_lint_fr clean (« exploré » + « hypothèses » accents present) ; zero LSFin banned terms (snapshot-guarded + explicit assertion).
  - `TURN_CAP_THRESHOLD = 3` hard per D-08.
  - `OVERFLOW_BREADCRUMB_CATEGORY = "coach.chat_overflow.turn_4"` per D-11.
  - Helpers : `reset()` (test isolation), `is_cap_hit(key)` (predicate), `increment_and_get_previous(key)` (read-then-write within coroutine — Python GIL + non-preemptive async + workers=1 keep this safe per CONTEXT §Claude's Discretion), `emit_overflow_breadcrumb(*, source_card_id, turn_count)` (non-PII payload, fail-open), `render_terminal_template(card_id)` (single substitution path).
  - Module-load tolerance for missing `sentry_sdk` (`sentry_sdk = None` on ImportError).
- `services/backend/app/services/coach/claude_coach_service.py` — `_render_source_card_block(source_card)` helper renders the `<source_card>` block per D-13 with all 7 fields (optional ones omitted entirely when None/empty). `build_narrator_system_prompt` gains `source_card: Optional[SerializedCardContext] = None` kwarg ; appended AFTER the citation-grammar fragment with `\n\n` separator. When `source_card=None` (the legacy call shape), the function is byte-identical to pre-T3 output (pinned by `test_source_card_none_preserves_legacy_byte_identity` + the 213-test Phase 94/95 matrix).
- `services/backend/app/api/v1/endpoints/coach_chat.py` :
  - New top-level import block for turn_cap helpers.
  - `if body.source_card is not None:` block after the standard system_prompt assembly, calling `_render_source_card_block` (1-branch addition, legacy path zero-touch).
  - New inner async wrapper `_run_narrator_with_gate_and_cap(pack=)` :
    - `body.source_card is None` → pass-through (Phase 94/95 byte-identity guard ; wrapper has zero side effects on legacy path).
    - `is_cap_hit((session_id, card_id))` → emit Sentry breadcrumb + return terminal template dict (`model_used="n/a-cap-hit"` surfaces in `response_meta` for telemetry). ZERO LLM call.
    - else → `increment_and_get_previous(key)` then delegate to `_run_narrator_with_gate(pack=)`.
  - Single call site swapped from `await _run_narrator_with_gate()` to `await _run_narrator_with_gate_and_cap()`. Inner wrapper signature unchanged ; the 2-3 `_run_narrator_with_gate` occurrences inside `_run_agent_loop` (Phase 94 §3 surgical scope) NOT touched.
- 4 new test files (20 tests) : `test_turn_cap.py` (7), `test_terminal_template.py` (5), `test_narrator_source_card_block.py` (4), `test_sentry_overflow_breadcrumb.py` (4).

## Test count

| File | Tests | Status |
|---|---|---|
| `tests/test_chat_as_verb/test_serialized_card_context.py` | 12 | green |
| `tests/test_chat_as_verb/test_narrative_sleeve_schema.py` | 14 | green |
| `tests/test_chat_as_verb/test_turn_cap.py` | 7 | green |
| `tests/test_chat_as_verb/test_terminal_template.py` | 5 | green |
| `tests/test_chat_as_verb/test_narrator_source_card_block.py` | 4 | green |
| `tests/test_chat_as_verb/test_sentry_overflow_breadcrumb.py` | 4 | green |
| **Wave 2 net new** | **46** | **all green** |

**Full backend pytest suite:** 6567 passed, 60 skipped, 1 xfailed in 109.99s (`cd services/backend && .venv/bin/python3 -m pytest tests/ -q --tb=no --ignore=tests/integration --ignore=tests/test_property_invariants.py`). Pre-W2 baseline = 6521 ; W2 net new = +46. Zero pre-existing regressions.

**Phase 94 byte-identity:** `cd services/backend && .venv/bin/python3 -m pytest tests/test_citation_gate/ -q` → 181 passed (1 skipped). Identical to pre-W2 baseline.

**Phase 95 byte-identity:** `cd services/backend && .venv/bin/python3 -m pytest tests/test_dag_invalidation/ -q` → 74 passed. Identical to pre-W2 baseline.

## Gate evidence (deterministic citations)

| Gate | Result | Citation |
|------|--------|----------|
| Phase 95 W2 merge gate-check | green, 3/3 SHAs present | `git log --oneline \| grep -E "fb2b13aa\|e6a4a12f\|29bb08de" \| wc -l` → `3` |
| SerializedCardContext schema invariants | 12/12 passed | `.venv/bin/python3 -m pytest tests/test_chat_as_verb/test_serialized_card_context.py -q` |
| NarrativeSleeve schema + CoachChat extensions | 14/14 passed | `.venv/bin/python3 -m pytest tests/test_chat_as_verb/test_narrative_sleeve_schema.py -q` |
| turn_cap module invariants | 7/7 passed | `.venv/bin/python3 -m pytest tests/test_chat_as_verb/test_turn_cap.py -q` |
| Terminal template snapshot + accent + LSFin | 5/5 passed | `.venv/bin/python3 -m pytest tests/test_chat_as_verb/test_terminal_template.py -q` |
| Narrator <source_card> block + byte-id | 4/4 passed | `.venv/bin/python3 -m pytest tests/test_chat_as_verb/test_narrator_source_card_block.py -q` |
| Sentry breadcrumb non-PII payload | 4/4 passed | `.venv/bin/python3 -m pytest tests/test_chat_as_verb/test_sentry_overflow_breadcrumb.py -q` |
| accent_lint_fr on turn_cap.py | clean | `python3 tools/checks/accent_lint_fr.py --file services/backend/app/services/coach/turn_cap.py` → exit 0 |
| banned_terms_python on turn_cap.py | clean | `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/turn_cap.py` → exit 0 |
| pii_fixture_scan extension (clean fixture) | exit 0 | `python3 tools/checks/pii_fixture_scan.py tools/checks/fixtures/pii_scan/computed_facts_clean.jsonl` → exit 0 |
| pii_fixture_scan extension (dirty fixture) | exit 1 with 3 hits | `python3 tools/checks/pii_fixture_scan.py tools/checks/fixtures/pii_scan/computed_facts_dirty.jsonl` → exit 1, cites `computed_facts.user_email` + `SWISS_PHONE` + `computedFacts.primaryPhone` |
| Phase 94 byte-identity (citation gate) | 181 passed, 1 skipped | `.venv/bin/python3 -m pytest tests/test_citation_gate/ -q` |
| Phase 95 byte-identity (dag invalidation) | 74 passed | `.venv/bin/python3 -m pytest tests/test_dag_invalidation/ -q` |
| Coach chat endpoint regression | 42 passed | `.venv/bin/python3 -m pytest tests/test_coach_chat_endpoint.py -q` |
| Full backend pytest | 6567 passed, 60 skipped, 1 xfailed | `.venv/bin/python3 -m pytest tests/ -q --tb=no --ignore=tests/integration --ignore=tests/test_property_invariants.py` |

## Decisions Made

- **session_id derivation** : the CoachChatRequest schema does not carry a session_id field (chat is stateless on the wire — conversation_history is replayed). The wrapper uses `str(_user.id)` as the per-app-session anchor under the workers=1 staging assumption documented in turn_cap.py. Anonymous fallback ("anonymous") for safety. This matches D-09's intent ("per-session, not per-day") within the single-process deployment. If multi-process surfaces drift at G2, the patch path is Redis-backed counter (Phase 97 per CONTEXT §Deferred §7).
- **<source_card> block placement** : appended at the END of system_prompt assembly (after memory blocks + reasoning_block + the existing citation_grammar fragment). This minimises the diff to `_build_system_prompt_with_memory` (its signature is unchanged) and keeps the byte-identity invariant strict — when source_card is None, no string mutation occurs.
- **`_run_narrator_with_gate` signature unchanged** : the new wrapper is `_run_narrator_with_gate_and_cap` which COMPOSES the existing wrapper rather than modifying it. This is the same compositional pattern Phase 95 used to add `pack=` (additive kwarg, not signature break). The 213-test Phase 94/95 byte-identity matrix exercises the inner wrapper unchanged.
- **`mode='before'` validator on `computed_facts`** : Pydantic v2's default validation order coerces bool→int silently in `Dict[str, Union[Decimal, int, str]]`. The `mode='before'` hook inspects raw input values pre-coercion, rejecting bool / None / nested dicts / lists explicitly. Without this, `computed_facts={'flag': True}` would have silently survived as `{'flag': 1}` — losing the PII gate semantics.

## Deviations from Plan

### Auto-fixed

**1. [Rule 3 - Blocking] Missing `uuid_utils` + `rfc8785` Python deps in venv**

- **Found during:** Task 1 baseline pytest run (`tests/test_dag_invalidation/` failed to collect on `ModuleNotFoundError`).
- **Issue:** Both packages are project dependencies for Phase 95 W1 (DAG-invalidation parity foundation) but the local venv was at a state pre-Phase-95.
- **Fix:** `.venv/bin/python3 -m pip install uuid_utils rfc8785` — both installed cleanly.
- **Files modified:** None (venv-side install only, no code change).
- **Verification:** `.venv/bin/python3 -m pytest tests/test_dag_invalidation/ -q` → 74 passed.
- **Commit:** n/a (venv state, not committed).

**2. [Rule 1 - Bug] Pydantic Union coercion silently accepted `bool` in `computed_facts`**

- **Found during:** Task 1 (`test_computed_facts_rejects_bool` failed RED→GREEN cycle).
- **Issue:** Initial validator used `mode='after'` (default) ; Pydantic v2's Union[Decimal, int, str] coerced `True` to `1` BEFORE the validator saw the value, so the validator could not detect bool inputs.
- **Fix:** Switched validator to `mode='before'`. The hook now inspects raw input dict before Union coercion, rejecting bool / None / dict / list values explicitly.
- **Files modified:** `services/backend/app/schemas/card_context.py:63` (validator mode + docstring).
- **Verification:** `test_computed_facts_rejects_bool` + `test_computed_facts_rejects_none` both pass.
- **Committed in:** `b81172a3` (T1 commit).

**3. [Rule 3 - Documentation] CoachChatBaseModel does NOT have `extra="forbid"`**

- **Found during:** Task 2 (planning the additive extension).
- **Issue:** The 96-02-PLAN.md `<interfaces>` block claimed `CoachChatBaseModel` had `extra="forbid"`. The actual config (line 34) is `populate_by_name=True, alias_generator=to_camel` only.
- **Fix:** Preserved the existing config strictly (Karpathy #3 surgical). Adding `extra="forbid"` would break pre-96 clients that send unknown fields. The plan's `must_haves` block only required `SerializedCardContext` and `NarrativeSleeve` to be `extra="forbid"` — that was honoured. The Request and Response surfaces remain permissive on extra fields.
- **Files modified:** None — divergence is documentation-only, no plan-prescribed code path was altered.
- **Verification:** `test_coach_chat_request_backward_compat_no_phase_96_fields` passes ; existing 42 `test_coach_chat_endpoint.py` tests pass.

### Observed but not fixed (out of scope per CLAUDE.md rule 7 — pre-existing, not caused by W2)

**Pre-existing test-ordering issue in `test_coach_chat_bundles.py`**

- 5 tests (`test_flag_on_uses_compile_bundles`, `test_flag_on_differs_from_flag_off`, `test_flag_on_telemetry_breadcrumb_no_user_content`, `test_flag_on_fallback_emits_breadcrumb`, `test_flag_on_empty_intent_routes_through`) fail when invoked AFTER `tests/test_coach_chat_endpoint.py` in the same pytest invocation. They pass in isolation AND in the full `tests/` traversal.
- Verified pre-existing by stashing my W2 changes : 5 failures still appear. Not introduced by this plan.
- Logged for the post-96 maintenance backlog ; full backend pytest (6567 passed) is the authoritative gate and stays green.

### Architectural call (within plan latitude)

**Source-card prompt injection landed in the endpoint, not in `_build_system_prompt_with_memory`.**

The plan suggested injecting the `<source_card>` block via the prompt builder. I landed it as a 7-line addition in `coach_chat.py` immediately after the existing `_build_system_prompt_with_memory(...)` call (Karpathy #3 — minimal blast radius). Reasoning : `_build_system_prompt_with_memory` is consumed by many code paths (legacy + dual_llm + bundle compiler) ; adding `source_card` to its signature would have required modifying all 3 internal branches AND extending its test surface. The endpoint-side injection isolates the W2 surface entirely to the W2 caller — Plan 96-01's UI surface is the only producer of source_card values today. The `_render_source_card_block` helper is still exported from `claude_coach_service.py` so future call sites (e.g. anonymous_chat — out of scope for W2) can import it directly.

## Issues Encountered

None — all 3 tasks executed cleanly. The 2 auto-fixes (Rules 1 and 3) were absorbed inline within Task 1 (no extra commit, rolled into `b81172a3`).

## USER VALUE DELIVERED

**Plan 96-02 ships the backend contract surface and the cap-enforcement behaviour. User-visible chat behaviour ships in Plan 96-03 + Plan 96-01 wiring.**

What ships with Wave 2 :

- The `SerializedCardContext` Pydantic v2 schema — Plan 96-01's Dart mirror can now round-trip cleanly with the backend.
- The `NarrativeSleeve` Pydantic v2 schema — Plan 96-03's hook digit-free linter middleware has a contract to validate against.
- `CoachChatRequest` accepts `source_card` + `turn_count` + `intent` ; pre-96 clients keep working (all fields optional, default None / 0).
- `CoachChatResponse` accepts `narrative_sleeve` ; populated only by Plan 96-03's middleware (Wave 3).
- The 3-turn cap is LIVE server-side : a 4th request to `/api/v1/coach/chat` with the same `(user_id, source_card.card_id)` returns the verbatim FR terminal template with ZERO LLM call, ZERO token cost. The `coach.chat_overflow.turn_4` Sentry breadcrumb fires with non-PII payload (`source_card_id` + `turn_count` only — NEVER `user_message` / `profile_context` / `api_key`).
- The narrator system prompt receives the `<source_card>` block (7 lines max, optional fields omitted when None) — Plan 94's citation gate continues to validate narrator output against the registry, and the `<source_card>` block provides the grounding-key candidates for that gate.

What does NOT ship with Wave 2 (explicitly out of scope per the wave split D-22) :

- The hook digit-free linter middleware (lands in Plan 96-03 W3 per D-16).
- The metaphor TOML library + lookup function (Plan 96-03).
- Maestro G1 flow `flow_card_action_intent_bar.yaml` (Plan 96-03).
- G2 Julien sim walkthrough — HUMAN-UAT per CLAUDE.md §9 (Plan 96-03 checkpoint).
- Server-side Redis-backed counter (deferred to Phase 97 if G2 surfaces drift).
- Production traffic exercising the cap path — staging-only until D-11 baseline pull.

A G2 « 4th turn returns the terminal template » verification is possible RIGHT NOW by curling the staging `/api/v1/coach/chat` endpoint 4 times with the same `source_card.card_id`. Plan 96-03 G1 Maestro exercises this end-to-end.

## Threat Flags

None — Wave 2 stays within the planned threat surface (T-96-W2-Phase95Gate, T-96-W2-TurnCountTamper, T-96-W2-PIISmuggling, T-96-W2-NarratorPromptInjection accepted, T-96-W2-MultiProcessDrift accepted, T-96-W2-TerminalTemplateLeakage). No new endpoints, no new auth paths, no new file access patterns at trust boundaries.

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| `NarrativeSleeve` instances are not yet emitted by any code path | `services/backend/app/schemas/narrative_sleeve.py` | Schema lands here per D-15 ; the response middleware that builds + emits NarrativeSleeve lands in Plan 96-03 W3. `CoachChatResponse.narrative_sleeve` stays None on every response shipped from W2 — intentional. |
| `body.intent` is parsed but not yet consumed by the narrator | `services/backend/app/schemas/coach_chat.py:160` | The intent literal validates ("explain"/"reassure"/None) but the narrator prompt does not yet branch on intent. Plan 96-03 wires intent-conditional prompt fragments. |
| Sentry breadcrumb production wiring E2E verification | `services/backend/app/services/coach/turn_cap.py:emit_overflow_breadcrumb` | Unit-tested via mock (PII gate + fail-open) ; the staging E2E exercise closes at Plan 96-03 W3 G1 Maestro flow (deferred from Phase 95 W2 per CONTEXT §Deferred). |

These stubs are INTENTIONAL per the wave split (D-22) and are explicitly listed in 96-02-PLAN.md `deferred:` field.

## Self-Check: PASSED

Verified claims (deterministic citations) :

- All 3 created schemas exist at the expected paths :
  - `services/backend/app/schemas/card_context.py` ✓ (created in `b81172a3`)
  - `services/backend/app/schemas/narrative_sleeve.py` ✓ (created in `54fee7cd`)
  - `services/backend/app/services/coach/turn_cap.py` ✓ (created in `bbcf0853`)
- All 3 commits exist on the current branch (`feature/S94-mvp-citation-gate`) :
  - `b81172a3 feat(96-02): T1 — Phase 95 gate-check + SerializedCardContext schema + pii_fixture_scan extension` ✓
  - `54fee7cd feat(96-02): T2 — NarrativeSleeve schema + CoachChatRequest/Response additive extensions` ✓
  - `bbcf0853 feat(96-02): T3 — turn_cap module + narrator <source_card> block + _run_narrator_with_gate_and_cap wrapper + Sentry breadcrumb` ✓
- 6 test files in `tests/test_chat_as_verb/` cover 46 net-new test cases ; all green at the time of writing.
- Phase 95 W2 gate : `git log --oneline | grep -E "fb2b13aa|e6a4a12f|29bb08de"` → 3 matches.
- Phase 94 byte-identity : `tests/test_citation_gate/` → 181 passed, 1 skipped.
- Phase 95 byte-identity : `tests/test_dag_invalidation/` → 74 passed.
- Full backend pytest : 6567 passed, 60 skipped, 1 xfailed (baseline 6521 + 46 W2 net new = 6567 exact).
- Terminal template accent_lint_fr → exit 0 ; banned_terms_python → exit 0.
- pii_fixture_scan clean fixture → exit 0 ; dirty fixture → exit 1 with 3 PII hits.

## Next Phase Readiness

- Plan 96-03 W3 ready to start :
  - NarrativeSleeve schema available for the hook digit-free linter middleware to validate against.
  - `<source_card>` block already injected when source_card is non-None — Plan 96-03's metaphor TOML resolver can consume `body.source_card.archetype` + `body.source_card.canton` + `body.source_card.life_event` for the lookup.
  - The 3-turn cap is enforced ; Plan 96-03 G1 Maestro flow can assert `coach.chat_overflow.turn_4` fires on the 4th request.
- No blockers for W3 :
  - The staging deploy of W2 (post-merge) will be the prerequisite for W3 G1 against `mint-staging.up.railway.app` per CONTEXT D-27.
  - G2 Julien sim walkthrough is on the W3 checkpoint, not W2.

---
*Phase: 96-mvp-chat-as-verb*
*Wave: 2 of 3*
*Completed: 2026-05-11*
