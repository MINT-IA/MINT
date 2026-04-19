// Phase 31 OBS-05 (b) — MintBreadcrumbs ComplianceGuard stub (Wave 0).
//
// Wave 1 Plan 31-01 implements:
//   apps/mobile/lib/services/sentry_breadcrumbs.dart
//     class MintBreadcrumbs {
//       static void complianceGuard({
//         required bool passed,
//         required String surface,
//         List<String>? flaggedTerms,
//       });
//     }
//
// D-03 LOCKED (CONTEXT.md §Implementation Decisions): the 4-level
// category MUST be `mint.<surface>.<action>.<outcome>`. Outcome is the
// 4th dotted segment (NOT carried only by SentryLevel) — this enables
// Sentry UI search `event.category:mint.compliance.guard.pass`. The
// SentryLevel enum (info / warning) remains set in parallel for
// ops filtering but is orthogonal to the category string.
//
// Exact literals for ComplianceGuard:
//   passed=true  -> category = `mint.compliance.guard.pass`   level=info
//   passed=false -> category = `mint.compliance.guard.fail`   level=warning
//
// Data payload MUST NOT leak flagged term contents. Only `flagged_count`
// (int) is permitted — the actual term strings may include banned
// financial vocabulary (garanti, sans risque) that we do not want to
// round-trip through Sentry as user-readable data.
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MintBreadcrumbs.complianceGuard (Wave 1 Plan 31-01)', () {
    test(
      'MintBreadcrumbs.complianceGuard emits category '
      'mint.compliance.guard.pass when passed=true',
      () {},
      skip: 'Wave 1 impl pending — Plan 31-01 creates sentry_breadcrumbs.dart',
    );

    test(
      'MintBreadcrumbs.complianceGuard emits category '
      'mint.compliance.guard.fail when passed=false '
      'with flagged_count int only (no flagged term strings leaked)',
      () {},
      skip: 'Wave 1 impl pending — Plan 31-01 creates sentry_breadcrumbs.dart',
    );
  });
}
