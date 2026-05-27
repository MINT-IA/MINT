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

  test('LAMal education frames franchise changes as conditional', () {
    final content = EducationContentData.getContent('lamal')!;
    final text = [
      content.intro,
      ...content.keyFacts,
      content.quiz.question,
      ...content.quiz.options,
      content.quiz.explanation,
      content.funFact,
    ].join('\n').toLowerCase();

    expect(text, contains('la prime peut baisser'));
    expect(text, contains('selon la caisse'));
    expect(text, contains('risque accru'));
    expect(text, contains('hospitalisation'));
    expect(text, contains("2'200"));
    expect(text, isNot(contains('tu economises')));
    expect(text, isNot(contains('tu économises')));
    expect(text, isNot(contains('te faire économiser')));
    expect(text, isNot(contains('faire economiser')));
    expect(text, isNot(contains('économie de prime')));
    expect(text, isNot(contains('offrent 10-20')));
    expect(text, isNot(contains('meilleur')));
    expect(text, isNot(contains('optimal')));
    expect(text, isNot(contains('garanti')));
    expect(RegExp(r'tu économise[a-zéè]*').hasMatch(text), isFalse);
    expect(RegExp(r'tu economise[a-z]*').hasMatch(text), isFalse);
  });
}
