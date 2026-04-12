import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/couple_question_generator.dart';
import 'package:mint_mobile/services/partner_estimate_service.dart';

void main() {
  group('CoupleQuestionGenerator', () {
    test('generate with all fields missing returns 5 questions', () {
      const estimate = PartnerEstimate();
      final questions = CoupleQuestionGenerator.generate(estimate);
      expect(questions.length, 5);
    });

    test('generate returns questions in priority order', () {
      const estimate = PartnerEstimate();
      final questions = CoupleQuestionGenerator.generate(estimate);
      final priorities = questions.map((q) => q.priority).toList();
      expect(priorities, [1, 2, 3, 4, 5]);
    });

    test('generate with salary filled returns 4 questions (no salary)', () {
      const estimate = PartnerEstimate(estimatedSalary: 80000);
      final questions = CoupleQuestionGenerator.generate(estimate);
      expect(questions.length, 4);
      expect(
        questions.every((q) => q.field != 'estimated_salary'),
        true,
      );
    });

    test('generate with all fields filled returns empty list', () {
      const estimate = PartnerEstimate(
        estimatedSalary: 80000,
        estimatedAge: 35,
        estimatedLpp: 50000,
        estimated3a: 20000,
        estimatedCanton: 'ZH',
      );
      final questions = CoupleQuestionGenerator.generate(estimate);
      expect(questions, isEmpty);
    });

    test('generate with 3 fields filled returns 2 questions', () {
      const estimate = PartnerEstimate(
        estimatedSalary: 80000,
        estimatedAge: 35,
        estimatedCanton: 'ZH',
      );
      final questions = CoupleQuestionGenerator.generate(estimate);
      expect(questions.length, 2);
      expect(questions[0].field, 'estimated_lpp');
      expect(questions[1].field, 'estimated_3a');
    });

    test('generateAll always returns 5 questions', () {
      final questions = CoupleQuestionGenerator.generateAll();
      expect(questions.length, 5);
    });

    test('generateAll returns questions in priority order', () {
      final questions = CoupleQuestionGenerator.generateAll();
      final priorities = questions.map((q) => q.priority).toList();
      expect(priorities, [1, 2, 3, 4, 5]);
    });

    test('each question has non-empty question and impact text', () {
      final questions = CoupleQuestionGenerator.generateAll();
      for (final q in questions) {
        expect(q.question.isNotEmpty, true,
            reason: '${q.field} has empty question');
        expect(q.impact.isNotEmpty, true,
            reason: '${q.field} has empty impact');
        expect(q.field.isNotEmpty, true,
            reason: 'Question has empty field');
      }
    });

    test('questions use French non-breaking space before question marks', () {
      final questions = CoupleQuestionGenerator.generateAll();
      for (final q in questions) {
        // French typography: non-breaking space (\u00a0) before ?
        expect(q.question.contains('\u00a0?'), true,
            reason: '${q.field} missing non-breaking space before ?');
      }
    });
  });
}
