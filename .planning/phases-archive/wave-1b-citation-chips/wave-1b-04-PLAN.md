---
phase: wave-1b
plan: 04
type: execute
wave: 1
depends_on: []
files_modified:
  - apps/mobile/lib/services/rag_service.dart
  - apps/mobile/lib/services/coach_llm_service.dart
  - apps/mobile/lib/services/coach/coach_chat_api_service.dart
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - apps/mobile/test/services/coach/tool_call_round_trip_test.dart
autonomous: true
requirements: [WAVE1B-04, WAVE1B-08]
must_haves:
  truths:
    - "Verified that the chat HTTP response carries each Wave 1a tool result with inputs_hash + computed_at + raw response payload reachable from Dart"
    - "ToolCallCitationChip Dart model exists with fields: toolName (String), inputsHash (String, 64 chars), computedAt (DateTime), rawResponse (Map<String, dynamic>)"
    - "CoachResponse.fromJson (or equivalent) deserializes a citation_chips array OR derives citation chips from existing tool_results blocks (whichever route survives the round-trip audit)"
    - "Backend serializes per-tool inputs_hash + computed_at in the chat response payload (verified via JSON dump in integration test)"
    - "Round-trip test asserts a fake backend response containing a budget_snapshot tool_result with inputs_hash='a'*64 + computed_at='2026-05-15T10:00:00Z' surfaces in Dart as ToolCallCitationChip with matching fields"
    - "wave-1b-04-AUDIT.md exists with the route decision + cap_status/retrieve_memories hash backfill strategy + 6-row tool reachability table"
  artifacts:
    - path: "apps/mobile/lib/services/rag_service.dart"
      provides: "ToolCallCitationChip Dart model + RagToolCall extension OR new ToolCallResult model"
      contains: "class ToolCallCitationChip|toolName|inputsHash|computedAt|rawResponse"
    - path: "apps/mobile/lib/services/coach_llm_service.dart"
      provides: "CoachResponse carries List<ToolCallCitationChip> citationChips field (default empty)"
      contains: "List<ToolCallCitationChip> citationChips|citationChips"
    - path: "services/backend/app/api/v1/endpoints/coach_chat.py"
      provides: "Per-tool result block in the chat response carries inputsHash + computedAt (camelCase)"
      contains: "citation_chips|citationChips|inputsHash|computedAt"
    - path: "apps/mobile/test/services/coach/tool_call_round_trip_test.dart"
      provides: "Round-trip JSON → Dart → ToolCallCitationChip test"
      contains: "test\\|expect\\|ToolCallCitationChip"
    - path: ".planning/phases/wave-1b-citation-chips/wave-1b-04-AUDIT.md"
      provides: "Audit document — route (a) or (b) decision + 6-tool reachability table + cap_status/retrieve_memories hash strategy"
      contains: "HTTP endpoint|Tool-result reachability|Route decision|Q9_DECISION"
  key_links:
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "apps/mobile/lib/services/coach_llm_service.dart"
      via: "JSON-over-HTTP — tool_results serialize backend Pydantic responses to Dart CoachResponse"
      pattern: "tool_results|citation_chips|toolCalls"
---

## Q9_DECISION — cap_status / retrieve_memories hash backfill strategy

**Status:** Pending Julien confirm at exec start.

**CONTEXT prescription:** D-02 + WAVE1B-01 = 6 registry entries (one per Wave 1a tool).

**Reality:** Only 4 / 6 Wave 1a tools have Pydantic response models with `inputs_hash` field (budget_snapshot, retirement_projection, cross_pillar_analysis, couple_optimization). `cap_status` + `retrieve_memories` lack the field today (verified via `ls services/backend/app/models/coach_tools/` audit).

**Recommended (plan adopts):** Synthetic hash via `hashlib.sha256(json.dumps(result, sort_keys=True).encode()).hexdigest()` computed at dispatcher layer for the 2 missing tools. Preserves the 6-chip user experience + respects D-02 schema (6 registry entries × 6 chips × 6 inputs_hash values). Cost: ~30 LOC in `coach_chat.py` dispatcher per tool (one synthetic-hash helper + 2 call sites).

**Alternative:** Ship 4 chips v1 + defer cap_status / retrieve_memories to wave-1c (CONTEXT non-goal already mentions wave-1c parity suite — would be a natural home).

**Risk if Julien picks alternative:** WAVE1B-01 lands as "6 registry entries declared, 4 rendering" — semantically partial. The 2 deferred entries must surface in SUMMARY.md as known-deferred (not silently). The 2 deferred chips also leave the narrator with `{{cite:tool_cap_status}}` / `{{cite:tool_retrieve_memories}}` placeholders that the gate would either reject (no chip data) or strip (which loses the citation discipline doctrine for those 2 tools).

**Plan adopts the synthetic-hash path.** Surfacing here for Julien override at exec start.

---

<objective>
**This plan is a verify-first task** per RESEARCH §5.4 + §9.6 (A1 assumption). The downstream Flutter chip widget (Plan 05) + modal (Plan 06) depend on `ToolCallCitationChip` data flowing from backend tool results to the Dart `CoachResponse`. Today (per `rag_service.dart:7-19`):

```dart
class RagToolCall {
  final String name;
  final Map<String, dynamic> input;  // <-- this is the tool INPUT, not the RESULT
  // no inputs_hash, no computed_at, no raw_response
}
```

The tool INPUT (LLM-emitted arguments) is round-tripped. The tool RESULT (Pydantic response from `_compute_<tool>`) is currently consumed by the LLM but NOT surfaced to Flutter. Wave 1b needs the RESULT side.

**Two routes** per RESEARCH §5.4:
- **(a)** Use existing `tool_calls` field if the backend already round-trips the full Pydantic dump.
- **(b)** Add a new `citation_chips` field in the chat response schema (additive, camelCase).

The plan **first verifies which route applies** (Step A audit), then **lands the chosen route**. The plan ships both wiring + an end-to-end round-trip test.

**Plan 08 dependency:** Plan 08 (Wave 2) wires Sentry breadcrumb emission against the data contract pinned here. Plan 08's Task 2 reads `wave-1b-04-AUDIT.md` mandatorily before editing `coach_chat.py`.
</objective>

## Counter-arguments considered

- **Counter-arg 1: skip audit, jump to Route (b) `citation_chips` field directly.** Rejected because Route (a) enrichment of `tool_calls` reuses existing serializer infrastructure (zero new Pydantic model). RESEARCH §4.3 shows `tool_calls` already serializes — adding 3 fields (`inputs_hash`, `computed_at`, `elapsed_ms`) is mechanical. The audit lets us pick mechanically vs additively per evidence, not assumption.
- **Counter-arg 2: ship 6 chips, accept 2 broken (cap_status, retrieve_memories).** Rejected because broken chips that tap into empty modals violate 0-trust UX. Synthetic hash (Q9_DECISION) gives all-6 working with ~30 LOC.
- **Counter-arg 3: defer Plan 04 entirely to Wave 2 (chips only for the 4 well-modeled tools).** Rejected because the citation discipline doctrine (CLAUDE.md §9 + project_coach_forced_tool_invocation) requires the LLM to cite every number from a Wave 1a tool — half-coverage means narrator can emit cap_status / retrieve_memories numbers un-cited and the gate either rejects (UX regression) or passes them silently (doctrine violation).
- **Data gap:** No real-user A/B baseline for chip tap rate — Wave 1b is the first sample. Sentry breadcrumb cardinality (Plan 08) will establish a baseline post-ship; if tap rate < 5% / week, chip UX revisits as Wave 2 polish.

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1b-citation-chips/wave-1b-CONTEXT.md
@.planning/phases/wave-1b-citation-chips/wave-1b-RESEARCH.md
@apps/mobile/lib/services/rag_service.dart
@apps/mobile/lib/services/coach_llm_service.dart
@apps/mobile/lib/services/coach/coach_chat_api_service.dart
@services/backend/app/api/v1/endpoints/coach_chat.py

<interfaces>
Current Dart RagToolCall (rag_service.dart:7-19):
```dart
class RagToolCall {
  final String name;
  final Map<String, dynamic> input;
  factory RagToolCall.fromJson(Map<String, dynamic> json) {
    return RagToolCall(
      name: json['name'] as String? ?? '',
      input: (json['input'] as Map<String, dynamic>?) ?? {},
    );
  }
}
```

Current Dart CoachResponse (coach_llm_service.dart:240-265):
```dart
class CoachResponse {
  final String message;
  final List<String>? suggestedActions;
  final String disclaimer;
  final List<RagSource> sources;
  final List<String> disclaimers;
  final bool wasFiltered;
  final List<RagToolCall> toolCalls;
  final bool degraded;
  // ...
}
```

Backend Wave 1a Pydantic response models (services/backend/app/models/coach_tools/):
- BudgetSnapshotResponse: monthly_income, monthly_expenses, monthly_surplus, months_liquidity, inputs_hash (64-char), computed_at (datetime). All camelCase aliases via to_camel.
- RetirementProjectionResponse: similar shape.
- CrossPillarAnalysisResponse: similar.
- CoupleOptimizationResponse: similar.
- cap_status / retrieve_memories: NO Pydantic model in app/models/coach_tools/ (per `ls` audit) — these may not have an `inputs_hash` in current Wave 1a code. Q9_DECISION resolves this gap.

Backend agent loop (coach_chat.py around lines 3252-3305 per RESEARCH §9.6) — where _compute_<tool>() output gets passed back to the LLM. The question is whether the **HTTP response to Flutter** carries the same payload.

Target Dart model (Wave 1b):
```dart
class ToolCallCitationChip {
  final String toolName;          // e.g. "budget_snapshot"
  final String inputsHash;        // 64-char hex SHA-256
  final DateTime computedAt;      // ISO 8601
  final Map<String, dynamic> rawResponse;  // for the modal JSON viewer

  const ToolCallCitationChip({
    required this.toolName,
    required this.inputsHash,
    required this.computedAt,
    required this.rawResponse,
  });

  factory ToolCallCitationChip.fromJson(Map<String, dynamic> json) {
    return ToolCallCitationChip(
      toolName: json['toolName'] as String? ?? json['tool_name'] as String? ?? '',
      inputsHash: json['inputsHash'] as String? ?? json['inputs_hash'] as String? ?? '',
      computedAt: DateTime.parse(json['computedAt'] as String? ?? json['computed_at'] as String? ?? ''),
      rawResponse: (json['rawResponse'] as Map<String, dynamic>?) ??
                    (json['raw_response'] as Map<String, dynamic>?) ?? {},
    );
  }
}
```

Per CONTEXT plan default Q1 + RESEARCH §3.2: ONE chip per tool call. For tools without `inputs_hash` (cap_status, retrieve_memories), the chip MAY still render with a synthetic hash (per Q9_DECISION recommended path) OR the chip is suppressed for those tools v1.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Audit backend HTTP response payload + decide route (a) or (b) + resolve Q9</name>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 3200-3400 (find the HTTP response builder for /chat or /coach/chat endpoint — look for response_model= or `return {"message": ..., "tool_calls": ...}`)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 4014-4115 (_run_narrator_with_gate wrapper per RESEARCH §8.4)
    - services/backend/app/services/coach/coach_chat.py if exists (alternate orchestrator location)
    - apps/mobile/lib/services/coach/coach_chat_api_service.dart (FULL — confirm which endpoint is called + how the response is parsed)
    - apps/mobile/lib/services/coach_llm_service.dart lines 240-280 (CoachResponse.fromJson if it exists)
    - services/backend/app/models/coach_tools/budget_snapshot.py (model_config alias_generator=to_camel — confirm camelCase serialization)
  </read_first>
  <files>
    - .planning/phases/wave-1b-citation-chips/wave-1b-04-AUDIT.md (create — single-page audit report)
  </files>
  <action>
    Step A — Grep + read:
    ```bash
    grep -n "tool_calls\|tool_results\|citation_chips" services/backend/app/api/v1/endpoints/coach_chat.py | head -20
    grep -n "response_model\|return\s*{" services/backend/app/api/v1/endpoints/coach_chat.py | head -20
    grep -n "_run_narrator_with_gate\|narrative_sleeve" services/backend/app/api/v1/endpoints/coach_chat.py | head -10
    ```

    Step B — Determine the chat endpoint's response shape. Look for the FastAPI `@router.post("/chat")` (or whatever path) handler, find what it returns, and trace each field back to its source.

    Step C — For each Wave 1a tool (budget_snapshot, retirement_projection, cross_pillar_analysis, couple_optimization, cap_status, retrieve_memories), determine whether the tool's **result** (Pydantic dump with `inputs_hash`) is included in the HTTP response sent to Flutter, OR whether it is consumed internally by the agent loop and never serialized to the client.

    Step D — Write the audit findings to `.planning/phases/wave-1b-citation-chips/wave-1b-04-AUDIT.md`:
    ```markdown
    # Wave 1b Plan 04 — Backend Response Payload Audit

    ## Section 1 — HTTP endpoint inventory
    - Path: `/api/v1/coach/chat` (or actual path found — keep the `/api/v1/coach/` prefix in the line for the lint grep)
    - File:line: services/backend/app/api/v1/endpoints/coach_chat.py:XXXX
    - Response shape today:
      ```json
      {
        "message": "...",
        "tool_calls": [{"name": "...", "input": {...}}],
        // does the backend currently serialize tool_results?
      }
      ```

    ## Section 2 — Tool-result reachability per tool
    | Tool | Result included in HTTP response? | Field path | inputs_hash present? |
    |---|---|---|---|
    | budget_snapshot | YES/NO | `tool_results[N].response` | YES/NO |
    | retirement_projection | YES/NO | ... | YES/NO |
    | cross_pillar_analysis | YES/NO | ... | YES/NO |
    | couple_optimization | YES/NO | ... | YES/NO |
    | cap_status | YES/NO | ... | YES/NO |
    | retrieve_memories | YES/NO | ... | YES/NO |

    ## Section 3 — Route decision
    - **(a) Existing tool_calls field round-trips full Pydantic dump?** YES/NO
    - **(b) Add new `citation_chips` field?** YES/NO
    - **Decision: (a) enrich tool_calls** OR **Decision: (b) add citation_chips field** — pick ONE and write the exact phrase.
    - Rationale: ... (1-3 sentences).

    ## Section 4 — Tools without inputs_hash (cap_status / retrieve_memories hash backfill strategy)
    Per Q9_DECISION block in Plan 04 frontmatter section: synthetic hash via
    `hashlib.sha256(json.dumps(result, sort_keys=True).encode()).hexdigest()`
    at the dispatcher layer for the 2 missing tools.
    - If Julien confirmed Q9_DECISION recommended path: state "Adopting Q9_DECISION synthetic-hash strategy for cap_status + retrieve_memories".
    - If Julien overrode: state "Q9_DECISION overridden — ship 4 chips v1; cap_status + retrieve_memories deferred to wave-1c. Surfaced as known-deferred in SUMMARY.md".
    ```

    Step E — Based on the audit + Q9_DECISION resolution, decide ROUTE (a) or ROUTE (b). The remaining tasks in this plan implement the chosen route.
  </action>
  <verify>
    <automated>test -f .planning/phases/wave-1b-citation-chips/wave-1b-04-AUDIT.md &amp;&amp; grep -c "Route decision\\|Q9_DECISION" .planning/phases/wave-1b-citation-chips/wave-1b-04-AUDIT.md</automated>
  </verify>
  <acceptance_criteria>
    - wave-1b-04-AUDIT.md exists at .planning/phases/wave-1b-citation-chips/wave-1b-04-AUDIT.md
    - Section 1 (HTTP endpoint inventory) — at least 1 line matches: `^- Path: \`/api/v1/coach/` (i.e., the chat endpoint path is cited by URL). Verify with `grep -cE '^- Path: \`/api/v1/coach/' .planning/phases/wave-1b-citation-chips/wave-1b-04-AUDIT.md` returns ≥1.
    - Section 2 (tool-result reachability per tool) — Markdown table with 6 rows for budget_snapshot, retirement_projection, cross_pillar_analysis, couple_optimization, cap_status, retrieve_memories. Grep: `grep -cE "^\| (budget_snapshot|retirement_projection|cross_pillar_analysis|couple_optimization|cap_status|retrieve_memories) \|" .planning/phases/wave-1b-citation-chips/wave-1b-04-AUDIT.md` returns 6.
    - Section 3 (route decision) — exactly one of: `**Decision: (a) enrich tool_calls**` OR `**Decision: (b) add citation_chips field**`. Grep: `grep -cE "^\*\*Decision: \((a|b)\)" .planning/phases/wave-1b-citation-chips/wave-1b-04-AUDIT.md` returns 1.
    - Section 4 (cap_status / retrieve_memories hash backfill strategy) — references Q9_DECISION block from frontmatter section of this plan. Grep: `grep -c "Q9_DECISION" .planning/phases/wave-1b-citation-chips/wave-1b-04-AUDIT.md` returns ≥1.
  </acceptance_criteria>
  <done>
    Audit document exists with all 4 sections populated by concrete evidence (endpoint path, 6-row tool table, route decision verbatim, Q9 resolution); downstream tasks know what to build.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Backend — ensure per-tool result payload carries inputs_hash + computed_at + raw response in HTTP response</name>
  <read_first>
    - The audit document `.planning/phases/wave-1b-citation-chips/wave-1b-04-AUDIT.md` (created by Task 1)
    - services/backend/app/api/v1/endpoints/coach_chat.py (FULL section identified in audit)
    - services/backend/app/models/coach_tools/budget_snapshot.py (Pydantic model + alias_generator=to_camel)
  </read_first>
  <files>
    - services/backend/app/api/v1/endpoints/coach_chat.py (modify if needed per audit)
  </files>
  <behavior>
    After this task, the JSON returned by the chat endpoint includes, for each tool_call that produced a Pydantic response:
    ```json
    {
      "toolCalls": [...],
      "citationChips": [
        {
          "toolName": "budget_snapshot",
          "inputsHash": "<64-hex>",
          "computedAt": "2026-05-15T10:00:00Z",
          "rawResponse": {"monthlyIncome": "...", "inputsHash": "...", ...}
        },
        ...
      ]
    }
    ```
    OR (Route a) the existing `toolCalls` array is enriched with `inputsHash` + `computedAt` + `rawResponse` per entry.

    **Route a (preferred if backend already round-trips):** Extend the `tool_calls` serializer at the chat endpoint to include the result payload alongside the input.

    **Route b (additive if Route a not possible):** Add a new `citation_chips` field to the response, computed from the loop's tool results.

    **For cap_status + retrieve_memories per Q9_DECISION:** if Julien confirmed the synthetic-hash recommended path, compute `inputs_hash` at the dispatcher layer via `hashlib.sha256(json.dumps(result, sort_keys=True).encode()).hexdigest()` and include it in the response payload alongside the other 4 tools.
  </behavior>
  <action>
    Based on the audit decision + Q9_DECISION outcome:

    **If Route (a):** Modify the existing `tool_calls` builder to also emit `inputs_hash` + `computed_at` + `raw_response` (the Pydantic `model_dump(by_alias=True)`) per tool result. Concrete pattern (assuming the endpoint loops through agent_loop results):
    ```python
    # After collecting tool_results from _run_agent_loop
    tool_calls_payload = []
    for tc in agent_result.tool_calls:
        entry = {
            "name": tc.name,
            "input": tc.input,
        }
        # Wave 1b — surface server-side computed result for chip rendering
        if tc.name in _WAVE_1B_TOOL_NAMES and tc.result is not None:
            # tc.result is one of the Wave 1a Pydantic responses; model_dump
            # serializes inputs_hash + computed_at + ... in camelCase.
            entry["inputsHash"] = tc.result.inputs_hash
            entry["computedAt"] = tc.result.computed_at.isoformat()
            entry["rawResponse"] = tc.result.model_dump(by_alias=True)
        tool_calls_payload.append(entry)
    ```

    **If Route (b):** Add a separate `citation_chips` field:
    ```python
    citation_chips = []
    for tc in agent_result.tool_calls:
        if tc.name in _WAVE_1B_TOOL_NAMES and tc.result is not None:
            citation_chips.append({
                "toolName": tc.name,
                "inputsHash": tc.result.inputs_hash,
                "computedAt": tc.result.computed_at.isoformat(),
                "rawResponse": tc.result.model_dump(by_alias=True),
            })
    response_payload["citationChips"] = citation_chips
    ```

    Define `_WAVE_1B_TOOL_NAMES = frozenset({"get_budget_status", "get_retirement_projection", "get_cross_pillar_analysis", "get_couple_optimization", "get_cap_status", "retrieve_memories"})` at module top.

    **For cap_status + retrieve_memories** — apply Q9_DECISION resolved at exec start:
    - If synthetic-hash adopted: wrap dispatcher result with a thin wrapper class exposing `inputs_hash` (via `hashlib.sha256(json.dumps(result, sort_keys=True).encode()).hexdigest()`) + `computed_at` (current UTC). Same `entry["inputsHash"] = wrapper.inputs_hash` access pattern.
    - If alternative adopted: exclude these 2 from `_WAVE_1B_TOOL_NAMES`; SUMMARY.md documents the deferred chip rendering.

    Run `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py` — MUST exit 0.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/ -q -k "chat or tool" | tail -5</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "citationChips\\|citation_chips\\|inputsHash" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (route a or b creates the field).
    - `grep -c "_WAVE_1B_TOOL_NAMES" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥2 (defined + referenced).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
    - `cd services/backend && python3 -m pytest tests/ -q | tail -1` exits 0 with no regressions.
  </acceptance_criteria>
  <done>
    HTTP response carries (per-tool) inputs_hash + computed_at + raw_response in camelCase; either via Route (a) enriched toolCalls or Route (b) citation_chips field. Q9_DECISION applied to cap_status + retrieve_memories per Julien confirmation.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Dart — add ToolCallCitationChip model + wire CoachResponse + round-trip test</name>
  <read_first>
    - apps/mobile/lib/services/rag_service.dart (FULL — match RagToolCall.fromJson pattern)
    - apps/mobile/lib/services/coach_llm_service.dart lines 240-280 (CoachResponse + fromJson if present)
    - apps/mobile/lib/services/coach/coach_chat_api_service.dart (FULL — find where the HTTP response JSON is parsed into a CoachResponse instance)
    - apps/mobile/test/services/coach/ (skim — match existing test conventions)
  </read_first>
  <files>
    - apps/mobile/lib/services/rag_service.dart (modify — add ToolCallCitationChip class)
    - apps/mobile/lib/services/coach_llm_service.dart (modify — extend CoachResponse + ChatMessage)
    - apps/mobile/lib/services/coach/coach_chat_api_service.dart (modify — parse citation_chips from response JSON)
    - apps/mobile/test/services/coach/tool_call_round_trip_test.dart (create)
  </files>
  <behavior>
    After this task:
    - `ToolCallCitationChip` Dart class exists with 4 fields + fromJson factory accepting both camelCase and snake_case keys (defensive).
    - `CoachResponse` has new field `List<ToolCallCitationChip> citationChips` (default empty).
    - `ChatMessage` has new field `List<ToolCallCitationChip> citationChips` (default empty).
    - `coach_chat_api_service.dart` parses `citationChips` (or `citation_chips`) from the response JSON and constructs the chips.
    - Round-trip test asserts a fake backend JSON containing a budget_snapshot result deserializes correctly.
  </behavior>
  <action>
    Step A — Edit `apps/mobile/lib/services/rag_service.dart`. Add after `class RagToolCall` (around line 19):
    ```dart
    /// Wave 1b — citation chip carrying tool-call provenance.
    /// Surfaces in chat messages alongside RagSource entries; renders via
    /// CoachCitationChipsSection (Plan 05) with tap-to-modal (Plan 06).
    class ToolCallCitationChip {
      final String toolName;
      final String inputsHash;
      final DateTime computedAt;
      final Map<String, dynamic> rawResponse;

      const ToolCallCitationChip({
        required this.toolName,
        required this.inputsHash,
        required this.computedAt,
        required this.rawResponse,
      });

      factory ToolCallCitationChip.fromJson(Map<String, dynamic> json) {
        final hash = (json['inputsHash'] as String?) ??
            (json['inputs_hash'] as String?) ??
            '';
        final computedAtStr = (json['computedAt'] as String?) ??
            (json['computed_at'] as String?) ??
            DateTime.now().toUtc().toIso8601String();
        return ToolCallCitationChip(
          toolName: (json['toolName'] as String?) ??
              (json['tool_name'] as String?) ??
              (json['name'] as String?) ??
              '',
          inputsHash: hash,
          computedAt: DateTime.tryParse(computedAtStr) ?? DateTime.now().toUtc(),
          rawResponse: (json['rawResponse'] as Map<String, dynamic>?) ??
              (json['raw_response'] as Map<String, dynamic>?) ??
              const <String, dynamic>{},
        );
      }
    }
    ```

    Step B — Edit `apps/mobile/lib/services/coach_llm_service.dart`. Locate `class CoachResponse` (line 240). Add field `final List<ToolCallCitationChip> citationChips;` with default `const []` and propagate through the constructor:
    ```dart
    class CoachResponse {
      // ... existing fields ...
      final List<ToolCallCitationChip> citationChips;
      // ...
      const CoachResponse({
        // ... existing args ...
        this.citationChips = const [],
      });
    }
    ```
    Also extend `class ChatMessage` similarly with `final List<ToolCallCitationChip> citationChips;` default `const []`. Update constructor.

    If a `CoachResponse.fromJson` exists in the file, extend it. If not, the parse happens in `coach_chat_api_service.dart` — Step C.

    Step C — Edit `apps/mobile/lib/services/coach/coach_chat_api_service.dart`. Locate where the chat HTTP response JSON is parsed into a `CoachResponse` or `ChatMessage`. Add:
    ```dart
    final citationChipsJson = (responseJson['citationChips'] as List<dynamic>?) ??
        (responseJson['citation_chips'] as List<dynamic>?) ??
        const <dynamic>[];
    final citationChips = citationChipsJson
        .whereType<Map<String, dynamic>>()
        .map(ToolCallCitationChip.fromJson)
        .toList();
    // Then pass citationChips into the CoachResponse / ChatMessage constructor.
    ```
    If the route is (a) — fields embedded in tool_calls — adapt to grep `inputsHash` per tool_call entry:
    ```dart
    final citationChips = toolCallsJson
        .whereType<Map<String, dynamic>>()
        .where((tc) => tc.containsKey('inputsHash') || tc.containsKey('inputs_hash'))
        .map(ToolCallCitationChip.fromJson)
        .toList();
    ```

    Step D — Create `apps/mobile/test/services/coach/tool_call_round_trip_test.dart`:
    ```dart
    // Wave 1b Plan 04 — JSON ↔ ToolCallCitationChip round-trip test.
    import 'package:flutter_test/flutter_test.dart';
    import 'package:mint_mobile/services/rag_service.dart';

    void main() {
      group('ToolCallCitationChip.fromJson', () {
        test('accepts camelCase keys (backend default)', () {
          final json = {
            'toolName': 'budget_snapshot',
            'inputsHash': 'a' * 64,
            'computedAt': '2026-05-15T10:00:00.000Z',
            'rawResponse': {'monthlyIncome': '7500'},
          };
          final chip = ToolCallCitationChip.fromJson(json);
          expect(chip.toolName, 'budget_snapshot');
          expect(chip.inputsHash, 'a' * 64);
          expect(chip.computedAt.toUtc().toIso8601String(),
              '2026-05-15T10:00:00.000Z');
          expect(chip.rawResponse['monthlyIncome'], '7500');
        });

        test('falls back to snake_case keys for resilience', () {
          final json = {
            'tool_name': 'retirement_projection',
            'inputs_hash': 'b' * 64,
            'computed_at': '2026-05-15T11:00:00.000Z',
            'raw_response': {'totalMonthly': '4200'},
          };
          final chip = ToolCallCitationChip.fromJson(json);
          expect(chip.toolName, 'retirement_projection');
          expect(chip.inputsHash, 'b' * 64);
        });

        test('handles missing fields with safe defaults', () {
          final chip = ToolCallCitationChip.fromJson(<String, dynamic>{});
          expect(chip.toolName, '');
          expect(chip.inputsHash, '');
          expect(chip.rawResponse.isEmpty, true);
        });

        test('handles all 6 Wave 1a tool names', () {
          for (final name in const [
            'budget_snapshot',
            'retirement_projection',
            'cross_pillar_analysis',
            'couple_optimization',
            'cap_status',
            'retrieve_memories',
          ]) {
            final chip = ToolCallCitationChip.fromJson({
              'toolName': name,
              'inputsHash': 'c' * 64,
              'computedAt': '2026-05-15T12:00:00.000Z',
              'rawResponse': {'_test': true},
            });
            expect(chip.toolName, name);
          }
        });
      });
    }
    ```

    Step E — Run `cd apps/mobile && flutter analyze && flutter test test/services/coach/tool_call_round_trip_test.dart`. MUST exit 0.
  </action>
  <verify>
    <automated>cd apps/mobile &amp;&amp; flutter test test/services/coach/tool_call_round_trip_test.dart</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "class ToolCallCitationChip" apps/mobile/lib/services/rag_service.dart` returns 1.
    - `grep -c "List<ToolCallCitationChip> citationChips" apps/mobile/lib/services/coach_llm_service.dart` returns ≥2 (CoachResponse + ChatMessage).
    - `grep -c "ToolCallCitationChip.fromJson\\|citationChips" apps/mobile/lib/services/coach/coach_chat_api_service.dart` returns ≥1.
    - `test -f apps/mobile/test/services/coach/tool_call_round_trip_test.dart` exits 0.
    - `cd apps/mobile && flutter test test/services/coach/tool_call_round_trip_test.dart 2>&1 | grep -E "All tests passed"` returns non-empty.
    - `cd apps/mobile && flutter analyze 2>&1 | grep -c "error"` returns 0 (no new analyzer errors).
  </acceptance_criteria>
  <done>
    ToolCallCitationChip Dart model exists; CoachResponse + ChatMessage carry citationChips field; round-trip test exits 0; Plan 05 can build the widget against this contract.
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1B-04-01 | T | Audit assumes backend round-trips tool results when it actually doesn't | mitigate | Task 1 produces a written audit document with grep-anchored evidence before Tasks 2-3 land code. Route decision documented in AUDIT.md. |
| T-WAVE1B-04-02 | I | rawResponse payload leaks PII (e.g. CHF amounts, AHV numbers) into Sentry / logs | mitigate | rawResponse is rendered client-side in the modal JSON viewer ONLY; never sent back to backend or telemetry. inputs_hash is non-PII (irreversible SHA-256). Tested in Plan 08's breadcrumb contract tests. |
| T-WAVE1B-04-03 | T | cap_status / retrieve_memories lack inputs_hash; chip count drops from 6 to 4 | mitigate | Q9_DECISION block + Task 1 audit Section 4 explicitly resolve this at exec start. Synthetic hash recommended; alternative documented if Julien overrides. |
| T-WAVE1B-04-04 | E | Backend field name drift (citation_chips vs citationChips vs tool_calls.inputs_hash) breaks Dart parser | mitigate | Dart fromJson is defensive: accepts both camelCase + snake_case. Round-trip test asserts both shapes. |
</threat_model>

<verification>
- `cd apps/mobile && flutter test test/services/coach/tool_call_round_trip_test.dart -q` exits 0.
- `cd services/backend && python3 -m pytest tests/ -q | tail -1` exits 0 (no regressions).
- AUDIT.md file exists with route decision + Q9 resolution.
- `cd apps/mobile && flutter analyze` produces no new errors.
</verification>

<success_criteria>
- A1 assumption from RESEARCH §9.6 resolved (audit done, route chosen, contract pinned, Q9 cap_status/retrieve_memories hash strategy resolved).
- Dart ToolCallCitationChip model exists.
- CoachResponse + ChatMessage carry citationChips.
- Round-trip test (≥4 cases) exits 0.
- Plan 05 can land the widget without further schema investigation.
- Plan 08 can wire breadcrumb emission against the AUDIT.md-pinned field names.
</success_criteria>

<output>
After completion create `.planning/phases/wave-1b-citation-chips/wave-1b-04-SUMMARY.md` with:
- Route decision (a or b) + rationale
- 4 / 6 tool coverage for chips (depending on Q9_DECISION outcome — synthetic-hash → 6, alternative → 4 + 2 deferred)
- Diff size (backend + 3 Dart files)
- 0-trust self-check citing test output verbatim
</output>
</content>
</invoke>
