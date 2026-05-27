import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/financial_explanations.dart';

void main() {
  String flattenSections(sections) => sections
      .map(
        (section) => [
          section.title,
          section.content,
          section.example,
          ...(section.keyPoints ?? []).map((point) => point.text),
        ].whereType<String>().join('\n'),
      )
      .join('\n');

  test('3a educational explanation avoids absolute investment promises', () {
    final sections = FinancialExplanations.pillar3aRealReturnExplanation(
      7258,
      1800,
      0.045,
      25,
    );

    final text = flattenSections(sections);

    expect(text, isNot(contains('Impossible à battre')));
    expect(text, isNot(contains('si peu de risque')));
    expect(text, isNot(contains('VIAC')));
    expect(text, contains('rendement équivalent estimé'));
    expect(text, isNot(contains('Ton économie fiscale grandit')));
    expect(text, contains('espace de déduction peut évoluer'));
  });

  test('LPP buyback explanation frames tax impact as conditional', () {
    final sections = FinancialExplanations.lppBuybackExplanation(
      50000,
      0.30,
    );

    final text = flattenSections(sections);

    expect(text, isNot(contains('il faut racheter')));
    expect(text, isNot(contains('maximiser l\'économie fiscale')));
    expect(text, isNot(contains('Gain supplémentaire')));
    expect(text, isNot(contains('économie fiscale')));
    expect(text, contains('impact fiscal potentiel'));
    expect(text, contains('Impact fiscal indicatif'));
  });
}
