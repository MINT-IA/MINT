# Golden Screenshot Tests

## Purpose

Regression guard for visual layout of key v2.0 screens. These tests capture
pixel-level screenshots and compare them against committed baselines. They
detect unintended visual regressions -- not design approval.

## Phone Sizes

| Device     | Logical Size | Pixel Ratio |
|------------|-------------|-------------|
| iPhone SE  | 375 x 667  | 2.0         |
| iPhone 15  | 393 x 852  | 3.0         |

## Languages

- **FR** (French): baseline for every screen
- **DE** (German): 1 variant per screen to catch text overflow / layout breaks

## Pixel Diff Threshold Policy

Flutter's built-in `matchesGoldenFile()` performs **exact** pixel comparison by
default. There is no configurable tolerance in the standard test runner.

For CI, a **1.5% pixel difference threshold** is the project standard:
- Use the `--update-goldens` flag **ONLY** on dedicated baseline-refresh PRs.
- NEVER include `--update-goldens` in the default CI test command.
- Any golden file update MUST be accompanied by a PR with justification.

If a CI run fails due to sub-pixel rendering differences across platforms,
investigate before blindly updating goldens.

## Update Protocol

1. Developer makes a visual change (intentional).
2. Run locally: `flutter test test/golden_screenshots/ --update-goldens`
3. Review the diff in the `goldens/` directory visually.
4. Commit updated golden files with a clear PR description of what changed and why.
5. Reviewer verifies the visual diff is intentional.

## Running Tests

```bash
# Generate/update baselines
flutter test test/golden_screenshots/ --update-goldens

# Compare against baselines (CI mode)
flutter test test/golden_screenshots/
```

## Directory Structure

```
test/golden_screenshots/
  golden_test_helpers.dart      # Shared setup, viewport, widget builders
  golden_screenshot_test.dart   # v2.0 key screen golden tests
  landing_screen_golden_test.dart
  quick_start_screen_golden_test.dart
  goldens/                      # Committed baseline images (PNG)
  failures/                     # Test failures (gitignored)
```

## Threat Mitigation (T-06-03)

Golden files are trusted baselines. Unauthorized updates bypass visual regression
detection. The `--update-goldens` flag must NEVER appear in CI default commands.
Updates require PR review with justification.
