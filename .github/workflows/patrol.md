# Patrol Integration Tests — Manual Gate Policy

## Status

Patrol integration tests are **NOT** included in CI. They require emulator infrastructure
(iOS 17 simulator + Android API 34 emulator) that is not available on GitHub Actions
ubuntu runners.

## Test Location

```
apps/mobile/test/patrol/
  mint_runtime_debug_gate_test.dart — Debug Spine redacted JSON launch gate
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

- macOS with Xcode 15+ (iOS 17 simulator)
- Android Studio with API 34 emulator image
- Flutter 3.41.4+ with `patrol_cli` installed
- Pub global executables on PATH:

```bash
flutter pub global activate patrol_cli
export PATH="$PATH:$HOME/.pub-cache/bin"
dart pub global list | grep -q '^patrol_cli '
command -v patrol
```

### Commands

```bash
cd <repo-root>

# Linux/CI-safe static subset. This does not prove iOS runtime behavior.
tools/checks/mint_runtime_debug_tooling_gate.sh --ci-static-only

# iOS simulator debug-spine launch gate
tools/checks/mint_runtime_debug_tooling_gate.sh

# Local release/profile leakage scan. By default this builds/scans local iOS
# no-codesign Runner.app artifacts. Use MINT_RELEASE_SCAN_PATHS for signed
# IPA/AAB/APK/expanded artifact paths.
tools/checks/mint_runtime_debug_tooling_gate.sh --release-scan-only
```

### Expected Results

- The app launches in debug with Mint2 runtime flags.
- The test asserts Debug Spine redacted JSON shape, not UI text.
- No raw wizard answer, financial value, email, token, device id, or chat body
  appears in the JSON evidence.
- The CI-safe static subset prints the local macOS runtime command and states
  that it is not runtime proof.
- Production workflows do not pass `ENABLE_ADMIN=1|true` or
  `ENABLE_DEBUG_TOOLS=1|true`, including through dart-define files.
- The local iOS release/profile Runner.app artifacts, or signed archives passed
  through `MINT_RELEASE_SCAN_PATHS`, do not contain `/admin/debug-spine`,
  Debug Spine labels, debug snapshot identifiers, or debug-tool flags.

## Future: CI Integration

When GitHub Actions macOS runners with iOS simulator support are configured
(or self-hosted runners with emulator access), add a dedicated `patrol` CI job:

1. Create `.github/workflows/patrol.yml` with macOS runner
2. Configure iOS 17 simulator boot
3. Add Android API 34 emulator via `reactivecircus/android-emulator-runner`
4. Run `test/patrol/` from the new workflow after installing `patrol_cli`
5. Remove this manual gate policy document

## Why Not CI Today

- GitHub Actions ubuntu runners have no iOS simulator support
- macOS runners are 10x more expensive and have limited availability
- Android emulator setup on CI adds 3-5 minutes of boot time per run
- Patrol tests are slow by nature (real navigation, screenshots) — better suited
  for a dedicated workflow than the main CI pipeline
