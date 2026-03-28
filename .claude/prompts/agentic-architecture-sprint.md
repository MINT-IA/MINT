# AGENTIC ARCHITECTURE SPRINT — Production-Ready Implementation

> Execute in strict priority order. Each P-level unlocks the next.
> Do NOT start P1 until P0 is green. Do NOT start P2 until P1 is green.
> "Green" = flutter analyze 0 issues + all existing tests pass + new tests pass.

---

## CONTEXT — What exists today (read these files FIRST)

Before writing ANY code, read and understand:

```
# Backend coach pipeline (the code you're extending)
services/backend/app/api/v1/endpoints/coach_chat.py    # The endpoint you're modifying
services/backend/app/services/coach/coach_tools.py     # Tool definitions with categories
services/backend/app/services/coach/claude_coach_service.py  # System prompt builder
services/backend/app/services/coach/structured_reasoning.py  # Deterministic reasoning layer

# Frontend coach (the consumer)
apps/mobile/lib/screens/coach/coach_chat_screen.dart   # Chat UI — consumes tool_calls
apps/mobile/lib/services/coach/voice_service.dart      # Voice stub — you're wiring TTS
apps/mobile/lib/services/voice/platform_voice_backend.dart  # Platform channel probing
apps/mobile/lib/services/voice/voice_state_machine.dart     # State machine (idle→listening→processing→speaking)

# State layer (source of truth)
apps/mobile/lib/models/mint_user_state.dart            # Unified state
apps/mobile/lib/services/mint_state_engine.dart        # State assembler
apps/mobile/lib/providers/mint_state_provider.dart     # Reactive provider

# Financial core (calculators you'll expose as tools)
apps/mobile/lib/services/financial_core/financial_core.dart  # Barrel export
apps/mobile/lib/services/financial_core/cross_pillar_calculator.dart  # VZ-grade analysis
apps/mobile/lib/services/retirement_projection_service.dart
apps/mobile/lib/services/budget_living_engine.dart
apps/mobile/lib/services/forecaster_service.dart

# Rules (NON-NEGOTIABLE)
CLAUDE.md    # Project rules, compliance, anti-patterns
rules.md     # Tier 1 rules
```

### Architecture invariants you MUST respect

1. **Backend = orchestrator, Flutter = executor.** The backend decides intent via LLM. Flutter decides routing via RoutePlanner + ScreenRegistry. The backend NEVER emits raw GoRouter routes.
2. **ComplianceGuard on ALL LLM output.** Every text response passes through compliance filter before reaching the user. No exceptions.
3. **BYOK model.** The API key comes from the user per-request. It is NEVER stored, logged, or persisted.
4. **Read-only posture.** MINT never moves money. Write tools modify user STATE (goals, steps, insights), never financial instruments.
5. **financial_core/ is the ONLY calculator.** Never create local `_calculate*()` methods. Always delegate to the existing calculators.
6. **All user-facing strings via ARB.** No hardcoded French. Add keys to ALL 6 ARB files. Run `flutter gen-l10n` after.
7. **Tests required.** Every new service: minimum 10 tests. Every bug fix: regression test. Golden couple (Julien + Lauren) tested where applicable.

---

## P0-A — AGENT LOOP (tool_use → execute → re-call LLM)

### Problem
`coach_chat.py` makes ONE LLM call. If the LLM returns a `tool_use` block (e.g. `retrieve_memories`, `set_goal`), the tool is not executed — the raw `tool_use` is returned to Flutter. Internal tools like `retrieve_memories` never produce results.

### What to build
A **tool execution loop** in `coach_chat.py` that:
1. Calls the LLM (orchestrator.query with tools)
2. Inspects the response for `tool_use` blocks
3. For each `tool_use` in `INTERNAL_TOOL_NAMES`: execute locally, collect `tool_result`
4. For each `tool_use` NOT in `INTERNAL_TOOL_NAMES`: collect for Flutter forwarding
5. If any internal tools were executed: re-call the LLM with the `tool_result` messages appended
6. Repeat until `stop_reason == "end_turn"` OR max 5 iterations (safety cap)
7. Return final text + any remaining Flutter-bound `tool_calls`

### Existing code to use
- `_handle_retrieve_memories(topic, memory_block, max_results)` in `coach_chat.py` — already implements the memory search logic. Currently returns a string inline. Refactor to return as `tool_result`.
- `INTERNAL_TOOL_NAMES` in `coach_tools.py` — list of tools handled by backend.
- `_strip_internal_fields()` — already strips `category`/`access_level` before LLM call.
- The LLM client (`orchestrator.query`) already supports `tools` parameter.

### Implementation spec

```python
# In coach_chat.py — replace the single orchestrator.query call

MAX_TOOL_ITERATIONS = 5

async def _run_agent_loop(
    orchestrator,
    question: str,
    api_key: str,
    provider: str,
    model: str | None,
    profile_context: dict | None,
    language: str,
    system_prompt: str,
    memory_block: str | None,
) -> dict:
    """Run the LLM agent loop until end_turn or max iterations.

    Returns the final orchestrator result dict with:
      - answer: str (final text, compliance-filtered)
      - tool_calls: list[dict] | None (Flutter-bound tool_use blocks only)
      - sources, disclaimers, tokens_used: as before
    """
    messages = []  # Conversation turns for multi-turn
    flutter_tool_calls = []
    final_answer = ""
    total_tokens = 0
    all_sources = []
    all_disclaimers = []

    for iteration in range(MAX_TOOL_ITERATIONS):
        # Call LLM
        result = await orchestrator.query(
            question=question if iteration == 0 else "",
            api_key=api_key,
            provider=provider,
            model=model,
            profile_context=profile_context,
            language=language,
            tools=_get_clean_tools(),  # stripped of internal fields
        )

        total_tokens += result.get("tokens_used", 0)
        all_sources.extend(result.get("sources", []))
        all_disclaimers.extend(result.get("disclaimers", []))

        raw_tool_calls = result.get("tool_calls") or []
        answer_text = result.get("answer", "")

        # Separate internal vs Flutter tool calls
        internal_calls = [t for t in raw_tool_calls if t["name"] in INTERNAL_TOOL_NAMES]
        external_calls = [t for t in raw_tool_calls if t["name"] not in INTERNAL_TOOL_NAMES]
        flutter_tool_calls.extend(external_calls)

        # If no internal tools to execute, we're done
        if not internal_calls:
            final_answer = answer_text
            break

        # Execute internal tools
        tool_results = []
        for call in internal_calls:
            if call["name"] == "retrieve_memories":
                result_text = _handle_retrieve_memories(
                    topic=call.get("input", {}).get("topic", ""),
                    memory_block=memory_block,
                    max_results=call.get("input", {}).get("max_results", 3),
                )
                tool_results.append({
                    "tool_use_id": call.get("id", ""),
                    "content": result_text,
                })

        # Append tool results to the question for the next iteration
        # The orchestrator needs to support multi-turn — if it doesn't,
        # append tool results inline to the question text as a pragmatic V1.
        question = f"{answer_text}\n\n[Résultats mémoire]\n" + "\n".join(
            r["content"] for r in tool_results
        )

    return {
        "answer": final_answer,
        "tool_calls": flutter_tool_calls if flutter_tool_calls else None,
        "sources": _deduplicate_sources(all_sources),
        "disclaimers": list(set(all_disclaimers)),
        "tokens_used": total_tokens,
    }
```

### Critical constraints
- **Max 5 iterations.** Prevent infinite loops. Log a warning if max is hit.
- **Internal tools NEVER forwarded to Flutter.** Filter them out of the response.
- **ComplianceGuard runs on the FINAL answer only** (not intermediate turns).
- **Token budget awareness.** Sum tokens across iterations. If > 8000, break.
- **The orchestrator.query may not support multi-turn messages natively.** If so, use the pragmatic approach: append tool results as text in the next question. This is V1. Multi-turn with proper `tool_result` blocks is V2.

### Write tools execution
For P0, the 3 write tools (`set_goal`, `mark_step_completed`, `save_insight`) should be:
- Intercepted by the backend (add to `INTERNAL_TOOL_NAMES`)
- Executed by calling the appropriate service (GoalSelectionService, CapMemoryStore, CoachMemoryService)
- Results returned as tool_result so the LLM can confirm to the user

**OR** forwarded to Flutter for execution (simpler, already has the services). Decision: forward to Flutter for V1. The write tools are user-visible actions (the user should see "Goal set to retirement"). Add them to INTERNAL_TOOL_NAMES only when backend-side execution is needed.

### Tests required (minimum 15)
- Loop terminates on end_turn (no tool_calls in response)
- Loop executes retrieve_memories and re-calls LLM
- Loop caps at MAX_TOOL_ITERATIONS
- Internal tools filtered from final response
- Flutter tool_calls preserved in final response
- Empty memory_block → graceful "no memory" result
- Token accumulation across iterations
- ComplianceGuard applied only to final answer
- Mixed internal + external tool_calls in same response
- retrieve_memories with no match → "pas de mémoire" response
- Error in tool execution → loop continues with error message
- Multiple internal tools in single response → all executed

---

## P0-B — STRIP CATEGORY/ACCESS_LEVEL (quick fix)

### Problem
Already partially done in commit 54f0cab. Verify that `_strip_internal_fields()` is called on `COACH_TOOLS` before every `orchestrator.query()` call, including in the new agent loop.

### What to build
A helper function in `coach_tools.py`:

```python
def get_llm_tools() -> list[dict]:
    """Return COACH_TOOLS cleaned for the Anthropic API.

    Strips backend-only fields (category, access_level) that the
    LLM API does not understand. These fields are used by
    get_tools_by_category() and get_read_only_tools() for
    backend access control only.
    """
    return [
        {k: v for k, v in tool.items() if k not in ("category", "access_level")}
        for tool in COACH_TOOLS
    ]
```

Use `get_llm_tools()` everywhere the tools are passed to the LLM. Never pass `COACH_TOOLS` raw.

### Tests: 3
- `get_llm_tools()` returns same count as `COACH_TOOLS`
- No dict in result contains "category" or "access_level"
- Tool names and schemas are preserved

---

## P1-A — STRUCTURED REASONING WIRED IN ENDPOINT

### Problem
`StructuredReasoningService.reason()` exists and produces `ReasoningOutput`. It's called in `coach_chat.py` and injected into the system prompt. Verify this is ACTUALLY working end-to-end.

### What to verify/fix
1. Read `coach_chat.py` lines 228-241 — the reasoning block is injected after the system prompt.
2. Verify `StructuredReasoningService.reason()` receives the right profile_context keys.
3. Verify `as_system_prompt_block()` produces a non-empty string for profiles with data.
4. Verify the LLM actually references the ANALYSE PRÉALABLE block in its responses (manual test with a real API key, not automated).

### If NOT wired
Wire it exactly as currently done in coach_chat.py (which appears correct from the audit). Add integration tests that verify the system prompt contains "ANALYSE PRÉALABLE" when profile data triggers a fact.

### Tests: 5
- Profile with deficit → system prompt contains "ANALYSE PRÉALABLE" and "deficit"
- Profile with 3a gap in December → prompt contains "3a_deadline"
- Profile with low replacement rate → prompt contains "gap_warning"
- Empty profile → no ANALYSE PRÉALABLE block (empty string)
- Reasoning output confidence is reflected in the block text

---

## P1-B — TTS BASIC (1 voice)

### Problem
`VoiceService` has a stub backend. `PlatformVoiceBackend` probes platform channels but STT/TTS plugins are not in pubspec. The voice state machine is ready (290 tests).

### What to build
Wire `flutter_tts` plugin for TEXT-TO-SPEECH only (reading coach responses aloud).

### Steps
1. Add `flutter_tts: ^4.0.0` to `apps/mobile/pubspec.yaml`
2. In `PlatformVoiceBackend`:
   - `isTtsAvailable()` → probe the flutter_tts channel (already structured for this)
   - `speak(text)` → call `FlutterTts().speak(text)` with French locale
   - `stopSpeaking()` → call `FlutterTts().stop()`
3. In `coach_chat_screen.dart`:
   - Add a "read aloud" button on coach messages (icon: `volume_up`)
   - On tap: `_voiceService.speak(message.text)`
   - While speaking: show a "stop" button. On tap: `_voiceService.stop()`
   - Respect `_voiceTtsAvailable` — hide button if TTS not available
4. Voice settings: speech rate 0.45 (calm, not robotic), pitch 1.0, locale `fr-CH`

### Constraints
- NO STT in this ticket. STT is P3+.
- NO ElevenLabs. Use native platform TTS (free, offline-capable).
- Accessibility: if `MediaQuery.of(context).accessibleNavigation`, auto-speak coach responses.
- The "read aloud" button must be an `IconButton` with `Semantics(label: l.ttsReadAloud)`.
- Add 1 ARB key per language: `ttsReadAloud` / `ttsStopReading`.

### Tests: 8
- TTS button visible when `_voiceTtsAvailable == true`
- TTS button hidden when `_voiceTtsAvailable == false`
- Tap TTS button → VoiceService.speak called
- Tap stop button → VoiceService.stop called
- State machine transition: idle → speaking → idle
- Voice state machine rejects speaking → listening (invalid)
- PlatformVoiceBackend degrades gracefully on missing plugin
- flutter_tts locale set to fr-CH

---

## P2 — DATA LOOKUP TOOLS

### Problem
The LLM cannot currently READ the user's financial calculations. It can only display widgets (`show_budget_snapshot`, `show_score_gauge`). To reason about the user's numbers, it needs DATA tools that return structured information.

### What to build
4 new tools in `coach_tools.py`:

```python
# 1. get_budget_status — returns BudgetSnapshot data as text
{
    "name": "get_budget_status",
    "category": "read",
    "access_level": "user_scoped",
    "description": "Get the user's current budget status: monthly net income, "
                   "fixed charges, savings, and free margin (monthlyFree). "
                   "Returns structured data so you can reason about it.",
    "input_schema": {"type": "object", "properties": {}, "required": []},
}

# 2. get_retirement_projection — returns replacement rate, gap, actions
{
    "name": "get_retirement_projection",
    "category": "read",
    ...
}

# 3. get_cross_pillar_analysis — returns CrossPillarCalculator insights
{
    "name": "get_cross_pillar_analysis",
    "category": "read",
    ...
}

# 4. get_cap_status — returns current cap, sequence progress, next step
{
    "name": "get_cap_status",
    "category": "read",
    ...
}
```

### Execution pattern
These tools are INTERNAL (add to `INTERNAL_TOOL_NAMES`). When the LLM calls `get_budget_status`, the backend:
1. Reads `profile_context` from the request body
2. Computes the result using the deterministic services (or reads from pre-computed cache)
3. Returns a formatted text result to the LLM as `tool_result`
4. The LLM incorporates the data into its response

### Implementation approach
The backend doesn't have direct access to Flutter's `BudgetLivingEngine` or `CrossPillarCalculator` (those are Dart). Two options:

**Option A (recommended):** The Flutter client includes pre-computed data in `profile_context`:
```json
{
  "monthly_free": 1340,
  "replacement_rate": 0.63,
  "budget_stage": "fullGapVisible",
  "cross_pillar_insights": [
    {"type": "pillar3aOptimization", "impact_chf": 1800, "confidence": 0.6}
  ]
}
```
The backend tool handler just formats this data as readable text for the LLM.

**Option B:** Mirror the calculators in Python (expensive, drift risk).

Go with Option A. Flutter already has MintUserState with all computed data. Serialize the relevant fields into `profile_context` before sending to the backend.

### Flutter side changes
In `coach_chat_screen.dart`, when building the API request body, include:
```dart
final mintState = context.read<MintStateProvider>().state;
final profileContext = {
  ...existingProfileContext,
  'monthly_free': mintState?.monthlyFree,
  'replacement_rate': mintState?.replacementRate,
  'budget_stage': mintState?.budgetSnapshot?.stage.name,
  'fri_score': mintState?.friScore,
  'cap_id': mintState?.currentCap?.id,
  'cap_headline': mintState?.currentCap?.headline,
  'sequence_completed': mintState?.capSequencePlan?.completedCount,
  'sequence_total': mintState?.capSequencePlan?.totalCount,
};
```

### Tests: 12
- Each tool returns non-empty text when profile has data
- Each tool returns "data not available" when profile is empty
- Tool results are formatted as human-readable text (not JSON)
- Profile context fields are serialized from MintUserState
- Tools are in INTERNAL_TOOL_NAMES (never forwarded to Flutter)
- Agent loop executes data lookup tools and re-calls LLM

---

## P3-A — VECTOR STORE

### When to implement
When the RAG corpus exceeds ~100 documents OR when keyword search produces poor recall.

### What to build
- Add `pgvector` extension to the existing Railway PostgreSQL
- Embed the 45 education concepts + FAQ entries using `text-embedding-3-small`
- Replace keyword search in `FaqService.search()` with vector similarity
- Keep keyword as fallback when vector store is unavailable

### Not now because
The current keyword search over 45 concepts works. The bottleneck is the agent loop (P0), not retrieval quality.

---

## P3-B — MULTI-AGENT

### When to implement
When the single-agent system prompt exceeds ~4000 tokens OR when domain-specific reasoning quality degrades.

### What to build
- An orchestrator prompt that classifies the user's intent into a domain (retraite, budget, fiscalité, événement, éducation, profil)
- Domain-specific system prompts with focused legal context
- Router that selects the right prompt + tool subset

### Not now because
The single prompt with lifecycle awareness + plan awareness + structured reasoning handles all current use cases. The `StructuredReasoningService` already provides domain-specific reasoning without multi-agent complexity.

### When the time comes
Start with a routing prompt, not separate processes. Same LLM, different system prompt selected by a classifier. This is 80% of multi-agent value at 10% of the complexity.

---

## EXECUTION CHECKLIST

For each P-level:
1. [ ] Read all referenced source files BEFORE writing code
2. [ ] `git branch --show-current` — confirm on feature branch
3. [ ] Implement the feature
4. [ ] Write tests (minimum count specified per feature)
5. [ ] `flutter analyze` — 0 issues
6. [ ] `flutter test` — all pass
7. [ ] `cd services/backend && python3 -m pytest tests/ -q` — all pass
8. [ ] Commit with conventional commit message
9. [ ] Move to next P-level

## NON-NEGOTIABLE RULES

- **Never skip tests.** If you can't test it, don't ship it.
- **Never hardcode strings.** All user-facing text in ARB files × 6 languages.
- **Never approximate financials.** Use `financial_core/` calculators.
- **Never log PII.** No salary, IBAN, name, employer in logs.
- **Never use banned terms.** See CLAUDE.md § 6.
- **ComplianceGuard on all LLM output.** No exceptions.
- **`git add` specific files.** Never `git add .` or `git add -A`.
