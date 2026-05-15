# Wave 1b Plan 04 — Backend Response Payload Audit

> Verify-first audit per RESEARCH §9.6 (A1 assumption probe). Produced before Tasks 2-3 touch any production code. The route decision in §3 is the contract Plans 05/06/08 build against.

## Section 1 — HTTP endpoint inventory

- Path: `/api/v1/coach/chat` (FastAPI `@router.post("/chat", response_model=CoachChatResponse, response_model_by_alias=True)`)
- File:line: `services/backend/app/api/v1/endpoints/coach_chat.py:3338-3351` (decorator), `coach_chat.py:4196-4208` (return)
- Response schema: `services/backend/app/schemas/coach_chat.py:175-238` (`CoachChatResponse`, camelCase via `alias_generator=to_camel`).
- Response shape today (camelCase on the wire):
  ```json
  {
    "message": "...",
    "toolCalls": [{"name": "...", "input": {...}}],
    "sources": [...],
    "cashLevel": 3,
    "disclaimers": [...],
    "tokensUsed": 0,
    "systemPromptUsed": true,
    "responseMeta": {"degraded": false, "modelUsed": "...", "budgetTier": "..."},
    "narrativeSleeve": null
  }
  ```
- **`toolCalls` only carries EXTERNAL (Flutter-bound) tool calls** — internal tools (the 6 Wave 1a tools, plus save_fact / set_goal / etc.) are filtered out at `coach_chat.py:3192-3197` before assignment to `flutter_tool_calls`. The filter is enforced via `INTERNAL_TOOL_NAMES` (defined at `services/backend/app/services/coach/coach_tools.py:57-90`).
- **Confirmed via grep**: `grep -n "INTERNAL_TOOL_NAMES" services/backend/app/services/coach/coach_tools.py` shows lines 57-64 contain ALL 6 Wave 1a tool names (`retrieve_memories`, `get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`, `get_cap_status`, `get_couple_optimization`).

## Section 2 — Tool-result reachability per tool

The 6 Wave 1a `_compute_*` dispatch branches (`coach_chat.py:1998-2021`) return a Python `str` to the agent loop. The string is the JSON dump of the Pydantic response (`response.model_dump_json(by_alias=True)`) when the flag is ON and the success path is taken. The string is appended into the LLM's next-iteration prompt at `coach_chat.py:3286-3288` (`f"[{call.get('name', 'unknown')}] {result_text}"`), then **the LLM reads it and produces the answer text**. The Pydantic object itself (with `inputs_hash`, `computed_at`, `monthly_income`, ...) is **never returned upward** to the endpoint handler and **never serialized to the HTTP response**. The endpoint receives `loop_result["tool_calls"]` which is `flutter_tool_calls` — only EXTERNAL calls.

| Tool | Result included in HTTP response? | Field path | inputs_hash present? |
|---|---|---|---|
| budget_snapshot | NO | not serialized (string consumed by LLM only, `coach_chat.py:3287` → next prompt iteration) | YES in Pydantic, NO in HTTP response (`_compute_budget_status` returns `model_dump_json(by_alias=True)` at `coach_chat.py:2441`; never round-tripped) |
| retirement_projection | NO | same — string-only, consumed by LLM | YES in Pydantic (`coach_chat.py:2546-2558`), NO in HTTP response |
| cross_pillar_analysis | NO | same — string-only, consumed by LLM | YES in Pydantic (`coach_chat.py:2669-2683`), NO in HTTP response |
| couple_optimization | NO | same — string-only, consumed by LLM | YES in Pydantic (`coach_chat.py:2921-2932`), NO in HTTP response |
| cap_status | NO | `_validate_cap_response(_format_cap_status(ctx))` returns plain FR string with NO Pydantic wrapper (`coach_chat.py:2015`, `2723-2773`, `2776-2804`) | NO — no Pydantic model exists for cap_status (`ls services/backend/app/models/coach_tools/` confirms: only `budget_snapshot.py`, `couple_optimization.py`, `cross_pillar.py`, `retirement_projection.py`, `__init__.py`). |
| retrieve_memories | NO | `_compute_retrieve_memories` returns newline-joined FR string (`coach_chat.py:929-979`); `inputs_hash` is computed (`coach_chat.py:974`) only for the Sentry breadcrumb payload, NOT serialized into the returned string. | inputs_hash computed for breadcrumb only (`coach_chat.py:974`), NO Pydantic response model, NO HTTP exposure. |

**Verdict on A1 assumption (RESEARCH §9.6 / §5.4):** **A1 is FALSE.** Today the Wave 1a Pydantic dumps (with `inputs_hash`, `computed_at`, `monthly_income`, …) reach the **LLM context** (as text appended to the next iteration's prompt) but **NOT the Flutter client**. Route (a) — "enrich existing `toolCalls` field" — does not apply because `toolCalls` is filtered to EXTERNAL tools only, and the 6 Wave 1a tools are all INTERNAL. Route (b) — "add a new `citationChips` field" — is the only viable path.

## Section 3 — Route decision

- **(a) Existing tool_calls field round-trips full Pydantic dump?** NO
- **(b) Add new `citation_chips` field?** YES

**Decision: (b) add citation_chips field**

- Rationale: per §2 evidence, the 6 Wave 1a tool results never reach `flutter_tool_calls` (they are filtered out by `INTERNAL_TOOL_NAMES`). The Pydantic dump is consumed by the LLM only, then discarded. Adding a new top-level `citationChips: List[CitationChipPayload]` field on `CoachChatResponse` is the minimal additive change. Plumbing: `_run_agent_loop` is extended to collect a `citation_chips` list alongside `flutter_tool_calls`; each internal-tool execution whose `_compute_*` returned a Pydantic Wave 1a response appends one entry with `toolName`, `inputsHash`, `computedAt`, `rawResponse`. The endpoint passes `loop_result["citation_chips"]` into the response. Karpathy #3 surgical: zero edits inside the existing INTERNAL_TOOL_NAMES filter; no change to `flutter_tool_calls` semantics; the new collection runs in parallel.

## Section 4 — Tools without inputs_hash (cap_status / retrieve_memories hash backfill strategy)

Per Q9_DECISION block in `wave-1b-04-PLAN.md` frontmatter (lines 46-60) — only 4 of 6 Wave 1a tools have Pydantic response models with `inputs_hash`. `cap_status` returns a plain FR string from `_format_cap_status` + `_validate_cap_response` (`coach_chat.py:2015`); `retrieve_memories` returns a newline-joined FR string from `_compute_retrieve_memories` (`coach_chat.py:929-979`) and computes `inputs_hash` only for the Sentry breadcrumb (`coach_chat.py:974`), never returning it upward.

**Sequential exec mode — Julien did not interactively confirm Q9_DECISION at exec start.** Plan adopts the recommended path: **Adopting Q9_DECISION synthetic-hash strategy for cap_status + retrieve_memories** via `hashlib.sha256(json.dumps(result, sort_keys=True).encode()).hexdigest()` computed at the dispatcher layer. This preserves the 6-chip user experience (D-02 schema, 6 registry entries × 6 chips × 6 `inputs_hash` values) and respects WAVE1B-01 (6 entries declared + 6 chips rendering). Cost: ~30 LOC in the dispatcher wrapper to wrap the string result with a synthetic-hash + computed_at + raw_response (where raw_response is `{"text": <string>}` for the 2 string-returning tools).

If Julien overrides at PR review, the alternative is shipping 4 chips v1 + deferring cap_status / retrieve_memories to wave-1c — surfaced as known-deferred in SUMMARY.md. The Plan-04 dispatcher would then exclude `get_cap_status` and `retrieve_memories` from the `_WAVE_1B_TOOL_NAMES` collection set, and the 2 narrator placeholders `{{cite:tool_cap_status}}` / `{{cite:tool_retrieve_memories}}` would either be rejected by the gate (UX regression — 2 of 6 tools cannot be cited despite Plan 02 declaring them in the registry) or stripped (citation discipline doctrine violation).

**Plan-04 ships the synthetic-hash path.** Documented here so Julien override path is a one-line frontmatter edit in Plan-05/08 if needed.

## Section 5 — Implementation impact

Per the Route (b) decision + Q9 synthetic-hash adoption:

- **Backend** (Task 2):
  - `services/backend/app/api/v1/endpoints/coach_chat.py` — extend `_run_agent_loop` signature/return to include a `citation_chips: list` collection. Within the internal-tool execution loop (around `coach_chat.py:3262-3294`), after `_execute_internal_tool` returns its result string, if `call["name"]` is in `_WAVE_1B_TOOL_NAMES`, parse the JSON string back into a dict (or synthesize one for cap_status/retrieve_memories) and append a chip entry with `toolName`, `inputsHash`, `computedAt`, `rawResponse`.
  - `services/backend/app/schemas/coach_chat.py` — add `citation_chips: list[dict[str, Any]] | None = None` field (camelCase alias `citationChips`).
  - `services/backend/app/api/v1/endpoints/coach_chat.py:4196-4208` — pass `citation_chips=loop_result.get("citation_chips")` into the `CoachChatResponse(...)` return.
- **Dart** (Task 3):
  - `apps/mobile/lib/services/rag_service.dart` — add `ToolCallCitationChip` class with 4 fields + fromJson factory (defensive: camelCase + snake_case).
  - `apps/mobile/lib/services/coach_llm_service.dart` — extend `CoachResponse` + `ChatMessage` with `List<ToolCallCitationChip> citationChips` (default empty).
  - `apps/mobile/lib/services/coach/coach_chat_api_service.dart` — extend `CoachChatApiResponse` with `citationChips` field; parse `json['citationChips']` (or `json['citation_chips']` fallback) into a `List<ToolCallCitationChip>`.
  - `apps/mobile/test/services/coach/tool_call_round_trip_test.dart` — round-trip test (≥4 cases).
- **Threats addressed**:
  - T-WAVE1B-04-01 (audit assumes round-trip) — RESOLVED: §2 evidence proves A1 was FALSE; Route (b) added as new field rather than blindly reusing toolCalls.
  - T-WAVE1B-04-02 (PII in rawResponse) — rawResponse contains `monthlyIncome` / `monthlyExpenses` / `monthlySurplus` etc. — these are CHF amounts derived from the user's own profile (already in profile_context) so re-exposing them to the same user's session is not a new leak surface. NEVER sent back to backend or telemetry per Plan 08 contract.
  - T-WAVE1B-04-03 (cap_status / retrieve_memories no inputs_hash) — RESOLVED via Q9 synthetic-hash adoption (§4).
  - T-WAVE1B-04-04 (field name drift) — RESOLVED via defensive Dart fromJson accepting both camelCase + snake_case keys.

## Section 6 — Tool reachability conclusion

A1 FALSE: zero of the 6 Wave 1a tools currently round-trip their Pydantic response to Flutter. Route (b) is mechanically required, not a choice. Q9 synthetic-hash extends the chip coverage from 4/6 (Pydantic-modeled) to 6/6 (synthetic for cap_status/retrieve_memories).
