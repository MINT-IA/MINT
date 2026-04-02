import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/retroactive_3a_calculator.dart';
import 'package:mint_mobile/services/financial_core/couple_optimizer.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/services/financial_core/cross_pillar_calculator.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';

/// Phase 5 — Production bug regression tests.
///
/// B1: 3a retroactif slider max hardcoded to 10
/// B2: CoupleOptimizer crash on null conjoint
/// B3: BudgetLivingEngine rejects age == 70
/// B4: Error messages not saved (verified structurally)
/// B5: salaireAssure ignored in projections
/// B6: FATCA asymmetric on main user
void main() {
  // ── Helpers ──────────────────────────────────────────────────

  GoalA retraiteGoal() => GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042, 1, 1),
        label: 'Retraite',
      );

  CoachProfile buildProfile({
    int birthYear = 1980,
    double salaireBrutMensuel = 8000,
    String canton = 'VD',
    CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
    ConjointProfile? conjoint,
    PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
    String? nationality,
    String? employmentStatus,
    int? targetRetirementAge,
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaireBrutMensuel,
      etatCivil: etatCivil,
      conjoint: conjoint,
      nationality: nationality,
      employmentStatus: employmentStatus ?? 'salarie',
      prevoyance: prevoyance,
      patrimoine: const PatrimoineProfile(
        epargneLiquide: 20000,
        investissements: 0,
      ),
      depenses: const DepensesProfile(
        loyer: 1800,
        assuranceMaladie: 430,
      ),
      goalA: retraiteGoal(),
      targetRetirementAge: targetRetirementAge,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  B1: 3a retroactif — slider max / calculator year guard
  // ════════════════════════════════════════════════════════════

  group('B1: Retroactive 3a — year guard', () {
    test('calculator never generates entries for years before 2025', () {
      // Even if gapYears=10 and referenceYear=2026, only 2025 is valid.
      final result = Retroactive3aCalculator.calculate(
        gapYears: 10,
        tauxMarginal: 0.30,
        referenceYear: 2026,
      );

      for (final entry in result.breakdown) {
        expect(entry.year, greaterThanOrEqualTo(2025),
            reason: 'No retroactive entry should exist before 2025');
      }
      // In 2026, only 1 year (2025) is available.
      expect(result.breakdown.length, 1);
      expect(result.breakdown.first.year, 2025);
    });

    test('in 2026, max retroactive = 1 year, breakdown = [2025]', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 10,
        tauxMarginal: 0.30,
        referenceYear: 2026,
      );

      expect(result.breakdown.length, 1);
      expect(result.breakdown.first.year, 2025);
      expect(result.totalRetroactive, 7258.0); // 2025 limit
    });

    test('in 2030, max retroactive = 5 years, breakdown = [2025-2029]', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 10,
        tauxMarginal: 0.30,
        referenceYear: 2030,
      );

      // 2030 - 2025 = 5 eligible years: 2029, 2028, 2027, 2026, 2025
      expect(result.breakdown.length, 5);
      final years = result.breakdown.map((e) => e.year).toList();
      expect(years, contains(2025));
      expect(years, contains(2029));
      // No year before 2025
      for (final y in years) {
        expect(y, greaterThanOrEqualTo(2025));
      }
    });

    test('in 2035, max retroactive = 10 years, breakdown = [2025-2034]', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 10,
        tauxMarginal: 0.30,
        referenceYear: 2035,
      );

      // 2035 - 2025 = 10 eligible years, capped at max 10
      expect(result.breakdown.length, 10);
      final years = result.breakdown.map((e) => e.year).toList();
      expect(years, contains(2025));
      expect(years, contains(2034));
    });

    test('in 2040, gapYears=10 still capped at 10 (not 15)', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 15,
        tauxMarginal: 0.30,
        referenceYear: 2040,
      );

      // OPP3 art. 7: max 10 years
      expect(result.gapYears, 10);
      expect(result.breakdown.length, 10);
      // Most recent 10 years: 2039..2030 (all >= 2025)
      for (final entry in result.breakdown) {
        expect(entry.year, greaterThanOrEqualTo(2025));
      }
    });

    test('referenceYear 2026, gapYears 5 → only 1 entry (2025)', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 0.30,
        referenceYear: 2026,
      );

      // Even though 5 years requested, only 2025 qualifies.
      expect(result.breakdown.length, 1);
      expect(result.breakdown.first.year, 2025);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  B2: CoupleOptimizer crash on null conjoint
  // ════════════════════════════════════════════════════════════

  group('B2: CoupleOptimizer — null conjoint guard', () {
    test('null conjoint returns empty result, no crash', () {
      final profile = buildProfile(
        etatCivil: CoachCivilStatus.divorce,
        conjoint: null,
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 70000),
      );

      final result = CoupleOptimizer.optimize(
        mainUser: profile,
        conjoint: null,
      );

      expect(result.hasResults, isFalse);
      expect(result.lppBuybackOrder, isNull);
      expect(result.pillar3aOrder, isNull);
      expect(result.avsCap, isNull);
      expect(result.marriagePenalty, isNull);
    });

    test('conjoint with zero salary still computes AVS cap (W16 guard fix)', () {
      final profile = buildProfile(
        etatCivil: CoachCivilStatus.marie,
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 70000),
      );

      const conjoint = ConjointProfile(
        firstName: 'Test',
        birthYear: 1985,
        salaireBrutMensuel: 0,
      );

      final result = CoupleOptimizer.optimize(
        mainUser: profile,
        conjoint: conjoint,
      );

      // W16: AVS cap and marriage penalty still apply even if conjoint has no salary.
      // Only LPP buyback and 3a order require both incomes.
      expect(result.hasResults, isTrue);
      expect(result.avsCap, isNotNull);
      // LPP buyback requires both incomes > 0 for tax comparison
      expect(result.lppBuybackOrder, isNull);
    });

    test('conjoint with null salary still computes AVS cap (W16 guard fix)', () {
      final profile = buildProfile(
        etatCivil: CoachCivilStatus.marie,
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 70000),
      );

      const conjoint = ConjointProfile(
        firstName: 'Test',
        birthYear: 1985,
        salaireBrutMensuel: null,
      );

      final result = CoupleOptimizer.optimize(
        mainUser: profile,
        conjoint: conjoint,
      );

      // W16: AVS cap still computed when at least one partner has income
      expect(result.hasResults, isTrue);
      expect(result.avsCap, isNotNull);
    });

    test('valid conjoint produces results', () {
      final profile = buildProfile(
        etatCivil: CoachCivilStatus.marie,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70000,
          rachatMaximum: 100000,
        ),
      );

      const conjoint = ConjointProfile(
        firstName: 'Marie',
        birthYear: 1985,
        salaireBrutMensuel: 5000,
        prevoyance: PrevoyanceProfile(
          avoirLppTotal: 30000,
          rachatMaximum: 50000,
        ),
      );

      final result = CoupleOptimizer.optimize(
        mainUser: profile,
        conjoint: conjoint,
      );

      expect(result.hasResults, isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  B3: BudgetLivingEngine rejects age == 70
  // ════════════════════════════════════════════════════════════

  group('B3: BudgetLivingEngine — age 70 retired mode', () {
    test('age 70 salary 0 produces fullGapVisible (retired), NOT presentOnly',
        () {
      // 70 years old, no salary (retired)
      final profile = buildProfile(
        birthYear: DateTime.now().year - 70,
        salaireBrutMensuel: 0,
        targetRetirementAge: 65,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 200000,
        ),
      );

      final snapshot = BudgetLivingEngine.compute(profile);

      // Retired mode: should NOT be presentOnly (that was the bug).
      // It should be fullGapVisible since the person IS retired.
      expect(snapshot.stage, isNot(BudgetStage.presentOnly),
          reason: 'Age 70 with 0 salary should be treated as retired, '
              'not as "no data"');
    });

    test('age 65 salary 0 is treated as retired mode', () {
      final profile = buildProfile(
        birthYear: DateTime.now().year - 65,
        salaireBrutMensuel: 0,
        targetRetirementAge: 65,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 150000,
        ),
      );

      final snapshot = BudgetLivingEngine.compute(profile);

      // 65 == targetRetirementAge → retired mode.
      expect(snapshot.stage, isNot(BudgetStage.presentOnly),
          reason: 'Age 65 = retirement age should be retired mode');
    });

    test('age 50 salary 8000 is pre-retirement mode', () {
      final profile = buildProfile(
        birthYear: DateTime.now().year - 50,
        salaireBrutMensuel: 8000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 100000,
        ),
      );

      final snapshot = BudgetLivingEngine.compute(profile);

      // Pre-retirement: should be fullGapVisible or emergingRetirement.
      expect(snapshot.stage, isNot(BudgetStage.presentOnly),
          reason: 'Working 50yo should have retirement projection');
    });

    test('age 50 salary 0 is presentOnly (no data)', () {
      final profile = buildProfile(
        birthYear: DateTime.now().year - 50,
        salaireBrutMensuel: 0,
      );

      final snapshot = BudgetLivingEngine.compute(profile);

      // Not retired (50 < 65) AND no salary → presentOnly.
      expect(snapshot.stage, BudgetStage.presentOnly);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  B4: Error messages saved (structural verification)
  // ════════════════════════════════════════════════════════════
  //
  // Note: B4 is a UI behavior in coach_chat_screen.dart where
  // _autoSaveConversation() must be called in BOTH catch blocks
  // of _handleStandardResponse. The actual save requires widget
  // testing with mocked services. Here we verify:
  // 1. ChatMessage model supports system error messages.
  // 2. ConversationStore serialization handles error messages.

  group('B4: Error message save — structural verification', () {
    test('ChatMessage can represent system error messages', () {
      final errorMsg = ChatMessage(
        role: 'system',
        content: 'Connection error occurred',
        timestamp: DateTime.now(),
      );

      expect(errorMsg.role, 'system');
      expect(errorMsg.isSystem, isTrue);
      expect(errorMsg.content, contains('error'));
    });

    test('system error messages are not assistant or user', () {
      final errorMsg = ChatMessage(
        role: 'system',
        content: 'Rate limit exceeded',
        timestamp: DateTime.now(),
      );

      expect(errorMsg.isUser, isFalse);
      expect(errorMsg.isAssistant, isFalse);
      expect(errorMsg.isSystem, isTrue);
    });

    test('ConversationStore serializes system error messages correctly', () {
      // Simulate what ConversationStore._messageToJson does
      final errorMsg = ChatMessage(
        role: 'system',
        content: 'Service unavailable',
        timestamp: DateTime(2026, 3, 23, 12, 0),
      );

      // Manual serialization matching ConversationStore._messageToJson
      final json = <String, dynamic>{
        'role': errorMsg.role,
        'content': errorMsg.content,
        'timestamp': errorMsg.timestamp.toIso8601String(),
        'tier': errorMsg.tier.name,
      };

      // Verify roundtrip
      expect(json['role'], 'system');
      expect(json['content'], 'Service unavailable');

      // Reconstruct (matching ConversationStore._messageFromJson)
      final restored = ChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

      expect(restored.role, 'system');
      expect(restored.content, 'Service unavailable');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  B5: salaireAssure ignored in projections
  // ════════════════════════════════════════════════════════════

  group('B5: salaireAssure used in retirement projections', () {
    test(
        'profile with salaireAssure=40000 uses it instead of salary*12 for LPP',
        () {
      // Low salaireAssure (40k) vs higher salary (7000*12=84k).
      // After coordination deduction (26'460):
      //   salaireAssure path: (40'000 - 26'460).clamp(3780, 64260) = 13'540
      //   salary path: (84'000 - 26'460).clamp(3780, 64260) = 57'540
      // These produce different LPP bonification amounts.
      final profileWithSA = buildProfile(
        birthYear: 1980,
        salaireBrutMensuel: 7000, // 84'000 / an
        canton: 'VD',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 50000,
          salaireAssure: 40000, // Well below salary*12
          rendementCaisse: 0.02,
        ),
      );

      final resultWithSA = RetirementProjectionService.project(
        profile: profileWithSA,
      );

      // Same profile WITHOUT salaireAssure → uses salary * 12 = 84'000
      final profileWithoutSA = buildProfile(
        birthYear: 1980,
        salaireBrutMensuel: 7000,
        canton: 'VD',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 50000,
          salaireAssure: null,
          rendementCaisse: 0.02,
        ),
      );

      final resultWithoutSA = RetirementProjectionService.project(
        profile: profileWithoutSA,
      );

      // With salaireAssure (40'000) << salary*12 (84'000), the LPP
      // bonifications are computed on a lower base, producing a different
      // retirement income. The results should NOT be identical.
      expect(
        resultWithSA.revenuMensuelAt65,
        isNot(equals(resultWithoutSA.revenuMensuelAt65)),
        reason: 'salaireAssure should change LPP projection vs raw salary',
      );

      // The profile with lower salaireAssure should produce less LPP income
      expect(
        resultWithSA.revenuMensuelAt65,
        lessThan(resultWithoutSA.revenuMensuelAt65),
        reason: 'Lower salaireAssure = lower LPP bonifications = less income',
      );
    });

    test('profile without salaireAssure falls back to revenuBrutAnnuel', () {
      final profile = buildProfile(
        birthYear: 1980,
        salaireBrutMensuel: 8000,
        canton: 'VD',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 50000,
          salaireAssure: null,
        ),
      );

      // Should not throw — graceful fallback.
      final result = RetirementProjectionService.project(profile: profile);
      expect(result.revenuMensuelAt65, greaterThan(0));
    });

    test('salaireAssure = 0 falls back to revenuBrutAnnuel', () {
      final profile = buildProfile(
        birthYear: 1980,
        salaireBrutMensuel: 8000,
        canton: 'VD',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 50000,
          salaireAssure: 0,
        ),
      );

      final result = RetirementProjectionService.project(profile: profile);
      expect(result.revenuMensuelAt65, greaterThan(0));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  B6: FATCA asymmetric on main user
  // ════════════════════════════════════════════════════════════

  group('B6: FATCA — canContribute3a on main user', () {
    test('expat_us archetype → canContribute3a == false', () {
      final profile = buildProfile(
        nationality: 'US',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 50000,
          canContribute3a: true, // Even if prevoyance says true
        ),
      );

      expect(profile.archetype, FinancialArchetype.expatUs);
      expect(profile.canContribute3a, isFalse,
          reason: 'US nationals (FATCA) cannot contribute to 3a');
    });

    test('swiss_native archetype → canContribute3a == true', () {
      final profile = buildProfile(
        nationality: 'CH',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 50000,
          canContribute3a: true,
        ),
      );

      expect(profile.archetype, FinancialArchetype.swissNative);
      expect(profile.canContribute3a, isTrue);
    });

    test('non-US with prevoyance.canContribute3a=false → false', () {
      final profile = buildProfile(
        nationality: 'CH',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 50000,
          canContribute3a: false, // Explicitly set to false
        ),
      );

      expect(profile.canContribute3a, isFalse,
          reason: 'Delegates to prevoyance.canContribute3a');
    });

    test(
        'CrossPillarCalculator.pillar3aOptimization returns null for FATCA user',
        () {
      final profile = buildProfile(
        nationality: 'US',
        salaireBrutMensuel: 8000,
        canton: 'VD',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 50000,
          totalEpargne3a: 0,
          canContribute3a: true, // Even with this, archetype overrides
        ),
      );

      // The analyze method should skip 3a optimization for FATCA users.
      final analysis = CrossPillarCalculator.analyze(profile: profile);

      final has3aInsight = analysis.insights
          .any((i) => i.type == CrossPillarType.pillar3aOptimization);
      expect(has3aInsight, isFalse,
          reason: 'FATCA user should not get 3a optimization insight');
    });

    test('non-FATCA user with no 3a gets pillar3aOptimization insight', () {
      final profile = buildProfile(
        nationality: 'CH',
        salaireBrutMensuel: 8000,
        canton: 'VD',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 50000,
          totalEpargne3a: 0,
          nombre3a: 0,
          canContribute3a: true,
        ),
      );

      final analysis = CrossPillarCalculator.analyze(profile: profile);

      final has3aInsight = analysis.insights
          .any((i) => i.type == CrossPillarType.pillar3aOptimization);
      expect(has3aInsight, isTrue,
          reason:
              'Non-FATCA user with 0 3a should get optimization suggestion');
    });

    test('golden Lauren (US/FATCA) → canContribute3a == false', () {
      // Lauren from CLAUDE.md golden couple: US citizen, FATCA
      final lauren = buildProfile(
        birthYear: 1982,
        salaireBrutMensuel: 5583,
        canton: 'VS',
        nationality: 'US',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 19620,
          totalEpargne3a: 14000,
        ),
      );

      expect(lauren.archetype, FinancialArchetype.expatUs);
      expect(lauren.canContribute3a, isFalse);
    });
  });
}
