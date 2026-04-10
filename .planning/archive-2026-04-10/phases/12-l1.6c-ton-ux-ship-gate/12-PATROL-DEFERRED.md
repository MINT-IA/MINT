# Patrol tests — LateInitializationError investigation (deferred to v2.3)

**Scope:** `apps/mobile/test/patrol/onboarding_patrol_test.dart`, `apps/mobile/test/patrol/document_patrol_test.dart`

**Current state:** both tests marked `skip: true` since Phase 1.5 Option 3 (baseline allowlist). Pre-dev-merge cleanup (2026-04-08) confirmed the skip is structural, not a quick fix, and defers resolution to v2.3 CI emulator infra work (tracked as QA-04 / QA-05).

## Error (reproduced 2026-04-08)

Both files use `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` and call `app.main()` inside a `testWidgets` callback. Under the widget-test binding that `flutter test` provides, `app.main()` throws a `LateInitializationError` before the first frame because several `late` globals (providers, GoRouter, Firebase-adjacent singletons, biography repository) are initialized only when a real integration-test binding hosts the app.

## Why this is not fixable in 60 min

1. **Binding mismatch is architectural, not a typo.** The Patrol / `integration_test` binding owns the Flutter engine and the platform-channel layer. The widget-test binding that `flutter test` uses shares neither. You cannot monkey-patch one into the other — you have to run the tests under `flutter drive` / `patrol test` with a real device or emulator.
2. **Camera + GoRouter + Firebase singletons.** `app.main()` transitively touches `image_picker`, `GoRouter`, and various providers that register late in `main()`. Mocking all of them via the widget-test binding is tantamount to rewriting `main()` as a test harness, which regresses production safety.
3. **CI emulator infra is the correct fix and is already tracked.** QA-04 (iOS simulator CI) and QA-05 (Android emulator CI) exist in the roadmap. Once those runners exist, `skip: true` comes off and the tests run unchanged.

## What was tried in the 60-min window

- Read both files in full (300 LOC total).
- Re-ran `flutter analyze` on both files — no static issues.
- Traced `app.main()` → confirmed it calls `runApp(MintApp())` where `MintApp` reads several late-bound singletons before the first frame.
- Confirmed the comments on lines 42-44 / 64-66 already explain the root cause and point at QA-04 / QA-05.
- Confirmed no change at the widget-test layer can make `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` co-exist with `flutter test`'s default binding. The only safe path is to run under `patrol test` on a real target.

## Decision

- Keep `skip: true` on both tests.
- Keep the existing comments pointing at QA-04 / QA-05.
- This document is the authoritative investigation note. Link back to it from v2.3 QA planning when the emulator runners land.

## Follow-up owner

v2.3 QA infrastructure track. Blocks on CI emulator availability, not on code changes in the mobile repo.
