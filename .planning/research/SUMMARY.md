# Project Research Summary

**Project:** MINT UX Journey Milestone — AI-Centric Fintech Experience
**Domain:** AI-orchestrated mobile UX for Swiss fintech (Flutter + FastAPI)
**Researched:** 2026-04-05
**Confidence:** HIGH (stack and architecture based on direct codebase inspection; features and pitfalls grounded in internal audit history W1-W14 + 40-app benchmark)

## Executive Summary

This milestone is a brownfield wiring project, not a greenfield build. MINT already has every component required to deliver an AI-centric journey — intent screen, coach chat, tool call parser, route planner, screen registry, cap sequence engine, financial calculators, confidence score, proactive nudge service, and regional voice. The gap is not missing features or libraries: it is three unconnected wires. The backend produces structured tool calls that the Flutter chat screen silently discards. The onboarding intent chip never triggers the cap sequence engine. The route planner produces pre-fill decisions that are never applied to calculator screen constructors. Fixing these three integration points, with under 500 lines of new code, delivers the core milestone promise.

The recommended approach is a dependency-ordered phase structure: first resolve pre-refactor debt (duplicate services, orphan routes) that would cause silent divergence during implementation; then wire the core tool dispatch loop so that LLM outputs reach the UI; then connect onboarding intent to the journey engine so the first coach response delivers a personalized premier eclairage; then complete profile pre-fill across all calculator entry screens. Only after these phases are complete should any polish or proactive nudge wiring be attempted, because earlier phases are foundations that later phases depend on.

The primary risk is "facade sans cablage" — the documented #1 failure pattern in MINT's own 14-wave audit history. Components test correctly in isolation while end-to-end flows remain broken. Every phase must include a mandatory cablage verification step in its definition of done: trace the complete flow from user action to visible output, verify each link exists, and confirm on a physical device before marking complete. The secondary risk is the post-onboarding void: the intent screen was shipped in S56 but the pipeline from intent-selected to first-premier-eclairage-shown has no verified owner. This must be treated as a single atomic feature, not two separate screens maintained by separate agents.

## Key Findings

### Recommended Stack

The stack requires no significant additions. Flutter SDK 3.27.4 (pinned), go_router 13.2.0, provider 6.1.1, and flutter_local_notifications 18.0.1 are already deployed and cover all animation, navigation, state, and notification needs. The existing MintMotion token system (150/300/600/350ms, four curves), MintEntrance, MintCountUp, and ChatCardEntrance cover every animation requirement without external libraries.

The one targeted addition recommended is `flutter_animate ^4.5.0` — but only for the 3-minute onboarding journey sequence (intent tap → loading → premier eclairage reveal), where sequencing 4-6 animations across multiple widgets would otherwise require 150+ lines of AnimationController boilerplate. This library is additive, carries zero runtime overhead when unused, and is compatible with Dart ^3.6.0 and Flutter 3.27.4.

**Core technologies:**
- Flutter SDK 3.27.4: pinned runtime — do not upgrade mid-milestone; all animation primitives available natively
- go_router ^13.2.0: already deployed; use `CustomTransitionPage` for AI-guided journey transitions (fade, not slide)
- provider ^6.1.1: already deployed; `CoachEntryPayloadProvider` is the AI routing bus — wire consistently
- flutter_animate ^4.5.0: one targeted addition for onboarding sequence only — additive, no conflicts
- MintMotion (internal): existing token system — extend, never replace

**Pattern changes (no new libraries):**
- `CustomTransitionPage` in GoRouter: replace Material slide push with fade on journey screens (`/onboarding/intent`, `/coach`, `/onboarding/premier-eclairage`)
- `ValueListenableBuilder` for streaming tokens: scope rebuilds to streaming bubble only, not full `CoachChatScreen` subtree
- `AnimatedSwitcher` for proactive signal cards: crossfade on dismiss/replace in Aujourd'hui tab
- `DraggableScrollableSheet` for deep dive from chat: stay in conversation while exploring tool output

### Expected Features

Research from 40+ benchmarked apps (Cleo, Monarch Money, bunq Finn, Fitbod, Duolingo, WHOOP, Noom, Perplexity) converges on four conclusions: chat is infrastructure not a feature; onboarding-to-first-value is a 90-second race; contextual tool surfacing beats menu navigation; and the "wow" moment is always a single surprising number about the user's own situation. MINT's differentiator vs Cleo and Monarch is that it can produce genuine Swiss-specific insights (LPP threshold, cantonal tax bracket, AVS projection) from just 3 inputs, without requiring bank connection — because the financial_core calculators are the data source, not transaction feeds.

**Must have (table stakes):**
- Post-onboarding first impact scene — users expect immediate personalized output after any AI-first onboarding flow; the `FirstImpactScreen` or equivalent must deliver the premier eclairage before any navigation
- Aujourd'hui tab as living cap — proactive CapEngine cards with clear next actions, not a static dashboard; `PulseHeroEngine` + `ProactiveTriggerService` must feed this
- Profile pre-fill on all calculator entry screens — users are frustrated repeating data MINT already has; `ProfileAutoFillMixin` and `SimulatorParams.resolve()` must be wired across all calculator screens
- Coach chat as second action — direct CTA from first impact scene to chat pre-seeded with context; not buried in a tab
- End-to-end journey for 3 life events — `firstJob`, `housingPurchase`, `newJob` as the three MVP journeys: intent → first insight → coach guidance → calculator (pre-filled) → result with disclaimer + next step
- Route cleanup — remove or alias orphan screens; dead navigation ends break trust

**Should have (competitive differentiators):**
- Premier eclairage via 4-layer insight engine in every substantive coach message (fact → translation → personal perspective → question to ask) — no competitor structures AI financial insights this rigorously
- ReadinessGate-aware Explorer — show only hubs/screens relevant to the user's life phase; `ReadinessGate` (3 levels) and `ScreenRegistry` (109 surfaces with requiredFields) already exist
- ConfidenceScore visible on Aujourd'hui — make the 4-axis score prominent; show what single action improves it; gamification hook for return visits
- Safe Mode surfaced in UX — when toxic debt detected, disable 3a/LPP optimization and show debt-first guidance; logic exists, UX surface does not

**Defer (v2+):**
- Full intent-to-journey routing (entire app reorganizes per life event) — requires `LifecycleDetector` → `CapEngine` → navigation reconfiguration pipeline; high risk, defer until v1.0 validates the journey model
- JITAI notification delivery — `JitaiNudgeService` trigger logic is complete; delivery wiring is partial; defer to v1.x after permission grant rate data
- Voice AI — `VoiceService` stub exists; Phase 3 roadmap; requires STT/TTS pipeline + compliance on spoken output
- Weekly Recap AI — requires consistent engagement data; `WeeklyRecapService` is foundation-only
- Social/cantonal benchmarks — compliance review needed for framing; shame-effect risk if careless

### Architecture Approach

The architecture is "AI as orchestration layer" — LLM decides intent, code decides routing. The full pipeline already exists: backend agent loop produces tool calls → orchestrator embeds them as text markers → `ToolCallParser` parses markers → `RoutePlanner` resolves intents to `RouteDecision` → `RouteSuggestionCard` presents navigation proposals → user taps to confirm → calculator opens pre-filled. The problem: `CoachChatScreen` never calls `ToolCallParser`, so all downstream components are permanently idle. The architecture is correct. The implementation has three disconnected wires.

**Major components:**
1. `ChatToolDispatcher` (NEW, ~120 lines) — parse tool markers from every `CoachResponse`, dispatch ROUTE_TO_SCREEN to RoutePlanner and SHOW_* to widget factory; this is the single missing connector that unblocks all downstream AI-driven UX
2. `JourneyTrigger` (NEW, ~60 lines) — detect `entryPayload.source == 'onboarding_intent'` in `CoachChatScreen.initState()`, map chip to goalIntentTag, call `CapMemoryStore.setActiveGoal()` to prime the CapSequenceEngine
3. `CalculatorPrefillBridge` (MODIFIED, `RouteSuggestionCard` + `app.dart` GoRouter handlers) — pass `RouteDecision.prefill` via `context.push(route, extra: decision.prefill)` and apply in screen constructors
4. Backend agent loop (UNCHANGED) — already produces correct tool calls; no changes needed
5. `financial_core` calculators (UNCHANGED) — all 8 calculators correct and tested; no changes needed
6. `RoutePlanner` / `ScreenRegistry` / `ToolCallParser` / `CapSequenceEngine` (UNCHANGED) — all correct, all idle; they become active once `ChatToolDispatcher` calls them

### Critical Pitfalls

1. **Facade sans cablage** — Components appear complete, unit tests pass, but the wire connecting them was never run. MINT has five documented W14 instances of this pattern. Prevention: every phase must include an explicit cablage verification step — trace the complete flow from user action to visible output, verify each link exists. Definition of done is "flow traced end-to-end," not "component done."

2. **Post-onboarding void** — Intent screen works, user arrives at Aujourd'hui, nothing reflects their stated intent. The premier eclairage promise is broken not by onboarding but by the gap after it. Prevention: treat the intent-to-first-insight pipeline as a single atomic feature with one owner. Write an integration test: intent selected → home tab shows matching content. Time it on device — if it takes over 90 seconds, the wiring is incomplete.

3. **Conversational-first UX that feels worse** — Making chat the primary surface fails when the agent loop is broken (LLM stops after 1 tool call instead of chaining), responses are text-only rather than inline widget-bearing, and users who prefer direct navigation are degraded. Prevention: fix agent loop before chat becomes primary entry for any feature; Explorer tab must work fully without AI; fallback templates must deliver a useful first insight when BYOK is disabled.

4. **Route simplification breaks deep links** — 147 routes (101 canonical + 46 redirects) with deep-link backward compat already documented for the removed Dossier tab. Any route restructuring must treat every canonical route as a contract. Prevention: write a static test asserting every pre-refactor route either resolves or has an explicit redirect, before any refactor commits touch `app.dart`.

5. **Duplicate services diverging during refactor** — Three confirmed duplicate service pairs (`coach_narrative_service`, `community_challenge_service`, `goal_tracker_service`) exist in different directories. A bug fix in one copy leaves the other broken. Prevention: resolve all three pairs before any journey refactor sprint; verify with grep that all imports point to a single canonical path.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 0: Pre-Refactor Cleanup
**Rationale:** Duplicate services and orphan routes create silent divergence risk during any implementation phase. These must be resolved before any other work, or bug fixes will silently apply to the wrong copy. ARCHITECTURE.md and PITFALLS.md both flag this as a prerequisite.
**Delivers:** Clean service layer (3 duplicate pairs resolved), confirmed route table (orphan screens removed or aliased), baseline integration test skeleton
**Addresses:** Pitfall 5 (duplicate services), Pitfall 2 (route breakage prevention — write the static route test)
**Avoids:** Mid-refactor discovery that a critical fix was applied to the non-canonical service copy

### Phase 1: Wire the Core Tool Dispatch Loop
**Rationale:** Everything else depends on tool calls reaching the Flutter UI. Display tools, navigation tools, and inline widgets are all permanently idle until `CoachChatScreen` calls `ToolCallParser`. This is the single highest-leverage change in the milestone — ~180 lines of new code unlock all downstream AI-driven UX.
**Delivers:** Coach responses surface inline widgets (FactCard, BudgetSnapshot, ScoreGauge) and RouteSuggestionCard when the LLM produces the appropriate tool calls; user can tap a route suggestion to navigate to a pre-filled calculator screen
**Uses:** `flutter_animate` for smooth widget arrival in chat; `ChatCardEntrance` for tool-rendered widget entrance; `ValueListenableBuilder` for streaming token scoping
**Implements:** `ChatToolDispatcher` (new), modified `CoachChatScreen._sendMessage()`, modified `CoachMessageBubble`, modified `RouteSuggestionCard` (add prefill parameter)
**Addresses:** Features — "calculators reachable from conversation," "readable and scannable results"; Architecture gaps 1 and 2
**Avoids:** Pitfall 1 (cablage verification: send "comment fonctionne mon LPP?" → verify show_fact_card widget appears inline)

### Phase 2: Connect Onboarding Intent to Journey Engine
**Rationale:** Phase 1 makes the coach capable of responding with tools. Phase 2 ensures the journey starts correctly: intent chip → CapSequenceEngine → premier eclairage as first output → Aujourd'hui tab shows Step 1 of the relevant sequence. Requires Phase 1 to be working so the first coach response can surface the journey's first insight.
**Delivers:** The 3-minute onboarding promise: tap intent chip → coach responds with personalized swiss-specific number + inline fact card + route suggestion → Aujourd'hui tab shows first sequence step; `CustomTransitionPage` fade transitions make the path feel guided, not menu-like
**Uses:** `flutter_animate` for the multi-step sequential reveal (intent → loading skeleton → number → narrative → CTA); `CustomTransitionPage` fade for journey screens
**Implements:** `JourneyTrigger` (new), `CapMemoryStore.setActiveGoal()` call in `CoachChatScreen.initState()`, verification that `MintHomeScreen` renders `CapSequenceCard` after goal is set
**Addresses:** Features — "post-onboarding first insight" (P1), "clear path from today's screen to action" (P1); Architecture gap 3
**Avoids:** Pitfall 3 (post-onboarding void — verify integration test: intent selected → home tab shows matching content within 90 seconds on device)

### Phase 3: Profile Pre-Fill Across Calculator Screens
**Rationale:** Route suggestions (Phase 1) become magical when the screen they open is pre-filled with user data — and frustrating when it asks for data MINT already has. Phase 3 completes the CalculatorPrefillBridge so that every AI-suggested navigation arrives pre-populated. Must come after Phase 1 (route suggestions must exist before pre-fill is meaningful).
**Delivers:** Every major calculator opened via coach suggestion arrives pre-filled with the user's CoachProfile data; `ProfileAutoFillMixin` verified and wired across priority screens (`/rente-vs-capital`, `/pilier-3a`, `/rachat-lpp`, `/hypotheque`, `/invalidite`)
**Uses:** `RoutePlanner.plan()` prefill output via `context.push(route, extra: decision.prefill)`; `SimulatorParams.resolve(CoachProfile)` in `initState` of each screen
**Implements:** GoRouter handlers in `app.dart` apply `state.extra as Map<String,dynamic>?` to screen constructors; priority calculator screens accept prefill map
**Addresses:** Features — "profile data pre-fills every screen" (P1), "calculators reachable from conversation" (P1); Architecture gap 4
**Avoids:** Pitfall 1 (cablage: verify Julien's 70,377 CHF LPP capital appears in rente-vs-capital screen opened via coach suggestion)

### Phase 4: End-to-End Journey Maps for 3 Life Events
**Rationale:** Phases 1-3 build the infrastructure. Phase 4 uses it to construct three coherent user journeys — the actual product the milestone promises. `firstJob`, `housingPurchase`, and `newJob` cover the highest-frequency life events. Each journey is: intent → first insight → coach guidance → relevant calculator (pre-filled) → result with disclaimer + next step.
**Delivers:** Three complete, tested, device-verified user journeys; widget tests for all touched screens; golden couple (Julien + Lauren) verified through each journey path; i18n complete in all 6 ARB files for any new strings
**Addresses:** Features — "single coherent user journey for 3 life events" (P1 HIGH complexity), 4-layer insight engine enforced in coach system prompt (P1 LOW complexity)
**Avoids:** Pitfall 6 (regression invisibility — widget test on every modified screen, visual inspection on device, golden couple pass before sign-off); Pitfall 7 (AI context pollution — standardize CoachContextBuilder for all calculator-feeding prompts)

### Phase 5: Polish and UX Coherence
**Rationale:** After functional flows are verified, polish addresses the experience quality. Signal card animations, confidence score visibility, safe mode surfacing in UX, and ReadinessGate-aware Explorer are all low-complexity, high-value additions that do not block core functionality.
**Delivers:** `AnimatedSwitcher` for proactive signal cards; ConfidenceScore visible on Aujourd'hui with improvement prompt; Safe Mode surface in UX (debt-first guidance when toxic debt detected); Explorer highlights hub matching user's stated intent; all remaining dead/duplicate routes cleaned
**Addresses:** Features — ConfidenceScore as engagement driver (P2), Safe Mode UX surface (P2), ReadinessGate-aware Explorer (P2)
**Avoids:** Pitfall 4 (conversational-first degradation — Explorer tab must work fully without AI; verify with BYOK disabled)

### Phase Ordering Rationale

- Phase 0 before everything: duplicate services create silent divergence risk that grows with every phase added on top. Resolving them first is low-cost, high-safety.
- Phase 1 before Phase 2: the journey trigger (Phase 2) relies on the first coach response surfacing an inline widget and route suggestion. Without Phase 1, the intent chip triggers a text-only coach response with no tools, and the journey never starts.
- Phase 3 after Phase 1: pre-fill is only relevant when route suggestions exist to trigger calculator navigation. Building pre-fill before route suggestions creates testable components with no active callers — the classic cablage trap.
- Phase 4 after 1-3: the journey maps are assemblies of Phase 1-3 components. Building them before the components are verified creates unstable integrations.
- Phase 5 after Phase 4: polish on verified flows; not a blocker for core value delivery.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 4 (Journey Maps):** The mapping from each intent chip to the correct sequence of coach messages, calculator screens, and compliance disclosures requires careful per-life-event specification. Suggest `/gsd-research-phase` to verify `firstJob` and `housingPurchase` journey step sequences against Swiss legal requirements (LPP threshold, EPL eligibility, 3a contribution rules).
- **Phase 3 (Pre-Fill Bridge):** Each calculator screen has its own parameter contract. A detailed mapping of `CoachProfile` field names to each screen's constructor parameters is needed before implementation. This could be a targeted research phase or a specification step within Phase 3 planning.

Phases with standard patterns (skip research-phase):
- **Phase 0 (Pre-Refactor Cleanup):** Standard service deduplication + route audit. Well-documented patterns. No research needed.
- **Phase 1 (Tool Dispatch):** Architecture is fully specified in ARCHITECTURE.md with exact code. `ChatToolDispatcher` design is complete. Implementation follows a clear spec.
- **Phase 2 (Journey Trigger):** `JourneyTrigger` is a small, well-bounded component (~60 lines) with a clear spec. No additional research needed.
- **Phase 5 (Polish):** Standard Flutter animation patterns (AnimatedSwitcher, ValueListenableBuilder). MintMotion token system covers all animation decisions.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Based on direct codebase inspection of pubspec.yaml, MintMotion, MintEntrance, MintCountUp, ChatCardEntrance — all claims verified against actual files |
| Features | MEDIUM | WebSearch/WebFetch unavailable during research; benchmark doc (March 2026, 40+ apps) is the primary external source; MINT-specific feature state is HIGH confidence from direct code inspection |
| Architecture | HIGH | All gap claims verified by direct inspection of `coach_orchestrator.dart:635-649`, `coach_chat_screen.dart` (confirmed: no calls to ToolCallParser/RoutePlanner), `coach_rich_widgets.dart` (confirmed: keyword-matching not tool-driven), `coach_chat.py` agent loop |
| Pitfalls | HIGH | Grounded entirely in MINT's own 14-wave audit history (W1-W14 documented), CONCERNS.md (43 TODO/FIXME items, 3 confirmed duplicate pairs, 109 untested screens), and specific regression incidents (85k salary hardcode, cashLevel never synced to backend) |

**Overall confidence:** HIGH

### Gaps to Address

- **flutter_animate version verification:** STACK.md notes MEDIUM confidence on `^4.5.0` (training data, not live pub.dev). Run `flutter pub outdated` after adding to confirm the resolved version is compatible with Dart ^3.6.0 and Flutter 3.27.4 before committing.
- **CapSequenceEngine goal family mapping:** ARCHITECTURE.md maps 6 intent chips to 3 goal families, with 2 chips ("intentChipChangement", "intentChipAutre") deferred to coach free-form or sub-intent resolution. The exact mapping for the remaining 4 chips needs validation against the current `CapSequenceEngine` goal family definitions during Phase 2 planning.
- **Journey step specifications for `firstJob` and `housingPurchase`:** The legal and product requirements for each step in these journeys (which screens, which disclaimers, which Swiss law references) are not fully enumerated in the research files. These need per-life-event specification before Phase 4 implementation.
- **Agent loop chain reliability:** PITFALLS.md confirms the agent loop (tool_use → execute → re-call LLM) is documented as P0 missing infrastructure. Phase 1 assumes the backend already produces correct tool calls (confirmed by ARCHITECTURE.md code inspection). However, multi-step tool chaining may require backend changes not covered in this research. Validate the current `MAX_AGENT_LOOP_ITERATIONS=5` behavior with a live test query before starting Phase 2.

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection — `coach_orchestrator.dart:635-649`, `coach_chat_screen.dart`, `coach_rich_widgets.dart`, `coach_chat.py`, `route_planner.dart`, `screen_registry.dart`, `tool_call_parser.dart`, `cap_sequence_engine.dart`, `pubspec.yaml`, `mint_motion.dart`, `mint_entrance.dart`, `mint_count_up.dart`, `chat_card_entrance.dart`
- `.planning/codebase/CONCERNS.md` — 43 TODO/FIXME items, 3 duplicate service pairs, 109 untested screens, 17 known stubs
- `.planning/codebase/ARCHITECTURE.md` — data flow diagrams, coach chat flow, GoRouter structure
- `.planning/codebase/TESTING.md` — test pyramid analysis, coverage gaps, golden couple scope
- `.planning/PROJECT.md` — milestone scope, validated vs active requirements, documented gaps
- `feedback_facade_sans_cablage.md` — 5 concrete W14 instances with root cause and grep detection patterns
- `project_navigation_chantier.md` — current navigation state: 147 routes, 68 orphan screens, 46 redirects

### Secondary (MEDIUM confidence)
- `visions/MINT_Analyse_Strategique_Benchmark.md` — 40+ apps analyzed, 18 academic themes, March 2026 (recent but internal document)
- `docs/NAVIGATION_GRAAL_V10.md`, `docs/MINT_UX_GRAAL_MASTERPLAN.md`, `docs/ROADMAP_V2.md`, `docs/MINT_IDENTITY.md` — MINT product docs for feature state assessment
- Training knowledge through August 2025 — Cleo, Perplexity, Arc Browser, Monarch Money, bunq Finn, Fitbod, Duolingo, WHOOP, Noom UX patterns (cannot verify 2025-2026 updates)

### Tertiary (LOW confidence — needs validation)
- pub.dev `flutter_animate ^4.5.0` version compatibility claim — verify with `flutter pub outdated` before implementation

---
*Research completed: 2026-04-05*
*Ready for roadmap: yes*
