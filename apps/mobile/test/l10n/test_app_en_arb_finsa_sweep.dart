// Phase 94 / COMP-05 — EN ARB regulator-name regression guard.
//
// The English regulator name for the Swiss Financial Services Act is
// « FinSA », not the French « LSFin ». This test asserts the sweep
// stays swept and that other locales keep their native regulator names
// (LSFin in FR, FIDLEG in DE, LSFin still in IT/ES/PT pending Phase 97
// counsel pass — IT will migrate to LSerFi at that time).
//
// CI failure on this test = either:
//   (a) someone copy-pasted FR disclaimer copy into EN ARB, OR
//   (b) a sed sweep accidentally touched a non-EN ARB file.
//
// Either way: revert and re-run the EN-only sweep.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app_en.arb contains 0 LSFin and >= 70 FinSA', () {
    final en = File('lib/l10n/app_en.arb').readAsStringSync();
    expect(
      en.contains('LSFin'),
      isFalse,
      reason: 'EN ARB must use FinSA, not French regulator name LSFin',
    );
    final finsaCount = 'FinSA'.allMatches(en).length;
    expect(
      finsaCount,
      greaterThanOrEqualTo(70),
      reason:
          'expected >= 70 FinSA mentions in EN disclaimers, got $finsaCount',
    );
  });

  test('app_fr.arb keeps LSFin (FR native regulator name)', () {
    final fr = File('lib/l10n/app_fr.arb').readAsStringSync();
    final count = 'LSFin'.allMatches(fr).length;
    expect(
      count,
      greaterThanOrEqualTo(60),
      reason: 'FR ARB must keep LSFin (native regulator name in French)',
    );
  });

  test('app_de.arb keeps FIDLEG (DE native regulator name)', () {
    final de = File('lib/l10n/app_de.arb').readAsStringSync();
    final fidleg = 'FIDLEG'.allMatches(de).length;
    expect(
      fidleg,
      greaterThanOrEqualTo(60),
      reason: 'DE ARB must use FIDLEG (German regulator name)',
    );
  });

  test(
      'app_it.arb / app_es.arb / app_pt.arb keep LSFin '
      '(IT migrates to LSerFi in Phase 97; ES/PT use FR-anchored fallback)',
      () {
    // CONTEXT.md notes: ES/PT currently fall back to FR regulator naming;
    // IT will migrate to LSerFi in Phase 97. For now, the regression guard
    // is « values present, count not regressed by this sweep ».
    for (final loc in <String>['it', 'es', 'pt']) {
      final c = File('lib/l10n/app_$loc.arb').readAsStringSync();
      final count = 'LSFin'.allMatches(c).length;
      expect(
        count,
        greaterThanOrEqualTo(50),
        reason:
            '$loc ARB lost LSFin mentions — sweep accidentally touched non-EN file',
      );
    }
  });
}
