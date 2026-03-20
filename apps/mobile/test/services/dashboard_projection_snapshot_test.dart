import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/dashboard_projection_snapshot.dart';
import 'package:mint_mobile/services/forecaster_service.dart';

/// Tests for DashboardProjectionSnapshot — single source of truth for dashboard numbers.
///
/// Validates that the snapshot correctly extracts per-pillar monthly income
/// from ForecasterService output and current household net income from profile.
void main() {
  /// Helper: build a minimal ProjectionResult.
  ProjectionResult buildProjection({
    double revenuAnnuelBase = 60000,
    double revenuAnnuelPrudent = 48000,
    double revenuAnnuelOptimiste = 72000,
    double tauxRemplacement = 0.6,
    Map<String, double> decomposition = const {
      'avs': 30000,
      'avs_user': 20000,
      'avs_conjoint': 10000,
      'lpp_user': 15000,
      'lpp_conjoint': 8000,
      '3a': 5000,
      'libre': 2000,
    },
  }) {
    final scenario = ProjectionScenario(
      label: 'Base',
      points: const [],
      capitalFinal: 500000,
      revenuAnnuelRetraite: revenuAnnuelBase,
      decomposition: decomposition,
    );
    final prudent = ProjectionScenario(
      label: 'Prudent',
      points: const [],
      capitalFinal: 400000,
      revenuAnnuelRetraite: revenuAnnuelPrudent,
      decomposition: decomposition,
    );
    final optimiste = ProjectionScenario(
      label: 'Optimiste',
      points: const [],
      capitalFinal: 600000,
      revenuAnnuelRetraite: revenuAnnuelOptimiste,
      decomposition: decomposition,
    );
    return ProjectionResult(
      prudent: prudent,
      base: scenario,
      optimiste: optimiste,
      tauxRemplacementBase: tauxRemplacement,
      milestones: const [],
      disclaimer: 'test',
      sources: const [],
    );
  }

  /// Helper: build a minimal CoachProfile.
  CoachProfile buildProfile({
    double salaireBrutMensuel = 10000,
    int birthYear = 1977,
    String canton = 'VS',
    ConjointProfile? conjoint,
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaireBrutMensuel,
      conjoint: conjoint,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042, 1, 1),
        label: 'Retraite',
      ),
    );
  }

  group('DashboardProjectionSnapshot.fromProjection — single', () {
    test('totalMonthlyIncome = base revenuAnnuel / 12', () {
      final snap = DashboardProjectionSnapshot.fromProjection(
        projection: buildProjection(revenuAnnuelBase: 60000),
        profile: buildProfile(),
      );
      expect(snap.totalMonthlyIncome, closeTo(5000, 0.01));
    });

    test('monthlyPrudent and monthlyOptimiste reflect scenarios', () {
      final snap = DashboardProjectionSnapshot.fromProjection(
        projection: buildProjection(
          revenuAnnuelPrudent: 48000,
          revenuAnnuelOptimiste: 72000,
        ),
        profile: buildProfile(),
      );
      expect(snap.monthlyPrudent, closeTo(4000, 0.01));
      expect(snap.monthlyOptimiste, closeTo(6000, 0.01));
    });

    test('replacementRate comes from projection', () {
      final snap = DashboardProjectionSnapshot.fromProjection(
        projection: buildProjection(tauxRemplacement: 0.65),
        profile: buildProfile(),
      );
      expect(snap.replacementRate, 0.65);
    });

    test('per-pillar monthly income extracted from decomposition', () {
      final snap = DashboardProjectionSnapshot.fromProjection(
        projection: buildProjection(),
        profile: buildProfile(),
      );
      expect(snap.avsMonthly, closeTo(30000 / 12, 0.01));
      expect(snap.avsUserMonthly, closeTo(20000 / 12, 0.01));
      expect(snap.avsConjointMonthly, closeTo(10000 / 12, 0.01));
      expect(snap.lppUserMonthly, closeTo(15000 / 12, 0.01));
      expect(snap.lppConjointMonthly, closeTo(8000 / 12, 0.01));
      expect(snap.threeAMonthly, closeTo(5000 / 12, 0.01));
      expect(snap.libreMonthly, closeTo(2000 / 12, 0.01));
    });

    test('missing decomposition keys default to 0', () {
      final snap = DashboardProjectionSnapshot.fromProjection(
        projection: buildProjection(decomposition: const {'avs': 24000}),
        profile: buildProfile(),
      );
      expect(snap.avsMonthly, closeTo(2000, 0.01));
      expect(snap.lppUserMonthly, 0);
      expect(snap.lppConjointMonthly, 0);
      expect(snap.threeAMonthly, 0);
      expect(snap.libreMonthly, 0);
    });

    test('currentHouseholdNetMonthly computed from profile salary', () {
      final snap = DashboardProjectionSnapshot.fromProjection(
        projection: buildProjection(),
        profile: buildProfile(salaireBrutMensuel: 10000), // 120k/an
      );
      // NetIncomeBreakdown gives a net < gross
      expect(snap.currentHouseholdNetMonthly, greaterThan(0));
      expect(snap.currentHouseholdNetMonthly, lessThan(10000),
          reason: 'Net should be less than gross monthly salary');
    });
  });

  group('DashboardProjectionSnapshot.fromProjection — couple', () {
    test('includes conjoint net income in household total', () {
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 5500,
      );
      final snapCouple = DashboardProjectionSnapshot.fromProjection(
        projection: buildProjection(),
        profile: buildProfile(
          salaireBrutMensuel: 10000,
          conjoint: conjoint,
        ),
      );
      final snapSingle = DashboardProjectionSnapshot.fromProjection(
        projection: buildProjection(),
        profile: buildProfile(salaireBrutMensuel: 10000),
      );
      expect(snapCouple.currentHouseholdNetMonthly,
          greaterThan(snapSingle.currentHouseholdNetMonthly),
          reason: 'Couple household net includes conjoint salary');
    });

    test('conjoint with null salary does not increase household net', () {
      const conjoint = ConjointProfile(
        firstName: 'Test',
        birthYear: 1985,
        salaireBrutMensuel: null,
      );
      final snapWithConj = DashboardProjectionSnapshot.fromProjection(
        projection: buildProjection(),
        profile: buildProfile(conjoint: conjoint),
      );
      final snapSingle = DashboardProjectionSnapshot.fromProjection(
        projection: buildProjection(),
        profile: buildProfile(),
      );
      expect(snapWithConj.currentHouseholdNetMonthly,
          closeTo(snapSingle.currentHouseholdNetMonthly, 0.01));
    });

    test('conjoint with zero salary does not increase household net', () {
      const conjoint = ConjointProfile(
        firstName: 'Test',
        birthYear: 1985,
        salaireBrutMensuel: 0,
      );
      final snap = DashboardProjectionSnapshot.fromProjection(
        projection: buildProjection(),
        profile: buildProfile(conjoint: conjoint),
      );
      // Should be same as single
      final snapSingle = DashboardProjectionSnapshot.fromProjection(
        projection: buildProjection(),
        profile: buildProfile(),
      );
      expect(snap.currentHouseholdNetMonthly,
          closeTo(snapSingle.currentHouseholdNetMonthly, 0.01));
    });
  });

  group('DashboardProjectionSnapshot — edge cases', () {
    test('zero salary profile has zero household net', () {
      final snap = DashboardProjectionSnapshot.fromProjection(
        projection: buildProjection(),
        profile: buildProfile(salaireBrutMensuel: 0),
      );
      expect(snap.currentHouseholdNetMonthly, 0);
    });

    test('const constructor works for manual creation', () {
      const snap = DashboardProjectionSnapshot(
        totalMonthlyIncome: 5000,
        monthlyPrudent: 4000,
        monthlyOptimiste: 6000,
        replacementRate: 0.6,
        avsMonthly: 2500,
        avsUserMonthly: 1500,
        avsConjointMonthly: 1000,
        lppUserMonthly: 1250,
        lppConjointMonthly: 667,
        threeAMonthly: 417,
        libreMonthly: 167,
        currentHouseholdNetMonthly: 8000,
      );
      expect(snap.totalMonthlyIncome, 5000);
      expect(snap.currentHouseholdNetMonthly, 8000);
    });
  });
}
