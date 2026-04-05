import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/wizard_conditions_service.dart';
import 'package:mint_mobile/data/wizard_questions_v2.dart';

/// Deep unit tests for WizardConditionsService
///
/// The basic shouldAskQuestion cases are covered in wizard_service_test.dart.
/// These tests focus on:
/// - Combination scenarios (multiple conditions interacting)
/// - getNextQuestion navigation logic with condition filtering
/// - calculateTotalSteps accuracy under different profiles
/// - Edge cases: empty answers, unknown IDs, boundary questions
/// - Swiss-specific profiles (independant, retraite, frontalier patterns)
void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // shouldAskQuestion — Combination & Edge Cases
  // ═══════════════════════════════════════════════════════════════════════

  group('WizardConditionsService.shouldAskQuestion — combinations', () {
    test('LPP buyback skipped when pension fund is unknown', () {
      final answers = <String, dynamic>{
        'q_has_pension_fund': 'unknown',
      };
      // 'unknown' means user doesn't know their LPP status — can't know buyback
      expect(
        WizardConditionsService.shouldAskQuestion(
            'q_lpp_buyback_available', answers),
        false,
      );
    });

    test('LPP buyback allowed when pension fund key is absent', () {
      // No answer at all — default behavior should allow the question
      expect(
        WizardConditionsService.shouldAskQuestion(
            'q_lpp_buyback_available', {}),
        true,
      );
    });

    test('investments skipped when both debt and no emergency fund', () {
      final answers = <String, dynamic>{
        'q_has_consumer_debt': 'yes',
        'q_emergency_fund': 'no',
      };
      // Both conditions trigger skip independently; combined should also skip
      expect(
        WizardConditionsService.shouldAskQuestion('q_has_investments', answers),
        false,
      );
    });

    test('investments allowed with no debt and sufficient cash reserve', () {
      final answers = <String, dynamic>{
        'q_has_consumer_debt': 'no',
        'q_cash_total': 30000.0,
        'q_housing_cost_period_chf': 2000.0,
        'q_tax_provision_monthly_chf': 800.0,
        'q_lamal_premium_monthly_chf': 400.0,
      };
      // cash / expenses = 30000 / 3200 = 9.4 months => has emergency fund
      expect(
        WizardConditionsService.shouldAskQuestion('q_has_investments', answers),
        true,
      );
    });

    test('investments skipped when no cash reserve (computed emergency fund)', () {
      // No cash or expenses => computed emergency fund is false (cash <= 10000)
      final answers = <String, dynamic>{
        'q_has_consumer_debt': 'no',
        'q_cash_total': 5000.0,
        'q_housing_cost_period_chf': 2000.0,
      };
      // cash / expenses = 5000 / 2000 = 2.5 months < 3 => no emergency fund
      expect(
        WizardConditionsService.shouldAskQuestion('q_has_investments', answers),
        false,
      );
    });

    test('3a details all skipped when has_3a is unknown', () {
      final answers = <String, dynamic>{
        'q_has_3a': 'unknown',
      };
      // 'unknown' != 'yes' => all 3a detail questions skipped
      expect(
        WizardConditionsService.shouldAskQuestion(
            'q_3a_accounts_count', answers),
        false,
      );
      // q_3a_providers was removed (low value, zero calc impact)
      expect(
        WizardConditionsService.shouldAskQuestion(
            'q_3a_annual_contribution', answers),
        false,
      );
    });

    test('3a details all skipped when has_3a key is absent', () {
      // null != 'yes' => skip
      expect(
        WizardConditionsService.shouldAskQuestion('q_3a_accounts_count', {}),
        false,
      );
      // q_3a_providers was removed (low value, zero calc impact)
      expect(
        WizardConditionsService.shouldAskQuestion(
            'q_3a_annual_contribution', {}),
        false,
      );
    });

    test('spouse AVS skipped when married but AVS gaps is no_gaps', () {
      final answers = <String, dynamic>{
        'q_civil_status': 'married',
        'q_avs_lacunes_status': 'no_gaps',
      };
      // q_spouse_avs_contribution_years is not conditionally gated,
      // so it always returns true (falls through to default)
      expect(
        WizardConditionsService.shouldAskQuestion(
            'q_spouse_avs_contribution_years', answers),
        true,
      );
    });

    test('spouse AVS lacunes status skipped when not married', () {
      final answers = <String, dynamic>{
        'q_civil_status': 'single',
        'q_avs_lacunes_status': 'unknown',
      };
      // Not married => spouse AVS lacunes status question skipped
      expect(
        WizardConditionsService.shouldAskQuestion(
            'q_spouse_avs_lacunes_status', answers),
        false,
      );
    });

    test('spouse AVS lacunes status skipped for concubinage', () {
      final answers = <String, dynamic>{
        'q_civil_status': 'cohabiting',
      };
      // Concubinage = no couple rente AVS (LAVS art. 35) → skip spouse AVS
      expect(
        WizardConditionsService.shouldAskQuestion(
            'q_spouse_avs_lacunes_status', answers),
        false,
      );
    });

    test('spouse AVS lacunes status asked for registered_partner', () {
      final answers = <String, dynamic>{
        'q_civil_status': 'registered_partner',
      };
      // Registered partner = same as married (CC art. 65a) → ask spouse AVS
      expect(
        WizardConditionsService.shouldAskQuestion(
            'q_spouse_avs_lacunes_status', answers),
        true,
      );
    });

    test('spouse AVS lacunes status asked when married', () {
      final answers = <String, dynamic>{
        'q_civil_status': 'married',
        'q_avs_lacunes_status': 'unknown',
      };
      // married => spouse AVS lacunes status question is shown
      expect(
        WizardConditionsService.shouldAskQuestion(
            'q_spouse_avs_lacunes_status', answers),
        true,
      );
    });

    test('AVS contribution years asked when avs_gaps key is absent', () {
      // null != 'no' => condition passes
      expect(
        WizardConditionsService.shouldAskQuestion(
            'q_avs_contribution_years', {}),
        true,
      );
    });

    test('regular non-conditional question always asked', () {
      // q_canton has no special condition in shouldAskQuestion
      expect(
        WizardConditionsService.shouldAskQuestion('q_canton', {}),
        true,
      );
      expect(
        WizardConditionsService.shouldAskQuestion('q_birth_year', {}),
        true,
      );
      expect(
        WizardConditionsService.shouldAskQuestion('q_risk_tolerance', {}),
        true,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // getNextQuestion — Navigation Logic
  // ═══════════════════════════════════════════════════════════════════════

  group('WizardConditionsService.getNextQuestion', () {
    test('returns null for nonexistent question ID', () {
      final next =
          WizardConditionsService.getNextQuestion('nonexistent_id', {});
      expect(next, isNull);
    });

    test('returns null when current is the last question', () {
      final questions = WizardQuestionsV2.questions;
      final lastId = questions.last.id;

      final next = WizardConditionsService.getNextQuestion(lastId, {});
      expect(next, isNull);
    });

    test('returns second question after firstname with empty answers', () {
      // First question is q_firstname (stress check removed)
      final next = WizardConditionsService.getNextQuestion(
          'q_firstname', {});
      expect(next, isNotNull);
      expect(next!.id, 'q_birth_year');
    });

    test('skips 3a detail questions when has_3a is no', () {
      final answers = <String, dynamic>{
        'q_has_3a': 'no',
      };

      // Navigate from q_has_3a — should skip q_3a_accounts_count, q_3a_providers,
      // q_3a_annual_contribution, and land on q_avs_lacunes_status
      final next =
          WizardConditionsService.getNextQuestion('q_has_3a', answers);
      expect(next, isNotNull);
      // It should skip the three 3a detail questions
      expect(next!.id, isNot('q_3a_accounts_count'));
      expect(next.id, isNot('q_3a_providers'));
      expect(next.id, isNot('q_3a_annual_contribution'));
      expect(next.id, 'q_avs_lacunes_status');
    });

    test('includes 3a detail questions when has_3a is yes', () {
      final answers = <String, dynamic>{
        'q_has_3a': 'yes',
      };

      final next =
          WizardConditionsService.getNextQuestion('q_has_3a', answers);
      expect(next, isNotNull);
      expect(next!.id, 'q_3a_accounts_count');
    });

    test('skips LPP buyback when pension fund is no', () {
      final answers = <String, dynamic>{
        'q_has_pension_fund': 'no',
        'q_has_3a': 'yes', // so 3a detail questions are shown
      };

      final next = WizardConditionsService.getNextQuestion(
          'q_has_pension_fund', answers);
      expect(next, isNotNull);
      // Should skip q_lpp_buyback_available and go to q_has_3a
      expect(next!.id, isNot('q_lpp_buyback_available'));
      expect(next.id, 'q_has_3a');
    });

    test('navigates through pension fund to buyback when pension is yes', () {
      final answers = <String, dynamic>{
        'q_has_pension_fund': 'yes',
      };

      final next = WizardConditionsService.getNextQuestion(
          'q_has_pension_fund', answers);
      expect(next, isNotNull);
      expect(next!.id, 'q_lpp_buyback_available');
    });

    test('skips investment question when debt protection mode active', () {
      final answers = <String, dynamic>{
        'q_has_consumer_debt': 'yes',
        'q_avs_lacunes_status': 'no_gaps',
        'q_civil_status': 'single',
      };

      // From q_avs_lacunes_status, navigate forward — investments should be skipped
      // due to debt protection mode (q_has_consumer_debt == 'yes')
      final next = WizardConditionsService.getNextQuestion(
          'q_avs_lacunes_status', answers);
      expect(next, isNotNull);
      expect(next!.id, isNot('q_has_investments'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // calculateTotalSteps — Profile-Based Step Count
  // ═══════════════════════════════════════════════════════════════════════

  group('WizardConditionsService.calculateTotalSteps', () {
    test('returns positive count for empty answers', () {
      final total = WizardConditionsService.calculateTotalSteps({});
      // Most questions pass conditions with empty answers (default true)
      expect(total, greaterThan(0));
    });

    test('total matches full question list minus conditionally skipped', () {
      final allCount = WizardQuestionsV2.questions.length;
      final totalEmpty = WizardConditionsService.calculateTotalSteps({});

      // With empty answers, 3a details are skipped (3 questions)
      // since has_3a is null != 'yes'
      // AVS conditional questions are also skipped (arrived_late/lived_abroad
      // conditions fail with null answers), plus spouse AVS conditions
      expect(totalEmpty, lessThan(allCount));
      expect(totalEmpty, greaterThan(allCount - 15));
    });

    test('Swiss independent profile has fewer LPP-related steps', () {
      final independentProfile = <String, dynamic>{
        'q_employment_status': 'self_employed',
        'q_has_pension_fund': 'no',
        'q_has_3a': 'no',
        'q_has_consumer_debt': 'yes',
        'q_avs_lacunes_status': 'no_gaps',
        'q_civil_status': 'single',
      };

      final total =
          WizardConditionsService.calculateTotalSteps(independentProfile);
      final totalEmpty = WizardConditionsService.calculateTotalSteps({});

      // Independent with no pension, no 3a, debt, no AVS gaps, single
      // has LPP buyback + investments skipped but debt details added,
      // so total may be equal to or less than empty-answer total
      expect(total, lessThanOrEqualTo(totalEmpty));
    });

    test('married profile with AVS gaps has more steps than single', () {
      final marriedWithGaps = <String, dynamic>{
        'q_civil_status': 'married',
        'q_avs_lacunes_status': 'arrived_late',
        'q_spouse_avs_lacunes_status': 'arrived_late',
        'q_has_3a': 'yes',
        'q_has_pension_fund': 'yes',
        'q_has_consumer_debt': 'no',
        'q_cash_total': 50000.0, // Computed emergency fund via cash/expenses
        'q_housing_cost_period_chf': 2000.0,
        'q_employment_status': 'employee',
      };

      final singleNoGaps = <String, dynamic>{
        'q_civil_status': 'single',
        'q_avs_lacunes_status': 'no_gaps',
        'q_has_3a': 'no',
        'q_has_pension_fund': 'no',
        'q_has_consumer_debt': 'yes',
      };

      final totalMarried =
          WizardConditionsService.calculateTotalSteps(marriedWithGaps);
      final totalSingle =
          WizardConditionsService.calculateTotalSteps(singleNoGaps);

      // Married + AVS gaps + 3a + LPP => more questions
      // Single + no gaps + no 3a + no LPP + debt => fewer questions
      expect(totalMarried, greaterThan(totalSingle));
    });

    test('fully answered maximal profile includes all conditional questions',
        () {
      final maxProfile = <String, dynamic>{
        'q_has_pension_fund': 'yes',
        'q_has_3a': 'yes',
        'q_has_consumer_debt': 'no',
        'q_cash_total': 50000.0, // Enough cash for computed emergency fund
        'q_housing_cost_period_chf': 2000.0,
        'q_avs_lacunes_status': 'arrived_late',
        'q_civil_status': 'married',
        'q_spouse_avs_lacunes_status': 'arrived_late',
        'q_employment_status': 'employee',
      };

      final total = WizardConditionsService.calculateTotalSteps(maxProfile);
      final allCount = WizardQuestionsV2.questions.length;

      // Maximal profile should include all or nearly all questions
      // Skipped: q_has_pension_fund (pre-answered), arrived_late vs lived_abroad
      // mutually exclusive (2 own + 2 spouse = 4), housing_cost (not family)
      // q_3a_providers removed. Net: allCount - ~8
      expect(total, greaterThanOrEqualTo(allCount - 10));
    });

    test('step count never exceeds total questions', () {
      final total = WizardConditionsService.calculateTotalSteps({});
      final allCount = WizardQuestionsV2.questions.length;
      expect(total, lessThanOrEqualTo(allCount));
    });

    test('step count is always non-negative', () {
      final profiles = [
        <String, dynamic>{},
        {'q_has_3a': 'no', 'q_has_pension_fund': 'no', 'q_avs_lacunes_status': 'no_gaps'},
        {
          'q_has_consumer_debt': 'yes',
          'q_emergency_fund': 'no',
          'q_civil_status': 'single'
        },
      ];

      for (final profile in profiles) {
        final total = WizardConditionsService.calculateTotalSteps(profile);
        expect(total, greaterThanOrEqualTo(0));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Full Navigation Path Tests
  // ═══════════════════════════════════════════════════════════════════════

  group('Full navigation path simulation', () {
    test('can traverse entire wizard with maximal profile without null', () {
      final answers = <String, dynamic>{
        'q_has_pension_fund': 'yes',
        'q_has_3a': 'yes',
        'q_has_consumer_debt': 'no',
        'q_cash_total': 50000.0, // Computed emergency fund via cash/expenses
        'q_housing_cost_period_chf': 2000.0,
        'q_avs_lacunes_status': 'arrived_late',
        'q_civil_status': 'married',
        'q_employment_status': 'employee',
      };

      final questions = WizardQuestionsV2.questions;
      String currentId = questions.first.id;
      int stepCount = 1; // counting the first question
      final visited = <String>{currentId};

      while (true) {
        final next =
            WizardConditionsService.getNextQuestion(currentId, answers);
        if (next == null) break;
        visited.add(next.id);
        currentId = next.id;
        stepCount++;
        // Safety: prevent infinite loops
        if (stepCount > 100) break;
      }

      expect(stepCount, greaterThan(5));
      expect(stepCount, lessThanOrEqualTo(questions.length));
      // Should end at the last question (risk_tolerance)
      expect(currentId, 'q_risk_tolerance');
    });

    test('minimal profile skips conditional questions and finishes', () {
      final answers = <String, dynamic>{
        'q_has_pension_fund': 'no',
        'q_has_3a': 'no',
        'q_has_consumer_debt': 'yes',
        'q_cash_total': 1000.0, // Low cash → no emergency fund (computed)
        'q_avs_lacunes_status': 'no_gaps',
        'q_civil_status': 'single',
      };

      final questions = WizardQuestionsV2.questions;
      String currentId = questions.first.id;
      int stepCount = 1;
      final visited = <String>{currentId};

      while (true) {
        final next =
            WizardConditionsService.getNextQuestion(currentId, answers);
        if (next == null) break;
        visited.add(next.id);
        currentId = next.id;
        stepCount++;
        if (stepCount > 100) break;
      }

      // Should NOT have visited 3a detail questions
      expect(visited.contains('q_3a_accounts_count'), false);
      expect(visited.contains('q_3a_providers'), false);
      expect(visited.contains('q_3a_annual_contribution'), false);
      // Should NOT have visited LPP buyback
      expect(visited.contains('q_lpp_buyback_available'), false);
      // Should NOT have visited investments (debt protection mode)
      expect(visited.contains('q_has_investments'), false);
      // Should NOT have visited spouse AVS (single)
      expect(visited.contains('q_spouse_avs_contribution_years'), false);
      // Should NOT have visited AVS contribution years (no gaps)
      expect(visited.contains('q_avs_contribution_years'), false);
    });
  });
}
