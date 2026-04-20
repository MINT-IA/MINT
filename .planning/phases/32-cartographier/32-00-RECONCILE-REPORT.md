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
`(?:GoRoute|ScopedGoRoute)\s*\([^)]*?path\s*:\s*(['"])([^'"]+)\1` (DOTALL). Note: nested child routes inside
`routes: [...]` blocks carry a path literal that is a segment (e.g., `admin-observability`, `byok`) — their
runtime-composed path is parent + child (e.g., `/profile/admin-observability`). The raw list below captures
declared path literals AS-WRITTEN.

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
/anonymous-chat
/arbitrage/calendrier-retraits
/arbitrage/rachat-vs-marche
/arbitrage/rente-vs-capital
/ask-mint
/auth/login
/auth/register
/bank-import
/budget
/coach/agir
/coach/checkin
/coach/chat
/coach/cockpit
/coach/dashboard
/coach/decaissement
/coach/refresh
/coach/succession
/connection-error
/couple
/couple/accept
/decaissement
/disability/gap
/divorce
/document-scan
/document-scan/avs-guide
/epl
/explore
/explore/famille
/explore/fiscalite
/explore/logement
/explore/patrimoine
/explore/retraite
/explore/sante
/explore/travail
/expose/fri
/expose/nav
/expose/snapshot
/facts
/fiscalite
/fiscalite/deductions/3a
/fiscalite/declaration
/fiscalite/lance-moi
/frais-caches
/habits
/home
/household
/household/accept
/hypotheque
/hypotheque-deep/amort-vs-3a
/hypotheque-deep/fiscalite
/hypotheque-deep/renewal
/hypotheque-deep/sarona
/hypotheque-deep/taux-mix
/invalidite
/journal
/libre-passage
/life-event/divorce
/life-event/succession
/logement-deep/renovation
/logement-deep/residence
/logement-deep/vente
/lpp-deep/epl
/lpp-deep/libre-passage
/lpp-deep/rachat
/memoire
/mode-survie
/mon-argent
/mortgage/affordability
/nouveau-job
/objectif/:id
/objectifs
/objectifs/famille
/objectifs/liberte
/objectifs/maison
/objectifs/retraite
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
/parental-sharing
/pension
/pilier-3a
/portfolio
/premier-lancement
/profile
/rachat-lpp
/rachat-lpp-deep/simulateur
/rapport
/rente-vs-capital
/report
/report/v2
/retirement
/retirement/projection
/retraite
/retraite/settings
/rythme-mensuel
/scan
/scan/avs-guide
/score-reveal
/segments/expat-perspective
/segments/gender-gap
/segments/life-phases
/segments/tenant-dashboard
/semester-preview
/seuils
/simulator/3a
/simulator/disability-gap
/simulator/rente-capital
/simulator/retraite
/situation-check
/succession
/timeline-vie
/tools
/univers
/univers/famille
/univers/fiscalite
/univers/logement
/univers/travail
/verite-financiere
/voix-rassurance
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
| `/explore/retraite` | `explore` | `retraite` enum value exists | owner=**explore** (cross-domain context = metadata only) |
| `/explore/famille` | `explore` | `famille` enum value exists | owner=**explore** |
| `/explore/travail` | `explore` | `travail` enum value exists | owner=**explore** |
| `/explore/logement` | `explore` | `logement` enum value exists | owner=**explore** |
| `/explore/fiscalite` | `explore` | `fiscalite` enum value exists | owner=**explore** |
| `/explore/patrimoine` | `explore` | `patrimoine` enum value exists | owner=**explore** |
| `/explore/sante` | `explore` | `sante` enum value exists | owner=**explore** |
| `/univers/famille` | `univers` | `famille` enum value exists | owner=**univers** |
| `/univers/fiscalite` | `univers` | `fiscalite` enum value exists | owner=**univers** |
| `/univers/logement` | `univers` | `logement` enum value exists | owner=**univers** |
| `/univers/travail` | `univers` | `travail` enum value exists | owner=**univers** |
| `/life-event/divorce` | `life-event` | `divorce` destination exists | owner=**life-event** (redirect shim, shim owner) |
| `/life-event/succession` | `life-event` | `succession` destination exists | owner=**life-event** |
| `/coach/chat`, `/coach/checkin`, `/coach/dashboard`, ... | `coach` | coach is its own enum value | owner=**coach** (unambiguous) |
| `/simulator/3a`, `/simulator/rente-capital`, `/simulator/disability-gap`, `/simulator/retraite` | `simulator` | second segment matches domain | owner=**simulator** |
| `/arbitrage/*` | `arbitrage` | second segment matches domain | owner=**arbitrage** |
| `/lpp-deep/*`, `/3a-deep/*`, `/hypotheque-deep/*`, `/logement-deep/*`, `/rachat-lpp-deep/*` | `*-deep` | deep-dive family | owner=**\*-deep** (dedicated bucket per CONTEXT D-01 owner list) |

No owner-ambiguity resolution drift from CONTEXT v4. Planner's 15-owner enum covers all observed first
segments.

## Scaffolding

Task 3 results appended after scaffold creation (section reserved).

## Verdict

- [x] Counts match CONTEXT v4 — proceed to Wave 1
- [ ] Counts drift — STOP, amend CONTEXT first

Both empirical counts (147 routes, 43 redirects) match CONTEXT v4 exactly. No drift. Wave 0 scaffolding
proceeds as planned. Plan 03 Task 2 breadcrumb coverage contract published (43 call-sites × 1 branch each =
43 expected `MintBreadcrumbs.legacyRedirectHit` invocations post-Wave-3).
