# Phase 32 Wave 0 — Reconciliation Report

**Date:** 2026-04-20
**app.dart SHA:** b7a88cc8
**Branch:** feature/v2.8-phase-32-cartographier
**Plan:** 32-00-reconcile-PLAN.md

---

## Route count (MAP-01 foundation)

Command: `grep -cE "^\s*(GoRoute|ScopedGoRoute)\(" apps/mobile/lib/app.dart`
Result: 147  (expected 147 per CONTEXT v4)
Drift: NONE

Cross-check: `grep -nE "^\s*(GoRoute|ScopedGoRoute)\(" apps/mobile/lib/app.dart | wc -l` = 147 (identical).

## Redirect count (MAP-05 foundation)

Command: `grep -cE "redirect:\s*\(_,\s*_?_?\)" apps/mobile/lib/app.dart`
Result: 43  (expected 43 per CONTEXT v4)
Drift: NONE

### Note on broader `redirect:` matches

A wider grep `grep -cE "redirect:" apps/mobile/lib/app.dart` returns **52** occurrences. The 9-count delta
between 43 (legacy-arrow-redirect) and 52 (all redirects) consists of 9 block-form redirects using
`(context, state)` or `(_, state)` callbacks. These are NOT legacy redirects — they are guards / feature-flag
gates / parameter-passing redirects. They emit no `mint.routing.legacy_redirect.hit` breadcrumb. They are:

| Line | Path | Purpose (not a legacy redirect) |
|------|------|---------------------------------|
| 194  | (root GoRouter) | Scope-based auth guard |
| 870  | `/household/accept` | Param-passing (forwards `?code=` to `/couple/accept`) |
| 908  | `/profile` | Sub-route pass-through guard (null when path != `/profile`) |
| 916  | `/profile/admin-observability` | `FeatureFlags.enableAdminScreens` gate |
| 922  | `/profile/admin-analytics` | `FeatureFlags.enableAdminScreens` gate |
| 1134 | `/open-banking` | `FeatureFlags.enableOpenBanking` gate |
| 1141 | `/open-banking/transactions` | `FeatureFlags.enableOpenBanking` gate |
| 1148 | `/open-banking/consents` | `FeatureFlags.enableOpenBanking` gate |
| 1163 | `/advisor/wizard` | Param-passing (forwards `?section=` to `/coach/chat?topic=`) |

These 9 are scope/flag/param redirects and belong to Phase 33 Kill-switches surface, not MAP-05. The MAP-05
contract is the 43 arrow-form redirects enumerated below.

## Redirect Call-Site Inventory (M-3 fix — per-site breadcrumb coverage contract)

This table is the CONTRACT that Plan 03 Task 2 consumes. For each of the 43 redirect call-sites: the line
number, source-path pattern, target path(s), number of redirect-taking branches (each emits 1 breadcrumb
when taken), and number of null-pass-through branches (emit 0 breadcrumbs — go_router continues matching).

Every row in this inventory is an arrow-form `(_, __) => '/target'` redirect. By construction each has
exactly 1 redirect branch and 0 null-pass-through branches. Plan 03 Task 2 asserts:

1. Each call-site's callback BODY contains exactly `redirect_branches` calls to
   `MintBreadcrumbs.legacyRedirectHit` (static count, AST-free via regex).
2. Sum of `grep -c "MintBreadcrumbs.legacyRedirectHit" app.dart` >= 43
   (loose lower bound — here exactly 43 since every site is single-branch).

| #  | line | source pattern                          | target(s)          | redirect_branches | null_pass_through | callback signature                                   |
|----|------|-----------------------------------------|--------------------|-------------------|-------------------|------------------------------------------------------|
| 1  | 531  | `/coach/dashboard`                      | `/retraite`        | 1                 | 0                 | `(_, __) => '/retraite'`                             |
| 2  | 532  | `/retirement`                           | `/retraite`        | 1                 | 0                 | `(_, __) => '/retraite'`                             |
| 3  | 533  | `/retirement/projection`                | `/retraite`        | 1                 | 0                 | `(_, __) => '/retraite'`                             |
| 4  | 540  | `/arbitrage/rente-vs-capital`           | `/rente-vs-capital`| 1                 | 0                 | `(_, __) => '/rente-vs-capital'`                     |
| 5  | 541  | `/simulator/rente-capital`              | `/rente-vs-capital`| 1                 | 0                 | `(_, __) => '/rente-vs-capital'`                     |
| 6  | 548  | `/lpp-deep/rachat`                      | `/rachat-lpp`      | 1                 | 0                 | `(_, __) => '/rachat-lpp'`                           |
| 7  | 549  | `/arbitrage/rachat-vs-marche`           | `/rachat-lpp`      | 1                 | 0                 | `(_, __) => '/rachat-lpp'`                           |
| 8  | 556  | `/lpp-deep/epl`                         | `/epl`             | 1                 | 0                 | `(_, __) => '/epl'`                                  |
| 9  | 563  | `/coach/decaissement`                   | `/decaissement`    | 1                 | 0                 | `(_, __) => '/decaissement'`                         |
| 10 | 564  | `/arbitrage/calendrier-retraits`        | `/decaissement`    | 1                 | 0                 | `(_, __) => '/decaissement'`                         |
| 11 | 567  | `/coach/cockpit`                        | `/retraite`        | 1                 | 0                 | `(_, __) => '/retraite'`                             |
| 12 | 569  | `/coach/checkin`                        | `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'`                           |
| 13 | 570  | `/coach/refresh`                        | `/home`            | 1                 | 0                 | `(_, __) => '/home'`                                 |
| 14 | 582  | `/coach/succession`                     | `/succession`      | 1                 | 0                 | `(_, __) => '/succession'`                           |
| 15 | 583  | `/life-event/succession`                | `/succession`      | 1                 | 0                 | `(_, __) => '/succession'`                           |
| 16 | 590  | `/lpp-deep/libre-passage`               | `/libre-passage`   | 1                 | 0                 | `(_, __) => '/libre-passage'`                        |
| 17 | 598  | `/simulator/3a`                         | `/pilier-3a`       | 1                 | 0                 | `(_, __) => '/pilier-3a'`                            |
| 18 | 632  | `/mortgage/affordability`               | `/hypotheque`      | 1                 | 0                 | `(_, __) => '/hypotheque'`                           |
| 19 | 688  | `/life-event/divorce`                   | `/divorce`         | 1                 | 0                 | `(_, __) => '/divorce'`                              |
| 20 | 766  | `/disability/gap`                       | `/invalidite`      | 1                 | 0                 | `(_, __) => '/invalidite'`                           |
| 21 | 767  | `/simulator/disability-gap`             | `/invalidite`      | 1                 | 0                 | `(_, __) => '/invalidite'`                           |
| 22 | 800  | `/document-scan`                        | `/scan`            | 1                 | 0                 | `(_, __) => '/scan'`                                 |
| 23 | 807  | `/document-scan/avs-guide`              | `/scan/avs-guide`  | 1                 | 0                 | `(_, __) => '/scan/avs-guide'`                       |
| 24 | 860  | `/household`                            | `/couple`          | 1                 | 0                 | `(_, __) => '/couple'`                               |
| 25 | 901  | `/report`                               | `/rapport`         | 1                 | 0                 | `(_, __) => '/rapport'`                              |
| 26 | 902  | `/report/v2`                            | `/rapport`         | 1                 | 0                 | `(_, __) => '/rapport'`                              |
| 27 | 1032 | `/achievements`                         | `/home`            | 1                 | 0                 | `(_, __) => '/home'`                                 |
| 28 | 1060 | `/ask-mint`                             | `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'`                           |
| 29 | 1062 | `/tools`                                | `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'`                           |
| 30 | 1063 | `/portfolio`                            | `/home`            | 1                 | 0                 | `(_, __) => '/home'`                                 |
| 31 | 1083 | `/score-reveal`                         | `/home`            | 1                 | 0                 | `(_, __) => '/home'`                                 |
| 32 | 1092 | `/onboarding/quick` (parent L1089)      | `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'` (block-style route)       |
| 33 | 1097 | `/onboarding/quick-start` (parent L1094)| `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'` (block-style route)       |
| 34 | 1102 | `/onboarding/premier-eclairage` (L1099) | `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'` (block-style route)       |
| 35 | 1108 | `/onboarding/intent` (parent L1105)     | `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'` (block-style route)       |
| 36 | 1113 | `/onboarding/promise` (parent L1110)    | `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'` (block-style route)       |
| 37 | 1118 | `/onboarding/plan` (parent L1115)       | `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'` (block-style route)       |
| 38 | 1161 | `/advisor`                              | `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'`                           |
| 39 | 1162 | `/advisor/plan-30-days`                 | `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'`                           |
| 40 | 1168 | `/coach/agir`                           | `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'`                           |
| 41 | 1169 | `/onboarding/smart`                     | `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'` (scope: onboarding)       |
| 42 | 1170 | `/onboarding/minimal`                   | `/coach/chat`      | 1                 | 0                 | `(_, __) => '/coach/chat'` (scope: onboarding)       |
| 43 | 1171 | `/onboarding/enrichment`                | `/profile/bilan`   | 1                 | 0                 | `(_, __) => '/profile/bilan'` (scope: onboarding)    |

**Totals:**
- Total sites: **43**
- Total `redirect_branches` (expected `MintBreadcrumbs.legacyRedirectHit` source-call count in app.dart): **43**
- Total `null_pass_through` branches: **0** (every site is arrow-form, single-branch, non-null)

**Plan 03 Task 2 contract (derived from this inventory):**
- Sum of `grep -c "MintBreadcrumbs.legacyRedirectHit" apps/mobile/lib/app.dart` MUST be >= 43 after Wave 3.
- Each of the 43 call-sites listed above MUST contain exactly 1 invocation of
  `MintBreadcrumbs.legacyRedirectHit(from: '<source>', to: '<target>')` inside its callback.
- No breadcrumb emission expected for the 9 non-legacy redirects (lines 194, 870, 908, 916, 922, 1134, 1141, 1148, 1163).

## Extracted paths (full list for Wave 1 kRouteRegistry)

Total unique path literals extracted from app.dart: **147**. Extraction regex:
`path\s*:\s*(['"])([^'"]+)\1` (module-level scan; every `path:` literal in the file, independent of
surrounding `GoRoute(...)` structure). Note: nested child routes inside `routes: [...]` blocks carry a path
literal that is a segment (e.g., `admin-observability`, `byok`) — their runtime-composed path is parent +
child (e.g., `/profile/admin-observability`). The raw list below captures declared path literals AS-WRITTEN.

```
/
/3a-deep/comparator
/3a-deep/real-return
/3a-deep/staggered-withdrawal
/3a-retroactif
/about
/achievements
/advisor
/advisor/plan-30-days
/advisor/wizard
/anonymous/chat
/arbitrage/allocation-annuelle
/arbitrage/bilan
/arbitrage/calendrier-retraits
/arbitrage/location-vs-propriete
/arbitrage/rachat-vs-marche
/arbitrage/rente-vs-capital
/ask-mint
/assurances/coverage
/assurances/lamal
/auth/forgot-password
/auth/login
/auth/register
/auth/verify
/auth/verify-email
/bank-import
/budget
/cantonal-benchmark
/check/debt
/coach/agir
/coach/chat
/coach/checkin
/coach/cockpit
/coach/dashboard
/coach/decaissement
/coach/history
/coach/refresh
/coach/succession
/concubinage
/confidence
/couple
/couple/accept
/data-block/:type
/debt/help
/debt/ratio
/debt/repayment
/decaissement
/disability/gap
/disability/insurance
/disability/self-employed
/divorce
/document-scan
/document-scan/avs-guide
/documents
/documents/:id
/education/hub
/education/theme/:id
/epl
/expatriation
/explore
/explore/famille
/explore/fiscalite
/explore/logement
/explore/patrimoine
/explore/retraite
/explore/sante
/explore/travail
/first-job
/fiscal
/home
/household
/household/accept
/hypotheque
/independants/3a
/independants/avs
/independants/dividende-salaire
/independants/ijm
/independants/lpp-volontaire
/invalidite
/libre-passage
/life-event/deces-proche
/life-event/demenagement-cantonal
/life-event/divorce
/life-event/donation
/life-event/housing-sale
/life-event/succession
/lpp-deep/epl
/lpp-deep/libre-passage
/lpp-deep/rachat
/mariage
/mon-argent
/mortgage/affordability
/mortgage/amortization
/mortgage/epl-combined
/mortgage/imputed-rental
/mortgage/saron-vs-fixed
/naissance
/onboarding/enrichment
/onboarding/intent
/onboarding/minimal
/onboarding/plan
/onboarding/premier-eclairage
/onboarding/promise
/onboarding/quick
/onboarding/quick-start
/onboarding/smart
/open-banking
/open-banking/consents
/open-banking/transactions
/pilier-3a
/portfolio
/profile
/rachat-lpp
/rapport
/rente-vs-capital
/report
/report/v2
/retirement
/retirement/projection
/retraite
/scan
/scan/avs-guide
/scan/impact
/scan/review
/score-reveal
/segments/frontalier
/segments/gender-gap
/segments/independant
/settings/langue
/simulator/3a
/simulator/compound
/simulator/credit
/simulator/disability-gap
/simulator/job-comparison
/simulator/leasing
/simulator/rente-capital
/succession
/timeline
/tools
/unemployment
admin-analytics
admin-observability
bilan
byok
privacy
privacy-control
slm
```

Note: the final 7 rows (`admin-analytics`, `admin-observability`, `bilan`, `byok`, `privacy`,
`privacy-control`, `slm`) are children of `/profile` (declared as bare segments inside `routes: [...]` at
L913-948). Their runtime-composed paths are `/profile/admin-analytics`, `/profile/admin-observability`,
`/profile/bilan`, `/profile/byok`, `/profile/privacy`, `/profile/privacy-control`, `/profile/slm`. Wave 1
`kRouteRegistry` MUST register the composed form per CONTEXT v4 D-04 nested-route guidance.

## Known-miss patterns found (for D-04 KNOWN-MISSES.md)

Catalog from empirical grep on app.dart SHA b7a88cc8.

| Category | app.dart line(s) | Pattern snippet | Parity lint behavior |
|----------|------------------|-----------------|----------------------|
| Multi-line constructor (simple) | 281-285, 286-290, 291-295, 296-300, 301-305, 306-310, 315-319 (108 occurrences) | `ScopedGoRoute(\n      path: '/x',\n      ...\n    )` | DOTALL regex handles; captured correctly (147 total path extraction matches confirms) |
| Ternary path expression | **none observed** in HEAD-b7a88cc8 | `grep -E "path:\s*\w+\s*\?"` returns 0 hits | N/A — no occurrences to skip |
| Dynamic path builder | **none observed** in HEAD-b7a88cc8 | `grep -E "path:\s*_\w+\("` returns 0 hits | N/A — no occurrences to skip |
| Conditional route list (`if` inside `routes: [...]`) | **none observed** at route-list scope in HEAD-b7a88cc8 | `if` statements appear only inside redirect/builder callbacks, not at route-array scope | N/A |
| Nested `routes: [...]` (child prefix inheritance) | parent `/profile` L906-948 → 7 children (admin-observability L915, admin-analytics L921, byok L928, slm L932, bilan L936, privacy-control L940, privacy L945); parent `/` L325 branches Tab-0/1/2/3 at L333/372/382/409 | Children declared with bare segments; runtime prefixes parent path | Parity lint MUST either (a) register composed paths in kRouteRegistry OR (b) use `--resolve-nested` flag (Wave 4) |
| Multi-line constructor with block-form redirect | 870, 908-912, 914-918, 920-924, 1134-1135, 1141-1142, 1148-1149, 1163-1167 | `ScopedGoRoute(\n  path: '/x',\n  redirect: (context, state) { ... }\n)` | Path captured by DOTALL; redirect NOT counted as legacy (arrow-form regex rejects it — correct per MAP-05 scope) |

## Owner assignment pre-audit (D-01 v4 first-segment-wins)

Routes where first-segment-wins rule produces a non-obvious owner. All resolved per D-01 v4:

| Path | First segment | Potential owner ambiguity | D-01 v4 resolution |
|------|---------------|---------------------------|---------------------|
| `/explore/retraite` (L421) | `explore` | `retraite` enum value exists | owner=**explore** (cross-domain context = metadata only) |
| `/explore/famille` (L436) | `explore` | `famille` enum value exists | owner=**explore** |
| `/explore/travail` (L450) | `explore` | `travail` enum value exists | owner=**explore** |
| `/explore/logement` (L465) | `explore` | `logement` enum value exists | owner=**explore** |
| `/explore/fiscalite` (L481) | `explore` | `fiscalite` enum value exists | owner=**explore** |
| `/explore/patrimoine` (L496) | `explore` | `patrimoine` enum value exists | owner=**explore** |
| `/explore/sante` (L510) | `explore` | `sante` enum value exists | owner=**explore** |
| `/life-event/divorce` (L688) | `life-event` | `divorce` destination exists | owner=**life-event** (redirect shim, shim owner) |
| `/life-event/succession` (L583) | `life-event` | `succession` destination exists | owner=**life-event** |
| `/life-event/deces-proche`, `/life-event/demenagement-cantonal`, `/life-event/donation`, `/life-event/housing-sale` | `life-event` | event type matches destination concept | owner=**life-event** (destination, not redirect) |
| `/coach/chat`, `/coach/checkin`, `/coach/cockpit`, `/coach/dashboard`, `/coach/decaissement`, `/coach/history`, `/coach/refresh`, `/coach/succession`, `/coach/agir` | `coach` | coach is its own enum value | owner=**coach** (unambiguous) |
| `/simulator/3a`, `/simulator/rente-capital`, `/simulator/disability-gap`, `/simulator/compound`, `/simulator/credit`, `/simulator/job-comparison`, `/simulator/leasing` | `simulator` | second segment matches domain in some cases | owner=**simulator** |
| `/arbitrage/allocation-annuelle`, `/arbitrage/bilan`, `/arbitrage/calendrier-retraits`, `/arbitrage/location-vs-propriete`, `/arbitrage/rachat-vs-marche`, `/arbitrage/rente-vs-capital` | `arbitrage` | second segment matches domain | owner=**arbitrage** |
| `/lpp-deep/epl`, `/lpp-deep/libre-passage`, `/lpp-deep/rachat`, `/3a-deep/comparator`, `/3a-deep/real-return`, `/3a-deep/staggered-withdrawal` | `*-deep` | deep-dive family | owner=**\*-deep** (dedicated bucket per CONTEXT D-01 owner list) |
| `/independants/3a`, `/independants/avs`, `/independants/dividende-salaire`, `/independants/ijm`, `/independants/lpp-volontaire` | `independants` | segmentation-by-persona; second segment matches pillar | owner=**independants** |
| `/disability/gap`, `/disability/insurance`, `/disability/self-employed` | `disability` | disability = bucket | owner=**disability** |
| `/debt/help`, `/debt/ratio`, `/debt/repayment` | `debt` | debt = bucket | owner=**debt** |
| `/documents`, `/documents/:id`, `/document-scan`, `/document-scan/avs-guide`, `/scan`, `/scan/avs-guide`, `/scan/impact`, `/scan/review` | `documents` / `document-scan` / `scan` | first-segment already unambiguous | owner per first segment (no drift) |
| `/education/hub`, `/education/theme/:id` | `education` | education = bucket | owner=**education** |
| `/assurances/coverage`, `/assurances/lamal` | `assurances` | assurances = bucket | owner=**assurances** |
| `/mortgage/affordability`, `/mortgage/amortization`, `/mortgage/epl-combined`, `/mortgage/imputed-rental`, `/mortgage/saron-vs-fixed` | `mortgage` | mortgage = bucket | owner=**mortgage** |
| `/segments/frontalier`, `/segments/gender-gap`, `/segments/independant` | `segments` | segments = persona bucket | owner=**segments** |

No owner-ambiguity resolution drift from CONTEXT v4. Planner's 15-owner enum covers all observed first
segments. Note: the previously-listed `/univers/*` and `/*-deep` families beyond `/lpp-deep` and `/3a-deep`
are NOT in the current app.dart (stale references from prior CONTEXT drafts). Updated owner list reflects
empirically-observed first segments at HEAD-b7a88cc8.

## Scaffolding

Task 3 created 10 scaffold files at the paths mandated by plan frontmatter. Empirical smoke results:

### JSON fixture smoke
Command: `python3 -c "import json; d=json.load(open('tests/tools/fixtures/sentry_health_response.json')); assert d['_meta']['route_count']==147 and len(d['issues'])==147; print('OK')"`
Result: **OK** — fixture has `_meta.route_count == 147` AND `len(issues) == 147`.
Status distribution: 3 red (count_24h 15-17), 5 yellow (count_24h 2-6), 139 green (count_24h 0).

### Python pytest stub collection
Command: `python3 -m pytest tests/tools/test_mint_routes.py --collect-only -q`
Result: **12 tests collected in 0.01s** — every test has a non-empty `pytest.mark.skip(reason=...)`.

### Flutter stub compilation smoke
Command: `cd apps/mobile && flutter test test/routes/route_metadata_test.dart test/routes/route_meta_json_test.dart test/routes/legacy_redirect_breadcrumb_test.dart test/screens/admin/`
Result: **00:00 +0 ~17: All tests skipped.** — 17 test stubs across 6 files compile without analyzer errors; every stub skips with a reason pointing to its implementing Plan.

### Files created

| Path | Purpose |
|------|---------|
| `apps/mobile/test/routes/route_metadata_test.dart` | MAP-01 entry count + enum integrity stubs (4 tests) |
| `apps/mobile/test/routes/route_meta_json_test.dart` | MAP-01 JSON shape + schemaVersion stubs (2 tests) |
| `apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart` | MAP-05 breadcrumb stubs (2 tests, D-09 §2 redaction) |
| `apps/mobile/test/screens/admin/admin_shell_gate_test.dart` | MAP-02b gate (2 tests, D-10 ENABLE_ADMIN × isAdmin matrix) |
| `apps/mobile/test/screens/admin/routes_registry_screen_test.dart` | MAP-02b render (4 tests, 147 × 15 buckets) |
| `apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart` | D-09 §4 admin-access breadcrumb (3 tests, aggregates only) |
| `tests/tools/test_mint_routes.py` | 12 pytest stubs for MAP-02a CLI (3.9-compatible) |
| `tests/tools/fixtures/sentry_health_response.json` | 147-route DRY_RUN fixture |
| `tests/checks/fixtures/parity_drift.dart` | Parity lint drift fixture (Wave 4 consumes) |
| `tests/checks/fixtures/parity_known_miss.dart` | KNOWN-MISSES respect fixture (Wave 4 consumes) |

## Verdict

- [x] Counts match CONTEXT v4 — proceed to Wave 1
- [ ] Counts drift — STOP, amend CONTEXT first

Both empirical counts (147 routes, 43 redirects) match CONTEXT v4 exactly. No drift. Wave 0 scaffolding
proceeds as planned. Plan 03 Task 2 breadcrumb coverage contract published (43 call-sites × 1 branch each =
43 expected `MintBreadcrumbs.legacyRedirectHit` invocations post-Wave-3).
