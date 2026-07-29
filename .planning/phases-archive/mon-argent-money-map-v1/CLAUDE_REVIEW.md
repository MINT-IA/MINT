description: External Claude CLI review notes for mon-argent-money-map-v1.

# Claude CLI Review — 2026-05-25

## Command

Claude CLI was used as a read-only external reviewer. The first tool-enabled
attempt did not return its body in stdout, so the final usable pass was run with
tools disabled and a bounded timeout.

## Findings Received

### P0 — Resolved

`MonArgentScreen._loadBudget` read `CoachProfileProvider` without a
`ProviderNotFoundException` guard, unlike `BudgetContainerScreen`.

Resolution:

- Added guarded read/watch helpers in `MonArgentScreen`.
- Added a widget test that mounts `MonArgentScreen` without
  `CoachProfileProvider`.

### P1 — Resolved

Partial `CoachProfile` data could overwrite a fuller `BudgetLocalStore` cache.
Example: a user enters one budget field, abandons the flow, and later opens a
budget surface where the partial profile wins over a complete saved budget.

Resolution:

- Complete profile still wins over stale cache.
- Partial profile only feeds the budget when no saved budget cache exists.
- Added tests for Budget and Mon Argent:
  - full `CoachProfile` beats stale cache;
  - full cache beats partial `CoachProfile`.

### P1 — Deferred Mechanical Cleanup

Generated `app_localizations*.dart` files are tracked with CRLF. New generated
getters trigger raw `git diff --check` whitespace findings.

Disposition:

- Not fixed in this product phase to avoid a huge line-ending diff.
- Requires a separate mechanical normalization or linter exclusion commit.

### P2/P3 — Accepted Follow-ups

- Prefer Semantics-key driven tests over localized text taps where possible.
- Consider section-specific missing-data messages instead of one generic
  `dataBlockIncomplete` surface.
- Keep `/budget` UX demotion/collapsible changes separate when splitting PRs.
- The phase remains too large for one PR and should be split before landing.

## Verification After Fixes

```bash
cd apps/mobile && flutter analyze \
  lib/screens/budget/budget_container_screen.dart \
  lib/screens/mon_argent/mon_argent_screen.dart \
  test/screens/budget_screen_smoke_test.dart \
  test/screens/mon_argent_screen_test.dart
```

PASS — no issues.

```bash
cd apps/mobile && flutter test \
  test/screens/mon_argent_screen_test.dart \
  test/screens/budget_setup_screen_test.dart \
  test/screens/budget_screen_smoke_test.dart
```

PASS — 17 tests.

## PR-B Review

Claude Opus reviewed the stacked `feat/mon-argent-money-map-ia-v1` branch after
local Flutter tests, ARB parity, and Maestro passed.

Verdict:

- MERGE.
- No P0/P1 blocker.

Accepted follow-ups before final ship:

- Validate the five-segment selector on compact devices; the current tests need
  `ensureVisible('Futur')`, which means discoverability must be checked on
  iPhone SE / small widths.
- Revisit whether `Aujourd'hui` should remain a stronger consolidated overview
  rather than only the current data-spine summary and situation map.
- Make the coach whisper section-aware.

Resolved during PR-B:

- Added widget coverage for the missing-data surface when the pension section
  has no data spine.
