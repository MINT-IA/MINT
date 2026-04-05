# Architecture Research

**Domain:** AI-centric UX journey for Swiss fintech mobile app (Flutter + FastAPI)
**Researched:** 2026-04-05
**Confidence:** HIGH (based on direct code inspection, not inference)

---

## Current Architecture: What Actually Exists

Before recommending changes, here is what was found in the codebase — the real state, not the intended state.

### What Works

| Component | Location | Status |
|-----------|----------|--------|
| `CapSequenceEngine` | `lib/services/cap_sequence_engine.dart` | Builds 3 goal sequences (retirement/budget/housing) — pure function, tested |
| `RoutePlanner` | `lib/services/navigation/route_planner.dart` | Takes intent + profile → produces `RouteDecision` (openScreen/askFirst/openWithWarning/conversationOnly) |
| `ScreenRegistry` / `MintScreenRegistry` | `lib/services/navigation/screen_registry.dart` | Maps 24 intent tags to routes, behavior classes (A-E), readiness requirements |
| `ReadinessGate` | `lib/services/navigation/readiness_gate.dart` | Checks profile fields before allowing screen open |
| `RouteSuggestionCard` | `lib/widgets/coach/route_suggestion_card.dart` | Card widget to show coach suggestion + CTA — with `ScreenOutcome` return contract |
| `ToolCallParser` | `lib/services/coach/tool_call_parser.dart` | Parses `[TOOL_NAME:{json}]` markers from coach text — whitelist of 134 valid routes |
| `SequenceCoordinator` | `lib/services/sequence/sequence_coordinator.dart` | Decides what happens after each sequence step (AdvanceAction/CompleteAction/PauseAction) |
| Backend agent loop | `services/backend/app/api/v1/endpoints/coach_chat.py` | Executes internal tools (7), collects Flutter-bound tools, returns them in `tool_calls` field |
| `CoachEntryPayload` | `lib/models/coach_entry_payload.dart` | Carries source+topic+data into coach chat — used by `IntentScreen` |
| `coach_tools.py` | `services/backend/app/services/coach/coach_tools.py` | 14 tool definitions: 7 internal, 4 display (show_*), 1 navigate (route_to_screen), 1 document, 1 input |

### What Is Broken (The Facade Without Wiring)

**Gap 1 — Tool call to UI (the critical gap):**

`CoachOrchestrator._generateByokChat()` (line 635-649) transforms `route_to_screen` and `generate_document` tool calls into text markers:
```
text = '$text\n[ROUTE_TO_SCREEN:{"intent":"retirement_choice","confidence":0.9,"context_message":"..."}]'
```

`coach_chat_screen.dart` never calls `ToolCallParser.parse()` on the response. The `RoutePlanner`, `RouteSuggestionCard`, and all navigation logic are completely disconnected from the chat flow. A user asking "comment préparer ma retraite\u00a0?" may receive a `route_to_screen` tool call that is silently discarded.

**Gap 2 — Display tools not rendered:**

`show_fact_card`, `show_budget_snapshot`, `show_score_gauge`, `ask_user_input` tool calls are returned by the backend in `tool_calls` → deserialized as `RagToolCall` objects in `CoachResponse.toolCalls` → stored in `ChatMessage.richToolCalls` — but `coach_chat_screen.dart` never renders them. `CoachRichWidgetBuilder` uses keyword matching on the user message instead of LLM-driven tool calls.

**Gap 3 — Post-onboarding journey not triggered:**

`IntentScreen` sends the intent chip text as `CoachEntryPayload.userMessage` to the coach chat. The chat starts a conversation. But `CapSequenceEngine` is never invoked to establish a multi-step journey from the selected intent. The engine exists with 3 goal families and sequence logic — it is just never called after onboarding.

**Gap 4 — Calculators not connected to contextual surfacing:**

8 calculators in `financial_core/` power 40+ screens. The connection from a conversation topic to the right calculator screen goes through explicit route constants in `ToolCallParser.validRoutes` (134 hard-coded routes) — but the mapping from LLM intent to the correct prefilled screen is not implemented. `ScreenRegistry.prefillFromProfile` is declared but the `RouteDecision.prefill` populated by `RoutePlanner` is never applied to screen constructors.

---

## Recommended Architecture: AI as Orchestration Layer

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER INTERACTION LAYER                        │
│  ┌──────────────┐  ┌───────────────┐  ┌────────────────────┐   │
│  │ IntentScreen │  │CoachChatScreen│  │  Calculator Screen  │   │
│  │  (onboard)   │  │  (main loop)  │  │  (pre-filled)       │   │
│  └──────┬───────┘  └───────┬───────┘  └──────────┬─────────┘   │
│         │                  │                      │             │
├─────────┼──────────────────┼──────────────────────┼─────────────┤
│                   ORCHESTRATION BUS                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                ChatOrchestrationController                 │  │
│  │  1. Receive CoachResponse with tool_calls                  │  │
│  │  2. Dispatch: display tools → WidgetRenderer               │  │
│  │              navigate tool → RoutePlanner → RouteDecision  │  │
│  │              input tool   → InputCapture                   │  │
│  │  3. Sequence: SequenceCoordinator.advance()                │  │
│  └───────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                    AI LAYER (existing, partial)                  │
│  ┌─────────────────┐  ┌───────────────────┐  ┌───────────────┐  │
│  │  Backend Agent  │  │ ContextInjector   │  │ComplianceGuard│  │
│  │  Loop (works)   │  │ Service (works)   │  │  (works)      │  │
│  └─────────────────┘  └───────────────────┘  └───────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                  CALCULATOR + DATA LAYER (works)                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │
│  │   AVS    │ │   LPP    │ │   Tax    │ │  Monte Carlo +   │   │
│  │ Calculator│ │Calculator│ │Calculator│ │  3 more calcs    │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### The Three Wiring Points to Implement

The architecture change is not a rewrite. It is connecting three existing, working components through a single new coordinator.

---

## Architectural Patterns

### Pattern 1: ChatOrchestrationController (the missing connector)

**What:** A new class (or extracted section of `_CoachChatScreenState`) that handles the post-response dispatch. When `CoachResponse` arrives, it calls `ToolCallParser.parse()` on the text, then dispatches each parsed tool call to the correct handler.

**When to use:** Every time a coach response arrives from `CoachOrchestrator`.

**Why this is the right seam:** The orchestrator already produces structured tool calls embedded in text. The parser already exists. The renderers already exist. The connector is the only missing piece.

**Recommended implementation:**

```dart
// lib/services/coach/chat_tool_dispatcher.dart  (NEW)
class ChatToolDispatcher {
  final RoutePlanner routePlanner;
  final CoachProfile profile;

  // Returns: list of widgets to render inline, and optional navigation action.
  DispatchResult dispatch(CoachResponse response) {
    final parseResult = ToolCallParser.parse(response.message);
    final inlineWidgets = <Widget>[];
    RouteDecision? navigationDecision;

    for (final call in parseResult.toolCalls) {
      switch (call.toolName) {
        case 'ROUTE_TO_SCREEN':
          final intent = call.arguments['intent'] as String;
          final confidence = (call.arguments['confidence'] as num).toDouble();
          if (confidence >= 0.5) {
            navigationDecision = routePlanner.plan(intent, confidence: confidence);
          }
        case 'SHOW_FACT_CARD':
          inlineWidgets.add(FactCardWidget(
            title: call.arguments['title'],
            content: call.arguments['content'],
            source: call.arguments['source'],
          ));
        case 'SHOW_BUDGET_SNAPSHOT':
          inlineWidgets.add(BudgetSnapshotWidget(profile: profile));
        case 'SHOW_SCORE_GAUGE':
          inlineWidgets.add(ScoreGaugeWidget(profile: profile));
        case 'ASK_USER_INPUT':
          inlineWidgets.add(InlineInputCapture(
            fieldKey: call.arguments['field_key'],
            promptText: call.arguments['prompt_text'],
            inputType: call.arguments['input_type'] ?? 'text',
          ));
      }
    }

    return DispatchResult(
      cleanText: parseResult.cleanText,
      inlineWidgets: inlineWidgets,
      navigationDecision: navigationDecision,
    );
  }
}
```

**Integration point:** `_CoachChatScreenState._sendMessage()` — after receiving `CoachResponse`, call `dispatcher.dispatch()` before building `ChatMessage`. The `ChatMessage.richToolCalls` and `routePayload` fields already exist in the model — they just need to be populated.

### Pattern 2: JourneyTrigger — Connecting Onboarding Intent to CapSequence

**What:** After `IntentScreen` sends a `CoachEntryPayload` to the chat, `CoachChatScreen.initState()` should detect the intent and prime `CapSequenceEngine` with the corresponding goal.

**When to use:** First chat message from `IntentScreen` only (one-shot, detected via `entryPayload.source == 'onboarding_intent'`).

**Why this is the right seam:** `IntentScreen` chips map to 3 of the 5 known `CapSequenceEngine` goal families. The engine is a pure function that takes `CoachProfile` + `CapMemory` + `goalIntentTag`. It just needs to be called.

**Intent chip to goal mapping:**

| IntentScreen chip ARB key | goalIntentTag |
|--------------------------|---------------|
| `intentChip3a`, `intentChipFiscalite` | `tax_optimization_3a` (new) or `budget_overview` |
| `intentChipBilan` | `budget_overview` |
| `intentChipPrevoyance` | `retirement_choice` |
| `intentChipProjet` | `housing_purchase` |
| `intentChipChangement` | depends on sub-intent — defer to coach |
| `intentChipAutre` | no sequence — coach free-form |

**Recommended implementation:**

```dart
// In CoachChatScreen._loadOnboardingPayload() — extend existing method
if (widget.entryPayload?.source == 'onboarding_intent') {
  final goalTag = _resolveGoalFromEntry(widget.entryPayload!.userMessage);
  if (goalTag != null) {
    final memory = await CapMemoryStore.load();
    // Store the active goal so CapSequenceEngine can build the sequence
    await memory.setActiveGoal(goalTag);
    await CapMemoryStore.save(memory);
  }
}
```

**Where to show the sequence:** `Aujourd'hui` tab (`MintHomeScreen`) already renders a `CapSequenceCard`. The goal persistence through `CapMemoryStore` is already wired. The missing step is the trigger from onboarding.

### Pattern 3: CalculatorPrefillBridge — Profile-Aware Screen Entry

**What:** When `RoutePlanner` produces `RouteDecision.openScreen(route, prefill: ...)`, the `prefill` map must be applied to the screen constructor via GoRouter `extra` parameter.

**When to use:** Every `context.push(route)` triggered by a `RouteSuggestionCard` tap.

**Why this is the right seam:** `RoutePlanner` already populates `RouteDecision.prefill` from `CoachProfile`. `ScreenEntry.prefillFromProfile` is already declared. The receiving screens already have `SimulatorParams.resolve(profile)` patterns. The missing step is passing `prefill` via `context.push(route, extra: decision.prefill)`.

**Recommended implementation in `RouteSuggestionCard`:**

```dart
// In RouteSuggestionCard._onConfirm() — change:
context.push(route)
// To:
context.push(route, extra: prefill)  // prefill comes from RoutePlanner.plan()
```

Each calculator screen's route handler in `app.dart` should then apply `state.extra as Map<String,dynamic>?` to its constructor. The ARCH NOTE in `cap_sequence_engine.dart` already acknowledges this — route strings and intent tags are currently conflated, a clean separation helps here.

### Pattern 4: AI-Driven vs Menu-Driven Navigation (The Policy Decision)

**What:** The 67-route GoRouter stays as-is. The `Explorer` tab (7 hubs) stays as-is. AI-driven navigation is additive: the coach suggests routes, but the user can always browse manually.

**The rule (non-negotiable):** LLM decides intent, code decides routing. This is already the architecture in `route_planner.dart`. It must not be bypassed.

**AI-driven navigation trigger:**
- Route suggestion card shown only when `RoutePlanner` returns `openScreen` or `openWithWarning`
- Coach confidence threshold: 0.5 minimum (already in `route_to_screen` tool description)
- User always taps to confirm — never automatic push

**Menu-driven navigation stays:**
- Explorer tab for browsing by topic
- All 67 routes accessible via deep links
- Direct URL entry always works

**Why not collapse to fewer routes:** The 67 routes are each screens with their own state and prefill contracts. Collapsing them creates screens trying to do too many things. The problem is not too many routes — it is no AI layer using them intelligently.

---

## Data Flow

### Correct End-to-End Tool Call Flow (Target State)

```
User message
    ↓
CoachOrchestrator._generateByokChat()
    ↓ (calls backend /api/v1/coach/chat)
Backend agent loop:
    - Internal tools (retrieve_memories, get_budget_status, etc.) → executed, result injected
    - Flutter tools (route_to_screen, show_fact_card, etc.) → collected in flutter_tool_calls
    ↓
CoachChatResponse { message: text, tool_calls: [...] }
    ↓
Orchestrator embeds tool calls as [TOOL_NAME:{json}] markers in text  ← currently works
    ↓
CoachResponse returned to CoachChatScreen  ← GAP: screen ignores markers
    ↓  (target state: screen calls ChatToolDispatcher)
ChatToolDispatcher.dispatch(response):
    - ToolCallParser.parse(response.message) → cleanText + list<ParsedToolCall>
    - For each call:
        - ROUTE_TO_SCREEN → RoutePlanner.plan(intent) → RouteDecision
        - SHOW_* → build inline widget
        - ASK_USER_INPUT → build inline input capture
    ↓
ChatMessage built with:
    - content: cleanText
    - richToolCalls: [inline widgets]
    - routePayload: RouteToolPayload (if navigation decision)
    ↓
CoachMessageBubble renders:
    - clean text
    - inline widgets (FactCard, BudgetSnapshot, ScoreGauge, InputCapture)
    - RouteSuggestionCard (if routePayload present)
    ↓
User taps RouteSuggestionCard CTA
    ↓
context.push(route, extra: decision.prefill)
    ↓
Calculator screen opens pre-filled with user's own data
    ↓
ScreenCompletionTracker records outcome
    ↓
SequenceCoordinator.advance() → next step or completion
```

### Onboarding to First Insight Flow (Target State, Under 3 Minutes)

```
App launch → auth check
    ↓
IntentScreen (chips: 7 intents)
    ↓  (user taps chip, e.g. "Ma prévoyance")
CoachEntryPayload { source: 'onboarding_intent', userMessage: "Ma prévoyance" }
    ↓
CoachChatScreen.initState():
    a) JourneyTrigger: maps intent → goalIntentTag = 'retirement_choice'
    b) CapMemoryStore.setActiveGoal('retirement_choice')
    c) ContextInjectorService builds profile context
    ↓  (auto-send entry payload as first message)
Backend chat: StructuredReasoningService computes facts from profile
    ↓
Coach responds with:
    - Personalized premier_eclairage (the surprising number)
    - show_fact_card tool for the key insight
    - route_to_screen tool for the relevant calculator
    ↓
ChatToolDispatcher:
    - Renders FactCard inline in chat
    - Shows RouteSuggestionCard ("Voir ta projection")
    ↓
Aujourd'hui tab: CapSequenceCard shows Step 1 of retirement sequence
```

### State Management for Journey Engine

```
CapMemoryStore (SharedPreferences)
    ├── activeGoal: String             ← set by JourneyTrigger on onboarding
    ├── completedActions: Set<String>  ← set by mark_step_completed tool
    └── savedInsights: List<Insight>   ← set by save_insight tool

CoachProfileProvider (ChangeNotifier)
    └── profile: CoachProfile         ← central data, drives all calculations

SequenceCoordinator (stateless pure function)
    ← reads CapMemoryStore + CoachProfile
    → produces SequenceAction (Advance/Complete/Pause/Skip)
```

---

## Component Boundaries

| Component | Responsibility | Communicates With | New/Modified |
|-----------|---------------|-------------------|--------------|
| `ChatToolDispatcher` | Parse tool markers, dispatch to handlers | `ToolCallParser`, `RoutePlanner`, widget builders | **NEW** |
| `JourneyTrigger` | Map onboarding intent to CapSequence goal | `CapMemoryStore`, `CapSequenceEngine` | **NEW** (small) |
| `CoachChatScreen` | Host orchestration, render messages | `ChatToolDispatcher`, `CoachOrchestrator` | **MODIFIED** (call dispatcher) |
| `RouteSuggestionCard` | Show AI navigation proposal | `RoutePlanner`, `context.push()` | **MODIFIED** (pass prefill) |
| `CoachRichWidgets` | Render AI-driven inline widgets | `profile`, `financial_core` | **MODIFIED** (switch from keyword to tool-driven) |
| `CapSequenceEngine` | Build multi-step goal sequences | `CapMemory`, `CoachProfile` | **UNCHANGED** |
| `SequenceCoordinator` | Decide sequence advancement | `ScreenRegistry`, `ScreenReturn` | **UNCHANGED** |
| `RoutePlanner` | Intent → route decision | `ScreenRegistry`, `ReadinessGate` | **UNCHANGED** |
| `ScreenRegistry` | Map intents to routes + requirements | pure data | **UNCHANGED** |
| Backend agent loop | Run LLM + internal tools | `claude_coach_service.py`, `coach_tools.py` | **UNCHANGED** |

---

## Build Order (Dependency-Aware)

Phase ordering is driven by dependencies — later phases build on earlier ones.

### Phase 1: Wire the Core Tool Loop

**Why first:** Everything else depends on tool calls reaching the UI. Without this, display tools and navigation tools remain invisible.

1. Implement `ChatToolDispatcher` in `lib/services/coach/chat_tool_dispatcher.dart`
   - Calls `ToolCallParser.parse()` on coach response text
   - Dispatches `ROUTE_TO_SCREEN` to `RoutePlanner.plan()`
   - Dispatches `SHOW_*` to widget factory functions
   - Returns `DispatchResult { cleanText, inlineWidgets, navigationDecision }`

2. Modify `_CoachChatScreenState._sendMessage()` to call dispatcher after receiving `CoachResponse`
   - Replace direct message text use with `dispatchResult.cleanText`
   - Set `ChatMessage.richToolCalls` from `dispatchResult.inlineWidgets`
   - Set `ChatMessage.routePayload` from `dispatchResult.navigationDecision`

3. Modify `CoachMessageBubble` (or `coach_chat_screen` inline build) to render `richToolCalls`
   - Already has `hasRichToolCalls` guard in `ChatMessage`

4. Modify `RouteSuggestionCard` to accept and pass `prefill` to `context.push()`

**Verification:** Send "comment fonctionne mon LPP\u00a0?" → should see `show_fact_card` widget inline in chat.

### Phase 2: Connect Onboarding to Journey Engine

**Why second:** Needs the tool loop working (Phase 1) so the first coach response can surface the journey's first insight.

1. Add `JourneyTrigger` logic to `CoachChatScreen.initState()`
   - Detect `entryPayload.source == 'onboarding_intent'`
   - Map chip text to `goalIntentTag` (simple lookup, ~10 lines)
   - Call `CapMemoryStore.setActiveGoal()`

2. Verify `MintHomeScreen` renders `CapSequenceCard` after goal is set (it already should)

3. Ensure `SequenceCoordinator` is called on `RouteSuggestionCard.onReturn()` with `ScreenOutcome`

**Verification:** Tap "Ma prévoyance" chip in `IntentScreen` → coach responds with personalized insight + route suggestion → `Aujourd'hui` tab shows Step 1 of retirement sequence.

### Phase 3: Profile-Aware Screen Entry

**Why third:** Needs Phase 1 (route suggestions) working before prefill is meaningful.

1. Modify `RoutePlanner.plan()` to populate `RouteDecision.prefill` from `CoachProfile`
   - Each `ScreenEntry` has `requiredFields` and `optionalFields` — use these to build prefill map
   - Map `CoachProfile` field names to each screen's parameter contract

2. Modify each major calculator screen to accept `state.extra` prefill in route handler
   - Priority order: `/rente-vs-capital`, `/pilier-3a`, `/rachat-lpp`, `/hypotheque`, `/invalidite`

3. Modify GoRouter handlers in `app.dart` to pass `state.extra as Map<String,dynamic>?` to screen constructors

**Verification:** From coach chat, ask "est-ce que je devrais prendre rente ou capital\u00a0?" → route suggestion card appears → tapping it opens `/rente-vs-capital` with user's actual LPP data pre-filled.

---

## Integration Points with Existing Code

### Existing Files That Must Be Modified

| File | Change Required | Risk |
|------|----------------|------|
| `lib/screens/coach/coach_chat_screen.dart` | Call `ChatToolDispatcher.dispatch()` after receiving `CoachResponse`; populate `ChatMessage.richToolCalls` and `routePayload` | MEDIUM — large file (836 lines post-extraction), focused change in `_sendMessage` |
| `lib/widgets/coach/coach_rich_widgets.dart` | Change `CoachRichWidgetBuilder` from keyword-matching to rendering passed `RagToolCall` list | LOW — isolated widget, clear interface change |
| `lib/widgets/coach/route_suggestion_card.dart` | Accept `prefill: Map<String,dynamic>?` parameter, pass to `context.push()` | LOW — small widget, additive parameter |
| `apps/mobile/lib/app.dart` (GoRouter) | Calculator screens accept `state.extra` prefill map | LOW per route, MEDIUM total (multiple routes) |

### Existing Files That Are Unchanged

| File | Why Unchanged |
|------|--------------|
| `lib/services/navigation/route_planner.dart` | Already correct — produces `RouteDecision` with prefill field |
| `lib/services/navigation/screen_registry.dart` | Already correct — 24 intent tags, behavior classes, readiness requirements |
| `lib/services/coach/tool_call_parser.dart` | Already correct — parses markers, whitelists 134 routes |
| `lib/services/cap_sequence_engine.dart` | Already correct — pure function, 3 goal families, tested |
| `lib/services/sequence/sequence_coordinator.dart` | Already correct — advance/complete/pause/skip logic |
| `lib/widgets/coach/route_suggestion_card.dart` (mostly) | Widget structure correct — only prefill param addition needed |
| `services/backend/` | Backend already produces correct tool calls — no changes needed |
| `financial_core/` calculators | All 8 calculators work correctly — no changes needed |

### New Files Required

| File | Purpose | Size estimate |
|------|---------|---------------|
| `lib/services/coach/chat_tool_dispatcher.dart` | Dispatch tool calls to handlers | ~120 lines |
| `lib/services/coach/journey_trigger.dart` | Map onboarding intent to CapSequence goal | ~60 lines |

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Current (beta, ~100 users) | Single coach session, client-side sequence state in SharedPreferences — fine |
| 1k-10k users | CapMemory migration to backend persistence — `CapMemoryStore` already has a backend sync stub; activate it |
| 100k+ users | Backend agent loop already has MAX_AGENT_LOOP_ITERATIONS=5 and token budgets; CoachChatResponse tool_calls already serialized — no changes needed at this scale |
| If LLM latency becomes the bottleneck | SLM on-device tier (Gemma 3n) already implemented — but SLM cannot produce structured tool calls yet; this is a known limitation requiring a separate on-device dispatch format |

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Double-Dispatch

**What people do:** Call `ToolCallParser` in both `CoachOrchestrator` (to embed markers) and `CoachChatScreen` (to re-parse them), and also process `CoachResponse.toolCalls` directly in the screen.

**Why it's wrong:** `CoachResponse.toolCalls` contains the raw `RagToolCall` list AND the text has markers. Dispatching both creates duplicate widgets. Current orchestrator already embeds markers — the screen should parse markers only.

**Do this instead:** Use only the text marker path in `CoachChatScreen`. The `CoachResponse.toolCalls` field can be used as a debug/analytics signal but not for rendering.

### Anti-Pattern 2: LLM Routes Directly

**What people do:** Return a raw `/route-path` string from the LLM and call `context.push()` directly.

**Why it's wrong:** The LLM can hallucinate routes. RoutePlanner is the compliance boundary — it checks profile readiness, behavior class, and whitelisted intents. Bypassing it means opening broken screens.

**Do this instead:** Always go through `RoutePlanner.plan(intentTag, confidence: ...)`. It is the single routing authority.

### Anti-Pattern 3: Keyword Widget Matching as Primary Path

**What people do:** Keep `CoachRichWidgetBuilder` keyword logic as the primary widget source, treating tool calls as optional enhancement.

**Why it's wrong:** Keywords are unreliable (language variants, abbreviations, topic combinations). The LLM is already running with full context — its `show_fact_card` decision is more accurate than any keyword matcher. Keyword matching should be the fallback, not the primary.

**Do this instead:** Tool calls from `ChatToolDispatcher` are the primary widget source. If no tool calls returned AND the message contains relevant keywords (budget/score/retraite), then optionally surface a widget. Not the other way around.

### Anti-Pattern 4: Rewriting Working Components

**What people do:** Because the current UX is broken, assume the architecture is wrong and rewrite the coach, orchestrator, or route planner.

**Why it's wrong:** All of these components work correctly. The broken UX comes from three missing wiring calls (dispatch, journey trigger, prefill pass-through), not from architectural errors.

**Do this instead:** Write `ChatToolDispatcher` (120 lines), `JourneyTrigger` (60 lines), modify 4 existing files. The entire milestone can be accomplished with under 500 lines of new code.

---

## Sources

- Direct code inspection of `coach_orchestrator.dart` lines 635-649 (tool marker embedding)
- Direct code inspection of `coach_chat_screen.dart` (confirmed: no calls to `ToolCallParser`, `RoutePlanner`, or `RouteSuggestionCard`)
- Direct code inspection of `coach_rich_widgets.dart` (confirmed: keyword-matching, not tool-driven)
- Direct code inspection of `coach_chat.py` `_run_agent_loop()` (confirmed: backend correctly separates internal vs Flutter tool calls)
- Direct code inspection of `route_planner.dart`, `screen_registry.dart`, `tool_call_parser.dart` (confirmed: all correct, unused)
- `docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md` (referenced in multiple files as the canonical spec for this layer)
- `decisions/ADR-20260223-unified-financial-engine.md` (referenced in `cap_sequence_engine.dart`)

---

*Architecture research for: MINT UX Journey milestone — AI orchestration wiring*
*Researched: 2026-04-05*
*Confidence: HIGH — all claims based on direct code inspection, not inference*
