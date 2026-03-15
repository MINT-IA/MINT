import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/services/coaching_service.dart';

/// Unit tests for CoachingService — Sprint S11 (Coaching proactif)
///
/// Tests pure Dart coaching tip generation based on user financial profile.
/// All coaching triggers are tested: missing 3a, LPP buyback, emergency fund,
/// debt ratio, age milestones, part-time gap, independent alert, budget.
///
/// Legal references: LPP, OPP3, LAVS, LIFD, LHID, FINMA
void main() {
  // ════════════════════════════════════════════════════════════
  //  MISSING 3A TRIGGER
  // ════════════════════════════════════════════════════════════

  group('CoachingService - Missing 3a', () {
    test('user without 3a and with income triggers missing_3a tip', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 30,
          canton: 'VD',
          revenuAnnuel: 80000,
          has3a: false,
          has3aAnswered: true,
          hasLpp: true,
          avoirLpp: 100000,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final missing3a = tips.where((t) => t.id == 'missing_3a');
      expect(missing3a, isNotEmpty, reason: 'Should trigger missing_3a tip');

      final tip = missing3a.first;
      expect(tip.category, 'prevoyance');
      expect(tip.priority, CoachingPriority.haute);
      expect(tip.source, isNotEmpty);
      expect(tip.estimatedImpactChf, isNotNull);
      expect(tip.estimatedImpactChf!, greaterThan(0));
    });

    test('user with 3a does not trigger missing_3a tip', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 30,
          canton: 'VD',
          revenuAnnuel: 80000,
          has3a: true,
          montant3a: 5000,
          hasLpp: true,
          avoirLpp: 100000,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final missing3a = tips.where((t) => t.id == 'missing_3a');
      expect(missing3a, isEmpty);
    });

    test('user without income does not trigger missing_3a tip', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 30,
          canton: 'VD',
          revenuAnnuel: 0,
          has3a: false,
          employmentStatus: EmploymentStatus.sansEmploi,
        ),
      );

      final missing3a = tips.where((t) => t.id == 'missing_3a');
      expect(missing3a, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  LPP BUYBACK TRIGGER
  // ════════════════════════════════════════════════════════════

  group('CoachingService - LPP Buyback', () {
    test('user with LPP lacune triggers lpp_buyback tip', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 45,
          canton: 'ZH',
          revenuAnnuel: 120000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          avoirLpp: 200000,
          lacuneLpp: 60000,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final buyback = tips.where((t) => t.id == 'lpp_buyback');
      expect(buyback, isNotEmpty);

      final tip = buyback.first;
      expect(tip.category, 'prevoyance');
      expect(tip.source, contains('LPP'));
      expect(tip.estimatedImpactChf, isNotNull);
      expect(tip.estimatedImpactChf!, greaterThan(0));
    });

    test('large lacune > 50k sets haute priority', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 45,
          canton: 'VD',
          revenuAnnuel: 120000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          avoirLpp: 200000,
          lacuneLpp: 80000,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final buyback = tips.firstWhere((t) => t.id == 'lpp_buyback');
      expect(buyback.priority, CoachingPriority.haute);
    });

    test('small lacune <= 50k sets moyenne priority', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 45,
          canton: 'VD',
          revenuAnnuel: 120000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          avoirLpp: 200000,
          lacuneLpp: 30000,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final buyback = tips.firstWhere((t) => t.id == 'lpp_buyback');
      expect(buyback.priority, CoachingPriority.moyenne);
    });

    test('no lacune does not trigger lpp_buyback', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 45,
          canton: 'VD',
          revenuAnnuel: 120000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          avoirLpp: 200000,
          lacuneLpp: 0,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final buyback = tips.where((t) => t.id == 'lpp_buyback');
      expect(buyback, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  EMERGENCY FUND TRIGGER
  // ════════════════════════════════════════════════════════════

  group('CoachingService - Emergency Fund', () {
    test('savings < 1 month of charges triggers haute priority', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 30,
          canton: 'GE',
          revenuAnnuel: 80000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          hasSavingsAnswered: true,
          chargesFixesMensuelles: 4000,
          epargneDispo: 2000, // 0.5 months
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final emergency = tips.firstWhere((t) => t.id == 'emergency_fund');
      expect(emergency.priority, CoachingPriority.haute);
      expect(emergency.category, 'budget');
      expect(emergency.estimatedImpactChf, isNotNull);
      // Deficit = 3 * 4000 - 2000 = 10000
      expect(emergency.estimatedImpactChf!, closeTo(10000, 0.01));
    });

    test('savings between 1-3 months triggers moyenne priority', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 30,
          canton: 'GE',
          revenuAnnuel: 80000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          hasSavingsAnswered: true,
          chargesFixesMensuelles: 3000,
          epargneDispo: 5000, // ~1.7 months
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final emergency = tips.firstWhere((t) => t.id == 'emergency_fund');
      expect(emergency.priority, CoachingPriority.moyenne);
    });

    test('savings >= 3 months does not trigger emergency_fund', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 30,
          canton: 'GE',
          revenuAnnuel: 80000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          chargesFixesMensuelles: 3000,
          epargneDispo: 12000, // 4 months
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final emergency = tips.where((t) => t.id == 'emergency_fund');
      expect(emergency, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  DEBT RATIO TRIGGER
  // ════════════════════════════════════════════════════════════

  group('CoachingService - Debt Ratio', () {
    test('high debt ratio triggers debt_ratio tip', () {
      // Monthly income: 60000/12 = 5000
      // Debt service: 500000 * (0.03 + 0.05) / 12 = ~3333
      // Ratio: 3333 / 5000 = 66.7% > 33%
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 40,
          canton: 'VD',
          revenuAnnuel: 60000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          detteTotale: 500000,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final debt = tips.where((t) => t.id == 'debt_ratio');
      expect(debt, isNotEmpty);
      expect(debt.first.category, 'budget');
    });

    test('no debt does not trigger debt_ratio tip', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 40,
          canton: 'VD',
          revenuAnnuel: 80000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          detteTotale: 0,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final debt = tips.where((t) => t.id == 'debt_ratio');
      expect(debt, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  RETIREMENT COUNTDOWN TRIGGER
  // ════════════════════════════════════════════════════════════

  group('CoachingService - Retirement Countdown', () {
    test('age 50-60 triggers retirement_countdown tip', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 55,
          canton: 'VD',
          revenuAnnuel: 120000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          avoirLpp: 500000,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final retirement = tips.where((t) => t.id == 'retirement_countdown');
      expect(retirement, isNotEmpty);

      final tip = retirement.first;
      expect(tip.category, 'retraite');
      expect(tip.title, contains('10 ans'));
      expect(tip.source, contains('LAVS'));
    });

    test('age <= 5 years to retirement sets haute priority', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 62,
          canton: 'VD',
          revenuAnnuel: 120000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          avoirLpp: 500000,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final retirement = tips.firstWhere((t) => t.id == 'retirement_countdown');
      expect(retirement.priority, CoachingPriority.haute);
    });

    test('age < 50 does not trigger retirement_countdown', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 40,
          canton: 'VD',
          revenuAnnuel: 80000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final retirement = tips.where((t) => t.id == 'retirement_countdown');
      expect(retirement, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  INDEPENDENT ALERT TRIGGER
  // ════════════════════════════════════════════════════════════

  group('CoachingService - Independent Alert', () {
    test('independent worker triggers independant_alert tip', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 35,
          canton: 'VD',
          revenuAnnuel: 100000,
          has3a: false,
          hasLpp: false,
          employmentStatus: EmploymentStatus.independant,
        ),
      );

      final indep = tips.where((t) => t.id == 'independant_alert');
      expect(indep, isNotEmpty);

      final tip = indep.first;
      expect(tip.priority, CoachingPriority.haute);
      expect(tip.category, 'prevoyance');
      expect(tip.estimatedImpactChf, isNotNull);
      expect(tip.estimatedImpactChf!, greaterThan(0));
    });

    test('salaried worker does not trigger independant_alert', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 35,
          canton: 'VD',
          revenuAnnuel: 100000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final indep = tips.where((t) => t.id == 'independant_alert');
      expect(indep, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  BUDGET MISSING TRIGGER
  // ════════════════════════════════════════════════════════════

  group('CoachingService - Budget Missing', () {
    test('user without budget triggers budget_missing tip', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 30,
          canton: 'GE',
          revenuAnnuel: 60000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          hasBudget: false,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final budget = tips.where((t) => t.id == 'budget_missing');
      expect(budget, isNotEmpty);
      expect(budget.first.priority, CoachingPriority.moyenne);
      expect(budget.first.category, 'budget');
    });

    test('user with budget does not trigger budget_missing tip', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 30,
          canton: 'GE',
          revenuAnnuel: 60000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          hasBudget: true,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final budget = tips.where((t) => t.id == 'budget_missing');
      expect(budget, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  PART-TIME GAP TRIGGER
  // ════════════════════════════════════════════════════════════

  group('CoachingService - Part-Time Gap', () {
    test('part-time < 60% triggers haute priority', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 35,
          canton: 'VD',
          revenuAnnuel: 48000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          tauxActivite: 50,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final partTime = tips.where((t) => t.id == 'part_time_gap');
      expect(partTime, isNotEmpty);
      expect(partTime.first.priority, CoachingPriority.haute);
      expect(partTime.first.message, contains('50'));
    });

    test('part-time 60-99% triggers moyenne priority', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 35,
          canton: 'VD',
          revenuAnnuel: 64000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          tauxActivite: 80,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final partTime = tips.where((t) => t.id == 'part_time_gap');
      expect(partTime, isNotEmpty);
      expect(partTime.first.priority, CoachingPriority.moyenne);
    });

    test('100% activity does not trigger part_time_gap', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 35,
          canton: 'VD',
          revenuAnnuel: 80000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          tauxActivite: 100,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final partTime = tips.where((t) => t.id == 'part_time_gap');
      expect(partTime, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  AGE MILESTONES TRIGGER
  // ════════════════════════════════════════════════════════════

  group('CoachingService - Age Milestones', () {
    test('age 25 triggers milestone tip', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 25,
          canton: 'VD',
          revenuAnnuel: 50000,
          has3a: false,
          hasLpp: true,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final milestone = tips.where((t) => t.id == 'age_milestone_25');
      expect(milestone, isNotEmpty);
      expect(milestone.first.priority, CoachingPriority.basse);
      expect(milestone.first.title, contains('25 ans'));
    });

    test('age 50 triggers milestone tip with moyenne priority', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 50,
          canton: 'VD',
          revenuAnnuel: 120000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          avoirLpp: 400000,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final milestone = tips.where((t) => t.id == 'age_milestone_50');
      expect(milestone, isNotEmpty);
      expect(milestone.first.priority, CoachingPriority.moyenne);
    });

    test('non-milestone age does not trigger age_milestone tip', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 32,
          canton: 'VD',
          revenuAnnuel: 80000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      final milestones = tips.where((t) => t.id.startsWith('age_milestone_'));
      expect(milestones, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  BUDGET DRIFT TRIGGER
  // ════════════════════════════════════════════════════════════

  group('CoachingService - Budget Drift', () {
    test('exceptional expenses > 20% of income triggers budget_drift', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 30,
          canton: 'VD',
          revenuAnnuel: 60000, // 5000/month
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          hasBudget: true,
          employmentStatus: EmploymentStatus.salarie,
          lastCheckInDepensesExceptionnelles: 1500, // 30% of monthly income
        ),
      );

      final drift = tips.where((t) => t.id == 'budget_drift');
      expect(drift, isNotEmpty);
      expect(drift.first.category, 'budget');
      expect(drift.first.priority, CoachingPriority.moyenne);
    });

    test('exceptional expenses > 40% triggers haute priority', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 30,
          canton: 'VD',
          revenuAnnuel: 60000, // 5000/month
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          hasBudget: true,
          employmentStatus: EmploymentStatus.salarie,
          lastCheckInDepensesExceptionnelles: 2500, // 50% of monthly income
        ),
      );

      final drift = tips.where((t) => t.id == 'budget_drift');
      expect(drift, isNotEmpty);
      expect(drift.first.priority, CoachingPriority.haute);
    });

    test('exceptional expenses <= 20% does not trigger budget_drift', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 30,
          canton: 'VD',
          revenuAnnuel: 60000, // 5000/month
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          hasBudget: true,
          employmentStatus: EmploymentStatus.salarie,
          lastCheckInDepensesExceptionnelles: 800, // 16% of monthly income
        ),
      );

      final drift = tips.where((t) => t.id == 'budget_drift');
      expect(drift, isEmpty);
    });

    test('no check-in data does not trigger budget_drift', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 30,
          canton: 'VD',
          revenuAnnuel: 60000,
          has3a: true,
          montant3a: 7056,
          hasLpp: true,
          hasBudget: true,
          employmentStatus: EmploymentStatus.salarie,
          // lastCheckInDepensesExceptionnelles defaults to null
        ),
      );

      final drift = tips.where((t) => t.id == 'budget_drift');
      expect(drift, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SORTING & GENERAL
  // ════════════════════════════════════════════════════════════

  group('CoachingService - Sorting & General', () {
    test('tips are sorted by priority (haute first)', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 55,
          canton: 'VD',
          revenuAnnuel: 100000,
          has3a: false,
          hasLpp: true,
          avoirLpp: 200000,
          lacuneLpp: 80000,
          chargesFixesMensuelles: 4000,
          epargneDispo: 1000,
          hasBudget: false,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      expect(tips, isNotEmpty);

      // Verify sorted by priority: haute (0) < moyenne (1) < basse (2)
      for (int i = 0; i < tips.length - 1; i++) {
        expect(tips[i].priority.index, lessThanOrEqualTo(tips[i + 1].priority.index));
      }
    });

    test('all tips have required fields populated', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 35,
          canton: 'VD',
          revenuAnnuel: 80000,
          has3a: false,
          hasLpp: true,
          lacuneLpp: 50000,
          chargesFixesMensuelles: 3000,
          epargneDispo: 1000,
          hasBudget: false,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      for (final tip in tips) {
        expect(tip.id, isNotEmpty, reason: 'Every tip must have an id');
        expect(tip.category, isNotEmpty, reason: 'Every tip must have a category');
        expect(tip.title, isNotEmpty, reason: 'Every tip must have a title');
        expect(tip.message, isNotEmpty, reason: 'Every tip must have a message');
        expect(tip.action, isNotEmpty, reason: 'Every tip must have an action');
        expect(tip.source, isNotEmpty, reason: 'Every tip must have a legal source');
        expect(tip.icon, isA<IconData>(), reason: 'Every tip must have an icon');
      }
    });

    test('demo profile generates multiple tips', () {
      final profile = CoachingService.buildDemoProfile();
      final tips = CoachingService.generateTips(s: SFr(), profile: profile);

      // Demo profile: no 3a, lacune LPP 42k, savings ~2.2 months, no budget
      // Should generate at least: missing_3a, lpp_buyback, emergency_fund, budget_missing
      expect(tips.length, greaterThanOrEqualTo(3));
    });

    test('formatChf formats values with Swiss apostrophe', () {
      expect(CoachingService.formatChf(1234), 'CHF\u00A01\'234');
      expect(CoachingService.formatChf(0), 'CHF\u00A00');
      expect(CoachingService.formatChf(7056), 'CHF\u00A07\'056');
      expect(CoachingService.formatChf(1000000), 'CHF\u00A01\'000\'000');
    });

    test('unknown canton uses default marginal rate of 33%', () {
      final tips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 30,
          canton: 'XX',
          revenuAnnuel: 80000,
          has3a: false,
          has3aAnswered: true,
          hasLpp: true,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );

      // missing_3a tip should be generated with default rate
      final missing3a = tips.firstWhere((t) => t.id == 'missing_3a');
      // Impact = 7258 (plafond 3a 2025) * 0.33 (default taux) = 2395.14
      expect(missing3a.estimatedImpactChf, closeTo(7258 * 0.33, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  TIP ENRICHMENT (T2 — Tips Narratifs)
  // ════════════════════════════════════════════════════════════

  group('CoachingService - Tip Enrichment', () {
    const testProfile = CoachingProfile(
      age: 35,
      canton: 'VD',
      revenuAnnuel: 85000,
      has3a: false,
      montant3a: 0,
      hasLpp: true,
      avoirLpp: 95000,
      lacuneLpp: 42000,
      tauxActivite: 100,
      chargesFixesMensuelles: 3800,
      epargneDispo: 8500,
      detteTotale: 0,
      hasBudget: false,
      employmentStatus: EmploymentStatus.salarie,
      etatCivil: EtatCivil.celibataire,
    );

    test('enrichTips returns tips unchanged when no BYOK', () async {
      final tips = CoachingService.generateTips(s: SFr(), profile: testProfile);
      final result = await CoachingService.enrichTips(
        tips: tips,
        profile: testProfile,
        firstName: 'Julien',
        apiKey: null,
        provider: null,
      );
      expect(result.length, tips.length);
      for (final tip in result) {
        expect(tip.narrativeMessage, isNull);
      }
    });

    test('enrichTips returns tips unchanged when apiKey is empty', () async {
      final tips = CoachingService.generateTips(s: SFr(), profile: testProfile);
      final result = await CoachingService.enrichTips(
        tips: tips,
        profile: testProfile,
        firstName: 'Julien',
        apiKey: '',
        provider: 'openai',
      );
      for (final tip in result) {
        expect(tip.narrativeMessage, isNull);
      }
    });

    test('enrichTips handles empty tips list', () async {
      final result = await CoachingService.enrichTips(
        tips: [],
        profile: testProfile,
        firstName: 'Julien',
        apiKey: 'sk-test',
        provider: 'openai',
      );
      expect(result, isEmpty);
    });

    test('enrichTips gracefully handles LLM failure', () async {
      // When RAG backend is unreachable, tips should be returned unchanged
      final tips = [
        CoachingTip(
          id: 'test',
          category: 'test',
          priority: CoachingPriority.haute,
          title: 'Test',
          message: 'Original message',
          action: 'Test',
          source: 'Test',
          icon: Icons.info,
        ),
      ];
      final result = await CoachingService.enrichTips(
        tips: tips,
        profile: testProfile,
        firstName: 'Julien',
        apiKey: 'sk-fake-key',
        provider: 'openai',
      );
      // Should not crash, tips returned with original message
      expect(result.first.message, 'Original message');
    });

    test('narrativeMessage field defaults to null on CoachingTip', () {
      final tip = CoachingTip(
        id: 'test',
        category: 'test',
        priority: CoachingPriority.haute,
        title: 'Test',
        message: 'Original',
        action: 'Test',
        source: 'Test',
        icon: Icons.info,
      );
      expect(tip.narrativeMessage, isNull);
      expect(tip.message, 'Original');
    });

    test('narrativeMessage can be set after construction', () {
      final tip = CoachingTip(
        id: 'test',
        category: 'test',
        priority: CoachingPriority.haute,
        title: 'Test',
        message: 'Original',
        action: 'Test',
        source: 'Test',
        icon: Icons.info,
      );
      tip.narrativeMessage = 'Enriched narrative message for Julien';
      expect(tip.narrativeMessage, 'Enriched narrative message for Julien');
      expect(tip.message, 'Original'); // original unchanged
    });
  });

  // ════════════════════════════════════════════════════════════
  //  FILTER BY STRESS TYPE (P8 Phase 2)
  // ════════════════════════════════════════════════════════════

  group('CoachingService - filterByStressType', () {
    late List<CoachingTip> allTips;

    setUp(() {
      // Generate tips from a profile that triggers multiple categories
      allTips = CoachingService.generateTips(s: SFr(), 
        profile: const CoachingProfile(
          age: 50,
          canton: 'VD',
          revenuAnnuel: 100000,
          has3a: false,
          has3aAnswered: true,
          hasLpp: true,
          avoirLpp: 50000,
          employmentStatus: EmploymentStatus.salarie,
        ),
      );
    });

    test('stress_retraite filters to retraite + prevoyance', () {
      final filtered =
          CoachingService.filterByStressType(allTips, 'stress_retraite');
      for (final tip in filtered) {
        expect(['retraite', 'prevoyance'], contains(tip.category));
      }
    });

    test('stress_impots filters to fiscalite', () {
      final filtered =
          CoachingService.filterByStressType(allTips, 'stress_impots');
      for (final tip in filtered) {
        expect(tip.category, 'fiscalite');
      }
    });

    test('stress_budget filters to budget', () {
      final filtered =
          CoachingService.filterByStressType(allTips, 'stress_budget');
      for (final tip in filtered) {
        expect(tip.category, 'budget');
      }
    });

    test('stress_patrimoine filters to prevoyance + fiscalite + budget', () {
      final filtered =
          CoachingService.filterByStressType(allTips, 'stress_patrimoine');
      for (final tip in filtered) {
        expect(['prevoyance', 'fiscalite', 'budget'], contains(tip.category));
      }
    });

    test('stress_couple filters to retraite + prevoyance + fiscalite + budget', () {
      final filtered =
          CoachingService.filterByStressType(allTips, 'stress_couple');
      for (final tip in filtered) {
        expect(
            ['retraite', 'prevoyance', 'fiscalite', 'budget'], contains(tip.category));
      }
    });

    test('stress_general returns all categories', () {
      final filtered =
          CoachingService.filterByStressType(allTips, 'stress_general');
      expect(filtered.length, allTips.length);
    });

    test('unknown stress type falls back to all categories', () {
      final filtered =
          CoachingService.filterByStressType(allTips, 'stress_unknown');
      expect(filtered.length, allTips.length);
    });

    test('all 6 UI stress IDs are handled (no silent fallback)', () {
      const uiStressIds = [
        'stress_retraite',
        'stress_impots',
        'stress_budget',
        'stress_patrimoine',
        'stress_couple',
        'stress_general',
      ];
      for (final id in uiStressIds) {
        final filtered = CoachingService.filterByStressType(allTips, id);
        // Each should produce a subset, not necessarily == allTips
        // (except stress_general which is all)
        expect(filtered, isNotEmpty, reason: '$id should match some tips');
      }
    });

    test('filtered tips is subset of input', () {
      final filtered =
          CoachingService.filterByStressType(allTips, 'stress_retraite');
      expect(filtered.length, lessThanOrEqualTo(allTips.length));
      for (final tip in filtered) {
        expect(allTips, contains(tip));
      }
    });
  });
}
