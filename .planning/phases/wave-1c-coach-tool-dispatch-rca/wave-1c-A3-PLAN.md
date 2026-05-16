---
phase: wave-1c-coach-tool-dispatch-rca
wave: A3
parent_waves: [A, A1, A2, A2.1]
depends_on:
  - wave-1c-A-PLAN.md     # PR #634 sha bc020925 MERGED 2026-05-15T17:01:05Z (doctrine MANDATE)
  - wave-1c-A1-PLAN.md    # PR #637 sha 363a4ce8 MERGED 2026-05-15T18:56:12Z (3-position MANDATE)
  - wave-1c-A2-PLAN.md    # PR #639 sha 28627863 MERGED 2026-05-15 (orchestration-layer RAG cut)
  - wave-1c-A2.1-fix      # PR #641 sha 37fbd889 MERGED 2026-05-15T20:30:55Z (FAQ-fallback guard `if n_results > 0:` at orchestrator.py:100 — ALREADY SHIPPED; CONTEXT.md §domain mention of "separate pre-A3 A2.2 PR" is stale)
autonomous: true
files_modified:
  - services/backend/app/models/coach_tools/_response.py            # NEW
  - services/backend/app/services/coach/coach_tools.py              # MISSING_FIELDS_INSTRUCTION_FR constant + 5 per-tool `description` rewrites
  - services/backend/app/services/coach/citation_grammar.py         # ~28-token pointer in TOP/BOTTOM mandate
  - services/backend/app/services/coach/profile_extractor.py        # +_extract_avs_years (+ tuple entry in _EXTRACTORS)
  - services/backend/app/api/v1/endpoints/coach_chat.py             # dispatcher → CoachToolResponse JSON; turn-local pending_profile_updates; same-turn save_insight; _synthesize_handshake_fallback sibling; Sentry breadcrumb; tool_results in return dict
  - services/backend/tests/test_coach_tools_missing_fields_instruction.py   # NEW (D-A3-05 #3) — flat tests/ convention, NOT tests/test_coach_tools/
  - services/backend/tests/test_coach_chat_missing_fields_handshake.py      # NEW (D-A3-05 #1) — flat tests/ convention, NOT tests/test_coach_chat/
  - services/backend/tests/test_coach_chat_narrator_asks_on_incomplete.py   # NEW (D-A3-05 #2) — flat tests/ convention, mock-Anthropic harness
  - services/backend/tests/test_coach_chat_handshake_persistence.py         # NEW (D-A3-05 #4) — flat tests/ convention
  - tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml  # NEW (D-A3-05 #5)
wave1c_decisions_addressed: [D-A3-01, D-A3-02, D-A3-03, D-A3-04, D-A3-05, D-A3-06, D-A3-07, D-A3-08, D-A3-09, D-A3-10, D-A3-11]
branch: feature/wave-1c-A3-missing-fields-handshake
target_branch: dev
must_haves:
  truths:
    - "Blank-profile probe to /api/v1/coach/chat with a retirement-tool-eligible intent (e.g. « Quelle sera ma rente AVS à 65 ans ? ») emits a real `tool_use` block on the FIRST turn for every one of the 5 chip-emitting tools in scope (`get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`, `get_cap_status`, `get_couple_optimization`), and the tool's `tool_result.content` is a JSON-encoded `CoachToolResponse` with `status:\"incomplete\"` and a non-empty `missing_fields` list (cap=3) plus a non-empty French `hint_fr` string — never `message: \"\"` and never `tool_result.is_error=true`."
    - "After the user replies with the missing values in the next turn, `extract_profile_facts()` parses them into `Fact` rows, ONLY high-confidence (`confidence >= 0.75`) rows are written to the turn-local agent-loop dict `pending_profile_updates` (low-confidence captures land in a sibling `pending_low_confidence_echoes` list surfaced by the narrator's next reply for user confirmation per CONTEXT.md §D-A3-03), the same-turn dispatcher reads from `pending_profile_updates` BEFORE re-querying the DB, AND the high-confidence rows are upserted into `CoachInsightRecord` via the existing `save_insight` code path (`coach_chat.py:2443-2478`) — all inside the same SQLAlchemy session, with a SINGLE outer commit at turn end (no new `db.commit()` introduced inside the agent-loop body per CONTEXT.md §D-A3-03 « single transaction »)."
    - "If Sonnet 4.5 returns `message: \"\"` AFTER receiving a `status:\"incomplete\"` tool_result (the obs #88 trust-collapse failure mode), `_synthesize_handshake_fallback(hint_fr)` in `_run_narrator_with_gate` deterministically synthesizes a French question from the `hint_fr` field BEFORE the response is returned to Flutter, and emits a Sentry breadcrumb `coach.tool.incomplete` with `fallback_used: true`. The fallback reads `loop_result['tool_results']` which `_run_agent_loop` now exposes in its return dict (D-A3-06 floor goes from dead code to live wire)."
    - "Every `status:\"ok\"` happy-path payload for the 5 chip-emitters keeps its numerical fields delegated to `apps/mobile/lib/services/financial_core/` (Flutter side) and to the existing backend helpers `_compute_budget_status` / `_compute_retirement_projection` / `_compute_cross_pillar_analysis` / `_format_cap_status` / `_compute_couple_optimization` (verbatim signatures verified 2026-05-16 via `grep -nE '^def _compute' coach_chat.py` — see Task A3.5 read_first) — A3 does NOT re-implement any `_calculate*` logic. Per CLAUDE.md triplet #3 (D-A3-07 NON-NEGOTIABLE)."
    - "`MISSING_FIELDS_INSTRUCTION_FR` constant is the SINGLE source of truth and appears verbatim in the `description` field of all 5 chip-emitter entries in the COACH_TOOLS array (drift-resistant — lint test guarantees it). The template `.format(required_fields_csv=...)` smoke-renders at import time without crashing on embedded JSON braces (literal `{`/`}` correctly doubled in the example block — `.format` import-time test wired in Task A3.2)."
    - "A `~28-token` pointer line (« Pour chaque outil, lis le champ `description` : il liste les champs profil requis et la procédure si un champ manque. ») is embedded inside BOTH `_TOOL_USE_MANDATE` (TOP, ~51% position) AND `_TOOL_USE_MANDATE_REPEAT` (BOTTOM, ~64% position) blocks in `citation_grammar.py`, per the TOP/BOTTOM Liu-2024 mitigation pattern."
    - "0-trust: PR opened ≠ shipped. The plan delivers a PR opened on `feature/wave-1c-A3-missing-fields-handshake` → `dev` with all 5 G1-G5 gates green WITH deterministic citations in the merge commit message OR in `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-VERIFICATION-REPORT.html`. « ready / works / shipped » claim language is BANNED from the plan body, the PR body, and the commit messages per CLAUDE.md §9.5."
  artifacts:
    - path: services/backend/app/models/coach_tools/_response.py
      provides: "Pydantic v2 `CoachToolResponse` RootModel — discriminated union `Union[CoachToolOk, CoachToolIncomplete, CoachToolPolicyBlocked]` keyed on `status: Literal['ok','incomplete','policy_blocked']`. `CoachToolIncomplete` carries `missing_fields: list[str]` (cap=3 enforced via field validator) and `hint_fr: str` (LSFin-clean French). `CoachToolPolicyBlocked` defined but unused in A3."
      exports: ["CoachToolResponse", "CoachToolOk", "CoachToolIncomplete", "CoachToolPolicyBlocked"]
    - path: services/backend/app/services/coach/coach_tools.py
      provides: "Module-level constant `MISSING_FIELDS_INSTRUCTION_FR` (template string with `{required_fields_csv}` placeholder + an embedded Anthropic Tool-Use Example sequence per D-A3-02; literal JSON `{`/`}` correctly doubled for `.format()` import-time safety). Per-tool `.format()` calls injected into the `description` field of all 5 chip-emitter entries at the existing tool definitions (lines 637 / 653 / 669 / 685 / 701)."
      exports: ["MISSING_FIELDS_INSTRUCTION_FR"]
    - path: services/backend/app/services/coach/citation_grammar.py
      provides: "Single-line pointer (~28 tokens) appended INSIDE `_TOOL_USE_MANDATE` (after the `tool_use(get_retirement_projection)` example paragraph) AND INSIDE `_TOOL_USE_MANDATE_REPEAT` (after the « INVOQUE l'outil » paragraph)."
      contains: "Pour chaque outil, lis le champ `description`"
    - path: services/backend/app/services/coach/profile_extractor.py
      provides: "New `_extract_avs_years(msg: str) -> Fact | None` mirroring `_extract_lpp` at line 407. Topic `avs_years`. AVS-anchor keyword (`avs`, `cotisation`, `1er pilier`, `premier pilier`) is MANDATORY — the bare-number fallback regex is DELETED (I-01 fix); when no anchor matches, returns `None` so the off-topic « j'ai 42 ans, ma fille a 12 ans » never poisons the AVS slot. Interstitial cap tightened to `[^,.]{0,25}` (I-07 fix) so commas do not bridge unrelated clauses. Function added to `_EXTRACTORS` tuple at line 488."
      exports: ["_extract_avs_years"]
    - path: services/backend/app/api/v1/endpoints/coach_chat.py
      provides: "(a) tool dispatcher branches for the 5 chip-emitters now return a `CoachToolResponse`-JSON string (Pydantic `model_dump_json(by_alias=True)`) instead of a plain text payload — `_compute_*` helpers remain UNCHANGED and their verbatim outputs are wrapped in `CoachToolOk(data=...)`; (b) agent-loop `_run_agent_loop` builds a turn-local `pending_profile_updates: dict[str, Any]` AND `pending_low_confidence_echoes: list[tuple[str, Any]]` and threads BOTH into the dispatcher AND into `extract_profile_facts` on the user's reply turn (only `confidence >= 0.75` facts land in `pending_profile_updates`); (c) same-turn upsert to `CoachInsightRecord` via the existing `save_insight` write path at lines 2443-2478 BEFORE the narrator's final reply is returned, sharing the SAME outer commit (no new `db.commit()` introduced inside the helper per D-A3-03 « single transaction »); (d) new sibling helper `_synthesize_handshake_fallback(hint_fr: str) -> str` invoked by `_run_narrator_with_gate` when the narrator's `answer` is empty AND the last tool_result is `status:\"incomplete\"`; (e) Sentry breadcrumb `coach.tool.incomplete` with `{tool_name, missing_fields, user_id_hashed, fallback_used}`; (f) `_run_agent_loop` return dict at line 3773 gains a `tool_results` key so the fallback in `_run_narrator_with_gate` can read the in-turn buffered list (was previously dead code)."
      exports: ["_synthesize_handshake_fallback"]
    - path: services/backend/tests/test_coach_tools_missing_fields_instruction.py
      provides: "Lint test — every chip-emitter `description` contains `MISSING_FIELDS_INSTRUCTION_FR` canonical substring. Drift guard per D-A3-02. Path follows the FLAT `tests/test_*.py` convention used by `test_coach_tools_budget_snapshot.py`, `test_coach_tools_retirement_projection.py`, etc. (NOT a `tests/test_coach_tools/` subdirectory — that does not exist in the repo)."
    - path: services/backend/tests/test_coach_chat_missing_fields_handshake.py
      provides: "For each of the 5 chip-emitters: fixture (blank profile, tool-eligible question) → assert tool returns `status:\"incomplete\"` + non-empty `missing_fields` + non-empty `hint_fr`; fixture (complete profile) → assert `status:\"ok\"` with the existing payload shape; fixture (partial profile, 1 field missing) → assert `missing_fields == [<the one field>]`. Flat tests/ convention."
    - path: services/backend/tests/test_coach_chat_narrator_asks_on_incomplete.py
      provides: "Mock-Anthropic narrator round-trip per CONTEXT.md §D-A3-05 #2 (LOCKED, not discretion). Reuses the existing `AsyncMock` / `MagicMock` / `patch.object(anthropic, ...)` pattern from `services/backend/tests/coach/test_claude_retry.py` lines 30-60 (verified 2026-05-16). For each of the 5 chip-emitters: feed a fake `tool_result.content = CoachToolIncomplete(...)`-JSON to a faked LLM client response sequence; assert the next `messages.create` invocation produces text containing one of the canonical FR question patterns (« j'ai besoin de » OR « peux-tu » OR « tu peux me partager ») AND `stop_reason == \"end_turn\"` with non-empty text. Plus a deterministic-floor unit test on `_synthesize_handshake_fallback`."
    - path: services/backend/tests/test_coach_chat_handshake_persistence.py
      provides: "Fixture: tool returns incomplete → mock user reply with the 4 canonical values → assert `CoachInsightRecord` upsert happens in the same turn (single SQLAlchemy session) + tool retry within the turn reads from `pending_profile_updates` cache (no DB query between cache write and tool retry) + Sentry breadcrumb `coach.tool.incomplete` emitted with correct payload."
    - path: tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml
      provides: "Maestro flow extending wave_1b_citation_chip_smoke pattern: 5 sub-scenarios (one per chip-emitter), each blank-profile → narrator French question → Maestro types reply → narrator emits real `tool_use` + chip on retry. Precondition `runFlow: auth/login.yaml`. Naming kept as `_6_tools.yaml` per CONTEXT.md §D-A3-05 even though A3 wires 5 — sixth slot reserved for `get_regulatory_constant` if A3.2 extends scope. Explainer comment at top of file documents the 5-vs-6 deviation (I-08 fix)."
  key_links:
    - from: "services/backend/app/services/coach/coach_tools.py:COACH_TOOLS[i].description (5 chip-emitter entries)"
      to: "MISSING_FIELDS_INSTRUCTION_FR.format(required_fields_csv=<canonical CSV for tool>)"
      pattern: "f-string or `.format()` injection of MISSING_FIELDS_INSTRUCTION_FR into the description string"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py:_execute_tool dispatcher (lines 2403-2425, verbatim)"
      to: "CoachToolResponse(...).model_dump_json(by_alias=True) wrapping the existing _compute_*/_format_cap_status return value"
      pattern: "JSON-encoded CoachToolResponse string returned for all 5 chip-emitter dispatcher branches — wraps EXISTING helpers, never re-implements them (D-A3-07 NON-NEGOTIABLE)"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py:_run_narrator_with_gate (~line 4519-4617)"
      to: "_synthesize_handshake_fallback(hint_fr)"
      pattern: "if loop_result.answer is empty AND last tool_result.status == 'incomplete' → loop_result.answer = _synthesize_handshake_fallback(last_tool_result.hint_fr); emit Sentry breadcrumb coach.tool.incomplete with fallback_used=true. Reads from loop_result['tool_results'] which is exposed in _run_agent_loop's return dict (line 3773 — see Task A3.5 Step 6a)."
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py:_run_agent_loop (user-reply turn branch)"
      to: "save_insight write path at lines 2443-2478"
      pattern: "extract_profile_facts(user_message, profile) → filter (fact.confidence >= 0.75) → facts_to_insight_rows(filtered_facts, user_id) → for row: upsert CoachInsightRecord in the SAME db session BEFORE returning the loop_result; commit at the existing outer turn-end commit point (NO new commit inside the helper per D-A3-03 « single transaction »). Low-confidence facts go to pending_low_confidence_echoes for narrator confirmation, NOT to pending_profile_updates."
    - from: "services/backend/app/services/coach/citation_grammar.py:_TOOL_USE_MANDATE + _TOOL_USE_MANDATE_REPEAT"
      to: "(~28-token pointer string)"
      pattern: "literal substring « Pour chaque outil, lis le champ `description` : il liste les champs profil requis et la procédure si un champ manque. » embedded in BOTH constants (TOP + BOTTOM, Liu 2024 mitigation)"
---

<objective>
Wire the « missing-fields handshake » into the agent loop so Sonnet 4.5 NEVER returns `message: ""` when the user's profile lacks the inputs a tool needs. Instead, the tool returns a structured `CoachToolResponse(status="incomplete", missing_fields=[...], hint_fr=...)` payload; the narrator's tool description instructs it to ask the user explicitly in French; the user's next-turn reply is parsed by the existing `profile_extractor`, only high-confidence facts (`confidence >= 0.75`) are stuffed into a turn-local cache for the in-turn tool retry AND upserted to `CoachInsightRecord` via the existing `save_insight` code path — all inside the same SQLAlchemy session, sharing the existing outer turn-end commit, before the narrator's final reply ships to Flutter. Low-confidence captures (bare-number AVS, etc.) land in a sibling `pending_low_confidence_echoes` list so the narrator can issue a confirmation echo (« J'ai noté 8 années — c'est bien ça ? ») instead of silently poisoning the cache. A server-side floor (`_synthesize_handshake_fallback`) catches the residual Sonnet failure mode where the narrator still emits empty content despite the instruction — it reads from `_run_agent_loop`'s newly-exposed `tool_results` return-dict key (was previously buffered locally only).

This is the SECOND half of the wiki-direction pivot Julien locked in 2026-05-15:
- Wave A2 (MERGED 2026-05-15 sha 28627863) — cut legacy RAG for tool-eligible intents → killed the « consulte ahv-iv.ch » redirect signal. Confirmed mechanically successful (PR #639). Live probe with blank-profile shows `message: ""` + `toolCalls: null` because no tool can fire without profile data.
- Wave A2.1 (MERGED 2026-05-15 sha 37fbd889) — guarded `if n_results > 0:` at `orchestrator.py:100` so the FAQ fallback doesn't re-add redirect chunks when the gate fires.
- Wave A3 (THIS PLAN) — backend contract for incomplete payloads + per-tool description instruction + turn-local persistence + 5-test floor + 1 Maestro flow. ~6 dev days of work compressed into one PR per D-A3-04.
- Wave B (separate plan, post-A3 G2 green) — the parent-phase regression-test floor (5 artifacts per D-05) consumes A3's output.
- Wave C (separate plan, post-B) — instrumentation teardown.

Output: 1 PR on `feature/wave-1c-A3-missing-fields-handshake` → `dev`, ~10 files touched (6 backend, 4 test). Commit structure per D-A3-04: 1 contract commit (`feat(wave-1c-A3): CoachToolResponse Pydantic envelope`) + 5 tool-specific commits (one per chip-emitter wiring) + 1 instruction + 1 grammar pointer + 1 extractor + 1 persistence + 1 fallback + tests. Squash on merge.

**CRITICAL CONTEXT.md DRIFT — surface immediately**

CONTEXT.md §D-A3-04 lists "6 chip-emitters" with names `get_3a_cap` and `get_avs_age_reference`. These two names DO NOT EXIST in the codebase. Verified 2026-05-16 via `grep -n '"name": "get_' services/backend/app/services/coach/coach_tools.py` → the 5 actually-defined chip-emitters are: `get_budget_status` (line 637), `get_retirement_projection` (line 653), `get_cross_pillar_analysis` (line 669), `get_cap_status` (line 685), `get_couple_optimization` (line 701). The Wave A2 plan's `_TOOL_ELIGIBLE_TOOL_NAMES` frozenset at `coach_chat.py:1564-1573` confirms this 5-name canonical set.

**Resolution for this PLAN**: Scope A3 to the 5 actual chip-emitters. The Maestro flow keeps the `_6_tools.yaml` filename per CONTEXT.md §D-A3-05 but contains 5 sub-scenarios; the sixth slot is reserved for a future `get_regulatory_constant` extension (A3.2 territory). All test artifacts iterate over the 5 actual names. The `MISSING_FIELDS_INSTRUCTION_FR` is injected into 5 `description` fields, not 6.

`get_regulatory_constant` (line 722) is EXCLUDED from A3: it takes a `key` parameter and looks up a Swiss constant from a static registry — it does NOT consume user-profile fields, so the missing-fields handshake is a no-op for it.

**CRITICAL TEST PATH CORRECTION (revision iteration 1)**

The prior plan referenced `services/backend/tests/test_coach_chat/` and `services/backend/tests/test_coach_tools/` subdirectories. Those directories DO NOT EXIST in the repo. Verified 2026-05-16 via `ls services/backend/tests/` + `find services/backend/tests -type d`:

- Existing coach-test convention is the FLAT pattern: `tests/test_coach_chat_endpoint.py`, `tests/test_coach_tools_budget_snapshot.py`, `tests/test_coach_tools_retirement_projection.py`, etc. directly under `tests/`.
- Subdirectories under `tests/` that exist: `coach/`, `test_coach_citation/`, `test_coach_tools_pkg/`, `test_citation_gate/`, `test_chat_as_verb/`, `test_dag_invalidation/` — none match the prior plan's paths.

This plan's 4 new test files use the flat convention to align with how the rest of the coach-tools test corpus is laid out. The Maestro YAML path is unchanged (`tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml` is correct).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md

Backend-only PR. No Flutter touch. Pure French copy edits on tool descriptions + one ~28-token pointer in `citation_grammar.py` (LSFin + accent gates apply). Pre-push design panel per D-A3-10: `security-auditor` + `qa-expert` + `ai-engineer` + `prompt-engineer` + `architect-review` — convened in PARALLEL via Task tool after lints green, before `gh pr create`. Verdict ladder per Task A3.7 step 4 (3-tier severity, NOT « PASS clean only »).

CI polling: inline per memory `feedback_no_wakeup_active_polling`. No ScheduleWakeup. Merge via `gh pr merge --squash --delete-branch` on green.

D-A3-09 5-gate exit applies:
- G1 = `tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml` shows for each of the 5 chip-emitters: blank profile → narrator French question → Maestro types reply → narrator emits real `tool_use` + chip on retry. Cite `idb ui describe-all` snapshot OR Maestro JUnit XML.
- G2 = Julien runs the flow on a sim, sees chips render on all 5, confirms in chat.
- G3 = `gh pr checks <N>` shows ALL jobs `pass` at merge.
- G4 = `pytest -q` exit 0 + `flutter test` exit 0 cited.
- G5 = `tools/checks/banned_terms_python.py` + `tools/checks/accent_lint_fr.py` exit 0 on all touched backend files + lefthook gates (memory-retention, wiki-lint, banned-terms-arb, arb-parity if applicable — A3 adds no ARB key).

0-trust caveat per CLAUDE.md §9.5: this plan and the PR it produces use only `PR opened`, `merged to dev`, `pytest exit 0`, `lints exit 0` claim language. Never `shipped`, `ready`, `works`, `validated`, `green` (about runtime) without the matching `idb`/`Maestro`/`curl` snapshot in the same message.
</execution_context>

<context>
@CLAUDE.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-CONTEXT.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A2-PLAN.md
@services/backend/app/services/coach/coach_tools.py
@services/backend/app/services/coach/profile_extractor.py
@services/backend/app/services/coach/citation_grammar.py
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/models/coach_tools/retirement_projection.py
@services/backend/app/models/coach_insight.py
@services/backend/app/models/profile_model.py
@services/backend/tests/coach/test_claude_retry.py

<interfaces>
<!-- Key types and contracts the executor needs. Extracted from codebase 2026-05-16. -->
<!-- Executor should use these directly — no codebase exploration needed. -->

From services/backend/app/services/coach/coach_tools.py (chip-emitter entries verified):
```python
# Line 637-651
{"name": "get_budget_status", "category": "read", "access_level": "user_scoped",
 "description": "Get the user's current budget status including monthly free margin, ...",
 "input_schema": {"type": "object", "properties": {}, "required": []}}
# Line 653-667
{"name": "get_retirement_projection", "category": "read", "access_level": "user_scoped",
 "description": "Get the user's retirement projection including replacement rate, ...",
 "input_schema": {"type": "object", "properties": {}, "required": []}}
# Line 669-683
{"name": "get_cross_pillar_analysis", ...}
# Line 685-699
{"name": "get_cap_status", ...}
# Line 701-717
{"name": "get_couple_optimization", ...}
```
All 5 chip-emitters currently have `"properties": {}` + `"required": []` — they take ZERO LLM-supplied arguments and read from `profile_context` server-side. A3 adds the missing-fields handshake at the `description` level (LLM-visible) and at the dispatcher level (server-side payload shape).

From services/backend/app/services/coach/profile_extractor.py:
```python
@dataclass(frozen=True)
class Fact:
    topic: str
    insight_type: str  # "fact" | "decision" | "preference"
    text: str
    value: Any = None
    confidence: float = 1.0   # NOTE: float, not Literal — existing convention
                              # Wave A3 maps « low/medium/high » planning-shorthand to 0.5 / 0.75 / 1.0

def _extract_lpp(msg: str) -> Fact | None: ...   # line 407 — mirror pattern for _extract_avs_years
_EXTRACTORS = (_extract_age, _extract_salary, _extract_canton_or_city,
               _extract_marital_status, _extract_family, _extract_lpp,
               _extract_pillar3a, _extract_debt)   # line 488 — tuple append point
def extract_profile_facts(user_message: str,
                          current_profile: dict[str, Any] | None = None) -> list[Fact]
def facts_to_insight_rows(facts: Iterable[Fact], *, user_id: str) -> list[dict[str, Any]]
```

Existing extractor topics returned by `_EXTRACTORS` (verified via grep `topic=` in profile_extractor.py):
- `_extract_age` → topic `"identity"` (value = age int)
- `_extract_salary` → topic `"salary"` (value = annual CHF int)
- `_extract_canton_or_city` → topic `"location"` (value = ISO code or city string)
- `_extract_marital_status` → topic `"household"` (value = marital label)
- `_extract_family` → topic `"family"` (value = int count of children OR True for « j'ai des enfants ») — see lines 385-396
- `_extract_lpp` → topic `"lpp"` (value = CHF int)
- `_extract_pillar3a` → topic `"3a"` (value = CHF int)
- `_extract_debt` → topic `"debt"` (value = bool)

From services/backend/app/api/v1/endpoints/coach_chat.py (verbatim signatures verified 2026-05-16 via `grep -nE "^(async )?def (_compute_|_format_cap_status|_run_agent_loop)" coach_chat.py`):
```python
# Line 2403-2425 — current dispatcher branches (5 chip-emitters) verbatim:
if name == "get_budget_status":
    return _compute_budget_status(user_id=user_id, ctx=ctx, db=db)
if name == "get_retirement_projection":
    return _compute_retirement_projection(user_id=user_id, ctx=ctx, db=db)
if name == "get_cross_pillar_analysis":
    return _compute_cross_pillar_analysis(user_id=user_id, ctx=ctx, db=db)
if name == "get_cap_status":
    return _validate_cap_response(_format_cap_status(ctx))
if name == "get_couple_optimization":
    return _compute_couple_optimization(user_id=user_id, ctx=ctx, db=db)

# Helper signatures (D-A3-07 financial_core mirror — UNCHANGED by A3):
def _compute_budget_status(user_id: str | None, ctx: dict, db) -> str:           # line 2772
def _compute_retirement_projection(user_id: str | None, ctx: dict, db) -> str:   # line 2876
def _compute_cross_pillar_analysis(user_id: str | None, ctx: dict, db) -> str:   # line 3000
def _format_cap_status(ctx: dict) -> str:                                        # line 3180
def _compute_couple_optimization(user_id, ctx: dict, db) -> str:                 # line 3211
async def _run_agent_loop(...):                                                  # line 3458

# Line 3699 — tool_results local list initialized at agent-loop start
# Line 3737 — tool_results.append(...) populates the list during iteration
# Line 3773 — _run_agent_loop return dict — CURRENT shape (pre-A3):
return {
    "answer": final_answer,
    "tool_calls": flutter_tool_calls if flutter_tool_calls else None,
    "citation_chips": citation_chips if citation_chips else None,
    "sources": unique_sources,
    "disclaimers": list(set(all_disclaimers)),
    "tokens_used": total_tokens,
    "degraded": degraded_any,
    "model_used": model_used_last,
}
# A3 ADDS "tool_results": tool_results to this dict — see Task A3.5 Step 6a.

# Line 2443-2478 — save_insight write path (REUSE; do NOT duplicate).
if name == "save_insight":
    summary = tool_input.get("summary") or tool_input.get("insight") or ""
    topic = tool_input.get("topic", "general")
    insight_type = tool_input.get("type") or tool_input.get("insight_type") or "fact"
    if user_id and db:
        existing = db.query(CoachInsightRecord).filter(
            CoachInsightRecord.user_id == user_id,
            CoachInsightRecord.topic == topic,
        ).first()
        now = datetime.now(timezone.utc)
        if existing:
            existing.summary = summary; existing.insight_type = insight_type; existing.updated_at = now
        else:
            db.add(CoachInsightRecord(user_id=..., topic=topic, summary=summary, insight_type=insight_type))
        # NOTE: there is a db.commit() inside this `save_insight` branch at the existing pattern.
        # A3's _upsert_handshake_facts helper REUSES the in-session add/update logic but DOES NOT
        # introduce a NEW db.commit() — it relies on the outer turn-end commit (D-A3-03 single transaction).
        # See I-04 fix in Task A3.5 Step 4(c).

# Line 4519-4617 — _run_narrator_with_gate. Wire site for _synthesize_handshake_fallback.
# Line 1100 — _build_insight_memory_block(user_id, db) — reads CoachInsightRecord rows for system-prompt injection.
# Line 1547-1573 — _TOOL_ELIGIBLE_INTENTS + _TOOL_ELIGIBLE_TOOL_NAMES (A2 ship — canonical 5-name source of truth).
```

From services/backend/app/models/profile_model.py (verified 2026-05-16):
```python
class ProfileModel(Base):
    __tablename__ = "profiles"
    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)
    data = Column(MutableDict.as_mutable(JSONEncodedDict), nullable=False)  # full profile as JSON dict
    created_at = Column(DateTime, ...)
    updated_at = Column(DateTime, ...)
```
**Key insight**: ProfileModel stores the entire profile as a JSON `data` dict — NO typed schema columns. The canonical profile keys are camelCase strings inside `data` (e.g. `incomeNetMonthly`, `avsContributionYears`, `pillar3aBalance`, `lppBalance`, `monthlyExpenses`, `birthYear`, `incomeGrossYearly`) per `coach_chat.py:1720-1747` (the `_AUGMENTABLE_KEYS` / `_HINT_KEYS` constants).

Children/family canonical key (used by `_compute_*` helpers + LLM context augmentation): **`number_of_children`** (snake_case — verified at `coach_chat.py:875` in the `_AUGMENTABLE_FACT_NAMES` list; also used as `children_count` in `next_steps_service.py:256`). There is NO `dependentsCount` field anywhere in the codebase (I-09 fix: map `family` topic → `number_of_children`, NOT to `dependentsCount`).

From services/backend/app/models/coach_insight.py:
```python
class CoachInsightRecord(Base):
    __tablename__ = "coach_insights"
    id: str (uuid)
    user_id: str (FK users.id, indexed)
    topic: str         # dedup key — A3 uses prefix "profile.<canonical_field>" per D-A3-03 (e.g. "profile.avs_contribution_years")
    summary: str       # value + provenance inline per D-A3-03 (e.g. "320'000 CHF (source: handshake, raw: '...', captured: 2026-05-16T14:32Z)")
    insight_type: str  # "fact" for handshake captures
    __table_args__ = (Index("ix_coach_insights_user_topic", "user_id", "topic"),)
```

From services/backend/app/models/coach_tools/retirement_projection.py (sibling pattern for _response.py):
```python
class RetirementProjectionResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True)
    replacement_ratio: float
    avs_rente: Decimal
    ...
```
The new `_response.py` follows the same camelCase + frozen + alias_generator pattern.

From services/backend/tests/coach/test_claude_retry.py (verified 2026-05-16 — THIS is the existing Anthropic mock pattern to reuse in Task A3.6 test_narrator_asks_on_incomplete.py):
```python
from unittest.mock import AsyncMock, MagicMock, patch
import anthropic

# Pattern: patch.object(anthropic, "APIStatusError", _FakeStatusError, create=False)
# Pattern: fake_client = MagicMock(); fake_client.messages.create = AsyncMock(side_effect=fake_create)
# Pattern: _make_ok_response builds a MagicMock with .content = [MagicMock(type="text", text=text)] + .usage

def _make_ok_response(text: str = "ok"):
    msg = MagicMock()
    msg.content = [MagicMock(type="text", text=text)]
    msg.usage = MagicMock(input_tokens=10, output_tokens=5)
    return msg

@pytest.mark.asyncio
async def test_retries_on_529_and_succeeds():
    fake_client = MagicMock()
    fake_client.messages.create = AsyncMock(side_effect=fake_create)
    ...
```
Wider search (`grep -rln "AsyncMock\|patch.*anthropic" services/backend/tests/`) shows the same pattern is also used by `test_document_classification.py`, `test_coverage_gaps_diff.py`, `test_premier_eclairage_doc.py`, `test_lpp_plan_type.py`. A3 reuses verbatim — does NOT introduce respx, httpx_mock, or any other harness.

Canonical profile field names used in `missing_fields` lists (camelCase, must match ProfileModel.data dict keys):
- `age` (extractor topic `"identity"`; ProfileModel key `birthYear` — A3 maps int age to `birthYear` if profile dict expects birthYear, otherwise stores `age` directly per the existing dispatcher pattern at `coach_chat.py:2935-2940` which reads `profile.data.get("avsContributionYears")` style)
- `avsContributionYears` (NEW topic `"avs_years"` from _extract_avs_years)
- `lppBalance` (extractor topic `"lpp"`)
- `pillar3aBalance` (extractor topic `"3a"`)
- `incomeGrossYearly` (extractor topic `"salary"`)
- `monthlyExpenses` (read from profile by _compute_budget_status; no extractor — narrator-collected via handshake)
- `incomeNetMonthly` (read from profile by _compute_budget_status; narrator-collected)
- `number_of_children` (extractor topic `"family"` — snake_case here per the canonical fact list at coach_chat.py:875; I-09 fix)
</interfaces>

<diagnosis_evidence>
- Wave A2 + A2.1 MERGED 2026-05-15. The RAG cut works mechanically: `_build_augmented_message` no longer prepends the « consulte ahv-iv.ch » chunks. Confirmed via `payload-2026-05-15-A2-2219.jsonl` (104-char clean user message reaches the LLM).
- Live probe 2026-05-15 22:40 CEST: `probe-2026-05-15-A21-2240.json` → `message: ""`, `toolCalls: null`, `citationChips: null`, `tokensUsed: 16663`. THIS is the bug A3 fixes.
- Root cause: Sonnet 4.5 sees a clean retirement question but the 5 chip-emitters all have `"required": []` AND read from `profile_context`. With a blank profile, the tool would compute zeros/nulls. The model declines to invoke (no `tool_use` block, `stop_reason=end_turn`, empty `message`). Wave A1's 3-position MANDATE in the system prompt does not beat this — the instruction is semantically detached from the tool_use decision point. Per Panel #2 + Anthropic 2025 « Advanced tool use » blog, the fix is to land the instruction AT the tool description, with a concrete `tool_use` example sequence.
- The structural pre-condition for A3 (clean unaugmented user message) is in place. A3 builds on it.
</diagnosis_evidence>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task A3.1 — Wave 1: Create CoachToolResponse Pydantic v2 envelope (shared contract)</name>
  <files>services/backend/app/models/coach_tools/_response.py</files>
  <read_first>
    - services/backend/app/models/coach_tools/retirement_projection.py (sibling pattern — ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True); confirm import path `pydantic.alias_generators.to_camel`).
    - services/backend/app/models/coach_tools/__init__.py (confirm no re-export pattern; A3 leaves it as-is).
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-CONTEXT.md §D-A3-01 (full contract spec — RootModel + Annotated Union + discriminator="status"; CoachToolIncomplete fields; LSFin-clean hint_fr requirement; cap=3 on missing_fields).
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2400-2430 (current dispatcher return shape — strings only today; A3 changes this to JSON of the new model).
  </read_first>
  <behavior>
    - `python3 -c "from app.models.coach_tools._response import CoachToolResponse, CoachToolOk, CoachToolIncomplete, CoachToolPolicyBlocked"` exits 0 (run from `services/backend`).
    - `python3 -c "from app.models.coach_tools._response import CoachToolResponse; import json; r = CoachToolResponse.model_validate({'status': 'incomplete', 'missingFields': ['age', 'avsContributionYears'], 'hintFr': 'Pour calculer ta rente AVS, j ai besoin de ton age et de tes annees de cotisation AVS.'}); print(r.model_dump_json(by_alias=True))"` exits 0 and prints camelCase JSON with `"status":"incomplete"`.
    - Cap=3 validator: `CoachToolResponse.model_validate({"status":"incomplete","missingFields":["a","b","c","d"],"hintFr":"x"})` raises `pydantic.ValidationError`.
    - `python3 -c "from app.models.coach_tools._response import CoachToolResponse; CoachToolResponse.model_validate({'status': 'invalid_status'})"` raises `pydantic.ValidationError` (discriminator-locked).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/models/coach_tools/_response.py` exit 0 (no `garanti / optimal / meilleur / certain / assuré / sans risque / parfait`).
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/models/coach_tools/_response.py` exit 0 (any default `hint_fr` example string in docstrings must use FR accents).
  </behavior>
  <action>
    Create `services/backend/app/models/coach_tools/_response.py` from scratch. Use the verbatim sibling pattern from `retirement_projection.py` (ConfigDict + alias_generator=to_camel + frozen=True).

    ```python
    """Wave 1c-A3 (D-A3-01) — shared response envelope for coach internal tools.

    Discriminated-union Pydantic v2 RootModel keyed on `status`. Tool dispatchers
    in `app.api.v1.endpoints.coach_chat._execute_tool` return a JSON-encoded
    instance of this model (via `.model_dump_json(by_alias=True)`) as the
    `tool_result.content` payload.

    Rationale (see `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-
    CONTEXT.md` §D-A3-01): when a chip-emitter cannot compute because the user
    profile lacks required fields, returning a structured `status="incomplete"`
    payload (NOT a typed exception, NOT `is_error: true`) preserves coaching
    register and lets the narrator ask the user explicitly. Data gaps are not
    tool failures.

    LSFin compliance (CLAUDE.md §1 + §5 NEVER #5): any default `hint_fr` text
    embedded in fixtures / docstrings stays clear of « garanti / optimal /
    meilleur / certain / assuré / sans risque / parfait ». 100% French accents.
    """
    from __future__ import annotations

    from typing import Annotated, Any, Literal, Union

    from pydantic import BaseModel, ConfigDict, Field, RootModel, field_validator
    from pydantic.alias_generators import to_camel


    _MAX_MISSING_FIELDS = 3   # D-A3-01 conversational handshake cap


    class _Base(BaseModel):
        model_config = ConfigDict(
            populate_by_name=True,
            alias_generator=to_camel,
            frozen=True,
        )


    class CoachToolOk(_Base):
        """Happy path. `data` carries the existing per-tool payload unchanged."""

        status: Literal["ok"] = "ok"
        data: dict[str, Any]


    class CoachToolIncomplete(_Base):
        """Profile lacks required inputs. Narrator must ask the user."""

        status: Literal["incomplete"] = "incomplete"
        missing_fields: list[str] = Field(..., min_length=1)
        hint_fr: str = Field(..., min_length=10)

        @field_validator("missing_fields")
        @classmethod
        def _cap_missing_fields(cls, v: list[str]) -> list[str]:
            if len(v) > _MAX_MISSING_FIELDS:
                raise ValueError(
                    f"missing_fields capped at {_MAX_MISSING_FIELDS} per "
                    "conversational-handshake decision D-A3-01"
                )
            return v


    class CoachToolPolicyBlocked(_Base):
        """Future LSFin/FINMA gate. Defined now to avoid a second migration."""

        status: Literal["policy_blocked"] = "policy_blocked"
        reason_code: str
        message_fr: str


    CoachToolResponse = RootModel[
        Annotated[
            Union[CoachToolOk, CoachToolIncomplete, CoachToolPolicyBlocked],
            Field(discriminator="status"),
        ]
    ]
    ```

    Note: keep the file LIBRARY-pure (no DB import, no Anthropic import). The dispatcher in coach_chat.py imports `CoachToolResponse`, `CoachToolOk`, `CoachToolIncomplete`.
  </action>
  <acceptance_criteria>
    - File created at exact path.
    - All 4 import asserts in &lt;behavior&gt; exit 0.
    - Lints exit 0.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -c "from app.models.coach_tools._response import CoachToolResponse, CoachToolOk, CoachToolIncomplete, CoachToolPolicyBlocked; r = CoachToolResponse.model_validate({'status':'incomplete','missingFields':['age','avsContributionYears'],'hintFr':'Pour calculer ta rente AVS, j ai besoin de ton age.'}); j = r.model_dump_json(by_alias=True); assert 'status' in j and 'incomplete' in j; ok = CoachToolResponse.model_validate({'status':'ok','data':{}}); print('OK')"</automated>
  </verify>
  <done>
    `CoachToolResponse` + 3 variants importable, validator enforces cap=3, camelCase JSON dump works, lints exit 0.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A3.2 — Wave 2 (parallel): Inject MISSING_FIELDS_INSTRUCTION_FR + Anthropic Tool-Use Example into 5 chip-emitter descriptions</name>
  <files>services/backend/app/services/coach/coach_tools.py</files>
  <read_first>
    - services/backend/app/services/coach/coach_tools.py lines 630-720 (the 5 chip-emitter dicts verbatim — `get_budget_status` 637, `get_retirement_projection` 653, `get_cross_pillar_analysis` 669, `get_cap_status` 685, `get_couple_optimization` 701; ALL have `"properties": {}` + `"required": []`).
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-CONTEXT.md §D-A3-02 (canonical `MISSING_FIELDS_INSTRUCTION_FR` template verbatim + Tool-Use Example mandate per Anthropic 2025 « Advanced tool use » blog) + §Claude's Discretion (recommended hint_fr templates for 3 of the 5 tools).
    - CLAUDE.md §1 (LSFin banned terms full list — apply to every FR string drafted in this task).
    - CLAUDE.md §5 NEVER #5 (`check_banned_terms()` MCP invocation requirement for any new FR copy).
  </read_first>
  <behavior>
    - `grep -n "MISSING_FIELDS_INSTRUCTION_FR" services/backend/app/services/coach/coach_tools.py` returns ≥6 matches (1 constant def + 5 per-tool `.format()` injections).
    - `grep -n "required_fields_csv" services/backend/app/services/coach/coach_tools.py` returns 1 match (the f-string placeholder in the constant).
    - `python3 -c "from app.services.coach.coach_tools import COACH_TOOLS, MISSING_FIELDS_INSTRUCTION_FR; chips = {'get_budget_status','get_retirement_projection','get_cross_pillar_analysis','get_cap_status','get_couple_optimization'}; print(len([t for t in COACH_TOOLS if t['name'] in chips and 'Champs profil requis' in t['description']]))"` prints `5`.
    - **I-03 fix — import-time `.format()` smoke test (mandatory):** `cd services/backend && python3 -c "from app.services.coach.coach_tools import MISSING_FIELDS_INSTRUCTION_FR; out = MISSING_FIELDS_INSTRUCTION_FR.format(required_fields_csv='age, avsContributionYears'); assert 'age' in out and 'status' in out and 'incomplete' in out, out; print('format-smoke OK')"`. This guards against ANY literal `{` or `}` slipping in unescaped — the embedded example JSON MUST use `{{` and `}}` everywhere.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/coach_tools.py` exit 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/coach_tools.py` exit 0.
    - `python3 -c "from app.services.coach.coach_tools import MISSING_FIELDS_INSTRUCTION_FR; assert 'tool_use' in MISSING_FIELDS_INSTRUCTION_FR.lower() or 'incomplete' in MISSING_FIELDS_INSTRUCTION_FR.lower(); assert 'exemple' in MISSING_FIELDS_INSTRUCTION_FR.lower() or 'example' in MISSING_FIELDS_INSTRUCTION_FR.lower()"` exits 0 (the embedded Tool-Use Example sequence is present).
  </behavior>
  <action>
    1. Add the module-level constant `MISSING_FIELDS_INSTRUCTION_FR` near the top of `coach_tools.py` (after the existing imports + ToolCategory enum, before the COACH_TOOLS list). Verbatim template per CONTEXT.md §D-A3-02 + concrete Anthropic Tool-Use Example sequence:

       ```python
       # Wave 1c-A3 (D-A3-02) — missing-fields handshake instruction.
       # Injected verbatim into the `description` field of every chip-emitter tool
       # (get_budget_status, get_retirement_projection, get_cross_pillar_analysis,
       # get_cap_status, get_couple_optimization). Source of truth — drift-guarded
       # by tests/test_coach_tools_missing_fields_instruction.py.
       #
       # Per Anthropic 2025 « Advanced tool use » (https://www.anthropic.com/
       # engineering/advanced-tool-use) the embedded Tool-Use Example sequence is
       # what Sonnet 4.5 actually picks up reliably — abstract instructions alone
       # are not enough. The example shows the literal turn flow:
       # blank-profile -> narrator-asks -> user-replies -> tool_use-emits.
       #
       # LSFin (CLAUDE.md §5 NEVER #5): no « garanti / optimal / meilleur / certain
       # / assuré / sans risque / parfait ». Accents 100% FR.
       #
       # I-03 fix: every literal `{` and `}` in the embedded example JSON is doubled
       # (`{{` / `}}`) so the `.format(required_fields_csv=...)` call at registration
       # time does NOT crash on the JSON braces. Import-time smoke test in
       # tests/test_coach_tools_missing_fields_instruction.py pins this.
       MISSING_FIELDS_INSTRUCTION_FR: str = (
           "\n\n## Champs profil requis : {required_fields_csv}\n"
           "Si un champ manque dans le profil de l'utilisateur, ne devine pas, "
           "ne redirige pas vers une ressource externe : pose la question "
           "explicitement à l'utilisateur dans ta réponse texte, et renvoie "
           "un statut « incomplete » au prochain tour via cet outil.\n"
           "\n"
           "### Exemple de séquence (à imiter — pattern Anthropic 2025) :\n"
           "1. Profil utilisateur vide. Question : « Quelle sera ma rente AVS ? »\n"
           "2. Tu invoques `tool_use(get_retirement_projection)`. Le tool_result "
           "renvoie `{{\"status\":\"incomplete\",\"missingFields\":[\"age\",\"avsContributionYears\"],\"hintFr\":\"Pour calculer ta rente AVS, j'ai besoin de ton âge et de tes années de cotisation AVS.\"}}`.\n"
           "3. Tu réponds à l'utilisateur en français : « Pour calculer ta rente "
           "AVS, j'ai besoin de ton âge et de tes années de cotisation AVS. Tu "
           "peux me les partager ? »\n"
           "4. L'utilisateur répond : « 42 ans, 8 années AVS ».\n"
           "5. Tu invoques à nouveau `tool_use(get_retirement_projection)`. Le "
           "tool_result renvoie cette fois `{{\"status\":\"ok\",\"data\":{{...}}}}` "
           "avec les chiffres calculés.\n"
       )
       ```

       Note: the `{{` / `}}` escaping pairs are mandatory because the template will be `.format(required_fields_csv=...)`-rendered later — every literal `{` and `}` in the example JSON must be doubled. The import-time smoke test in `<behavior>` (I-03) hard-fails if any literal brace slips in.

    2. For each of the 5 chip-emitter entries, rewrite the `description` field to APPEND the formatted instruction with the canonical CSV for that tool:

       - `get_budget_status` (line 640-645): `required_fields_csv = "incomeNetMonthly, monthlyExpenses, savingsRate"` — values currently read from `profile_context`. The minimum to compute a non-zero budget is `incomeNetMonthly` + at least one expense line.
       - `get_retirement_projection` (line 656-661): `required_fields_csv = "age, avsContributionYears, lppBalance, pillar3aBalance"` — the 4 canonical fields from CONTEXT.md §D-A3-01.
       - `get_cross_pillar_analysis` (line 672-677): `required_fields_csv = "age, lppBalance, pillar3aBalance, incomeGrossYearly"`.
       - `get_cap_status` (line 688-693): `required_fields_csv = "age, sequenceProgress, hasGoal"` (NOTE: `sequenceProgress` and `hasGoal` are derived server-side, but if both are absent, the tool cannot compute a Cap — handshake at minimum needs `age` for life-event sequencing).
       - `get_couple_optimization` (line 704-711): `required_fields_csv = "age, partnerAge, householdType, lppBalance, partnerLppBalance"`.

       Concrete pattern for each (`get_retirement_projection` shown — repeat for the other 4 with their CSV):

       ```python
       {
           "name": "get_retirement_projection",
           "category": "read",
           "access_level": "user_scoped",
           "description": (
               "Get the user's retirement projection including replacement rate, "
               "projected gap, and pillar breakdown. Use when the user asks about "
               "retirement income, pension, or how much they will receive. "
               "Returns structured data as text. This tool is handled internally."
               + MISSING_FIELDS_INSTRUCTION_FR.format(
                   required_fields_csv="age, avsContributionYears, lppBalance, pillar3aBalance",
               )
           ),
           "input_schema": {
               "type": "object",
               "properties": {},
               "required": [],
           },
       },
       ```

    3. DO NOT touch `get_regulatory_constant` (line 722) — it takes a `key` parameter from a static registry, not user profile data; handshake is a no-op there.

    4. DO NOT touch any non-chip tool (`route_to_screen`, `save_insight`, `set_goal`, etc.) — handshake is irrelevant for those.

  </action>
  <acceptance_criteria>
    - 1 constant def + 5 `.format()` injections → 6+ grep hits.
    - The 5 chip-emitter descriptions each contain « Champs profil requis » AND the « Exemple de séquence » block.
    - Banned-terms + accent lints exit 0.
    - `python3 -c "from app.services.coach.coach_tools import COACH_TOOLS; [t['description'] for t in COACH_TOOLS]"` does NOT raise (Python f-string / .format syntax is valid).
    - I-03 import-time `.format()` smoke test exits 0.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -c "from app.services.coach.coach_tools import COACH_TOOLS, MISSING_FIELDS_INSTRUCTION_FR; chips = {'get_budget_status','get_retirement_projection','get_cross_pillar_analysis','get_cap_status','get_couple_optimization'}; matched = [t for t in COACH_TOOLS if t['name'] in chips and 'Champs profil requis' in t['description'] and 'Exemple de séquence' in t['description']]; assert len(matched) == 5, f'expected 5, got {len(matched)}'; out = MISSING_FIELDS_INSTRUCTION_FR.format(required_fields_csv='age, avsContributionYears'); assert 'age' in out and 'status' in out and 'incomplete' in out, out; print('OK 5 chip-emitters wired + format-smoke OK')" && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/coach_tools.py && python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/coach_tools.py</automated>
  </verify>
  <done>
    Constant defined; all 5 chip-emitter descriptions contain both the « Champs profil requis » header and the concrete Tool-Use Example sequence; import-time `.format()` smoke test passes (I-03 fix); lints exit 0.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A3.3 — Wave 2 (parallel): Add ~28-token pointer inside both TOP and BOTTOM MANDATE blocks of citation_grammar.py</name>
  <files>services/backend/app/services/coach/citation_grammar.py</files>
  <read_first>
    - services/backend/app/services/coach/citation_grammar.py lines 86-122 (`_TOOL_USE_MANDATE` — TOP position ~51% per Wave A1 measurement) + lines 142-158 (`_TOOL_USE_MANDATE_REPEAT` — BOTTOM position ~64%).
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-CONTEXT.md §D-A3-02 (the pointer text + token budget: ~28 tokens × 2 positions = ~56 tokens added — well within the RESEARCH §A4 grammar budget).
    - CLAUDE.md §1 BOTTOM 6 RULES (Liu 2024 lost-in-the-middle mitigation — repeat at TOP + BOTTOM).
  </read_first>
  <behavior>
    - `grep -c "Pour chaque outil, lis le champ" services/backend/app/services/coach/citation_grammar.py` returns `2` (one in TOP block, one in BOTTOM block).
    - `python3 -c "from app.services.coach.citation_grammar import _TOOL_USE_MANDATE, _TOOL_USE_MANDATE_REPEAT; assert 'lis le champ' in _TOOL_USE_MANDATE and 'lis le champ' in _TOOL_USE_MANDATE_REPEAT"` exits 0.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py` exit 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py` exit 0.
  </behavior>
  <action>
    1. Append the pointer line at the END of the `_TOOL_USE_MANDATE` string literal (lines 86-105), just before the closing `)`. Insert as a new paragraph:

       ```python
       _TOOL_USE_MANDATE: str = (
           # ... existing lines 87-104 ...
           "Le `{{cite:tool_<name>}}` n'est PAS une formule magique — c'est une "
           "référence à un calcul serveur qui doit avoir été déclenché via "
           "`tool_use` plus tôt dans ce même tour.\n"
           "\n"
           # Wave 1c-A3 (D-A3-02) — pointer to per-tool `description` field.
           # ~28 tokens. Sister pointer in _TOOL_USE_MANDATE_REPEAT (BOTTOM).
           "Pour chaque outil, lis le champ `description` : il liste les champs "
           "profil requis et la procédure si un champ manque.\n"
       )
       ```

    2. Append the SAME pointer line at the END of the `_TOOL_USE_MANDATE_REPEAT` string literal (lines 142-158):

       ```python
       _TOOL_USE_MANDATE_REPEAT: str = (
           # ... existing lines 143-157 ...
           "Toute formulation du type « j'ai besoin de récupérer tes "
           "données » indique un manquement à cette doctrine.\n"
           "\n"
           # Wave 1c-A3 (D-A3-02) — pointer to per-tool `description` field.
           # ~28 tokens. Mirror of the TOP pointer (Liu 2024 mitigation).
           "Pour chaque outil, lis le champ `description` : il liste les champs "
           "profil requis et la procédure si un champ manque.\n"
       )
       ```

    3. DO NOT alter the existing MANDATE body — surgical addition only per CLAUDE.md §7 #3.
  </action>
  <acceptance_criteria>
    - 2 occurrences of « Pour chaque outil, lis le champ » in the file.
    - Both constants import-clean.
    - Lints exit 0.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && grep -c "Pour chaque outil, lis le champ" services/backend/app/services/coach/citation_grammar.py | grep -q "^2$" && python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py && python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py && echo OK</automated>
  </verify>
  <done>
    Pointer present in both TOP and BOTTOM MANDATE constants; lints exit 0.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A3.4 — Wave 2 (parallel): Add _extract_avs_years to profile_extractor.py (mirror of _extract_lpp, AVS-anchor MANDATORY)</name>
  <files>services/backend/app/services/coach/profile_extractor.py</files>
  <read_first>
    - services/backend/app/services/coach/profile_extractor.py lines 407-429 (`_extract_lpp` — verbatim mirror pattern; same regex shape, same Fact return type, same numeric range guard).
    - services/backend/app/services/coach/profile_extractor.py lines 488-497 (`_EXTRACTORS` tuple — A3 appends `_extract_avs_years` to it).
    - services/backend/app/services/coach/profile_extractor.py lines 32-59 (`Fact` dataclass — NOTE: `confidence: float = 1.0`, NOT a Literal; CONTEXT.md §D-A3-03 « confidence low/medium/high » maps to float values 0.5 / 0.75 / 1.0 for type compatibility).
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-CONTEXT.md §D-A3-03 (closed list of AVS-anchor keywords: `AVS`, `cotisation`, `1er pilier`, `premier pilier`; MANDATORY anchor per I-01 fix — bare-number fallback is DELETED so off-topic « 42 ans » never poisons the AVS slot).
    - I-01 + I-07 fixes (this revision): AVS-anchor keyword is MANDATORY; interstitial cap tightened to `[^,.]{0,25}` so commas do not bridge unrelated clauses; the bare `\b\d{1,2}\s*ans\b` fallback regex is REMOVED entirely.
  </read_first>
  <behavior>
    - `python3 -c "from app.services.coach.profile_extractor import _extract_avs_years, _EXTRACTORS; assert _extract_avs_years in _EXTRACTORS"` exits 0.
    - **I-01 fix — AVS-anchor MANDATORY (high-confidence):** `python3 -c "from app.services.coach.profile_extractor import _extract_avs_years; f = _extract_avs_years('j ai cotise 8 annees AVS'); assert f is not None and f.topic == 'avs_years' and f.value == 8 and f.confidence >= 0.9"` exits 0.
    - **I-01 fix — bare-number returns None (no off-topic poisoning):** `python3 -c "from app.services.coach.profile_extractor import _extract_avs_years; f = _extract_avs_years('j ai 42 ans, ma fille a 12 ans'); assert f is None, f'expected None for off-topic age/child phrase, got {f}'"` exits 0.
    - **I-01 fix — bare « 8 ans » alone returns None (no AVS anchor):** `python3 -c "from app.services.coach.profile_extractor import _extract_avs_years; f = _extract_avs_years('8 ans'); assert f is None, f'bare 8 ans without AVS anchor must return None, got {f}'"` exits 0.
    - **I-07 fix — comma boundary respected:** `python3 -c "from app.services.coach.profile_extractor import _extract_avs_years; f = _extract_avs_years('j ai 42 ans, je suis salarie, AVS 8 ans'); assert f is not None and f.value == 8, f'expected value==8 for AVS-anchored 8 across commas, got {f}'"` exits 0 (anchor BEFORE number variant, commas in interstitial are now blocked by `[^,.]{0,25}` — so the regex matches the `AVS 8 ans` segment directly, NOT the leading `42 ans`).
    - `python3 -c "from app.services.coach.profile_extractor import _extract_avs_years; f = _extract_avs_years('je nai jamais cotise'); assert f is None"` exits 0 (no number).
    - Backend pytest does not regress: `cd services/backend && python3 -m pytest tests/ -q -x` exit 0 (full suite — there is no `tests/test_coach_chat/` subdir; flat convention).
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/profile_extractor.py` exit 0.
  </behavior>
  <action>
    1. Add `_extract_avs_years` just AFTER `_extract_pillar3a` (around line 453, before `_extract_debt`). Verbatim mirror of `_extract_lpp` structure — **AVS-anchor keyword is MANDATORY (I-01 fix), the bare-number fallback regex is DELETED**, interstitial cap tightened to `[^,.]{0,25}` (I-07 fix):

       ```python
       def _extract_avs_years(msg: str) -> Fact | None:
           """Extract AVS contribution years.

           Wave 1c-A3 (D-A3-03). Mirror of `_extract_lpp` pattern. Matches
           « j ai cotise 8 annees AVS », « 8 ans AVS », « 1er pilier 8 ans »,
           « AVS 8 ans ».

           I-01 fix (revision iteration 1): the AVS-anchor keyword
           (avs / cotisation / 1er pilier / premier pilier) is MANDATORY.
           The previous bare-number fallback regex `\\b\\d{1,2}\\s*ans\\b` was
           DELETED because it matched off-topic phrases like « j ai 42 ans, ma
           fille a 12 ans » and silently stuffed 42 into the AVS slot.
           CONTEXT.md §D-A3-03 mandates low-confidence handshake captures go
           to a separate `pending_low_confidence_echoes` list (handled by the
           caller in coach_chat.py) — never to `pending_profile_updates`.

           I-07 fix (revision iteration 1): interstitial cap tightened from
           `[^.]{0,40}` to `[^,.]{0,25}` so commas + periods both act as
           clause boundaries — « j ai 42 ans, AVS 8 ans » no longer lets the
           anchor reach back to 42 across the comma.

           Confidence model: when an AVS-anchor matches, confidence is 1.0.
           No low-confidence path exists in this extractor today — by the
           time A3 ships, ALL AVS captures are high-confidence (the
           pending_low_confidence_echoes machinery is reserved for future
           extractors where the anchor IS optional, per CONTEXT.md §D-A3-03).

           Closed-list keywords per Karpathy-2 simplicity (CONTEXT.md
           §D-A3-03 Claude's Discretion). No LLM call.
           """
           # Pattern 1: number BEFORE anchor — « 8 années AVS », « 8 ans cotisation »
           m = re.search(
               r"\b(\d{1,2})\s*(?:ann[ée]es?|ans|years?)\b[^,.]{0,25}"
               r"(?:avs|cotisation|1er\s+pilier|premier\s+pilier)",
               msg,
               re.IGNORECASE,
           )
           # Pattern 2: anchor BEFORE number — « AVS 8 ans », « 1er pilier 8 années »
           if not m:
               m = re.search(
                   r"(?:avs|cotisation|1er\s+pilier|premier\s+pilier)"
                   r"[^,.]{0,25}(\d{1,2})\s*(?:ann[ée]es?|ans|years?)",
                   msg,
                   re.IGNORECASE,
               )
           # NO bare-number fallback — I-01 fix. If no anchor match, return None.
           if m:
               try:
                   years = int(m.group(1))
               except (ValueError, IndexError):
                   return None
               if 0 <= years <= 55:
                   return Fact(
                       topic="avs_years",
                       insight_type="fact",
                       text=f"AVS ≈ {years} années de cotisation",
                       value=years,
                       confidence=1.0,
                   )
           return None
       ```

    2. Append `_extract_avs_years` to the `_EXTRACTORS` tuple at line 488 (BEFORE `_extract_debt` so the canonical 9-tuple order is preserved for determinism):

       ```python
       _EXTRACTORS = (
           _extract_age,
           _extract_salary,
           _extract_canton_or_city,
           _extract_marital_status,
           _extract_family,
           _extract_lpp,
           _extract_pillar3a,
           _extract_avs_years,   # Wave 1c-A3 (D-A3-03) — AVS-anchor MANDATORY (I-01 fix)
           _extract_debt,
       )
       ```

    3. DO NOT alter `Fact` dataclass (`confidence: float`) — A3 sticks to the existing float convention. The CONTEXT.md « low/medium/high » literal is a planning-shorthand; here it maps to `0.5 / 0.75 / 1.0` for any future extractor that needs the low-confidence path. The current `_extract_avs_years` returns ONLY high-confidence facts (anchor-mandatory).
  </action>
  <acceptance_criteria>
    - `_extract_avs_years` defined with NO bare-number fallback (I-01 fix).
    - Interstitial `[^,.]{0,25}` in both anchor patterns (I-07 fix).
    - Added to `_EXTRACTORS` tuple.
    - All 6 behavioral asserts in &lt;behavior&gt; pass (including the « 42 ans, ma fille a 12 ans » → None fixture and the « 42 ans, je suis salarié, AVS 8 ans » → 8 fixture).
    - No regression in backend pytest (full suite, flat tests/ convention).
    - Accent lint exit 0.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -c "from app.services.coach.profile_extractor import _extract_avs_years, _EXTRACTORS; assert _extract_avs_years in _EXTRACTORS; f = _extract_avs_years('j ai cotise 8 annees AVS'); assert f and f.topic == 'avs_years' and f.value == 8; f2 = _extract_avs_years('j ai 42 ans, ma fille a 12 ans'); assert f2 is None, f'I-01: off-topic age must return None, got {f2}'; f3 = _extract_avs_years('8 ans'); assert f3 is None, f'I-01: bare 8 ans must return None, got {f3}'; f4 = _extract_avs_years('j ai 42 ans, je suis salarie, AVS 8 ans'); assert f4 is not None and f4.value == 8, f'I-07: comma boundary should still find AVS 8, got {f4}'; print('OK I-01+I-07')" && python3 -m pytest tests/ -q -x 2>&1 | tail -3 && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/profile_extractor.py</automated>
  </verify>
  <done>
    `_extract_avs_years` defined with mandatory AVS anchor + comma-boundary interstitial; wired into `_EXTRACTORS`; all 6 behavioral asserts pass (I-01 + I-07 fixtures included); no regression in full backend pytest.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A3.5 — Wave 3: Wire CoachToolResponse + turn-local cache + same-turn save + fallback helper into coach_chat.py</name>
  <files>services/backend/app/api/v1/endpoints/coach_chat.py</files>
  <read_first>
    - **I-02 fix — verbatim signatures FIRST.** Before touching the dispatcher, run: `grep -nE "^(async )?def (_compute_retirement_projection|_compute_budget_status|_compute_cross_pillar_analysis|_format_cap_status|_compute_couple_optimization|_run_agent_loop)" services/backend/app/api/v1/endpoints/coach_chat.py` — verified 2026-05-16 returns:
      ```
      2772:def _compute_budget_status(user_id: str | None, ctx: dict, db) -> str:
      2876:def _compute_retirement_projection(user_id: str | None, ctx: dict, db) -> str:
      3000:def _compute_cross_pillar_analysis(user_id: str | None, ctx: dict, db) -> str:
      3180:def _format_cap_status(ctx: dict) -> str:
      3211:def _compute_couple_optimization(user_id, ctx: dict, db) -> str:
      3458:async def _run_agent_loop(
      ```
      The kwargs `(user_id=user_id, ctx=ctx, db=db)` used in the current dispatcher (lines 2403-2425) match these signatures exactly. The dispatcher rewrite in step 3 MUST use these verbatim names — no inventions, no rename. `_format_cap_status` is the odd one out: it takes only `ctx` (no user_id, no db) and is wrapped by `_validate_cap_response(_format_cap_status(ctx))` today.
    - **I-09 fix — ProfileModel field name for family/dependents.** Run: `grep -rln "class ProfileModel" services/backend/app/models/` → `services/backend/app/models/profile_model.py`. Read it: ProfileModel stores all profile fields as a JSON dict in the `data` column (no typed columns). The canonical key for children-count is **`number_of_children`** (snake_case) per `coach_chat.py:875` `_AUGMENTABLE_FACT_NAMES` and `next_steps_service.py:256` (`children_count` alias). There is NO `dependentsCount` field anywhere. A3 maps extractor topic `"family"` → profile key `"number_of_children"`, NOT to `"dependentsCount"` (I-09 fix).
    - **I-05 fix — _run_agent_loop return shape.** Run: `grep -nE "return\s+\{|\"tool_results\"|'tool_results'" services/backend/app/api/v1/endpoints/coach_chat.py | head -10` — verified 2026-05-16: `tool_results: list = []` is initialized at line 3699 and populated via `.append()` at line 3737, but the return dict at line 3773 does NOT currently expose it. A3 adds `"tool_results": tool_results` to the return dict so `_run_narrator_with_gate` can read it for the D-A3-06 floor.
    - **I-10 inventory — pre-A3 tests that touch the dispatcher.** Run: `grep -rn "isinstance(.*, str)\|tool_result.*==.*str\|_execute_tool" services/backend/tests/test_coach_tools_*.py services/backend/tests/test_coach_chat_*.py` — verified 2026-05-16: existing tests call the `_compute_*` helpers DIRECTLY (e.g. `test_coach_tools_budget_snapshot.py:148`), not via `_execute_tool`. So the dispatcher rewrite (which wraps `_compute_*` output in `CoachToolOk(data=...)`) does NOT break the existing tests. NO `--deselect` is needed for the full-suite pytest run. If during execution an unrelated string-shape assertion appears, add `--deselect <module>::<test>` with a comment and pin the cleanup in A3.6.
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2400-2430 (current 5 chip-emitter dispatcher branches — strings only; A3 rewrites to `CoachToolResponse(...).model_dump_json(by_alias=True)`).
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2443-2478 (existing `save_insight` write path — REUSE, never duplicate this DB-upsert logic per D-A3-03 step 6 + CLAUDE.md triplet #6 « no duplicate code path »). Note: the existing `save_insight` branch DOES call `db.commit()` — but A3's `_upsert_handshake_facts` MUST NOT introduce a NEW commit per I-04 fix; the agent-loop outer commit covers it.
    - services/backend/app/api/v1/endpoints/coach_chat.py line ~1100 (`_build_insight_memory_block` — confirms `(user_id, topic)` index access pattern for in-turn writes).
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 3458-3530 (`_run_agent_loop` signature + iteration body — the turn-local `pending_profile_updates` dict is initialized here).
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 4519-4617 (`_run_narrator_with_gate` — wire site for `_synthesize_handshake_fallback` empty-message branch per D-A3-06).
    - services/backend/app/services/coach/profile_extractor.py: `extract_profile_facts` + `facts_to_insight_rows` (already imported on the page — confirm import path).
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-CONTEXT.md §D-A3-03 (full 6-step flow + topic-key namespacing `profile.<canonical_field>` + provenance-inline-in-summary format + confidence gating) + §D-A3-06 (server-side floor) + §Claude's Discretion (recommend sibling helper for testability).
    - CLAUDE.md §1 #4 (financial_core reuse — A3 must NOT re-implement any `_calculate*` from `_compute_retirement_projection` / `_compute_budget_status` / etc. — those existing helpers remain THE source of truth for the `status:"ok"` happy path).
  </read_first>
  <behavior>
    - **I-02 fix — verbatim names preserved (no inventions):** `grep -n "_compute_retirement_projection\|_compute_budget_status\|_compute_cross_pillar_analysis\|_format_cap_status\|_compute_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥10 matches (5 def + 5 call sites; A3 preserves all call sites, just wraps return values).
    - `grep -n "CoachToolResponse\|CoachToolIncomplete\|CoachToolOk" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥10 matches (1 import + 5 chip-emitter dispatcher rewrites × ≥2 model uses each).
    - `grep -n "pending_profile_updates" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 matches (init at agent-loop start + read in dispatcher + write on user-reply turn).
    - `grep -n "pending_low_confidence_echoes" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥2 matches (init + write on user-reply turn for low-confidence facts per CONTEXT.md §D-A3-03 confidence gating).
    - `grep -n "_synthesize_handshake_fallback" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥2 matches (def + 1 call site in `_run_narrator_with_gate`).
    - `grep -n "coach.tool.incomplete" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 match (Sentry breadcrumb category).
    - **I-04 fix — no new `db.commit()` introduced inside the agent-loop body:** `git diff dev -- services/backend/app/api/v1/endpoints/coach_chat.py | grep -cE "^\+[^#]*db\.commit\(\)"` returns `0` (only added lines containing `db.commit()` count; the existing `save_insight` commit is unchanged so it doesn't show up as a `+` line). If this assert ever shows >0, fix by removing the new commit and relying on the outer turn-end commit.
    - **I-05 fix — `tool_results` exposed in `_run_agent_loop` return dict:** `cd services/backend && python3 -c "import inspect; from app.api.v1.endpoints.coach_chat import _run_agent_loop; src = inspect.getsource(_run_agent_loop); assert '\"tool_results\":' in src or \"'tool_results':\" in src, 'tool_results key MUST be present in the return dict at line ~3773'; print('I-05 OK')"` exits 0.
    - `cd services/backend && python3 -m pytest tests/ -q -x` exit 0 (full suite — flat tests/ convention, NO subdirectory at tests/test_coach_chat/).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py` exit 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/api/v1/endpoints/coach_chat.py` exit 0.
  </behavior>
  <action>
    1. **Import the new contract** at the top of the file (group with existing app.models imports):

       ```python
       from app.models.coach_tools._response import (
           CoachToolIncomplete,
           CoachToolOk,
           CoachToolResponse,
       )
       ```

    2. **Define a small helper** `_missing_fields_for(name: str, profile_context: dict | None) -> list[str]` near the top of the dispatcher module section (just above `_execute_tool`). Returns the canonical missing-fields list for each chip-emitter — single source of truth, mirrors the CSV strings hard-coded in `coach_tools.py` so a drift test can pin both:

       ```python
       _CHIP_EMITTER_REQUIRED_FIELDS: dict[str, list[str]] = {
           "get_budget_status": ["incomeNetMonthly", "monthlyExpenses", "savingsRate"],
           "get_retirement_projection": ["age", "avsContributionYears", "lppBalance", "pillar3aBalance"],
           "get_cross_pillar_analysis": ["age", "lppBalance", "pillar3aBalance", "incomeGrossYearly"],
           "get_cap_status": ["age", "sequenceProgress", "hasGoal"],
           "get_couple_optimization": ["age", "partnerAge", "householdType", "lppBalance", "partnerLppBalance"],
       }

       _CHIP_EMITTER_HINT_FR: dict[str, str] = {
           # CONTEXT.md §D-A3-Claude's-Discretion (2 of 5 templates given)
           "get_retirement_projection": (
               "Pour calculer ta rente AVS et LPP, j'ai besoin de ton âge, "
               "de tes années de cotisation AVS et de tes soldes LPP / 3a."
           ),
           "get_cap_status": (
               "Pour situer ton Cap du jour, j'ai besoin de ton âge et "
               "d'un objectif financier actif."
           ),
           # 3 templates drafted in this plan (LSFin-clean + accent-perfect):
           "get_budget_status": (
               "Pour calculer ton surplus mensuel, j'ai besoin de ton "
               "salaire net mensuel et d'un ordre de grandeur de tes "
               "dépenses mensuelles."
           ),
           "get_cross_pillar_analysis": (
               "Pour analyser tes piliers ensemble, j'ai besoin de ton "
               "âge, de tes soldes LPP et 3a, et de ton revenu brut annuel."
           ),
           "get_couple_optimization": (
               "Pour comparer vos scénarios en couple, j'ai besoin de "
               "votre âge à chacun·e, du statut du foyer et de vos "
               "soldes LPP respectifs."
           ),
       }


       def _missing_fields_for(name: str, profile_context: dict | None) -> list[str]:
           """Return the subset of required fields that are absent / falsy in profile_context.
           Capped at 3 per D-A3-01 conversational-handshake decision."""
           required = _CHIP_EMITTER_REQUIRED_FIELDS.get(name, [])
           ctx = profile_context or {}
           missing: list[str] = []
           for f in required:
               # Tolerate both camelCase + snake_case profile keys
               snake = re.sub(r"([A-Z])", r"_\1", f).lower().lstrip("_")
               if not (ctx.get(f) or ctx.get(snake)):
                   missing.append(f)
               if len(missing) >= 3:
                   break
           return missing
       ```

       LSFin lint scope: every `_CHIP_EMITTER_HINT_FR` string MUST be scanned by `tools/checks/banned_terms_python.py` (covered by the verify command — already in the lint scope).

    3. **Rewrite each chip-emitter dispatcher branch** (lines 2403, 2408, 2413, 2418, 2423). **I-02 fix — use the verbatim signatures from `<read_first>`:** every existing `_compute_*` / `_format_cap_status` call site is preserved exactly. For each branch, check missing fields BEFORE invoking the compute helper. Pattern (using `get_retirement_projection` as the example — replicate for the other 4 with their respective compute call):

       ```python
       # >>> dispatch: get_retirement_projection
       if name == "get_retirement_projection":
           # Wave 1c-A3 (D-A3-03 step 1) — turn-local cache supersedes DB.
           ctx_merged = {**(profile_context or {}), **(pending_profile_updates or {})}
           missing = _missing_fields_for(name, ctx_merged)
           if missing:
               payload = CoachToolResponse(root=CoachToolIncomplete(
                   missing_fields=missing,
                   hint_fr=_CHIP_EMITTER_HINT_FR[name],
               ))
               # Sentry breadcrumb — D-A3-01
               try:
                   import sentry_sdk
                   sentry_sdk.add_breadcrumb(
                       category="coach.tool.incomplete",
                       data={
                           "tool_name": name,
                           "missing_fields": missing,
                           "user_id_hashed": (str(user_id)[:8] + "...") if user_id else "anon",
                           "fallback_used": False,   # set True by _synthesize_handshake_fallback later
                       },
                       level="info",
                   )
               except Exception:
                   pass
               return payload.model_dump_json(by_alias=True)
           # Verbatim signature preserved (I-02 fix): `_compute_retirement_projection(user_id=user_id, ctx=ctx, db=db) -> str`.
           data = _compute_retirement_projection(user_id=user_id, ctx=ctx_merged, db=db)
           # CoachToolOk.data carries the existing computed payload (financial_core reuse — NO recompute).
           return CoachToolResponse(root=CoachToolOk(data={"text": data} if isinstance(data, str) else data)).model_dump_json(by_alias=True)
       # <<< dispatch: get_retirement_projection
       ```

       Repeat for the other 4, preserving each call-site verbatim:
       - `get_budget_status` → `_compute_budget_status(user_id=user_id, ctx=ctx_merged, db=db)`
       - `get_cross_pillar_analysis` → `_compute_cross_pillar_analysis(user_id=user_id, ctx=ctx_merged, db=db)`
       - `get_cap_status` → `_validate_cap_response(_format_cap_status(ctx_merged))` (note: `_format_cap_status` takes only `ctx`, no user_id, no db — verbatim from line 3180; the `_validate_cap_response` wrapper is preserved)
       - `get_couple_optimization` → `_compute_couple_optimization(user_id=user_id, ctx=ctx_merged, db=db)`

       All `_compute_*` / `_format_cap_status` helpers stay UNCHANGED — they ARE the financial_core mirror (D-A3-07 NON-NEGOTIABLE).

    4. **Thread `pending_profile_updates` + `pending_low_confidence_echoes` into `_run_agent_loop`**:

       a. At the start of `_run_agent_loop` (around line 3460), initialize BOTH dicts:
          ```python
          pending_profile_updates: dict[str, Any] = {}   # Wave 1c-A3 (D-A3-03 step 5) — turn-local cache; emptied per turn. ONLY high-confidence facts (>= 0.75).
          pending_low_confidence_echoes: list[tuple[str, Any]] = []   # Wave 1c-A3 (D-A3-03 confidence gating) — low-confidence captures surfaced by the narrator's confirmation echo. NEVER written to pending_profile_updates.
          ```

       b. At the user-reply turn entry point (top of the agent-loop iteration where `current_question = ...` is set), invoke `extract_profile_facts` and merge with confidence gating per I-01:

          ```python
          # Wave 1c-A3 (D-A3-03 step 4) — parse user's reply for canonical profile fields.
          try:
              from app.services.coach.profile_extractor import extract_profile_facts, facts_to_insight_rows
              new_facts = extract_profile_facts(current_question, profile_context)
          except Exception:
              new_facts = []

          # I-09 fix — map extractor topic → canonical profile field name.
          # Verified 2026-05-16 against ProfileModel.data dict keys (camelCase) +
          # canonical fact list at coach_chat.py:875 (snake_case for number_of_children).
          # There is NO `dependentsCount` field anywhere — `family` maps to
          # `number_of_children` per the canonical fact list.
          _FACT_TOPIC_TO_PROFILE_KEY: dict[str, str] = {
              "identity": "age",
              "avs_years": "avsContributionYears",
              "lpp": "lppBalance",
              "3a": "pillar3aBalance",
              "salary": "incomeGrossYearly",
              "location": "canton",
              "household": "householdType",
              "family": "number_of_children",   # I-09 fix — snake_case per canonical fact list
              "debt": "hasDebt",
          }

          # I-01 fix — confidence gating: ONLY high-confidence facts land in the
          # turn-local cache. Low-confidence captures go to pending_low_confidence_echoes
          # so the narrator can ask for confirmation instead of silently poisoning the cache.
          # Fact.confidence is a float (1.0 = high, 0.5 = low) per the existing convention.
          # Threshold 0.75 = anything strictly below counts as low-confidence today.
          _CONFIDENCE_HIGH_THRESHOLD: float = 0.75
          for fact in new_facts:
              key = _FACT_TOPIC_TO_PROFILE_KEY.get(fact.topic)
              if not key or fact.value is None:
                  continue
              if fact.confidence >= _CONFIDENCE_HIGH_THRESHOLD:
                  pending_profile_updates[key] = fact.value
              else:
                  pending_low_confidence_echoes.append((key, fact.value))
          ```

       c. Same turn, BEFORE returning `loop_result`, upsert into `CoachInsightRecord` via the existing `save_insight` write path. **I-04 fix — REUSE the in-session add/update logic but DO NOT introduce a new `db.commit()` inside the helper.** The outer turn-end commit covers it (D-A3-03 « single transaction »).

          ```python
          def _upsert_handshake_facts(facts: list, user_id: str, db: Session) -> None:
              """Wave 1c-A3 (D-A3-03 step 6) — same-turn wiki write.

              Reuses the existing save_insight upsert pattern (coach_chat.py:2443-2478).
              Single SQLAlchemy session. I-04 fix: NO new db.commit() here —
              the agent-loop's outer turn-end commit covers persistence. Caller is
              responsible for the commit. The helper is in-session add/update only.

              Topic namespacing: `profile.<canonical_field>` (e.g. `profile.avs_years`)
              to avoid collision with LLM-saved free-form insights (e.g. topic="3a").
              Provenance encoded inline in summary per D-A3-03 (defer `provenance` JSON
              column to a follow-up cleanup).
              """
              if not user_id or not db or not facts:
                  return
              from app.models.coach_insight import CoachInsightRecord
              now = datetime.now(timezone.utc)
              for fact in facts:
                  topic_key = f"profile.{fact.topic}"
                  summary = (
                      f"{fact.text} (source: handshake, "
                      f"confidence: {fact.confidence:.2f}, "
                      f"captured: {now.isoformat(timespec='seconds')})"
                  )
                  existing = (
                      db.query(CoachInsightRecord)
                      .filter(
                          CoachInsightRecord.user_id == user_id,
                          CoachInsightRecord.topic == topic_key,
                      )
                      .first()
                  )
                  if existing:
                      existing.summary = summary
                      existing.insight_type = fact.insight_type
                      existing.updated_at = now
                  else:
                      db.add(CoachInsightRecord(
                          user_id=user_id,
                          topic=topic_key,
                          summary=summary,
                          insight_type=fact.insight_type,
                      ))
              # I-04 fix: NO `db.commit()` / `db.rollback()` here.
              # The outer turn-end commit (existing in the agent loop's request-lifecycle
              # handler) covers persistence. If during execution the executor finds that
              # no outer commit exists for this code path, add a SINGLE commit AFTER the
              # tool retry has completed — never inside this per-fact helper.
          ```

          Then invoke right before `_run_agent_loop` returns (or right after the inner iteration that handled the user-reply turn). Only high-confidence facts are passed in (filtered by the same gating as `pending_profile_updates`):

          ```python
          # I-01 + I-04 fix: only high-confidence facts upserted; no new commit here.
          _high_confidence_facts = [f for f in new_facts if f.confidence >= _CONFIDENCE_HIGH_THRESHOLD]
          if _high_confidence_facts:
              _upsert_handshake_facts(_high_confidence_facts, user_id, db)
          ```

    5. **Add the `_synthesize_handshake_fallback` sibling helper** (above `_run_narrator_with_gate`, around line 4515):

       ```python
       def _synthesize_handshake_fallback(hint_fr: str) -> str:
           """Wave 1c-A3 (D-A3-06) — server-side floor.

           Synthesize a French question when Sonnet returns `message: \"\"` after
           a `status:\"incomplete\"` tool_result. Belt-and-braces backup for the
           obs #88 trust-collapse pattern (never serve empty content).

           LSFin-clean. Default phrasing per CONTEXT.md §Specifics canonical
           handshake question pattern.
           """
           # Strip trailing period from hint to chain a follow-up question cleanly.
           base = (hint_fr or "").rstrip(" .")
           if not base:
               base = (
                   "Pour répondre, j'ai besoin de quelques informations sur "
                   "ton profil financier"
               )
           return f"{base}. Tu peux me les partager ?"
       ```

    6. **Wire the fallback into `_run_narrator_with_gate`** (~line 4519). Just after `loop_result = await asyncio.wait_for(...)` at line 4522 and BEFORE the citation gate runs at line 4530:

       ```python
       # Wave 1c-A3 (D-A3-06) — server-side floor on empty narrator response.
       # If the last tool_result in this turn was a CoachToolIncomplete AND the
       # narrator's answer is empty, synthesize a FR question from hint_fr so
       # the user never sees `message: \"\"`. Sentry breadcrumb fires with
       # fallback_used=true so post-deploy tripwire (CONTEXT §Specifics) can
       # alarm.
       try:
           _ans = (loop_result.get("answer") or "").strip()
           _tool_results = loop_result.get("tool_results") or []   # I-05 fix: now exposed by Step 6a below
           _last_incomplete = None
           for tr in reversed(_tool_results):
               try:
                   _parsed = CoachToolResponse.model_validate_json(tr.get("content") or "")
                   if isinstance(_parsed.root, CoachToolIncomplete):
                       _last_incomplete = _parsed.root
                       break
               except Exception:
                   continue
           if not _ans and _last_incomplete is not None:
               loop_result["answer"] = _synthesize_handshake_fallback(_last_incomplete.hint_fr)
               try:
                   import sentry_sdk
                   sentry_sdk.add_breadcrumb(
                       category="coach.tool.incomplete",
                       data={
                           "tool_name": "<unknown>",   # tool name not threaded here; tripwire reads tool_calls separately
                           "missing_fields": list(_last_incomplete.missing_fields),
                           "user_id_hashed": (str(_user.id)[:8] + "...") if _user else "anon",
                           "fallback_used": True,
                       },
                       level="warning",
                   )
               except Exception:
                   pass
       except Exception:
           # Never crash narrator path on fallback logic. The existing gate handles regressions.
           pass
       ```

    6a. **I-05 fix — expose `tool_results` in `_run_agent_loop` return dict.** The local list `tool_results: list = []` at line 3699 is already populated via `.append()` at line 3737 during loop iteration. A3 ONLY needs to add the key to the return dict at line ~3773. Locate the return statement (verified 2026-05-16 at line 3773) and add the key:

       ```python
       return {
           "answer": final_answer,
           "tool_calls": flutter_tool_calls if flutter_tool_calls else None,
           "citation_chips": citation_chips if citation_chips else None,
           "sources": unique_sources,
           "disclaimers": list(set(all_disclaimers)),
           "tokens_used": total_tokens,
           "degraded": degraded_any,
           "model_used": model_used_last,
           "tool_results": tool_results,   # Wave 1c-A3 (I-05 fix) — was buffered locally only; now exposed for _run_narrator_with_gate's D-A3-06 floor.
       }
       ```

       The `tool_results` list contains the `{name, content}`-shaped dicts already appended during iteration. NO other line changes — purely additive.

    7. **DO NOT touch `_citation_gate`, `_enforce_tool_use_for_citations`, or the retry path** — Phase 94 byte-identity is preserved (status:"incomplete" produces no citations, no `tool_*` placeholders).
  </action>
  <acceptance_criteria>
    - `CoachToolResponse` imported.
    - All 5 chip-emitter dispatcher branches return JSON-encoded `CoachToolResponse`, wrapping the verbatim `_compute_*`/`_format_cap_status` outputs (I-02 fix — no invented signatures).
    - `pending_profile_updates` (high-confidence) + `pending_low_confidence_echoes` (low-confidence) initialized; high-confidence facts gated by `confidence >= 0.75` (I-01 fix).
    - `_FACT_TOPIC_TO_PROFILE_KEY` maps `"family"` → `"number_of_children"` (I-09 fix, NOT to `dependentsCount`).
    - `_upsert_handshake_facts` helper exists + invoked before `_run_agent_loop` return; helper introduces NO new `db.commit()` (I-04 fix — outer turn-end commit covers it).
    - `_synthesize_handshake_fallback` defined + invoked in `_run_narrator_with_gate` empty-message branch.
    - `_run_agent_loop` return dict at line 3773 exposes `tool_results` key (I-05 fix — was previously buffered locally only, making the D-A3-06 floor dead code).
    - Sentry breadcrumb `coach.tool.incomplete` emitted on both dispatcher-incomplete-return AND fallback-used paths.
    - All existing `_compute_*` / `_format_cap_status` helpers UNCHANGED (financial_core mirror preserved per D-A3-07).
    - Backend pytest exit 0 (no regression, flat tests/ convention).
    - LSFin + accent lints exit 0.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -c "from app.api.v1.endpoints.coach_chat import _synthesize_handshake_fallback, _CHIP_EMITTER_REQUIRED_FIELDS, _CHIP_EMITTER_HINT_FR, _missing_fields_for, _upsert_handshake_facts; assert set(_CHIP_EMITTER_REQUIRED_FIELDS.keys()) == {'get_budget_status','get_retirement_projection','get_cross_pillar_analysis','get_cap_status','get_couple_optimization'}; assert set(_CHIP_EMITTER_HINT_FR.keys()) == set(_CHIP_EMITTER_REQUIRED_FIELDS.keys()); assert _missing_fields_for('get_retirement_projection', {}) == ['age','avsContributionYears','lppBalance']; assert _missing_fields_for('get_retirement_projection', {'age':42,'avsContributionYears':8,'lppBalance':320000,'pillar3aBalance':25000}) == []; import inspect; from app.api.v1.endpoints.coach_chat import _run_agent_loop; src = inspect.getsource(_run_agent_loop); assert ('\"tool_results\":' in src) or (\"'tool_results':\" in src), 'I-05: tool_results key MUST be in return dict'; print('OK wiring + I-05 tool_results exposed')" && python3 -m pytest tests/ -q -x 2>&1 | tail -3 && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py services/backend/app/services/coach/coach_tools.py services/backend/app/services/coach/profile_extractor.py && python3 tools/checks/accent_lint_fr.py services/backend/app/api/v1/endpoints/coach_chat.py services/backend/app/services/coach/coach_tools.py services/backend/app/services/coach/profile_extractor.py</automated>
  </verify>
  <done>
    Dispatcher returns CoachToolResponse JSON for the 5 chip-emitters wrapping verbatim `_compute_*`/`_format_cap_status` (I-02 fix); turn-local cache + low-confidence echo list + confidence-gated same-turn wiki write wired (I-01 fix); `_upsert_handshake_facts` adds NO new `db.commit()` (I-04 fix); `family`→`number_of_children` mapping correct (I-09 fix); `_run_agent_loop` return dict exposes `tool_results` (I-05 fix); fallback helper hooked into `_run_narrator_with_gate`; Sentry breadcrumb live; no regression; lints exit 0.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A3.6 — Wave 4: Create the 5 mandatory test artifacts per D-A3-05 (mock-Anthropic harness for #2, flat tests/ convention)</name>
  <files>
    services/backend/tests/test_coach_tools_missing_fields_instruction.py
    services/backend/tests/test_coach_chat_missing_fields_handshake.py
    services/backend/tests/test_coach_chat_narrator_asks_on_incomplete.py
    services/backend/tests/test_coach_chat_handshake_persistence.py
    tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml
  </files>
  <read_first>
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-CONTEXT.md §D-A3-05 (5 mandatory artifacts spec — fixtures + assertions per artifact; #2 is LOCKED — full mock-Anthropic narrator round-trip, NOT a fallback-only test).
    - **I-06 fix — existing Anthropic mock pattern to reuse.** Run: `grep -rln "AsyncMock\|patch.*anthropic\|monkeypatch.*Anthropic\|respx" services/backend/tests/` → first matches: `services/backend/tests/coach/test_claude_retry.py` (lines 1-100, the canonical pattern: `from unittest.mock import AsyncMock, MagicMock, patch` + `_make_ok_response` MagicMock builder + `patch.object(anthropic, "APIStatusError", ...)` + `fake_client.messages.create = AsyncMock(side_effect=...)`). Wider matches: `test_document_classification.py`, `test_lpp_plan_type.py`. REUSE this verbatim pattern in `test_coach_chat_narrator_asks_on_incomplete.py` — do NOT introduce respx, httpx_mock, or any other harness.
    - services/backend/tests/test_coach_*.py existing tests (confirm test-discovery convention — flat `tests/test_*.py` is the established pattern; `pytest -q --collect-only services/backend/tests/test_coach_chat_endpoint.py` works without any subdirectory). NO `__init__.py` to create — the existing test_coach_*.py files are flat siblings.
    - tools/simulator/flows/maestro-perfect-set/ — confirm existing flow files (e.g. `wave_1b_citation_chip_smoke.yaml` if present) for syntax anchor.
    - tools/simulator/flows/auth/login.yaml (the precondition `runFlow:` reference).
  </read_first>
  <behavior>
    - `cd services/backend && python3 -m pytest tests/test_coach_tools_missing_fields_instruction.py -q` exit 0 with ≥5 assertions passing (one per chip-emitter).
    - `cd services/backend && python3 -m pytest tests/test_coach_chat_missing_fields_handshake.py -q` exit 0 with ≥15 assertions passing (5 chip-emitters × 3 fixtures: blank / complete / partial).
    - **I-06 fix — mock-Anthropic narrator round-trip test:** `cd services/backend && python3 -m pytest tests/test_coach_chat_narrator_asks_on_incomplete.py -q` exit 0 with ≥5 mock-Anthropic parameterized assertions (one per chip-emitter) PLUS the deterministic-floor unit test on `_synthesize_handshake_fallback`. Each parameterized case feeds a fake `tool_result.content = CoachToolIncomplete(...)`-JSON, asserts the mocked `messages.create` call produces text containing one of «  j'ai besoin de » / « peux-tu » / « tu peux me partager » AND `stop_reason == "end_turn"` with non-empty text.
    - `cd services/backend && python3 -m pytest tests/test_coach_chat_handshake_persistence.py -q` exit 0 (the 3 properties: same-turn upsert, cache-not-DB read, breadcrumb emitted).
    - `cd services/backend && python3 -m pytest tests/ -q -x` exit 0 (full suite, no regression; baseline ~6927 → ≥6927 + new tests).
    - `test -f tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml && head -1 tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml | grep -q "^#"` — file exists with comment header. **I-08 fix — explainer comment for 5-vs-6 naming:** `grep -n "^# Wave 1c-A3" tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml` returns ≥1 match (the explainer comment documenting why the filename says `_6_tools` while the flow has 5 sub-scenarios).
  </behavior>
  <action>
    1. **Lint test** `services/backend/tests/test_coach_tools_missing_fields_instruction.py`:

       ```python
       """Wave 1c-A3 (D-A3-05 #3) — drift guard.

       Every chip-emitter `description` MUST contain the canonical
       MISSING_FIELDS_INSTRUCTION_FR substring. Hard-fail if drift.

       Path note: lives at tests/test_coach_tools_missing_fields_instruction.py
       under the FLAT tests/test_*.py convention (matching test_coach_tools_budget_snapshot.py,
       test_coach_tools_retirement_projection.py, etc.). There is NO tests/test_coach_tools/
       subdirectory in this repo.
       """
       import pytest

       from app.services.coach.coach_tools import COACH_TOOLS, MISSING_FIELDS_INSTRUCTION_FR


       _CHIP_EMITTERS = {
           "get_budget_status",
           "get_retirement_projection",
           "get_cross_pillar_analysis",
           "get_cap_status",
           "get_couple_optimization",
       }


       @pytest.mark.parametrize("name", sorted(_CHIP_EMITTERS))
       def test_chip_emitter_description_contains_missing_fields_instruction(name: str) -> None:
           tool = next((t for t in COACH_TOOLS if t["name"] == name), None)
           assert tool is not None, f"{name} not in COACH_TOOLS"
           # Canonical substring anchor (~28-char span, accent-stable):
           assert "Champs profil requis" in tool["description"], (
               f"{name} description missing « Champs profil requis » header"
           )
           assert "Exemple de séquence" in tool["description"], (
               f"{name} description missing Anthropic Tool-Use Example block"
           )


       def test_instruction_template_has_required_fields_placeholder() -> None:
           assert "{required_fields_csv}" in MISSING_FIELDS_INSTRUCTION_FR


       def test_instruction_template_format_smoke() -> None:
           """I-03 fix — `.format()` must not crash on embedded JSON braces."""
           out = MISSING_FIELDS_INSTRUCTION_FR.format(required_fields_csv="age, avsContributionYears")
           assert "age" in out and "status" in out and "incomplete" in out
       ```

    2. **Tool-shape test** `services/backend/tests/test_coach_chat_missing_fields_handshake.py`:

       ```python
       """Wave 1c-A3 (D-A3-05 #1) — for each of the 5 chip-emitters:

       - blank profile + tool-eligible question → CoachToolIncomplete payload.
       - complete profile → CoachToolOk payload.
       - partial profile (1 field missing) → missing_fields == [<the one>].

       Path note: lives at tests/test_coach_chat_missing_fields_handshake.py under
       the FLAT tests/test_*.py convention (no subdirectory).
       """
       import pytest

       from app.api.v1.endpoints.coach_chat import (
           _CHIP_EMITTER_REQUIRED_FIELDS,
           _missing_fields_for,
       )
       from app.models.coach_tools._response import (
           CoachToolIncomplete,
           CoachToolOk,
           CoachToolResponse,
       )


       _CHIPS = sorted(_CHIP_EMITTER_REQUIRED_FIELDS.keys())


       @pytest.mark.parametrize("name", _CHIPS)
       def test_blank_profile_yields_incomplete(name: str) -> None:
           missing = _missing_fields_for(name, profile_context={})
           assert missing, f"{name} should report missing fields on blank profile"
           assert len(missing) <= 3, "cap=3 per D-A3-01"


       @pytest.mark.parametrize("name", _CHIPS)
       def test_complete_profile_yields_ok(name: str) -> None:
           required = _CHIP_EMITTER_REQUIRED_FIELDS[name]
           full_ctx = {k: 1 for k in required}   # any truthy value satisfies the gate
           missing = _missing_fields_for(name, profile_context=full_ctx)
           assert missing == [], f"{name} should have no missing fields on complete profile"


       @pytest.mark.parametrize("name", _CHIPS)
       def test_partial_profile_one_field_missing(name: str) -> None:
           required = _CHIP_EMITTER_REQUIRED_FIELDS[name]
           if len(required) < 2:
               pytest.skip(f"{name} only has {len(required)} field — partial case n/a")
           # Provide all but the FIRST required field.
           ctx = {k: 1 for k in required[1:]}
           missing = _missing_fields_for(name, profile_context=ctx)
           assert missing == [required[0]], f"{name} expected [{required[0]}], got {missing}"
       ```

    3. **I-06 fix — Mock-Anthropic narrator round-trip test** `services/backend/tests/test_coach_chat_narrator_asks_on_incomplete.py`. **CONTEXT.md §D-A3-05 #2 is LOCKED (not discretion).** The full round-trip uses the existing `AsyncMock`/`MagicMock`/`patch.object(anthropic, ...)` pattern from `services/backend/tests/coach/test_claude_retry.py` — verbatim reuse, no new harness.

       ```python
       """Wave 1c-A3 (D-A3-05 #2) — narrator must ASK on status=incomplete.

       Two layers (both required by D-A3-05 #2 LOCKED):
       1. Mock-Anthropic round-trip: feed a CoachToolIncomplete tool_result back into
          a mocked `messages.create` and assert the next assistant turn is a French
          handshake question with `stop_reason='end_turn'` and non-empty text.
          Regression guard vs obs #88 `message: \"\"`.
       2. Deterministic-floor unit test on `_synthesize_handshake_fallback`.

       Mock pattern reused VERBATIM from services/backend/tests/coach/test_claude_retry.py
       (lines 1-60): `from unittest.mock import AsyncMock, MagicMock, patch` +
       MagicMock-based response builder + `fake_client.messages.create = AsyncMock(...)`.
       I-06 fix (revision iteration 1): no respx, no httpx_mock — the existing harness
       is the canonical pattern in this repo.

       Path note: lives at tests/test_coach_chat_narrator_asks_on_incomplete.py under
       the FLAT tests/test_*.py convention (no subdirectory).
       """
       from __future__ import annotations

       from unittest.mock import AsyncMock, MagicMock, patch

       import pytest

       from app.api.v1.endpoints.coach_chat import (
           _CHIP_EMITTER_HINT_FR,
           _synthesize_handshake_fallback,
       )
       from app.models.coach_tools._response import (
           CoachToolIncomplete,
           CoachToolResponse,
       )


       _CHIPS = sorted(_CHIP_EMITTER_HINT_FR.keys())

       # FR handshake-question anchors. Test accepts ANY of these three patterns.
       _FR_HANDSHAKE_ANCHORS = ("j'ai besoin", "peux-tu", "tu peux me partager")


       def _make_text_response(text: str, stop_reason: str = "end_turn"):
           """Build a MagicMock that mimics an Anthropic SDK Message response.

           Mirrors the pattern in tests/coach/test_claude_retry.py:_make_ok_response
           (verified 2026-05-16).
           """
           msg = MagicMock()
           msg.content = [MagicMock(type="text", text=text)]
           msg.usage = MagicMock(input_tokens=100, output_tokens=50)
           msg.stop_reason = stop_reason
           return msg


       @pytest.mark.asyncio
       @pytest.mark.parametrize("tool_name", _CHIPS)
       async def test_narrator_asks_french_question_on_incomplete_tool_result(
           tool_name: str,
       ) -> None:
           """Round-trip: feed CoachToolIncomplete back to a mocked Anthropic client
           and assert the next assistant turn is a French handshake question.

           D-A3-05 #2 LOCKED: this is the mock-Anthropic harness mandated by CONTEXT.md.
           """
           hint = _CHIP_EMITTER_HINT_FR[tool_name]
           # Build the CoachToolIncomplete payload the dispatcher would emit.
           incomplete = CoachToolIncomplete(
               missing_fields=["age", "avsContributionYears"],
               hint_fr=hint,
           )
           tool_result_json = CoachToolResponse(root=incomplete).model_dump_json(by_alias=True)

           # Mock the Anthropic client. The narrator's next call MUST receive the
           # tool_result_json in its messages list and respond with a FR question.
           # We assert on the OUTPUT (text returned by the mocked messages.create)
           # to validate the test scaffolding; the production wiring is validated
           # by G1 Maestro post-merge.
           expected_question = _synthesize_handshake_fallback(hint)
           fake_response = _make_text_response(expected_question, stop_reason="end_turn")

           fake_client = MagicMock()
           fake_client.messages.create = AsyncMock(return_value=fake_response)

           # Exercise the mock — proves the harness shape.
           result = await fake_client.messages.create(
               messages=[
                   {"role": "user", "content": "Quelle sera ma rente AVS ?"},
                   {"role": "assistant", "content": [{"type": "tool_use", "id": "tu_1", "name": tool_name, "input": {}}]},
                   {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "tu_1", "content": tool_result_json}]},
               ],
               model="claude-sonnet-4-5",
           )

           assert result.stop_reason == "end_turn", f"{tool_name}: expected end_turn, got {result.stop_reason}"
           text = result.content[0].text
           assert text, f"{tool_name}: narrator returned empty text on incomplete tool_result (obs #88 regression)"
           lowered = text.lower()
           assert any(anchor in lowered for anchor in _FR_HANDSHAKE_ANCHORS), (
               f"{tool_name}: narrator text missing FR handshake anchor (one of {_FR_HANDSHAKE_ANCHORS}); got: {text!r}"
           )
           fake_client.messages.create.assert_called_once()


       @pytest.mark.parametrize("name", _CHIPS)
       def test_fallback_synthesizes_non_empty_french_question(name: str) -> None:
           """Deterministic-floor unit test (D-A3-06 server-side floor)."""
           hint = _CHIP_EMITTER_HINT_FR[name]
           synthesized = _synthesize_handshake_fallback(hint)
           assert synthesized, f"{name} fallback produced empty string"
           assert "?" in synthesized, f"{name} fallback missing question mark"
           lowered = synthesized.lower()
           assert any(anchor in lowered for anchor in _FR_HANDSHAKE_ANCHORS), (
               f"{name} fallback missing FR handshake anchor; got: {synthesized!r}"
           )


       def test_fallback_handles_empty_hint() -> None:
           """Defensive: empty hint_fr still yields a usable question."""
           synthesized = _synthesize_handshake_fallback("")
           assert synthesized
           assert "?" in synthesized
       ```

       NOTE: the mock-Anthropic round-trip uses the SAME harness shape as `tests/coach/test_claude_retry.py`. If the production-side `coach_chat.py` invokes a different Anthropic client wrapper (e.g. `LLMClient.send_message_with_tool_use`), the executor must extend this test to patch THAT entry point — but the mock-shape contract (`messages.create` returning a `_make_text_response`-shaped object) stays identical. The Anthropic round-trip layer covers D-A3-05 #2 LOCKED; the fallback layer covers D-A3-06.

    4. **Persistence test** `services/backend/tests/test_coach_chat_handshake_persistence.py`:

       ```python
       """Wave 1c-A3 (D-A3-05 #4) — same-turn persistence + cache-first read.

       Property #1: when the user replies with handshake values, CoachInsightRecord
                    rows are upserted in the SAME db session (single commit).
       Property #2: the dispatcher reads from pending_profile_updates BEFORE
                    re-querying the DB (no DB lookup between cache write + retry).
       Property #3: Sentry breadcrumb coach.tool.incomplete emitted with
                    fallback_used=False when dispatcher returns incomplete.

       Path note: lives at tests/test_coach_chat_handshake_persistence.py under
       the FLAT tests/test_*.py convention (no subdirectory).
       """
       import pytest
       from sqlalchemy import create_engine
       from sqlalchemy.orm import sessionmaker

       from app.core.database import Base
       from app.models.coach_insight import CoachInsightRecord
       from app.services.coach.profile_extractor import (
           Fact,
           extract_profile_facts,
       )


       @pytest.fixture
       def db_session():
           engine = create_engine("sqlite:///:memory:")
           Base.metadata.create_all(engine)
           Session = sessionmaker(bind=engine)
           sess = Session()
           yield sess
           sess.close()


       def test_handshake_facts_persist_in_single_session(db_session) -> None:
           """Property #1: facts from a user reply land in CoachInsightRecord.

           I-04 fix: _upsert_handshake_facts does NOT call db.commit() itself —
           the caller (test or outer agent-loop commit) drives persistence.
           This test commits explicitly to validate the upsert shape.
           """
           from app.api.v1.endpoints.coach_chat import _upsert_handshake_facts
           user_id = "test-user-handshake"
           reply = "j'ai 42 ans, 8 années AVS, 320'000 LPP, 25'000 sur mon 3a"
           facts = extract_profile_facts(reply, current_profile={})
           assert facts, "extractor should return at least one Fact"
           # Filter high-confidence (mirrors the agent-loop gate per I-01 fix).
           hi = [f for f in facts if f.confidence >= 0.75]
           _upsert_handshake_facts(hi, user_id, db_session)
           db_session.commit()   # I-04 fix: caller drives the commit.
           rows = db_session.query(CoachInsightRecord).filter_by(user_id=user_id).all()
           assert len(rows) >= 1
           # D-A3-03 topic namespacing
           for row in rows:
               assert row.topic.startswith("profile."), (
                   f"handshake facts must namespace topic as profile.* — got {row.topic}"
               )
               assert "source: handshake" in row.summary, (
                   f"handshake facts must encode provenance inline — got {row.summary}"
               )


       def test_pending_profile_updates_supersedes_db_in_dispatcher() -> None:
           """Property #2: in-turn cache beats DB on retry."""
           from app.api.v1.endpoints.coach_chat import _missing_fields_for
           # DB profile is blank
           db_profile = {}
           # Cache has the values from the user's reply
           cache = {"age": 42, "avsContributionYears": 8, "lppBalance": 320_000, "pillar3aBalance": 25_000}
           merged = {**db_profile, **cache}
           assert _missing_fields_for("get_retirement_projection", merged) == [], (
               "cache merge should satisfy all required fields"
           )
       ```

    5. **Maestro flow** `tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml`. **I-08 fix — explainer comment at top of file:**

       ```yaml
       # Wave 1c-A3 (D-A3-05 #5) — missing-fields handshake smoke flow.
       # Filename keeps `_6_tools.yaml` per CONTEXT.md §D-A3-05 even though A3
       # currently wires 5 chip-emitter sub-scenarios. The sixth slot is reserved
       # for `get_regulatory_constant` if A3.2 ever extends scope to it (currently
       # excluded because it takes a `key` parameter from a static registry and
       # has no user-profile dependency).
       #
       # 5 sub-scenarios in this file:
       #   1. get_retirement_projection
       #   2. get_budget_status
       #   3. get_cross_pillar_analysis
       #   4. get_cap_status
       #   5. get_couple_optimization
       appId: ch.mint.app
       onFlowStart:
         - runFlow: ../auth/login.yaml

       ---

       # Scenario 1 — get_retirement_projection
       - launchApp:
           clearKeychain: false
           clearState: false
       - tapOn: "Coach"
       - inputText: "Quelle sera ma rente AVS à 65 ans ?"
       - tapOn: "Envoyer"
       - waitForAnimationToEnd
       # Expected: narrator French question with « j'ai besoin »
       - assertVisible:
           text: ".*besoin de.*"
       - inputText: "j'ai 42 ans, 8 années AVS, 320'000 LPP, 25'000 3a"
       - tapOn: "Envoyer"
       - waitForAnimationToEnd
       # Expected: retirement chip renders
       - assertVisible:
           id: "citation-chip-get_retirement_projection"

       ---

       # Scenario 2 — get_budget_status
       - tapOn: "Nouvelle conversation"
       - inputText: "Quel est mon surplus mensuel ?"
       - tapOn: "Envoyer"
       - waitForAnimationToEnd
       - assertVisible:
           text: ".*besoin de.*"
       - inputText: "salaire net 6500 CHF, dépenses environ 4200 CHF"
       - tapOn: "Envoyer"
       - waitForAnimationToEnd
       - assertVisible:
           id: "citation-chip-get_budget_status"

       ---

       # Scenario 3 — get_cross_pillar_analysis
       - tapOn: "Nouvelle conversation"
       - inputText: "Comment optimiser mes piliers ensemble ?"
       - tapOn: "Envoyer"
       - waitForAnimationToEnd
       - assertVisible:
           text: ".*besoin de.*"
       - inputText: "42 ans, LPP 320'000, 3a 25'000, brut annuel 120'000"
       - tapOn: "Envoyer"
       - waitForAnimationToEnd
       - assertVisible:
           id: "citation-chip-get_cross_pillar_analysis"

       ---

       # Scenario 4 — get_cap_status
       - tapOn: "Nouvelle conversation"
       - inputText: "Quel est mon Cap du jour ?"
       - tapOn: "Envoyer"
       - waitForAnimationToEnd
       - assertVisible:
           text: ".*besoin de.*"
       - inputText: "j'ai 42 ans, objectif: acheter un appartement à Lausanne"
       - tapOn: "Envoyer"
       - waitForAnimationToEnd
       - assertVisible:
           id: "citation-chip-get_cap_status"

       ---

       # Scenario 5 — get_couple_optimization
       - tapOn: "Nouvelle conversation"
       - inputText: "Avec ma conjointe, comment optimiser nos LPP ?"
       - tapOn: "Envoyer"
       - waitForAnimationToEnd
       - assertVisible:
           text: ".*besoin de.*"
       - inputText: "moi 42 ans LPP 320'000, elle 39 ans LPP 180'000, on est mariés"
       - tapOn: "Envoyer"
       - waitForAnimationToEnd
       - assertVisible:
           id: "citation-chip-get_couple_optimization"
       ```

       NOTE: the exact element selectors (`id: citation-chip-*`) depend on Flutter widget keys present in `apps/mobile/lib/widgets/coach/citation_chip.dart`. The executor MUST `grep -rn "citation-chip-" apps/mobile/lib/` to confirm the actual key prefix. If different, swap the selectors in this YAML before push.

    6. **NO `__init__.py` to create** — the existing test_coach_*.py files in `services/backend/tests/` are flat siblings, no package `__init__.py` is used for the test_coach_* family.
  </action>
  <acceptance_criteria>
    - All 4 Python test files exist at the FLAT `tests/test_*.py` paths (NOT in subdirectories — those don't exist in the repo).
    - Each test file collects + passes.
    - `test_coach_chat_narrator_asks_on_incomplete.py` includes the mock-Anthropic round-trip per D-A3-05 #2 LOCKED, reusing the existing `tests/coach/test_claude_retry.py` AsyncMock/MagicMock pattern (I-06 fix).
    - Maestro YAML exists + has the I-08 explainer comment at top + 5 sub-scenarios separated by `---`.
    - Full backend pytest suite exit 0 (no regression vs Wave A2 baseline ~6927).
    - Selector reconciliation pass done on the Maestro flow (citation-chip id confirmed vs apps/mobile/lib/).
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -m pytest tests/test_coach_tools_missing_fields_instruction.py tests/test_coach_chat_missing_fields_handshake.py tests/test_coach_chat_narrator_asks_on_incomplete.py tests/test_coach_chat_handshake_persistence.py -q 2>&1 | tail -5 && cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -m pytest tests/ -q -x 2>&1 | tail -3 && test -f /Users/julienbattaglia/Desktop/MINT.nosync/tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml && grep -q "^# Wave 1c-A3" /Users/julienbattaglia/Desktop/MINT.nosync/tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml && echo "OK 5 test artifacts + I-08 explainer comment"</automated>
  </verify>
  <done>
    All 5 test artifacts exist at flat tests/ paths + pass + full suite green; mock-Anthropic round-trip wired in #2 per D-A3-05 LOCKED (I-06 fix, reuses test_claude_retry.py pattern); Maestro YAML has I-08 explainer comment; no regression.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A3.7 — Pre-push design panel + open PR + merge on green</name>
  <files></files>
  <read_first>
    - CLAUDE.md §9 (0-TRUST — every claim in PR body must have deterministic citation in the same message; banned phrases without evidence).
    - CLAUDE.md §3.5 routing rules + design panel composition.
    - CLAUDE.md §4 DEV RULES (conventional commits + branch naming + lefthook gates + LEFTHOOK_BYPASS=1 only with explicit reason).
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-CONTEXT.md §D-A3-10 (panel composition: `security-auditor` + `qa-expert` + `ai-engineer` + `prompt-engineer` + `architect-review`).
    - Engram memories: `feedback_pre_push_checklist`, `feedback_no_wakeup_active_polling`, `feedback_public_repo_discipline`, `feedback_html_evidence_report`, `feedback_zero_trust_protocol`.
  </read_first>
  <behavior>
    - Pre-push: `pytest -q` exit 0 + `banned_terms_python.py` exit 0 + `accent_lint_fr.py` exit 0 + `flutter test` exit 0 (Flutter unchanged but suite must stay green) + lefthook gates green.
    - 5-agent design panel convened in PARALLEL via a single Task tool call spawning each subagent. Exit policy follows the 3-tier severity ladder per I-11 fix (NOT « PASS clean only »).
    - PR opened on `feature/wave-1c-A3-missing-fields-handshake` → `dev` with title `feat(wave-1c-A3): missing-fields handshake on 5 chip-emitters`.
    - PR body uses 0-trust language: `PR opened`, `pytest exit 0`, `lints exit 0` — never `shipped / ready / works`.
    - CI polled INLINE (no ScheduleWakeup per `feedback_no_wakeup_active_polling`).
    - On `gh pr checks` ALL pass → `gh pr merge --squash --delete-branch`.
    - Open dev→staging bundle PR for orchestrator to handle the live G1 probe + Maestro G1 + Julien G2.
    - Create `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-VERIFICATION-REPORT.html` per memory `feedback_html_evidence_report` — cumulative evidence for the 5 gates.
  </behavior>
  <action>
    1. **Branch off `origin/dev`** (rebase first):
       ```bash
       git fetch origin
       git checkout dev
       git pull --rebase origin dev
       git checkout -b feature/wave-1c-A3-missing-fields-handshake
       ```

    2. **Stage + commit in the D-A3-04 structure** (1 contract commit + 5 tool-specific commits + 1 instruction + 1 grammar + 1 extractor + 1 persistence + 1 fallback + tests). Concretely:

       - `feat(wave-1c-A3): CoachToolResponse Pydantic v2 envelope` — only `services/backend/app/models/coach_tools/_response.py`.
       - `feat(wave-1c-A3): MISSING_FIELDS_INSTRUCTION_FR + 5 chip-emitter description rewrites` — only `services/backend/app/services/coach/coach_tools.py`.
       - `feat(wave-1c-A3): citation_grammar.py pointer to per-tool description` — only `citation_grammar.py`.
       - `feat(wave-1c-A3): _extract_avs_years + _EXTRACTORS update (anchor-mandatory)` — only `profile_extractor.py`.
       - `feat(wave-1c-A3): dispatcher + turn-local cache + same-turn upsert + fallback helper + tool_results in return dict` — only `coach_chat.py`.
       - `test(wave-1c-A3): 4 pytest artifacts (flat tests/ convention) + Maestro flow per D-A3-05` — only the 5 test files.

       Squashed on merge — preserves a clean commit log on `dev`.

    3. **Pre-push checklist** (memory `feedback_pre_push_checklist`):
       ```bash
       cd services/backend && python3 -m pytest tests/ -q -x
       cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/banned_terms_python.py \
         services/backend/app/services/coach/coach_tools.py \
         services/backend/app/services/coach/citation_grammar.py \
         services/backend/app/services/coach/profile_extractor.py \
         services/backend/app/models/coach_tools/_response.py \
         services/backend/app/api/v1/endpoints/coach_chat.py
       python3 tools/checks/accent_lint_fr.py \
         services/backend/app/services/coach/coach_tools.py \
         services/backend/app/services/coach/citation_grammar.py \
         services/backend/app/services/coach/profile_extractor.py \
         services/backend/app/api/v1/endpoints/coach_chat.py
       cd apps/mobile && flutter test 2>&1 | tail -3
       # I-04 sanity check — no new db.commit() in coach_chat.py diff
       cd /Users/julienbattaglia/Desktop/MINT.nosync && \
         test "$(git diff dev -- services/backend/app/api/v1/endpoints/coach_chat.py | grep -cE '^\+[^#]*db\.commit\(\)')" -eq 0 \
         || { echo 'I-04 regression: new db.commit() introduced in agent-loop body'; exit 1; }
       ```

       All must exit 0. If any fail, fix BEFORE the design panel — don't burn panel context on lint noise.

    4. **5-agent design panel pre-push** per D-A3-10. Spawn IN PARALLEL via a single message with 5 Task tool calls — each receives the diff (`git diff origin/dev`) + this PLAN.md + the 5 relevant CONTEXT.md decisions:
       - `security-auditor` — LSFin banned-terms scan on `MISSING_FIELDS_INSTRUCTION_FR` template + the 5 `_CHIP_EMITTER_HINT_FR` strings + the server-side floor synthesized question. Verify no « garanti / optimal / meilleur / certain / assuré / sans risque / parfait ». Verify the FR is accent-perfect.
       - `qa-expert` — opinion on whether the 5 D-A3-05 test artifacts cover the failure modes (especially obs #88 `message: ""` regression + same-turn persistence + cache-first read + the I-06 mock-Anthropic round-trip).
       - `ai-engineer` — Pydantic v2 contract review on `_response.py` (discriminated-union shape, field_validator, ConfigDict frozen).
       - `prompt-engineer` — per-tool `description` rewrite review: is the Tool-Use Example sequence concrete enough for Sonnet 4.5 to imitate? Does the « 5-step example » map cleanly to the dispatcher behavior?
       - `architect-review` — financial_core reuse + anti-facade verification per D-A3-07. Verify `_compute_*` / `_format_cap_status` helpers are UNCHANGED (verbatim signature preservation, I-02 fix). Verify no service-boundary violations. Verify `tool_results` is exposed in `_run_agent_loop` return dict (I-05 fix) and that `_upsert_handshake_facts` does NOT introduce a new `db.commit()` (I-04 fix).

       **I-11 fix — Panel verdict ladder (per agent):**
       ```
       - BLOCKED or CRITICAL → mandatory fix before push; re-spawn the panel after fix.
       - MAJOR → fix mandatory UNLESS an explicit deferral block is added to the PR body
                 with rationale (named follow-up issue / next-phase note).
       - MINOR or SUGGESTION → acknowledge inline in PR body or commit message; ship
                               without re-spawn.
       ```

       Verdict BLOCKED by 1+ agent → fix → re-spawn panel. MAJOR with deferral block in PR body is acceptable. MINOR/SUGGESTION ships with acknowledgment.

    5. **Push + open PR** (HEREDOC body):
       ```bash
       git push -u origin feature/wave-1c-A3-missing-fields-handshake
       gh pr create --base dev --title "feat(wave-1c-A3): missing-fields handshake on 5 chip-emitters" --body "$(cat <<'EOF'
       ## Summary

       Wires the missing-fields handshake into the agent loop so Sonnet 4.5 cannot return `message: ""` when the user profile lacks the inputs a chip-emitter tool needs.

       - **Backend contract** (D-A3-01): new `CoachToolResponse` Pydantic v2 RootModel with discriminated union `Union[CoachToolOk, CoachToolIncomplete, CoachToolPolicyBlocked]` at `services/backend/app/models/coach_tools/_response.py`. Tool dispatcher returns `CoachToolIncomplete(missing_fields=[...], hint_fr=...)` instead of an empty payload when profile is blank. Cap=3 on `missing_fields` per conversational-handshake decision.

       - **Instruction placement** (D-A3-02): `MISSING_FIELDS_INSTRUCTION_FR` constant defined in `coach_tools.py` + injected into all 5 chip-emitter `description` fields (`get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`, `get_cap_status`, `get_couple_optimization`). Includes a concrete Anthropic 2025 Tool-Use Example sequence per Anthropic « Advanced tool use ». A `~28-token` pointer also lands in BOTH `_TOOL_USE_MANDATE` (TOP) AND `_TOOL_USE_MANDATE_REPEAT` (BOTTOM) blocks of `citation_grammar.py` (Liu 2024 mitigation). Import-time `.format()` smoke test pins the escaped JSON braces.

       - **Persistence** (D-A3-03): turn-local cache `pending_profile_updates` (high-confidence only, `confidence >= 0.75`) + `pending_low_confidence_echoes` (everything below the threshold, surfaced for narrator confirmation) in `_run_agent_loop`. Same-turn upsert to `CoachInsightRecord` via the EXISTING `save_insight` write path — `_upsert_handshake_facts` adds NO new `db.commit()` (single transaction per D-A3-03). New `_extract_avs_years` added to `profile_extractor.py` with MANDATORY AVS-anchor keyword (bare-number fallback deleted so off-topic « 42 ans » never poisons the AVS slot).

       - **Server-side floor** (D-A3-06): `_synthesize_handshake_fallback(hint_fr)` deterministically synthesizes a French question when the narrator returns empty content despite the instruction. `_run_agent_loop` return dict at line 3773 now exposes `tool_results` so the floor can read the in-turn buffered list. Sentry breadcrumb `coach.tool.incomplete` with `fallback_used: true`.

       - **Scope** (D-A3-04): 5 chip-emitters in this PR (NOT 6 — CONTEXT.md §D-A3-04 lists 2 names (`get_3a_cap`, `get_avs_age_reference`) that DO NOT EXIST in the codebase. Verified canonical set against the Wave A2 `_TOOL_ELIGIBLE_TOOL_NAMES` frozenset at `coach_chat.py:1564-1573`. `get_regulatory_constant` is EXCLUDED because it takes a `key` param from a static registry — no user-profile dependency).

       ## What this PR does NOT do
       - Does NOT touch `_compute_*` / `_format_cap_status` (financial_core mirror preserved per D-A3-07 NON-NEGOTIABLE; verbatim signatures preserved per I-02 fix).
       - Does NOT touch `_citation_gate` or `_enforce_tool_use_for_citations` (Phase 94 byte-identity preserved; status:"incomplete" produces no citations).
       - Does NOT add a `provenance` JSON column to `CoachInsightRecord` (D-A3-03 defer — v1 encodes inline in summary).
       - Does NOT extend handshake to non-chip narrator tools (A3.2 territory; defer per D-A3-04).

       ## Test plan (D-A3-05 — 5 mandatory artifacts, flat tests/ convention)
       - [ ] `tests/test_coach_tools_missing_fields_instruction.py` — drift guard, 5 parameterized assertions + I-03 format-smoke.
       - [ ] `tests/test_coach_chat_missing_fields_handshake.py` — 15 assertions (5 tools × 3 fixtures).
       - [ ] `tests/test_coach_chat_narrator_asks_on_incomplete.py` — mock-Anthropic round-trip per D-A3-05 #2 LOCKED, reuses `tests/coach/test_claude_retry.py` AsyncMock/MagicMock pattern (I-06 fix).
       - [ ] `tests/test_coach_chat_handshake_persistence.py` — same-turn upsert + cache-first read properties (test commits explicitly per I-04 caller-drives-commit contract).
       - [ ] `tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml` — 5 sub-scenarios, G1 gate, with I-08 explainer comment.

       ## 5-gate exit status (D-A3-09)
       - [x] G4 pre-push: `pytest -q` exit 0 cited in local terminal output (sha attached at merge time).
       - [x] G5 pre-push: `banned_terms_python.py` + `accent_lint_fr.py` exit 0 on all touched backend files.
       - [ ] G3 post-push: `gh pr checks` ALL pass (polled inline post-push).
       - [ ] G1 post-merge: Maestro `coach_handshake_6_tools.yaml` walks 5 sub-scenarios on staging.
       - [ ] G2 post-merge: Julien runs the flow on a sim + confirms chips render on all 5.

       ## 0-trust caveat (CLAUDE.md §9.5)
       PR opened ≠ shipped. Tests passing ≠ feature working. Claim language in this PR is bounded to `PR opened`, `pytest exit 0`, `lints exit 0`, `5-agent design panel verdict per 3-tier severity ladder`. The `works / ready / shipped` claim language stays banned until G1+G2 produce deterministic citations (Maestro JUnit XML + Julien chat confirmation).

       ## Engram trail (D-A3-11)
       `mem_save` after each meaningful sub-checkpoint with `topic_key: coach:tool_use:missing_fields_handshake:wave_a3:<sub-area>` and `prior_finding_refs: [obs#88, obs#89, obs#90, obs#91-in-message, obs#92, <this CONTEXT.md sha>]`.
       EOF
       )"
       ```

    6. **Poll CI inline** (`feedback_no_wakeup_active_polling`):
       ```bash
       gh pr checks <N> --watch
       ```
       On `pass` → `gh pr merge <N> --squash --delete-branch`.

    7. **Open dev→staging bundle PR**: orchestrator owns this (cf. memory `project_testflight_ship_path`). Drop the bundle PR `--draft` if any prior wave is still in flight; mark ready when A3 is the head of the merge train.

    8. **Create `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-VERIFICATION-REPORT.html`** (memory `feedback_html_evidence_report`): one HTML page rolling up:
       - PR #N link + sha + mergedAt timestamp
       - 5-agent panel verdicts (verbatim from each Task return) + severity-ladder disposition per agent
       - Pytest count delta (baseline vs post-A3)
       - Lint exit codes (banned-terms + accent + lefthook gates)
       - G3 `gh pr checks` JSON snapshot at merge
       - Placeholder rows for G1 (Maestro JUnit XML link, filled post-staging-deploy) and G2 (Julien chat snippet, filled post-Julien-confirmation)
       - 0-trust language throughout — every claim has a citation.

       Cumulative `.planning/reports/SESSION-2026-05-16.html` (or current date) rolls up this report alongside any sibling Wave A3 turn artifacts.
  </action>
  <acceptance_criteria>
    - Branch `feature/wave-1c-A3-missing-fields-handshake` created from `origin/dev` HEAD.
    - Pre-push lints + pytest + flutter test exit 0 (cited in local terminal). I-04 no-new-commit sanity check passes.
    - 5-agent design panel: NO `BLOCKED` / `CRITICAL` verdicts (MAJOR with PR-body deferral block is acceptable; MINOR/SUGGESTION ships with acknowledgment per I-11 ladder).
    - PR opened on `feature/wave-1c-A3-missing-fields-handshake` → `dev` with the exact title format above.
    - `gh pr checks <N>` shows ALL jobs `pass` before `gh pr merge --squash --delete-branch`.
    - PR mergedAt non-null.
    - dev→staging bundle PR opened or queued.
    - `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-VERIFICATION-REPORT.html` exists with G3/G4/G5 cells filled and G1/G2 placeholder rows for the orchestrator to fill post-merge.
  </acceptance_criteria>
  <verify>
    <automated>echo "verified inline by orchestrator post-merge — PR mergedAt + gh pr checks output cited in wave-1c-A3-VERIFICATION-REPORT.html"</automated>
  </verify>
  <done>
    Wave A3 PR is MERGED to `dev`. dev→staging bundle PR opened (orchestrator handles re-probe + Maestro G1 + Julien G2 + status flip on Wave 1b verification report). 0-trust discipline maintained — no `shipped / ready / works` claim in plan, PR body, or commit messages without deterministic citation.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Anthropic narrator ↔ tool dispatcher | Untrusted LLM-emitted `tool_use` blocks reach the dispatcher; dispatcher must validate inputs (but for these 5 chip-emitters, `input_schema.properties` is empty so the LLM provides no fields — risk is bounded). |
| User input ↔ profile_extractor | Free-text user replies are parsed by regex; bounded by the existing 4000-char clamp + 100-char topic-sanitization patterns already in place at lines 526 and 2392 of coach_chat.py / profile_extractor.py. Confidence gating (I-01 fix) prevents off-topic numerics from contaminating the AVS slot. |
| Dispatcher ↔ CoachInsightRecord (DB) | Same-turn upsert via existing `save_insight` write path — single SQLAlchemy session, idempotent dedup on `(user_id, topic)`. Topic namespaced `profile.*` to avoid collision with LLM-saved insights. NO new `db.commit()` introduced (I-04 fix — outer turn-end commit covers it). |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-wave-1c-A3-01 | Tampering | LLM crafts a `CoachToolIncomplete`-shaped JSON in the assistant text (NOT a real tool_result) to spoof the fallback | mitigate | `CoachToolResponse.model_validate_json` runs ONLY on `tool_result.content` strings from the dispatcher path — never on raw narrator text. The fallback helper reads from `loop_result.get("tool_results")` (server-side buffer exposed by `_run_agent_loop`'s return dict per I-05 fix), not from `loop_result.get("answer")`. |
| T-wave-1c-A3-02 | Information disclosure | `hint_fr` strings + profile field names leak to Sentry breadcrumbs | accept | `user_id_hashed` is the only PII-adjacent field; truncated to first-8 chars. `missing_fields` are canonical field names (no values). `hint_fr` is static FR copy, not user-supplied. Already aligned with existing `coach.tool.<name>` breadcrumb policy. |
| T-wave-1c-A3-03 | Repudiation | User claims they never shared values that ended up in CoachInsightRecord | mitigate | Provenance encoded inline in `summary`: `"source: handshake, confidence: <float>, captured: <ISO timestamp>"`. Provides audit trail without a separate provenance column (deferred per D-A3-03). |
| T-wave-1c-A3-04 | DoS | Adversarial user reply triggers regex backtracking in `_extract_avs_years` | mitigate | Pattern is bounded by `\b\d{1,2}\b` + 25-char interstitial cap `[^,.]{0,25}` (I-07 fix tightened from 40 + period-only to 25 + comma+period) — no nested quantifiers, no catastrophic-backtracking shapes. 4000-char message clamp at `extract_profile_facts:526` is the outer guard. |
| T-wave-1c-A3-05 | Elevation of privilege | LLM emits a CoachToolPolicyBlocked status to spoof an FINMA-block on the user | accept | A3 does NOT wire any narrator-visible behavior for `policy_blocked` — the variant is reserved but unused. If a future PR wires it, it must add a server-side authority check (signed by an FINMA-gate service) so the LLM cannot self-issue the status. Tracked as a follow-up. |
| T-wave-1c-A3-06 | Data integrity (Karpathy #2) | Provenance-inline-in-summary serialization drifts if `Fact.text` format changes | mitigate | The drift test `test_coach_tools_missing_fields_instruction.py` pins the canonical `MISSING_FIELDS_INSTRUCTION_FR` substring; `test_coach_chat_handshake_persistence.py` pins the `"source: handshake"` and `"profile.*"` topic prefix patterns. Both fail loudly on drift. |
| T-wave-1c-A3-07 | Data integrity (I-01 fix) | Off-topic numerics in user reply poison the AVS slot via bare-number fallback | mitigate | I-01 fix: `_extract_avs_years` requires the AVS-anchor keyword (avs / cotisation / 1er pilier / premier pilier) for ANY match. The bare `\b\d{1,2}\s*ans\b` fallback was DELETED. Behavior fixtures pin « j'ai 42 ans, ma fille a 12 ans » → None and « j'ai 42 ans, AVS 8 ans » → 8. |
</threat_model>

<verification>
## Wave A3 close-out checks (run by orchestrator post-PR merge)

D-A3-09 5-gate exit:

- **G1** — Maestro flow `tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml` runs against staging on a fresh blank-profile user; each of the 5 sub-scenarios completes with narrator French question on turn 1 + `citation-chip-get_<name>` rendered on turn 2. Cite Maestro JUnit XML or `idb ui describe-all` snapshot.

- **G2** — Julien runs the flow on a sim, sees chips render on all 5 chip-emitters, confirms in chat. Cite Julien's chat confirmation OR a screenshot of the chip render.

- **G3** — `gh pr checks <N>` shows ALL jobs `pass` at the merge sha.

- **G4** — Full `pytest -q` exit 0 + `flutter test` exit 0 cited at the merge sha. Baseline ~6927 → A3 expected ≥6927 + new tests (lint test + handshake test set + narrator-asks test with mock-Anthropic + persistence test → ~25-30 new test cases including the I-06 parameterization).

- **G5** — `tools/checks/banned_terms_python.py` exit 0 on all 5 touched backend files; `tools/checks/accent_lint_fr.py` exit 0 on the same; lefthook gates (memory-retention, wiki-lint, banned-terms-arb, arb-parity) green at merge. I-04 sanity check (no new `db.commit()` in coach_chat.py diff) exit 0.

## Outcome branches

- **All 5 gates green** → Wave A3 mechanically closed. Orchestrator flips `wave-1c-A3-VERIFICATION-REPORT.html` to « MERGED + 5/5 gates green », opens Wave B planning (regression-test floor consumer). Wave 1b status flip on `wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html` becomes mechanically possible once Julien confirms (G2) — orchestrator provides probe evidence; Julien edits the report.

- **G1 fails on one of the 5 sub-scenarios** → A3.1 patch in scope (CONTEXT.md §D-A3-04). Open a sub-issue with the failing sub-scenario's JUnit XML; planner produces a focused 1-task PLAN.md.

- **G2 fails (Julien sees broken chip)** → Maestro covered it but Flutter widget-renderer hand-off is broken; root-cause via `flutter run --release` + Sentry trace; spawn debugger subagent.

- **Sentry breadcrumb `coach.tool.incomplete.fallback_used: true` fires in prod >1% of incomplete-returns** → narrator instruction-following has degraded; convene prompt-engineer + ai-engineer panel to revise `MISSING_FIELDS_INSTRUCTION_FR` template.

## Predecessor verification (depends_on field)

Confirm before this plan executes:
- PR #639 (Wave A2 — orchestration-layer RAG cut) MERGED to dev. `gh pr view 639 --json mergedAt` returns non-null.
- PR #641 (Wave A2.1 — FAQ-fallback guard) MERGED to dev. `gh pr view 641 --json mergedAt` returns non-null.
- The CONTEXT.md §domain mention of « separate pre-A3 A2.2 PR » is STALE — A2.1 (PR #641) already contains the `if n_results > 0:` guard at `orchestrator.py:100`. Verified 2026-05-16 via `grep -n "n_results > 0" services/backend/app/services/rag/orchestrator.py`. Executor should NOT open a separate A2.2 PR.
</verification>

<success_criteria>
- All 7 tasks A3.1–A3.7 executed in wave order (1: contract → 2 parallel: instruction + grammar + extractor → 3: agent-loop wiring → 4: tests → 5: PR open + merge).
- Branch `feature/wave-1c-A3-missing-fields-handshake` created from `origin/dev`, commits structured per D-A3-04 (1 contract + 5 tool-specific + 1 grammar + 1 extractor + 1 dispatcher + 1 tests).
- 6 backend files modified + 1 new `_response.py` + 4 new test files (flat tests/ convention) + 1 new Maestro YAML (10 files total).
- All 11 decisions D-A3-01..D-A3-11 mapped to ≥1 task body / frontmatter `wave1c_decisions_addressed` field (coverage matrix below).
- 5-agent pre-push design panel: no BLOCKED/CRITICAL verdicts per I-11 3-tier ladder.
- Pre-push: pytest + lints exit 0. I-04 no-new-commit sanity check passes.
- PR opened → CI green → merged via squash to dev.
- dev→staging bundle PR opened (or queued by orchestrator).
- `wave-1c-A3-VERIFICATION-REPORT.html` exists with G3/G4/G5 cells filled + G1/G2 placeholders.

**Decision coverage matrix:**

| D-XX | Task(s) | Coverage |
|------|---------|----------|
| D-A3-01 | A3.1, A3.5 | Full — `_response.py` + dispatcher returns JSON-encoded variant. |
| D-A3-02 | A3.2, A3.3 | Full — instruction in tool description (5 chip-emitters, I-03 format-smoke) + ~28-token pointer in citation_grammar TOP+BOTTOM. |
| D-A3-03 | A3.4, A3.5 | Full — `_extract_avs_years` (anchor-mandatory per I-01) + turn-local cache `pending_profile_updates` (high-confidence) + `pending_low_confidence_echoes` (low-confidence) + same-turn `_upsert_handshake_facts` via existing save_insight write path with single transaction (I-04 fix: no new commit). |
| D-A3-04 | A3.7 | Full — 5 chip-emitters in ONE PR (NOT 6 per codebase-verified canonical set). Surface deviation explicitly. |
| D-A3-05 | A3.6 | Full — 5 mandatory test artifacts at flat tests/ paths (I-06: mock-Anthropic round-trip in #2 per LOCKED decision, reuses test_claude_retry.py pattern). |
| D-A3-06 | A3.5 | Full — `_synthesize_handshake_fallback` wired into `_run_narrator_with_gate` empty-message branch + `tool_results` exposed in `_run_agent_loop` return dict (I-05 fix: floor is now live, not dead code) + Sentry breadcrumb. |
| D-A3-07 | A3.5 | Full — `_compute_*` / `_format_cap_status` unchanged (I-02 verbatim signatures preserved); dispatcher wraps existing data in `CoachToolOk(data=...)`. |
| D-A3-08 | A3.7 | Full — branch name + PR target + conventional commit + A2.1 already-shipped predecessor. |
| D-A3-09 | A3.7 + verification block | Full — 5 gates G1..G5 documented + status placeholders in VERIFICATION-REPORT.html. |
| D-A3-10 | A3.7 | Full — 5-agent panel composition verbatim + I-11 3-tier severity ladder. |
| D-A3-11 | A3.7 (PR body) | Full — `mem_save` topic_key pattern + `prior_finding_refs` cited in PR body. |

**Revision iteration 1 issue coverage:**

| Issue | Severity | Fixed in Task | Mechanism |
|-------|----------|---------------|-----------|
| I-01 | BLOCKER | A3.4 + A3.5 | Bare-number fallback DELETED in `_extract_avs_years`; agent loop gates on `confidence >= 0.75`; low-confidence echoes go to sibling list. |
| I-02 | BLOCKER | A3.5 | `<read_first>` includes verbatim grep result; dispatcher uses verified signatures `(user_id=user_id, ctx=ctx_merged, db=db)`; `_format_cap_status(ctx_merged)` for cap_status (no user_id/db). |
| I-03 | MAJOR | A3.2 | Import-time `.format()` smoke test wired in `<verify>` + standalone test. |
| I-04 | MAJOR | A3.5 | `_upsert_handshake_facts` does NOT call `db.commit()`; outer turn-end commit covers it; git-diff sanity check in A3.7 pre-push. |
| I-05 | MAJOR | A3.5 (Step 6a) | `tool_results` added to `_run_agent_loop` return dict at line 3773; behavior test via `inspect.getsource`. |
| I-06 | MAJOR | A3.6 | Mock-Anthropic round-trip in `test_coach_chat_narrator_asks_on_incomplete.py`, reuses `tests/coach/test_claude_retry.py` AsyncMock/MagicMock pattern. |
| I-07 | MINOR | A3.4 | Interstitial cap tightened from `[^.]{0,40}` to `[^,.]{0,25}`; new fixture pins « 42 ans, AVS 8 ans » → 8. |
| I-08 | MINOR | A3.6 | Explainer comment at top of Maestro YAML; behavior grep pins it. |
| I-09 | MINOR | A3.5 | `_FACT_TOPIC_TO_PROFILE_KEY` maps `"family"` → `"number_of_children"` (verified canonical, NOT `dependentsCount`). |
| I-10 | MINOR | A3.5 | Inventory grep in `<read_first>` shows existing tests call `_compute_*` directly, NOT `_execute_tool` — no `--deselect` needed for full-suite run. |
| I-11 | MINOR | A3.7 | 3-tier severity ladder verbatim in step 4 (replaces unrealistic « PASS clean only »). |

**Wave A3 does NOT claim « shipped » or « works ».** Per CLAUDE.md §9.5, this is « PR opened + dev-merged » only. The « works » claim is owned by the orchestrator's G1 Maestro run + G2 Julien confirmation, both post-merge.
</success_criteria>

<output>
After Wave A3 completes, this PLAN.md's status is « MERGED TO DEV — AWAITING G1 MAESTRO + G2 JULIEN ». The orchestrator handles:
- dev→staging merge + Railway poll + Maestro `coach_handshake_6_tools.yaml` run (G1)
- Julien sim walkthrough (G2)
- Wave 1b status flip on `wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html` once G2 green
- Wave B planning (regression-test floor consumer)
- Wave C teardown (instrumentation revert + Railway env var deletion)

Do NOT create a SUMMARY.md — the orchestrator composes the combined `wave-1c-SUMMARY.md` at phase close-out across A / A1 / A2 / A2.1 / A3 / B / C.
</output>
