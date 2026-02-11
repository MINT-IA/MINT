import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/circle_scoring_service.dart';
import 'package:mint_mobile/models/circle_score.dart';

/// Unit tests for CircleScoringService
///
/// Tests the financial health score calculation engine that evaluates
/// a user's financial situation across 4 circles:
///   1. Protection (emergency fund, debt, income)
///   2. Prevoyance (3a, LPP, AVS)
///   3. Croissance (investments, real estate)
///   4. Optimisation (placeholder)
void main() {
  late CircleScoringService service;

  setUp(() {
    service = CircleScoringService();
  });

  group('Overall score calculation', () {
    test('calculates weighted average across all 4 circles', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_net_income_period_chf': 6000,
        'q_3a_accounts_count': 3,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'no',
        'q_has_investments': 'yes',
        'q_housing_status': 'owner',
      };

      final score = service.calculateScore(answers);

      // Weights: C1=35%, C2=35%, C3=20%, C4=10%
      expect(score.overallScore, greaterThan(0));
      expect(score.overallScore, lessThanOrEqualTo(100));
      expect(score.allCircles.length, 4);
    });

    test('returns top priorities (max 3)', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'no',
        'q_has_consumer_debt': 'yes',
        'q_net_income_period_chf': 5000,
        'q_3a_accounts_count': 0,
        'q_employment_status': 'employee',
        'q_avs_gaps': null,
      };

      final score = service.calculateScore(answers);
      expect(score.topPriorities.length, lessThanOrEqualTo(3));
    });

    test('excellent profile scores high overall', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_net_income_period_chf': 10000,
        'q_3a_accounts_count': 3,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'no',
        'q_has_investments': 'yes',
        'q_housing_status': 'owner',
      };

      final score = service.calculateScore(answers);
      expect(score.overallScore, greaterThan(50));
    });

    test('poor profile scores low overall', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'no',
        'q_has_consumer_debt': 'yes',
        'q_3a_accounts_count': 0,
        'q_employment_status': 'employee',
        'q_avs_gaps': 'yes',
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      expect(score.overallScore, lessThan(50));
    });
  });

  group('Circle 1 - Protection', () {
    test('perfect emergency fund (6 months) scores perfect', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_net_income_period_chf': 5000,
        'q_3a_accounts_count': 0,
        'q_employment_status': 'employee',
        'q_avs_gaps': null,
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c1 = score.circle1Protection;
      expect(c1.circleNumber, 1);
      expect(c1.circleName, 'Protection & Sécurité');
      expect(c1.percentage, greaterThan(70));
    });

    test('consumer debt drops protection score to critical', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'no',
        'q_has_consumer_debt': 'yes',
        'q_3a_accounts_count': 0,
        'q_employment_status': 'employee',
        'q_avs_gaps': null,
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c1 = score.circle1Protection;
      // With no emergency fund (critical, weight 2.0) and debt (critical, weight 1.5)
      // the score should be very low
      expect(c1.percentage, lessThan(60));
    });

    test('3-month emergency fund scores good', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_3months',
        'q_has_consumer_debt': 'no',
        'q_net_income_period_chf': 5000,
        'q_3a_accounts_count': 0,
        'q_employment_status': 'employee',
        'q_avs_gaps': null,
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c1 = score.circle1Protection;
      // 3-month fund scores "good" (0.75), not "perfect" (1.0)
      expect(c1.percentage, greaterThan(50));
      expect(c1.percentage, lessThan(100));
    });

    test('no income is treated as unknown (neutral)', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        // no q_net_income_period_chf
        'q_3a_accounts_count': 0,
        'q_employment_status': 'employee',
        'q_avs_gaps': null,
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c1 = score.circle1Protection;
      // Income unknown = 0.5 score value, still decent overall
      expect(c1.percentage, greaterThan(50));
    });

    test('generates debt priority recommendation when debt exists', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'no',
        'q_has_consumer_debt': 'yes',
        'q_3a_accounts_count': 0,
        'q_employment_status': 'employee',
        'q_avs_gaps': null,
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c1 = score.circle1Protection;
      // Should recommend paying off debt first
      expect(
        c1.recommendations.any((r) => r.contains('dette') || r.contains('PRIORIT')),
        true,
      );
    });
  });

  group('Circle 2 - Prevoyance', () {
    test('multiple 3a accounts score perfect', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_net_income_period_chf': 5000,
        'q_3a_accounts_count': 3,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'no',
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      expect(c2.circleNumber, 2);
      expect(c2.percentage, greaterThan(70));
    });

    test('zero 3a accounts scores critical', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 0,
        'q_3a_annual_contribution': null,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': null,
        'q_avs_gaps': null,
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      // 0 accounts = critical for the account item
      expect(c2.percentage, lessThan(80));
    });

    test('AVS gaps detected lowers score', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'yes',
        'q_avs_contribution_years': 30,
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      // 44 - 30 = 14 years gap => warning
      final avsItem = c2.items.firstWhere((i) => i.label == 'AVS');
      expect(avsItem.status, ItemStatus.warning);
    });

    test('full AVS contributions score perfect', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'yes',
        'q_avs_contribution_years': 44,
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      final avsItem = c2.items.firstWhere((i) => i.label == 'AVS');
      expect(avsItem.status, ItemStatus.perfect);
    });

    test('spouse AVS gap downgrades married user score', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'yes',
        'q_avs_contribution_years': 44,
        'q_civil_status': 'married',
        'q_spouse_avs_contribution_years': 30,
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      final avsItem = c2.items.firstWhere((i) => i.label == 'AVS');
      // Despite user having 44 years, spouse has gap => warning
      expect(avsItem.status, ItemStatus.warning);
      expect(avsItem.detail, contains('Conjoint'));
    });

    test('LPP buyback available scores good (opportunity)', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 50000.0,
        'q_avs_gaps': 'no',
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      final lppItem = c2.items.firstWhere((i) => i.label == 'LPP - Rachat');
      expect(lppItem.status, ItemStatus.good);
    });

    test('no LPP gap scores perfect', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'no',
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      final lppItem = c2.items.firstWhere((i) => i.label == 'LPP - Rachat');
      expect(lppItem.status, ItemStatus.perfect);
    });

    test('recommends opening 2nd 3a account when only 1', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 1,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'no',
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      expect(
        c2.recommendations.any((r) => r.contains('2e compte 3a') || r.contains('VIAC')),
        true,
      );
    });

    test('recommends LPP buyback when gap > 50k', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 3,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 60000.0,
        'q_avs_gaps': 'no',
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      expect(
        c2.recommendations.any((r) => r.contains('rachat LPP')),
        true,
      );
    });
  });

  group('Circle 3 - Croissance', () {
    test('investor + owner scores good', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 0,
        'q_employment_status': 'employee',
        'q_avs_gaps': null,
        'q_has_investments': 'yes',
        'q_housing_status': 'owner',
      };

      final score = service.calculateScore(answers);
      final c3 = score.circle3Croissance;
      expect(c3.circleNumber, 3);
      // Both items are "good" (0.75 each)
      expect(c3.percentage, 75.0);
    });

    test('no investments and renter scores warning', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 0,
        'q_employment_status': 'employee',
        'q_avs_gaps': null,
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c3 = score.circle3Croissance;
      // Both items are "warning" (0.5 each)
      expect(c3.percentage, 50.0);
    });
  });

  group('Circle 4 - Optimisation', () {
    test('always returns static placeholder with 20% score', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 0,
        'q_employment_status': 'employee',
        'q_avs_gaps': null,
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c4 = score.circle4Optimisation;
      expect(c4.circleNumber, 4);
      expect(c4.percentage, 20.0);
      expect(c4.level, ScoreLevel.needsImprovement);
    });
  });

  group('ScoreLevel mapping', () {
    test('perfect profile reaches at least good level', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_net_income_period_chf': 10000,
        'q_3a_accounts_count': 3,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'no',
        'q_has_investments': 'yes',
        'q_housing_status': 'owner',
      };

      final score = service.calculateScore(answers);
      // Circle 4 is fixed at 20%, so overall can't be excellent
      // But C1, C2, C3 should be high
      expect(score.circle1Protection.level, isIn([ScoreLevel.good, ScoreLevel.excellent]));
    });
  });

  group('Empty and minimal answers', () {
    test('empty answers do not crash', () {
      final answers = <String, dynamic>{};
      // Should not throw; missing keys result in null/default values
      final score = service.calculateScore(answers);
      expect(score.overallScore, isNotNull);
      expect(score.allCircles.length, 4);
    });

    test('only employment status provided still computes', () {
      final answers = <String, dynamic>{
        'q_employment_status': 'employee',
      };

      final score = service.calculateScore(answers);
      expect(score.overallScore, greaterThanOrEqualTo(0));
    });
  });

  group('3a contribution scoring tiers', () {
    test('contribution >= 90% of max is perfect', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': 7000.0, // > 90% of 7258
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'no',
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      final contrib = c2.items.firstWhere((i) => i.label == '3a - Versement');
      expect(contrib.status, ItemStatus.perfect);
    });

    test('contribution 50-89% of max is good', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': 5000.0, // ~69% of 7258
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'no',
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      final contrib = c2.items.firstWhere((i) => i.label == '3a - Versement');
      expect(contrib.status, ItemStatus.good);
    });

    test('small contribution is warning', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': 1000.0, // ~14% of 7258
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'no',
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      final contrib = c2.items.firstWhere((i) => i.label == '3a - Versement');
      expect(contrib.status, ItemStatus.warning);
    });

    test('zero contribution is critical', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': null,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'no',
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      final contrib = c2.items.firstWhere((i) => i.label == '3a - Versement');
      expect(contrib.status, ItemStatus.critical);
    });
  });

  group('AVS gap severity', () {
    test('minor gap (<=2 years) is good', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'yes',
        'q_avs_contribution_years': 42, // gap = 2
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      final avs = c2.items.firstWhere((i) => i.label == 'AVS');
      expect(avs.status, ItemStatus.good);
    });

    test('large gap (>2 years) is warning', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': 'yes',
        'q_avs_contribution_years': 35, // gap = 9
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      final avs = c2.items.firstWhere((i) => i.label == 'AVS');
      expect(avs.status, ItemStatus.warning);
      expect(avs.detail, contains('Rente'));
    });

    test('unknown AVS status scores as unknown', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_avs_gaps': null,
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };

      final score = service.calculateScore(answers);
      final c2 = score.circle2Prevoyance;
      final avs = c2.items.firstWhere((i) => i.label == 'AVS');
      expect(avs.status, ItemStatus.unknown);
    });
  });
}
