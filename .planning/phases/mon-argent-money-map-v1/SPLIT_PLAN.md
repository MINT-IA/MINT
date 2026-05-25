description: Split plan from secured WIP branch into reviewable PRs.

# mon-argent-money-map-v1 — Split Plan

## Current Safety Branch

- Branch: `feature/S-mon-argent-money-map-v1`
- Remote: `origin/feature/S-mon-argent-money-map-v1`
- Safety commits:
  - `238bba1fb` — secure full money-map phase
  - `3f15d209e` — post-review Maestro evidence

This branch is the recovery point. Do not rewrite it until split PRs exist and
are green.

## Claude Opus Challenge

Claude challenged the initial 4-PR split as too granular because several files
are shared across budget, Mon Argent, i18n, and test surfaces. The actionable
split is two product PRs plus one later mechanical cleanup.

## PR-A — Budget/Profile Trust Rule

Branch:

`fix/budget-profile-first-v1`

Purpose:

Make budget surfaces deterministic about data precedence.

Files:

- `apps/mobile/lib/providers/coach_profile_provider.dart`
- `apps/mobile/lib/screens/budget/budget_container_screen.dart`
- `apps/mobile/lib/screens/budget/budget_screen.dart`
- `apps/mobile/lib/app.dart`
- `apps/mobile/test/screens/budget_setup_screen_test.dart`
- `apps/mobile/test/screens/budget_screen_smoke_test.dart`

Acceptance:

- Complete `CoachProfile` beats stale `BudgetLocalStore`.
- Partial `CoachProfile` does not overwrite a fuller saved budget.
- `/budget` route extra no longer depends on `GoRouterState.of(context)` inside
  the screen.

Verification:

```bash
cd apps/mobile && flutter analyze \
  lib/providers/coach_profile_provider.dart \
  lib/app.dart \
  lib/screens/budget/budget_container_screen.dart \
  lib/screens/budget/budget_screen.dart \
  test/screens/budget_setup_screen_test.dart \
  test/screens/budget_screen_smoke_test.dart

cd apps/mobile && flutter test \
  test/screens/budget_setup_screen_test.dart \
  test/screens/budget_screen_smoke_test.dart
```

## PR-B — Mon Argent Money Map IA

Branch:

`feat/mon-argent-money-map-ia-v1`

Base:

After PR-A, or stacked on PR-A if we want review before merge.

Purpose:

Make `Mon argent` readable as a human money map instead of a repeated card
stack.

Files:

- `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart`
- `apps/mobile/lib/l10n/app_*.arb`
- `apps/mobile/lib/l10n/app_localizations*.dart`
- `apps/mobile/test/screens/mon_argent_screen_test.dart`
- `tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml`
- `.planning/phases/mon-argent-money-map-v1/**`

Acceptance:

- Segments: Aujourd'hui, Mois, Patrimoine, Prevoyance, Futur.
- Each section uses existing read models; no new persistent money-map store.
- Maestro walks the five sections and verifies direct budget relaunch.

Verification:

```bash
cd apps/mobile && flutter analyze \
  lib/screens/mon_argent/mon_argent_screen.dart \
  test/screens/mon_argent_screen_test.dart

cd apps/mobile && flutter test \
  test/screens/mon_argent_screen_test.dart

bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml \
  --output .planning/walker/maestro-flows/mon-argent-money-map-v1/result.xml \
  --format junit
```

## PR-C — Generated l10n Line Endings

Branch:

`chore/l10n-generated-lf`

Purpose:

Normalize or explicitly exempt generated `app_localizations*.dart` files so
raw `git diff --check` no longer reports CRLF-generated lines as whitespace
failures.

Timing:

After PR-A and PR-B. Keep this mechanical so reviewers do not have to inspect a
line-ending diff mixed with product logic.

## Hold

Do not start `money-trust-contract-v1` until PR-A and PR-B are merged or at
least stable/green. That phase will touch the same budget and Mon Argent
surfaces and should not be layered on a moving WIP.
