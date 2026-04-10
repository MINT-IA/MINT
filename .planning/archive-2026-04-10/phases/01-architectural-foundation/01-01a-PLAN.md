---
phase: 01-architectural-foundation
plan: 01a
type: execute
wave: 1
depends_on: []
parent_plan: 01-01-PLAN.md
files_modified:
  - apps/mobile/lib/router/route_scope.dart
  - apps/mobile/lib/router/scoped_go_route.dart
  - apps/mobile/lib/app.dart
autonomous: true
requirements: [NAV-01, NAV-02]
---

# Plan 01-01a: Scope infra + router migration + guard replacement + ProfileDrawer re-mount

**Split rationale:** The parent plan (01-01) bundled router migration + 5 static-analysis tests + would-have-fired fixtures into a single executor run. Executor refused (correctly, per `feedback_facade_sans_cablage.md`): a 144-route migration cannot be done in one shot without per-route hermeneutic verification. This sub-plan does ONLY the migration. The 5 tests and fixtures are 01-01b. The proof-of-fire and verification are 01-01c.

## Scope (this sub-plan only)

1. Create `apps/mobile/lib/router/route_scope.dart` — `RouteScope` enum (`public`, `onboarding`, `authenticated`)
2. Create `apps/mobile/lib/router/scoped_go_route.dart` — `ScopedGoRoute extends GoRoute` carrying a `final RouteScope scope` field
3. Migrate every `GoRoute(...)` declaration in `apps/mobile/lib/app.dart` to `ScopedGoRoute(...)` with explicit scope. Default for any forgotten route = `authenticated` (fail-closed). Document scope choice with an inline comment per route.
4. DELETE the `protectedPrefixes` whitelist at `apps/mobile/lib/app.dart:167-173`. Replace with a `GoRouter.redirect` callback that walks `state.matches`, reads the topmost `ScopedGoRoute.scope`, and gates per the rules in CONTEXT.md (`authenticated` → requires AuthState.signedIn||localAnonymous, `onboarding` → requires !completedOnboarding, `public` → always allowed).
5. Re-mount ProfileDrawer ONLY inside the authenticated scope subtree. Read the current shell composition first to understand where it lives today; this is the structural cause of Bug 1 and must be fixed surgically, not patched.

## Out of scope for this sub-plan

- The 5 mechanical tests (→ 01-01b)
- The would-have-fired fixtures (→ 01-01b)
- The route_guard_snapshot golden file (→ 01-01b)
- The proof-of-fire commit (→ 01-01c)
- VERIFICATION.md (→ 01-01c, after all 3 sub-plans pass)

## Verification gates for this sub-plan

1. `flutter analyze` on `apps/mobile/lib/` → 0 errors, 0 warnings
2. `flutter test` (full mobile suite) → no regression vs current baseline (8137+ tests still green)
3. Manual smoke check: cold-start the app builds and reaches landing without router errors

If gates 1+2 fail, fix the migration before proceeding. If gate 3 fails, the migration changed runtime behavior — investigate and fix.

## Atomic commits

- `feat(01): add RouteScope enum + ScopedGoRoute wrapper [NAV-01]`
- `refactor(01): migrate every GoRoute in app.dart to ScopedGoRoute [NAV-01]`
- `refactor(01): replace operation-based protectedPrefixes whitelist with scope-based redirect guard [NAV-02]`
- `refactor(01): mount ProfileDrawer only inside authenticated scope subtree [NAV-02]`

## Hermeneutic checks per commit

- Every commit body cites the v2.2 P0 it prevents and the founding principle it serves (Principle #2 chat-as-shell — explicit scopes are the type-level encoding of "the chat is the authenticated entry point")
- No commit modifies user-facing copy
- No commit modifies any backend file
- No commit modifies any l10n/ARB file
