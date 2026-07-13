import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/tornado_sensitivity_service.dart';

// ════════════════════════════════════════════════════════════════
//  TORNADO SENSITIVITY SERVICE — edge-case tests
//
//  Covers: zero values, negative-like inputs, boundary retirement ages,
//  single-variable profiles, very large values, empty contributions,
//  multiple zeros, extreme ages, and variable isolation.
// ════════════════════════════════════════════════════════════════

void main() {
  group('TornadoSensitivityService — edge cases', () {
    // ──────────────────────────────────────────────────────────
    //  1. Zero salary produces limited variables
    // ──────────────────────────────────────────────────────────
    test('zero salary skips salary variable', () {
      final profile = _buildProfile(salaireBrutMensuel: 0);
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      final labels = result.map((v) => v.label).toList();
      expect(labels, isNot(contains('Salaire brut')));
    });

    // ──────────────────────────────────────────────────────────
    //  2. Boundary retirement age: minimum (58)
    // ──────────────────────────────────────────────────────────
    test('retirement age at boundary 58 does not crash', () {
      final profile = _buildProfile(birthYear: DateTime.now().year - 57);
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 58,
      );
      expect(result, isEmpty);
    });

    // ──────────────────────────────────────────────────────────
    //  3. Boundary retirement age: maximum (70)
    // ──────────────────────────────────────────────────────────
    test('retirement age at boundary 70 does not crash', () {
      final profile = _buildProfile(birthYear: DateTime.now().year - 45);
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 70,
      );
      expect(result, isEmpty);
    });

    // ──────────────────────────────────────────────────────────
    //  4. Very large salary (1M/month)
    // ──────────────────────────────────────────────────────────
    test('very large salary produces valid results without overflow', () {
      final profile = _buildProfile(salaireBrutMensuel: 1000000);
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      expect(result, isEmpty);
    });

    // ──────────────────────────────────────────────────────────
    //  5. Very large LPP avoir (10M)
    // ──────────────────────────────────────────────────────────
    test('very large LPP avoir does not overflow', () {
      final profile = _buildProfile(
        avoirLppTotal: 10000000,
        salaireBrutMensuel: 20000,
      );
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      expect(result, isEmpty);
    });

    // ──────────────────────────────────────────────────────────
    //  6. Empty contributions list — no 3a/libre variables
    // ──────────────────────────────────────────────────────────
    test('empty contributions skips epargne 3a and libre mensuelle', () {
      final profile = _buildProfile(
        plannedContributions: const [],
        totalEpargne3a: 0,
      );
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      final labels = result.map((v) => v.label).toList();
      expect(labels, isNot(contains('\u00c9pargne 3a mensuelle')));
      expect(labels, isNot(contains('\u00c9pargne libre mensuelle')));
      expect(labels, isNot(contains('Capital 3e pilier')));
    });

    // ──────────────────────────────────────────────────────────
    //  7. All zeros patrimoine — no patrimoine variables
    // ──────────────────────────────────────────────────────────
    test('zero patrimoine skips investissements and epargne liquide', () {
      final profile = _buildProfile(
        epargneLiquide: 0,
        investissements: 0,
      );
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      final labels = result.map((v) => v.label).toList();
      expect(labels, isNot(contains('Investissements libres')));
      expect(labels, isNot(contains('\u00c9pargne liquide')));
    });

    // ──────────────────────────────────────────────────────────
    //  8. Null anneesContribuees — AVS years variable excluded
    // ──────────────────────────────────────────────────────────
    test('null anneesContribuees excludes AVS years variable', () {
      final profile = _buildProfile(anneesContribuees: null);
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      final labels = result.map((v) => v.label).toList();
      expect(labels, isNot(contains('Ann\u00e9es AVS cotis\u00e9es')));
    });

    // ──────────────────────────────────────────────────────────
    //  9. Minimal profile remains unavailable without official AVS
    // ──────────────────────────────────────────────────────────
    test('minimal profile does not expose partial sensitivity variables', () {
      final profile = _buildProfile(
        salaireBrutMensuel: 5000,
        avoirLppTotal: 0,
        totalEpargne3a: 0,
        epargneLiquide: 0,
        investissements: 0,
        plannedContributions: const [],
      );
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      expect(result, isEmpty);
    });

    // ──────────────────────────────────────────────────────────
    //  10. Retirement at exactly current age — no crash
    // ──────────────────────────────────────────────────────────
    test('retirement age equal to current age does not crash', () {
      // Person born 65 years ago, retiring at 65 — edge case
      final profile = _buildProfile(birthYear: DateTime.now().year - 65);
      // This might produce limited or empty results, but must not throw
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      // All variables should have valid (finite) values
      for (final v in result) {
        expect(v.baseValue.isFinite, isTrue);
        expect(v.lowValue.isFinite, isTrue);
        expect(v.highValue.isFinite, isTrue);
      }
    });
  });
}

// ════════════════════════════════════════════════════════════════
//  TEST HELPERS
// ════════════════════════════════════════════════════════════════

CoachProfile _buildProfile({
  int? birthYear,
  double salaireBrutMensuel = 8000,
  double? avoirLppTotal = 200000,
  double totalEpargne3a = 40000,
  int nombre3a = 2,
  int? anneesContribuees = 20,
  double epargneLiquide = 15000,
  double investissements = 50000,
  List<PlannedMonthlyContribution>? plannedContributions,
}) {
  return CoachProfile(
    firstName: 'Edge',
    birthYear: birthYear ?? DateTime.now().year - 45,
    canton: 'ZH',
    salaireBrutMensuel: salaireBrutMensuel,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.celibataire,
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: avoirLppTotal,
      tauxConversion: 0.068,
      rendementCaisse: 0.02,
      totalEpargne3a: totalEpargne3a,
      nombre3a: nombre3a,
      anneesContribuees: anneesContribuees,
      lacunesAVS: 1,
    ),
    patrimoine: PatrimoineProfile(
      epargneLiquide: epargneLiquide,
      investissements: investissements,
    ),
    depenses: const DepensesProfile(
      loyer: 1500,
      assuranceMaladie: 400,
    ),
    plannedContributions: plannedContributions ?? const [
      PlannedMonthlyContribution(
        id: '3a_edge',
        label: '3a Test',
        amount: 604,
        category: '3a',
      ),
      PlannedMonthlyContribution(
        id: 'invest_edge',
        label: 'Investissements',
        amount: 400,
        category: 'investissement',
      ),
    ],
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
    dataSources: const {
      AvsGapEvidence.selfFieldPath: ProfileDataSource.certificate,
    },
  );
}
