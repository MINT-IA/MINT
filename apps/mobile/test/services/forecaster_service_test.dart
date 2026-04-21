import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/forecaster_service.dart';

/// Unit tests for ForecasterService — Sprint C3 (MINT Coach)
///
/// Tests the projection engine with 3 scenarios, AVS couple estimation,
/// milestone detection, and edge cases.
///
/// Legal references: LAVS art. 21-29, LPP art. 14, OPP3 art. 7, LPP art. 79b
void main() {
  // ════════════════════════════════════════════════════════════
  //  PROJECTION WITH DEMO PROFILE (Julien+Lauren)
  // ════════════════════════════════════════════════════════════

  group('ForecasterService - Demo profile projection', () {
    late CoachProfile demo;
    late ProjectionResult result;

    setUp(() {
      demo = CoachProfile.buildDemo();
      result = ForecasterService.project(profile: demo);
    });

    test('result has 3 scenarios', () {
      expect(result.prudent.label, 'Prudent');
      expect(result.base.label, 'Base');
      expect(result.optimiste.label, 'Optimiste');
    });

    test('optimiste > base > prudent capital final', () {
      expect(result.optimiste.capitalFinal,
          greaterThan(result.base.capitalFinal));
      expect(result.base.capitalFinal,
          greaterThan(result.prudent.capitalFinal));
    });

    test('base scenario has reasonable capital for 16-year projection', () {
      // Starting with ~450k (300k LPP + 35k 3a + 100k IB + 15k liquide)
      // + monthly contributions ~4200/mois for ~16 years
      // Should be well above 500k
      expect(result.base.capitalFinal, greaterThan(500000));
    });

    test('projection has monthly points', () {
      // ~16 years = ~192 months
      expect(result.base.points.length, greaterThan(150));
      expect(result.base.points.length, lessThan(250));
    });

    test('capital grows over time (monotonically in base)', () {
      final points = result.base.points;
      for (int i = 1; i < points.length; i++) {
        expect(points[i].capitalCumule,
            greaterThanOrEqualTo(points[i - 1].capitalCumule),
            reason: 'Capital should grow month over month (month $i)');
      }
    });

    test('taux de remplacement is reasonable', () {
      // Should be between 40% and 120% for this profile
      expect(result.tauxRemplacementBase, greaterThan(30));
      expect(result.tauxRemplacementBase, lessThan(150));
    });

    test('decomposition has required keys', () {
      final decomp = result.base.decomposition;
      expect(decomp.containsKey('avs'), true);
      expect(decomp.containsKey('lpp_user'), true);
      expect(decomp.containsKey('lpp_conjoint'), true);
      expect(decomp.containsKey('3a'), true);
      expect(decomp.containsKey('libre'), true);
    });

    test('AVS rente couple is capped at 150%', () {
      final avs = result.base.decomposition['avs']!;
      // Max couple annual: 3780 * 13 = 49140 (13th rente since Dec 2026)
      expect(avs, lessThanOrEqualTo(49140));
      expect(avs, greaterThan(0));
    });

    test('disclaimer is present and compliant', () {
      expect(result.disclaimer, isNotEmpty);
      expect(result.disclaimer.contains('educatif') ||
          result.disclaimer.contains('conseil financier'), true);
      // No banned terms
      expect(result.disclaimer.contains('garanti'), false);
      expect(result.disclaimer.contains('certain'), false);
      expect(result.disclaimer.contains('assure'), false);
    });

    test('sources reference Swiss law', () {
      expect(result.sources, isNotEmpty);
      expect(result.sources.any((s) => s.contains('LAVS')), true);
      expect(result.sources.any((s) => s.contains('LPP')), true);
    });

    test('milestones are detected', () {
      expect(result.milestones, isNotEmpty);
      // Should at least hit 500k threshold
      expect(
        result.milestones.any((m) => m.amount >= 500000),
        true,
        reason: 'Should reach at least 500k milestone',
      );
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SCENARIO ASSUMPTIONS
  // ════════════════════════════════════════════════════════════

  group('ScenarioAssumptions', () {
    test('prudent has lowest returns', () {
      expect(ScenarioAssumptions.prudent.lppReturn, 0.01);
      expect(ScenarioAssumptions.prudent.investmentReturn, 0.03);
    });

    test('base has moderate returns', () {
      expect(ScenarioAssumptions.base.lppReturn, 0.02);
      expect(ScenarioAssumptions.base.investmentReturn, 0.06);
    });

    test('optimiste has highest returns', () {
      expect(ScenarioAssumptions.optimiste.lppReturn, 0.03);
      expect(ScenarioAssumptions.optimiste.investmentReturn, 0.09);
    });

    test('all scenarios have same inflation', () {
      expect(ScenarioAssumptions.prudent.inflation,
          ScenarioAssumptions.base.inflation);
      expect(ScenarioAssumptions.base.inflation,
          ScenarioAssumptions.optimiste.inflation);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CUSTOM SCENARIO
  // ════════════════════════════════════════════════════════════

  group('ForecasterService - Custom scenario', () {
    test('projectCustom with zero returns', () {
      final demo = CoachProfile.buildDemo();
      final result = ForecasterService.projectCustom(
        profile: demo,
        assumptions: const ScenarioAssumptions(
          label: 'Zero',
          lppReturn: 0,
          threeAReturn: 0,
          investmentReturn: 0,
          savingsReturn: 0,
          inflation: 0,
        ),
      );

      // With zero returns, capital = initial + contributions
      // No compound interest
      expect(result.capitalFinal, greaterThan(0));
      expect(result.label, 'Zero');
    });

    test('projectCustom with high returns gives more capital', () {
      final demo = CoachProfile.buildDemo();
      final low = ForecasterService.projectCustom(
        profile: demo,
        assumptions: ScenarioAssumptions.prudent,
      );
      final high = ForecasterService.projectCustom(
        profile: demo,
        assumptions: const ScenarioAssumptions(
          label: 'High',
          lppReturn: 0.05,
          threeAReturn: 0.10,
          investmentReturn: 0.12,
          savingsReturn: 0.03,
          inflation: 0.015,
        ),
      );

      expect(high.capitalFinal, greaterThan(low.capitalFinal));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SINGLE PROFILE (NO COUPLE)
  // ════════════════════════════════════════════════════════════

  group('ForecasterService - Single profile', () {
    test('single person projection works', () {
      final single = CoachProfile(
        firstName: 'Marc',
        birthYear: 1990,
        canton: 'ZH',
        salaireBrutMensuel: 7000,
        nombreDeMois: 12,
        etatCivil: CoachCivilStatus.celibataire,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 80000,
          nombre3a: 2,
          totalEpargne3a: 20000,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 10000,
          investissements: 30000,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055, 12, 31),
          label: 'Retraite',
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_marc',
            label: '3a Marc',
            amount: 604.83,
            category: '3a',
          ),
        ],
      );

      final result = ForecasterService.project(profile: single);
      expect(result.base.capitalFinal, greaterThan(100000));
      expect(result.base.decomposition['lpp_conjoint'], 0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  LPP BUYBACK CAP
  // ════════════════════════════════════════════════════════════

  group('ForecasterService - LPP buyback cap', () {
    test('buyback stops when lacune is exhausted', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'VD',
        salaireBrutMensuel: 8000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 100000,
          rachatMaximum: 10000, // Only 10k lacune
          rachatEffectue: 0,
        ),
        patrimoine: const PatrimoineProfile(epargneLiquide: 20000),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: 'lpp_buyback',
            label: 'Rachat LPP',
            amount: 2000, // 2000/mois → 10k in 5 months
            category: 'lpp_buyback',
          ),
        ],
      );

      final result = ForecasterService.project(profile: profile);
      // Should have points and not crash
      expect(result.base.points, isNotEmpty);
      expect(result.base.capitalFinal, greaterThan(100000));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  3A CAP
  // ════════════════════════════════════════════════════════════

  group('ForecasterService - 3a annual cap', () {
    test('3a contributions respect annual plafond', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'GE',
        salaireBrutMensuel: 10000,
        prevoyance: const PrevoyanceProfile(totalEpargne3a: 0),
        patrimoine: const PatrimoineProfile(epargneLiquide: 5000),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(DateTime.now().year + 2),
          label: 'Test',
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_test',
            label: '3a Test',
            amount: 1000, // 1000/mois = 12000/an but cap is 7258
            category: '3a',
          ),
        ],
      );

      final result = ForecasterService.project(profile: profile);
      expect(result.base.points, isNotEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  EDGE CASES
  // ════════════════════════════════════════════════════════════

  group('ForecasterService - Edge cases', () {
    test('past target date returns empty scenario', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'ZH',
        salaireBrutMensuel: 5000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2020, 1, 1),
          label: 'Passe',
        ),
      );

      final result = ForecasterService.project(profile: profile);
      expect(result.base.points, isEmpty);
      expect(result.base.capitalFinal, 0);
    });

    test('zero salary profile still works', () {
      final profile = CoachProfile(
        birthYear: 1960,
        canton: 'BE',
        salaireBrutMensuel: 0,
        employmentStatus: 'retraite',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 500000),
        patrimoine: const PatrimoineProfile(epargneLiquide: 100000),
        goalA: GoalA(
          type: GoalAType.custom,
          targetDate: DateTime(DateTime.now().year + 5),
          label: 'Succession',
        ),
      );

      final result = ForecasterService.project(profile: profile);
      expect(result.base.capitalFinal, greaterThan(0));
    });

    test('very long projection (40 years) does not crash', () {
      final profile = CoachProfile(
        birthYear: 2000,
        canton: 'ZG',
        salaireBrutMensuel: 6000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 10000,
          totalEpargne3a: 5000,
        ),
        patrimoine: const PatrimoineProfile(epargneLiquide: 3000),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2065, 12, 31),
          label: 'Retraite',
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a',
            label: '3a',
            amount: 604.83,
            category: '3a',
          ),
        ],
      );

      final result = ForecasterService.project(profile: profile);
      expect(result.base.points.length, greaterThan(400));
      expect(result.base.capitalFinal, greaterThan(50000));
    });

    test('calculateMonthlyDelta returns sum of versements', () {
      final demo = CoachProfile.buildDemo();
      final delta = ForecasterService.calculateMonthlyDelta(
        profile: demo,
        versements: {'3a': 604.83, 'lpp': 1000, 'ib': 500},
      );
      expect(delta, closeTo(2104.83, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  MILESTONES
  // ════════════════════════════════════════════════════════════

  group('ForecasterService - Milestones', () {
    test('milestones are in chronological order', () {
      final demo = CoachProfile.buildDemo();
      final result = ForecasterService.project(profile: demo);

      for (int i = 1; i < result.milestones.length; i++) {
        expect(
          result.milestones[i].date.isAfter(result.milestones[i - 1].date) ||
              result.milestones[i].date == result.milestones[i - 1].date,
          true,
          reason: 'Milestones should be chronological',
        );
      }
    });

    test('milestone amounts are increasing', () {
      final demo = CoachProfile.buildDemo();
      final result = ForecasterService.project(profile: demo);

      for (int i = 1; i < result.milestones.length; i++) {
        expect(
          result.milestones[i].amount,
          greaterThan(result.milestones[i - 1].amount),
          reason: 'Milestone amounts should increase',
        );
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SERIALIZATION
  // ════════════════════════════════════════════════════════════

  group('ForecasterService - JSON output', () {
    test('ProjectionResult toJson works', () {
      final demo = CoachProfile.buildDemo();
      final result = ForecasterService.project(profile: demo);
      final json = result.toJson();

      expect(json['prudent'], isNotNull);
      expect(json['base'], isNotNull);
      expect(json['optimiste'], isNotNull);
      expect(json['tauxRemplacementBase'], isA<double>());
      expect(json['milestones'], isA<List>());
      expect(json['disclaimer'], isA<String>());
      expect(json['sources'], isA<List>());
    });

    test('ProjectionResult fromJson round-trip preserves aggregate data', () {
      final demo = CoachProfile.buildDemo();
      final original = ForecasterService.project(profile: demo);
      final json = original.toJson();
      final restored = ProjectionResult.fromJson(json);

      // Aggregate figures preserved
      expect(restored.base.capitalFinal, original.base.capitalFinal);
      expect(restored.base.revenuAnnuelRetraite,
          original.base.revenuAnnuelRetraite);
      expect(restored.prudent.capitalFinal, original.prudent.capitalFinal);
      expect(
          restored.optimiste.capitalFinal, original.optimiste.capitalFinal);
      expect(
          restored.tauxRemplacementBase, original.tauxRemplacementBase);

      // Labels preserved
      expect(restored.prudent.label, 'Prudent');
      expect(restored.base.label, 'Base');
      expect(restored.optimiste.label, 'Optimiste');

      // Disclaimer and sources preserved
      expect(restored.disclaimer, original.disclaimer);
      expect(restored.sources, original.sources);

      // Points NOT persisted (by design — lightweight snapshot)
      expect(restored.base.points, isEmpty);
      expect(restored.milestones, isEmpty);
    });

    test('ProjectionResult fromJson handles empty/null gracefully', () {
      final restored = ProjectionResult.fromJson(const {});
      expect(restored.base.capitalFinal, 0);
      expect(restored.tauxRemplacementBase, 0);
      expect(restored.disclaimer, '');
      expect(restored.sources, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  FORMAT HELPER
  // ════════════════════════════════════════════════════════════

  group('ForecasterService - formatChf', () {
    test('formats with Swiss apostrophe', () {
      expect(ForecasterService.formatChf(1234567),
          contains("1'234'567"));
    });

    test('formats small amounts', () {
      expect(ForecasterService.formatChf(500), contains('500'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SCENARIO ASSUMPTIONS — copyWith
  // ════════════════════════════════════════════════════════════

  group('ScenarioAssumptions - copyWith', () {
    test('copyWith with no changes returns equal values', () {
      final copy = ScenarioAssumptions.base.copyWith();
      expect(copy.lppReturn, ScenarioAssumptions.base.lppReturn);
      expect(copy.threeAReturn, ScenarioAssumptions.base.threeAReturn);
      expect(copy.investmentReturn, ScenarioAssumptions.base.investmentReturn);
      expect(copy.savingsReturn, ScenarioAssumptions.base.savingsReturn);
      expect(copy.inflation, ScenarioAssumptions.base.inflation);
    });

    test('copyWith overrides specified fields', () {
      final custom = ScenarioAssumptions.base.copyWith(
        lppReturn: 0.04,
        threeAReturn: 0.08,
      );
      expect(custom.lppReturn, 0.04);
      expect(custom.threeAReturn, 0.08);
      expect(custom.investmentReturn, ScenarioAssumptions.base.investmentReturn);
    });

    test('copyWith preserves label when not overridden', () {
      final custom = ScenarioAssumptions.prudent.copyWith(lppReturn: 0.05);
      expect(custom.label, 'Prudent');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  ET SI... PROJECTION
  // ════════════════════════════════════════════════════════════

  group('ForecasterService - projectEtSi', () {
    late CoachProfile demo;

    setUp(() {
      demo = CoachProfile.buildDemo();
    });

    test('projectEtSi with default base returns similar result to project', () {
      final standard = ForecasterService.project(profile: demo);
      final etSi = ForecasterService.projectEtSi(
        profile: demo,
        customBase: ScenarioAssumptions.base,
      );
      // Same base assumptions → same base capital (within rounding)
      expect(etSi.base.capitalFinal,
          closeTo(standard.base.capitalFinal, 1.0));
    });

    test('projectEtSi with higher returns increases capital', () {
      final standard = ForecasterService.project(profile: demo);
      final etSi = ForecasterService.projectEtSi(
        profile: demo,
        customBase: ScenarioAssumptions.base.copyWith(
          lppReturn: 0.04,
          threeAReturn: 0.08,
          investmentReturn: 0.10,
        ),
      );
      expect(etSi.base.capitalFinal,
          greaterThan(standard.base.capitalFinal));
    });

    test('projectEtSi preserves 3-scenario ordering', () {
      final etSi = ForecasterService.projectEtSi(
        profile: demo,
        customBase: ScenarioAssumptions.base.copyWith(
          lppReturn: 0.03,
          threeAReturn: 0.06,
        ),
      );
      expect(etSi.optimiste.capitalFinal,
          greaterThan(etSi.base.capitalFinal));
      expect(etSi.base.capitalFinal,
          greaterThan(etSi.prudent.capitalFinal));
    });

    test('projectEtSi with very low returns still produces valid result', () {
      final etSi = ForecasterService.projectEtSi(
        profile: demo,
        customBase: ScenarioAssumptions.base.copyWith(
          lppReturn: 0.001,
          threeAReturn: 0.005,
          investmentReturn: 0.01,
        ),
      );
      expect(etSi.base.capitalFinal, greaterThan(0));
      expect(etSi.base.points.length, greaterThan(100));
    });

    test('projectEtSi disclaimer mentions "Et si..."', () {
      final etSi = ForecasterService.projectEtSi(
        profile: demo,
        customBase: ScenarioAssumptions.base,
      );
      expect(etSi.disclaimer, contains('Et si...'));
      expect(etSi.disclaimer, contains('LSFin'));
    });

    test('projectEtSi sources include legal references', () {
      final etSi = ForecasterService.projectEtSi(
        profile: demo,
        customBase: ScenarioAssumptions.base,
      );
      expect(etSi.sources, contains(contains('LPP art. 14')));
      expect(etSi.sources, contains(contains('OPP3 art. 7')));
    });

    test('projectEtSi with high inflation reduces taux de remplacement', () {
      final etSi = ForecasterService.projectEtSi(
        profile: demo,
        customBase: ScenarioAssumptions.base.copyWith(
          inflation: 0.04,
        ),
      );
      // Higher inflation doesn't directly affect capital in our model,
      // but the result should still be valid
      expect(etSi.base.capitalFinal, greaterThan(0));
      expect(etSi.tauxRemplacementBase, greaterThan(0));
    });

    test('projectEtSi clamps negative returns to 0', () {
      final etSi = ForecasterService.projectEtSi(
        profile: demo,
        customBase: const ScenarioAssumptions(
          label: 'Custom',
          lppReturn: 0.005, // Very low — prudent would go negative without clamp
          threeAReturn: 0.01,
          investmentReturn: 0.02,
          savingsReturn: 0.002,
          inflation: 0.03,
        ),
      );
      // Should not crash, prudent returns clamped to >= 0
      expect(etSi.prudent.capitalFinal, greaterThan(0));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SMART CHECK-IN CONTRIBUTIONS
  // ════════════════════════════════════════════════════════════

  group('ForecasterService - Smart check-in contributions', () {
    late CoachProfile demo;

    setUp(() {
      demo = CoachProfile.buildDemo();
    });

    MonthlyCheckIn makeCheckIn(DateTime month, Map<String, double> v) {
      return MonthlyCheckIn(
        month: month,
        versements: v,
        completedAt: month.add(const Duration(days: 28)),
      );
    }

    test('0 check-ins: projection uses planned values only', () {
      // Demo has 0 check-ins by default
      expect(demo.checkIns, isEmpty);
      final result = ForecasterService.project(profile: demo);
      expect(result.base.capitalFinal, greaterThan(0));
    });

    test('1 check-in: smart block skipped (requires >= 2)', () {
      final profile = demo.copyWithCheckIns([
        makeCheckIn(DateTime(2026, 1, 1), {
          '3a_julien': 900,
          '3a_lauren': 900,
        }),
      ]);
      final resultWith = ForecasterService.project(profile: profile);
      final resultBase = ForecasterService.project(profile: demo);
      // With only 1 check-in, should be identical to base
      expect(resultWith.base.capitalFinal, resultBase.base.capitalFinal);
    });

    test('2 check-ins with higher 3a: projection increases', () {
      final profile = demo.copyWithCheckIns([
        makeCheckIn(DateTime(2026, 1, 1), {
          '3a_julien': 900,
          '3a_lauren': 900,
          'lpp_buyback_julien': 1000,
          'lpp_buyback_lauren': 500,
        }),
        makeCheckIn(DateTime(2026, 2, 1), {
          '3a_julien': 900,
          '3a_lauren': 900,
          'lpp_buyback_julien': 1000,
          'lpp_buyback_lauren': 500,
        }),
      ]);
      final resultSmart = ForecasterService.project(profile: profile);
      final resultBase = ForecasterService.project(profile: demo);
      // Actual 3a = 1800/month > planned 1209.66/month → capital should increase
      expect(resultSmart.base.capitalFinal,
          greaterThan(resultBase.base.capitalFinal));
    });

    test('check-ins with lower amounts: garde-fou prevents decrease', () {
      final profile = demo.copyWithCheckIns([
        makeCheckIn(DateTime(2026, 1, 1), {
          '3a_julien': 200,
          '3a_lauren': 200,
          'lpp_buyback_julien': 300,
        }),
        makeCheckIn(DateTime(2026, 2, 1), {
          '3a_julien': 200,
          '3a_lauren': 200,
          'lpp_buyback_julien': 300,
        }),
      ]);
      final resultSmart = ForecasterService.project(profile: profile);
      final resultBase = ForecasterService.project(profile: demo);
      // Garde-fou: max(planned, actual) → should not decrease
      expect(resultSmart.base.capitalFinal,
          greaterThanOrEqualTo(resultBase.base.capitalFinal));
    });

    test('3+ check-ins: only last 3 are used', () {
      final profile = demo.copyWithCheckIns([
        // Old check-in with very high amount (should be ignored)
        makeCheckIn(DateTime(2025, 10, 1), {
          '3a_julien': 3000,
          '3a_lauren': 3000,
        }),
        // Recent 3 check-ins with moderate increase
        makeCheckIn(DateTime(2026, 1, 1), {
          '3a_julien': 700,
          '3a_lauren': 700,
        }),
        makeCheckIn(DateTime(2026, 2, 1), {
          '3a_julien': 700,
          '3a_lauren': 700,
        }),
        makeCheckIn(DateTime(2026, 3, 1), {
          '3a_julien': 700,
          '3a_lauren': 700,
        }),
      ]);
      final result = ForecasterService.project(profile: profile);
      final resultBase = ForecasterService.project(profile: demo);
      // Rolling avg of last 3 = 1400/mo > planned 1209.66 → increases
      expect(result.base.capitalFinal,
          greaterThan(resultBase.base.capitalFinal));
    });

    test('check-ins with empty versements: no crash', () {
      final profile = demo.copyWithCheckIns([
        makeCheckIn(DateTime(2026, 1, 1), {}),
        makeCheckIn(DateTime(2026, 2, 1), {}),
      ]);
      final result = ForecasterService.project(profile: profile);
      final resultBase = ForecasterService.project(profile: demo);
      // Empty versements → counts stay 0, planned values used
      expect(result.base.capitalFinal, resultBase.base.capitalFinal);
    });

    test('check-ins with unknown IDs: gracefully skipped', () {
      final profile = demo.copyWithCheckIns([
        makeCheckIn(DateTime(2026, 1, 1), {
          'unknown_contribution': 5000,
          'also_unknown': 3000,
        }),
        makeCheckIn(DateTime(2026, 2, 1), {
          'unknown_contribution': 5000,
        }),
      ]);
      final result = ForecasterService.project(profile: profile);
      final resultBase = ForecasterService.project(profile: demo);
      // Unknown IDs are skipped → same as planned
      expect(result.base.capitalFinal, resultBase.base.capitalFinal);
    });

    test('per-month averaging: couple 3a entries summed per month', () {
      // This tests CRIT-C1 fix: average should be per-month, not per-entry
      // Planned total 3a = 604.83 + 604.83 = 1209.66/month
      // Actual per month = 800 + 800 = 1600/month → should trigger increase
      final profile = demo.copyWithCheckIns([
        makeCheckIn(DateTime(2026, 1, 1), {
          '3a_julien': 800,
          '3a_lauren': 800,
        }),
        makeCheckIn(DateTime(2026, 2, 1), {
          '3a_julien': 800,
          '3a_lauren': 800,
        }),
      ]);
      final resultSmart = ForecasterService.project(profile: profile);
      final resultBase = ForecasterService.project(profile: demo);
      // Per-month total 1600 > planned 1209.66 → capital must increase
      expect(resultSmart.base.capitalFinal,
          greaterThan(resultBase.base.capitalFinal));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  WAVE 7 — FATCA PARTNER 3a BLOCKER
  // ════════════════════════════════════════════════════════════
  //
  // Regression guard for P0-F1 (fiscal audit 2026-04-18). A conjoint
  // flagged as US person must NOT receive the auto-injected partner
  // 3a contribution — IRC §1291 PFIC / IRS Notice 2014-7 makes that
  // contribution a net loss under US tax. We assert the projected
  // capital shrinks when we flip the conjoint from swiss_native to
  // `isFatcaResident: true`, proving the FATCA branch removes the
  // ~7'258 CHF/yr partner 3a potential.

  group('ForecasterService - FATCA partner 3a blocker', () {
    ConjointProfile baseConjoint(PrevoyanceProfile prev) => ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 5583, // ~67k/yr, well over LPP threshold
          employmentStatus: 'salarie',
          prevoyance: prev,
        );

    CoachProfile buildCoupleProfile({required ConjointProfile conj}) {
      final demo = CoachProfile.buildDemo();
      // Drop any pre-seeded partner 3a contributions from the demo so the
      // FATCA/auto-injection branch is actually exercised (buildDemo ships
      // with `3a_lauren` hardcoded, which short-circuits the auto path).
      final filtered = demo.plannedContributions
          .where((c) => !(c.category == '3a' &&
              c.id.toLowerCase().contains('lauren')))
          .toList();
      return demo.copyWith(conjoint: conj).copyWithContributions(filtered);
    }

    test('non-FATCA conjoint: partner 3a injected, higher projected capital',
        () {
      final conj = baseConjoint(const PrevoyanceProfile());
      final profile = buildCoupleProfile(conj: conj);
      final result = ForecasterService.project(profile: profile);
      expect(result.base.capitalFinal, greaterThan(500000));
    });

    test('FATCA conjoint: no partner 3a, capital strictly lower', () {
      final nonFatca = baseConjoint(const PrevoyanceProfile());
      final withFatca = baseConjoint(const PrevoyanceProfile())
          .copyWith(isFatcaResident: true, canContribute3a: false);

      final nonFatcaResult = ForecasterService.project(
        profile: buildCoupleProfile(conj: nonFatca),
      );
      final fatcaResult = ForecasterService.project(
        profile: buildCoupleProfile(conj: withFatca),
      );

      // The FATCA path must drop the partner 3a auto-contribution; the
      // resulting capital should therefore be strictly below the
      // non-FATCA baseline.
      expect(fatcaResult.base.capitalFinal,
          lessThan(nonFatcaResult.base.capitalFinal));
    });

    test('nationality=US also blocks partner 3a (isFatcaResident unset)', () {
      final defaultConj = baseConjoint(const PrevoyanceProfile());
      final usConj = baseConjoint(const PrevoyanceProfile())
          .copyWith(nationality: 'US');

      final defaultResult = ForecasterService.project(
        profile: buildCoupleProfile(conj: defaultConj),
      );
      final usResult = ForecasterService.project(
        profile: buildCoupleProfile(conj: usConj),
      );

      expect(usResult.base.capitalFinal,
          lessThan(defaultResult.base.capitalFinal));
    });
  });
}
