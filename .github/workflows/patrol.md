# Patrol Integration Tests — Manual Gate Policy

## Status

Patrol integration tests are **NOT** included in CI. They require emulator infrastructure
(iOS 17 simulator + Android API 34 emulator) that is not available on GitHub Actions
ubuntu runners.

## Test Location

```
apps/mobile/test/patrol/
  onboarding_patrol_test.dart   — Full onboarding flow (7 steps)
  document_patrol_test.dart     — Document capture flow (7 steps, screenshots)
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
- Flutter 3.27.4+ with patrol_cli installed

### Commands

```bash
cd apps/mobile

# iOS (iPhone 15 simulator)
flutter test test/patrol/ --device-id "iPhone 15"

# Android (Pixel 7 API 34 emulator)
flutter test test/patrol/ --device-id "emulator-5554"
```

### Expected Results

- All 7 onboarding steps complete without crash
- All 7 document capture steps complete with screenshots captured
- No unhandled exceptions in console output

## Future: CI Integration

When GitHub Actions macOS runners with iOS simulator support are configured
(or self-hosted runners with emulator access), add a dedicated `patrol` CI job:

1. Create `.github/workflows/patrol.yml` with macOS runner
2. Configure iOS 17 simulator boot
3. Add Android API 34 emulator via `reactivecircus/android-emulator-runner`
4. Move `test/patrol/` into the new workflow
5. Remove this manual gate policy document

## Why Not CI Today

- GitHub Actions ubuntu runners have no iOS simulator support
- macOS runners are 10x more expensive and have limited availability
- Android emulator setup on CI adds 3-5 minutes of boot time per run
- Patrol tests are slow by nature (real navigation, screenshots) — better suited
  for a dedicated workflow than the main CI pipeline
