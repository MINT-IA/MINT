import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/educational_insert_service.dart';

void main() {
  // All 16 question IDs (8 old + 8 new)
  const allQuestionIds = [
    // Existing inserts (S16-S19)
    'q_financial_stress_check',
    'q_has_pension_fund',
    'q_has_3a',
    'q_3a_annual_amount',
    'q_mortgage_type',
    'q_has_consumer_credit',
    'q_has_leasing',
    'q_emergency_fund',
    // New inserts S27 — Niveau 1
    'q_civil_status',
    'q_employment_status',
    'q_housing_status',
    'q_canton',
    // New inserts S27 — Niveau 2
    'q_lpp_buyback_available',
    'q_3a_accounts_count',
    'q_has_investments',
    'q_real_estate_project',
  ];

  group('EducationalInsertService — hasInsert()', () {
    for (final questionId in allQuestionIds) {
      test('hasInsert returns true for $questionId', () {
        expect(EducationalInsertService.hasInsert(questionId), isTrue);
      });
    }

    test('hasInsert returns false for unknown question ID', () {
      expect(EducationalInsertService.hasInsert('q_unknown'), isFalse);
    });

    test('hasInsert returns false for empty string', () {
      expect(EducationalInsertService.hasInsert(''), isFalse);
    });

    test('hasInsert returns false for null-like string', () {
      expect(EducationalInsertService.hasInsert('null'), isFalse);
    });

    test('questionsWithInserts contains exactly 16 entries', () {
      expect(
        EducationalInsertService.questionsWithInserts.length,
        equals(16),
      );
    });
  });

  group('EducationalInsertService — getInsertWidget()', () {
    const emptyAnswers = <String, dynamic>{};

    for (final questionId in allQuestionIds) {
      test('getInsertWidget returns non-null widget for $questionId', () {
        final widget = EducationalInsertService.getInsertWidget(
          questionId: questionId,
          answers: emptyAnswers,
        );
        expect(widget, isNotNull);
        expect(widget, isA<Widget>());
      });
    }

    test('getInsertWidget returns null for unknown question ID', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_does_not_exist',
        answers: emptyAnswers,
      );
      expect(widget, isNull);
    });
  });

  group('EducationalInsertService — getLearnMoreTitle()', () {
    for (final questionId in allQuestionIds) {
      test('getLearnMoreTitle returns non-null for $questionId', () {
        final title = EducationalInsertService.getLearnMoreTitle(questionId);
        expect(title, isNotNull);
        expect(title, isA<String>());
        expect(title!.isNotEmpty, isTrue);
      });
    }

    test('getLearnMoreTitle returns null for unknown question ID', () {
      final title =
          EducationalInsertService.getLearnMoreTitle('q_does_not_exist');
      expect(title, isNull);
    });
  });
}
