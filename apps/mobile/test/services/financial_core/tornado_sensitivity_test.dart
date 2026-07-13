import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/tornado_sensitivity_service.dart';

void main() {
  group('TornadoSensitivityService.compute', () {
    test('rich minimal and couple profiles stay unavailable without AVS', () {
      for (final profile in [
        _buildFullProfile(),
        _buildMinimalProfile(),
        _buildCoupleProfile(),
      ]) {
        final result = TornadoSensitivityService.compute(
          profile: profile,
          retirementAgeUser: 65,
          retirementAgeConjoint: profile.isCouple ? 65 : null,
        );
        expect(result, isEmpty);
        expect(
          result.where((variable) => variable.category == 'avs'),
          isEmpty,
          reason: 'A dormant sensitivity must not fabricate AVS variables',
        );
      }
    });

    test('results are sorted by swing descending', () {
      final profile = _buildFullProfile();
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      for (int i = 0; i < result.length - 1; i++) {
        expect(
          result[i].swing,
          greaterThanOrEqualTo(result[i + 1].swing),
          reason: 'Variable ${result[i].label} (swing=${result[i].swing}) '
              'should have >= swing than ${result[i + 1].label} '
              '(swing=${result[i + 1].swing})',
        );
      }
    });

    test('retirement age sensitivity stays unavailable', () {
      final profile = _buildFullProfile();
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      expect(result, isEmpty);
    });

    test('LPP balance sensitivity stays unavailable', () {
      final profile = _buildFullProfile();
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      expect(result, isEmpty);
    });

    test('variables with 0 base value are skipped', () {
      // Profile with zero investissements, zero epargne, zero 3a
      final profile = _buildMinimalProfile();
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      final labels = result.map((v) => v.label).toList();
      // No investissements = skip
      expect(labels, isNot(contains('Investissements libres')));
      // No epargne liquide = skip
      expect(labels, isNot(contains('\u00C9pargne liquide')));
      // No 3a = skip
      expect(labels, isNot(contains('Capital 3e pilier')));
      // No 3a mensuel = skip
      expect(labels, isNot(contains('\u00C9pargne 3a mensuelle')));
      // No epargne libre mensuelle = skip
      expect(labels, isNot(contains('\u00C9pargne libre mensuelle')));
    });

    test('all labels are non-empty', () {
      final profile = _buildFullProfile();
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      for (final v in result) {
        expect(v.label, isNotEmpty, reason: 'label should not be empty');
        expect(v.lowLabel, isNotEmpty, reason: 'lowLabel should not be empty');
        expect(v.highLabel, isNotEmpty,
            reason: 'highLabel should not be empty');
        expect(v.category, isNotEmpty,
            reason: 'category should not be empty');
      }
    });

    test('couple-only variables excluded for singles', () {
      final profile = _buildMinimalProfile();
      // Minimal profile is celibataire
      expect(profile.isCouple, isFalse);

      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      final labels = result.map((v) => v.label).toList();
      expect(labels, isNot(contains('Salaire conjoint\u00B7e')));
    });

    test('couple profile does not expose partial sensitivity variables', () {
      final profile = _buildCoupleProfile();
      expect(profile.isCouple, isTrue);

      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
        retirementAgeConjoint: 65,
      );
      expect(result, isEmpty);
    });

    test('minimal profile stays unavailable', () {
      final profile = _buildMinimalProfile();
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      expect(result, isEmpty);
    });

    test('baseValue is consistent across all variables', () {
      final profile = _buildFullProfile();
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      expect(result, isEmpty,
          reason: 'There is no complete base projection to compare');
    });

    test('swing equals abs(highValue - lowValue)', () {
      final profile = _buildFullProfile();
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      for (final v in result) {
        expect(
          v.swing,
          closeTo((v.highValue - v.lowValue).abs(), 0.01),
          reason: '${v.label}: swing should equal |high - low|',
        );
      }
    });

    test('categories are valid', () {
      final profile = _buildFullProfile();
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      const validCategories = {
        'strategy', 'lpp', 'avs', '3a', 'libre', 'depenses',
      };
      for (final v in result) {
        expect(
          validCategories.contains(v.category),
          isTrue,
          reason: '${v.label}: category "${v.category}" not in $validCategories',
        );
      }
    });

    test('salary sensitivity stays unavailable without official AVS', () {
      final profile = _buildFullProfile();
      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );
      expect(result, isEmpty);
    });

    test('uncertified AVS gaps fail closed with no sensitivity results', () {
      final profile = _buildFullProfile().copyWith(dataSources: const {});

      final result = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: 65,
      );

      expect(result, isEmpty);
    });
  });
}

// ════════════════════════════════════════════════════════════════
//  TEST HELPERS
// ════════════════════════════════════════════════════════════════

/// Full profile with all fields populated — maximizes variable coverage.
CoachProfile _buildFullProfile() {
  return CoachProfile(
    firstName: 'Test',
    birthYear: DateTime.now().year - 45,
    canton: 'ZH',
    salaireBrutMensuel: 8000,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.celibataire,
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 300000,
      tauxConversion: 0.068,
      rendementCaisse: 0.02,
      totalEpargne3a: 50000,
      nombre3a: 3,
      anneesContribuees: 25,
      lacunesAVS: 2,
    ),
    patrimoine: const PatrimoineProfile(
      epargneLiquide: 20000,
      investissements: 80000,
    ),
    depenses: const DepensesProfile(
      loyer: 1800,
      assuranceMaladie: 450,
    ),
    plannedContributions: const [
      PlannedMonthlyContribution(
        id: '3a_test',
        label: '3a Test',
        amount: 604,
        category: '3a',
      ),
      PlannedMonthlyContribution(
        id: 'invest_test',
        label: 'Investissements',
        amount: 500,
        category: 'investissement',
      ),
      PlannedMonthlyContribution(
        id: 'epargne_test',
        label: 'Epargne libre',
        amount: 300,
        category: 'epargne_libre',
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

/// Minimal profile — salary only, no patrimoine/3a/epargne.
CoachProfile _buildMinimalProfile() {
  return CoachProfile(
    firstName: 'Mini',
    birthYear: DateTime.now().year - 35,
    canton: 'GE',
    salaireBrutMensuel: 6000,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.celibataire,
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 80000,
      tauxConversion: 0.068,
      rendementCaisse: 0.02,
      lacunesAVS: 0,
    ),
    patrimoine: const PatrimoineProfile(
      epargneLiquide: 0,
      investissements: 0,
    ),
    depenses: const DepensesProfile(
      loyer: 1500,
      assuranceMaladie: 400,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055),
      label: 'Retraite',
    ),
    dataSources: const {
      AvsGapEvidence.selfFieldPath: ProfileDataSource.certificate,
    },
  );
}

/// Couple profile — includes conjoint for testing couple-only variables.
CoachProfile _buildCoupleProfile() {
  return CoachProfile(
    firstName: 'Alice',
    birthYear: DateTime.now().year - 40,
    canton: 'VD',
    salaireBrutMensuel: 7500,
    nombreDeMois: 13,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.marie,
    conjoint: ConjointProfile(
      firstName: 'Bob',
      birthYear: DateTime.now().year - 38,
      salaireBrutMensuel: 5000,
      nombreDeMois: 12,
      employmentStatus: 'salarie',
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 120000,
        tauxConversion: 0.068,
        rendementCaisse: 0.02,
        totalEpargne3a: 20000,
        nombre3a: 1,
        lacunesAVS: 0,
      ),
    ),
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 200000,
      tauxConversion: 0.060,
      rendementCaisse: 0.02,
      totalEpargne3a: 40000,
      nombre3a: 2,
      anneesContribuees: 20,
      lacunesAVS: 1,
    ),
    patrimoine: const PatrimoineProfile(
      epargneLiquide: 30000,
      investissements: 60000,
    ),
    depenses: const DepensesProfile(
      loyer: 2200,
      assuranceMaladie: 900,
    ),
    plannedContributions: const [
      PlannedMonthlyContribution(
        id: '3a_alice',
        label: '3a Alice',
        amount: 604,
        category: '3a',
      ),
      PlannedMonthlyContribution(
        id: '3a_bob',
        label: '3a Bob',
        amount: 604,
        category: '3a',
      ),
      PlannedMonthlyContribution(
        id: 'invest_couple',
        label: 'Investissements',
        amount: 800,
        category: 'investissement',
      ),
    ],
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2051),
      label: 'Retraite',
    ),
    dataSources: const {
      AvsGapEvidence.selfFieldPath: ProfileDataSource.certificate,
      AvsGapEvidence.spouseFieldPath: ProfileDataSource.certificate,
    },
  );
}
