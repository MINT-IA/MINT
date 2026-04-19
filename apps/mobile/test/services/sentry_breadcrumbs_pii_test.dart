// Phase 31 OBS-05 (c) — MintBreadcrumbs.saveFact PII fuzz stub (Wave 0).
//
// Wave 1 Plan 31-01 implements:
//   apps/mobile/lib/services/sentry_breadcrumbs.dart
//     static void saveFact({
//       required bool success,
//       required String factKind,
//       String? errorCode,
//     });
//
// D-03 LOCKED EXACT LITERALS (CONTEXT.md): the category uses the 4-level
// hierarchy — revision dropped the intermediate `tool` segment.
//   success=true  -> category = `mint.coach.save_fact.success`  level=info
//   success=false -> category = `mint.coach.save_fact.error`    level=error
//
// The `factKind` is an enum value (e.g. "income_monthly_net",
// "employer_country", "third_pillar_balance") — NEVER the factValue
// itself. Leaking factValue through a breadcrumb would regress Pitfall 6
// (A1 secondaire PITFALLS.md) — CHF amounts, AVS numbers, IBANs must
// NOT reach Sentry.
//
// Wave 1 implementer MUST add a fuzz test: emit 100 breadcrumbs across
// all factKind values, then grep the emitted payload for patterns:
//   - CHF[- ]?\d+          (CHF amounts, any format)
//   - 756\.\d{4}           (AVS number prefix)
//   - [A-Z]{2}\d{2}[A-Z0-9]{1,30}  (IBAN prefix)
// Any hit = test fails + Wave 1 cannot ship saveFact breadcrumbs.
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MintBreadcrumbs.saveFact PII (Wave 1 Plan 31-01)', () {
    test(
      'MintBreadcrumbs.saveFact emits category mint.coach.save_fact.success '
      'or mint.coach.save_fact.error (D-03 4-level) with factKind enum '
      'only — no factValue leak (CHF, AVS 756., IBAN patterns banned)',
      () {},
      skip: 'Wave 1 impl pending — Plan 31-01 creates sentry_breadcrumbs.dart',
    );
  });
}
