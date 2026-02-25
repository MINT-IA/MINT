import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/recommendations_service.dart';
import 'package:mint_mobile/models/recommendation.dart';
import 'package:mint_mobile/models/profile.dart';

/// Unit tests for RecommendationsService
///
/// Tests the personalized recommendation engine that generates
/// financial action items based on user profile data.
/// Priority ordering: Protection > 3a > LPP > Compound interest
void main() {
  /// Helper to create a Profile with sensible defaults
  Profile makeProfile({
    String id = 'test-user',
    int? birthYear = 1990,
    String? canton = 'VD',
    HouseholdType householdType = HouseholdType.single,
    double? incomeNetMonthly = 5000,
    double? incomeGrossYearly = 80000,
    double? savingsMonthly = 500,
    double? totalSavings = 10000,
    bool hasDebt = false,
    Goal goal = Goal.optimizeTaxes,
    EmploymentStatus? employmentStatus = EmploymentStatus.employee,
    bool? has2ndPillar = true,
  }) {
    return Profile(
      id: id,
      birthYear: birthYear,
      canton: canton,
      householdType: householdType,
      incomeNetMonthly: incomeNetMonthly,
      incomeGrossYearly: incomeGrossYearly,
      savingsMonthly: savingsMonthly,
      totalSavings: totalSavings,
      hasDebt: hasDebt,
      goal: goal,
      createdAt: DateTime(2025, 1, 1),
      employmentStatus: employmentStatus,
      has2ndPillar: has2ndPillar,
    );
  }

  group('Null profile (generic recommendations)', () {
    test('returns generic recommendations when profile is null', () {
      final recs = RecommendationsService.generateRecommendations(
        profile: null,
      );
      expect(recs, isNotEmpty);
      expect(recs.length, 1);
      expect(recs.first.id, 'start_advisor');
      expect(recs.first.kind, 'onboarding');
    });

    test('generic recommendation has next action', () {
      final recs = RecommendationsService.generateRecommendations(
        profile: null,
      );
      expect(recs.first.nextActions, isNotEmpty);
      expect(recs.first.nextActions.first.type, NextActionType.checklist);
    });
  });

  group('Protection recommendations (debt / low savings)', () {
    test('recommends emergency fund when user has debt', () {
      final profile = makeProfile(hasDebt: true, totalSavings: 5000);
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final emergencyRec = recs.where((r) => r.id == 'emergency_fund');
      expect(emergencyRec, isNotEmpty);
      expect(emergencyRec.first.kind, 'protection');
    });

    test('recommends emergency fund when savings < 3000', () {
      final profile = makeProfile(hasDebt: false, totalSavings: 1000);
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final emergencyRec = recs.where((r) => r.id == 'emergency_fund');
      expect(emergencyRec, isNotEmpty);
    });

    test('emergency fund recommendation calculates remaining amount', () {
      final profile = makeProfile(hasDebt: false, totalSavings: 1500);
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final emergencyRec = recs.firstWhere((r) => r.id == 'emergency_fund');
      // Target is 3000, savings is 1500 => remaining = 1500
      expect(emergencyRec.impact.amountCHF, 1500.0);
      expect(emergencyRec.impact.period, Period.oneoff);
    });

    test('no emergency fund recommendation when savings >= 3000 and no debt', () {
      final profile = makeProfile(hasDebt: false, totalSavings: 5000);
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final emergencyRec = recs.where((r) => r.id == 'emergency_fund');
      expect(emergencyRec, isEmpty);
    });
  });

  group('3a recommendations', () {
    test('recommends 3a for employed user with income and no debt', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 5000,
        employmentStatus: EmploymentStatus.employee,
        incomeGrossYearly: 80000,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final rec3a = recs.where((r) => r.id == 'pillar3a');
      expect(rec3a, isNotEmpty);
      expect(rec3a.first.kind, 'pillar3a');
    });

    test('3a recommendation estimates tax savings at 25% marginal rate', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 5000,
        employmentStatus: EmploymentStatus.employee,
        incomeGrossYearly: 80000,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final rec3a = recs.firstWhere((r) => r.id == 'pillar3a');
      // 7258 * 0.25 = 1814.5
      expect(rec3a.impact.amountCHF, closeTo(7258 * 0.25, 1.0));
      expect(rec3a.impact.period, Period.yearly);
    });

    test('no 3a recommendation when user has debt (protection first)', () {
      final profile = makeProfile(
        hasDebt: true,
        totalSavings: 5000,
        employmentStatus: EmploymentStatus.employee,
        incomeGrossYearly: 80000,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final rec3a = recs.where((r) => r.id == 'pillar3a');
      expect(rec3a, isEmpty);
    });

    test('no 3a recommendation when no income', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 5000,
        employmentStatus: EmploymentStatus.employee,
        incomeGrossYearly: 0,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final rec3a = recs.where((r) => r.id == 'pillar3a');
      expect(rec3a, isEmpty);
    });

    test('no 3a recommendation when employment status unknown', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 5000,
        employmentStatus: null,
        incomeGrossYearly: 80000,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final rec3a = recs.where((r) => r.id == 'pillar3a');
      expect(rec3a, isEmpty);
    });
  });

  group('LPP buyback recommendations', () {
    test('recommends LPP buyback for employee with LPP and high income', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 5000,
        employmentStatus: EmploymentStatus.employee,
        has2ndPillar: true,
        incomeGrossYearly: 120000,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final lppRec = recs.where((r) => r.id == 'lpp_buyback');
      expect(lppRec, isNotEmpty);
      expect(lppRec.first.kind, 'lpp');
    });

    test('no LPP recommendation for self-employed without LPP', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 5000,
        employmentStatus: EmploymentStatus.selfEmployed,
        has2ndPillar: false,
        incomeGrossYearly: 120000,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final lppRec = recs.where((r) => r.id == 'lpp_buyback');
      expect(lppRec, isEmpty);
    });

    test('no LPP recommendation for income below 80k threshold', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 5000,
        employmentStatus: EmploymentStatus.employee,
        has2ndPillar: true,
        incomeGrossYearly: 60000,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final lppRec = recs.where((r) => r.id == 'lpp_buyback');
      expect(lppRec, isEmpty);
    });
  });

  group('Compound interest recommendations', () {
    test('recommends compound interest when monthly savings > 0', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 5000,
        savingsMonthly: 500,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final compRec = recs.where((r) => r.id == 'compound_interest');
      expect(compRec, isNotEmpty);
    });

    test('compound interest uses correct formula', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 5000,
        savingsMonthly: 500,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final compRec = recs.firstWhere((r) => r.id == 'compound_interest');

      // Formula: monthlySavings * 12 * ((pow(1 + rate, years) - 1) / rate) * (1 + rate)
      // with rate=0.05, years=20, monthlySavings=500
      final futureValue = 500 * 12 * ((pow(1 + 0.05, 20) - 1) / 0.05) * (1 + 0.05);
      const totalInvested = 500.0 * 12 * 20;
      final expectedInterest = futureValue - totalInvested;

      expect(compRec.impact.amountCHF, closeTo(expectedInterest, 1.0));
    });

    test('no compound interest when savings = 0', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 5000,
        savingsMonthly: 0,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final compRec = recs.where((r) => r.id == 'compound_interest');
      expect(compRec, isEmpty);
    });

    test('no compound interest when savings is null', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 5000,
        savingsMonthly: null,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      final compRec = recs.where((r) => r.id == 'compound_interest');
      expect(compRec, isEmpty);
    });
  });

  group('Max recommendations limit', () {
    test('respects maxRecommendations default of 3', () {
      // Profile that qualifies for all 4 recommendations
      final profile = makeProfile(
        hasDebt: true, // triggers emergency fund
        totalSavings: 1000,
        savingsMonthly: 500,
        employmentStatus: EmploymentStatus.employee,
        has2ndPillar: true,
        incomeGrossYearly: 120000,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
      );
      expect(recs.length, lessThanOrEqualTo(3));
    });

    test('respects custom maxRecommendations = 1', () {
      final profile = makeProfile(
        hasDebt: true,
        totalSavings: 1000,
        savingsMonthly: 500,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
        maxRecommendations: 1,
      );
      expect(recs.length, 1);
    });

    test('respects custom maxRecommendations = 10 (returns all available)', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 5000,
        savingsMonthly: 500,
        employmentStatus: EmploymentStatus.employee,
        has2ndPillar: true,
        incomeGrossYearly: 120000,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
        maxRecommendations: 10,
      );
      // Should have 3a, LPP, compound interest (no emergency fund since no debt and savings > 3000)
      expect(recs.length, 3);
    });
  });

  group('Priority ordering', () {
    test('emergency fund comes before 3a and LPP', () {
      final profile = makeProfile(
        hasDebt: true, // triggers emergency fund
        totalSavings: 1000,
        savingsMonthly: 500,
        employmentStatus: EmploymentStatus.employee,
        has2ndPillar: true,
        incomeGrossYearly: 120000,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
        maxRecommendations: 10,
      );
      // Even though debt blocks 3a, emergency fund should be first
      expect(recs.first.id, 'emergency_fund');
    });

    test('debt-first rule: no 3a/LPP when debt exists', () {
      final profile = makeProfile(
        hasDebt: true,
        totalSavings: 5000,
        employmentStatus: EmploymentStatus.employee,
        has2ndPillar: true,
        incomeGrossYearly: 120000,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
        maxRecommendations: 10,
      );
      // Debt blocks 3a eligibility
      final rec3a = recs.where((r) => r.id == 'pillar3a');
      expect(rec3a, isEmpty);
    });
  });

  group('Recommendation data quality', () {
    test('all recommendations have non-empty id and title', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 5000,
        savingsMonthly: 500,
        employmentStatus: EmploymentStatus.employee,
        has2ndPillar: true,
        incomeGrossYearly: 120000,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
        maxRecommendations: 10,
      );
      for (final rec in recs) {
        expect(rec.id, isNotEmpty);
        expect(rec.title, isNotEmpty);
        expect(rec.summary, isNotEmpty);
        expect(rec.why, isNotEmpty);
        expect(rec.nextActions, isNotEmpty);
      }
    });

    test('all recommendations have at least one risk listed', () {
      final profile = makeProfile(
        hasDebt: false,
        totalSavings: 1000,
        savingsMonthly: 500,
        employmentStatus: EmploymentStatus.employee,
        has2ndPillar: true,
        incomeGrossYearly: 120000,
      );
      final recs = RecommendationsService.generateRecommendations(
        profile: profile,
        maxRecommendations: 10,
      );
      for (final rec in recs) {
        expect(rec.risks, isNotEmpty,
            reason: 'Recommendation ${rec.id} should list at least one risk');
      }
    });
  });
}
