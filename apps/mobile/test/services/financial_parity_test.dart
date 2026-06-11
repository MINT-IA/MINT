// Parity test harness for the « mint-illogism-fixes » phase.
//
// Encode l'oracle de la matrice d'illogismes
// (.planning/reports/MATRIX-illogismes-2026-06-09.md) sous forme de tests de
// parité : pour un même input, les moteurs d'estimation financière doivent
// produire un chiffre IDENTIQUE (au centime), quelle que soit la surface
// publique empruntée. Toute régression vers la classe DIVERGENT casse la CI.
//
// Conformément à CLAUDE.md NEVER #3 (pas de calcul dupliqué L1), la source
// canonique est `LppCalculator` (financial_core L1). Les tests passent par les
// surfaces PUBLIQUES uniquement (CoachProfile.fromWizardAnswers /
// MinimalProfileService.compute) — jamais par les membres privés `_estimate*`.
//
// Groupes prévus :
//   - « Parity W1 — Avoir LPP »          (plan 01, ce fichier)
//   - « Parity W2 — Rente LPP »          (plan 02)
//   - « Parity W3 — Taux de remplacement » (plan 03)
//   - « Parity W4 — 3a »                  (plan 04)
//   - « Parity W5 — Invariants »          (plan 05)

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';

/// Construit les réponses du wizard pour un profil salarié canonique.
///
/// `q_gross_salary_annual` court-circuite la conversion net→brut afin que le
/// salaire brut soit déterministe (salaireBrutMensuel = gross / 12).
Map<String, dynamic> _salariedAnswers({
  required int age,
  required double grossAnnual,
  String? avsLacunesStatus,
  int? arrivalYear,
}) {
  final birthYear = DateTime.now().year - age;
  return <String, dynamic>{
    'q_birth_year': birthYear,
    'q_canton': 'GE',
    'q_employment_status': 'salarie',
    'q_pay_frequency': 'yearly',
    'q_gross_salary_annual': grossAnnual,
    'q_has_pension_fund': true,
    if (avsLacunesStatus != null) 'q_avs_lacunes_status': avsLacunesStatus,
    if (arrivalYear != null) 'q_avs_arrival_year': arrivalYear,
  };
}

/// Avoir LPP estimé via la surface publique CoachProfile.
double _coachAvoir(Map<String, dynamic> answers) {
  final profile = CoachProfile.fromWizardAnswers(answers);
  return profile.prevoyance.avoirLppTotal ?? 0.0;
}

/// Avoir LPP estimé via la surface publique MinimalProfileService.
double _minimalAvoir({
  required int age,
  required double grossAnnual,
  int? arrivalAge,
}) {
  final result = MinimalProfileService.compute(
    age: age,
    grossSalary: grossAnnual,
    canton: 'GE',
    employmentStatus: 'salarie',
    arrivalAge: arrivalAge,
  );
  return result.existingLpp;
}

void main() {
  group('Parity W1 — Avoir LPP', () {
    test('salarie_swiss-1 — 42/102000 : 3 chemins égaux + coord plafonné 64260',
        () {
      const age = 42;
      const gross = 102000.0;

      final coach = _coachAvoir(_salariedAnswers(age: age, grossAnnual: gross));
      final minimal = _minimalAvoir(age: age, grossAnnual: gross);
      // Référence canonique : accumulation balance-only depuis 25 (financial_core).
      final canonical = LppCalculator.accumulateAvoir(
        currentAge: age,
        grossAnnualSalary: gross,
      );

      // Le salaire coordonné est plafonné à 64260 (LPP art. 8) — 102000 - 26460
      // = 75540 > 64260, donc clamp haut. Régression mesurée : clamp min-only.
      expect(
        LppCalculator.computeSalaireCoordonne(gross),
        closeTo(64260.0, 0.01),
      );

      expect(coach, closeTo(canonical, 0.01),
          reason: 'coach divergent de la source canonique');
      expect(minimal, closeTo(canonical, 0.01),
          reason: 'minimal divergent de la source canonique');
      expect(coach, closeTo(minimal, 0.01),
          reason: 'coach et minimal divergent entre eux (classe DIVERGENT)');
    });

    test('cadre_divorce_hypo-2 — 52/162000 : 3 chemins égaux au centime', () {
      const age = 52;
      const gross = 162000.0;

      final coach = _coachAvoir(_salariedAnswers(age: age, grossAnnual: gross));
      final minimal = _minimalAvoir(age: age, grossAnnual: gross);
      final canonical = LppCalculator.accumulateAvoir(
        currentAge: age,
        grossAnnualSalary: gross,
      );

      // Cas où l'écart historique culminait à +105% (gross 162k au-delà du
      // plafond → le clamp min-only de coach gonflait le salaire coordonné).
      expect(coach, closeTo(canonical, 0.01));
      expect(minimal, closeTo(canonical, 0.01));
      expect(coach, closeTo(minimal, 0.01));
    });

    test('jeune_diplome-1 (contrôle négatif) — 25/78000 : avoir == 0 partout',
        () {
      const age = 25;
      const gross = 78000.0;

      final coach = _coachAvoir(_salariedAnswers(age: age, grossAnnual: gross));
      final minimal = _minimalAvoir(age: age, grossAnnual: gross);
      final canonical = LppCalculator.accumulateAvoir(
        currentAge: age,
        grossAnnualSalary: gross,
      );

      // Aucune année de bonification écoulée (boucle [25, 25)) → avoir 0.
      expect(canonical, closeTo(0.0, 0.01));
      expect(coach, closeTo(0.0, 0.01),
          reason: 'NE PAS régresser le contrôle négatif jeune diplômé');
      expect(minimal, closeTo(0.0, 0.01));
    });

    test('returning_swiss_gaps-4 — 48/120000/arrivée 43 : accumulation ~5 ans',
        () {
      const age = 48;
      const gross = 120000.0;
      const arrivalAge = 43;
      final arrivalYear = DateTime.now().year - age + arrivalAge;

      final coach = _coachAvoir(_salariedAnswers(
        age: age,
        grossAnnual: gross,
        avsLacunesStatus: 'arrived_late',
        arrivalYear: arrivalYear,
      ));
      final minimal = _minimalAvoir(
        age: age,
        grossAnnual: gross,
        arrivalAge: arrivalAge,
      );

      // Référence : accumulation démarrant à 43, pas à 25 → ~5 années
      // (43→48) au lieu de 23 (25→48).
      final canonicalArrival = LppCalculator.accumulateAvoir(
        currentAge: age,
        grossAnnualSalary: gross,
        startAge: arrivalAge,
      );
      final canonicalFrom25 = LppCalculator.accumulateAvoir(
        currentAge: age,
        grossAnnualSalary: gross,
      );

      // L'accumulation depuis l'arrivée est nettement inférieure à depuis 25.
      expect(canonicalArrival, lessThan(canonicalFrom25));

      expect(coach, closeTo(canonicalArrival, 0.01),
          reason: 'coach doit démarrer l\'accumulation à arrivalAge=43');
      expect(minimal, closeTo(canonicalArrival, 0.01),
          reason: 'minimal doit démarrer l\'accumulation à arrivalAge=43');
      expect(coach, closeTo(minimal, 0.01));
    });
  });
}
