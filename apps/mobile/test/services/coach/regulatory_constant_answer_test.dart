import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/coach/regulatory_constant_answer.dart';

void main() {
  group('CoachRegulatoryConstantAnswer', () {
    test('resolves 3a ceiling with LPP from regulatory constants', () async {
      final l = await S.delegate.load(const Locale('fr'));
      final answer = CoachRegulatoryConstantAnswer.resolve(
        'Quel est le plafond legal 3a 2026 avec LPP ?',
        l,
      );

      expect(answer, isNotNull);
      expect(answer!.text, contains("7'258"));
      expect(answer.text, contains('OPP3 art. 7'));
      expect(answer.text, isNot(contains('Je n’ai pas cette donnée')));
    });

    test('does not answer unrelated coach turns', () async {
      final l = await S.delegate.load(const Locale('fr'));
      final answer = CoachRegulatoryConstantAnswer.resolve(
        'Comment organiser mon budget mensuel ?',
        l,
      );

      expect(answer, isNull);
    });
  });
}
