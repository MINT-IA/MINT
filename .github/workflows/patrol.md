# Patrol Integration Tests — Manual Gate Policy

## Status

Patrol integration tests are **NOT** included in the main CI path. They require
device infrastructure that is not available on GitHub Actions ubuntu runners.
Canonical local iOS Patrol proof runs on the Mac Mini **iPhone 17 Pro**
simulator. If that simulator is unavailable, use an iPhone 15/14-class fallback
and cite the fallback in the evidence. Compact legacy iPhone targets are not
accepted for Patrol runtime proof.

## Test Location

```
apps/mobile/test/patrol/
  first_salary_tax_datablock_to_3a_patrol_test.dart  — Salary/tax data reuse into 3a
  first_salary_tax_fatca_3a_patrol_test.dart         — FATCA branch without duplicate answers
  f2_datablock_to_mortgage_patrol_test.dart          — Income/savings data reuse into mortgage
  transmit_property_patrol_test.dart                 — Property transfer Data Quest proof
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

- macOS with Xcode and the local iPhone 17 Pro simulator, or an iPhone
  15/14-class fallback when explicitly cited
- Android Studio with API 34 emulator image
- Flutter 3.27.4+ with patrol_cli installed

### Commands

```bash
cd apps/mobile

# iOS canonical local runtime
flutter test test/patrol/ --device-id "iPhone 17 Pro"

# Android (Pixel 7 API 34 emulator)
flutter test test/patrol/ --device-id "emulator-5554"
```

### Expected Results

- All four P0 Patrol flows complete without crash
- Real user-input facts are persisted once and reused by the target screen
- No duplicate chronological data collection for already-known variables
- No unhandled exceptions in console output

## Future: CI Integration

When GitHub Actions macOS runners with iOS simulator support are configured
(or self-hosted runners with emulator access), add a dedicated `patrol` CI job:

1. Create `.github/workflows/patrol.yml` with macOS runner
2. Configure iPhone 17 Pro simulator boot, with iPhone 15/14-class fallback only
   when the canonical simulator is unavailable
3. Add Android API 34 emulator via `reactivecircus/android-emulator-runner`
4. Move `test/patrol/` into the new workflow
5. Remove this manual gate policy document

## Why Not CI Today

- GitHub Actions ubuntu runners have no iOS simulator support
- macOS runners are 10x more expensive and have limited availability
- Android emulator setup on CI adds 3-5 minutes of boot time per run
- Patrol tests are slow by nature (real navigation, screenshots) — better suited
  for a dedicated workflow than the main CI pipeline
