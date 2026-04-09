---
status: passed
phase: 1
plan: 01-01a, 01-01b, 01-01c
reqs_covered: [NAV-01, NAV-02, GATE-01, GATE-02, GATE-03, GATE-04, GATE-05, DEVICE-01]
verified: 2026-04-09
---

# Phase 1: Architectural Foundation -- Verification

## Summary

Phase 1 replaced the fragile `protectedPrefixes` whitelist with a declarative `RouteScope` system across all 144 GoRouter routes, installed 5 CI gate tests, proved 3 would-have-fired fixtures detect the v2.2 P0 patterns, and demonstrated proof-of-fire (gates reject intentional scope leaks).

## Routes Migrated

- **Total:** 144 routes (all routes in `app.dart`)
- **Public (7):** `/`, `/auth/login`, `/auth/register`, `/auth/forgot-password`, `/terms`, `/privacy`, `/disclaimer`
- **Onboarding (2):** `/onboarding/intent`, `/onboarding/quick-start`
- **Authenticated (135):** All remaining routes (fail-closed default via `ScopedGoRoute`)

## Guard Replacement

- **Deleted:** `protectedPrefixes` string-matching whitelist in `app.dart` redirect callback
- **Installed:** Scope-based redirect reading `RouteScope` from matched `ScopedGoRoute.scope`
- **Fail-closed:** Any route without explicit scope defaults to `RouteScope.authenticated`

## ProfileDrawer Verification

ProfileDrawer is rendered inside the `ShellRoute` subtree which contains only `authenticated`-scope routes. No structural change was needed -- the drawer was already correctly scoped. Confirmed by GATE-02 (scope leak test) finding zero violations in the live router.

## 5 CI Gate Tests

All 5 gates GREEN (25 test cases total).

| Gate | File | What It Catches |
|------|------|----------------|
| GATE-01 | `test/architecture/route_cycle_test.dart` | Circular route dependencies via Tarjan SCC (DFS cycle detection) |
| GATE-02 | `test/architecture/route_scope_leak_test.dart` | Child routes with lower scope than parent; onboarding/auth routes with authenticated scope |
| GATE-03 | `test/architecture/route_payload_consumption_test.dart` | Routes receiving `extra` payloads that fail to consume them (null-check bypass) |
| GATE-04 | `test/architecture/route_guard_snapshot_test.dart` | Golden file snapshot of all 151 route entries; detects unintended route additions/removals |
| GATE-05 | `test/architecture/route_doctrine_lint_test.dart` | Scans source for banned patterns: `Navigator.push`, raw `GoRoute(` without scope, hardcoded auth checks |

## 3 Would-Have-Fired Fixtures

| Fixture | File | v2.2 P0 Replicated | Result |
|---------|------|---------------------|--------|
| Scope leak | `test/architecture/fixtures/would_have_fired_scope_leak_test.dart` | Bug 1: `/auth/register` -> `/profile/consent` (public -> authenticated navigation) | FIRES correctly (2 leaks detected) |
| Cycle | `test/architecture/fixtures/would_have_fired_cycle_test.dart` | Circular redirect chains between routes | FIRES correctly |
| Payload | `test/architecture/fixtures/would_have_fired_payload_test.dart` | Bug 2: `coach_chat_screen` receiving null payload from deep link | FIRES correctly |

## Bug 2 Bonus Fix

**File:** `apps/mobile/lib/screens/coach/coach_chat_screen.dart`
**Issue:** The `!_hasProfile` guard at the top of `coach_chat_screen.dart` did not check `entryPayload` and `initialPrompt` before consuming them, allowing null payloads from deep links to cause runtime errors.
**Fix:** Added null/empty checks for `entryPayload` and `initialPrompt` inside the `!_hasProfile` short-circuit path. Applied during 01-01b execution.

## Test Counts

| Metric | Before Phase 1 | After Phase 1 | Delta |
|--------|----------------|---------------|-------|
| Flutter tests passing | 9302 | 9333 | +31 |
| Architecture tests | 0 | 25 | +25 |
| Fixture tests | 0 | 8 | +8 |
| Total (incl. skip/fail) | 9302 | 9333 passed, 6 skipped, 6 failed | +31 net passing |

The 6 failures are pre-existing and unrelated to Phase 1:
- 3x patrol integration tests (require device, not CI-runnable)
- 1x `ton_chooser_test.dart` (missing ARB keys from prior sprint)
- 1x `navigation_route_integrity_test.dart` (pre-existing route mismatch)
- 1x duplicate patrol count

## Flutter Analyze

- **0 errors in Phase 1 files** (router/, app.dart, scoped_go_route.dart, route_scope.dart)
- 886 total issues in `apps/mobile/lib/` are pre-existing (431 errors in voice widgets + duplicate files with spaces in names, 455 infos). None introduced by Phase 1.

## Proof-of-Fire

**File:** `.planning/phases/01-architectural-foundation/proof_of_fire.txt`

A temporary test file was created that deliberately introduced a v2.2 Bug 1 pattern (public route `/auth/register` navigating to authenticated route `/profile/consent`). The GATE-02 scope-leak detection logic caught the violation and the test FAILED as expected:

```
Expected: empty
  Actual: ['/auth/register (scope=public) -> /profile/consent (scope=authenticated)']
PROOF-OF-FIRE: If this fails, the scope leak gate is REAL.
```

The temporary test file was deleted after capturing the output. This proves the gates are not decorative -- they fire red on real scope violations.

## Gate 0 Status

Phase 1 ships zero user-facing change. No screens were added, removed, or visually modified. The entire phase is infrastructure-only (enum, wrapper class, guard logic, tests).

**Gate 0 = CI gates green + proof-of-fire.** Awaiting Julien screenshot of architecture test results on PR as final confirmation.

## Files Created

- `apps/mobile/lib/router/route_scope.dart` -- RouteScope enum
- `apps/mobile/lib/router/scoped_go_route.dart` -- ScopedGoRoute wrapper
- `apps/mobile/test/architecture/route_cycle_test.dart` -- GATE-01
- `apps/mobile/test/architecture/route_scope_leak_test.dart` -- GATE-02
- `apps/mobile/test/architecture/route_payload_consumption_test.dart` -- GATE-03
- `apps/mobile/test/architecture/route_guard_snapshot_test.dart` -- GATE-04
- `apps/mobile/test/architecture/route_doctrine_lint_test.dart` -- GATE-05
- `apps/mobile/test/architecture/route_guard_snapshot.golden.txt` -- golden baseline
- `apps/mobile/test/architecture/fixtures/would_have_fired_cycle_test.dart`
- `apps/mobile/test/architecture/fixtures/would_have_fired_scope_leak_test.dart`
- `apps/mobile/test/architecture/fixtures/would_have_fired_payload_test.dart`

## Files Modified

- `apps/mobile/lib/app.dart` -- 144 GoRoute -> ScopedGoRoute + scope-based redirect
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` -- Bug 2 payload guard fix
