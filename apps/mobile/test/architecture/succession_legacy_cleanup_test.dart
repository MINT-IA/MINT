import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy testament calculator is deleted and unreachable', () {
    const legacyPath = 'lib/widgets/coach/testament_invisible_widget.dart';
    expect(File(legacyPath).existsSync(), isFalse);

    final references = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.readAsStringSync().contains(
              'TestamentInvisibleWidget',
            ))
        .map((file) => file.path)
        .toList();
    expect(references, isEmpty);
  });

  test('succession source-year copy is explicit in all six locales', () {
    const expected = <String, String>{
      'fr':
          'Année de référence du document (déclarée, non validée juridiquement)',
      'en': 'Document reference year (declared, not legally validated)',
      'de': 'Referenzjahr des Dokuments (deklariert, nicht rechtlich geprüft)',
      'es':
          'Año de referencia del documento (declarado, no validado jurídicamente)',
      'it':
          'Anno di riferimento del documento (dichiarato, non convalidato giuridicamente)',
      'pt':
          'Ano de referência do documento (declarado, não validado juridicamente)',
    };
    for (final entry in expected.entries) {
      final arb = jsonDecode(
        File('lib/l10n/app_${entry.key}.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(
        arb['successionQuestYearLabel'],
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('death guide semantics label is localized in all six locales', () {
    const expected = <String, String>{
      'fr': 'Guide des démarches après le décès d’un proche',
      'en': 'Guide to steps after the death of a loved one',
      'de': 'Leitfaden zu Schritten nach dem Tod einer nahestehenden Person',
      'es': 'Guía de trámites tras el fallecimiento de un ser querido',
      'it': 'Guida alle procedure dopo il decesso di una persona cara',
      'pt': 'Guia de procedimentos após o falecimento de um ente querido',
    };
    for (final entry in expected.entries) {
      final arb = jsonDecode(
        File('lib/l10n/app_${entry.key}.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(
        arb['successionDeathGuideSemanticsLabel'],
        entry.value,
        reason: entry.key,
      );
    }
  });
}
