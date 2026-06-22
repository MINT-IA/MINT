---
phase: mint-runtime-debug-tooling-m1
status: planned
created: 2026-06-22
---

# Mint Runtime Debug Tooling M1 — Verification

This file defines the closeout proof for the phase. It is intentionally stricter
than a normal docs plan because this phase exists to stop false confidence.
The active product context remains `mint-2-0-first-experience-rente-capital`;
active-context guards prove router coherence, not M1 promotion.

## Required Static Gates

```bash
python3 tools/checks/active_context_guard.py
python3 tools/checks/phase_contract_guard.py
python3 tools/checks/mint_rules_guard.py
git diff --check
tools/checks/mint_debug_spine_gate.sh
gsd-sdk query verify.plan-structure .planning/phases/mint-runtime-debug-tooling-m1/PLAN.md
gsd-sdk query verify.plan-structure .planning/phases/mint-runtime-debug-tooling-m1/01-patrol-bootstrap-contract-PLAN.md
gsd-sdk query verify.plan-structure .planning/phases/mint-runtime-debug-tooling-m1/02-runtime-fresh-reset-relaunch-PLAN.md
gsd-sdk query verify.plan-structure .planning/phases/mint-runtime-debug-tooling-m1/03-ci-release-closeout-PLAN.md
```

## Required Flutter Gates

```bash
cd apps/mobile
flutter analyze
flutter test test/services/debug/mint_debug_spine_service_test.dart \
  test/screens/admin/mint_debug_spine_screen_test.dart
```

## Required Runtime Gate

```bash
tools/checks/mint_runtime_debug_tooling_gate.sh
```

The runtime gate must produce:

- Patrol log;
- screenshot on constrained final/reset Debug Spine state;
- UI-tree or OCR extracted text for every screenshot;
- redacted Debug Spine JSON before reset;
- redacted Debug Spine JSON after reset/relaunch;
- network-sync assertion log with endpoint/method/status-class/count only;
- exit status.

The runtime gate must use true-fresh simulator reset for the first leg:
`xcrun simctl keychain <UDID> reset` plus app uninstall or a fresh cloned
simulator. Reinstall-only cleanup is not sufficient.

## Forbidden Evidence Content

Fail the phase if any artifact contains:

- raw wizard answers;
- raw chat message bodies;
- email, JWT, Apple credential, device identifier;
- real user financial values;
- seeded synthetic sentinel values used by the test fixture;
- `37'600`, `37600`, `6'640`, `6640`, `Avoir LPP`, `Marge libre`;
- `CHF` adjacent to digits in UI/OCR evidence unless the same extracted block
  also contains provenance/readiness/source/version labels.

Bare `CHF` in a label is not sufficient to fail the gate; value-bearing CHF
patterns are.

## Required Network Artifact Schema

Allowed fields:

- `method`
- `endpoint_path`
- `status_class`
- `count`
- `forbidden_match`

Forbidden fields:

- headers;
- request or response body;
- query string;
- Authorization token;
- device id;
- email;
- wizard answers;
- raw financial values;
- chat message text.

Forbidden call matchers:

- `/sync/claim-local-data`
- profile writes;
- coach sync writes;
- snapshot endpoints;
- `claimLocalData`;
- `_syncToBackend` push-origin calls during fresh anonymous/reset/register-login
  sync-off paths.

The recorder must attach at the central `MintHttpClient.shared` layer, because
some services call it directly. An `ApiService`-only hook is not acceptable
unless the executor also provides exhaustive tests proving that no forbidden
path bypasses the recorder. Existing debug HTTP body logs must be suppressed or
redacted during the runtime gate; artifacts containing request/response body log
lines fail the gate.

## Required Release Leakage Gate

Closeout requires a source/workflow scan and either a release/profile artifact
scan or an explicit NO-GO explaining why the artifact could not be built. The
scan must reject:

- `/admin/debug-spine`
- Debug Spine user-facing labels;
- debug snapshot identifiers;
- `ENABLE_DEBUG_TOOLS`
- production workflows passing `ENABLE_ADMIN=(1|true)` or
  `ENABLE_DEBUG_TOOLS=(1|true)` through direct `--dart-define`,
  environment-wrapped build args, or dart-define-from-file inputs.

## Required Reviews

Before closeout:

- `qa-expert` reviews gate coverage and flake risk;
- `flutter-expert` reviews Patrol/iOS integration;
- `security-auditor` or `mobile-security-coder` reviews privacy evidence;
- Claude Max reviews the final diff with tools disabled or narrowly scoped.

The phase may close only when reviewers return GO or every blocker has a
committed fix and a repeated targeted review.

## GO / NO-GO

GO requires all required gates above and complete evidence. If iOS runtime is
not available, the correct verdict is NO-GO with the missing prerequisite
listed. Do not substitute Maestro or widget tests for the Patrol runtime gate.
Do not claim physical iPhone/TestFlight/iCloud restore from this simulator gate.
