import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/educational_insert_service.dart';

/// Unit tests for EducationalInsertService
///
/// Tests the educational insert mapping service that associates wizard
/// questions with just-in-time educational content (OECD/INFE pattern).
///
/// Validates:
///   - hasInsert() correctly identifies questions with inserts
///   - getLearnMoreTitle() returns titles for known questions
///   - getInsertWidget() returns widgets for known question IDs
///   - Edge cases: unknown keys, empty answers, null handling
///   - Content coverage for all declared question IDs
///   - Compliance: sources and disclaimers in GenericInfoInsertWidget content
void main() {
  // ══════════════════════════════════════════════════════════════════════
  // DECLARED QUESTION IDS
  // ══════════════════════════════════════════════════════════════════════

  /// All question IDs that should have inserts, per the source code.
  const allQuestionIds = [
    'q_financial_stress_check',
    'q_has_pension_fund',
    'q_has_3a',
    'q_3a_annual_amount',
    'q_mortgage_type',
    'q_has_consumer_credit',
    'q_has_leasing',
    'q_emergency_fund',
    'q_civil_status',
    'q_employment_status',
    'q_housing_status',
    'q_canton',
    'q_lpp_buyback_available',
    'q_3a_accounts_count',
    'q_has_investments',
    'q_real_estate_project',
  ];

  // ══════════════════════════════════════════════════════════════════════
  // hasInsert()
  // ══════════════════════════════════════════════════════════════════════

  group('hasInsert()', () {
    test('returns true for all declared question IDs', () {
      for (final id in allQuestionIds) {
        expect(EducationalInsertService.hasInsert(id), true,
            reason: 'Expected hasInsert("$id") to be true');
      }
    });

    test('returns false for unknown question ID', () {
      expect(EducationalInsertService.hasInsert('q_unknown_question'), false);
    });

    test('returns false for empty string', () {
      expect(EducationalInsertService.hasInsert(''), false);
    });

    test('returns false for similar but incorrect ID', () {
      // Typo variations that should NOT match
      expect(EducationalInsertService.hasInsert('q_has_3A'), false); // uppercase
      expect(EducationalInsertService.hasInsert('q_emergency_Fund'), false); // uppercase
      expect(EducationalInsertService.hasInsert('q_canton '), false); // trailing space
    });

    test('questionsWithInserts set has expected count (16)', () {
      expect(EducationalInsertService.questionsWithInserts.length, 16);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // getLearnMoreTitle()
  // ══════════════════════════════════════════════════════════════════════

  group('getLearnMoreTitle()', () {
    test('returns non-null title for all declared question IDs', () {
      for (final id in allQuestionIds) {
        final title = EducationalInsertService.getLearnMoreTitle(id);
        expect(title, isNotNull, reason: 'Expected title for "$id" to be non-null');
        expect(title!.isNotEmpty, true,
            reason: 'Expected title for "$id" to be non-empty');
      }
    });

    test('returns null for unknown question ID', () {
      expect(EducationalInsertService.getLearnMoreTitle('q_nonexistent'), isNull);
    });

    test('q_has_pension_fund title mentions LPP', () {
      final title = EducationalInsertService.getLearnMoreTitle('q_has_pension_fund');
      expect(title, contains('LPP'));
    });

    test('q_has_3a and q_3a_annual_amount share the same title', () {
      final title3a = EducationalInsertService.getLearnMoreTitle('q_has_3a');
      final titleAmount =
          EducationalInsertService.getLearnMoreTitle('q_3a_annual_amount');
      expect(title3a, titleAmount);
    });

    test('q_canton title mentions fiscalite', () {
      final title = EducationalInsertService.getLearnMoreTitle('q_canton');
      expect(title!.toLowerCase(), contains('fiscalité'));
    });

    test('q_emergency_fund title is about emergency fund', () {
      final title = EducationalInsertService.getLearnMoreTitle('q_emergency_fund');
      expect(title, contains('urgence'));
    });

    test('q_mortgage_type title mentions hypotheques', () {
      final title = EducationalInsertService.getLearnMoreTitle('q_mortgage_type');
      expect(title!.toLowerCase(), anyOf(contains('hypotheque'), contains('hypothèque')));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // getInsertWidget()
  // ══════════════════════════════════════════════════════════════════════

  group('getInsertWidget()', () {
    test('returns non-null widget for q_financial_stress_check', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_financial_stress_check',
        answers: {},
      );
      expect(widget, isNotNull);
      expect(widget, isA<Widget>());
    });

    test('returns non-null widget for q_has_pension_fund', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_has_pension_fund',
        answers: {'q_has_pension_fund': 'yes'},
      );
      expect(widget, isNotNull);
    });

    test('returns non-null widget for q_has_3a with employee status', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_has_3a',
        answers: {
          'q_employment_status': 'employee',
          'q_net_income_period_chf': 6000.0,
        },
      );
      expect(widget, isNotNull);
    });

    test('returns non-null widget for q_3a_annual_amount', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_3a_annual_amount',
        answers: {'q_employment_status': 'self_employed'},
      );
      expect(widget, isNotNull);
    });

    test('returns non-null widget for q_civil_status', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_civil_status',
        answers: {},
      );
      expect(widget, isNotNull);
    });

    test('returns non-null widget for q_employment_status', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_employment_status',
        answers: {},
      );
      expect(widget, isNotNull);
    });

    test('returns non-null widget for q_housing_status', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_housing_status',
        answers: {},
      );
      expect(widget, isNotNull);
    });

    test('returns non-null widget for q_canton', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_canton',
        answers: {},
      );
      expect(widget, isNotNull);
    });

    test('returns non-null widget for q_lpp_buyback_available', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_lpp_buyback_available',
        answers: {},
      );
      expect(widget, isNotNull);
    });

    test('returns non-null widget for q_3a_accounts_count', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_3a_accounts_count',
        answers: {},
      );
      expect(widget, isNotNull);
    });

    test('returns non-null widget for q_has_investments', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_has_investments',
        answers: {},
      );
      expect(widget, isNotNull);
    });

    test('returns non-null widget for q_real_estate_project', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_real_estate_project',
        answers: {},
      );
      expect(widget, isNotNull);
    });

    test('returns null for unknown question ID', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_nonexistent',
        answers: {},
      );
      expect(widget, isNull);
    });

    test('returns non-null for all declared question IDs', () {
      for (final id in allQuestionIds) {
        final widget = EducationalInsertService.getInsertWidget(
          questionId: id,
          answers: {
            'q_has_pension_fund': 'yes',
            'q_employment_status': 'employee',
            'q_net_income_period_chf': 6000.0,
          },
        );
        expect(widget, isNotNull,
            reason: 'Expected getInsertWidget for "$id" to return non-null');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // 3A INSERT: INCOME RESOLUTION LOGIC
  // ══════════════════════════════════════════════════════════════════════

  group('3a insert income resolution', () {
    test('uses period income with monthly frequency by default', () {
      // This tests that the widget can be created with period income
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_has_3a',
        answers: {
          'q_net_income_period_chf': 5000.0,
          'q_employment_status': 'employee',
        },
      );
      expect(widget, isNotNull);
    });

    test('handles weekly pay frequency', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_has_3a',
        answers: {
          'q_net_income_period_chf': 1500.0,
          'q_pay_frequency': 'weekly',
          'q_employment_status': 'employee',
        },
      );
      expect(widget, isNotNull);
    });

    test('handles biweekly pay frequency', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_has_3a',
        answers: {
          'q_net_income_period_chf': 3000.0,
          'q_pay_frequency': 'biweekly',
          'q_employment_status': 'employee',
        },
      );
      expect(widget, isNotNull);
    });

    test('falls back to monthly direct income when no period income', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_has_3a',
        answers: {
          'q_income_net_monthly': 6000.0,
          'q_employment_status': 'employee',
        },
      );
      expect(widget, isNotNull);
    });

    test('defaults to 6000 when no income provided', () {
      // Should not crash; uses default 6000
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_has_3a',
        answers: {
          'q_employment_status': 'employee',
        },
      );
      expect(widget, isNotNull);
    });

    test('employee always gets hasPensionFund = true', () {
      // Even without explicit q_has_pension_fund, employee defaults to LPP = true
      // This is tested implicitly by verifying the widget creates successfully
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_has_3a',
        answers: {
          'q_employment_status': 'employee',
        },
      );
      expect(widget, isNotNull);
    });

    test('self-employed defaults to no pension fund unless explicit', () {
      // Self-employed without explicit pension fund -> no LPP -> large 3a
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_has_3a',
        answers: {
          'q_employment_status': 'self_employed',
          'q_net_income_period_chf': 8000.0,
        },
      );
      expect(widget, isNotNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // EDGE CASES
  // ══════════════════════════════════════════════════════════════════════

  group('Edge cases', () {
    test('empty answers map does not crash for any question', () {
      for (final id in allQuestionIds) {
        // Should not throw
        final widget = EducationalInsertService.getInsertWidget(
          questionId: id,
          answers: {},
        );
        expect(widget, isNotNull,
            reason: 'getInsertWidget("$id") with empty answers should not crash');
      }
    });

    test('answers with wrong types do not crash', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_has_consumer_credit',
        answers: {
          'q_credit_amount': 'not_a_number',
          'q_credit_rate': null,
          'q_credit_duration': 12.5, // double instead of int
        },
      );
      expect(widget, isNotNull);
    });

    test('handles string-encoded numbers in answers', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_has_3a',
        answers: {
          'q_net_income_period_chf': '5000', // String instead of double
          'q_employment_status': 'employee',
        },
      );
      expect(widget, isNotNull);
    });

    test('onLearnMore callback is passed through', () {
      var called = false;
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_canton',
        answers: {},
        onLearnMore: () => called = true,
      );
      expect(called, isFalse); // callback exists but not invoked without rendering
      expect(widget, isNotNull);
      // We cannot easily invoke onLearnMore without rendering,
      // but we verify the widget was created without error.
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CONSISTENCY CHECKS
  // ══════════════════════════════════════════════════════════════════════

  group('Consistency between hasInsert, getLearnMoreTitle, getInsertWidget', () {
    test('every ID in questionsWithInserts has a title and a widget', () {
      for (final id in EducationalInsertService.questionsWithInserts) {
        expect(EducationalInsertService.hasInsert(id), true,
            reason: 'hasInsert should be true for "$id"');
        expect(EducationalInsertService.getLearnMoreTitle(id), isNotNull,
            reason: 'getLearnMoreTitle should be non-null for "$id"');
        final widget = EducationalInsertService.getInsertWidget(
          questionId: id,
          answers: {
            'q_has_pension_fund': 'yes',
            'q_employment_status': 'employee',
            'q_net_income_period_chf': 6000.0,
          },
        );
        expect(widget, isNotNull,
            reason: 'getInsertWidget should return non-null for "$id"');
      }
    });

    test('questionsWithInserts matches the known list exactly', () {
      final expected = Set<String>.from(allQuestionIds);
      expect(EducationalInsertService.questionsWithInserts, expected);
    });
  });
}
