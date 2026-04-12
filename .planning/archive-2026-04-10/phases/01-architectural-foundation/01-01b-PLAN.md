---
phase: 01-architectural-foundation
plan: 01b
type: execute
wave: 1
depends_on: [01-01a]
parent_plan: 01-01-PLAN.md
files_modified:
  - apps/mobile/test/architecture/route_cycle_test.dart
  - apps/mobile/test/architecture/route_scope_leak_test.dart
  - apps/mobile/test/architecture/route_payload_consumption_test.dart
  - apps/mobile/test/architecture/route_guard_snapshot_test.dart
  - apps/mobile/test/architecture/route_doctrine_lint_test.dart
  - apps/mobile/test/architecture/fixtures/cycle_fixture.dart
  - apps/mobile/test/architecture/fixtures/scope_leak_fixture.dart
  - apps/mobile/test/architecture/fixtures/payload_shortcircuit_fixture.dart
  - apps/mobile/test/architecture/fixtures/would_have_fired_test.dart
  - apps/mobile/test/architecture/route_guard_snapshot.golden.txt
autonomous: true
requirements: [GATE-01, GATE-02, GATE-03, GATE-04, GATE-05]
---

# Plan 01-01b: 5 mechanical CI gates + would-have-fired fixtures + guard snapshot golden

**Depends on:** 01-01a complete and verified (router migrated, guard replaced, ProfileDrawer re-mounted, full test suite still green).

## Scope

Build the 5 mechanical CI tests in `apps/mobile/test/architecture/`. Each test in its own file. Implement them ONE AT A TIME, verify each passes against the migrated router from 01-01a, then move to the next.

### Order of implementation

1. **`route_cycle_test.dart`** (GATE-01) — load the migrated router from app.dart, build adjacency graph from GoRoute parent-child + every reachable target via static analysis of `context.go/push` calls within routed widget files, run DFS for SCCs, fail on any non-whitelisted SCC. Whitelist is empty for v2.3.
2. **`route_scope_leak_test.dart`** (GATE-02) — for every navigation call site in `apps/mobile/lib/screens/**` and `apps/mobile/lib/widgets/**`, resolve the source widget's scope (via the route that mounts it) and the target route's scope, fail on any `public→authenticated` or `onboarding→authenticated` edge.
3. **`route_payload_consumption_test.dart`** (GATE-03) — AST-walk every screen widget that reads `GoRouterState.of(context).extra` or receives `extra` via constructor, assert the extra is consumed BEFORE any short-circuit return (if (X) return EmptyState() pattern with X computed before extra-read = fail).
4. **`route_guard_snapshot_test.dart`** (GATE-04) — generate a sorted text snapshot of (route_path, scope) pairs from the migrated router. Compare to golden file `route_guard_snapshot.golden.txt`. First run creates the golden; subsequent runs fail on any unreviewed delta.
5. **`route_doctrine_lint_test.dart`** (GATE-05) — load every routed widget source file + every ARB file, scan for the banned-term corpus documented in CONTEXT.md (compliance terms, raw legal articles, internal Nx— level naming, social comparison, gamified completion %, banned tone phrases). Fail on any match in user-facing strings.

### Then build the would-have-fired fixtures

In `apps/mobile/test/architecture/fixtures/`:
- `cycle_fixture.dart` — minimal GoRouter setup replicating the v2.2 `intent → diagnostic → intent` cycle
- `scope_leak_fixture.dart` — minimal setup with an onboarding-scope screen calling `context.go('/profile/consent')` (the v2.2 register_screen.dart:431 pattern)
- `payload_shortcircuit_fixture.dart` — minimal screen with `state.extra` ignored before `if (!_hasProfile) return EmptyState()` short-circuit (the v2.2 coach_chat_screen.dart:1317 pattern)

`would_have_fired_test.dart` runs each gate against its corresponding fixture and asserts the gate FAILS. This is the proof the safety net is real, not theatrical.

## Out of scope

- Any change to non-test files (router migration is 01-01a)
- Modifying any l10n/ARB file (the doctrine lint READS them, never writes)
- The proof-of-fire commit + VERIFICATION.md (→ 01-01c)

## Verification gates

1. `flutter analyze` on test/architecture/ → 0 errors
2. `flutter test apps/mobile/test/architecture/` → all 5 gates green against migrated router
3. The would-have-fired suite → all 3 fixtures cause their gate to fail (this is success — the gates catch the bugs)
4. `flutter test` full mobile suite → no regression

## Atomic commits

- `test(01): add route cycle DFS gate [GATE-01]`
- `test(01): add scope-leak detection gate [GATE-02]`
- `test(01): add payload consumption gate [GATE-03]`
- `test(01): add route guard snapshot gate + initial golden [GATE-04]`
- `test(01): add doctrine string lint gate [GATE-05]`
- `test(01): add would-have-fired fixtures proving 3 gates catch v2.2 P0 patterns [GATE-01,02,03]`

## Iterative discipline

If any gate is harder than ~150 LOC of test code, STOP and split it further. Static-analysis tests have a habit of growing — keep each gate surgical. If you need more than 2 commits per gate, open a sub-sub-plan.
