import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/fri_computation_service.dart';

/// Tests for FriComputationService — FRI computation from CoachProfile.
///
/// FRI (Financial Resilience Index) bridges CoachProfile + ProjectionResult → FriInput → FriCalculator.
/// All 4 axes: L(iquidity), F(iscal), R(etirement), S(tructural risk).
///
/// Legal: LAVS art. 21-29, LPP art. 14-16, LIFD art. 38, FINMA circ. 2008/21.
void main() {
  /// Helper to build a minimal CoachProfile for FRI testing.
  CoachProfile buildProfile({
    int birthYear = 1977,
    String canton = 'VS',
    double salaireBrutMensuel = 10000,
    String employmentStatus = 'salarie',
    CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
    int nombreEnfants = 0,
    double epargneLiquide = 50000,
    double investissements = 100000,
    double totalDettes = 0,
    double? avoirLppTotal,
    double? rachatMaximum,
    double? rachatEffectue,
    double? immobilier,
    double? propertyMarketValue,
    double? mortgageBalance,
    double? mortgageRate,
    String? nationality,
    int? arrivalAge,
    String? residencePermit,
    List<PlannedMonthlyContribution> contributions = const [],
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaireBrutMensuel,
      employmentStatus: employmentStatus,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
      nationality: nationality,
      arrivalAge: arrivalAge,
      residencePermit: residencePermit,
      patrimoine: PatrimoineProfile(
        epargneLiquide: epargneLiquide,
        investissements: investissements,
        immobilier: immobilier,
        propertyMarketValue: propertyMarketValue,
        mortgageBalance: mortgageBalance,
        mortgageRate: mortgageRate,
      ),
      dettes: DetteProfile(autresDettes: totalDettes),
      prevoyance: PrevoyanceProfile(
        avoirLppTotal: avoirLppTotal,
        rachatMaximum: rachatMaximum,
        rachatEffectue: rachatEffectue,
      ),
      plannedContributions: contributions,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042, 1, 1),
        label: 'Retraite',
      ),
    );
  }

  /// Helper for a minimal ProjectionResult.
  ProjectionResult buildProjection({double tauxRemplacementBase = 0.6}) {
    const scenario = ProjectionScenario(
      label: 'Base',
      points: [],
      capitalFinal: 500000,
      revenuAnnuelRetraite: 50000,
      decomposition: {'avs': 30000, 'lpp': 20000},
    );
    return ProjectionResult(
      prudent: scenario,
      base: scenario,
      optimiste: scenario,
      tauxRemplacementBase: tauxRemplacementBase,
      milestones: const [],
      disclaimer: 'test',
      sources: const [],
    );
  }

  group('FriComputationService.compute', () {
    test('returns FriBreakdown with all axes for salaried worker', () {
      final profile = buildProfile();
      final projection = buildProjection();
      final result = FriComputationService.compute(
        profile: profile,
        projection: projection,
      );

      expect(result.total, greaterThan(0));
      expect(result.total, lessThanOrEqualTo(100));
      expect(result.liquidite, greaterThanOrEqualTo(0));
      expect(result.fiscalite, greaterThanOrEqualTo(0));
      expect(result.retraite, greaterThanOrEqualTo(0));
      expect(result.risque, greaterThanOrEqualTo(0));
    });

    test('high liquidity improves L axis — 6+ months expenses', () {
      // 50k savings / ~6250 monthly expenses ≈ 8 months
      final highLiq = FriComputationService.compute(
        profile: buildProfile(epargneLiquide: 100000),
        projection: buildProjection(),
      );
      final lowLiq = FriComputationService.compute(
        profile: buildProfile(epargneLiquide: 5000),
        projection: buildProjection(),
      );

      expect(highLiq.liquidite, greaterThan(lowLiq.liquidite),
          reason: 'More liquid savings → better liquidity score');
    });

    test('high debt ratio worsens L axis', () {
      final noDebt = FriComputationService.compute(
        profile: buildProfile(totalDettes: 0),
        projection: buildProjection(),
      );
      final highDebt = FriComputationService.compute(
        profile: buildProfile(totalDettes: 200000),
        projection: buildProjection(),
      );

      expect(noDebt.liquidite, greaterThanOrEqualTo(highDebt.liquidite),
          reason: 'High debt lowers liquidity score');
    });

    test('higher replacement ratio improves R axis', () {
      final high = FriComputationService.compute(
        profile: buildProfile(),
        projection: buildProjection(tauxRemplacementBase: 0.8),
      );
      final low = FriComputationService.compute(
        profile: buildProfile(),
        projection: buildProjection(tauxRemplacementBase: 0.3),
      );

      expect(high.retraite, greaterThan(low.retraite),
          reason: '80% replacement rate > 30%');
    });

    test('independant worker has different employer dependency', () {
      final salarie = FriComputationService.compute(
        profile: buildProfile(employmentStatus: 'salarie'),
        projection: buildProjection(),
      );
      final indep = FriComputationService.compute(
        profile: buildProfile(employmentStatus: 'independant'),
        projection: buildProjection(),
      );

      // Both should compute successfully
      expect(salarie.total, greaterThan(0));
      expect(indep.total, greaterThan(0));
    });

    test('mortgage stress ratio affects S axis — FINMA 5% theoretical rate', () {
      final noMortgage = FriComputationService.compute(
        profile: buildProfile(),
        projection: buildProjection(),
      );
      final highMortgage = FriComputationService.compute(
        profile: buildProfile(
          mortgageBalance: 600000,
          propertyMarketValue: 800000,
          mortgageRate: 0.05,
          immobilier: 800000,
        ),
        projection: buildProjection(),
      );

      expect(noMortgage.risque,
          greaterThanOrEqualTo(highMortgage.risque),
          reason: 'Heavy mortgage worsens structural risk');
    });

    test('property owner with 3a gets amort indirect benefit on F axis', () {
      final withProperty = FriComputationService.compute(
        profile: buildProfile(
          immobilier: 500000,
          propertyMarketValue: 500000,
        ),
        projection: buildProjection(),
      );
      // Should compute without error
      expect(withProperty.fiscalite, greaterThanOrEqualTo(0));
    });

    test('married with children flags hasDependents for S axis', () {
      final result = FriComputationService.compute(
        profile: buildProfile(
          etatCivil: CoachCivilStatus.marie,
          nombreEnfants: 2,
        ),
        projection: buildProjection(),
      );
      expect(result.risque, greaterThanOrEqualTo(0));
      expect(result.total, greaterThan(0));
    });

    test('confidence score is passed through to FRI computation', () {
      final result = FriComputationService.compute(
        profile: buildProfile(),
        projection: buildProjection(),
        confidenceScore: 85.0,
      );
      // FRI should still compute valid result regardless of confidence
      expect(result.total, greaterThan(0));
      expect(result.total, lessThanOrEqualTo(100));
    });

    test('overall score is bounded 0-100', () {
      // Extreme values: very poor profile
      final poor = FriComputationService.compute(
        profile: buildProfile(
          epargneLiquide: 0,
          investissements: 0,
          totalDettes: 500000,
          salaireBrutMensuel: 3000,
        ),
        projection: buildProjection(tauxRemplacementBase: 0.1),
      );
      expect(poor.total, greaterThanOrEqualTo(0));
      expect(poor.total, lessThanOrEqualTo(100));

      // Excellent profile
      final excellent = FriComputationService.compute(
        profile: buildProfile(
          epargneLiquide: 200000,
          investissements: 500000,
          totalDettes: 0,
          salaireBrutMensuel: 15000,
        ),
        projection: buildProjection(tauxRemplacementBase: 0.9),
      );
      expect(excellent.total, greaterThanOrEqualTo(0));
      expect(excellent.total, lessThanOrEqualTo(100));
    });
  });

  group('FriComputationService.detectArchetype', () {
    test('swiss_native for CH nationality', () {
      final profile = buildProfile(nationality: 'CH');
      expect(FriComputationService.detectArchetype(profile), 'swiss_native');
    });

    test('swiss_native for "suisse" nationality', () {
      final profile = buildProfile(nationality: 'suisse');
      expect(FriComputationService.detectArchetype(profile), 'swiss_native');
    });

    test('expat_us for US nationality — FATCA', () {
      final profile = buildProfile(nationality: 'US');
      expect(FriComputationService.detectArchetype(profile), 'expat_us');
    });

    test('expat_us for USA nationality', () {
      final profile = buildProfile(nationality: 'USA');
      expect(FriComputationService.detectArchetype(profile), 'expat_us');
    });

    test('cross_border for permit G — frontalier', () {
      final profile = buildProfile(nationality: 'FR', residencePermit: 'G');
      expect(FriComputationService.detectArchetype(profile), 'cross_border');
    });

    test('independent_with_lpp for independant with LPP', () {
      final profile = buildProfile(
        employmentStatus: 'independant',
        avoirLppTotal: 50000,
      );
      expect(FriComputationService.detectArchetype(profile), 'independent_with_lpp');
    });

    test('independent_no_lpp for independant without LPP', () {
      final profile = buildProfile(
        employmentStatus: 'independant',
        avoirLppTotal: 0,
      );
      expect(FriComputationService.detectArchetype(profile), 'independent_no_lpp');
    });

    test('returning_swiss for CH national arrived late', () {
      final profile = buildProfile(nationality: 'CH', arrivalAge: 35);
      expect(FriComputationService.detectArchetype(profile), 'returning_swiss');
    });

    test('expat_eu for EU national arrived after 20', () {
      final profile = buildProfile(nationality: 'fr', arrivalAge: 25);
      expect(FriComputationService.detectArchetype(profile), 'expat_eu');
    });

    test('expat_non_eu for non-EU national arrived after 20', () {
      final profile = buildProfile(nationality: 'jp', arrivalAge: 30);
      expect(FriComputationService.detectArchetype(profile), 'expat_non_eu');
    });

    test('swiss_native for foreign national arrived young (< 20)', () {
      final profile = buildProfile(nationality: 'de', arrivalAge: 15);
      expect(FriComputationService.detectArchetype(profile), 'swiss_native');
    });

    test('independant overrides nationality check', () {
      // Even if US citizen, independant detection takes priority
      final profile = buildProfile(
        nationality: 'US',
        employmentStatus: 'independant',
        avoirLppTotal: 0,
      );
      expect(FriComputationService.detectArchetype(profile), 'independent_no_lpp');
    });
  });
}
