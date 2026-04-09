---
phase: 01-architectural-foundation
plan: 01b
subsystem: testing
tags: [flutter-test, gorouter, scope, dfs, tarjan, golden-file, doctrine-lint]

requires:
  - phase: 01-01a
    provides: ScopedGoRoute, RouteScope enum, scope-based redirect guard, 144 migrated routes
provides:
  - 5 mechanical CI gate tests in test/architecture/
  - 3 would-have-fired fixture tests proving gates detect v2.2 P0 bugs
  - route_guard_snapshot.golden.txt baseline (151 routes)
  - Bug 2 fix in coach_chat_screen.dart (payload guard)
affects: [01-01c, phase-02-deletion-spree, ci-pipeline]

tech-stack:
  added: []
  patterns: [source-file-parsing-tests, tarjan-scc, golden-snapshot-testing, doctrine-lint-scanning]

key-files:
  created:
    - apps/mobile/test/architecture/route_cycle_test.dart
    - apps/mobile/test/architecture/route_scope_leak_test.dart
    - apps/mobile/test/architecture/route_payload_consumption_test.dart
    - apps/mobile/test/architecture/route_guard_snapshot_test.dart
    - apps/mobile/test/architecture/route_doctrine_lint_test.dart
    - apps/mobile/test/architecture/route_guard_snapshot.golden.txt
    - apps/mobile/test/architecture/fixtures/would_have_fired_cycle_test.dart
    - apps/mobile/test/architecture/fixtures/would_have_fired_scope_leak_test.dart
    - apps/mobile/test/architecture/fixtures/would_have_fired_payload_test.dart
  modified:
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart

key-decisions:
  - "Source-file parsing over runtime introspection: tests parse app.dart as text since _router is private"
  - "Raw legal refs allowed in ARB files: disclaimer/source/body strings MUST cite articles per CLAUDE.md compliance"
  - "Bug 2 fix applied inline: added entryPayload/initialPrompt checks to !_hasProfile guard"
  - "2 pre-existing garanti violations tracked as known count, not hard-fail"

patterns-established:
  - "Architecture gate tests: source-file-parsing approach for testing private router structure"
  - "Golden snapshot: deterministic route-scope baseline for drift detection"
  - "Known-violation tracking: pre-existing violations tracked by count, new violations fail"

requirements-completed: [GATE-01, GATE-02, GATE-03, GATE-04, GATE-05]

duration: 14min
completed: 2026-04-09
---

# Plan 01-01b: 5 Mechanical CI Gate Tests + Would-Have-Fired Fixtures Summary

**5 architecture gate tests (25 assertions) + 3 fixture proofs catching v2.2 P0 bug patterns, plus Bug 2 payload short-circuit fix**

## Performance

- **Duration:** ~14 min
- **Started:** 2026-04-09T11:09:42Z
- **Completed:** 2026-04-09T11:23:24Z
- **Tasks:** 6 (5 gates + 1 fixture bundle)
- **Files modified:** 11

## Accomplishments

- GATE-01: Route cycle DFS with Tarjan SCC algorithm — detects any cycle in the GoRouter tree
- GATE-02: Scope leak detection — catches child routes with lower scope than parent, verifies /onboarding/ and /auth/ scope consistency
- GATE-03: Payload consumption structural analysis — detects Bug 2 pattern (short-circuit before payload read), PLUS fixed the actual bug in coach_chat_screen.dart
- GATE-04: Route guard golden snapshot — 151 routes baselined, any unreviewed scope change fails the test
- GATE-05: Doctrine string lint — scans ARB + screen files for compliance absolutes, internal naming leaks, social comparison, banned tone, gamified framing
- 3 would-have-fired fixtures proving gates detect the exact v2.2 P0 bug patterns (cycle, scope leak, payload short-circuit)

## Task Commits

1. **GATE-01: Route cycle DFS** - `e90298d9` (test)
2. **GATE-02: Scope leak detection** - `ce97596f` (test + fix: 7 onboarding redirect scopes)
3. **GATE-03: Payload consumption** - `db351c83` (test + fix: Bug 2 guard in coach_chat_screen.dart)
4. **GATE-04: Route guard snapshot + golden** - `e1d922b4` (test)
5. **GATE-05: Doctrine string lint** - `18ec4ce1` (test)
6. **Would-have-fired fixtures** - `e28910fa` (test)

## Files Created/Modified

- `test/architecture/route_cycle_test.dart` — DFS + Tarjan SCC cycle detection (186 LOC)
- `test/architecture/route_scope_leak_test.dart` — Scope hierarchy invariant checks (284 LOC)
- `test/architecture/route_payload_consumption_test.dart` — Structural Bug 2 pattern detection (184 LOC)
- `test/architecture/route_guard_snapshot_test.dart` — Golden snapshot comparison (185 LOC)
- `test/architecture/route_guard_snapshot.golden.txt` — 151-route baseline
- `test/architecture/route_doctrine_lint_test.dart` — Banned term scanner (360 LOC)
- `test/architecture/fixtures/would_have_fired_cycle_test.dart` — Cycle fixture
- `test/architecture/fixtures/would_have_fired_scope_leak_test.dart` — Scope leak fixture
- `test/architecture/fixtures/would_have_fired_payload_test.dart` — Payload fixture
- `apps/mobile/lib/app.dart` — Added scope: RouteScope.onboarding to 7 redirect shims
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — Bug 2 fix: compound guard

## Decisions Made

1. **Source-file parsing over runtime introspection** — The `_router` in app.dart is a private top-level variable, inaccessible from tests. Tests parse app.dart as text using regex to extract route declarations. This is pragmatic and sufficient for structural invariant checking.
2. **Raw legal references allowed in ARB** — CLAUDE.md compliance rules REQUIRE legal article citations in disclaimer/source strings. The doctrine lint skips raw-legal-reference category for ARB files entirely.
3. **Known pre-existing violation count** — 2 "garanti" uses in app_fr.arb are pre-existing compliance violations. GATE-05 tracks the count and fails only if NEW violations appear.
4. **Bug 2 fix applied inline** — GATE-03 detected the actual Bug 2 pattern in coach_chat_screen.dart. Per plan instructions ("fix the bug, don't skip the test"), added `widget.entryPayload == null && widget.initialPrompt == null` to the `!_hasProfile` guard.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed 7 onboarding redirect shims missing scope declaration**
- **Found during:** Task 2 (GATE-02 scope leak detection)
- **Issue:** `/onboarding/quick-start`, `/onboarding/premier-eclairage`, `/onboarding/promise`, `/onboarding/plan`, `/onboarding/smart`, `/onboarding/minimal`, `/onboarding/enrichment` defaulted to `RouteScope.authenticated` because they had no explicit scope
- **Fix:** Added `scope: RouteScope.onboarding` to all 7
- **Files modified:** apps/mobile/lib/app.dart
- **Committed in:** ce97596f

**2. [Rule 1 - Bug] Fixed Bug 2 payload short-circuit in coach_chat_screen.dart**
- **Found during:** Task 3 (GATE-03 payload consumption)
- **Issue:** `build()` method short-circuits on `!_hasProfile` WITHOUT checking `widget.entryPayload`, trapping users in CoachEmptyState loop
- **Fix:** Changed guard to `!_hasProfile && widget.entryPayload == null && widget.initialPrompt == null`
- **Files modified:** apps/mobile/lib/screens/coach/coach_chat_screen.dart
- **Committed in:** db351c83

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** Both fixes are directly related to the gates being tested. No scope creep.

## Issues Encountered

- GATE-05 initial implementation flagged 343 violations due to overly broad legal reference matching in ARB files. Refined to skip raw-legal-reference category for ARB content (legal citations are required, not banned, in disclaimer/source/educational strings).

## Known Stubs

None — all tests are fully functional, no placeholder logic.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All 5 mechanical CI gates green on current codebase
- Golden snapshot baseline committed (151 routes)
- Bug 2 payload fix applied — CoachEmptyState loop no longer traps users with valid payloads
- Ready for 01-01c (verification/proof-of-fire) and Phase 2 (deletion spree with gate safety net)

---
*Phase: 01-architectural-foundation*
*Completed: 2026-04-09*
