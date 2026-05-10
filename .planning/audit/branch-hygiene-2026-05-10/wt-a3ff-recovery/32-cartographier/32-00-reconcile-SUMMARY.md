---
phase: 32-cartographier
plan: 00
subsystem: infra
tags: [routing, go_router, testing, scaffolding, sentry, nlpd, reconciliation, wave-0]

# Dependency graph
requires:
  - phase: 31-instrumenter
    provides: SentryNavigatorObserver wired in app.dart L184 (D-07 foundation)
  - phase: 30.5-context-sanity
    provides: CLAUDE.md directives enforced via lefthook pre-commit
provides:
  - "147-route + 43-redirect empirical baseline (app.dart SHA b7a88cc8)"
  - "M-3 per-site breadcrumb coverage contract (43-row inventory) Plan 03 Task 2 consumes"
  - "KNOWN-MISSES.md catalog built from live grep evidence (6 categories, Wave 4 parity lint ground truth)"
  - "10 scaffolded test/fixture artefacts Wave 1-4 flip from skip to green incrementally"
  - "147-path authoritative list for Wave 1 kRouteRegistry"
  - "Owner Pre-audit covering all 15 owner buckets empirically (no ghost path references)"
affects:
  - 32-01 (MAP-01 registry implementation consumes 147-path list + owner pre-audit)
  - 32-02 (MAP-02a CLI consumes 12 pytest stubs + 147-route DRY_RUN fixture)
  - 32-03 (MAP-02b Flutter UI + MAP-05 breadcrumb wiring consumes test stubs + 43-row inventory contract)
  - 32-04 (MAP-04 parity lint consumes 2 Dart fixtures + KNOWN-MISSES.md)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Wave 0 scaffold pattern: skip-with-reason test stubs block compilation errors while allowing Wave N implementers to flip to live assertions (inherited from Phase 31-00)"
    - "M-3 per-site contract: enumerate call-sites with branch structure so downstream tests assert PER-SITE coverage, not fragile total grep counts"
    - "Empirical grep before registry write: extract ground truth from source before writing structured artefacts (inherited from Phase 31 Wave 0)"
    - "DOTALL regex extractor validated against simpler anchor-free `path:` regex on full app.dart — both return identical 147-path set"

key-files:
  created:
    - .planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md
    - tools/checks/route_registry_parity-KNOWN-MISSES.md
    - apps/mobile/test/routes/route_metadata_test.dart
    - apps/mobile/test/routes/route_meta_json_test.dart
    - apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart
    - apps/mobile/test/screens/admin/admin_shell_gate_test.dart
    - apps/mobile/test/screens/admin/routes_registry_screen_test.dart
    - apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart
    - tests/tools/test_mint_routes.py
    - tests/tools/fixtures/sentry_health_response.json
    - tests/checks/fixtures/parity_drift.dart
    - tests/checks/fixtures/parity_known_miss.dart
  modified: []

key-decisions:
  - "43 MAP-05 redirects = arrow-form `(_, __) => '...'` only; 9 block-form redirects classified as guards/FF-gates/param-passing, NOT legacy redirects"
  - "Single-branch by construction: all 43 redirect call-sites have exactly 1 redirect branch and 0 null-pass-through — expected total MintBreadcrumbs.legacyRedirectHit source-call count = 43 after Wave 3"
  - "KNOWN-MISSES Categories 2/3/4 empty in HEAD-b7a88cc8: team convention holds string-literal paths, no ternary/dynamic/route-array-conditional patterns exist today"
  - "Category 6 (block-form redirect) added beyond plan's 5 categories: documents the 9 non-legacy redirect call-sites so Wave 3 does not accidentally wire breadcrumbs there"
  - "Path extraction regex simplified from DOTALL-constrained `(?:GoRoute|ScopedGoRoute)\\s*\\([^)]*?path:` to permissive `path:\\s*(['\"])([^'\"]+)\\1` — both return 147 unique, permissive form more robust against future constructor shapes"
  - "Owner Pre-audit rewritten from hallucinated draft: removed /univers/*, /hypotheque-deep/*, /logement-deep/*, /rachat-lpp-deep/*, /simulator/retraite (ghost paths from stale CONTEXT drafts); now cites live app.dart line numbers"

patterns-established:
  - "Wave 0 scaffolding pattern: skip-with-reason stubs + per-test reason pointing to implementing Plan number (inherited from Phase 31-00, reused here)"
  - "Empirical contract publication: per-site inventory table replaces fragile total-count grep assertions (M-3 fix)"
  - "KNOWN-MISSES maintenance contract: drift from baseline 147/43 requires updating RECONCILE-REPORT + KNOWN-MISSES + test assertions in single commit"

requirements-completed: [MAP-01, MAP-04, MAP-05]

# Metrics
duration: 14 min
completed: 2026-04-20
---

# Phase 32 Plan 00: Reconcile Summary

**Empirical 147-route + 43-redirect baseline locked against app.dart HEAD-b7a88cc8, M-3 per-site breadcrumb contract published, 10 Wave 0 scaffolds block no Wave 1-4 compilation errors.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-04-20T07:36:36Z
- **Completed:** 2026-04-20T07:50:42Z
- **Tasks:** 3
- **Files created:** 12 (1 report + 1 KNOWN-MISSES + 6 Flutter stubs + 1 Python stub + 1 JSON fixture + 2 Dart fixtures)
- **Files modified:** 0

## Accomplishments

- Empirical grep confirmed **147 GoRoute/ScopedGoRoute** entries + **43 arrow-form redirects** in `apps/mobile/lib/app.dart` — zero drift from CONTEXT v4.
- Published **43-row Redirect Call-Site Inventory** (M-3 fix): per-site line number, source pattern, target, branch structure. Plan 03 Task 2 asserts breadcrumb coverage against this contract, not a fragile total-count grep.
- Classified **9 non-legacy redirects** (guards / FF-gates / param-passing) separately — Wave 3 does not wire `MintBreadcrumbs.legacyRedirectHit` at those sites.
- Populated **KNOWN-MISSES.md** with 6 categories from live evidence (not speculation): Categories 2/3/4 empty in HEAD, Category 5 enumerates 6 nested-route parent sites, Category 6 added to document the 9 block-form redirects.
- Shipped **10 scaffold artefacts** (6 Flutter test stubs × 17 test cases + 1 Python pytest stub × 12 test cases + 1 JSON fixture × 147 entries + 2 Dart parity fixtures). Smoke: `flutter test` → 17 skipped, 0 failures. `pytest --collect-only` → 12 tests collected. JSON `_meta.route_count == 147` AND `len(issues) == 147`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Empirical reconciliation grep + 43-row redirect inventory + RECONCILE-REPORT.md** — `cb124aff` (docs)
2. **Task 2: Populate KNOWN-MISSES.md from real app.dart patterns** — `160cb063` (docs)
3. **Task 3: Scaffold 6 Flutter + 1 Python + 3 fixture files + fix RECONCILE-REPORT path-list accuracy** — `1de6d61e` (test)

_Plan metadata commit follows this SUMMARY._

## Files Created/Modified

### Created

- `.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md` — empirical counts, 43-row redirect inventory, 147-path authoritative list, 6-category known-miss catalog, owner pre-audit, scaffolding results, verdict
- `tools/checks/route_registry_parity-KNOWN-MISSES.md` — 6 categories (Multi-line ctor / Ternary / Dynamic / Conditional / Nested / Block-form redirect) + Maintenance Policy
- `apps/mobile/test/routes/route_metadata_test.dart` — 4 skip-stubs for MAP-01 entry count + enum integrity (Wave 1)
- `apps/mobile/test/routes/route_meta_json_test.dart` — 2 skip-stubs for MAP-01 JSON shape + schemaVersion (Wave 2)
- `apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart` — 2 skip-stubs for MAP-05 breadcrumb + D-09 §2 redaction (Wave 3)
- `apps/mobile/test/screens/admin/admin_shell_gate_test.dart` — 2 skip-stubs for D-10 gate matrix (Wave 3)
- `apps/mobile/test/screens/admin/routes_registry_screen_test.dart` — 4 skip-stubs for MAP-02b render 147×15 (Wave 3)
- `apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart` — 3 skip-stubs for D-09 §4 admin breadcrumb (Wave 3)
- `tests/tools/test_mint_routes.py` — 12 `pytest.mark.skip` stubs for MAP-02a CLI, 3.9-compatible (Wave 2)
- `tests/tools/fixtures/sentry_health_response.json` — 147-entry DRY_RUN fixture, deterministic status distribution (3 red / 5 yellow / 139 green)
- `tests/checks/fixtures/parity_drift.dart` — drift test case (Wave 4 parity lint exits non-zero)
- `tests/checks/fixtures/parity_known_miss.dart` — KNOWN-MISSES respect case (Wave 4 parity lint exits 0)

## Decisions Made

- **43 != 52 redirect count**: Arrow-form `(_, __) => '/target'` is the MAP-05 scope. The 9 block-form `(context, state) { ... }` redirects are guards / feature-flag gates / param-passing redirects, NOT legacy redirects. They emit no `mint.routing.legacy_redirect.hit` breadcrumb.
- **Single-branch contract**: All 43 legacy redirects are single-branch, non-null, arrow-form by construction. Expected total `MintBreadcrumbs.legacyRedirectHit` source-call count = 43 after Wave 3 (not >= 43 as a loose bound).
- **Category 6 added to KNOWN-MISSES**: Plan specified 5 categories; I added a 6th to document the 9 block-form redirect sites. Parity lint doesn't need special handling but future maintainers benefit from knowing those sites are intentional non-legacy redirects.
- **Permissive path-extraction regex**: Simpler `path:\s*(['"])([^'"]+)\1` returns the same 147-path set as the DOTALL-constrained `(?:GoRoute|ScopedGoRoute)\s*\([^)]*?path:` regex. Chose simpler form for Wave 4 parity lint (less surface area for future constructor shape drift).
- **Owner Pre-audit rewritten**: Initial draft hallucinated `/univers/*`, `/hypotheque-deep/*`, `/logement-deep/*`, `/rachat-lpp-deep/*`, `/simulator/retraite` references (stale paths from prior CONTEXT drafts). Corrected by diffing against authoritative 147-path extractor output. Net-new coverage: `/disability`, `/debt`, `/independants`, `/mortgage`, `/assurances`, `/education`, `/segments`, `/scan`, `/document-scan`, `/documents`.
- **147-path list corrected mid-execution**: Report's initial embedded path list had 51 ghost paths + 52 missing paths (hallucinated draft, not from regex output). Fixed in Task 3 commit alongside scaffolding — single atomic repair.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Embedded path list inaccuracy in RECONCILE-REPORT.md**
- **Found during:** Task 3 acceptance-criteria verification (path-list line count 145 vs required ≥147)
- **Issue:** Initial Task 1 draft's embedded 147-path list was hand-written from memory rather than regex-extracted — contained 51 ghost paths (/journal, /memoire, /fiscalite, /univers/*, etc. that don't exist in app.dart HEAD-b7a88cc8) and was missing 52 real paths (/anonymous/chat, /arbitrage/allocation-annuelle, /debt/*, /independants/*, /mortgage/amortization, etc.)
- **Fix:** Regenerated authoritative 147-path list from permissive regex `path:\s*(['"])([^'"]+)\1` against live app.dart, replaced the embedded list, rewrote Owner Pre-audit to remove ghost references and add net-new buckets (disability/debt/independants/mortgage/assurances/education/segments/scan/document-scan/documents)
- **Files modified:** `.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md`
- **Verification:** `awk '/^```$/{c++; next} c==1' 32-00-RECONCILE-REPORT.md | wc -l` = 147 exact. Owner Pre-audit entries all carry app.dart line citations (grep-verified).
- **Committed in:** `1de6d61e` (part of Task 3 commit)

**2. [Rule 2 - Missing Critical] Category 6 added to KNOWN-MISSES.md**
- **Found during:** Task 2 (populating catalog)
- **Issue:** Plan specified 5 categories. The 9 block-form redirects at app.dart L194/870/908/916/922/1134/1141/1148/1163 are NOT legacy redirects (they are guards/FF-gates/param-passing) and would be incorrectly wired with `MintBreadcrumbs.legacyRedirectHit` if Wave 3 doesn't know they're excluded. Without explicit documentation, a future maintainer could wire them up.
- **Fix:** Added Category 6 "Block-form redirect callbacks (NOT legacy redirects)" enumerating all 9 sites with their purpose (scope guard, FF gate, param-passing). Wave 3 now has explicit guidance that breadcrumb wiring targets only the 43 arrow-form sites in RECONCILE-REPORT.md §Redirect Call-Site Inventory.
- **Files modified:** `tools/checks/route_registry_parity-KNOWN-MISSES.md`
- **Verification:** `grep -c "^## Category [0-9]" KNOWN-MISSES.md` = 6. Content verified against empirical grep of `redirect:` patterns in app.dart.
- **Committed in:** `160cb063`

---

**Total deviations:** 2 auto-fixed (1 bug [stale-data hallucination], 1 missing critical [non-legacy redirect documentation]).
**Impact on plan:** Both auto-fixes essential for correctness. Path-list drift would have broken Wave 1 kRouteRegistry population (missing routes cause /home splash crash; ghost routes cause registry vs app.dart parity lint fail). Category 6 absence would have caused Wave 3 to wire breadcrumbs at 9 non-legacy sites, polluting the Phase 35 redirects analytics.

## Intentional Wave 0 Stubs

The 10 scaffold files are intentional stubs by plan design (Wave 0 scaffolding pattern). They block no Wave 1-4 progress because:

- All Flutter tests use `skip: 'Plan 32-XX Wave N ...'` with a non-empty reason — compile green, report as "skipped" in `flutter test`
- All Python tests use `@pytest.mark.skip(reason=...)` — collect green, report as "skipped" in pytest
- JSON fixture is live data (147 entries, no placeholder values)
- Dart parity fixtures are valid Dart (use `// ignore_for_file:` to silence unused warnings)

Each stub's reason explicitly names the implementing Plan (e.g., `Plan 32-03 Wave 3 wires legacyRedirectHit in app.dart`). Wave N flips `skip:` to live assertion as production code lands. This mirrors the Phase 31-00 Wave 0 scaffolding pattern (17/17 Flutter + pytest stubs flipped green across Waves 1-4 of Phase 31).

## Known Stubs

None. Every scaffolded stub has an explicit `skip:` reason pointing to its Wave N implementer. No façade-sans-câblage risk — the stubs are scaffolds (test scaffolds, not UI stubs), which is the explicit plan design.

## Threat Flags

None. Wave 0 produces markdown reports + test scaffolds only; no production code, no new network endpoints, no file access at trust boundaries. Threats T-32-01..05 enter at Waves 1-4.

## Issues Encountered

- **Path-list drift (resolved)**: My Task 1 draft's embedded 147-path list was hand-written instead of regex-extracted, contained 51 ghosts and was missing 52 real paths. Caught during Task 3 acceptance-criteria verify (`wc -l` = 145 instead of 147). Fixed in single atomic Task 3 commit.
- **Committer identity warning (non-blocking)**: git reports `Committer: Julien <julienbattaglia@Juliens-Mac-mini.local>` with a suggestion to set user.name/user.email. Not my scope to modify git config per `feedback_worktree_merge_protocol` + agent rules. Author/co-author trailer correctly carries Claude signature.

## User Setup Required

None — no external service configuration required for Wave 0.

## Next Phase Readiness

**Wave 1 (Plan 32-01) unblocked.** Consumes from this plan:
- 147-path authoritative list (RECONCILE-REPORT §Extracted paths) → populate `kRouteRegistry`
- Owner Pre-audit table (RECONCILE-REPORT §Owner assignment) → assign 15-owner bucket per route
- Stubs `route_metadata_test.dart` + `route_meta_json_test.dart` — flip `skip:` to live assertions
- Nested-route guidance (Category 5 of KNOWN-MISSES) → register composed paths for 7 `/profile/*` children

**Wave 2 (Plan 32-02) unblocked.** Consumes: 12 pytest stubs + 147-route DRY_RUN fixture + Category 6 redirect exclusion list.

**Wave 3 (Plan 32-03) unblocked.** Consumes: 43-row Redirect Call-Site Inventory (exact per-site breadcrumb contract) + 9-site non-legacy exclusion list (Category 6) + 3 admin screen test stubs.

**Wave 4 (Plan 32-04) unblocked.** Consumes: KNOWN-MISSES.md catalog + 2 Dart parity fixtures.

**No blockers. No concerns.** Single atomic commit sequence per plan `<verification>` section (cb124aff → 160cb063 → 1de6d61e).

## Self-Check: PASSED

File existence + commit existence verified:

- `.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md` — FOUND
- `tools/checks/route_registry_parity-KNOWN-MISSES.md` — FOUND
- `apps/mobile/test/routes/route_metadata_test.dart` — FOUND
- `apps/mobile/test/routes/route_meta_json_test.dart` — FOUND
- `apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart` — FOUND
- `apps/mobile/test/screens/admin/admin_shell_gate_test.dart` — FOUND
- `apps/mobile/test/screens/admin/routes_registry_screen_test.dart` — FOUND
- `apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart` — FOUND
- `tests/tools/test_mint_routes.py` — FOUND
- `tests/tools/fixtures/sentry_health_response.json` — FOUND
- `tests/checks/fixtures/parity_drift.dart` — FOUND
- `tests/checks/fixtures/parity_known_miss.dart` — FOUND
- Commit `cb124aff` — FOUND
- Commit `160cb063` — FOUND
- Commit `1de6d61e` — FOUND

---

*Phase: 32-cartographier*
*Plan: 00-reconcile*
*Completed: 2026-04-20*
