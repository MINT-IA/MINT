# 05 — Devil's Advocate Review of the 4 Expert Proposals

> **Author**: Senior principal engineer + product manager, 20 years shipping mobile fintech.
> **Role**: Critic. I don't build solutions. I tear holes in proposals until only the parts that survive contact with reality remain.
> **Date**: 2026-04-11
> **Input**: `01-IA-FINTECH-EXPERT.md`, `02-UX-SENIOR.md`, `03-NAV-ENGINEER.md`, `04-PRODUCT-STRATEGIST.md`, plus `CLAUDE.md`, `SCREEN_MAP.md`, `NAVIGATION_GRAAL_V10.md`.
> **Tone**: respectfully brutal. The point is to save two weeks of engineering from a beautiful plan that collapses on day 3.

---

## 0. The uncomfortable opening

The four experts wrote four good documents. Three of them (IA, UX, Strategist) are basically the **same document dressed in different vocabulary**: kill most screens, collapse to chat-first, delete the catalog. The fourth (Nav Engineer) is the only one grounded in compile-time reality and is also the only one whose plan can be shipped next week without a product vote.

That convergence is suspicious. Four consultants who never spoke to each other all landed on "Cleo, but Swiss". Either they're right, or they read the same prior (`MINT_IDENTITY.md`) and parroted it back with confidence. Probably both. What none of them did was:

1. Ask whether their plan would crash the app for 200 TestFlight users on Monday morning.
2. Ask for a single line of usage data.
3. Model what happens when Claude (the LLM) hallucinates a `tool_call` to `retirement_dashboard` after you've deleted it.
4. Consider that a 58-year-old in Sion might rather tap "Retraite" than talk to a chatbot that calls itself "MINT".

Let's go through the gaps.

---

## Deliverable A — Convergence map

### A.1 Shell architecture

| Expert | Verdict |
|---|---|
| **IA** | 2-tab shell: Coach + Monde. Dossier = drawer. Capture = top-right +. |
| **UX Senior** | Does not mandate a specific shell count. Argues for "one primary surface (chat) + a Today homecoming surface + a search-first Explorer". Effectively 2-3 surfaces. |
| **Nav Engineer** | Single `ShellRoute` with chat as root child. No tabs. Upgrade path to `StatefulShellRoute` later. Technically chat-only. |
| **Strategist** | "One primary surface (the coach) + one escape hatch (document vault + profile)". Effectively 2 surfaces. |

**Agreement**: chat is the persistent root. Dashboards die. Dossier/Profile is a secondary surface, not a tab.
**Disagreement**: IA wants a **visible second tab called Monde** for people who refuse to chat. The Strategist and Nav Engineer effectively say "just chat, everything else opens over it". UX sits in the middle.

**What's at stake**: if you ship chat-only (Strategist/Nav), users who are allergic to chatbots have zero entry point. If you ship 2 tabs (IA), you re-introduce the thing everyone is trying to kill — a catalog called "Monde". The IA tries to hide the catalog behind life-event wording but it's still a catalog. Neither side validated this with users.

### A.2 Screen count

| Expert | Target count |
|---|---|
| **IA** | ~55 routable surfaces + 18 life-event hub templates + shell pieces. Effectively ~55 code-level screens, ~95 → ~55. |
| **UX Senior** | Not quantified. Focus is on killing facades, renaming Explorer, fixing back button. |
| **Nav Engineer** | No target. Reuses all ~90 tools under `/app/`. Phase 3 deletes "a few dead screens". |
| **Strategist** | **26 screens**. 23 user-facing + 3 reserved. 95 → 26. |

**Agreement**: the current 95 is too many.
**Disagreement**: factor of **2x** between IA (~55) and Strategist (26). Nav Engineer implicitly keeps ~90.

**What's at stake**: the Strategist's 26 requires **writing 5 brand-new "Unified" mega-screens** (Decision Canvas, Life Simulator, Protection Gap, Prévoyance Planner, Housing Decision) that don't exist today. Those are 5 net-new features disguised as consolidation. The IA's 55 keeps existing screens and relocates them, which is cheaper but doesn't actually fix the "one product, one voice" problem the Strategist is trying to solve. Nav Engineer says "do nothing, fix the router". They are not comparable plans.

### A.3 Specific screen kills

Where all four (implicitly or explicitly) agree to kill:
- `achievements_screen` (anti-shame doctrine)
- `cantonal_benchmark_screen` (no social comparison)
- `ask_mint_screen` (duplicates coach chat)
- `score_reveal_screen` (gamification)
- `budget_container_screen` (LOOP-01 facade)
- `retirement_dashboard_screen` (dashboard framing contradicts identity)
- `portfolio_screen` (out of scope)

Where they disagree:
- **`timeline_screen`**: IA defers to v2. Strategist kills with prejudice. UX and Nav silent.
- **`gender_gap_screen`**: IA relocates as a tool. Strategist kills it as "segmentation by gender is a lecture". This is a voice/ethics call masquerading as an IA call.
- **`provider_comparator_screen`**: IA kills for LSFin risk. Nav Engineer keeps it in Phase 2. Strategist kills.
- **`frontalier` / `expat` / `independant` screens**: IA relocates as life events. Strategist kills outright ("archetype modifies every chat response, not a sidebar section"). These are load-bearing for real users — frontaliers are 340k Swiss residents. Killing the dedicated screen is a defensible UX call but an indefensible content-strategy call if the chat can't reliably produce the same depth.

### A.4 Budget loop fix

All four agree the facade must die. The disagreement is on replacement:
- **IA**: Budget becomes a Tool opened from Monde > Commencer > Mon budget (Hero Plan template).
- **UX**: Budget card opens a **bottom sheet** with 3 inputs.
- **Nav**: Delete facade, route `/app/budget` to the orphaned `BudgetScreen` directly.
- **Strategist**: Same as Nav — delete facade, keep BudgetScreen.

**What's at stake**: the UX Senior's bottom sheet answer is actually the simplest and the only one that closes the loop end-to-end (card → sheet → data committed → back to chat with new Budget B anchor). The other three assume `BudgetScreen` is fit for purpose. **None of them read `BudgetScreen`** to check if it actually collects data or if it's just a second facade under the first one.

### A.5 Migration timing

| Expert | Timing |
|---|---|
| **IA** | "Phase 1, not Phase 2" — wants chat-first shell shipped before polish. No day count. |
| **UX Senior** | Explicit 2-week sprint, 6 tickets, ordered. |
| **Nav Engineer** | Phase 1 = 1-2 days (critical fixes). Phase 2 = 3-5 days (shell refactor). Phase 3 = 1-2 weeks (consolidation). |
| **Strategist** | Not specified. "Next deliverable should be a kill ticket list." |

**Agreement**: Phase 1 is "fix the loop, fix safePop" — a few days at most.
**Disagreement**: whether Phase 2 onwards is 1 week (UX) or 1 month (IA/Strategist if you're honestly rebuilding 5 Unified screens + a Monde taxonomy). The Nav Engineer is the only one who priced the work.

### A.6 Mental model sentence

- **IA**: "MINT is the voice in my pocket that protects me before I sign something I'll regret."
- **UX**: "MINT, c'est une conversation calme avec quelqu'un qui connaît le système suisse et qui prend ton parti..."
- **Strategist**: "MINT is a calm, pocket-sized Swiss intelligence that translates any financial document, decision, or life event into plain-language implications — before you sign, not after."
- **Nav Engineer**: silent on voice.

All three non-silent versions orbit the same idea. The UX version is the longest and the most testable ("tu parles, je traduis"). The IA version is the shortest and the most marketing-ready. The Strategist version is the most compliance-safe. **There is no disagreement on substance, only on sentence length**.

---

## Deliverable B — 10 critical questions the experts FAILED to address

### B.1 What is the usage distribution across the 95 screens today?

**Why they didn't ask**: three of them were operating from doctrine, not data. The Strategist kills `achievements_screen` because of anti-shame doctrine. Fair. But what if analytics show it's the second most-opened screen in the app? Then killing it is a P0 retention event dressed as doctrine.
**What could go wrong**: you delete the only screen 30% of users actually open, retention drops, you blame the chat for not "replacing" achievements, and you rebuild it in 6 weeks under a different name.
**Evidence needed**: MixPanel / Segment / Firebase Analytics / any event log showing per-screen MAU for the last 30 days. If MINT has **zero usage data**, that is itself a P0 finding the experts should have led with.

### B.2 What happens to TestFlight users when you delete 65 screens?

**Why they didn't ask**: none of the experts mentioned TestFlight once. The MEMORY.md context says `TestFlight: operational on macos-15 runner`. There are beta users on the current build.
**What could go wrong**: you ship a new build with the new router. An existing user has a conversation thread with a `ResponseCard` whose `cta_route` is `/achievements`. On resume, the router errorBuilder fires. In the best case, you see `_MintErrorScreen`. In the worst case, the notification deep link `mint://achievements` is in an Apple push buffer and the user taps it from Notification Center. App opens → error → user force-quits → session lost.
**Evidence needed**: (a) crash logs from Sentry/Crashlytics on Phase 1 of the refactor; (b) a mechanical audit of every persisted `cta_route` in conversation history storage; (c) server-side push notifications that reference deleted routes.

### B.3 Does chat-first work for ANONYMOUS users?

**Why they didn't ask**: three of them assumed Persona 1 has always-on local state. But the UX walkthrough says "no signup wall", which means Camille is anonymous. An anonymous user has no CoachProfile. The 4-layer engine needs profile data. The silent opener needs `age + canton + income` which requires at least local persistence. What's the Swiss privacy stance on local-only profile writes without consent?
**What could go wrong**: anonymous flow ships. First 3 inputs are stored locally (no server). User reaches Premier Éclairage. User force-quits. Reopens. Everything is gone — you assumed `SharedPreferences` works, but App Tracking Transparency or a privacy sandbox reset wiped it. Shame moment. Churn. Worse: you stored it server-side without consent → nLPD violation.
**Evidence needed**: (a) explicit decision on anonymous persistence strategy; (b) legal review of nLPD/FINMA stance on anonymous profiling; (c) recovery path when local profile is lost.

### B.4 What happens when Claude (the LLM) returns a tool_call to a killed screen?

**Why they didn't ask**: the experts talk about navigation in isolation from the AI. But the MEMORY.md says "Claude Sonnet LIVE on staging + production with tool calling". The coach emits structured tool calls that include route names. The server-side prompt tells Claude what tools exist.
**What could go wrong**: you delete `cantonal_benchmark_screen`. Claude has been fine-tuned / prompted with a tool `navigate_to_cantonal_benchmark`. On the Friday after the deploy, Claude emits that tool call. Frontend has no handler. Chat thread shows a broken card. User taps → error screen. Compliance guard didn't catch it because the prompt was legal, just the route was dead.
**Evidence needed**: full audit of the Claude system prompt in `claude_coach_service.py` + every tool schema that references a route name + a mechanical CI check "no tool references a killed route". None of the experts mentioned this file.

### B.5 How does the 4-layer engine work for a user who hasn't scanned a document?

**Why they didn't ask**: the Strategist explicitly frames MINT as "document-first". The 4-layer engine is beautiful when applied to a real PDF. But for a user who opens the app without a certificate LPP, there is no fact to translate. The silent opener produces a fake "first number" from 3 inputs, which is **estimated data at confidence 0.25**. Applying a 4-layer translation to estimated data produces a 4-layer translation of a guess.
**What could go wrong**: you promise "fact → translation → implication → question to ask". You deliver "guess → over-confident translation → irrelevant implication → question to ask nobody". The user, being Swiss and suspicious, notices. Trust is burned in minute 2.
**Evidence needed**: a hard rule on when the 4-layer engine is allowed to fire and when it must fall back to "je ne peux pas encore te traduire ça, j'ai besoin de X". None of the experts specified this. The IA calls this "Premier Éclairage" but doesn't say what data quality is required to produce one honestly.

### B.6 Android. Full stop.

**Why they didn't ask**: every persona is `on the tram with iOS`. Every UX walkthrough assumes an iPhone. The Nav Engineer talks about "iOS swipe-back" and "Android system back" but all three others are silent. The app ships on both.
**What could go wrong**: Android back button semantics differ from iOS swipe. `WillPopScope`/`PopScope` behavior on the persistent chat shell is non-trivial. If back from chat doesn't exit the app on Android, Android Q+ gesture nav starts behaving weirdly. Play Store review flags "back button broken". Google pulls the app.
**Evidence needed**: explicit Android back-button decision tree. The Nav Engineer started one in §A.4 but didn't finish it. Manual test on Android Q, R, S, T devices.

### B.7 What about the existing 8137 Flutter tests?

**Why they didn't ask**: all four wrote as if the app had no tests. MEMORY.md says `8137 Flutter tests + 4755 backend tests = 12'892 total, all green`. Deleting 65 screens means deleting ~1500 tests. Merging 5 Unified screens means rewriting ~1000 more. Nav Engineer's §E says "expect 0 regressions" — that's optimism, not a plan.
**What could go wrong**: test count drops from 8137 to 6000 overnight. Coverage report looks like a crater. Nobody notices the 40 regressions hiding in the 2000 deleted tests because the test names no longer exist.
**Evidence needed**: a migration matrix of "which tests are expected to die" vs "which tests must still pass on the new routes", produced BEFORE any code change.

### B.8 Has anyone validated chat-first with SWISS users specifically?

**Why they didn't ask**: the Strategist cited Cleo as the model. Cleo is anglo-American, young, casual, overdraft-selling. MINT's Swiss segment skews older (18-99 per CLAUDE.md), higher-trust-threshold, less chat-comfortable. The regional-voice section in CLAUDE.md §6 says "Suisse Romande: dry humor" but a 62-year-old Vaudois tapping into a chat interface to talk about his 2e pilier is not an empirically validated interaction.
**What could go wrong**: you ship chat-first. Valais farmers and Zurich insurance agents try it once, bounce, never return. Retention curve collapses. You didn't test because the experts said "Cleo proved it". Cleo proved it in the UK for 18-25-year-olds with overdrafts. Different universe.
**Evidence needed**: 5 moderated usability sessions with Swiss users 40+, in Romand and Alémanique, using a chat-first prototype. Not a figma, a working prototype. None of the experts suggested this.

### B.9 How does the "Unified" screen concept survive compliance?

**Why they didn't ask**: the Strategist proposes 5 Unified mega-screens (Decision Canvas, Life Simulator, etc.) each of which must handle 4-8 distinct compliance domains. A Unified Life Simulator that handles divorce + death + marriage + first job + unemployment + expatriation is 6 different LSFin/LIFD/LAVS contexts in one codebase. Compliance guard rules differ per event (e.g. divorce triggers split pension rules, death triggers succession rules). Merging screens without merging compliance logic is a CVE waiting to happen.
**What could go wrong**: Unified Life Simulator ships. A user selects "divorce" then mid-flow switches to "décès d'un proche". State bleeds. Compliance rules from divorce (CO art. X) persist into succession (CC art. Y). Output is legally wrong. Lauren (FATCA) triggers US-specific rules and the Unified screen hasn't archetype-gated them.
**Evidence needed**: a compliance matrix per Unified screen showing which rule set fires for which sub-event. None of the experts produced one. The Strategist's "merge them all" is attractive on an org chart and horrifying in a compliance audit.

### B.10 What does the user DO when the chat is offline or rate-limited?

**Why they didn't ask**: the Strategist/IA treat chat as always-available. But MINT uses Claude API on Railway with ANTHROPIC_API_KEY. Anthropic has rate limits. Railway has uptime. In the chat-first model, **if the chat is down, the app is down**. There is no Monde tab to browse.
**What could go wrong**: Anthropic has a 90-minute outage (has happened in 2025). Every user opening MINT sees "chat is thinking..." forever, or an error, or the fallback template answers which are generic and don't feel like MINT. In a 4-tab shell, users could still browse hubs. In a chat-first shell, they see a broken app.
**Evidence needed**: an explicit degraded-mode plan. "When chat is unavailable, what's the second surface?" The Nav Engineer's ShellRoute is fine; the product answer is missing.

---

## Deliverable C — 5 "show me the data" challenges

### C.1 Strategist: "Killing 65 screens won't lose any meaningful user feature"

**Evidence needed**:
- Per-screen MAU and session count from the last 30 days.
- Drop-off funnel: of users who land on `achievements_screen`, what % complete a session vs bounce?
- Conversation tree analysis: of all `cta_route` values ever emitted by Claude in production, how many point to screens in the KILL list? If >5%, those kills are breaking live conversation history.

**If we can't answer**: the kill list is aspirational, not evidence-based. Reduce the scope of Phase 1 deletions to the 7 screens that are either facades or contradicted by doctrine (achievements, score_reveal, cantonal_benchmark, ask_mint, portfolio, budget_container, retirement_dashboard) — that's 7, not 65. The other 58 stay until we have usage data.

### C.2 IA: "2 tabs (Coach + Monde) cover 100% of use cases"

**Evidence needed**:
- Session tab-switch frequency. If users open the existing 4-tab shell and dwell on one tab 90% of sessions, the IA's 2-tab claim is probably right. If tab-switches are frequent, users are treating tabs as real destinations and collapsing them to 2 is a regression.
- User interviews asking "where would you look for X?" where X = "my 3a status", "my retirement projection", "my last scanned document". If users map all 3 to "the chat", IA is right. If they map to separate surfaces, they want tabs.

**If we can't answer**: the 2-tab claim is IA theology. Keep a minimum of 3 surfaces (Chat, Explore-or-whatever, Profile-drawer) until disproven.

### C.3 UX Senior: "Returning users pay a tax of 1 tap per session. Don't charge it."

**Evidence needed**:
- Session-2 funnel: what % of users who install reach session 2? What % of session-2 openers spend >10s on Landing before advancing?
- Skip-landing A/B test: ship both, measure session length delta.

**If we can't answer**: the "Today surface" proposal is a reasonable hypothesis, not a proven win. Cleo ships landing on chat cold-open. Wise ships landing on balance. Both are correct for their own users. Don't assume MINT is one or the other.

### C.4 Nav Engineer: "LOOP-01 is a P0 that's trapping users today"

**Evidence needed**:
- Session duration histograms. Look for the telltale bimodal signature: sessions that end cleanly + sessions that end in a loop (user force-quits after N rapid navigation events).
- Sentry/Crashlytics filtered on navigation events leading into `budget_container_screen`.
- Support tickets mentioning "budget" or "boucle".

**If we can't answer**: the loop is real code but the severity is unknown. The fix is still cheap (delete facade, 1 day) so it doesn't matter if it's P0 or P3. Just do it. But don't let it dominate the narrative — the loop might be hitting 2% of sessions or 40%, and that matters for how the rest of the plan is prioritized.

### C.5 All four: "Facades must die"

**Evidence needed**:
- Mechanical scan: any screen with <80 LOC and a single button is suspect. The UX Senior named this rule explicitly. Run a real grep:
  ```
  rg -c "class \w+Screen extends" apps/mobile/lib/screens/ | awk -F: '$2<80'
  ```
- Cross-reference against the 21 `safePop` call sites. Any overlap is almost certainly a facade.

**If we don't do this**: "delete facades" is a slogan. The only confirmed facade is `budget_container_screen`. The experts assume "suspect others" exist. Prove it mechanically before spending a sprint on it.

---

## Deliverable D — 5 unresolved tensions (with decision frameworks)

### D.1 Tension: 2 tabs vs 5 Unified flows vs chat-only

**IA**: 2 tabs (Coach + Monde) + drawer.
**Strategist**: chat + 5 Unified flows + document vault.
**Nav Engineer**: 1 ShellRoute with chat root. No tabs.
**UX**: 3ish surfaces (Chat + Today + search-first Explorer).

**Framework for resolution**:
1. Is there a usage signal in the next 48 hours you can collect? (Add a one-line analytics event, wait a day.) If yes → decide from data.
2. If not: what's the **rollback cost**? Ship the version that is cheapest to undo. Nav Engineer's single ShellRoute is the cheapest to undo because `StatefulShellRoute.indexedStack` is a drop-in upgrade (see §E of their spec). IA's 2-tab is cheap-ish. Strategist's 5 Unified flows is a **one-way trip** — once you've deleted 12 simulators and merged them into 1, coming back is 3 sprints.
3. Pick the shell with the highest **optionality**, not the one with the strongest narrative. That's Nav Engineer's Phase 2 ShellRoute, not Strategist's Unified flows.

**Suggested decision**: ship Nav Engineer's ShellRoute in week 1. Keep all existing tool screens alive under `/app/*`. Decide chat-only vs 2-tab in week 3 after collecting real usage.

### D.2 Tension: Monde tab vs search-first Explorer vs "no browse surface at all"

**IA**: Monde with 6 life-coded domains.
**UX**: Search input + 8 intent chips, hubs secondary.
**Strategist**: no browse surface. Everything chat-invoked.

**Framework for resolution**:
1. Test with non-chatters. Find 3 users who explicitly refuse to interact with AI chat (they exist, especially 50+). Show them each variant as a paper prototype. The one that gets "ok I'd actually use this" wins.
2. Default: if you can't test, ship the search-first variant (UX's). It degrades gracefully to the IA's Monde if you add default chips, and it degrades gracefully to the Strategist's chat-only if you set the empty-state to "ask me anything".

**Suggested decision**: UX Senior's search-first, with chips. It's the only variant that is not load-bearing on a content taxonomy that doesn't exist yet.

### D.3 Tension: Kill dedicated life-event screens vs keep them

**IA**: relocate to `Monde > domain > event`. Keep them as templated Roadmap Flows.
**Strategist**: merge all into one Unified Life Simulator. Kill the individual screens.

**Framework for resolution**:
1. Does each life event have **domain-specific compliance logic** that differs from the others? Yes (divorce → CO art. X, death → CC art. Y, marriage → LIFD art. Z). Merging screens with different compliance footprints is riskier than keeping them separate.
2. Does each life event have **domain-specific UI affordances**? Probably yes (divorce needs a partner invite flow, death needs a heritage calculator, marriage needs a joint-tax toggle). Merging means either losing these or building a complicated switch-case UI.
3. Default: keep the screens, merge only if a user test shows users can't tell them apart. Otherwise you're refactoring for developer elegance at the cost of compliance safety.

**Suggested decision**: IA's relocate-but-keep wins on compliance + execution risk. The Strategist's "Unified Life Simulator" is 4 sprints of work and 1 legal review that nobody budgeted.

### D.4 Tension: Silent opener vs greeting vs Today surface

**IA**: chat with Cap du jour at top of scroll.
**UX Senior**: silent opener for first session, Today surface for returning users.
**Strategist**: chat-first, no dedicated home.
**Nav Engineer**: silent on content.

**Framework for resolution**:
1. Session 1 and session N+1 are different problems. The silent opener is correct for session 1 (cold, anonymous). The Today surface is correct for session N+1 (warm, memory of last session).
2. The IA's Cap du jour conflates them into one surface. That's one design that partially works for both and fully works for neither.
3. Default: UX's two-state answer. Branch on `hasActiveProfile() && lastSessionDate != null`. Two code paths, one screen.

**Suggested decision**: UX Senior's split-mode. This is the only one that handles both cold-start and return-user without compromise.

### D.5 Tension: Anonymous persistence strategy

**All four**: assume it works. None said how.

**Framework for resolution**:
1. Does Swiss nLPD + FINMA require explicit consent for any data stored, even device-local? Answer: no, local-only is fine, but persisting across reinstalls requires keychain or server, which triggers consent.
2. What happens when a user uninstalls and reinstalls? Local profile is gone. The "MINT remembers you" promise breaks silently.
3. Default: the only honest model is **local-only with explicit "create an account to keep this" CTA after the first Premier Éclairage**. No anonymous server-side persistence.

**Suggested decision**: document this explicitly. Ship the anonymous flow with a hard rule: local SharedPreferences only, cleared on uninstall, with a one-line "fais-moi un compte si tu veux retrouver ça sur un autre appareil" after the first value moment. Not after login wall at install.

---

## Deliverable E — What could go catastrophically wrong

If the user adopts ALL the experts' recommendations and ships in 2 weeks, here are the five worst outcomes.

### E.1 TestFlight users hit dead routes on app resume

**Probability**: HIGH.
**Impact**: BAD (not catastrophic — it's a beta cohort).
**Root cause**: persisted conversation cards emit `cta_route` values pointing at killed screens. No mechanical audit of persisted state was performed.
**Mitigation**: before Phase 3 deletions, run a migration that rewrites stored `cta_route` values from killed routes to `/app/chat?prompt=<original>`. Add a router-level fallback that never errorBuilds on an unknown `/app/*` path — it redirects to chat with a toast "cette page a été retirée".

### E.2 Claude emits tool_calls to deleted routes

**Probability**: MEDIUM-HIGH.
**Impact**: BAD. User sees broken cards in live conversations.
**Root cause**: `claude_coach_service.py` has route references in prompts/tools that weren't updated in lockstep with the Flutter kill list.
**Mitigation**: introduce a shared `ROUTE_REGISTRY` JSON as source of truth, read by both backend (prompt builder) and Flutter (router). Any route change must update the JSON. Add a CI check: backend prompt strings cannot reference routes not in the registry.

### E.3 Chat-first is a Swiss user mismatch

**Probability**: MEDIUM.
**Impact**: CATASTROPHIC if it's true. 40-60% of installs bounce after session 1 because they expected a dashboard and got a chatbot.
**Root cause**: no user testing with non-chatter Swiss demographics before shipping.
**Mitigation**: keep a fallback "Explore" surface reachable in ≤2 taps. Instrument a metric: session-1 completion where `chat_input_count == 0`. If this cohort is above 30%, the chat-first model is failing for a meaningful slice.

### E.4 Unified screens ship with a compliance bug

**Probability**: MEDIUM if Strategist's plan adopted, LOW otherwise.
**Impact**: CATASTROPHIC. A Swiss fintech shipping wrong legal output is a FINMA letter, not a bug report.
**Root cause**: merging 6 life events into one UI means merging 6 rule sets. Edge cases compound.
**Mitigation**: don't ship Unified screens in week 1-2. If you want them, build one (Decision Canvas is the safest — it's purely a compare widget) and ship it behind a feature flag. Validate with the Golden Couple test harness (Julien + Lauren) before exposing.

### E.5 Anonymous users lose their profile on reinstall / OS clear

**Probability**: MEDIUM.
**Impact**: BAD. The "MINT remembers you" promise is the emotional core; breaking it silently is a trust event.
**Root cause**: no documented persistence model, no degraded-mode UX.
**Mitigation**: explicit "create an account to save this" moment after the Premier Éclairage, framed as a gift, not a wall. Silent restoration from keychain on reinstall if the user opted in.

---

## Deliverable F — 3 right, 3 wrong

### Got right

1. **The Budget loop is the canary in the coal mine, and all four flagged it.** This is not a navigation bug — it is the architecture saying out loud "this screen should not exist". Every expert saw this, every expert flagged it. The codebase diagnosis is sound.
2. **`safePop` → `/coach/chat` is a lie.** The Nav Engineer's critique of it (§A.4, anti-pattern #4) is surgical and correct. The fact that 21 screens all fall back to chat is proof that the router is a chat-centric monolith with no mental model. Replacing it with `MintNav.back(fallback: ...)` is a type-safe win.
3. **The Identity document is 10/10 and the code is 5/10** (Strategist's phrasing). This is the most honest line in all four docs. The product writing is world-class. The execution is not aligned with it. Closing that gap is the whole job.

### Got wrong

1. **None of them demanded usage data before proposing a kill list.** Doctrine-driven product decisions in a live app with beta users is malpractice. The Strategist's "69 screens die with prejudice" would be criminal without a single analytics query to back it. This is the single biggest blind spot across all four docs.
2. **None of them costed the backend/AI impact.** Deleting screens is a frontend task. But the route names live in Claude prompts, in server-side push notifications, in email templates, in openapi contracts. The Nav Engineer mentions `tools/openapi/` once ("nothing to update") which is probably wrong — `ScreenRegistry` is referenced in contextual engines (`contextual_detector`, `life_event_router`) and those feed Claude's system prompt. The refactor has a much bigger blast radius than any expert acknowledged.
3. **All four wrote for iOS.** Every persona, every walkthrough, every animation reference is iOS-coded. The app ships on Android. The back button, the bottom sheet behavior, the system navigation bar, the keyboard overlay — all differ. Shipping a 2-week refactor that only works properly on iPhone is a Play Store review rejection or a 1.5-star rating spiral.

---

## Deliverable G — What the user should actually DO this week

Not in 2 months. This week. Concrete, sequenced, surgical.

### Day 1 (Monday) — Evidence gathering, not code

- **Run a mechanical audit** of the 95 screens by LOC + imports. Any screen <80 LOC with one button is a facade candidate. Grep for `_calculate` in services to catch duplicate logic.
- **Pull analytics** (if any). If there is **zero usage data**, that is itself the finding of the week: you cannot make doctrine-driven kill decisions without instrumentation. Add a one-line event emitter to the router: `GoRouter.of(context).routerDelegate.addListener` → log route + timestamp. Deploy as a one-file PR. Wait 24 hours.
- **Grep the backend** (`services/backend/app/`) for every string that looks like a route (`/coach/chat`, `/retraite`, etc.). Compile a list of routes referenced server-side. Cross-reference with the kill list.
- **Grep `claude_coach_service.py`** for tool schemas that reference route names. Same cross-reference.
- Outcome of day 1: a **blast radius document** — what breaks on the backend / in Claude's tools if you delete route X?

### Day 2 (Tuesday) — Phase 1 of Nav Engineer's plan. Stop the bleeding.

- Implement `MintNav` (Nav Engineer §B). Create `mint_nav.dart`. Deprecate `safe_pop.dart`.
- Create `preserving_redirect.dart`. Patch the 40 redirects in `app.dart` to preserve query params.
- **Delete `budget_container_screen.dart`.** Wire `/budget` to the orphaned `BudgetScreen` OR build the UX Senior's bottom-sheet inline collector — whichever is cheaper to test.
- Run `flutter test`. Expect zero regressions. If there are regressions, the test suite was hiding something.
- Commit as one small PR. Ship to TestFlight.
- Outcome: LOOP-01 dead, NAV-01 dead, zero feature changes, router is no longer lying.

### Day 3 (Wednesday) — User testing of the kill list

- Find 3 users (ideally including one non-chatter 45+). 30 minutes each.
- Show them the current app with a moderator script: "Where would you look to understand your 3a?", "Where would you look to see your retirement number?", "How would you import your LPP certificate?"
- Record the gap between their mental model and the current IA. **This is the data the experts should have had.**
- Outcome: a 1-page memo documenting what users expect. This memo beats the four expert docs.

### Day 4 (Thursday) — Decide the shell

- With the day-3 data and the day-1 blast radius document, pick one of:
  - **Option A (conservative)**: Nav Engineer's single `ShellRoute` wrapping all existing screens, no deletions. Ship this. Collect 2 weeks of data. Decide shell shape later.
  - **Option B (moderate)**: A + kill the 7 doctrinally-indefensible screens (achievements, score_reveal, cantonal_benchmark, ask_mint, portfolio, retirement_dashboard, budget_container). No Unified screens. No 2-tab commitment.
  - **Option C (ambitious)**: B + IA's 2-tab Coach + Monde shell, where Monde is the UX Senior's search-first surface with 8 chips. Six-domain taxonomy deferred.
- Do NOT pick Strategist's option (26 screens, 5 Unified flows) this week. It's a 6-week project, not a 2-week one, and it has unaudited compliance risk.

### Day 5 (Friday) — Cross-stack audit

- Update `claude_coach_service.py` tool schemas to match the new route registry. Route registry becomes the source of truth in `shared/route_registry.json`.
- Add a CI check: backend cannot reference routes not in the registry, Flutter cannot reference routes not in the registry.
- Add a router-level fallback: any unknown `/app/*` path redirects to `/app/chat?prompt=<original-path>` with a toast. This is the safety net for persisted `cta_route` values pointing at killed screens.
- Manual smoke test on Android (Pixel, Samsung), iOS (iPhone SE, iPhone 15). Back button, deep links, cold start, notification tap.
- Outcome: the Phase 1 router refactor is shippable to production. Everything else (kill list, Unified screens, Monde taxonomy, voice tuning) is a future sprint with real data to guide it.

### What NOT to do this week

- **Do not** delete 65 screens.
- **Do not** rename `Explorer` to `Monde`.
- **Do not** build a Unified Decision Canvas.
- **Do not** ship a silent opener rewrite.
- **Do not** publish a new mental-model sentence.
- **Do not** commit to a chat-first-only architecture before the user tests on Wednesday.

All of these can happen later. None of them can happen responsibly this week.

---

## Closing — the one thing the four experts missed

All four of them wrote from the inside of MINT's own identity document. That document is gospel, and they converged on "chat-first Cleo-Swiss". But the identity document is a **hypothesis**, not a validated truth. The experts treated it as the conclusion and worked backwards to navigation.

A principal engineer's job is to treat the identity document as a prior and the code as evidence and the users as the arbiter. The evidence (95 screens, 21 `safePop` calls, the Budget loop) says the team tried to build chat-first and couldn't close the loop. The arbiter (users) has not spoken, because no one has asked them.

**Ship the Nav Engineer's Phase 1 this week. It's the only work that is uncontested, low-risk, and that buys time to learn the rest.**

Everything else — the 2-tab shell, the kill list, the Unified flows, the Monde taxonomy — is theology until you have data. Theology makes good slide decks and bad apps.

---

*End of devil's advocate review. The next document should be a one-page decision memo from the founder picking A/B/C for day 4.*
