import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/education_content.dart';

void main() {
  test('fiscal education avoids absolute 3a profitability claims', () {
    final content = EducationContentData.getContent('fiscal')!;
    final text = [
      content.intro,
      ...content.keyFacts,
      content.quiz.question,
      ...content.quiz.options,
      content.quiz.explanation,
      content.funFact,
    ].join('\n');

    expect(text, contains('deduction plafonnee'));
    expect(text, contains('simple a documenter'));
    expect(text, isNot(contains('la plus rentable')));
    expect(text, isNot(contains('plus efficace a mettre en place')));
    expect(text, isNot(contains('faire economiser')));
  });
}
