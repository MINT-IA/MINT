import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/document_parser/tax_declaration_parser.dart';

void main() {
  const safeAssessedStatusCopy = {
    'fr': 'Taxé, entrée en force non confirmée',
    'en': 'Assessed, entry into force not confirmed',
    'de': 'Veranlagt, Rechtskraft nicht bestätigt',
    'es': 'Liquidado, firmeza no confirmada',
    'it': 'Accertato, definitività non confermata',
    'pt': 'Liquidado, caráter definitivo não confirmado',
  };

  for (final entry in safeAssessedStatusCopy.entries) {
    test(
      'assessed status does not infer an open appeal period in ${entry.key}',
      () {
        final arb = jsonDecode(
          File('lib/l10n/app_${entry.key}.arb').readAsStringSync(),
        ) as Map<String, dynamic>;

        expect(
          arb['taxReviewOptionAssessedAppealable'],
          entry.value,
          reason: '${entry.key}:arb',
        );
        expect(
          lookupS(Locale(entry.key)).taxReviewOptionAssessedAppealable,
          entry.value,
          reason: '${entry.key}:generated',
        );
      },
    );
  }

  test('tax impact disclaimer is specific, local-only and neutral in 6 locales',
      () {
    const expectations = {
      'fr': ['local', 'ne constituent pas un conseil fiscal'],
      'en': ['local', 'not tax advice'],
      'de': ['lokal', 'keine steuerberatung'],
      'es': ['local', 'no constituyen asesoramiento fiscal'],
      'it': ['locale', 'non costituiscono consulenza fiscale'],
      'pt': ['local', 'não constituem aconselhamento fiscal'],
    };

    for (final entry in expectations.entries) {
      final arb = jsonDecode(
        File('lib/l10n/app_${entry.key}.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final copy = (arb['docImpactTaxDisclaimer'] as String).toLowerCase();
      for (final fragment in entry.value) {
        expect(copy, contains(fragment), reason: entry.key);
      }
      expect(copy, isNot(contains('prévoyance')), reason: entry.key);
      expect(copy, isNot(contains('retirement')), reason: entry.key);
    }
  });

  test('tax review copy is localized in 6 locales, never emitted by parser',
      () {
    const localizedKeys = {
      'taxReviewCantonalIncome',
      'taxReviewFederalIncome',
      'taxReviewCantonalWealth',
      'taxReviewCantonalTax',
      'taxReviewFederalTax',
      'taxReviewMarginalRate',
      'taxReviewAverageRate',
      'taxParserDiagnosticPercentUnit',
      'taxParserDiagnosticNegativeWealth',
      'taxParserDiagnosticAverageNotMarginal',
      'taxReviewLocalDisclaimer',
    };
    for (final locale in const ['fr', 'en', 'de', 'es', 'it', 'pt']) {
      final arb = jsonDecode(
        File('lib/l10n/app_$locale.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final key in localizedKeys) {
        expect(arb[key], isNot(isEmpty), reason: '$locale:$key');
      }
    }

    final result = TaxDeclarationParser.parseTaxDeclaration(
      TaxDeclarationParser.sampleOcrText,
    );

    expect(result.warnings, isEmpty);
    expect(result.disclaimer, isEmpty);
    expect(result.sources, isEmpty);
  });

  test('fiscal acquisition copy makes no universal rate or coefficient claim',
      () {
    const coefficientTerms = {
      'fr': 'coefficient',
      'en': 'coefficient',
      'de': 'koeffizient',
      'es': 'coeficiente',
      'it': 'coefficiente',
      'pt': 'coeficiente',
    };

    for (final entry in coefficientTerms.entries) {
      final arb = jsonDecode(
        File('lib/l10n/app_${entry.key}.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final copy = (arb['dataBlockFiscaliteDesc'] as String).toLowerCase();
      expect(copy, isNot(contains(entry.value)), reason: entry.key);
      expect(copy, isNot(contains('60')), reason: entry.key);
      expect(copy, isNot(contains('130')), reason: entry.key);
    }

    final parserSource = File(
      'lib/services/document_parser/tax_declaration_parser.dart',
    ).readAsStringSync();
    expect(parserSource, isNot(contains('LIFD art. 38')));
  });
}
