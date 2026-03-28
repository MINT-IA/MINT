import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/product_cohort_service.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';

/// Golden personas for cohort testing (Anti-Bullshit Manifesto §8).
/// Each persona verifies: correct cohort, correct suppression, no absurd feedback.

CoachProfile _persona({
  required int birthYear,
  double salaire = 6000,
  String canton = 'VD',
  String employment = 'salarie',
  CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
  int enfants = 0,
  PrevoyanceProfile? prevoyance,
}) {
  return CoachProfile(
    birthYear: birthYear,
    salaireBrutMensuel: salaire,
    canton: canton,
    employmentStatus: employment,
    etatCivil: etatCivil,
    nombreEnfants: enfants,
    prevoyance: prevoyance ?? const PrevoyanceProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2060),
      label: 'Clarifier ma retraite',
    ),
  );
}

void main() {
  // ═══════════════════════════════════════════════════════════
  //  COHORT PROJECTION — maps LifecyclePhase → ProductCohort
  // ═══════════════════════════════════════════════════════════

  group('ProductCohortService.resolve — phase mapping', () {
    test('age 24 → premiersPas', () {
      final result = ProductCohortService.resolve(_persona(birthYear: 2002));
      expect(result.cohort, ProductCohort.premiersPas);
      expect(result.lifecycle.phase, LifecyclePhase.demarrage);
    });

    test('age 32 → construction', () {
      final result = ProductCohortService.resolve(_persona(birthYear: 1994));
      expect(result.cohort, ProductCohort.construction);
      expect(result.lifecycle.phase, LifecyclePhase.construction);
    });

    test('age 42 → densification (acceleration)', () {
      final result = ProductCohortService.resolve(_persona(birthYear: 1984));
      expect(result.cohort, ProductCohort.densification);
      expect(result.lifecycle.phase, LifecyclePhase.acceleration);
    });

    test('age 50 → densification (consolidation)', () {
      final result = ProductCohortService.resolve(_persona(birthYear: 1976));
      expect(result.cohort, ProductCohort.densification);
      expect(result.lifecycle.phase, LifecyclePhase.consolidation);
    });

    test('age 59 → preRetraite', () {
      final result = ProductCohortService.resolve(_persona(birthYear: 1967));
      expect(result.cohort, ProductCohort.preRetraite);
      expect(result.lifecycle.phase, LifecyclePhase.transition);
    });

    test('age 70 → retraiteActive', () {
      final result = ProductCohortService.resolve(
        _persona(birthYear: 1956, employment: 'retraite'),
      );
      expect(result.cohort, ProductCohort.retraiteActive);
    });

    test('age 82 → transmission', () {
      final result = ProductCohortService.resolve(
        _persona(birthYear: 1944, employment: 'retraite'),
      );
      expect(result.cohort, ProductCohort.transmission);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  SUPPRESSION RULES — Anti-Bullshit Manifesto §6
  // ═══════════════════════════════════════════════════════════

  group('Suppression rules — never show absurd content', () {
    test('22yo never sees succession or retirement deep', () {
      final result = ProductCohortService.resolve(_persona(birthYear: 2004));
      expect(result.suppressedTopics, contains('succession'));
      expect(result.suppressedTopics, contains('retirement_deep'));
      expect(result.suppressedTopics, contains('rente_vs_capital'));
    });

    test('59yo never sees first_job or birth_costs', () {
      final result = ProductCohortService.resolve(_persona(birthYear: 1967));
      expect(result.suppressedTopics, contains('first_job'));
      expect(result.suppressedTopics, contains('birth_costs'));
    });

    test('72yo never sees housing_purchase or job_comparison', () {
      final result = ProductCohortService.resolve(
        _persona(birthYear: 1954, employment: 'retraite'),
      );
      expect(result.suppressedTopics, contains('housing_purchase'));
      expect(result.suppressedTopics, contains('job_comparison'));
    });

    test('42yo has no suppressions (peak complexity)', () {
      final result = ProductCohortService.resolve(_persona(birthYear: 1984));
      expect(result.suppressedTopics, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  GOLDEN PERSONAS — 6 real-world profiles
  //  "Est-ce que cette personne aurait l'impression que MINT
  //   comprend vraiment sa situation ?"
  // ═══════════════════════════════════════════════════════════

  group('Golden personas — behavioral assertions', () {
    test('Alex (24, premier emploi) → premiersPas, no retirement', () {
      final alex = _persona(birthYear: 2002, salaire: 4500, canton: 'VS');
      final result = ProductCohortService.resolve(alex);

      expect(result.cohort, ProductCohort.premiersPas);
      expect(result.suppressedTopics, contains('retirement_deep'));
      expect(result.suppressedTopics, contains('succession'));
      expect(result.suppressedTopics, contains('lpp_buyback'));
      expect(result.lifecycle.tone, LifecycleTone.encouraging);
    });

    test('Julia (33, projet logement, mariée) → construction', () {
      final julia = _persona(
        birthYear: 1993, salaire: 7000, canton: 'VD',
        etatCivil: CoachCivilStatus.marie, enfants: 1,
      );
      final result = ProductCohortService.resolve(julia);

      expect(result.cohort, ProductCohort.construction);
      expect(result.suppressedTopics, contains('succession'));
      // Housing, couple, birth are NOT suppressed
      expect(result.suppressedTopics, isNot(contains('housing_purchase')));
    });

    test('Sabine (47, indépendante, haut revenu) → densification', () {
      final sabine = _persona(
        birthYear: 1979, salaire: 12000, canton: 'GE',
        employment: 'independant', enfants: 2,
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 300000),
      );
      final result = ProductCohortService.resolve(sabine);

      expect(result.cohort, ProductCohort.densification);
      expect(result.suppressedTopics, isEmpty); // Full access
      // Intermediate because financial literacy not explicitly set to advanced.
      // Complexity upgrades with explicit financialLiteracyLevel.
      expect(result.lifecycle.complexity, LifecycleComplexity.intermediate);
    });

    test('Jérôme (59, pré-retraité) → preRetraite, no first_job', () {
      final jerome = _persona(
        birthYear: 1967, salaire: 11000, canton: 'BE',
        etatCivil: CoachCivilStatus.marie,
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 800000),
      );
      final result = ProductCohortService.resolve(jerome);

      expect(result.cohort, ProductCohort.preRetraite);
      expect(result.suppressedTopics, contains('first_job'));
      expect(result.suppressedTopics, contains('birth_costs'));
      expect(result.lifecycle.tone, LifecycleTone.reassuring);
    });

    test('Christiane (72, retraitée active) → retraiteActive', () {
      final christiane = _persona(
        birthYear: 1954, salaire: 0, canton: 'ZH',
        employment: 'retraite',
      );
      final result = ProductCohortService.resolve(christiane);

      expect(result.cohort, ProductCohort.retraiteActive);
      expect(result.suppressedTopics, contains('first_job'));
      expect(result.suppressedTopics, contains('housing_purchase'));
      expect(result.lifecycle.tone, LifecycleTone.simple);
    });

    test('Margaret (82, transmission) → transmission, minimal topics', () {
      final margaret = _persona(
        birthYear: 1944, salaire: 0, canton: 'TI',
        employment: 'retraite',
      );
      final result = ProductCohortService.resolve(margaret);

      expect(result.cohort, ProductCohort.transmission);
      expect(result.suppressedTopics.length, greaterThanOrEqualTo(5));
      expect(result.suppressedTopics, contains('lpp_buyback'));
      expect(result.lifecycle.tone, LifecycleTone.simple);
    });

    // 18th assertion: cross-cohort consistency check
    test('densification has NO suppressed topics (full access to all tools)', () {
      final fullAccess = _persona(birthYear: 1984, salaire: 10000);
      final result = ProductCohortService.resolve(fullAccess);
      expect(result.cohort, ProductCohort.densification);
      expect(result.suppressedTopics, isEmpty,
          reason: 'Densification (38-52) should have unrestricted access');
    });
  });
}
