# Pitfalls Research

**Domain:** Adding AI-centric UX journey to an existing feature-rich fintech app
**Researched:** 2026-04-05
**Confidence:** HIGH — grounded entirely in MINT's own audit history (W1-W14), codebase analysis, and documented failure patterns. No speculative claims.

---

## Critical Pitfalls

### Pitfall 1: Facade Sans Cablage — The #1 AI Agent Development Trap

**What goes wrong:**
Components are built individually and appear complete — the widget exists, the backend service exists, the route exists — but the wire connecting them was never run. The user sees a UI that promises a feature, but the feature is a placebo. Unit tests pass (every component works in isolation), so CI stays green. Only an end-to-end flow trace reveals the break.

MINT has five documented instances from W14:
- `cashLevel` (UI preference, saved to SharedPreferences) was never sent to the backend — Claude always responded at the same intensity regardless of user choice.
- `LLM_ANTI_PATTERNS` (list of 9 banned phrases) was defined in Python but never interpolated into the system prompt — Claude kept saying "Je comprends que..." despite the prohibition.
- `RegulatorySyncService.getEchelle44()` fetched and cached updated AVS tables, but `avs_calculator.dart` read `const table = avsEchelle44` (hardcoded) — regulatory updates were silently ignored.
- `AnomalyDetectionService` detected spending anomalies and returned them via API, but `CapEngine` had no `hasSpendingAnomaly` field — anomalies were computed and discarded.
- The anomaly endpoint was built without `require_current_user` — it was open to unauthenticated callers.

**Why it happens:**
In AI-agent development, each agent works within its assigned scope. Agent A builds the Flutter widget correctly. Agent B builds the backend handler correctly. Neither agent is responsible for verifying that A's output reaches B's input. There is no "joint owner." This is structurally different from solo development where the same person writes both sides and sees the gap.

**How to avoid:**
1. Every agent prompt must include an explicit "CABLAGE" section: "After implementing, trace the complete flow: user action → widget → Provider → ApiService → endpoint → service → response → UI update. Verify each link exists."
2. After every multi-agent sprint, run a dedicated "cableur" verification pass whose only job is checking that new components are connected to their consumers.
3. Treat "component done" as insufficient. The definition of done is "flow traced end-to-end."
4. Use this grep pattern to catch dead code masquerading as features:
   ```bash
   grep -rn "INTENSITY_MAP\|REGIONAL_MAP\|LLM_ANTI_PATTERNS" services/backend/
   # Then verify each result is actually USED, not just defined:
   grep -rn "intensity_map\|regional_map\|anti_patterns" services/backend/ | grep -v "def \|= {"
   # 0 results = facade
   ```

**Warning signs:**
- A feature has a TODO comment on one side but not the other ("TODO: wire mobile to backend")
- A service or map is defined but never passed as an argument to the function that needs it
- SharedPreferences saves a value but no API call carries that value to the backend
- A test passes for a service that has no calling code in the rest of the app
- CONCERNS.md currently flags: `expat_service.dart:44` — mobile not wired to backend for source tax calculations

**Phase to address:**
Every phase. This is a process pitfall, not a feature pitfall. Mandatory cablage verification step must be part of the Definition of Done for each phase.

---

### Pitfall 2: Route Simplification That Breaks Deep Links

**What goes wrong:**
67 routes get reorganized into cleaner conceptual paths, but 46 existing redirect rules and external deep links (notifications, TestFlight links, shared URLs) now return 404 or silently redirect to the wrong screen. Users with saved bookmarks or push notification links lose their entry points. CI catches zero failures because tests don't exercise link-to-screen mapping.

MINT's specific risk: 147 routes (101 canonical + 46 redirects), with `deep-link compat: /home?tab=3` already documented as backward compatibility for the removed Dossier tab. The same problem will recur with any route restructuring.

**Why it happens:**
Navigation refactors focus on the "after" state (clean routes) and forget the "during" state (what existing links resolve to). The GoRouter redirect chain works in the happy path but has edge cases when the destination route has also changed. Developers test new routes but not old routes.

**How to avoid:**
1. Before restructuring any route, export the current full route table and treat every canonical route as a contract. New routes add; old routes must redirect, never vanish.
2. Write a static test that asserts every route in the pre-refactor table either (a) still resolves to a screen or (b) has an explicit redirect to its replacement. This test should be written BEFORE the refactor, not after.
3. Document the redirect mapping in GoRouter as named constants (not magic strings) so a route rename is caught by the Dart compiler.
4. For push notification and TestFlight links: maintain a `deep_link_manifest.md` mapping external URLs to current screens. Update it before any merge that touches `app.dart` routes.

**Warning signs:**
- `app.dart` L161-974 GoRouter definition changes without a corresponding update to redirect rules
- New route added with the same path prefix as a removed route (e.g., `/dossier/*` redirected to `/home?tab=3` — a new `/dossier/` feature would break this)
- `_MintErrorScreen` appearing in integration tests after navigation changes
- `context.pop()` vs `Navigator.pop()` mix-up causing stack inconsistencies (currently 4 files affected)

**Phase to address:**
Phase 1 (Navigation Overhaul). Must include a deep-link compatibility test suite as a gate condition before any routes are removed.

---

### Pitfall 3: The Post-Onboarding Void — Promising Personalization Before Delivering It

**What goes wrong:**
The onboarding collects intent (the new intent-based screen works). The user arrives at the home tab ("Aujourd'hui"). Nothing there reflects their stated intent. The "premier éclairage" that was promised takes 5+ taps to reach. The first impression is a generic dashboard, not a personalized moment. The 3-minute promise is broken not by the onboarding but by the gap after it.

MINT's documented state: "Post-onboarding gap: User completes intent screen... then what?" The `CoachEntryPayloadProvider` exists to carry intent through the session, but there is no verified path from `intent_selected` to `first_premier_eclairage_shown`.

**Why it happens:**
Onboarding is built as a self-contained flow. The "Aujourd'hui" tab is built as a general-purpose home. Neither team (nor agent) is responsible for the transition between them. The intent data lands in a provider but no consumer subscribes to it and acts on it immediately.

**How to avoid:**
1. Treat the intent-to-first-insight pipeline as a single atomic feature with one owner, not two separate features owned by separate agents.
2. Trace the specific path: `OnboardingIntentScreen` sets `CoachEntryPayloadProvider.intent` → `AujourdhuiTab` reads `CoachEntryPayloadProvider.intent` on first load → calls `ChiffreChocSelector` (or `PremierEclairageSelector`) with that intent → displays the result. Verify each link.
3. Write an integration test for this specific flow with a mock profile (18-year-old, no data) verifying that the home tab surface changes based on the intent selected.
4. Time the flow manually on device. If it takes more than 90 seconds from intent selection to first personalized number, the wiring is incomplete.

**Warning signs:**
- `CoachEntryPayloadProvider` is read in tests but never read in `aujourd_hui_tab.dart` (or equivalent)
- The first screen after onboarding shows the same content regardless of which intent was selected
- "Premier éclairage" is shown only after navigating to a specific calculator screen, not proactively
- `chiffre_choc_selector.dart` (or its renamed equivalent) has no connection to the onboarding intent

**Phase to address:**
Phase 1 (Onboarding to first insight pipeline). This is the phase's primary deliverable and must be verified by a human tapping through the flow, not just by unit tests.

---

### Pitfall 4: Conversational-First UX That Feels Worse, Not Better

**What goes wrong:**
Making the chat tab the primary surface causes three failure modes:
(a) The app becomes a slow text interface — users who want to check their LPP capital must wait for an LLM response instead of tapping a tab.
(b) Responses are verbose and generic, failing to embed the calculators that make MINT unique — the coach says "go to the retirement screen" instead of showing the result inline.
(c) The agent loop is broken: the LLM makes one tool call and stops without re-calling to chain `get_profile → compute_projection → show_result`. Users see "I'll need more information" instead of an answer.

MINT's documented state: The agent loop (tool_use → execute → re-call LLM) is described as P0 missing infrastructure. Without it, data lookup tools (`get_projection_retraite`, `get_budget_status`) are present but non-functional because the LLM cannot chain them.

**Why it happens:**
Conversational-first is mistaken for "chat is the only surface." The actual pattern is "AI as narrative layer, not chatbot-first" — the coach responds in the tab where the user is, embedding widgets inline, and the chat tab is one of several surfaces, not the mandatory entry point. Agents build a chat-centric interface because it's the explicit instruction without considering the degraded experience when the agent loop doesn't work.

**How to avoid:**
1. Prioritize the agent loop fix (tool_use → execute → re-call LLM) before making chat the primary entry point for any feature. A broken loop means every complex question returns a placeholder.
2. Follow the documented pattern: `StructuredReasoningService` computes, `claude_coach_service.py` humanizes. The LLM does not calculate — it narrates calculations. This means the LLM can respond correctly even with a partial loop if the structured data is pre-computed and injected.
3. Rich response cards (inline widgets, mini charts, comparison cards) must be part of every AI response phase. Chat that returns only text is not the MINT vision.
4. Explorer tab must remain fully functional without AI. Users who prefer autonomous navigation (tap to hub → use calculator) must not be degraded by the conversational-first pivot.
5. Test the "conversation degraded" scenario: turn off the LLM (BYOK off, SLM unavailable) and verify the fallback templates still deliver a useful first insight.

**Warning signs:**
- Chat responses say "Je vous recommande d'aller sur l'écran retraite" instead of embedding the number inline
- The "Aujourd'hui" tab requires an LLM response to show any meaningful content
- `CoachChatScreen` (1577 lines) grows larger while `AujourdhuiTab` grows smaller
- Response time for a first insight exceeds 3 seconds on a cold start
- Users with BYOK disabled see a blank or generic home screen

**Phase to address:**
Phase 2 (calculator wiring) must close the loop between `CoachChatScreen` tool calls and `financial_core` results. Phase 1 must not require a working agent loop to deliver the onboarding → first insight promise.

---

### Pitfall 5: Duplicate Services Diverging During Refactor

**What goes wrong:**
MINT currently has three documented duplicate service pairs:
- `lib/services/coach_narrative_service.dart` (1457 lines) AND `lib/services/coach/coach_narrative_service.dart`
- `lib/services/gamification/community_challenge_service.dart` AND `lib/services/coach/community_challenge_service.dart`
- `lib/services/memory/goal_tracker_service.dart` AND `lib/services/coach/goal_tracker_service.dart`

During a refactor, a bug is fixed in one copy. The other copy is not updated. The fixed version is what the new journey uses. The unfixed version is what an old deep-link or A/B test uses. Behavior becomes inconsistent, confidence calculations diverge, and the issue is invisible to unit tests (both copies pass their own tests).

**Why it happens:**
When agents reorganize directory structure, they move files without checking whether the old path is still imported elsewhere. Two files with the same name in different directories are both valid Dart packages. Nothing prevents both from existing. Import paths in screens don't break; they just silently reference the old copy.

**How to avoid:**
1. Resolve all three duplicate pairs before starting the journey refactor. Choose one canonical location (the `coach/` subdirectory is the correct home for coach-related services per the architecture's layer model), delete the other, and fix all imports.
2. Run `grep -rn "coach_narrative_service\|community_challenge_service\|goal_tracker_service" apps/mobile/lib/ --include="*.dart"` to find every import, and verify all point to the same file.
3. After resolution, add a CI lint rule (or a comment in `analysis_options.yaml`) preventing duplicate filenames across the service directories.

**Warning signs:**
- Two files with the same name in different directories (already confirmed in CONCERNS.md)
- A bug fix applied in a sprint that "should have worked" but didn't — check if the wrong copy was fixed
- Import autocomplete suggests two files with the same name

**Phase to address:**
Phase 0 (pre-refactor cleanup). Must be resolved before any phase that reorganizes the service layer.

---

### Pitfall 6: Regression Invisibility — 12,892 Tests That Don't Catch UX Failures

**What goes wrong:**
The test suite is green. `flutter analyze` reports 0 errors. A phase ships. The retirement dashboard still shows generic numbers instead of the user's actual LPP capital because the screen reads from a default value instead of `CoachProfileProvider`. This is invisible to the 199 service test files and the 80 widget test files because neither tests the chain "profile data → screen display → user-visible number."

MINT's documented instance: A critical regression in `quick_start_screen.dart` replaced a salary field with a hardcoded `85000` default. This was discovered by the founder reviewing a screenshot, not by any test.

**Why it happens:**
The test pyramid is inverted for UX: strong unit tests for calculators, weak widget tests for screens, almost no integration tests (2 files). The 109 screens with no test file include `coach_chat_screen.dart` (1577 lines), `pulse_screen.dart` (1665 lines), and `rente_vs_capital_screen.dart` (1980 lines). When screens are modified during a journey refactor, there is no safety net.

**How to avoid:**
1. For every screen touched in the journey refactor, write a minimum widget test verifying: (a) the screen renders without error, (b) if the profile has a salary, the salary is visible somewhere in the rendered tree (not the default 85k), (c) the primary action (CTA) is tappable.
2. Add an integration test (not unit test) for the 3-minute flow: launch → onboarding → home → first insight → first action. This test catches UX regressions that zero unit tests will ever find.
3. The golden couple tests (Julien + Lauren) must be run after each phase, not just before milestone completion. If Julien's LPP capital stops appearing correctly in the journey flow, the golden test should catch it.
4. Visual inspection is a required step before any phase is marked complete. Running on a physical device or simulator and verifying each user-facing screen is not optional.

**Warning signs:**
- A screen is modified but `test/screens/` has no corresponding test file
- `quick_start_screen.dart` or any "first insight" screen reads from a hardcoded value (`85000`, `30`, default canton)
- The golden test passes but the flow in the app doesn't reflect golden couple values (tests use mock providers, app uses real providers with empty state)
- A refactor changes a screen's `initState` without verifying the provider it reads from

**Phase to address:**
All phases. Phase 1 specifically must add widget tests for any onboarding or first-insight screen it ships.

---

### Pitfall 7: AI Context Pollution — LLM Receiving Stale or Wrong Profile Data

**What goes wrong:**
The AI coach responds to the user based on a profile snapshot injected at session start. The user updates their salary during the conversation. The LLM continues to base its responses on the old salary. The user sees contradictory numbers. This is worse than no personalization because it feels like the app is ignoring what the user just said.

MINT's specific risk: `CoachContext` is explicitly forbidden from containing exact salary/savings/debts for compliance reasons, but the coach is supposed to be personalized. The tension between compliance (no exact PII in prompts) and personalization (coach knows your situation) is resolved by injecting bucketed/approximate values. If this bucketing logic is applied inconsistently — exact values in some prompts, bucketed in others — the user experience is incoherent.

**Why it happens:**
Multiple services build `CoachContext` independently: `context_injector_service.dart`, `coach_orchestrator.dart`, `prompt_registry.dart`. Each makes its own decision about what to include. When a profile value changes, it propagates to some but not all context builders. No single source of truth for "what does the coach know about the user right now."

**How to avoid:**
1. Centralize all CoachContext construction behind a single `CoachContextBuilder.buildFor(CoachProfile, currentIntent)` method. All prompts use this method. No prompt builds context ad hoc.
2. Add a runtime assertion in `CoachContextBuilder` that exact PII fields (salary, savings, debt balances) are bucketed before injection, not passed verbatim.
3. When the profile updates during a session (user corrects salary in chat), re-build the context and inject it into the next LLM call. This requires the agent loop to work (Pitfall 4).
4. Test: inject a profile with salary 122,207 CHF and verify the prompt contains "autour de 120,000" or "entre 100,000 et 150,000" but never the exact figure.

**Warning signs:**
- `prompt_registry.dart:47` and `coach_llm_service.dart:333` construct context with different rules (currently documented as a risk in CONCERNS.md)
- The coach refers to "ton salaire de 67,000 CHF" with an exact figure in the chat log
- After the user corrects a value in the chat, the next response still uses the old value

**Phase to address:**
Phase 2 (calculator wiring into coach). When building the pipeline that feeds calculator outputs into coach responses, this is the right moment to standardize context construction.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keeping both duplicate service files | Avoids breaking imports now | Silent divergence during refactor; two copies of the same bug | Never — resolve before any refactor sprint |
| `print()` debug logs in production services | Fast debugging | PII leakage if salary/LPP data hits logs; performance noise | Never in production paths; guard with `kDebugMode` |
| `catch (e) { debugPrint(...); }` without Sentry | Services never crash visibly | Silent failures in regulatory sync, LLM calls, RAG — user sees nothing, bug is invisible | Never for P0/P1 flows (regulatory, LLM, auth) |
| Hardcoded French strings in services without BuildContext | Avoids complex localization plumbing | App appears untranslated for ~120 strings in 24 files for 5 of 6 languages | Never for user-facing text; acceptable only for internal debug strings |
| Screen reads from hardcoded default (85k salary) | Screen renders without requiring profile | User sees "personalized" screen that is actually generic; destroys trust | Never — screens must either use real profile data or clearly mark as estimate |
| `Navigator.pop()` mixed with `GoRouter` | Works for dialogs/bottom sheets | Stack inconsistencies in deep navigation; acceptable only for modals | Acceptable for dialogs/modals; never for screen-to-screen navigation |
| `CoachProfile` as single 2956-line model | All profile data in one place | Merge conflicts, slow IDE, difficult to test individual concerns | Acceptable for now; split into focused models in a cleanup sprint after the journey milestone |

---

## Integration Gotchas

Common mistakes when connecting components in the MINT architecture.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Flutter → Backend (profile values) | Save to SharedPreferences only; never send to API | Every profile field relevant to LLM/calculations must be synced to backend via `CoachProfileProvider.syncToBackend()` |
| GoRouter → Feature flags | Add a new route without a feature flag gate | Use `FeatureFlags.isEnabled(flag)` in the route redirect, not inside the screen — prevents blank screen flash |
| financial_core → Display layer | Re-compute values in screen `build()` method | Compute once in initState or Provider, cache result; re-computation in build causes jank on every frame |
| LLM context → Compliance guard | Build prompt → send to LLM → guard output | Build prompt → guard input context (no exact PII) → send to LLM → guard output (compliance). Two guard points, not one |
| Calculator result → i18n display | Format number inline: `"${result.toStringAsFixed(0)} CHF"` | Use `NumberFormat.currency(locale: locale).format(result)` with user locale; spacing before % and CHF must use `\u00a0` (non-breaking space) |
| Provider → Service call | Call service directly in `build()` | Call service in `initState` or via explicit user action; never in `build()` |
| RegulatorySyncService → financial_core | Calculator uses `const` hardcoded table | Calculator must call `RegulatorySyncService.getEchelle44()` or equivalent; never `const` for regulatory values that update annually |

---

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Computation in `build()` | UI jank on navigation, dropped frames | Move all financial calculations to initState, Provider, or FutureBuilder | On every frame rebuild (scroll, animation, keyboard) |
| 14 ChangeNotifierProviders all at root | Unrelated state changes trigger full tree rebuild | Use `context.select<T, R>()` to subscribe to specific fields; split large providers | Noticeable with CoachProfile (2956 lines) on any update |
| SLM download on cold start | First launch stalls for 30s+ | Defer SLM download to background after first insight is shown | Always — SLM download must never block UI |
| Synchronous SharedPreferences in initState | Screen freezes briefly on first render | Use `FutureBuilder` or initialize asynchronously before `runApp` | On slow devices with large profile data |
| 169 debugPrint calls in production | PII exposure in crash logs; slight perf cost | Replace with `if (kDebugMode) debugPrint(...)` | On every print call in production builds |
| LLM called for every screen load | 2-3s latency on every navigation | LLM is called on explicit user action (send message) or proactively once per session start | On every tab switch if LLM is used to "personalize" the tab |

---

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Exact salary/savings in LLM prompt | Data leaves app boundary; Anthropic logs may contain PII | Bucket all financial values before CoachContext injection; assert in `CoachContextBuilder` |
| Anomaly endpoint without auth (documented W14) | Any caller can query financial anomaly data | Every endpoint that touches user financial data must have `require_current_user`; add auth audit to CI |
| Multi-account key collision in SharedPreferences | Data leaks between accounts if multi-account is ever enabled | Prefix all keys with user ID now: `{userId}_{key}` in both `coach_memory_service.dart` and `open_finance_service.dart` |
| EXIF metadata in document scan images | GPS coordinates, device info sent to Vision API | Strip EXIF before any API call using `image` package |
| `debugPrint` near API key handling | BYOK keys could appear in device logs | Audit all `debugPrint` calls near `byok_provider.dart` and `auth_service.dart` |
| Broad exception swallowing in RAG pipeline | Silent auth bypass or data processing failure looks like success | Each `except Exception` in 24 backend files must either propagate or log to Sentry with context |

---

## UX Pitfalls

Common user experience mistakes during the AI-centric journey refactor.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Coach says "go to the retirement screen" | User must leave conversation to get the answer they asked for | Coach embeds the result inline via ResponseCard with the number, meaning, and one action |
| First insight requires user to navigate | 3-minute promise broken; app feels like every other app | First insight appears proactively on first home tab load, driven by intent selected in onboarding |
| Chat tab is blank until user types | User opens MINT and sees an empty conversation | "Aujourd'hui" tab (not chat tab) is the home; it proactively shows the premier éclairage without requiring user input |
| All 7 Explorer hubs visible immediately | Cognitive overload; user doesn't know where to start | Highlight the hub matching the user's stated intent; de-emphasize others without hiding them |
| Conversational entry forced for all users | Older users, users who prefer direct navigation feel excluded | Explorer tab must work fully without any AI interaction; conversation is additive, not mandatory |
| Profile data not pre-filled in simulators | User asked to enter data MINT already has; destroys "companion" feeling | Every simulator screen calls `SimulatorParams.resolve(CoachProfile)` in initState; fields with known values are pre-populated |
| Retirement framing in "Aujourd'hui" tab | 22-year-olds see retirement content; identity pivot not reflected in UX | First insight driven by user's stated intent and life event, never defaulting to retirement |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces in a journey refactor.

- [ ] **Intent captured in onboarding:** Verify `CoachEntryPayloadProvider` is read by `AujourdhuiTab` on first load — not just set by the onboarding screen.
- [ ] **Premier éclairage wired:** Verify `chiffre_choc_selector.dart` (or `premier_eclairage_selector.dart`) receives the intent from `CoachEntryPayloadProvider`, not a hardcoded category.
- [ ] **Calculators feed the journey:** Verify at least one `financial_core/` calculation result is visible on the home tab for a user with profile data — not a placeholder number.
- [ ] **Route simplification backward-compatible:** Verify every route in the pre-refactor canonical list either resolves or redirects. Run `flutter test` after any `app.dart` change.
- [ ] **Duplicate services resolved:** Verify `grep -rn "import.*coach_narrative_service"` returns only one path per importing file.
- [ ] **Coach responses embed widgets:** Verify a chat message asking "combien ai-je à la retraite?" returns a response containing a `ResponseCard` with a number, not just text saying to visit another screen.
- [ ] **Profile pre-fill working:** Verify opening `rente_vs_capital_screen.dart` (or any refactored equivalent) with a profile that has LPP capital shows Julien's 70,377 CHF, not a blank or default field.
- [ ] **i18n not broken:** Verify all new strings added during the journey refactor are present in all 6 ARB files. Run `flutter gen-l10n` and confirm no missing key errors.
- [ ] **Agent loop functional (if used):** Verify a multi-step query ("quels sont mes options pour racheter ma LPP avant l'achat de ma maison?") results in the LLM making at least 2 tool calls in sequence, not stopping after 1.
- [ ] **Fallback works without LLM:** Verify the home tab shows a meaningful first insight when BYOK is disabled and SLM is unavailable (fallback template path).

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Facade sans cablage discovered post-ship | MEDIUM — 1-2 sprint days | Trace the broken flow, identify the missing link, add the wire in a surgical commit. Do NOT refactor around it. |
| Route simplification breaks deep links | HIGH — requires hotfix + notification | Restore the broken route as a redirect immediately. Audit full route table. Ship the redirect as hotfix before fixing root cause. |
| Post-onboarding void (intent not consumed) | LOW — single Provider subscription | Add `context.watch<CoachEntryPayloadProvider>().intent` read in `AujourdhuiTab`. Verify flow in 30 minutes. |
| Duplicate service divergence found mid-refactor | MEDIUM — careful import surgery | Do not merge the two files hastily. Diff them, identify which version is more correct, update it, redirect all imports, delete the other. |
| Regression discovered via screenshot (hardcoded default) | LOW-MEDIUM — find and fix the `initState` | Grep for the hardcoded value, find the screen, restore the `CoachProfileProvider.watch()` read, verify golden couple values appear. |
| LLM context contains exact PII | HIGH — compliance incident | Immediately disable the affected context builder path. Audit all prompt logs in Sentry for PII exposure. Notify compliance review before re-enabling. |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Facade sans cablage | Every phase — mandatory cablage step in DoD | Post-sprint: trace every new feature flow end-to-end |
| Route simplification breaks deep links | Phase 1 (Navigation Overhaul) | Pre-refactor: write static route test; post-refactor: run test and verify 0 broken routes |
| Post-onboarding void | Phase 1 (Onboarding pipeline) | Integration test: intent selected → home tab shows matching content |
| Conversational-first degrades experience | Phase 2 (Calculator wiring) | Manual test: ask 3 financial questions in chat; verify inline widgets appear, not navigation redirects |
| Duplicate services diverge | Phase 0 (Pre-refactor cleanup) | `grep -rn "coach_narrative_service"` returns single canonical path across all imports |
| Regression invisibility | Phase 1, 2 (each phase) | Widget test on every modified screen; visual inspection on device before phase sign-off |
| AI context pollution | Phase 2 (Calculator wiring into coach) | Unit test: profile with exact salary → prompt contains bucketed value, not exact figure |

---

## Sources

- `feedback_facade_sans_cablage.md` — 5 concrete W14 instances with root cause and grep-based detection pattern. HIGH confidence.
- `project_navigation_chantier.md` — Current navigation state: 147 routes, 68 orphan screens, 46 redirects. HIGH confidence.
- `.planning/codebase/CONCERNS.md` — 43 TODO/FIXME items, 3 duplicate service pairs, 109 untested screens, 17 known stubs. HIGH confidence.
- `.planning/codebase/ARCHITECTURE.md` — Data flow diagrams, coach chat flow, GoRouter structure. HIGH confidence.
- `.planning/codebase/TESTING.md` — Test pyramid analysis, coverage gaps, golden couple scope. HIGH confidence.
- `.planning/PROJECT.md` — Milestone scope, validated vs active requirements, documented gaps. HIGH confidence.
- `feedback_conversation_driven_ux.md` — Vision for inline widgets vs navigation redirects. HIGH confidence.
- `feedback_agent_loop_is_bottleneck.md` — Agent loop P0 status, tool-call chaining requirement. HIGH confidence.
- `feedback_profile_prefill_architecture.md` — SimulatorParams.resolve() pattern, 15-instance history of screens ignoring profile. HIGH confidence.
- `feedback_no_regressions.md` — Documented 85k salary regression caught visually, not by tests. HIGH confidence.
- `feedback_agent_blast_radius.md` — Multi-agent scope control, commit granularity. HIGH confidence.
- `CLAUDE.md §9` — Anti-patterns including duplicate logic, hardcoded defaults, retirement framing. HIGH confidence.
- `feedback_no_multiagent_premature.md` — 1 process / 6 modes vs multi-agent complexity trap. HIGH confidence.

---
*Pitfalls research for: AI-centric UX journey refactor of a feature-rich Swiss fintech app*
*Researched: 2026-04-05*
