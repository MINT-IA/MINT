// Regression test for W-05 (CLAUDE.md TOP rule #3 — MINT ≠ retirement app).
//
// The « Pourquoi créer un compte ? » bullets on the register screen used to
// lead with « Projections AVS/LPP alignées à ta situation » in all 6
// locales. CLAUDE.md TOP rule #3: « MINT ≠ retirement app — 18 life events
// equally weighted ». Bullet #1 must not be retirement-first.
//
// The string can mention retirement INSIDE a list of life events (« housing,
// tax, pension, family… »); the rule is about the LEAD framing, not about
// erasing the word entirely. We split on the first opening paren and only
// test the headline portion.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

const _retirementKeywords = <String>[
  'avs',
  'lpp',
  'ahv',
  'bvg',
  'retraite',
  'retirement',
  'pension',
  'jubilación',
  'pensione',
  'reforma',
  'rente',
  'aposentadoria',
];

void main() {
  group('W-05 register-screen brand framing (CLAUDE.md TOP rule #3)', () {
    for (final locale in ['fr', 'en', 'de', 'es', 'it', 'pt']) {
      test('authBenefitProjections in $locale must not LEAD retirement-first',
          () {
        final arbFile = File('lib/l10n/app_$locale.arb');
        expect(
          arbFile.existsSync(),
          isTrue,
          reason: 'ARB file for $locale must exist',
        );
        final json = jsonDecode(arbFile.readAsStringSync()) as Map<String, dynamic>;
        final value = json['authBenefitProjections'] as String?;
        expect(
          value,
          isNotNull,
          reason: 'authBenefitProjections must exist in $locale',
        );
        // Only check the headline portion (before the first « ( » or « : »).
        // The parenthetical list of life events can legitimately enumerate
        // retirement alongside housing / tax / family.
        final headline = value!
            .split(RegExp(r'[(:]'))
            .first
            .toLowerCase()
            .trim();
        for (final keyword in _retirementKeywords) {
          expect(
            headline.contains(keyword),
            isFalse,
            reason:
                'authBenefitProjections HEADLINE in $locale must not lead '
                'with « $keyword » — first bullet on register screen, '
                'must stay 18-life-events-generic (W-05 + CLAUDE.md TOP rule #3). '
                'Headline parsed: « $headline »',
          );
        }
      });
    }
  });
}
