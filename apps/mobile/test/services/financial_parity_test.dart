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
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/cap_sequence_engine.dart';
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

  // ════════════════════════════════════════════════════════════════
  //  Parity W2 — Rente LPP (plan 02)
  //
  //  Oracle matrice §2 « Rente LPP » + « Capacité rachat LPP » :
  //  pour un même avoirLppTotal stocké, la rente mensuelle estimée est
  //  IDENTIQUE quel que soit le chemin (cap_sequence, minimal_profile, …) —
  //  fin du spread device-prouvé 250-347 CHF/mois (D4). UNE base de taux
  //  via LppCalculator.adjustedConversionRate / monthlyRenteFromAvoir.
  // ════════════════════════════════════════════════════════════════

  group('Parity W2 — Rente LPP', () {
    const memory = CapMemory();
    final l = SFr();

    /// Construit un profil retraite minimal avec un avoir LPP stocké
    /// et un taux de conversion de caisse explicite.
    CoachProfile _retirementProfile({
      required double avoirLpp,
      double tauxConversion = lppTauxConversionMinDecimal,
      int birthYear = 1976, // ~50 ans
      double salaireBrutMensuel = 9000,
      int? targetRetirementAge,
      double rachatMaximum = 0,
    }) {
      return CoachProfile(
        birthYear: birthYear,
        canton: 'GE',
        salaireBrutMensuel: salaireBrutMensuel,
        employmentStatus: 'salarie',
        targetRetirementAge: targetRetirementAge,
        prevoyance: PrevoyanceProfile(
          avoirLppTotal: avoirLpp,
          tauxConversion: tauxConversion,
          rachatMaximum: rachatMaximum,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2041),
          label: 'Retraite',
        ),
      );
    }

    /// Rente LPP mensuelle estimée via le chemin public CapSequenceEngine
    /// (step « ret_03_lpp », impactEstimate = rente mensuelle).
    double _capSequenceRente(CoachProfile profile) {
      final seq = CapSequenceEngine.build(
        profile: profile,
        memory: memory,
        goalIntentTag: 'retirement_choice',
        l: l,
      );
      final step = seq.steps.firstWhere((s) => s.id == 'ret_03_lpp');
      return step.impactEstimate ?? 0.0;
    }

    /// Impact mensuel d'un rachat via le chemin public CapSequenceEngine
    /// (step « ret_06_rachat », impactEstimate = impact mensuel).
    double _capSequenceRachatImpact(CoachProfile profile) {
      final seq = CapSequenceEngine.build(
        profile: profile,
        memory: memory,
        goalIntentTag: 'retirement_choice',
        l: l,
      );
      final step = seq.steps.firstWhere((s) => s.id == 'ret_06_rachat');
      return step.impactEstimate ?? 0.0;
    }

    test('avoir 300000 — UNE rente : cap_sequence == canonique (centime)', () {
      const avoir = 300000.0;
      final profile = _retirementProfile(avoirLpp: avoir);

      // Référence canonique : avoir × adjustedConversionRate(0.068, 65) / 12.
      final canonical = LppCalculator.monthlyRenteFromAvoir(
        avoir: avoir,
        baseRate: profile.prevoyance.tauxConversion,
        retirementAge: profile.effectiveRetirementAge,
      );

      // À l'âge de référence (65), adjustedConversionRate retourne baseRate :
      // 300000 × 0.068 / 12 = 1700 CHF/mois.
      expect(canonical, closeTo(1700.0, 0.01));

      expect(_capSequenceRente(profile), closeTo(canonical, 0.01),
          reason: 'cap_sequence doit déléguer à monthlyRenteFromAvoir');
    });

    test('retraite anticipée 62 < 65 — réduction art.13 al.2 appliquée', () {
      const avoir = 300000.0;
      final reference = _retirementProfile(avoirLpp: avoir);
      final early =
          _retirementProfile(avoirLpp: avoir, targetRetirementAge: 62);

      final renteReference = _capSequenceRente(reference);
      final renteEarly = _capSequenceRente(early);

      // 3 ans avant 65 → 3 × 0.002 = 0.006 de réduction → taux 0.062.
      final canonicalEarly = LppCalculator.monthlyRenteFromAvoir(
        avoir: avoir,
        baseRate: lppTauxConversionMinDecimal,
        retirementAge: 62,
      );
      expect(canonicalEarly, closeTo(300000 * 0.062 / 12, 0.01));

      // La retraite anticipée produit une rente strictement inférieure.
      expect(renteEarly, lessThan(renteReference),
          reason: 'la réduction LPP retraite anticipée doit s\'appliquer');
      expect(renteEarly, closeTo(canonicalEarly, 0.01));
    });

    test('avoir 250000 — minimal_profile == cap_sequence (même taux/age)', () {
      const avoir = 250000.0;
      const age = 50;
      final birthYear = DateTime.now().year - age;
      final profile = _retirementProfile(avoirLpp: avoir, birthYear: birthYear);

      final capRente = _capSequenceRente(profile);

      // minimal_profile partage le même avoir stocké, le même taux (0.068
      // obligatoire) et le même age de retraite référence (65).
      final minimal = MinimalProfileService.compute(
        age: age,
        grossSalary: profile.revenuBrutAnnuel,
        canton: 'GE',
        employmentStatus: 'salarie',
        existingLpp: avoir,
      );

      // Les deux chemins convertissent le MÊME avoir stocké au MÊME taux.
      expect(minimal.lppMonthlyRente, closeTo(capRente, 0.01),
          reason: 'minimal_profile et cap_sequence doivent partager la base');
    });

    test('rachat 50000 — impact identique par les deux chemins (fin 283 vs 242)',
        () {
      const avoir = 200000.0;
      const rachat = 50000.0;
      final profile =
          _retirementProfile(avoirLpp: avoir, rachatMaximum: rachat);

      final impactCap = _capSequenceRachatImpact(profile);

      // L'impact d'un rachat utilise la MÊME base de taux que la rente
      // (fin de la divergence 283 vs 242 CHF/mois). 50000 × 0.068 / 12.
      final canonicalImpact = LppCalculator.monthlyRenteFromAvoir(
        avoir: rachat,
        baseRate: profile.prevoyance.tauxConversion,
        retirementAge: profile.effectiveRetirementAge,
      );
      expect(canonicalImpact, closeTo(50000 * 0.068 / 12, 0.01));
      expect(impactCap, closeTo(canonicalImpact, 0.01),
          reason: 'impact rachat doit déléguer à la même base canonique');
    });
  });
}
