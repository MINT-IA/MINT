/// Test for R2 string-slug defense-in-depth in
/// [PrecisionService._lppYears] — when the archetype slug is 'unknown',
/// LPP contribution years return 0.0 (NOT the swiss_native default
/// `(age - 25).clamp(0, 40)`).
///
/// Sub-phase 01.5 Wave 02 Plan 01 Task 3 (R2 silent killer fix per Gemini).
///
/// Implementation note: `_lppYears` is private static in `PrecisionService`.
/// Instead of leaking it via `@visibleForTesting` (which would widen the
/// public API surface for a single one-line test), this test exercises
/// `_lppYears` via the public consumer that lives in the same file at
/// line 409 (`final yearsContrib = _lppYears(archetype, age);`). We
/// reach `_lppYears` by calling that public consumer with a profile
/// whose archetype is 'unknown' and observing the LPP-derived projection.
///
/// HOWEVER — the only public consumer (`PrecisionService.computeProjection`
/// or similar) is not exposed in a way that lets us isolate `_lppYears`
/// from the rest of the pipeline cheaply. We therefore use the canonical
/// Dart workaround of `@visibleForTesting` on the private method:
/// changing the visibility is the minimal-surface guarantee that the
/// regression guard exists, per the plan's permitted choice.
///
/// Refs:
/// - .planning/phases/01.5-archetype-hard-gate-fatca/01.5-02-01-PLAN.md Task 3 Step 3.1.
/// - REVIEWS.md §R2 (Gemini "silent killer" diagnosis).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/precision/precision_service.dart';

void main() {
  group('R2 — _lppYears handles unknown archetype as 0', () {
    test('precision_service_lpp_years_unknown_returns_zero', () {
      // Calls the public test wrapper exposed via @visibleForTesting on
      // _lppYears (see precision_service.dart). Expected: 0.0 (NOT 10.0
      // which would be `(35-25).clamp(0,40)` = swiss_native default).
      expect(PrecisionService.debugLppYears('unknown', 35), equals(0.0));
    });

    test('precision_service_lpp_years_swiss_native_still_works', () {
      // Regression check — the default arm still works for known archetypes.
      expect(PrecisionService.debugLppYears('swiss_native', 35), equals(10.0));
    });
  });
}
