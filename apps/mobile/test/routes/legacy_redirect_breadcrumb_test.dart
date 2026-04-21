// Phase 32 Plan 03 Wave 3 — static guards for MAP-05 legacy redirect wiring.
//
// Per-site coverage is asserted by
// `tests/tools/test_redirect_breadcrumb_coverage.py` using the
// RECONCILE-REPORT inventory. This file is the lightweight Dart-side
// guard rail: (a) helper presence, (b) no query-param leak, (c) loose
// lower bound on source-call count.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('legacyRedirectHit wiring (MAP-05) — static guards', () {
    test('MintBreadcrumbs.legacyRedirectHit helper declared', () {
      final src = File('lib/services/sentry_breadcrumbs.dart').readAsStringSync();
      expect(src.contains('static void legacyRedirectHit'), isTrue);
      expect(
        src.contains("category: 'mint.routing.legacy_redirect.hit'"),
        isTrue,
      );
    });

    test('breadcrumb data uses state.uri.path — never state.uri.toString()', () {
      final src = File('lib/app.dart').readAsStringSync();
      // Every MintBreadcrumbs.legacyRedirectHit call must use state.uri.path
      // (not .toString()) so query params never reach Sentry.
      final badPattern = RegExp(
        r'legacyRedirectHit\([^)]*state\.uri\.toString\(\)',
      );
      expect(
        badPattern.hasMatch(src),
        isFalse,
        reason:
            'Using state.uri.toString() leaks query params — must use state.uri.path',
      );
    });

    test('app.dart wires at least 43 legacyRedirectHit calls (inventory sum)', () {
      // Per-site coverage is asserted by
      // tests/tools/test_redirect_breadcrumb_coverage.py using the
      // RECONCILE-REPORT inventory. This test is the loose lower bound
      // (sum across all sites of redirect_branches >= 43, since no site
      // has zero redirect-taking branches).
      final src = File('lib/app.dart').readAsStringSync();
      final count = 'MintBreadcrumbs.legacyRedirectHit'.allMatches(src).length;
      expect(
        count,
        greaterThanOrEqualTo(43),
        reason:
            'Wave 0 reconciled 43 redirects; every one emits breadcrumb at least once',
      );
    });
  });
}
