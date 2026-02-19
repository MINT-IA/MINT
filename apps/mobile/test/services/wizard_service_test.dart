import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/wizard_question.dart';
import 'package:mint_mobile/services/wizard_service.dart';
import 'package:mint_mobile/services/wizard_conditions_service.dart';

/// Unit tests for WizardService and WizardConditionsService
///
/// Tests question filtering, condition evaluation, safe mode detection,
/// income calculation, validation, score calculation, and the conditions
/// service that routes wizard questions based on answers.
void main() {
  // ─────────────────────────────────────────────────────────────────────
  // Helper: build a minimal list of WizardQuestion objects for testing
  // ─────────────────────────────────────────────────────────────────────
  List<WizardQuestion> _buildTestQuestions() {
    return [
      WizardQuestion(
        id: 'q_canton',
        title: 'Canton?',
        type: QuestionType.choice,
        required: true,
        options: [
          const QuestionOption(label: 'Vaud', value: 'VD'),
          const QuestionOption(label: 'Zurich', value: 'ZH'),
        ],
      ),
      WizardQuestion(
        id: 'q_birth_year',
        title: 'Birth year?',
        type: QuestionType.number,
        required: true,
        minValue: 1940,
        maxValue: 2010,
      ),
      WizardQuestion(
        id: 'q_savings_monthly',
        title: 'Monthly savings?',
        type: QuestionType.number,
        required: false,
        hint: 'CHF par mois',
      ),
      WizardQuestion(
        id: 'q_has_3a',
        title: 'As-tu un 3a?',
        type: QuestionType.choice,
        required: true,
        options: [
          const QuestionOption(label: 'Oui', value: 'yes'),
          const QuestionOption(label: 'Non', value: 'no'),
        ],
      ),
      WizardQuestion(
        id: 'q_primary_goal',
        title: 'Objectif principal?',
        type: QuestionType.choice,
        required: true,
        options: [
          const QuestionOption(label: 'Maison', value: 'house'),
          const QuestionOption(label: 'Retraite', value: 'retire'),
        ],
      ),
      WizardQuestion(
        id: 'q_conditional',
        title: 'Conditional question',
        type: QuestionType.choice,
        required: false,
        condition: (answers) => answers['q_has_3a'] == 'yes',
        options: [
          const QuestionOption(label: 'A', value: 'a'),
        ],
      ),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // WizardService tests
  // ═══════════════════════════════════════════════════════════════════════

  group('WizardService.isSafeModeActive', () {
    test('safe mode ON when late payments in last 6 months', () {
      final answers = <String, dynamic>{
        'q_late_payments_6m': 'yes',
        'q_emergency_fund': 'yes_6months',
      };
      expect(WizardService.isSafeModeActive(answers), true);
    });

    test('safe mode ON when creditcard overdraft is often', () {
      final answers = <String, dynamic>{
        'q_creditcard_minimum_or_overdraft': 'often',
        'q_emergency_fund': 'yes_6months',
      };
      expect(WizardService.isSafeModeActive(answers), true);
    });

    test('safe mode ON when consumer credit exists', () {
      final answers = <String, dynamic>{
        'q_has_consumer_credit': 'yes',
        'q_emergency_fund': 'yes_6months',
      };
      expect(WizardService.isSafeModeActive(answers), true);
    });

    test('safe mode ON when consumer debt exists (V2)', () {
      final answers = <String, dynamic>{
        'q_has_consumer_debt': 'yes',
        'q_emergency_fund': 'yes_6months',
      };
      expect(WizardService.isSafeModeActive(answers), true);
    });

    test('safe mode ON when no emergency fund', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'no',
      };
      expect(WizardService.isSafeModeActive(answers), true);
    });

    test('safe mode ON when emergency fund field is missing entirely', () {
      final answers = <String, dynamic>{};
      // No emergency fund info => hasEmergencyFund = false => safe mode ON
      expect(WizardService.isSafeModeActive(answers), true);
    });

    test('safe mode OFF with emergency fund and no debt stress', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_late_payments_6m': 'no',
        'q_creditcard_minimum_or_overdraft': 'never',
        'q_has_consumer_credit': 'no',
        'q_has_consumer_debt': 'no',
      };
      expect(WizardService.isSafeModeActive(answers), false);
    });

    test('safe mode OFF with 3-month emergency fund (yes_3months)', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_3months',
      };
      expect(WizardService.isSafeModeActive(answers), false);
    });

    test('safe mode OFF with V1 emergency fund exists = yes', () {
      final answers = <String, dynamic>{
        'q_emergency_fund_exists': 'yes',
      };
      expect(WizardService.isSafeModeActive(answers), false);
    });

    test('safe mode ON with high debt ratio > 30%', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_net_income_period_chf': 5000,
        'q_pay_frequency': 'monthly',
        'q_has_leasing': 'yes',
        'q_leasing_monthly': 1000,
        'q_has_consumer_credit': 'yes',
        'q_credit_monthly': 800,
      };
      // Debt ratio: (1000+800)/5000 = 0.36 > 0.3
      // But q_has_consumer_credit == 'yes' triggers hasDebtStress anyway
      expect(WizardService.isSafeModeActive(answers), true);
    });
  });

  group('WizardService.getMonthlyIncome', () {
    test('returns legacy monthly income when q_net_income_monthly exists', () {
      final answers = <String, dynamic>{
        'q_net_income_monthly': 6000.0,
      };
      expect(WizardService.getMonthlyIncome(answers), 6000.0);
    });

    test('returns period income directly for monthly frequency', () {
      final answers = <String, dynamic>{
        'q_net_income_period_chf': 5000.0,
        'q_pay_frequency': 'monthly',
      };
      expect(WizardService.getMonthlyIncome(answers), 5000.0);
    });

    test('converts weekly income to monthly (x4.333)', () {
      final answers = <String, dynamic>{
        'q_net_income_period_chf': 1000.0,
        'q_pay_frequency': 'weekly',
      };
      expect(WizardService.getMonthlyIncome(answers), closeTo(4333.0, 1.0));
    });

    test('converts biweekly income to monthly (x2.166)', () {
      final answers = <String, dynamic>{
        'q_net_income_period_chf': 2500.0,
        'q_pay_frequency': 'biweekly',
      };
      expect(WizardService.getMonthlyIncome(answers), closeTo(5415.0, 1.0));
    });

    test('returns 0 for empty answers', () {
      expect(WizardService.getMonthlyIncome({}), 0.0);
    });

    test('handles null income value gracefully', () {
      final answers = <String, dynamic>{
        'q_net_income_period_chf': null,
        'q_pay_frequency': 'monthly',
      };
      expect(WizardService.getMonthlyIncome(answers), 0.0);
    });

    test('defaults to monthly when frequency missing', () {
      final answers = <String, dynamic>{
        'q_net_income_period_chf': 4000.0,
      };
      expect(WizardService.getMonthlyIncome(answers), 4000.0);
    });
  });

  group('WizardService.validateAnswer', () {
    test('returns error when required question has null answer', () {
      final question = WizardQuestion(
        id: 'q_test',
        title: 'Test?',
        type: QuestionType.choice,
        required: true,
      );

      final error = WizardService.validateAnswer(question, null);
      expect(error, isNotNull);
      expect(error, contains('obligatoire'));
    });

    test('returns null for valid required answer', () {
      final question = WizardQuestion(
        id: 'q_test',
        title: 'Test?',
        type: QuestionType.choice,
        required: true,
      );

      final error = WizardService.validateAnswer(question, 'some_value');
      expect(error, isNull);
    });

    test('returns null for optional question with null answer', () {
      final question = WizardQuestion(
        id: 'q_test',
        title: 'Test?',
        type: QuestionType.choice,
        required: false,
      );

      final error = WizardService.validateAnswer(question, null);
      expect(error, isNull);
    });

    test('returns error when numeric answer below minValue', () {
      final question = WizardQuestion(
        id: 'q_birth_year',
        title: 'Birth year?',
        type: QuestionType.number,
        required: true,
        minValue: 1940,
        maxValue: 2010,
      );

      final error = WizardService.validateAnswer(question, 1900);
      expect(error, isNotNull);
      expect(error, contains('1940'));
    });

    test('returns error when numeric answer above maxValue', () {
      final question = WizardQuestion(
        id: 'q_birth_year',
        title: 'Birth year?',
        type: QuestionType.number,
        required: true,
        minValue: 1940,
        maxValue: 2010,
      );

      final error = WizardService.validateAnswer(question, 2050);
      expect(error, isNotNull);
      expect(error, contains('2010'));
    });

    test('returns null for numeric answer within range', () {
      final question = WizardQuestion(
        id: 'q_birth_year',
        title: 'Birth year?',
        type: QuestionType.number,
        required: true,
        minValue: 1940,
        maxValue: 2010,
      );

      final error = WizardService.validateAnswer(question, 1990);
      expect(error, isNull);
    });

    test('returns null for input type with numeric answer within range', () {
      final question = WizardQuestion(
        id: 'q_income',
        title: 'Income?',
        type: QuestionType.input,
        required: true,
        minValue: 0,
        maxValue: 100000,
      );

      final error = WizardService.validateAnswer(question, 50000);
      expect(error, isNull);
    });
  });

  group('WizardService.calculateCompletionScore', () {
    test('returns 100 when no required questions exist', () {
      final questions = [
        WizardQuestion(
          id: 'q_optional',
          title: 'Optional',
          type: QuestionType.text,
          required: false,
        ),
      ];

      final score = WizardService.calculateCompletionScore({}, questions);
      expect(score, 100.0);
    });

    test('returns 0 when no required questions are answered', () {
      final questions = _buildTestQuestions();
      final requiredCount = questions.where((q) => q.required).length;

      final score = WizardService.calculateCompletionScore({}, questions);
      expect(score, 0.0);
      expect(requiredCount, greaterThan(0));
    });

    test('returns partial score for partially answered required questions', () {
      final questions = _buildTestQuestions();
      final requiredCount = questions.where((q) => q.required).length;

      final answers = <String, dynamic>{
        'q_canton': 'VD',
        'q_birth_year': 1990,
      };

      final score = WizardService.calculateCompletionScore(answers, questions);
      expect(score, closeTo((2 / requiredCount) * 100, 0.1));
    });

    test('returns 100 when all required questions are answered', () {
      final questions = _buildTestQuestions();

      final answers = <String, dynamic>{
        'q_canton': 'VD',
        'q_birth_year': 1990,
        'q_has_3a': 'yes',
        'q_primary_goal': 'house',
      };

      final score = WizardService.calculateCompletionScore(answers, questions);
      expect(score, 100.0);
    });

    test('ignores null-valued answers for required questions', () {
      final questions = _buildTestQuestions();
      final requiredCount = questions.where((q) => q.required).length;

      final answers = <String, dynamic>{
        'q_canton': 'VD',
        'q_birth_year': null, // null should not count
      };

      final score = WizardService.calculateCompletionScore(answers, questions);
      expect(score, closeTo((1 / requiredCount) * 100, 0.1));
    });
  });

  group('WizardService.getNextMostValuableQuestion', () {
    test('returns highest priority question from remaining list', () {
      final questions = _buildTestQuestions();

      final next = WizardService.getNextMostValuableQuestion(questions, {});
      // q_canton is in the priority list, so it should be returned
      expect(next, isNotNull);
      expect(next!.id, 'q_canton');
    });

    test('returns q_birth_year when q_canton already answered', () {
      final questions = _buildTestQuestions()
          .where((q) => q.id != 'q_canton')
          .toList();

      final next = WizardService.getNextMostValuableQuestion(questions, {
        'q_canton': 'VD',
      });
      expect(next, isNotNull);
      expect(next!.id, 'q_birth_year');
    });

    test('returns null on empty remaining list', () {
      final result = WizardService.getNextMostValuableQuestion([], {});
      expect(result, isNull);
    });

    test('returns first question when no priority match found', () {
      final questions = [
        WizardQuestion(
          id: 'q_custom_unknown',
          title: 'Custom',
          type: QuestionType.text,
          required: false,
        ),
      ];

      final next = WizardService.getNextMostValuableQuestion(questions, {});
      expect(next, isNotNull);
      expect(next!.id, 'q_custom_unknown');
    });
  });

  group('WizardService.generateAnswersSummary', () {
    test('generates summary for answered questions', () {
      final questions = _buildTestQuestions();
      final answers = <String, dynamic>{
        'q_canton': 'VD',
        'q_birth_year': 1990,
      };

      final summary = WizardService.generateAnswersSummary(answers, questions);
      expect(summary.isNotEmpty, true);
      // Canton question title should be in the summary
      expect(summary.containsKey('Canton?'), true);
    });

    test('formats choice answer with label from options', () {
      final questions = _buildTestQuestions();
      final answers = <String, dynamic>{
        'q_canton': 'VD',
      };

      final summary = WizardService.generateAnswersSummary(answers, questions);
      expect(summary['Canton?'], 'Vaud');
    });

    test('formats input answer with CHF prefix when hint contains CHF', () {
      // Use a custom question with type=input and a CHF hint
      final questions = [
        WizardQuestion(
          id: 'q_income_chf',
          title: 'Revenu mensuel?',
          type: QuestionType.input,
          required: false,
          hint: 'CHF par mois',
        ),
      ];
      final answers = <String, dynamic>{
        'q_income_chf': 500,
      };

      final summary = WizardService.generateAnswersSummary(answers, questions);
      expect(summary['Revenu mensuel?'], 'CHF 500');
    });

    test('returns empty summary for empty answers', () {
      final questions = _buildTestQuestions();
      final summary = WizardService.generateAnswersSummary({}, questions);
      expect(summary, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // WizardConditionsService tests
  // ═══════════════════════════════════════════════════════════════════════

  group('WizardConditionsService.shouldAskQuestion', () {
    test('skips LPP buyback when user has no pension fund', () {
      final answers = <String, dynamic>{
        'q_has_pension_fund': 'no',
      };
      expect(
        WizardConditionsService.shouldAskQuestion('q_lpp_buyback_available', answers),
        false,
      );
    });

    test('asks LPP buyback when user has pension fund', () {
      final answers = <String, dynamic>{
        'q_has_pension_fund': 'yes',
      };
      expect(
        WizardConditionsService.shouldAskQuestion('q_lpp_buyback_available', answers),
        true,
      );
    });

    test('skips investments when user has consumer debt', () {
      final answers = <String, dynamic>{
        'q_has_consumer_debt': 'yes',
      };
      expect(
        WizardConditionsService.shouldAskQuestion('q_has_investments', answers),
        false,
      );
    });

    test('skips investments when user has no emergency fund', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'no',
      };
      expect(
        WizardConditionsService.shouldAskQuestion('q_has_investments', answers),
        false,
      );
    });

    test('asks investments when no debt and has emergency fund', () {
      final answers = <String, dynamic>{
        'q_has_consumer_debt': 'no',
        'q_emergency_fund': 'yes_6months',
      };
      expect(
        WizardConditionsService.shouldAskQuestion('q_has_investments', answers),
        true,
      );
    });

    test('skips 3a details when user does not have 3a', () {
      final answers = <String, dynamic>{
        'q_has_3a': 'no',
      };
      expect(
        WizardConditionsService.shouldAskQuestion('q_3a_accounts_count', answers),
        false,
      );
      expect(
        WizardConditionsService.shouldAskQuestion('q_3a_providers', answers),
        false,
      );
      expect(
        WizardConditionsService.shouldAskQuestion('q_3a_annual_contribution', answers),
        false,
      );
    });

    test('asks 3a details when user has 3a', () {
      final answers = <String, dynamic>{
        'q_has_3a': 'yes',
      };
      expect(
        WizardConditionsService.shouldAskQuestion('q_3a_accounts_count', answers),
        true,
      );
    });

    test('skips AVS contribution years when no AVS gaps', () {
      final answers = <String, dynamic>{
        'q_avs_gaps': 'no',
      };
      expect(
        WizardConditionsService.shouldAskQuestion('q_avs_contribution_years', answers),
        false,
      );
    });

    test('asks AVS contribution years when there are AVS gaps', () {
      final answers = <String, dynamic>{
        'q_avs_gaps': 'yes',
      };
      expect(
        WizardConditionsService.shouldAskQuestion('q_avs_contribution_years', answers),
        true,
      );
    });

    test('skips spouse AVS when not married', () {
      final answers = <String, dynamic>{
        'q_civil_status': 'single',
        'q_avs_gaps': 'yes',
      };
      expect(
        WizardConditionsService.shouldAskQuestion(
            'q_spouse_avs_contribution_years', answers),
        false,
      );
    });

    test('asks spouse AVS when married with AVS gaps', () {
      final answers = <String, dynamic>{
        'q_civil_status': 'married',
        'q_avs_gaps': 'yes',
      };
      expect(
        WizardConditionsService.shouldAskQuestion(
            'q_spouse_avs_contribution_years', answers),
        true,
      );
    });

    test('returns true for unknown question ID (default behavior)', () {
      expect(
        WizardConditionsService.shouldAskQuestion('q_unknown_id', {}),
        true,
      );
    });
  });

  group('WizardConditionsService.calculateTotalSteps', () {
    test('counts all eligible questions for empty answers', () {
      final total = WizardConditionsService.calculateTotalSteps({});
      // With empty answers, most conditions pass (default true)
      // except where specific conditions fail
      expect(total, greaterThan(0));
    });

    test('reduces step count when conditions filter out questions', () {
      final totalEmpty = WizardConditionsService.calculateTotalSteps({});

      final totalWithNo3a = WizardConditionsService.calculateTotalSteps({
        'q_has_3a': 'no',
        'q_has_pension_fund': 'no',
        'q_has_consumer_debt': 'yes',
        'q_avs_gaps': 'no',
      });

      // With many "no" answers, fewer questions should be shown
      expect(totalWithNo3a, lessThanOrEqualTo(totalEmpty));
    });
  });

  group('WizardConditionsService.getNextQuestion', () {
    test('returns null for last question in the list', () {
      // Use a nonexistent ID to simulate end
      final next = WizardConditionsService.getNextQuestion('nonexistent_id', {});
      expect(next, isNull);
    });
  });

  group('WizardQuestion.shouldShow', () {
    test('returns true when no condition is set', () {
      final question = WizardQuestion(
        id: 'q_test',
        title: 'Test',
        type: QuestionType.text,
      );
      expect(question.shouldShow({}), true);
    });

    test('returns false when condition evaluates to false', () {
      final question = WizardQuestion(
        id: 'q_cond',
        title: 'Conditional',
        type: QuestionType.text,
        condition: (answers) => answers['q_required_key'] == 'yes',
      );
      expect(question.shouldShow({}), false);
    });

    test('returns true when condition evaluates to true', () {
      final question = WizardQuestion(
        id: 'q_cond',
        title: 'Conditional',
        type: QuestionType.text,
        condition: (answers) => answers['q_required_key'] == 'yes',
      );
      expect(question.shouldShow({'q_required_key': 'yes'}), true);
    });
  });
}
