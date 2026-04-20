# Route Registry Parity — Known Regex Misses

Purpose: document every `GoRoute`/`ScopedGoRoute` path declaration in `apps/mobile/lib/app.dart`
that `tools/checks/route_registry_parity.py` intentionally skips because its regex cannot
safely extract the path without a full Dart AST parser.

Parity lint contract: paths listed here are **silently ignored** — they are not treated
as missing from `kRouteRegistry`. Maintainers MUST update this file when a new unparsable
pattern is introduced, or the parity lint gate will false-positive and block CI.

Baseline: app.dart SHA `b7a88cc8` (Phase 32 Wave 0 reconciliation, 2026-04-20). Raw counts
at baseline: 147 `GoRoute`/`ScopedGoRoute` entries, 43 arrow-form redirects, 108
multi-line-constructor-with-opener-on-own-line entries (all parseable via DOTALL). See
`.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md` for full per-site inventory.

## Category 1 — Multi-line constructor with intervening comments

The `re.DOTALL` flag handles simple multi-line cases. If a comment block sits between
`(` and `path:` with a `)` literal inside a string, the regex may truncate early.

Current occurrences:
- none observed in HEAD-b7a88cc8. All 108 multi-line constructor entries in app.dart use a
  consistent shape (`ScopedGoRoute(\n      path: '/x',\n      ...\n    ),`) that DOTALL
  captures without truncation. Spot-check at L281-319 (7 simple entries), L325 (StatefulShellRoute
  wrapping 4 tab branches at L332/371/381/409), L862 (`/couple/accept` builder form), L876
  (`/rapport` builder form) all parse correctly into the 147-path extracted list.

## Category 2 — Ternary path expression

Regex cannot trace `path: isNew ? '/v2' : '/legacy'`.

Current occurrences:
- none observed in HEAD-b7a88cc8. `grep -E "path:\s*\w+\s*\?" apps/mobile/lib/app.dart`
  returns 0 matches. Team convention to date keeps path literals as string constants.

## Category 3 — Dynamic path builder

Regex cannot trace `path: _buildPath(segment)` or similar function-call expressions.

Current occurrences:
- none observed in HEAD-b7a88cc8. `grep -E "path:\s*_\w+\(" apps/mobile/lib/app.dart`
  returns 0 matches. No helper-generated paths currently in use.

## Category 4 — Conditional route list (if/else branch containing GoRoute)

The route is captured, but the conditional context is lost. Parity lint treats as
"exists". Acceptable per D-04.

Current occurrences:
- none observed at route-array scope in HEAD-b7a88cc8. `if` statements do appear inside
  builder/redirect callbacks (e.g., L209 inside root redirect, L226 inside /home builder
  redirect chain, L273 inside login redirect branch, L340/813/826/881 inside builder
  bodies). These do not affect path extraction because they occur after the path literal
  is already declared. Route-list-level conditional branches like
  `if (kDebug) GoRoute(path: '/x', ...)` are not used in the codebase.

## Category 5 — Nested `routes: [...]` inside parent `ScopedGoRoute` / `GoRoute`

Parent route's own `path:` is captured normally; nested children inherit prefix at
runtime (e.g., `/profile` + `admin-observability` -> `/profile/admin-observability`).
Parity lint treats nested entries as plain paths when `path: 'admin-observability'`
is declared under a parent with `path: '/profile'`. Maintainers MUST register the full
composed path in `kRouteRegistry` (e.g., `/profile/admin-observability`) — the
parity lint has a hint mode for this (see `--resolve-nested` flag, Wave 4).

Current occurrences (6 nested-route sites at HEAD-b7a88cc8):

- **Parent L906 `ScopedGoRoute(path: '/profile', ...)`** -> 7 children at L913-948:
  - L915 `path: 'admin-observability'` -> runtime `/profile/admin-observability`
  - L921 `path: 'admin-analytics'` -> runtime `/profile/admin-analytics`
  - L928 `path: 'byok'` -> runtime `/profile/byok`
  - L932 `path: 'slm'` -> runtime `/profile/slm`
  - L936 `path: 'bilan'` -> runtime `/profile/bilan`
  - L940 `path: 'privacy-control'` -> runtime `/profile/privacy-control`
  - L945 `path: 'privacy'` -> runtime `/profile/privacy`

- **Parent L325 `StatefulShellRoute.indexedStack(...)` shell** -> 4 branches with nested GoRoute:
  - L333 `routes: [ GoRoute(path: '/home', ...) ]` (Tab 0 — path already absolute, no prefix composition)
  - L372 `routes: [ GoRoute(path: '/mon-argent', ...) ]` (Tab 1 — absolute path)
  - L382 `routes: [ ScopedGoRoute(path: '/coach/chat', ...) ]` (Tab 2 — absolute path)
  - L409 `routes: [ GoRoute(path: '/explore', ...) ]` (Tab 3 — absolute path)

  Shell branches declare children with absolute paths (leading `/`), not segments, so they
  do NOT require composition. Parity lint treats them as standalone entries — correct.

## Category 6 — Block-form redirect callbacks (NOT legacy redirects)

Block-form `redirect: (context, state) { ... }` and `(_, state) => ...` callbacks are
used for guards, feature-flag gates, and parameter-passing redirects. They do NOT count
as MAP-05 legacy redirects and MUST NOT emit `MintBreadcrumbs.legacyRedirectHit`. The
parity lint does not need to handle them specially — they declare a path literal like
any other route.

Current occurrences (9 sites at HEAD-b7a88cc8):
- L194 root `GoRouter.redirect:` — scope-based auth guard (no path literal; not a route)
- L870 `/household/accept` — param-passing redirect (forwards `?code=` to `/couple/accept`)
- L908 `/profile` — sub-route pass-through guard (returns null when path != `/profile`)
- L916 `/profile/admin-observability` — `FeatureFlags.enableAdminScreens` gate
- L922 `/profile/admin-analytics` — `FeatureFlags.enableAdminScreens` gate
- L1134 `/open-banking` — `FeatureFlags.enableOpenBanking` gate
- L1141 `/open-banking/transactions` — `FeatureFlags.enableOpenBanking` gate
- L1148 `/open-banking/consents` — `FeatureFlags.enableOpenBanking` gate
- L1163 `/advisor/wizard` — param-passing redirect (forwards `?section=` to `/coach/chat?topic=`)

Plan 03 Task 2 asserts breadcrumb coverage is >= 43 (the arrow-form count), NOT 52 (all
redirects). Wave 3 breadcrumb wiring targets only the 43 sites in
`.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md §Redirect Call-Site Inventory`.

## Maintenance policy

When `tools/checks/route_registry_parity.py` reports an unexpected miss on `main`:
1. Reproduce locally: `python3 tools/checks/route_registry_parity.py`.
2. Classify the pattern into a category above (or add a new numbered category).
3. Append the snippet with file:line reference.
4. Re-run the lint; it should exit 0.
5. Commit `KNOWN-MISSES.md` change + production change together.

When raw counts drift from baseline (147 routes, 43 arrow-form redirects):
1. Re-run Phase 32 Wave 0 greps:
   - `grep -cE "^\s*(GoRoute|ScopedGoRoute)\(" apps/mobile/lib/app.dart`
   - `grep -cE "redirect:\s*\(_,\s*_?_?\)" apps/mobile/lib/app.dart`
2. Update `kRouteRegistry` length assertion in
   `apps/mobile/test/routes/route_metadata_test.dart` to match new count.
3. If new arrow-form redirects added: append rows to RECONCILE-REPORT.md Redirect
   Call-Site Inventory AND wire `MintBreadcrumbs.legacyRedirectHit` at the new site(s).
4. If new nested child added under an existing parent: add to Category 5 list above.
