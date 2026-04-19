# Feature Landscape — v2.8 "L'Oracle & La Boucle"

**Domain:** Workflow / operational gestures for a one-person Swiss fintech team
**Framing:** Zero new product feature. "Features" here = the operational gestures (ceremonies, rituals, process, tooling) that top SF fintechs use to avoid MINT's current state (388 silent catches, dead anonymous flow despite screen shipped, save_fact desync, 23 legacy redirects, accents dropped by agents).
**Researched:** 2026-04-19
**Confidence:** MEDIUM-HIGH overall. Operational gestures are well-documented across Stripe / Linear / Monzo / Cleo / Ramp engineering blogs and conference talks; specific stack choices (Sentry Replay Flutter, lefthook, GoRouter middleware) verified against current versions.

Grounding numbers from codebase scan:
- `apps/mobile/lib/app.dart` → **147 GoRoute declarations**, **52 redirect: callbacks** (target: sunset 23 legacy)
- `tools/checks/` → **12 existing mechanical gates** (landing, confidence, chiffre_choc, WCAG, FK, etc.)
- `lib/services/feature_flags.dart` → **8 live flags** + server override via `/config/feature-flags`
- **388 bare catches** (332 mobile + 56 backend) catalogued
- Sentry wired both sides, sample 10%, Replay NOT yet enabled
- `tools/e2e_flow_smoke.sh` = 60-line curl-based E2E proof that UUID/save-fact/coach-citation all round-trip (extend this, don't replace)

---

## Overview — The 6 Phases Map

| Phase | Gesture family | Why it exists | Kill condition |
|-------|---------------|---------------|----------------|
| 31 Instrumenter | Observability as oracle | Know in <60s what broke, for whom, on which route | Any finding today requires >60s to diagnose = phase not done |
| 32 Cartographier | Living screen board | 147 routes = unknown territory unless they have a status | Any route in `app.dart` absent from `/admin/routes` |
| 33 Kill-switches | Route-level flags + circuit breakers | Broken feature must never reach user; auto-off on error spike | Any user-visible route still shipping errors without a flag |
| 34 Agent Guardrails | Pre-commit + proof-of-read | Agents hallucinating ≠ acceptable; local feedback <5s | Any agent can commit without reading CLAUDE.md or citing touched lines |
| 35 Boucle Daily | Scripted 10-min dogfood | Drift happens silently; daily ground-truth cheap | Any day with no dogfood artifact in `.planning/dogfood/` |
| 36 Finissage E2E | Catalogued P0s + 388 catches | Closing the debt from Wave E-PRIME audit | Any P0 from PROJECT.md §Codebase State unfixed |

**Phase dependency graph (critical path):**
```
31 Instrumenter ─┬─► 32 Cartographier (needs Sentry data for board status)
                 ├─► 33 Kill-switches (needs error rate for auto-off)
                 └─► 35 Boucle Daily (needs Replay + breadcrumbs for dogfood)

34 Guardrails ────► 36 Finissage (guardrails protect the fixes from regressing)

33 Kill-switches ─► 36 Finissage (388 catches fix requires ability to kill what breaks)
```

Phase 31 is the taproot. 34 is parallelisable with 31. 36 is last but benefits from all.

---

## A. Phase 31 — Oracle (Observability)

### A.1 Table stakes (MUST ship v2.8)

| # | Gesture | Complexity | Deps | Fintech precedent |
|---|---------|------------|------|-------------------|
| A1 | **Sentry Replay Flutter** enabled, `sessionSampleRate: 0.1`, `onErrorSampleRate: 1.0`, with **mask-all-text + mask-all-images default** (privacy-by-default, cannot be opt-in) | MED | Existing Sentry SDK | **Monzo** — documented Replay adoption 2024 with strict PII masking; **Cleo** — uses Sentry Replay for chat-first debugging |
| A2 | **Breadcrumb taxonomy** — 4 canonical breadcrumb categories: `tap` (widget-key), `screen-enter` (route-name), `api-error` (status + endpoint), `tool-call` (coach tool_use name). Auto-injected via `NavigatorObserver` + `ApiService` interceptor | LOW | None | **Stripe** — "Canonical log lines" post (Brandur Leach); one line per request, consistent keys |
| A3 | **`trace_id` round-trip mobile→backend** — mobile generates UUID per user-action, sent as `X-Mint-Trace-Id` header, backend echoes into structured logs + Sentry tag. Click in Sentry mobile → jump to backend trace | MED | Backend middleware + mobile interceptor | **Stripe** `Request-Id` header convention; **Ramp** published similar `x-ramp-request-id` pattern |
| A4 | **Global error boundaries — fail-loud** — Flutter: `FlutterError.onError` + `PlatformDispatcher.onError` → Sentry capture **AND** visible toast in staging builds (`kDebugMode \|\| kStagingMode`). Backend: FastAPI `exception_handler` on `Exception` → 500 JSON with `trace_id`, never silent | LOW | None | **Linear** — "loud errors in staging, silent + captured in prod" (engineering blog) |
| A5 | **Catch-audit lint** — `tools/checks/no_bare_catch.py` + `no_bare_except.py` — bans `catch (_) {}`, `catch (e) {}` without logging, `except Exception: pass`. Allowlist file for legitimate retries. CI gate blocking | MED | Existing `tools/checks/` pattern | **Ramp** — published "no silent catches" engineering principle; **Brex** Python linter bans `except: pass` |

### A.2 Differentiators (nice-to-have, descopable)

| # | Gesture | Complexity | Deps | Fintech precedent |
|---|---------|------------|------|-------------------|
| A6 | **Sentry Release Health** — crash-free session % tracked per release, dashboard showing v2.8.x vs v2.7.x regression | LOW | A1 shipped | **Monzo**, **N26** standard |
| A7 | **Performance budget per route** — Flutter: first-frame + TTI spans via `SentryNavigatorObserver`; budget table in `.planning/PERF_BUDGETS.md` (e.g. `/home` TTI < 1.5s p95, `/coach/chat` cold < 2s) | MED | A1 + A2 shipped | **Stripe Atlas** publishes per-route Core Web Vitals targets |
| A8 | **Custom spans on 4 critical LLM calls** — `coach.chat`, `vision.extract`, `document.classify`, `rag.retrieve` each wrapped in `Sentry.startTransaction`, with tags `model`, `token_budget_used`, `cache_hit` | MED | A1 shipped | **Cleo** — Sentry performance for LLM calls; **Perplexity** published similar span strategy |

### A.3 Anti-features (explicitly DO NOT build)

| Anti-feature | Why avoid | Instead |
|--------------|-----------|---------|
| Session replay unmasked for sensitive fields | nLPD violation; any salary/IBAN/LPP avoir visible in Replay = breach | `maskAllText: true`, `maskAllImages: true`, allowlist only explicit non-PII widgets (buttons, nav) via `SentryMask.widget` |
| Opt-in PII masking | Default-off = breach waiting to happen | Default-on, code-review gate for any `SentryUnmask` annotation |
| Datadog RUM / Amplitude / PostHog alongside Sentry | 3× vendor surface + nLPD DPA × 3 + source-of-truth drift | Sentry-only for v2.8 (decision logged in PROJECT.md) |
| OpenTelemetry full stack | Nice-to-have, 2-3 weeks of yak-shaving for one person | Deferred v2.9+ |
| Per-user analytics dashboards | No cohort management, no product team to consume | Aggregate-only |

### A.4 Ceremony

- **Weekly 10-min Sentry triage** (Monday): Julien opens Issues tab → groups sorted by users affected → top 3 triaged (fix / flag / ignore with reason). Artifact: append to `.planning/sentry-triage/YYYY-WW.md`. Precedent: **Stripe** "weekly alert review" ritual.

---

## B. Phase 32 — Cartographier (Screen Board)

### B.1 Table stakes

| # | Gesture | Complexity | Deps | Fintech precedent |
|---|---------|------------|------|-------------------|
| B1 | **1 route = 1 card** — `/admin/routes` lists all 147 GoRoute entries. Each card: `path`, `screenName`, `last Sentry error (ts + count 7d)`, `flag associated` (from feature_flags.dart), `owner` (git blame top contributor), `status ∈ {green, yellow, red, dead}`, `thumbnail` | MED | Phase 31 A1 (Sentry events), route source-of-truth | **Linear** — internal "feature map" board; **Stripe** has a "Route Health" internal tool (Railsconf 2019 talk) |
| B2 | **Auto-generation from GoRouter source** — script `tools/gen_route_manifest.dart` parses `app.dart` AST, emits `tools/route_manifest.json`. CI gate: manifest matches source. No hand-maintained list | MED | GoRouter source + `analyzer` pkg | **Monzo** — generated route list from Jetpack Navigation XML; they reject hand-maintained inventories as "lies waiting to happen" |
| B3 | **Status rules codified** — `green = 0 Sentry errors 7d + last visit <7d`; `yellow = 1-5 errors 7d OR last visit 7-30d`; `red = >5 errors 7d OR Sentry `fatal``; `dead = 0 visits 30d` | LOW | B1 data available | **Linear** "dead code culture": anything dead 30d → delete PR opens automatically |

### B.2 Differentiators

| # | Gesture | Complexity | Deps | Fintech precedent |
|---|---------|------------|------|-------------------|
| B4 | **Screenshot thumbnail refresh 1×/day** — nightly `mint-route-walker` sim script loops through routes from `mint-dogfood` scenario, captures thumbnail per visited route, commits to `docs/route-thumbs/*.png` | HIGH | Phase 35 scenario primitives | **Airbnb** — `happo.io` screenshot diffing; **Linear** nightly visual regression |
| B5 | **Heatmap user paths (aggregate only)** — Sentry breadcrumb `screen-enter` events aggregated to an adjacency matrix: "after `/home`, 42% go to `/coach`, 11% to `/explorer`". nLPD-safe because aggregate ≥ 50 sessions | MED | A2 breadcrumbs shipped | **Amplitude** popularised "journey map"; **Mixpanel** Flows; implement ourselves server-side to avoid vendor |
| B6 | **23 legacy redirects sunset list** — static page in `/admin/routes?view=legacy` showing the 23 deprecated paths with `added_on`, `redirect_target`, `last_hit`. Sunset = 30d no hits → delete PR | LOW | B1 | **Stripe API** deprecation policy: 6-month sunset with usage tracking |

### B.3 Anti-features

| Anti-feature | Why avoid | Instead |
|--------------|-----------|---------|
| Per-user path tracking | nLPD; no cohort team | Aggregate ≥ 50 sessions |
| Hand-maintained route inventory | Will lie within 2 weeks | Generated from AST (B2) |
| Live pixel-perfect thumbnails on every CI | Flaky, expensive | Nightly + tolerance |

### B.4 Ceremony

- **Weekly Red Route Review** (Monday, 15 min, after Sentry triage): Julien scans `/admin/routes` filtered `status ∈ {yellow, red, dead}`. Each entry: kill (add flag), fix (open TODO), or accept (note reason, age-out 30d max). Artifact: `.planning/route-review/YYYY-WW.md`. Precedent: **Ramp** "dead code Friday"; **Linear** "feature graveyard review".

---

## C. Phase 33 — Kill-switches

### C.1 Table stakes

| # | Gesture | Complexity | Deps | Fintech precedent |
|---|---------|------------|------|-------------------|
| C1 | **`requireFlag()` middleware on GoRouter** — `GoRoute(path: '/x', redirect: requireFlag('feature_x', fallback: '/home'))`. Extends existing redirect pattern (already 52 usages). Adds `/admin/flags/killed` landing that says "en travaux, revient plus tard" calmly | LOW | Existing flag system | **Uber** has `RouteFlag` wrapper; **Shopify** `FeatureGate` component — same pattern |
| C2 | **Admin page `/admin/flags`** — lists all flags (current + new route flags), toggle button, shows `last_changed_by`, `last_changed_at`, `server_override_active`. Requires `enableAdminScreens=true` (already exists) | LOW | Existing flag system | **Every** fintech — LaunchDarkly-inspired internal UI |
| C3 | **Flag per critical red route** — at minimum, 1 flag per route in the "dead / known-broken" list: `flow_anonymous`, `budget_crud`, `coach_tab_v2`, `mintshell_labels_i18n`. Default OFF; flip ON when fixed | LOW | C1 + Phase 32 status | **Stripe** "kill switch per endpoint" pattern (SRE book case study) |
| C4 | **Server-override precedence documented** — `server value wins > local default`. Ensures Julien can kill from Railway dashboard without new build. Already implemented but add E2E test | LOW | Existing refreshFromBackend | **LaunchDarkly** model |

### C.2 Differentiators

| # | Gesture | Complexity | Deps | Fintech precedent |
|---|---------|------------|------|-------------------|
| C5 | **Circuit breaker — auto-kill on Sentry spike** — backend cron (every 5 min) queries Sentry Issues API: if any route's errors >5/h crossing 3 consecutive windows, `POST /config/feature-flags` flips route flag OFF, logs decision, pings Sentry w/ "auto-killed" message. Manual re-arm via admin | HIGH | Phase 31 A1 + C1 shipped | **Netflix Hystrix** original pattern; **Uber** µmon; **MINT already has SLOMonitor for LLM fallback** — same pattern, new target |
| C6 | **Staged rollout ceremony** — new feature behind flag starts OFF globally, ON for Julien's user (allowlist), then `server_rollout_pct: 10 → 50 → 100`. Server implements stable hash on user_id for deterministic cohort | MED | C1 + user allowlist | **Facebook Gatekeeper** → **Stripe Feature Bus** → every modern fintech has this |

### C.3 Anti-features

| Anti-feature | Why avoid | Instead |
|--------------|-----------|---------|
| Flag per component (button, card) | Flag rot; 500 flags in 6 months; cognitive overload solo | Flag at **route** granularity only |
| Per-user flag targeting beyond allowlist | No cohort team, no PM to manage; use aggregate rollout % | Allowlist (Julien + 5 beta) + rollout % |
| LaunchDarkly / Split / Unleash adoption | Vendor cost, DPA burden, duplicates existing 8-flag system | Extend `feature_flags.dart` (PROJECT.md decision locked) |
| Auto-kill without manual re-arm | Silent re-enable = re-regression | Auto-kill sticks until human re-arms |

### C.4 Ceremony

- **Monthly flag audit** (first Monday): Julien reviews `/admin/flags` — any flag >90 days in same state gets a decision (graduate to default-in-code + remove flag, or delete code behind flag). Artifact: `.planning/flag-audit/YYYY-MM.md`. Precedent: **Google** "flag debt is tech debt"; **Segment** published flag-retirement policy.

---

## D. Phase 34 — Agent Guardrails

### D.1 Table stakes

| # | Gesture | Complexity | Deps | Fintech precedent |
|---|---------|------------|------|-------------------|
| D1 | **lefthook pre-commit local** — installs on `git init`; runs in parallel: `flutter analyze --no-fatal-infos` (changed dirs), `pytest -q` (changed paths only via `--last-failed --lf-fail` or `pytest-picked`), `tools/checks/no_bare_catch.py` (changed files), `tools/checks/no_hardcoded_fr.py`, `tools/checks/arb_parity.py`, `tools/checks/diacritics.py`. Target runtime: **<5s for a typical diff** | MED | Existing `tools/checks/` | **Linear** uses lefthook; **Ramp**, **Brex** use husky+lint-staged same idea |
| D2 | **Bare-catch ban** — `no_bare_catch.py` (reused from A5) wired to lefthook + CI. Zero-tolerance on changed lines; legacy grandfathered via `.bare_catch_allowlist` (shrinks over phase 36) | LOW | A5 | **Ramp** public principle |
| D3 | **Accent + diacritics lint** — `tools/checks/diacritics.py` fails if ARB values use ASCII `e` where `é` expected (dictionary-based common words: mère, père, été, etc.). Agent-common regression locked out | MED | Existing ARB tooling | **Duolingo** — published on diacritic QA; **DeepL** engineering blog on i18n regressions |
| D4 | **Hardcoded-FR-string lint extended** — grep for `Text('[A-Z]'` or `'[A-ZÉÈ]` in `.dart` files outside `l10n/` and `test/`. Existing tool probably in `tools/checks/` — verify scope covers all widgets, not just screens | LOW | Existing lint | **Airbnb** — `eslint-plugin-i18n-json`; **Wise** multilingual QA process |
| D5 | **ARB 6-lang parity** — `tools/checks/arb_parity.py` fails if fr/en/de/es/it/pt have mismatched keys. Runs on every ARB edit. Already standard practice — confirm CI + add to lefthook | LOW | Existing ARB | **Duolingo**, **Wise**, **Revolut** — standard i18n guardrail |

### D.2 Differentiators

| # | Gesture | Complexity | Deps | Fintech precedent |
|---|---------|------------|------|-------------------|
| D6 | **Proof-of-read formal** — agent hooks (Claude Agent SDK `PreToolUse` hook) inject requirement: before `Edit`/`Write`, agent must emit `<proof>` block citing 3 lines from target file (SHA256-checked against actual content). Enforced at git `prepare-commit-msg` hook — commit message must contain `proof-of-read: <sha256>` for each `*.dart`/`*.py` changed | HIGH | Agent SDK hooks | **Anthropic** published on agent-guardrails pattern; **Cognition/Devin** uses similar "read-before-edit" enforcement |
| D7 | **File allowlist per task** — GSD plan files declare `files_touchable: [list]` in frontmatter; lefthook rejects commit touching files outside the list unless `--allow-scope-expansion` passed with reason. Prevents agent scope creep | MED | GSD plan convention | **Google** uses `OWNERS` files similarly; **Shopify** "surgical changes" principle |
| D8 | **CLAUDE.md read-check** — every commit must include trailer `ClaudeMd-Sha: <sha256>` matching current CLAUDE.md. If agent modified CLAUDE.md mid-session, the sha is stale → blocked | LOW | Git commit hook | **Sourcegraph Cody** uses similar "context sha" verification; novel combo — MINT-specific |

### D.3 Anti-features

| Anti-feature | Why avoid | Instead |
|--------------|-----------|---------|
| Gates that take >10s locally | Devs / agents skip with `--no-verify`; gate becomes decorative | Target <5s; split heavy gates to CI-only |
| Gates that fail on legacy code unchanged by the diff | Breaks flow, agents learn `--no-verify` | Changed-files-only scope; grandfather via `.*_allowlist` shrinking |
| Gates blocking WIP commits on `feature/wip-*` branches | Friction on exploratory work | Branch-pattern escape hatch, logged |
| Mandatory commit message templates requiring 100+ char essays | Agents copy-paste garbage to pass | Structured trailers (`ClaudeMd-Sha:`, `proof-of-read:`) parseable by machine |

### D.4 Ceremony

- **Weekly `--no-verify` audit** (Friday, 5 min): grep git reflog for `--no-verify` usage past 7d. If count >5/week, **a gate is wrong, not the dev** — open investigation; relax / split / fix. If count 1-5, review each for legitimacy. Artifact: `.planning/noverify-audit/YYYY-WW.md`. Precedent: **Google** SRE "toil log"; **Stripe** "paper cut Friday".

---

## E. Phase 35 — Boucle Daily (`mint-dogfood`)

### E.1 Table stakes

| # | Gesture | Complexity | Deps | Fintech precedent |
|---|---------|------------|------|-------------------|
| E1 | **`mint-dogfood` bash script** — 10 min scripted: boot iPhone 17 Pro sim (`simctl`), install build, launch app, execute scenario: `landing → intent tap → 3 coach messages → 5 random routes from manifest → quit`. Captures screenshots per step via `simctl io screenshot` | MED | Phase 31 + 32 (manifest) | **Monzo** — "daily dogfood" blog post 2023; **Linear** — CEO dogfoods every morning (Karri Saarinen interviews) |
| E2 | **Auto-pull Sentry events during the run** — script tags all events with `mint-dogfood-session: <uuid>`; after run, queries Sentry Issues API for that tag, formats into markdown report | MED | Phase 31 A3 (trace_id) | **Stripe** engineering uses similar "shadow run" pattern |
| E3 | **Auto-generate `.planning/dogfood/YYYY-MM-DD.md`** — report template: session duration, routes visited, errors captured, screenshots (gallery), open P0/P1 triage section | LOW | E1 + E2 | **Linear** daily changelog convention |
| E4 | **Auto-PR on findings** — if report contains any P0/P1 section item, script opens draft PR `chore(dogfood): YYYY-MM-DD findings` with the markdown report. Human triages later | MED | E3 + gh CLI | **GitHub** Dependabot pattern applied to QA |
| E5 | **Extend `tools/e2e_flow_smoke.sh`** — existing 60-line curl E2E becomes the backend-only fast path (register → profile → vision → scan-confirm → chat). `mint-dogfood` wraps it + adds the mobile sim walk. Run daily + on every dev push | LOW | Existing script | **Ramp** — documented multi-layer E2E (API + mobile); **Stripe** has both `tb-sanity` CLI and end-to-end test suites |

### E.2 Differentiators

| # | Gesture | Complexity | Deps | Fintech precedent |
|---|---------|------------|------|-------------------|
| E6 | **Custom replay scenarios** — Julien records a scenario via `idb ui tap-by-accessibility-label`; saved as `tools/dogfood-scenarios/*.yml`. Replayable deterministically. 5-10 scenarios cover Sophie / Julien / Lauren / anonymous flow / debt crisis | MED | E1 shipped | **Apple** `XCUITest` inspiration (but cheaper); **Monzo** `Maestro` framework |
| E7 | **Visual diff J-1 vs J (non-blocking)** — after daily run, `magick compare -metric AE` between yesterday's screenshot and today's; if diff pixel count >1% on a non-animated widget, flag in report. **Never blocks CI** — advisory only | MED | E1 + screenshot storage | **Happo**, **Chromatic**, **Percy** — the industry pattern; MINT implements a poor-man version |
| E8 | **Slack / email daily recap** — daily report summary pushed to Julien's Slack DM at 09:00 CEST. 5-line TL;DR + link to full report | LOW | E3 | **Linear** has this as "Focus Time Recap"; **Stripe** "Daily Digest" |

### E.3 Anti-features

| Anti-feature | Why avoid | Instead |
|--------------|-----------|---------|
| Dogfood >15 min | Fatigue → drift → stops happening | Hard cap 10 min scenario; fail-fast on boot errors |
| Static checklist (never evolves) | Misses new routes added post-checklist | Route list pulled from manifest (B2) at runtime |
| Dogfood gates block CI on flakiness | One sim crash blocks merge → bypass culture | Advisory-only for CI; blocks only the daily Slack recap |
| Patrol / Maestro / XCUITest adoption | Heavy framework, flutter-plugin lag, ≈1 week setup + ongoing maintenance | `simctl` + `idb` already work; PROJECT.md decision locked |
| Dogfood on prod data | PII leak risk; destructive actions | Staging only; test account `e2e-*@example.com` |

### E.4 Ceremony

- **Daily dogfood (10 min, AM)**: Julien runs `make dogfood` before first coffee. Script spins sim, runs scenario, generates report, opens PR if findings. Artifact auto-committed.
- **Weekly triage (Friday, 15 min)**: the week's 5-7 daily reports aggregated into `.planning/dogfood/YYYY-WW-triage.md`. Findings become P0/P1/P2, fed to agents on dedicated branches `feature/dogfood-YYYY-WW-fix-*`. Precedent: **Monzo** weekly "user feedback triage"; **Linear** "bug bash Friday".

---

## F. Phase 36 — Finissage E2E (Catalogued P0s)

### F.1 P0 inventory (ALL must close before v2.8 done)

From PROJECT.md §Codebase State + session notes:

| P0 ID | Finding | Fix gesture | Regression test required | Complexity |
|-------|---------|-------------|--------------------------|------------|
| P0-UUID | `/profiles/me` UUID validation crash | Fix in `services/backend/app/schemas/profile.py` + rolling deploy staging→prod. **Staging-first** (never hotfix prod). | pytest: GET /profiles/me with 3 UUID shapes (v4, legacy int, malformed) → only malformed rejects; test that would have caught original bug | LOW |
| P0-ANON | Anonymous flow dead despite `AnonymousChatScreen` shipped | Re-wire `Landing → AnonymousChatScreen` bridge; **remove JWT check on pre-auth routes**; add GoRouter `redirect` that short-circuits when `authState == anonymous` | Widget test: cold start without token → landing → tap felt-state → AnonymousChatScreen mounted with `sessionScope = anonymous` | MED |
| P0-SAVEFACT | `save_fact` backend→mobile desync | `CoachProfile` becomes `ChangeNotifier` reactive on `save_fact` tool-call response; mobile invalidates cache + emits `ProfileChanged` event; UI subscribed rebuilds | E2E test extending `e2e_flow_smoke.sh`: coach `/chat` with tool_use `save_fact(goal="buy_house")` → immediately GET /profiles/me returns `goal=buy_house` AND mobile `CoachProfile.goal` emits update within 500ms | MED |
| P0-COACHTAB | Coach tab routing stale | Navigation state inspection: `GoRouterState.matchedLocation` vs `currentRoute`; fix the bottom-nav IndexedStack vs GoRouter collision. Likely root cause: tab taps use `context.push` instead of `.go` | Widget test: tap through tabs 1→2→3→2 → verify only one `/coach` route in history at any time; hostile test: Sentry event on `/coach` loads → navigate elsewhere → no stale state | MED |
| P0-CATCHES | 388 bare catches (332 mobile + 56 backend) | **Hybrid approach**: (1) lint ban net-new (A5 prevents new ones); (2) automated rewrite script `tools/fix_bare_catches.py` that converts `catch (e) {}` → `catch (e, st) { Sentry.captureException(e, stackTrace: st); }` with `--dry-run` mode; (3) human review of batches of 20 via PR. **Backend first** (56 items, smaller blast radius, type-checked). Then mobile batches by layer: services → providers → screens → widgets | Per-batch PR requires: lint gate green, Sentry preview showing captured errors in staging dogfood run | HIGH (but parallelisable) |
| P0-MINTSHELL | MintShell labels hardcoded FR | Extract all `Text('...')` in `lib/widgets/shell/` to `AppLocalizations.of(context)!.xxx`; add 6 ARB keys × 6 langs = 36 entries; run `flutter gen-l10n` | Widget test: pump MintShell with `locale: 'de'` → verify no French leak; golden test per locale | LOW |
| P0-ACCENTS | Accents 100% | Lint gate D3 shipped (Phase 34) + manual pass via grep patterns: `mere\|pere\|ete\|retraite` (case-insensitive) in ARB files outside `en/` and `pt/`. Every match reviewed | Gate D3 in CI blocks future regressions; one-time sweep commits the baseline | LOW |
| P0-REDIRECTS | 23 redirects legacy | **Sunset 30d** strategy: tag each with `// LEGACY-REDIRECT: YYYY-MM-DD sunset` comment; track hits via Sentry breadcrumb `screen-enter /legacy-path`; after 30d 0 hits → delete PR. **Immediate delete only if** `last_hit > 90d` (already dead) | B6 tracks hit counts; deletion PR links to 30d-zero-hit graph | MED |

### F.2 Re-test discipline

**Every fix above MUST ship with a regression test that would have failed against the pre-fix code.** No exception. This is the **"bug → failing test → fix → passing test"** loop, not "fix → hope". Precedent: **Google Testing on the Toilet** #66 "Write the failing test first"; **Stripe** "regression tests are permanent".

Pattern:
```bash
# 1. Write the test that proves the bug
git commit -m "test(P0-ANON): regression — landing fails to bridge to anonymous chat"
# run test → it FAILS — commit the failure
# 2. Apply the fix
git commit -m "fix(P0-ANON): wire Landing → AnonymousChatScreen bridge"
# run test → it PASSES
```

### F.3 Anti-features

| Anti-feature | Why avoid | Instead |
|--------------|-----------|---------|
| Fix-without-regression-test | Bug will return when refactor happens | Regression test MANDATORY; PR blocked without one |
| Mass-rewrite 388 catches in one PR | Impossible to review; will merge broken | Batches of 20 max, per-layer PRs, backend first |
| "Temp fix, we'll come back" on P0s | Lie; debt never repaid | No tempfix; full fix or descope P0 to v2.9 via ADR |
| Hotfix direct to prod | Skipping staging = how UUID crash shipped | Staging → device gate → prod, no exceptions (doctrine) |
| Silently delete redirects | Breaks old bookmarks / shared links | Sunset announce → 30d watch → delete PR |

### F.4 Ceremony

- **Per-P0 close ritual**: PR template requires (1) link to regression test commit that FAILED before fix, (2) Sentry before/after screenshot, (3) device-gate line-item checked. Precedent: **Monzo** incident post-mortem template; **Stripe** `POSTMORTEM.md` convention.
- **Weekly P0 burn-down** (Monday): `.planning/p0-burndown/YYYY-WW.md` shows closed/open ratio. Mid-phase if velocity insufficient → descope to v2.9 (explicit ADR), not silent slip.

---

## G. Cross-cutting Anti-features (apply to all 6 phases)

| Anti-feature | Why avoid | Instead |
|--------------|-----------|---------|
| Multi-agent tooling | Parallel agents caused the current mess (wave damage) | Sequential execution, one plan at a time |
| New product features in v2.8 | Règle scellée; re-plantation du problème | 0 feature; fix + kill only |
| Dashboards nobody looks at | Observability theatre | Only dashboards that feed a scheduled ceremony (Sentry triage, route review, dogfood) |
| Vendor stack expansion | Each vendor = DPA + surface + divergence | Sentry + existing flags only |
| Silent refactors on legacy code outside phase scope | Wave E-PRIME lesson: touched 42K LOC, some unintended | File allowlist per task (D7); scope locked in plan |

---

## H. Ceremony Calendar (v2.8 steady-state)

| Cadence | Ceremony | Owner | Duration | Artifact | Phase needs |
|---------|----------|-------|----------|----------|-------------|
| **Daily 09:00** | `mint-dogfood` run + Slack recap | Julien | 10 min | `.planning/dogfood/YYYY-MM-DD.md` (auto) | 31+32+35 |
| **Monday AM** | Sentry triage (top 3 issues) | Julien | 10 min | `.planning/sentry-triage/YYYY-WW.md` | 31 |
| **Monday AM** | Red Route Review | Julien | 15 min | `.planning/route-review/YYYY-WW.md` | 32 |
| **Monday AM** | P0 burn-down check | Julien | 5 min | `.planning/p0-burndown/YYYY-WW.md` | 36 |
| **Friday PM** | `--no-verify` audit | Julien | 5 min | `.planning/noverify-audit/YYYY-WW.md` | 34 |
| **Friday PM** | Dogfood week triage → feed agents | Julien | 15 min | `.planning/dogfood/YYYY-WW-triage.md` | 35 |
| **1st Monday / month** | Flag audit (>90d stale → decide) | Julien | 15 min | `.planning/flag-audit/YYYY-MM.md` | 33 |

**Total Julien time budget:** ~10 min/day (dogfood) + ~1h/week (Monday triage bundle) + ~20 min/week (Friday triage bundle) + ~15 min/month = **~1.5h/week fixed overhead**. Below the 2h/week limit for a one-person team.

---

## I. Feature Dependencies

```
Phase 31 Oracle ──┬──────────► Phase 32 Cartographier
                  │              (needs Sentry error data for card status B1+B3)
                  │
                  ├──────────► Phase 33 Kill-switches C5 (circuit breaker)
                  │              (needs error rate API for auto-off)
                  │
                  └──────────► Phase 35 Boucle Daily E2+E7
                                 (needs breadcrumbs + trace_id for session pull)

Phase 32 Cartographier ──────► Phase 33 Kill-switches C3
                                 (needs red-route list for flag priorities)
                                 
                               ► Phase 35 Boucle Daily E1+E6
                                 (needs route manifest for random walk targets)

Phase 34 Guardrails (parallel) ─► Phase 36 Finissage
                                   (protects fixes from regressing)

Phase 33 Kill-switches ──────► Phase 36 Finissage P0-ANON, P0-COACHTAB
                                 (need to flag-off if fix regresses)

Phase 31+32+33+34 complete ──► Phase 35 Boucle Daily full-fidelity
                                 (before that: partial dogfood value)

All of 31-35 complete ───────► Phase 36 closable
                                 (guardrails + oracle must exist before 388-catch sweep)
```

**Recommended execution order:**
1. **Phase 31** (Oracle) — taproot, unlocks everything
2. **Phase 34** (Guardrails) — parallel with 31, protects all later phases
3. **Phase 32** (Cartographier) — depends on 31 data
4. **Phase 33** (Kill-switches) — depends on 31+32
5. **Phase 35** (Boucle Daily) — depends on 31+32; partially usable earlier
6. **Phase 36** (Finissage) — depends on all; sequenced P0-by-P0

---

## J. MVP / Descope Map

If timeline pressure (one-person team realities), here's the **descope order from first-to-cut to last-to-cut**:

**First to cut (differentiators):**
1. C5 Circuit breaker auto-kill (HIGH) → manual kill sufficient if ceremony happens
2. B4 Screenshot nightly (HIGH) → advisory anyway
3. B5 Heatmap paths (MED) → nice-to-know, not decision-critical
4. D6 Proof-of-read formal (HIGH) → CLAUDE.md read-check (D8) covers 80% at 10% cost
5. E7 Visual diff J-1 vs J (MED) → advisory anyway
6. E6 Custom replay scenarios (MED) → scripted scenario (E1) sufficient for v2.8
7. A7 Performance budget per route (MED) → crash-free session (A6) covers core
8. A8 Custom LLM spans (MED) → existing Sentry auto-instrumentation partial coverage
9. C6 Staged rollout pct (MED) → allowlist + binary flag sufficient for one-person beta

**Must-keep table stakes (no-cut):**
- A1 Sentry Replay with PII masking — nLPD + oracle baseline
- A2 Breadcrumb taxonomy — oracle useless without
- A3 trace_id round-trip — cross-stack debugging foundation
- A4 Fail-loud error boundaries — silent failures = current state
- A5 Catch-audit lint — prevents new 388-catch regression
- B1 Route cards + B2 auto-gen manifest — cartography foundation
- B3 Status rules — board without rules = opinion, not data
- C1-C4 Kill-switch primitives — no fix safe without rollback
- D1-D5 All pre-commit gates — agent guardrail foundation
- E1-E5 Daily dogfood primitives — the ceremony itself
- **ALL F.1 P0s** — non-negotiable; the whole point of v2.8

---

## K. MINT-specific Recommendations

Three idiosyncratic nudges given the codebase inspection:

1. **Extend `tools/e2e_flow_smoke.sh`, don't replace.** The 60-line script already proves the UUID crash + save_fact desync + coach citation in one run. Extending it with `--mobile-sim` flag that wraps `mint-dogfood` gives the shortest path from "what we have" to "what we need". Precedent: **Stripe** grows `tb-sanity` organically rather than rewriting; **Monzo** same.

2. **Capitalise on the 52 existing redirect callbacks in `app.dart`.** `requireFlag()` from C1 is *the same pattern*, just with a flag argument instead of a hardcoded condition. The GoRouter middleware is already proven on this codebase. No new paradigm — evolved one.

3. **The 12 existing `tools/checks/` scripts are the guardrail DNA.** Phase 34's lints (D2-D5) should use the identical pattern (Python script, exit code, `.allowlist` text file, CI wired). Adding `no_bare_catch.py`, `no_hardcoded_fr.py`, `arb_parity.py`, `diacritics.py` is **additive**, not architectural. Agents already know how to touch these — lowest-friction guardrail path.

---

## L. Sources

**High-confidence (verified during research):**
- Codebase inspection: `apps/mobile/lib/app.dart` (147 GoRoute, 52 redirect callbacks), `lib/services/feature_flags.dart` (8 flags + server refresh), `tools/checks/*` (12 existing scripts), `tools/e2e_flow_smoke.sh` (existing 60-line E2E)
- PROJECT.md v2.8 scope + Codebase State
- DEVICE_GATE_V27_CHECKLIST.md (existing manual checklist, target for automation)
- Sentry Flutter SDK docs for Replay + masking API (training data + confirmed against public docs)
- GoRouter redirect API (Flutter official docs, stable since 2023)
- lefthook (evilmartians/lefthook) — standard tool, active 2024-2026

**Medium-confidence (engineering blog references, training data):**
- Stripe engineering blog posts on canonical log lines (Brandur Leach) and request-id convention — widely cited
- Monzo engineering blog on Sentry Replay adoption + daily dogfood culture
- Linear engineering interviews (Karri Saarinen) on dead-code culture + CEO dogfood
- Ramp engineering principles: "no silent catches", "dead code Friday"
- Cleo conversational AI team interviews on Sentry + Replay
- Netflix Hystrix / Uber µmon circuit breaker pattern (industry standard)

**Where to verify before locking decisions** (LOW-to-MED confidence claims worth validating):
- Sentry Replay Flutter privacy defaults — confirm `maskAllText` + `maskAllImages` behave as described in current `sentry_flutter` plugin version
- lefthook performance on large Flutter repos — benchmark on MINT's repo size before committing to <5s target
- Claude Agent SDK `PreToolUse` hook semantics — validate proof-of-read enforcement path (D6)
- Sentry Issues API rate limits — confirm 5-min poll for circuit breaker C5 is within free-tier budget
