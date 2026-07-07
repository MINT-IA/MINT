# Patrol Integration Tests — Manual Gap Policy

## Status

Patrol integration tests are NOT included in CI. They require emulator
infrastructure that is not available on GitHub Actions ubuntu runners, and this
checkout does not yet install Patrol.

## Current Repo State

- `apps/mobile/pubspec.yaml` has `integration_test`, but no `patrol:`
  dependency.
- `patrol` is not expected on the default PATH.
- No committed Patrol suite is present yet. The reserved future location is
  `apps/mobile/test/patrol/`.
- Existing executable mobile runtime proof is Maestro-first until Patrol is
  added.

## When to Run

Patrol is a manual gap until the dependency, test suite, and runner exist.
After that, it becomes the required proof for native input surfaces:

| Surface | Patrol status |
|---|---|
| Pure Flutter logic/widget | Not required; use Flutter tests |
| Black-box route and data reuse | Use Maestro when identifiers/deep links exist |
| Native pickers, permissions, camera, biometrics | Required after Patrol is installed |
| Promotion PR with native input changed | Blocked until Patrol proof or explicit deferral |

## Future Command Shape

Once Patrol is added to `pubspec.yaml` and the suite exists, use a real device
or simulator command shaped like:

```bash
cd apps/mobile && patrol test --target test/patrol/<flow>_test.dart
```

Record every run under `.planning/runtime-evidence/` with branch, commit,
device, command, logs, screenshots, and pass/fail summary.

## Future: CI Integration

When GitHub Actions macOS runners with iOS simulator support are configured
(or self-hosted runners with emulator access), add a dedicated `patrol` CI job:

1. Create `.github/workflows/patrol.yml` with macOS runner
2. Configure iOS 17 simulator boot
3. Add Android API 34 emulator via `reactivecircus/android-emulator-runner`
4. Run the committed Patrol suite from the mobile package
5. Remove this manual gate policy document

## Why Not CI Today

- GitHub Actions ubuntu runners have no iOS simulator support
- macOS runners are 10x more expensive and have limited availability
- Android emulator setup on CI adds 3-5 minutes of boot time per run
- Patrol tests are slow by nature (real navigation, screenshots) — better suited
  for a dedicated workflow than the main CI pipeline
