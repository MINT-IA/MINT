# Patrol Integration Tests — Manual Gate Policy

## Status

Patrol integration tests are **NOT** included in the main Linux CI. They require
local simulator infrastructure, and the default MINT runtime gate is iOS.

## Test Location

```
apps/mobile/test/patrol/
  mint_runtime_smoke_test.dart  — Minimal Patrol bootstrap and app launch proof
  *_runtime_test.dart           — Focused runtime proofs for mapped journeys
```

## When to Run

Patrol tests are a **manual gate** required before promotion PRs:

| PR Type              | Patrol Required | Who Runs       |
|----------------------|-----------------|----------------|
| feature/* -> dev     | No              | —              |
| dev -> staging       | Yes             | Developer      |
| staging -> main      | Yes             | Developer      |

## How to Run

### Prerequisites

- macOS with Xcode and an iPhone 15+ simulator
- Flutter 3.27.4+ with patrol_cli installed
- Patrol CLI may live at `$HOME/.pub-cache/bin/patrol` even when `patrol` is
  not exported in `PATH`. Do not claim Patrol is unavailable before running
  `python3 tools/checks/patrol_tooling_guard.py`.

### Commands

```bash
cd apps/mobile

# iOS, preferred local simulator. Replace the device name with the currently
# booted iPhone 15+ simulator when needed.
$HOME/.pub-cache/bin/patrol test \
  -t test/patrol/mint_runtime_smoke_test.dart \
  -d "iPhone 17 Pro" \
  --dart-define=MINT_PATROL_CLI=true

# Focused journey proof. Replace the target with the relevant runtime test.
$HOME/.pub-cache/bin/patrol test \
  -t test/patrol/disability_insurance_runtime_test.dart \
  -d "iPhone 17 Pro" \
  --dart-define=MINT_PATROL_CLI=true

# Static/config preflight from repo root.
python3 tools/checks/patrol_tooling_guard.py

# If the Patrol console summary is ambiguous, verify the xcresult directly.
xcrun xcresulttool get test-results tests --path build/ios_results_<id>.xcresult --compact
```

### Expected Results

- Patrol builds and launches MINT through the native runner
- `mint_runtime_smoke_test.dart` finds the root `MaterialApp`
- `xcresulttool get test-results tests` reports the test case as `Passed`
- No unhandled exceptions in console output

## Future: CI Integration

When GitHub Actions macOS runners with iOS simulator support are configured
(or self-hosted runners with simulator access), add a dedicated `patrol` CI job:

1. Create `.github/workflows/patrol.yml` with macOS runner
2. Configure an iPhone 15+ simulator boot
3. Run `python3 tools/checks/patrol_tooling_guard.py`
4. Run `$HOME/.pub-cache/bin/patrol test -t test/patrol/mint_runtime_smoke_test.dart -d "<device>" --dart-define=MINT_PATROL_CLI=true`
5. Keep this document as the local/manual fallback

## Why Not CI Today

- GitHub Actions ubuntu runners have no iOS simulator support
- macOS runners are more expensive and have limited availability
- Patrol tests are slow by nature (real navigation, screenshots) — better suited
  for a dedicated workflow than the main CI pipeline
