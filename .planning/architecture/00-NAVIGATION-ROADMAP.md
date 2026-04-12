# 00 — MINT Navigation Roadmap (Master Decision Document)

> **Status**: Decision document. Not an opinion paper.
> **Author role**: Senior Principal Engineer + Design Director, synthesizing reports 01-05.
> **Date**: 2026-04-11
> **Read time**: 15 minutes.
> **Purpose**: Julien reads this once, and starts Monday morning with zero ambiguity.

---

## Section 1 — TL;DR

- **This week**: ship Nav Engineer Phase 1 (fix LOOP-01, kill `safePop`, patch redirects). No architecture change, no screen deletions. 2-3 days of surgical work. See Section 9.
- **This month**: introduce a single `ShellRoute` wrapping chat as the persistent root, migrate 21 `safePop` sites to `MintNav.back(fallback: …)`, delete the 7 doctrinally-indefensible screens (not 65). One TestFlight build per week.
- **Then**: gather evidence (analytics, 3 non-chatter user tests) before committing to chat-only vs 2-tab shell. The 26-screen utopia from the Strategist is a 6-week project and is frozen until you have data.
- **What you do NOT do**: delete 65 screens. Build 5 "Unified" mega-screens. Rename `Explorer` to `Monde`. Publish a new mental-model sentence. Ship chat-only before testing with a 55-year-old Valaisan. Change anything on the backend `claude_coach_service.py` prompt until the route registry is unified.
- **The one insight the 5 reports taught us**: the Budget infinite loop is not a bug. It is the codebase speaking out loud: *"this screen should not exist — route me back where I came from"*. Every architectural decision below listens to that signal.

---

## Section 2 — Convergence diagnosis

What all 5 experts independently converged on (IA Expert, UX Senior, Nav Engineer, Product Strategist, Critic):

1. **The chat is already the shell, the router is pretending it isn't.** IA Expert §0 ("the architecture is already coach-first in the code"), UX §0 ("the chat is simultaneously the hub, the shell, the fallback, the router, and the onboarding"), Nav Engineer §0 ("a chat-as-shell monolith with no shell primitive"), Strategist §C ("the loop bug IS the codebase literally speaking out loud"), Critic §F ("the team tried to build chat-first and couldn't close the loop"). Five consultants, one diagnosis.

2. **`BudgetContainerScreen` is a facade and must die.** Unanimous (LOOP-01 in SCREEN_MAP.md, file `apps/mobile/lib/screens/budget/budget_container_screen.dart`, ~lines 390-393 of `app.dart`). It is the canonical example of the facade anti-pattern. `BudgetScreen` is orphaned and should replace it or be consumed by a bottom-sheet inline collector.

3. **`safePop` → `/coach/chat` is a universal lie.** 21 call sites, all dumping to chat when the stack is empty (`safe_pop.dart:8-14`). Nav Engineer §A.4 and UX §Failure 2 both name this as P1. The fix is the same: mandatory typed `fallback` parameter.

4. **40+ redirect shims drop query params silently.** REDIR-01 in SCREEN_MAP.md. `app.dart:229-236` redirects `/home`, `/explore/*` to `/coach/chat` with no query preservation. Only one redirect (app.dart:922-926, `/advisor/wizard`) handles this correctly.

5. **Seven screens are unanimously killable on doctrine alone** (no data needed): `budget_container_screen`, `achievements_screen`, `cantonal_benchmark_screen`, `ask_mint_screen`, `score_reveal_screen`, `portfolio_screen`, `retirement_dashboard_screen`. Every expert kills these, every one cites CLAUDE.md §1 (not a retirement app, not a portfolio app) or §6 (no social comparison, no gamification).

6. **Navigation is not the visual crisis. It is the mental-model crisis.** UX §0 ("This is a mental-model crisis, not a visual one"), Strategist ("your Identity document is 10/10, your code is 5/10 because it ships three products"), IA Expert ("NAV_GRAAL tries to reconcile the ambition with a code base that grew as a catalog"). No color token or new component fixes this. Only deletions + a shell do.

7. **The single architectural move is `ShellRoute` with chat as persistent root.** Nav Engineer §A.1 specifies it in production Dart. IA Expert arrives at the same answer from user mental-model reasoning. Strategist arrives via "one primary surface + escape hatch". UX is silent on the primitive but compatible. Only the Critic flags that the shell *shape* (chat-only vs 2-tab) is still unproven — but not the shell *primitive* itself.

---

## Section 3 — The decisions

Below: every substantive disagreement, with a call. Not a framework — a decision.

### Decision 1 — Shell architecture

**→ Single `ShellRoute` with `/app/chat` as persistent root child. Upgrade path to `StatefulShellRoute.indexedStack` reserved but not taken now.**

- **Rationale**: Nav Engineer §A.1 shows this is the cheapest primitive that (a) eliminates `safePop` fallback soup, (b) makes chat persistent across pushes, (c) keeps upgrade path to 2-tab open. Critic §D.1 confirms it has the highest **optionality** — you can come back and add tabs in one afternoon (`StatefulShellRoute` is a drop-in parent).
- **Rejected alternatives**:
  - *2-tab (IA Expert "Coach + Monde")* — unproven with Swiss non-chatters. Requires building `MondeHome` + 6 domain templates. Ships a new taxonomy before data.
  - *Chat-only, no shell primitive* (implicit Strategist) — re-creates today's bug. We need the shell primitive even if the user-visible surface is one.
  - *5-branch StatefulShellRoute from day 1* — too much ceremony, no evidence it helps.
- **Why this wins**: one week of work, zero feature loss, maximum rollback. Critic §D.1 calls this explicitly: "ship the version that is cheapest to undo."

### Decision 2 — Number of screens to keep

**→ Kill 7 doctrinally-indefensible screens. Keep all ~88 others until Phase 0 evidence.**

- Not 65 (Strategist). Not 55 (IA Expert). Not 26 (Strategist target). **7 now, the rest after evidence.**
- **Rationale**: Critic §B.1 is decisive: "the kill list is aspirational, not evidence-based." Doctrine-driven kills in a live app with TestFlight users is malpractice. The 7 unanimous kills (see Section 2, item 5) are the only ones we can defend without a single analytics query.
- **Rejected alternatives**: Strategist's 26 is a 6-week rewrite disguised as consolidation — it requires building 5 brand-new Unified mega-screens (Decision Canvas, Life Simulator, Protection Gap, Prévoyance Planner, Housing Decision) that don't exist today. That's net-new features, not deletion. IA's 55 is closer but still requires relocating 67 screens under a new Monde taxonomy that hasn't been user-tested.
- **Why this wins**: it's the only kill count that is simultaneously (a) doctrinally safe, (b) execution-cheap, (c) reversible. Phase 0 evidence will tell us whether to escalate to 26, 55, or stay around 80.

### Decision 3 — Migration phasing

**→ Critic's path. Evidence → Phase 1 (stop the bleeding) → Phase 2 (shell) → Phase 3 (product reduction, only with data).**

- **Rationale**: the Critic is the only reviewer who priced the work honestly. Strategist and IA assume a 2-week sprint and it is not a 2-week sprint.
- **Rejected alternatives**: big-bang rewrite (Strategist implicit), UX's 2-week tidy-up (ignores the backend/LLM prompt coupling).
- **Why this wins**: each phase is independently shippable and independently rollback-able. If Phase 1 reveals something new, Phase 2 adapts. If Phase 2 users hate the shell, Phase 3 pivots. No one-way doors.

### Decision 4 — Budget loop fix

**→ Delete `BudgetContainerScreen`, route `/app/budget` to the orphaned `BudgetScreen`. If `BudgetScreen` doesn't actually collect data (nobody read it), fall back to UX Senior's bottom-sheet inline collector.**

- **Rationale**: Nav Engineer §E Phase 1 step 5-6 is explicit. Critic §A.4 calls out that nobody actually read `BudgetScreen` to verify it's fit for purpose — so Phase 1 Day 2 begins by reading it.
- **Rejected alternatives**: relocating Budget as a Tool under a Monde hub (IA) — out of scope for Phase 1.
- **Why this wins**: closes the loop end-to-end in <4 hours of work. Phase 1 gate.

### Decision 5 — Anti-shame patterns in navigation

**→ Adopt UX Senior §D verbatim. 10 patterns to kill, 10 patterns to embrace.**

- **Rationale**: this is the only place in the 5 reports where anti-shame is concretely mapped to navigation primitives (not just copy). Every item is already doctrine per `feedback_anti_shame_situated_learning.md` in memory — UX Senior's contribution is the navigation mapping.
- **What to ban now**:
  1. Profile completion percentages
  2. Locked icons
  3. The verb "débloquer"
  4. Progress bars that stall
  5. Streak counters
  6. Red numbers for user state
  7. Empty hubs saying "rien à afficher"
  8. "Vous avez loupé X"
  9. Peer comparisons (even flattering)
  10. Dead ends with no path forward
- **What to embrace now**:
  1. Honest silence ("Rien n'a bougé cette semaine. C'est OK.")
  2. Continuation, not progress ("on en était là")
  3. Inline data collection (never a separate "profile setup" screen)
  4. Pre-filled everything
  5. Reversibility
  6. "On" instead of "tu dois"
  7. Conditional language for all projections
  8. Intent-first navigation
  9. Visible memory on return
  10. Exits without questions
- **Enforcement**: grep-level CI guard on banned terms ("débloquer", "bravo", "tu as loupé", "profil à XX%"). See Section 7.

### Decision 6 — Mental model sentence

**→ UX Senior's short version: "Tu parles. Je traduis. Je te montre ce qu'on ne t'explique pas."**

- **Rationale**: it's the shortest, most testable of the three candidates and the only one that encodes the inversion (user speaks first, MINT responds). IA Expert's "voice in my pocket" is too abstract. Strategist's "calm pocket-sized Swiss intelligence" is a tagline, not a mental model.
- **Usage**: this sentence goes in one place only for now — the LandingScreen. Not in onboarding, not in marketing copy, not in pressing users. If it survives 3 user tests without eye-roll, it graduates.
- **What it replaces**: the current generic "Mint te dit ce que personne n'a intérêt à te dire" stays as the **brand promise** on the landing CTA; the UX Senior sentence is the **how** that sits underneath.

### Decision 7 — Life event screens (divorce, mariage, naissance, etc.)

**→ Keep them as individual routes. Do NOT merge into a Unified Life Simulator in v1.**

- **Rationale**: Critic §D.3 is decisive. Each life event has distinct compliance logic (divorce → CO art. X, décès → CC art. Y, mariage → LIFD art. Z). Merging screens means merging rule sets — a 6-way switch-case compliance surface. Critic §E.4: "merging 6 life events into one UI means merging 6 rule sets. Edge cases compound. FINMA letter, not a bug report."
- **Rejected**: Strategist's Unified Life Simulator.
- **Compromise**: life event screens keep their individual routes but move under `/app/*` inside the shell, so they back-button to chat cleanly.

### Decision 8 — Explorer tab / Monde / browse surface

**→ Defer. Do NOT rename, do NOT restructure, do NOT kill. Ship Phase 1 and Phase 2 with the current 4-tab shell broken (as it is today), and decide the browse surface in Phase 3 after user tests.**

- **Rationale**: IA wants Monde with 6 domains. UX wants search-first + chips. Strategist wants no browse surface at all. Critic §D.2 says "the only variant not load-bearing on a content taxonomy that doesn't exist yet" is UX's search-first. **Good — but we don't need to pick in April.** The current `Explorer` tab is not actively harmful, just mediocre. Phase 1 doesn't touch it.
- **Rejected alternatives**: committing to a 2-tab (IA) or chat-only (Strategist) shell before the 3 user tests in Section 4 Phase 0 Day 3.
- **Why this wins**: deferring costs nothing. Committing costs everything.

### Decision 9 — Anonymous user persistence

**→ Local-only via `SharedPreferences`. Cleared on uninstall. Explicit "fais-moi un compte si tu veux retrouver ça" CTA after the first Premier Éclairage, framed as a gift, never as a wall.**

- **Rationale**: Critic §B.3 + §D.5. nLPD/FINMA allows device-local without consent. Server-side persistence requires consent. The anti-shame rule (UX §D) forbids framing account creation as a "lock" — it must be a continuation, not a prison.
- **Explicit rule**: no profile data leaves the device until the user has opted in via the post-Éclairage CTA. This includes analytics — pseudonymous events only for anonymous sessions.

### Decision 10 — Backend / Claude prompt route coupling

**→ Create a shared `route_registry.json` in `shared/` (both backend and Flutter read it). Add CI check: no route referenced in `claude_coach_service.py` prompts/tools that isn't in the registry.**

- **Rationale**: Critic §B.4 is the most under-considered risk in the 5 reports. Claude already emits `tool_call` payloads that name routes. If we delete `/achievements` and Claude's tool schema still references it, users see broken cards in production. Nav Engineer §E Phase 3 hand-waved this as "tools/openapi/ — nothing to update" — the Critic is right that this is wrong.
- **Action**: before any route deletion lands, grep `services/backend/app/` for every string that matches a route pattern. Section 9 Day 5.

### Decision 11 — Android support

**→ Every manual smoke test runs on both platforms before a phase closes. Phase 1 explicitly tests Android back button semantics on Q, R, S, T.**

- **Rationale**: Critic §B.6 — all 5 reports wrote for iOS. The app ships on both. Android back behavior on a persistent `ShellRoute` with `PopScope` is non-trivial.
- **Gate**: Phase 2 cannot close until a real Android device (not emulator) survives: cold start, deep link, notification tap, back-button from every shell tool.

### Decision 12 — User testing before chat-first lock-in

**→ Phase 0 Day 3 is non-negotiable. 3 Swiss users, including at least one 50+ non-chatter, tested on a working Phase 1 build before Phase 2 shell lands.**

- **Rationale**: Critic §B.8. "Cleo proved chat-first in the UK for 18-25-year-olds with overdrafts. Different universe." MINT's doctrine is 18-99, Swiss, higher-trust-threshold. Zero evidence chat-first survives contact with a 58-year-old Vaudois.
- **Gate**: if 2 of 3 users bounce off chat as the primary surface, Phase 2 pivots to IA Expert's 2-tab (Coach + Monde) before shipping.

---

## Section 4 — The roadmap

Four phases. Phase 0 is evidence (no code). Phases 1-3 each gate into the next.

### Phase 0 — Evidence gathering (1-2 days, no code changes)

**Goal**: produce a single "blast radius + data" document that informs every Phase 1-3 decision.

**Actions**:

1. **Analytics audit** (2 hours):
   - Pull per-screen MAU / session count / dwell time from MixPanel / Firebase / Segment / whatever ships today.
   - **If MINT has zero usage data**: that is the Phase 0 finding. Add a one-line `GoRouter.of(context).routerDelegate.addListener` to log route transitions, deploy as a one-file PR, wait 24 hours. Then re-run analytics audit.
   - Cross-reference the 7 unanimous-kill screens against real usage. If any of them is in the top 20% by MAU, the kill list re-opens.

2. **Sentry / Crashlytics scan** (1 hour):
   - Filter on navigation-related crashes in the last 30 days.
   - Look specifically for (a) `safePop` / back-button errors, (b) `_MintErrorScreen` renders, (c) rapid nav events that look like a loop (bimodal session-end signature).
   - Produce a one-page "what is actually breaking in production" memo.

3. **Backend blast-radius grep** (1 hour):
   - `grep -rE "/(coach|retraite|budget|app|explore|3a|mortgage|segments|life-event|debt|independants|arbitrage|disability|assurances|simulator|scan|profile|settings|advisor|onboarding|couple|documents|education|rapport|portfolio|timeline|achievements|score-reveal|ask-mint|confidence|decaissement|succession|home|invalidite|mariage|naissance|concubinage|divorce|expatriation|first-job|unemployment|frontalier|pilier-3a|rachat-lpp|libre-passage|epl|hypotheque|fiscal|cantonal-benchmark|bank-import|data-block|open-banking|auth)" services/backend/`
   - Cross-reference every match against the current `screen_registry.dart`.
   - Specifically: read `services/backend/app/services/claude_coach_service.py` and every `tool_*` schema — list every route name referenced.

4. **Mechanical facade audit** (30 min):
   - `find apps/mobile/lib/screens -name "*.dart" -exec wc -l {} \; | awk '$1<80'`
   - Cross-reference with the 21 `safePop` call sites.
   - Any overlap = facade candidate.

5. **3 Swiss non-chatter user tests** (Day 3, 1 hour each):
   - Find 3 users: 1× 30-something chatter, 1× 45-55 skeptic, 1× 58+ non-chatter. Romand + Alémanique if possible.
   - Script: "Where would you look to understand your 3a? Where would you look for your retirement number? How would you import your LPP certificate? What do you expect to happen when you tap 'Coach'?"
   - **Deliverable**: a 1-page memo of what users expect vs what MINT ships. This memo is more valuable than all 5 expert reports combined.

**Phase 0 deliverable**: one document `/.planning/architecture/phase-0-evidence.md` containing (a) usage data or instrumentation plan, (b) crash taxonomy, (c) backend route list, (d) facade list, (e) 3 user-test notes. Estimated: 1.5 days if analytics exist, 3 days if they don't (add 24h data collection).

**What Phase 0 is NOT**: code changes, design files, Figma mocks, ADR drafts.

---

### Phase 1 — Critical fixes (2-3 days, no architecture change)

**Goal**: stop the bleeding (LOOP-01, NAV-01, REDIR-01) without renaming a single route.

**Files to modify, in order** (numbers match Nav Engineer §E Phase 1):

1. **Create** `apps/mobile/lib/services/navigation/mint_nav.dart` — paste the full `MintNav` class from Nav Engineer §B (lines 152-321 of `03-NAV-ENGINEER.md`). ~200 lines. Includes `back(fallback:)`, `closeWithResult`, `open`, `resetToHome`, `resetToRoot`, `replaceWith`.

2. **Create** `apps/mobile/lib/router/preserving_redirect.dart` — the 5-line helper from Nav Engineer §D anti-pattern #1:
   ```dart
   GoRouterRedirect preserveQueryRedirect(String target) {
     return (BuildContext context, GoRouterState state) {
       final query = state.uri.query;
       return query.isEmpty ? target : '$target?$query';
     };
   }
   ```

3. **Edit** `apps/mobile/lib/services/navigation/safe_pop.dart` (currently 15 lines):
   - Keep the file. Replace body with `MintNav.back(context, fallback: '/coach/chat')`.
   - Add `@Deprecated('Use MintNav.back(context, fallback: ...) — explicit fallback required')`.
   - This makes `flutter analyze` surface every call site as a lint warning without breaking the build.

4. **Patch** `apps/mobile/lib/app.dart` (~1310 lines) — the 40 redirects at lines ~229-930. Mechanical replace:
   - Every `redirect: (_, __) => '/coach/chat'` → `redirect: preserveQueryRedirect('/coach/chat')`.
   - Estimated diff: ~40 lines.
   - Specifically verify: `/home` (line ~229), `/onboarding/enrichment` (~930), `/advisor/*` (~920), every `/explore/*` (~236).

5. **Delete** `apps/mobile/lib/screens/budget/budget_container_screen.dart`. Before deleting:
   - **Read** `apps/mobile/lib/screens/budget/budget_screen.dart` and verify it actually collects data. If yes: route `/budget` in `app.dart` (line ~390-393) to `BudgetScreen`. If no: route `/budget` to an ephemeral route that triggers a bottom-sheet inline collector (3 inputs: revenu mensuel, charges fixes, envies) and returns the user to the chat on completion.
   - Either way, the facade dies.

6. **Audit** `apps/mobile/lib/screens/budget/budget_screen.dart`:
   - Ensure its CTAs do NOT emit `context.go('/coach/chat?prompt=budget')` (that would re-open the loop from the other end).
   - If they do, replace with a terminal "Merci, c'est enregistré" state + `MintNav.back(context, fallback: '/coach/chat')`.

7. **Kill 6 of 7 unanimously-indefensible screens** (leave `budget_container_screen` out because step 5 handled it). In order of risk (low to high):
   - `apps/mobile/lib/screens/achievements_screen.dart` — delete file, delete route in app.dart.
   - `apps/mobile/lib/screens/cantonal_benchmark_screen.dart` — delete file, delete route.
   - `apps/mobile/lib/screens/ask_mint_screen.dart` — delete file, replace `/ask-mint` with `preserveQueryRedirect('/coach/chat')`.
   - `apps/mobile/lib/screens/advisor/score_reveal_screen.dart` — delete file, delete `/score-reveal` route.
   - `apps/mobile/lib/screens/portfolio_screen.dart` — delete file, delete `/portfolio` route.
   - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart` — delete file, replace `/retraite` with `preserveQueryRedirect('/coach/chat?prompt=retraite')`. **GATE**: before deleting, confirm Phase 0 analytics show <1% of sessions land here. If it's a top-20 screen, reopen the kill.
   - **Before any delete**: grep for the route in `services/backend/`. If a backend reference exists, fix the backend first (Decision 10).

8. **Run** `flutter test` and `flutter analyze`. Expect 0 regressions. If there are regressions, the test suite was hiding something — investigate, don't override.

9. **Manual smoke test on a real device**, iOS + Android:
   - Chat → Budget card → Budget → back → chat (no loop).
   - Deep link `/achievements` → redirect to chat (doesn't crash).
   - Deep link `/retraite` → redirect to chat with `?prompt=retraite`.
   - Back button from 5 random tools → lands somewhere coherent.

**Phase 1 exit gate**: LOOP-01 dead, NAV-01 dead, 6 screens deleted, no new feature, no architecture change. Shippable to TestFlight the same day.

---

### Phase 2 — Architecture refactor (1-2 weeks, after Phase 1 ships and a user test says chat-first is OK)

**Goal**: introduce the `ShellRoute`, migrate all 21 `safePop` sites, make deep linking and back-button semantics mechanically consistent.

**Gate to start Phase 2**: Phase 1 is live on TestFlight for ≥48h with no crash spike. Phase 0 user tests did NOT reveal 2/3 non-chatters hating the chat (if they did, start Phase 2 by building IA Expert's 2-tab shell instead of single-shell).

**Files to modify, in order**:

1. **Create** `apps/mobile/lib/screens/app_shell/mint_app_shell.dart`:
   - Minimal `Scaffold` wrapper receiving `ShellRoute.child`.
   - `endDrawer: ProfileDrawer()`.
   - No AppBar (children provide their own).
   - `body: child`.

2. **Restructure** `apps/mobile/lib/app.dart`:
   - Add `final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');`
   - Wrap all tool routes in `ShellRoute(navigatorKey: _shellNavigatorKey, builder: (c, s, child) => MintAppShell(child: child), routes: [...])`.
   - **Critical**: remove `parentNavigatorKey: _rootNavigatorKey` from every tool route. Leave it ONLY on `/modal/*` routes and auth/landing.
   - Keep `/coach/chat` as the canonical hub path (do NOT rename to `/app/chat` — that's Phase 3).
   - Move `/scan`, `/scan/review`, `/scan/impact`, `/data-block/:type`, `/couple/accept` to a SECOND `ShellRoute` with `pageBuilder: (c, s, child) => MaterialPage(fullscreenDialog: true, child: child)` on the root navigator.

3. **Verify** `apps/mobile/lib/screens/coach/coach_chat_screen.dart`:
   - Because it's now hosted in `ShellRoute`, pushes no longer dispose its state.
   - Remove any `didChangeDependencies` assumption that state is torn down on navigation.
   - Audit for memory leaks in streams / subscriptions.

4. **Codemod** all 21 `safePop(context)` call sites:
   - Replace with `MintNav.back(context, fallback: '<screen-specific>')`.
   - Fallback per screen category (from Nav Engineer §A.4 + ScreenRegistry.fallbackRoute):
     - Crisis/life-event screens → `'/coach/chat'`
     - Document screens → `'/documents'`
     - Profile/settings screens → `'/profile/bilan'`
     - Auth screens → `'/'`
   - Mechanical, 1-2 hours.

5. **Delete** `apps/mobile/lib/services/navigation/safe_pop.dart`.

6. **Create** `tools/checks/no_raw_go_router.sh`:
   ```bash
   #!/bin/bash
   # Fails CI if any screen uses raw GoRouter calls instead of MintNav.
   hits=$(rg -l 'context\.(push|pop|go)|Navigator\.(push|pop)' apps/mobile/lib/screens/ || true)
   if [ -n "$hits" ]; then
     echo "FAIL: raw GoRouter calls found in screens. Use MintNav.*:"
     echo "$hits"
     exit 1
   fi
   ```
   Wire into CI (`.github/workflows/ci.yml`).

7. **Delete 4-8 more screens** based on Phase 0 evidence. Priority order (pick the ones with <2% MAU):
   - `apps/mobile/lib/screens/simulator_compound_screen.dart` (generic compound interest calculator, covered by 3a tool)
   - `apps/mobile/lib/screens/coach/cockpit_detail_screen.dart` (cockpit metaphor contradicts identity)
   - `apps/mobile/lib/screens/arbitrage/arbitrage_bilan_screen.dart` (internal taxonomy leak)
   - `apps/mobile/lib/screens/education/comprendre_hub_screen.dart` (education catalog, not in chat-first flow)
   - `apps/mobile/lib/screens/education/theme_detail_screen.dart` (education detail)
   - `apps/mobile/lib/screens/timeline_screen.dart` (deferred in IA, killed in Strategist — pick deferred unless Phase 0 shows zero usage)
   - `apps/mobile/lib/screens/coach/annual_refresh_screen.dart` (already archived per Wire Spec V2, confirm)
   - `apps/mobile/lib/screens/confidence/confidence_dashboard_screen.dart` (confidence is a property, not a screen)

   **Hard gate**: don't delete if usage > 2% or if backend references it.

8. **Run** `flutter test` + `flutter analyze`. Adjust widget tests that mocked `safePop` — they now must mock `MintNav.back` or the navigation harness.

9. **Manual E2E** on iOS + Android:
   - Cold-start deep link to every tool under `/app/*` (use `flutter run --route=/retraite`, etc.).
   - Verify back button returns to chat, not `_MintErrorScreen`.
   - Verify `CoachChatScreen` state persists across pushes (type text, push a tool, come back — text still there).
   - Test notification tap with `mint://retraite` — lands in chat with prompt pre-filled.

**Phase 2 exit gate**: `ShellRoute` live, 21 call sites migrated, 4-8 more screens deleted (based on evidence), CI guard on raw GoRouter, both platforms smoke-tested, 1 TestFlight build shipped.

---

### Phase 3 — Product reduction (4-6 weeks, requires evidence from Phase 0 + 2 weeks of Phase 2 data)

**Goal**: use data gathered in Phase 0 + 2 weeks of Phase 2 live analytics to decide what else to kill and whether to ship any of the 5 Unified flows from the Strategist's plan.

**This phase is conditional.** Do NOT start until:
- Phase 2 is stable on TestFlight for ≥2 weeks.
- You have per-screen MAU for the full route map.
- You have a Phase 0 user-test memo.
- You have the backend/Claude prompt blast-radius document from Phase 0.

**Possible workstreams** (pick 2-3, not all):

1. **Rename `/coach/chat` to `/app/chat`**. Namespace all tools under `/app/*`. Keep `/coach/chat` etc. as `preserveQueryRedirect` shims with a 6-month sunset date. Nav Engineer §E Phase 3.

2. **Ship the Unified Decision Canvas** as a NEW screen behind a feature flag. It's the safest of the 5 Unified flows (Critic §E.4: "it's purely a compare widget"). Test it with Rente vs Capital as the first consumer. Leave old simulators in place initially. A/B gate.

3. **Merge 3 disability screens → 1**. Low compliance risk (all 3 use the same LPP/LAVS rules).

4. **Merge 5 independants screens → 1 tabbed screen**. Medium compliance risk; validate with Golden Couple (Lauren's FATCA archetype).

5. **Build the "Today surface" for returning users** (UX Senior Failure 4). Triggered on `hasActiveProfile() && lastSessionDate != null`. Two code paths, one screen.

6. **Replace the Explorer tab with search-first + 8 life-moment chips** (UX Senior Failure 5). Only if 2/3 Phase 0 users said "where would I browse?".

7. **Migrate to `StatefulShellRoute.indexedStack`** with 2 branches (Chat + Monde) if Phase 0 user tests strongly favored IA's 2-tab model.

**Each workstream ships its own PR, its own A/B test, its own rollback.** No big-bang releases.

**Phase 3 exit gate**: open-ended. Phase 3 is a rolling product roadmap, not a sprint.

---

## Section 5 — The screen-by-screen verdict

**Legend**: K1 = Kill Phase 1 | K2 = Kill Phase 2 (evidence-gated) | K3 = Kill Phase 3 (needs Unified replacement) | KEEP | MERGE-X = merge into X | RELOC = relocate under shell | AUTH = auth/landing infra | ADMIN = internal only

### The 35 contentious screens

| Screen | IA | UX | Nav | Strat | Critic | **VERDICT** | When |
|---|---|---|---|---|---|---|---|
| `budget_container_screen` | KILL | KILL | DELETE | KILL | KILL OK | **KILL** | P1 |
| `achievements_screen` | KILL | — | — | KILL | — | **KILL (doctrine)** | P1 |
| `cantonal_benchmark_screen` | KILL | — | — | KILL | — | **KILL (doctrine)** | P1 |
| `ask_mint_screen` | KILL | — | — | KILL | — | **KILL (dup)** | P1 |
| `score_reveal_screen` | MERGE | — | — | KILL | — | **KILL (doctrine)** | P1 |
| `portfolio_screen` | KILL | — | — | KILL | — | **KILL (scope)** | P1 |
| `retirement_dashboard_screen` | KILL | — | — | KILL | — | **KILL (framing)** ⚠ gate on P0 MAU | P1 |
| `simulator_compound_screen` | KILL | — | — | KILL | — | **KILL** ⚠ gate on MAU | P2 |
| `cockpit_detail_screen` | KILL | — | — | — | — | **KILL** | P2 |
| `arbitrage_bilan_screen` | KILL | — | — | — | — | **KILL** | P2 |
| `comprendre_hub_screen` | KILL | — | — | — | — | **KILL** ⚠ if MAU < 2% | P2 |
| `theme_detail_screen` | KILL | — | — | — | — | **KILL** ⚠ if MAU < 2% | P2 |
| `confidence_dashboard_screen` | MERGE | — | — | KILL | — | **RELOC → Dossier** | P2 |
| `timeline_screen` | DEFER | — | — | KILL | — | **DEFER** (keep as orphan) | — |
| `annual_refresh_screen` | MERGE | — | — | — | — | **KILL** (already archived) | P2 |
| `fiscal_comparator_screen` | RELOC | — | — | KILL | — | **KEEP + RELOC** | P2 |
| `consumer_credit_screen` | RELOC | — | — | KILL | — | **KEEP** (debt-prevention context) | — |
| `gender_gap_screen` | RELOC | — | — | KILL | — | **KEEP but hide from top nav** | P3 |
| `provider_comparator_screen` | KILL | — | KEEP | KILL | — | **KEEP** (LSFin review first) | — |
| `frontalier_screen` | RELOC | — | — | KILL | KEEP | **KEEP** (340k users) | — |
| `expat_screen` | RELOC | — | — | KILL | KEEP | **KEEP** | — |
| `independant_screen` | RELOC | — | — | KILL | KEEP | **KEEP** | — |
| `first_job_screen` | RELOC | — | — | KILL | — | **KEEP + RELOC** | P2 |
| `unemployment_screen` | RELOC | — | — | KILL | — | **KEEP + RELOC** | P2 |
| `mariage_screen` | RELOC | — | — | KILL | KEEP | **KEEP** (compliance) | — |
| `divorce_simulator_screen` | RELOC | — | — | KILL | KEEP | **KEEP** (compliance) | — |
| `naissance_screen` | RELOC | — | — | KILL | KEEP | **KEEP** (compliance) | — |
| `deces_proche_screen` | RELOC | — | — | KILL | KEEP | **KEEP** (compliance) | — |
| `concubinage_screen` | RELOC | — | — | KILL | KEEP | **KEEP** | — |
| `demenagement_cantonal_screen` | RELOC | — | — | KILL | — | **KEEP** | — |
| `donation_screen` | RELOC | — | — | KILL | — | **KEEP** | — |
| `disability_gap_screen` + 2 merges | MERGE | — | — | KILL | — | **MERGE → 1** | P3 |
| `debt_ratio` + `debt_risk_check` + `repayment` + `help_resources` | MERGE | — | — | KILL | — | **MERGE → 1 Safe Mode** | P3 |
| 5× mortgage screens | RELOC | — | — | KILL→1 | — | **KEEP all 5 in P1/P2, MERGE in P3** | P3 |
| 5× independants screens | RELOC | — | — | KILL | — | **KEEP all 5 in P1/P2, MERGE in P3** | P3 |
| 4× 3a-deep screens | RELOC | — | — | KILL | — | **KEEP, MERGE in P3** | P3 |
| 3× lpp-deep screens | RELOC | — | — | KILL | — | **KEEP, MERGE in P3** | P3 |
| 4× arbitrage screens | RELOC | — | — | KILL→1 | — | **KEEP, consolidate in P3 via Unified Decision Canvas** | P3 |

### The rest, grouped (no drama)

- **Auth (4)**: `login`, `register`, `forgot_password`, `verify_email` — **KEEP, no changes**.
- **Landing (1)**: `landing_screen` — **KEEP**. Update CTA copy in Phase 2 to Decision 6 sentence.
- **Admin (2)**: `admin_analytics_screen`, `admin_observability_screen` — **KEEP**, feature-flagged, not user-facing.
- **Document flow (5)**: `document_scan`, `avs_guide`, `extraction_review`, `document_impact`, `documents_screen`, `document_detail_screen` — **KEEP all**, move to modal routes in Phase 2 per Nav Engineer §D anti-pattern #5. P2 converts `/scan/review` to `/modal/scan/review` with explicit `extra` passing.
- **Profile/settings (7)**: `about`, `byok_settings`, `slm_settings`, `langue_settings`, `privacy_control`, `consent_screen`, `financial_summary_screen` — **KEEP all**. Consider merging settings in P3 only if evidence shows users don't find them.
- **Couple (2)**: `household_screen`, `accept_invitation_screen` — **KEEP both**.
- **Coach surface (remaining)**: `coach_chat_screen`, `conversation_history_screen`, `optimisation_decaissement_screen`, `succession_patrimoine_screen` — **KEEP all**.
- **Onboarding (1)**: `data_block_enrichment_screen` — **KEEP**, convert to modal in P2.
- **Bank import (1)**: `bank_import_screen` — **KEEP** (feature-flagged).
- **Open banking (3)**: `open_banking_hub_screen`, `consent_screen`, `transaction_list_screen` — **KEEP all**, feature-flagged for v2.
- **Rapport (1)**: `financial_report_screen_v2` — **KEEP**, but Phase 3 consider whether this survives the anti-dashboard doctrine.

**Summary totals**:
- **Kill in P1**: 7 screens.
- **Kill in P2 (evidence-gated)**: 4-8 screens.
- **Merge / consolidate in P3**: ~15 screens into ~5 Unified canvases.
- **Keep as-is**: ~65 screens.
- **Reserved / deferred**: 3 (timeline + 2 open banking).

**Net Phase 2 state**: 95 → 80 screens, ShellRoute shipped, zero new Unified screens.
**Net Phase 3 state** (6-8 weeks later, evidence-driven): 80 → 50-60 screens, 2-3 Unified canvases shipped behind feature flags.

---

## Section 6 — The shell architecture spec (1 page)

### Visual

```
┌─────────────────────────────────────────────────┐
│                 Root Navigator                  │
│  ┌───────────────────────────────────────────┐ │
│  │ /                    LandingScreen        │ │  ← public, outside shell
│  │ /auth/*              Auth screens         │ │  ← public, outside shell
│  └───────────────────────────────────────────┘ │
│                                                 │
│  ┌───────────────────────────────────────────┐ │
│  │              ShellRoute                    │ │
│  │          (_shellNavigatorKey)              │ │
│  │                                            │ │
│  │  ┌──────────────────────────────────────┐ │ │
│  │  │    MintAppShell(child)               │ │ │
│  │  │  - Scaffold wrapper                  │ │ │
│  │  │  - endDrawer: ProfileDrawer          │ │ │
│  │  │  - body: child (the pushed tool)     │ │ │
│  │  │                                       │ │ │
│  │  │  ┌────────────────────────────────┐ │ │ │
│  │  │  │   /coach/chat                   │ │ │ │  ← persistent root
│  │  │  │   CoachChatScreen               │ │ │ │     never disposed
│  │  │  └────────────────────────────────┘ │ │ │
│  │  │                                       │ │ │
│  │  │  pushed children (tool drill-in):    │ │ │
│  │  │   /budget, /retraite, /rente-vs-...  │ │ │
│  │  │   /rachat-lpp, /epl, /pilier-3a, ... │ │ │
│  │  │   (~80 tools, all share back=chat)   │ │ │
│  │  └──────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────┘ │
│                                                 │
│  ┌───────────────────────────────────────────┐ │
│  │       Modal ShellRoute                     │ │
│  │       (parentNavigatorKey: _root)          │ │  ← fullscreenDialog
│  │  /modal/scan                               │ │     overlays everything
│  │  /modal/scan/review                        │ │
│  │  /modal/data-block/:type                   │ │
│  │  /modal/couple/accept                      │ │
│  └───────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

### Technical structure (abbreviated)

```dart
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  observers: [AnalyticsRouteObserver()],
  errorBuilder: (c, s) => _MintErrorScreen(error: s.error),
  redirect: _authGuard,
  routes: [
    // Public, outside shell
    ScopedGoRoute(path: '/', scope: RouteScope.public, builder: (_, __) => const LandingScreen()),
    ScopedGoRoute(path: '/about', scope: RouteScope.public, builder: (_, __) => const AboutScreen()),
    ..._authRoutes(), // login, register, forgot, verify, verify-email

    // Shell — chat as persistent root, tools push over it
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MintAppShell(child: child),
      routes: [
        ScopedGoRoute(
          path: '/coach/chat', // canonical in P2, renamed to /app/chat in P3
          scope: RouteScope.public,
          builder: (context, state) => CoachChatScreen(
            initialPrompt: state.uri.queryParameters['prompt'],
            conversationId: state.uri.queryParameters['conversationId'],
          ),
        ),
        // ~80 tool routes (budget, retraite, rachat-lpp, epl, mortgage/*, etc.)
        ..._toolRoutes(),
      ],
    ),

    // Modal routes — fullscreenDialog overlays on the root navigator
    ShellRoute(
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (c, s, child) => MaterialPage(
        fullscreenDialog: true,
        child: child,
      ),
      routes: [
        ScopedGoRoute(path: '/modal/scan', ...),
        ScopedGoRoute(path: '/modal/scan/review', ...),
        ScopedGoRoute(path: '/modal/data-block/:type', ...),
        ScopedGoRoute(path: '/modal/couple/accept', ...),
      ],
    ),

    // Legacy redirects (P2 keeps these, P3 adds sunset dates)
    ..._legacyRedirects(), // all using preserveQueryRedirect()
  ],
);
```

### Why this shape

- **Single ShellRoute, not `StatefulShellRoute`**: `StatefulShellRoute` is for multi-branch tab state. Today we have one branch. When Phase 3 user testing demands 2 tabs, swap to `StatefulShellRoute.indexedStack` — it's a drop-in parent class.
- **Modal in a second ShellRoute on root**: GoRouter's canonical way to make modals overlay the shell (not inside it). `parentNavigatorKey: _rootNavigatorKey` is the explicit hint.
- **No `parentNavigatorKey` on tool routes**: critical. Anti-pattern #3 in Nav Engineer §D. If we leave `parentNavigatorKey: _rootNavigatorKey` on tools (as today's code does for all ~90 routes), the shell silently breaks and the chat is hidden on every push.
- **Chat remains at `/coach/chat`, not `/app/chat`, in Phase 2**. Rename is a Phase 3 migration.

---

## Section 7 — Anti-patterns to ban (with CI guards)

Taken from all 5 expert reports, deduplicated and sorted by blast radius.

### AP-1 — Redirect chains that drop query params

- **Pattern**: `redirect: (_, __) => '/coach/chat'`
- **Why bad**: notification deep links, emails, analytics all lose context. A push with `?prompt=budget` becomes a cold chat.
- **Detect**: `rg "redirect: \(.*\) => '" apps/mobile/lib/app.dart`
- **Fix**: every redirect uses `preserveQueryRedirect('/target')` from `apps/mobile/lib/router/preserving_redirect.dart`.

### AP-2 — Facade screens (re-emit chat prompt)

- **Pattern**: a screen whose only CTA does `context.go('/coach/chat?prompt=X')` where X opened the screen.
- **Why bad**: infinite loop (LOOP-01).
- **Detect**: `rg "context\.go\('/coach/chat\?prompt=" apps/mobile/lib/screens/`
- **Fix**: delete the facade, replace with real data collection (bottom sheet or real screen).

### AP-3 — Raw GoRouter calls in screens

- **Pattern**: `context.push(...)`, `context.go(...)`, `context.pop(...)`, `Navigator.push(...)`, `Navigator.pop(...)` anywhere under `apps/mobile/lib/screens/`.
- **Why bad**: every raw call bypasses `MintNav`'s safety, analytics, and type-checked fallback.
- **Detect** (CI check, `tools/checks/no_raw_go_router.sh`):
  ```bash
  rg -l 'context\.(push|pop|go)\b|Navigator\.(push|pop)\b' apps/mobile/lib/screens/
  ```
- **Fix**: use `MintNav.open`, `MintNav.back`, `MintNav.closeWithResult`, `MintNav.replaceWith`, `MintNav.resetToHome`.

### AP-4 — `parentNavigatorKey: _rootNavigatorKey` on shell-bound tools

- **Pattern**: a `GoRoute` inside the `ShellRoute`'s `routes:` list setting `parentNavigatorKey: _rootNavigatorKey`.
- **Why bad**: silently bypasses the shell, breaking the persistent chat.
- **Detect** (CI check, `tools/checks/no_root_nav_key_in_shell.sh`):
  ```bash
  awk '/ShellRoute\(/,/\]\),/ {print}' apps/mobile/lib/app.dart | grep -n 'parentNavigatorKey: _rootNavigatorKey'
  ```
- **Fix**: remove the key from shell-bound tools. Keep it only on `/modal/*` routes.

### AP-5 — Screens that read `state.extra` for required data without fallback

- **Pattern**: `final result = state.extra as ExtractionResult?;` and then an error state if null.
- **Why bad**: `state.extra` doesn't survive cold start, deep link, or notification. Screen becomes non-deep-linkable silently.
- **Detect**: `rg 'state\.extra as [A-Z]\w+\?' apps/mobile/lib/`
- **Fix**: either make the route a modal (not deep-linkable) OR persist the data and rebuild from persistence.

### AP-6 — Shame-coded copy in navigation

- **Pattern**: "débloquer", "complet à X%", "bravo", "tu as loupé", "en retard", red numbers for user state.
- **Why bad**: CLAUDE.md §6, `feedback_anti_shame_situated_learning.md`.
- **Detect** (CI check, `tools/checks/no_shame_copy.sh`):
  ```bash
  rg -l '(débloquer|bravo|tu as loupé|complet à|retard)' apps/mobile/lib/l10n/*.arb apps/mobile/lib/screens/
  ```
- **Fix**: use the 10-item "embrace" list from Decision 5.

### AP-7 — Hardcoded routes in backend prompts

- **Pattern**: `"Navigate the user to /achievements"` in `claude_coach_service.py`.
- **Why bad**: when Flutter deletes `/achievements`, Claude still emits it. Users see broken cards.
- **Detect** (CI check):
  ```bash
  rg '"/(coach|retraite|budget|app|explore|3a|mortgage|segments|life-event|debt|independants|arbitrage|disability|assurances|simulator|scan|profile|settings|advisor|onboarding|couple|documents|education|rapport|portfolio|timeline|achievements|score-reveal|ask-mint|confidence|decaissement|succession|home|invalidite|mariage|naissance|concubinage|divorce|expatriation|first-job|unemployment|frontalier|pilier-3a|rachat-lpp|libre-passage|epl|hypotheque|fiscal|cantonal-benchmark|bank-import|data-block|open-banking|auth)' services/backend/
  ```
  Any match must exist in `shared/route_registry.json` (Phase 3 deliverable).
- **Fix**: centralize route strings in `shared/route_registry.json`, read by both stacks.

### AP-8 — Catalog exposure (grid of simulators)

- **Pattern**: a screen showing a list of 5+ tools in a grid with icons + names.
- **Why bad**: IA Expert §Paragraph 5 ("never let the user see a list of tools"). Teaches the user MINT is a calculator app.
- **Detect**: manual review. Candidates: current `/tools` route, `/explore/*` hub listing, `ComprendreHubScreen`.
- **Fix**: Phase 3 replaces with either (a) search-first + chips (UX Senior) or (b) kill entirely (Strategist).

---

## Section 8 — What we will measure

Critic §C is right: don't ship without metrics. Five KPIs, five targets, five reactions.

### KPI 1 — Back-button exit rate (ex-LOOP-01)

- **What it measures**: % of sessions that end within 60 seconds of tapping a Budget-related CTA.
- **How**: analytics event on `/budget` entry, session-end event, delta.
- **Target**: < 5% post-Phase 1 (vs. unknown baseline).
- **Reaction if wrong**: the loop still exists. Read `BudgetScreen` code again.

### KPI 2 — `_MintErrorScreen` render count

- **What it measures**: how often the router lands on the error fallback.
- **How**: Sentry breadcrumb + custom event in `errorBuilder`.
- **Target**: < 0.1% of sessions post-Phase 1.
- **Reaction if wrong**: a deleted route is still referenced somewhere (backend prompt, persisted conversation card, push notification). Rollback the delete, find the reference.

### KPI 3 — Session-1 chat engagement rate

- **What it measures**: % of first-session users who type at least one message to chat.
- **How**: analytics event on first `coach_chat_user_message_sent`.
- **Target**: > 40% (Cleo-band for anglo market; TBD for Swiss).
- **Reaction if wrong**: < 30% means chat-first is failing. Phase 3 must introduce a browse surface (IA's 2-tab OR UX's search-first).

### KPI 4 — Session-2 return rate

- **What it measures**: % of users who open MINT again within 7 days.
- **How**: standard retention cohort.
- **Target**: > 25% (fintech benchmark for non-transactional apps).
- **Reaction if wrong**: if this drops between Phase 1 and Phase 2, the ShellRoute broke something. Roll back.

### KPI 5 — Deep-link success rate

- **What it measures**: % of deep links (notification taps, email clicks) that land on the correct screen with the correct context.
- **How**: query param `?src=notification` on all notification deep links + analytics event on route-match.
- **Target**: > 95%.
- **Reaction if wrong**: the `preserveQueryRedirect` helper is not applied everywhere. Grep for raw redirects.

**Instrumentation deliverable (Phase 0 Day 1)**: add these 5 events to the analytics pipeline if they don't exist. No shell changes before these events are flowing.

---

## Section 9 — Next 24 hours (hour-by-hour)

Concrete. Julien starts Monday morning.

### Hour 1 (Monday 09:00)
- Read this document once, end to end. Total read time: 15 min.
- Open `apps/mobile/lib/app.dart`. Confirm it's ~1310 lines. Confirm `_rootNavigatorKey` at line 137.
- Open `apps/mobile/lib/services/navigation/safe_pop.dart`. Confirm 15 lines. Read the body.
- Open `apps/mobile/lib/screens/budget/budget_container_screen.dart`. **Read it fully.** This is the 30-minute investigation that all 5 experts skipped.
- Open `apps/mobile/lib/screens/budget/budget_screen.dart`. **Read it fully.** Decide: does it collect data or is it a second facade?

### Hour 2-3 (Monday 10:00-12:00) — Phase 0 Day 1 kickoff
- Run the mechanical facade audit: `find apps/mobile/lib/screens -name "*.dart" | xargs wc -l | awk '$1<80' | sort -n`. Cross-reference with the 21 `safePop` call sites.
- Run the backend blast-radius grep (Section 4 Phase 0 Action 3). Save the output to `.planning/architecture/phase-0-backend-routes.txt`.
- Grep `services/backend/app/services/claude_coach_service.py` for every route literal. Save to `.planning/architecture/phase-0-claude-routes.txt`.
- If MixPanel / Firebase / Segment exists: pull per-screen MAU for the last 30 days. Save to `.planning/architecture/phase-0-analytics.csv`.
- If not: add a one-line route logger to `app.dart`'s `observers:` list. Deploy a one-file PR. Wait 24 hours.

### Hour 4 (Monday 13:00-14:00)
- Lunch.

### Hour 5 (Monday 14:00-15:00) — user test recruiting
- Contact 3 Swiss testers for Wednesday. Explicit asks:
  - 1× 30-something product/tech worker (Romand or Alémanique)
  - 1× 45-55 non-technical, finance-curious
  - 1× 58+ non-chatter, explicitly skeptical of AI
- Offer 50 CHF + 1 hour.
- If nobody is available by Wednesday, push the user tests to Thursday — but DO NOT skip them.

### Hour 6-8 (Monday 15:00-18:00) — Phase 1 code start (ahead of schedule)
- Create `apps/mobile/lib/services/navigation/mint_nav.dart`. Paste from Nav Engineer §B (lines 152-321 of `03-NAV-ENGINEER.md`).
- Create `apps/mobile/lib/router/preserving_redirect.dart` (5-line helper).
- Run `flutter analyze`. Expect 0 errors.
- **Do not commit yet**. Wait for Phase 0 data to verify you're not about to delete a screen that's in the top 20% of MAU.

### Tuesday (if Phase 0 data confirms)
- Deprecate `safe_pop.dart` body → delegates to `MintNav.back`.
- Patch the 40 redirects in `app.dart` to use `preserveQueryRedirect`.
- Delete `BudgetContainerScreen` and route `/budget` to `BudgetScreen` OR bottom-sheet collector (based on what you read Monday hour 1).
- Run `flutter test`. Commit as one small PR. Ship to TestFlight.

### Wednesday
- User tests. 1 hour each. Follow the script in Section 4 Phase 0 Action 5.
- Write the 1-page memo: "What Swiss users expect vs what MINT ships."
- Based on the memo, decide Phase 2 shell shape: single-shell (Strategist/Nav) or 2-tab (IA Expert).

### Thursday-Friday
- Kill the 6 doctrinally-indefensible screens (Phase 1 step 7). **Hard gate**: Phase 0 MAU data must confirm each is < 2% usage.
- Manual smoke test on iOS + Android.
- Ship Phase 1 build to TestFlight Friday afternoon.

---

## Section 10 — Open questions for Julien

The things only you can answer. Do not start Phase 1 until these are clear.

1. **Do we have any usage analytics?** If MixPanel/Firebase/Segment exists, where is the dashboard? If not, are we OK adding a one-line route logger and waiting 24h before Phase 1?

2. **Are we OK with TestFlight users losing state when we ship Phase 1?** (In practice, no: the deletions in Phase 1 step 7 are all low-state screens. But if a user has a conversation card pointing at `/achievements`, it will 404-redirect to chat. Acceptable?)

3. **Is the anonymous coach already live on TestFlight?** The Critic §B.3 concern depends on this. If users are creating profiles anonymously today, we need the Decision 9 persistence rule *now*, not in Phase 3.

4. **Who owns `claude_coach_service.py`?** Is there a backend dev on-call this week? Because Decision 10 requires backend changes before Phase 1 deletions can land safely.

5. **Does the current Explorer tab generate any real engagement?** If yes, Phase 0 analytics will show it. If no, we can kill it in Phase 2 without ceremony.

6. **Are the 5 Unified flows (Strategist §D) a priority for you, or a distraction?** They are 6 weeks of work each, minimum. If you think they're the answer, Phase 3 is a 6-month project. If you're willing to defer, Phase 3 is a 3-month roll-out.

7. **Do you have a FINMA/LSFin legal advisor on retainer?** If yes, we can merge life-event screens in Phase 3 with legal review. If no, Decision 7 (keep individual life-event screens) is non-negotiable.

8. **What's the current state of the coach's system prompt?** Is it source-controlled? Is there a CI check on it? The Critic §B.4 blind spot depends entirely on the answer.

9. **Is there a "golden path" session flow you test manually before every TestFlight build?** If yes, that's Phase 0's 6th deliverable — document it and turn it into an automated smoke test. If no, creating one is Phase 0 Day 2.

10. **Are you willing to defer the mental-model sentence rollout?** Decision 6 says ship UX Senior's sentence on the landing CTA. But rolling it into onboarding / marketing / push notifications is a brand decision you haven't made yet. Phase 2 ships it on landing only, pending your sign-off for wider use.

---

## Closing — the one thing that matters

All 5 experts wrote from inside MINT's Identity document. That document is gospel and it's also a hypothesis. The navigation decisions above treat it as a prior, the code as evidence, and the user as the arbiter.

**Phase 1 is uncontested, low-risk, and buys time.** It fixes the Budget loop, it kills the 7 indefensible screens, it stabilizes the router without committing to a shell shape. Everything else — the 2-tab shell, the Unified flows, the Monde taxonomy, the 26-screen utopia — is theology until Wednesday's user tests produce the first piece of real data.

Ship Phase 1 this week. Decide Phase 2 with data Thursday. Decide Phase 3 with two weeks of Phase 2 telemetry.

That is the roadmap. That is the order.

*— End of master decision document —*
