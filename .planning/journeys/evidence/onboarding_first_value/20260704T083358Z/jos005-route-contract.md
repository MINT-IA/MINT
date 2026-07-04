# JOS-005 Route Contract Baseline

## Scope

This artifact records the code-level fix for JOS-005 after commit
`e2fd7f7a962e2b048f232184607bcd6c277db974`.

The original Journey OS red proof said the Mint2 LPP/rente-capital first-value
axis reached account creation instead of `/rente-vs-capital`. The clean
worktree does not contain the referenced
`flow_mint2_first_experience_rente_capital_entry.yaml`, so this proof is not a
runtime closure. It is a route-contract baseline that keeps JOS-005 queued for
runtime proof.

## Code Evidence

- `apps/mobile/lib/app.dart`: `/rente-vs-capital` now has
  `scope: RouteScope.onboarding`.
- `apps/mobile/lib/routes/route_metadata.dart`: `/rente-vs-capital` now has
  `requiresAuth: false`.
- `apps/mobile/test/architecture/route_guard_snapshot_test.dart`: adds
  `JOS-005 first-value route is reachable before account creation`.
- `apps/mobile/test/architecture/route_guard_snapshot.golden.txt`: records
  `/rente-vs-capital | onboarding`.

## Commands Run

```bash
flutter test test/architecture/route_guard_snapshot_test.dart --reporter expanded
flutter analyze lib/app.dart lib/routes/route_metadata.dart test/architecture/route_guard_snapshot_test.dart test/routes/route_metadata_test.dart
flutter test test/architecture/route_guard_snapshot_test.dart test/routes/route_metadata_test.dart --reporter expanded
./tools/mint-routes reconcile
python3 tools/checks/active_context_guard.py
python3 tools/checks/phase_contract_guard.py
python3 tools/checks/mint_rules_guard.py
python3 tools/checks/journey_os_check.py
python3 tools/checks/workflow_contract_guard.py
python3 tools/checks/verify_phase_acceptance.py
git diff --check
```

## Results

- Route snapshot test failed before the production change:
  `/rente-vs-capital` was `authenticated`, expected `onboarding`.
- Route snapshot tests passed after the production change.
- Targeted `flutter analyze` passed.
- Targeted route metadata tests passed.
- `./tools/mint-routes reconcile` passed.
- `./tools/mint-routes health` could not complete because Sentry returned 403.
- `verify_phase_acceptance.py` passed, including OS guards, workflow guard,
  ledger parity, and `mobile-data-quest`.

## External Audit

Claude CLI audit command:

```bash
git diff -- apps/mobile/lib/app.dart apps/mobile/lib/routes/route_metadata.dart apps/mobile/test/architecture/route_guard_snapshot.golden.txt apps/mobile/test/architecture/route_guard_snapshot_test.dart | /Users/julienbattaglia/.local/bin/claude --print --model sonnet --effort high --no-session-persistence 'External audit: JOS-005 Mint onboarding first-value route fix. Requirements: /rente-vs-capital must be reachable before account creation for first-value onboarding, no broad auth bypass, route metadata and route snapshot coherent, aliases can remain authenticated, no unrelated generated churn, tests meaningful. Findings first with severity/file:line; say explicitly if no blockers/high-risk.'
```

Verdict:

- No blockers.
- No high-risk issues.
- Info: `/admin/routes` and `/budget/setup` were pre-existing route snapshot
  drift from `b3e83b417`; both are authenticated.
- Info: alias routes stay authenticated by design.
- Info: the route snapshot guard validates declarations, not full runtime
  redirect behavior.

## Remaining Runtime Debt

`bash tools/checks/mint_lucidity_gate.sh mobile-scenarios` currently reaches
Maestro syntax checks but fails on:

```text
ERROR: maestro check-syntax timed out after 360s
apps/mobile/.maestro/r1_scan_review.yaml
```

JOS-005 should be moved to `verified/green` only after canonical iOS runtime
proof passes on the iPhone 17 Pro simulator, or an explicitly cited
iPhone 15/14-class fallback.

Supersession note, 2026-07-04: the earlier compact legacy iPhone runtime proof
is historical evidence only. Active JOS-005 acceptance moved to
`.planning/journeys/evidence/onboarding_first_value/20260704T203133Z-maestro-iphone17/`.
