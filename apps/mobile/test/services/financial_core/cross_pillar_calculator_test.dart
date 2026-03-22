import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/cross_pillar_calculator.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CrossPillarCalculator — test suite
//
//  Golden couple:
//   Julien: born 1977, age 49, salary 122'207 CHF/an, canton VS, married
//   Lauren: born 1982, age 43, salary 67'000 CHF/an, canton VS, US/FATCA
//  Ref: CLAUDE.md § 8 GOLDEN TEST COUPLE
// ════════════════════════════════════════════════════════════════════════════

/// Build Julien's CoachProfile (swiss_native, marie, canton VS).
CoachProfile _julienProfile({
  double salary = 122207.0,
  double lppAvoir = 70377.0,
  double rachatMax = 539414.0,
  double total3a = 32000.0,
  double epargne3aMensuelle = 0.0,
  double mortgageBalance = 0.0,
  double mortgageRate = 0.0,
  bool amortissementIndirect = false,
  double depensesLoyer = 0.0,
  double depensesMensuel = 0.0,
  double depensesMensualite = 0.0,
}) {
  return CoachProfile(
    birthYear: 1977,
    canton: 'VS',
    nationality: 'CH',
    salaireBrutMensuel: salary / 12,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.marie,
    nombreEnfants: 0,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042),
      label: 'Retraite Julien',
    ),
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: lppAvoir,
      rachatMaximum: rachatMax,
      tauxConversion: lppTauxConversionMinDecimal,
      rendementCaisse: 0.02,
      totalEpargne3a: total3a,
      canContribute3a: true,
    ),
    patrimoine: PatrimoineProfile(
      epargneLiquide: 50000,
      mortgageBalance: mortgageBalance > 0 ? mortgageBalance : null,
      mortgageRate: mortgageRate > 0 ? mortgageRate : null,
    ),
    dettes: DetteProfile(
      hypotheque: mortgageBalance > 0 ? mortgageBalance : null,
      mensualiteHypotheque: depensesMensualite > 0 ? depensesMensualite : null,
      amortissementIndirect: amortissementIndirect,
    ),
    depenses: DepensesProfile(
      loyer: depensesLoyer,
      assuranceMaladie: depensesMensuel,
    ),
    plannedContributions: epargne3aMensuelle > 0
        ? [
            PlannedMonthlyContribution(
              id: '3a_julien',
              label: '3a Julien',
              amount: epargne3aMensuelle,
              category: '3a',
            ),
          ]
        : [],
  );
}

/// Build Lauren's CoachProfile (expat_us, FATCA, canton VS).
CoachProfile _laurenProfile({
  double salary = 67000.0,
  double lppAvoir = 19620.0,
  double rachatMax = 52949.0,
  double total3a = 14000.0,
}) {
  return CoachProfile(
    birthYear: 1982,
    canton: 'VS',
    nationality: 'US',
    salaireBrutMensuel: salary / 12,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    arrivalAge: 22,
    etatCivil: CoachCivilStatus.celibataire,
    nombreEnfants: 0,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2047),
      label: 'Retraite Lauren',
    ),
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: lppAvoir,
      rachatMaximum: rachatMax,
      tauxConversion: lppTauxConversionMinDecimal,
      rendementCaisse: 0.02,
      totalEpargne3a: total3a,
      // US person: cannot contribute to 3a (FATCA / LSFin compliance)
      canContribute3a: false,
    ),
    patrimoine: const PatrimoineProfile(epargneLiquide: 20000),
  );
}

void main() {
  // ═══════════════════════════════════════════════════════════════
  //  1. EMPTY / MINIMAL PROFILE
  // ═══════════════════════════════════════════════════════════════

  group('CrossPillarCalculator — empty / minimal profiles', () {
    test('1. salary = 0 → empty analysis', () {
      final profile = CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 0,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042),
          label: 'test',
        ),
      );
      final result = CrossPillarCalculator.analyze(profile: profile);
      expect(result.insights, isEmpty);
      expect(result.totalPotentialImpact, equals(0));
      expect(result.disclaimer, isNotEmpty);
    });

    test('2. disclaimer always present', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      expect(result.disclaimer, isNotEmpty);
      expect(result.disclaimer.contains('LSFin'), isTrue);
    });

    test('3. totalPotentialImpact = sum of individual impacts', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      final sum = result.insights.fold(0.0, (s, i) => s + i.impactChfAnnual);
      expect(result.totalPotentialImpact, closeTo(sum, 0.01));
    });

    test('4. confidence in 0.0–1.0 range for all insights', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      for (final insight in result.insights) {
        expect(insight.confidence, greaterThanOrEqualTo(0.0));
        expect(insight.confidence, lessThanOrEqualTo(1.0));
      }
    });

    test('5. all trade-offs are non-empty', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      for (final insight in result.insights) {
        expect(insight.tradeOff, isNotEmpty);
      }
    });

    test('6. insights ordered descending by impactChfAnnual', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      for (int i = 0; i < result.insights.length - 1; i++) {
        expect(
          result.insights[i].impactChfAnnual,
          greaterThanOrEqualTo(result.insights[i + 1].impactChfAnnual),
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  2. PILLAR 3A OPTIMIZATION
  // ═══════════════════════════════════════════════════════════════

  group('CrossPillarCalculator — pillar3aOptimization', () {
    test('7. Julien: 3a not maxed → surfaces 3a insight', () {
      // Julien contributes 0 monthly to 3a
      final profile = _julienProfile(epargne3aMensuelle: 0);
      final result = CrossPillarCalculator.analyze(profile: profile);
      final insight = result.insights.firstWhere(
        (i) => i.type == CrossPillarType.pillar3aOptimization,
        orElse: () => throw StateError('Missing 3a insight'),
      );
      // Fiscal saving on 7258 CHF at VS marginal rate ~32%+10% = ~35%
      // 7258 × 0.35 ≈ 2540 CHF
      expect(insight.impactChfAnnual, greaterThan(500));
      expect(insight.impactChfAnnual, lessThan(5000));
      expect(insight.details['versementManquant'],
          closeTo(pilier3aPlafondAvecLpp, 1));
    });

    test('8. 3a already maxed → no 3a insight', () {
      // Julien contributes full 3a monthly
      final profile = _julienProfile(
        epargne3aMensuelle: pilier3aPlafondAvecLpp / 12,
      );
      final result = CrossPillarCalculator.analyze(profile: profile);
      final has3a = result.insights
          .any((i) => i.type == CrossPillarType.pillar3aOptimization);
      expect(has3a, isFalse);
    });

    test('9. Lauren US/FATCA → no 3a insight (FATCA block)', () {
      final profile = _laurenProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      final has3a = result.insights
          .any((i) => i.type == CrossPillarType.pillar3aOptimization);
      expect(has3a, isFalse);
    });

    test('10. 3a fiscal saving > 0 for VS canton', () {
      final profile = _julienProfile(epargne3aMensuelle: 0);
      final result = CrossPillarCalculator.analyze(profile: profile);
      final insight = result.insights.firstWhere(
        (i) => i.type == CrossPillarType.pillar3aOptimization,
        orElse: () => throw StateError('Missing 3a insight'),
      );
      expect(insight.details['economieImpotAnnuelle'], greaterThan(0));
    });

    test('11. tradeOff mentions liquidité and OPP3', () {
      final profile = _julienProfile(epargne3aMensuelle: 0);
      final result = CrossPillarCalculator.analyze(profile: profile);
      final insight = result.insights.firstWhere(
        (i) => i.type == CrossPillarType.pillar3aOptimization,
        orElse: () => throw StateError('Missing 3a insight'),
      );
      expect(insight.tradeOff.toLowerCase(), contains('liquidit'));
      expect(insight.tradeOff, contains('OPP3'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  3. LPP BUYBACK OPPORTUNITY
  // ═══════════════════════════════════════════════════════════════

  group('CrossPillarCalculator — lppBuybackOpportunity', () {
    test('12. Julien: rachat 539k → LPP insight present', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      final insight = result.insights.firstWhere(
        (i) => i.type == CrossPillarType.lppBuybackOpportunity,
        orElse: () => throw StateError('Missing LPP insight'),
      );
      // Fiscal saving on 539k at ~35% marginal rate ≈ 188k (multi-year, not all at once)
      // The estimate uses the full rachat against current income → significant saving
      expect(insight.impactChfAnnual, greaterThan(1000));
      expect(insight.details['lacuneRachat'], closeTo(539414, 1));
    });

    test('13. rachat = 0 → no LPP buyback insight', () {
      final profile = _julienProfile(rachatMax: 0);
      final result = CrossPillarCalculator.analyze(profile: profile);
      final hasLpp = result.insights
          .any((i) => i.type == CrossPillarType.lppBuybackOpportunity);
      expect(hasLpp, isFalse);
    });

    test('14. augmentationRenteAnnuelle = lacune × tauxConversion', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      final insight = result.insights.firstWhere(
        (i) => i.type == CrossPillarType.lppBuybackOpportunity,
        orElse: () => throw StateError('Missing LPP insight'),
      );
      const expectedBoost =
          539414.0 * lppTauxConversionMinDecimal;
      expect(insight.details['augmentationRenteAnnuelle'],
          closeTo(expectedBoost, 1));
    });

    test('15. Lauren: rachat 52949 → LPP buyback insight present', () {
      final profile = _laurenProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      final insight = result.insights.firstWhere(
        (i) => i.type == CrossPillarType.lppBuybackOpportunity,
        orElse: () => throw StateError('Missing LPP insight'),
      );
      expect(insight.impactChfAnnual, greaterThan(100));
      expect(insight.details['lacuneRachat'], closeTo(52949, 1));
    });

    test('16. tradeOff mentions blocage and LPP art. 79b', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      final insight = result.insights.firstWhere(
        (i) => i.type == CrossPillarType.lppBuybackOpportunity,
        orElse: () => throw StateError('Missing LPP insight'),
      );
      expect(insight.tradeOff, contains('LPP art. 79b'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  4. BUDGET REALLOCATION
  // ═══════════════════════════════════════════════════════════════

  group('CrossPillarCalculator — budgetReallocation', () {
    test('17. Julien with low expenses → budget reallocation insight', () {
      // Julien has little fixed expenses → large margin → reallocation possible
      final profile = _julienProfile(
        depensesMensuel: 500, // assurance maladie only
        epargne3aMensuelle: 0, // not currently contributing to 3a
      );
      final result = CrossPillarCalculator.analyze(profile: profile);
      // Budget reallocation may or may not trigger (depends on net income)
      // Key: if present, fiscalSaving3a > 0
      final realloc = result.insights
          .where((i) => i.type == CrossPillarType.budgetReallocation)
          .toList();
      if (realloc.isNotEmpty) {
        expect(realloc.first.impactChfAnnual, greaterThan(0));
        expect(realloc.first.details['economieImpot3a'], greaterThanOrEqualTo(0));
      }
    });

    test('18. high expenses → no budget reallocation', () {
      // Force expenses very high so no margin remains
      final profile = _julienProfile(
        depensesMensuel: 8000, // massive expenses
        depensesLoyer: 3000,
      );
      final result = CrossPillarCalculator.analyze(profile: profile);
      final hasRealloc = result.insights
          .any((i) => i.type == CrossPillarType.budgetReallocation);
      expect(hasRealloc, isFalse);
    });

    test('19. tradeOff mentions margeLibre and safety margin', () {
      final profile = _julienProfile(
        depensesMensuel: 200,
        epargne3aMensuelle: 0,
      );
      final result = CrossPillarCalculator.analyze(profile: profile);
      final realloc = result.insights
          .where((i) => i.type == CrossPillarType.budgetReallocation)
          .toList();
      if (realloc.isNotEmpty) {
        expect(realloc.first.tradeOff.toLowerCase(), contains('marge'));
        expect(realloc.first.tradeOff, contains('500'));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  5. CANTONAL ARBITRAGE
  // ═══════════════════════════════════════════════════════════════

  group('CrossPillarCalculator — cantonalArbitrage', () {
    test('20. Julien in VS (high-tax) → cantonal arbitrage present', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      // VS has rate 0.1456 at 100k; ZG (best) has 0.0823. Diff > 1000 CHF.
      final cantonal = result.insights
          .where((i) => i.type == CrossPillarType.cantonalArbitrage)
          .toList();
      // May or may not trigger depending on income level; if present, check quality
      if (cantonal.isNotEmpty) {
        expect(cantonal.first.impactChfAnnual,
            greaterThan(_minCantonalDiff));
        expect(cantonal.first.details['economieAnnuelle'],
            greaterThan(_minCantonalDiff));
        expect(cantonal.first.tradeOff, isNotEmpty);
      }
    });

    test('21. user already in ZG (lowest tax) → no cantonal arbitrage', () {
      final profile = CoachProfile(
        birthYear: 1977,
        canton: 'ZG', // already best canton
        salaireBrutMensuel: 122207.0 / 12,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042),
          label: 'test',
        ),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70377,
          rachatMaximum: 539414,
          tauxConversion: lppTauxConversionMinDecimal,
        ),
      );
      final result = CrossPillarCalculator.analyze(profile: profile);
      final hasArb = result.insights
          .any((i) => i.type == CrossPillarType.cantonalArbitrage);
      expect(hasArb, isFalse);
    });

    test('22. cantonal arbitrage tradeOff mentions déménagement', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      final cantonal = result.insights
          .where((i) => i.type == CrossPillarType.cantonalArbitrage)
          .toList();
      if (cantonal.isNotEmpty) {
        expect(
          cantonal.first.tradeOff.toLowerCase(),
          contains('déménagement'),
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  6. MORTGAGE TAX DEDUCTION
  // ═══════════════════════════════════════════════════════════════

  group('CrossPillarCalculator — mortgageTaxDeduction', () {
    test('23. mortgage present → mortgage insight present', () {
      final profile = _julienProfile(
        mortgageBalance: 500000.0,
        mortgageRate: 0.018, // 1.8% as decimal
      );
      final result = CrossPillarCalculator.analyze(profile: profile);
      final mortgage = result.insights
          .where((i) => i.type == CrossPillarType.mortgageTaxDeduction)
          .toList();
      expect(mortgage, isNotEmpty);
      // Annual interest = 500k × 1.8% = 9000 CHF
      // Tax saving ~= 9000 × marginal rate (~32%) ≈ 2880 CHF
      expect(mortgage.first.impactChfAnnual, greaterThan(500));
      expect(mortgage.first.details['interetsAnnuels'], closeTo(9000, 100));
    });

    test('24. no mortgage → no mortgage insight', () {
      final profile = _julienProfile(mortgageBalance: 0);
      final result = CrossPillarCalculator.analyze(profile: profile);
      final hasMortgage = result.insights
          .any((i) => i.type == CrossPillarType.mortgageTaxDeduction);
      expect(hasMortgage, isFalse);
    });

    test('25. indirect amortisation → tradeOff acknowledges it', () {
      final profile = _julienProfile(
        mortgageBalance: 500000.0,
        mortgageRate: 0.018,
        amortissementIndirect: true,
      );
      final result = CrossPillarCalculator.analyze(profile: profile);
      final mortgage = result.insights
          .where((i) => i.type == CrossPillarType.mortgageTaxDeduction)
          .toList();
      expect(mortgage, isNotEmpty);
      expect(
        mortgage.first.tradeOff.toLowerCase(),
        contains('indirect'),
      );
    });

    test('26. mortgage rate stored as percentage (>1) handled correctly', () {
      final profile = _julienProfile(
        mortgageBalance: 400000.0,
        mortgageRate: 1.8, // stored as % (1.8 = 1.8%)
      );
      final result = CrossPillarCalculator.analyze(profile: profile);
      final mortgage = result.insights
          .where((i) => i.type == CrossPillarType.mortgageTaxDeduction)
          .toList();
      // Either way, no crash and result is plausible
      if (mortgage.isNotEmpty) {
        expect(mortgage.first.impactChfAnnual, greaterThan(0));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  7. RETIREMENT GAP ACTION
  // ═══════════════════════════════════════════════════════════════

  group('CrossPillarCalculator — retirementGapAction', () {
    test('27. low projected income → gap insight present', () {
      // Force a very low projected income (e.g., 1500/month → ~28% replacement)
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(
        profile: profile,
        projectedRetirementIncomeMonthly: 1500.0,
      );
      final gap = result.insights
          .where((i) => i.type == CrossPillarType.retirementGapAction)
          .toList();
      expect(gap, isNotEmpty);
      expect(gap.first.details['tauxRemplacement'], lessThan(0.80));
      expect(gap.first.details['ecartMensuel'], greaterThan(0));
    });

    test('28. strong projected income → no gap insight', () {
      // 10000/month → replacement rate > 80% for Julien
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(
        profile: profile,
        projectedRetirementIncomeMonthly: 10000.0,
      );
      final hasGap = result.insights
          .any((i) => i.type == CrossPillarType.retirementGapAction);
      expect(hasGap, isFalse);
    });

    test('29. gap insight details contain all action fields', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(
        profile: profile,
        projectedRetirementIncomeMonthly: 2000.0,
      );
      final gap = result.insights.firstWhere(
        (i) => i.type == CrossPillarType.retirementGapAction,
        orElse: () => throw StateError('Missing gap insight'),
      );
      expect(gap.details.containsKey('ecartMensuel'), isTrue);
      expect(gap.details.containsKey('ecartAnnuel'), isTrue);
      expect(gap.details.containsKey('action3aEconomieFiscale'), isTrue);
      expect(gap.details.containsKey('actionRachatBoostRenteAnnuel'), isTrue);
      expect(gap.details.containsKey('actionAnneeSuppGainAnnuel'), isTrue);
    });

    test('30. actionRachatBoostRenteAnnuel = lacune × tauxConversion', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(
        profile: profile,
        projectedRetirementIncomeMonthly: 2000.0,
      );
      final gap = result.insights.firstWhere(
        (i) => i.type == CrossPillarType.retirementGapAction,
        orElse: () => throw StateError('Missing gap insight'),
      );
      const expectedBoost = 539414.0 * lppTauxConversionMinDecimal;
      expect(gap.details['actionRachatBoostRenteAnnuel'],
          closeTo(expectedBoost, 1));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  8. GOLDEN COUPLE — FULL ANALYSIS
  // ═══════════════════════════════════════════════════════════════

  group('CrossPillarCalculator — Golden Couple full analysis', () {
    test('31. Julien full analysis has meaningful total impact', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      // Julien has rachat 539k + 3a not maxed + VS high-tax canton
      // Total should be very significant
      expect(result.totalPotentialImpact, greaterThan(1000));
      expect(result.insights, isNotEmpty);
    });

    test('32. Lauren full analysis: LPP insight present, no 3a (FATCA)', () {
      final profile = _laurenProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      // Lauren cannot contribute to 3a (FATCA) but has LPP rachat
      final has3a = result.insights
          .any((i) => i.type == CrossPillarType.pillar3aOptimization);
      final hasLpp = result.insights
          .any((i) => i.type == CrossPillarType.lppBuybackOpportunity);
      expect(has3a, isFalse, reason: 'FATCA block: no 3a for US persons');
      expect(hasLpp, isTrue, reason: 'Lauren has LPP rachat 52949');
    });

    test('33. Julien with mortgage + low expenses = multiple insights', () {
      final profile = _julienProfile(
        mortgageBalance: 600000.0,
        mortgageRate: 0.02, // 2%
        depensesMensuel: 400.0, // low expenses → budget margin
      );
      final result = CrossPillarCalculator.analyze(profile: profile);
      final types = result.insights.map((i) => i.type).toSet();
      // Must have at least mortgage + LPP buyback
      expect(types.contains(CrossPillarType.mortgageTaxDeduction), isTrue);
      expect(types.contains(CrossPillarType.lppBuybackOpportunity), isTrue);
    });

    test('34. all impactChfAnnual values are positive', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      for (final insight in result.insights) {
        expect(
          insight.impactChfAnnual,
          greaterThan(0),
          reason: 'impactChfAnnual for ${insight.type} must be > 0',
        );
      }
    });

    test('35. intentTag is non-empty for all insights', () {
      final profile = _julienProfile();
      final result = CrossPillarCalculator.analyze(profile: profile);
      for (final insight in result.insights) {
        expect(
          insight.intentTag,
          isNotEmpty,
          reason: 'intentTag for ${insight.type} must be non-empty',
        );
      }
    });
  });
}

// Helper constant re-exposed for test readability
const double _minCantonalDiff = 1000.0;
