import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/financial_explanations.dart';

void main() {
  test('3a educational explanation avoids absolute investment promises', () {
    final sections = FinancialExplanations.pillar3aRealReturnExplanation(
      7258,
      1800,
      0.045,
      25,
    );

    final text = sections
        .map(
          (section) => [
            section.title,
            section.content,
            section.example,
            ...(section.keyPoints ?? []).map((point) => point.text),
          ].whereType<String>().join('\n'),
        )
        .join('\n');

    expect(text, isNot(contains('Impossible à battre')));
    expect(text, isNot(contains('si peu de risque')));
    expect(text, isNot(contains('VIAC')));
    expect(text, contains('rendement équivalent estimé'));
  });
}
