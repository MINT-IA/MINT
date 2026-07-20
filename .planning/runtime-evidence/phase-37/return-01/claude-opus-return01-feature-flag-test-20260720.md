# MINT External Audit — `code` mode

## Scope
Single unstaged change: `apps/mobile/test/navigation/data_block_return_uri_test.dart` (+6 lines, well within the 300-line budget). No production code, no staged changes.

## What the diff does
Adds a per-test flag toggle in `setUp`:

```dart
final originalFirstJobFlag = FeatureFlags.enableFirstJobScreen;   // :177
addTearDown(() => FeatureFlags.enableFirstJobScreen = originalFirstJobFlag); // :178-180
FeatureFlags.enableFirstJobScreen = true;                         // :181
```

plus the corresponding `import '.../services/feature_flags.dart';`.

## Verification (source of truth = code)

**Why the toggle is required (not masking a bug).** `_routedOrigins` includes `/first-job` (`test/...:32`), and the `G1-RETURN-01 exact P0 return-to-origin` group drives the **real production router** (`_pumpProductionRouter`, `:268/285/301`) then asserts the collector returns to the origin: `expect(_currentUri(router).toString(), origin)` (`:280,296,325`). In the production router that origin is fail-closed:
- `app.dart:1824-1828` — `/first-job` route has `redirect: (_, __) => firstJobFeatureRedirect()`.
- `app.dart:2440-2441` — `firstJobFeatureRedirect()` returns `/explore/travail` unless `enableFirstJobScreen`.
- `feature_flags.dart:75-79` — default is fail-closed (`bool.fromEnvironment('MINT_TEST_FIRST_JOB', defaultValue: false)`).

So without the toggle, a save with `returnUri:/first-job` redirects to `/explore/travail` and the equality assertion fails. Setting the flag exercises the return-to-origin contract under the feature-enabled world. This matches the established runtime-set pattern in sibling tests (`first_job_screen_test.dart:78-80`, `first_job_whole_screen_coherence_test.dart:50-53`).

**Security/compliance property preserved.** The flag stays outside `applyFromMap` (confirmed `feature_flags.dart:206-236` — no `enableFirstJobScreen` key), so the backend still cannot activate the dormant route. The test mutates the static only at runtime and restores it via `addTearDown` per test, so no leakage to other test files sharing the process. Guard tests that pin the compile-time gate target the `integration_test/*patrol*` files (`test/runtime/g1_return01_six_origin_runtime_test.dart:357-377`), not this file — this change does not touch them.

**No facade-without-wiring risk.** No production entrypoint sets `enableFirstJobScreen`; the producers that emit a `/first-job` returnUri (FirstJobScreen enrich CTA, `first_job_screen.dart:201-216`) are themselves unreachable when the flag is off, so the allowlisting of `/first-job` as a return origin stays consistent with production reachability.

## Findings
- **P0:** none
- **P1:** none
- **P2:** none. (Optional nit, not blocking: the added `import` is marked here as first-use; if `flutter analyze` flags ordering it would be cosmetic only. Run `cd apps/mobile && flutter test test/navigation/data_block_return_uri_test.dart` to confirm green — I could not execute it in this audit, but the code path above shows the assertion set is now internally consistent.)

## Verdict
**PASS**

Minimal, correct test-only fix. It makes the navigation return-to-origin contract valid for the `/first-job` origin under the feature-enabled condition, restores the fail-closed production default per test, and weakens no privacy/compliance/routing invariant.
