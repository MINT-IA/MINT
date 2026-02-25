import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/financial_core/monte_carlo_models.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

// ────────────────────────────────────────────────────────────
//  MONTE CARLO PROJECTION SERVICE
// ────────────────────────────────────────────────────────────
//
// Simule N trajectoires de retraite (defaut: 500) avec des hypotheses
// stochastiques (rendements, inflation, longevite, croissance salariale)
// pour produire des bandes de percentiles (P10, P25, P50, P75, P90).
//
// L'objectif est de montrer l'incertitude inherente aux projections
// a long terme, plutot qu'un chiffre unique deterministe.
//
// Boucle de projection simplifiee — on ne rappelle PAS
// RetirementProjectionService.project() 500 fois (trop lent).
//
// Base legale des constantes: LAVS, LPP, OPP3, LIFD art. 38.
// Aucun terme interdit ("garanti", "certain", "sans risque").
// ────────────────────────────────────────────────────────────

class MonteCarloProjectionService {
  MonteCarloProjectionService._();

  // ── Constantes ──────────────────────────────────────────
  static const double _safeWithdrawalRate = 0.04;
  static const int _projectionYears = 30;
  static const double _threeADrawdownYears = 20.0;

  static const String _disclaimer =
      'Simulation Monte Carlo a titre pedagogique. '
      'Les rendements passes ne garantissent pas les rendements futurs. '
      'Base : 500 simulations, distributions normales '
      '(LPP, marche, inflation). '
      'Ne constitue pas un conseil en placement (LSFin).';

  static const List<String> _sources = [
    'LPP art. 14, 16 (taux de conversion)',
    'LAVS art. 34-40 (rentes AVS)',
    'LIFD art. 38 (imposition capital)',
    'OPP3 art. 3 (retrait 3e pilier)',
  ];

  // ════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ════════════════════════════════════════════════════════════

  /// Lance une simulation Monte Carlo de retraite.
  ///
  /// [profile] : profil financier complet de l'utilisateur.
  /// [retirementAgeUser] : age de depart a la retraite (defaut 65).
  /// [lppCapitalPct] : fraction du LPP retiree en capital (0.0 = 100% rente).
  /// [depensesMensuelles] : depenses mensuelles estimees a la retraite.
  /// [numSimulations] : nombre de simulations (defaut 500).
  /// [seed] : graine pour le generateur aleatoire (tests reproductibles).
  static MonteCarloResult simulate({
    required CoachProfile profile,
    int retirementAgeUser = 65,
    double lppCapitalPct = 0.0,
    double? depensesMensuelles,
    int numSimulations = 500,
    int? seed,
  }) {
    final random = Random(seed);
    final results = <List<double>>[];
    int ruinCount = 0;

    final retirementYear =
        DateTime.now().year + (retirementAgeUser - profile.age);
    final expenses = depensesMensuelles ?? _estimateExpenses(profile);
    final canton =
        profile.canton.isNotEmpty ? profile.canton.toUpperCase() : 'ZH';
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;
    final yearsTo90 = (90 - retirementAgeUser).clamp(0, _projectionYears);

    // ── Conjoint context ────────────────────────────────────
    final hasConjoint = profile.isCouple && profile.conjoint != null;
    final conjoint = profile.conjoint;
    final conjointAge = conjoint?.age;
    // Default conjoint retirement age: 65 (could differ but we simplify)
    const conjointRetirementAge = 65;

    // ── Early retirement: AVS deferred start (LAVS art. 40) ─
    // AVS anticipation only possible from age 63. If retirement < 63,
    // we compute AVS as if drawn at 63 (with 2 years penalty = 13.6%),
    // and only add it to income starting at year (63 - retirementAge).
    final yearsUntilAvsUser = max(0, 63 - retirementAgeUser);
    final effectiveAvsAgeUser = max(retirementAgeUser, 63);

    for (int sim = 0; sim < numSimulations; sim++) {
      final yearlyIncome = <double>[];
      bool simRuined = false;

      // ── Tirage aleatoire pour cette simulation ──────────
      final lppReturn = _normalRandom(random, mean: 0.02, sd: 0.03);
      final libreReturn = _normalRandom(random, mean: 0.04, sd: 0.08);
      final inflationRate =
          _normalRandom(random, mean: 0.012, sd: 0.005).clamp(0.0, 0.05);
      final lifeExpectancy = 82 + random.nextInt(14); // 82-95
      final salaryGrowth =
          _normalRandom(random, mean: 0.01, sd: 0.015).clamp(-0.02, 0.05);
      final avsIndexation =
          _normalRandom(random, mean: 0.01, sd: 0.005).clamp(0.0, 0.03);

      // ── AVS mensuelle utilisateur ─────────────────────────
      final avsUserRaw = AvsCalculator.computeMonthlyRente(
        currentAge: profile.age,
        retirementAge: effectiveAvsAgeUser,
        lacunes: profile.prevoyance.lacunesAVS ?? 0,
        anneesContribuees: profile.prevoyance.anneesContribuees,
        arrivalAge: profile.arrivalAge,
        grossAnnualSalary: profile.revenuBrutAnnuel,
      );

      // ── AVS conjoint ──────────────────────────────────────
      double avsConjointRaw = 0;
      if (hasConjoint && conjointAge != null) {
        avsConjointRaw = AvsCalculator.computeMonthlyRente(
          currentAge: conjointAge,
          retirementAge: conjointRetirementAge,
          lacunes: conjoint!.prevoyance?.lacunesAVS ?? 0,
          anneesContribuees: conjoint.prevoyance?.anneesContribuees,
          arrivalAge: conjoint.arrivalAge,
          grossAnnualSalary: conjoint.revenuBrutAnnuel,
        );
      }

      // ── AVS couple cap (LAVS art. 35) ─────────────────────
      double avsUserMonthly;
      double avsConjointMonthly;
      if (hasConjoint) {
        final couple = AvsCalculator.computeCouple(
          avsUser: avsUserRaw,
          avsConjoint: avsConjointRaw,
          isMarried: isMarried,
        );
        avsUserMonthly = couple.user;
        avsConjointMonthly = couple.conjoint;
      } else {
        avsUserMonthly = avsUserRaw;
        avsConjointMonthly = 0;
      }

      // ── LPP utilisateur : projection simplifiee jusqu'a la retraite ─
      double lppBalance = profile.prevoyance.avoirLppTotal ?? 0;
      final userHasLpp =
          lppBalance > 0 || profile.employmentStatus != 'independant';
      for (int a = profile.age; a < retirementAgeUser && a < 70; a++) {
        lppBalance *= (1 + lppReturn);
        if (userHasLpp) {
          final salary = profile.revenuBrutAnnuel *
              pow(1 + salaryGrowth, (a - profile.age).toDouble());
          final salaireCoord = LppCalculator.computeSalaireCoordonne(salary);
          lppBalance += salaireCoord * getLppBonificationRate(a);
        }
      }

      // ── LPP utilisateur : rente et/ou capital ─────────────
      double lppMonthly;
      double lppCapitalNet = 0;
      final conversionRate = profile.prevoyance.tauxConversion;

      if (lppCapitalPct > 0 && lppBalance > 0) {
        final capitalPortion = lppBalance * lppCapitalPct;
        final rentePortion = lppBalance * (1 - lppCapitalPct);
        lppMonthly = rentePortion * conversionRate / 12;
        final tax = RetirementTaxCalculator.capitalWithdrawalTax(
          capitalBrut: capitalPortion,
          canton: canton,
          isMarried: isMarried,
        );
        lppCapitalNet = capitalPortion - tax;
      } else {
        lppMonthly = lppBalance * conversionRate / 12;
      }

      // ── LPP conjoint : projection simplifiee ──────────────
      double conjointLppMonthly = 0;
      if (hasConjoint && conjointAge != null) {
        double conjLppBalance = conjoint!.prevoyance?.avoirLppTotal ?? 0;
        final conjHasLpp = conjLppBalance > 0 ||
            conjoint.employmentStatus != 'independant';
        final conjSalary = conjoint.revenuBrutAnnuel;
        final conjConvRate = conjoint.prevoyance?.tauxConversion ?? 0.068;

        for (int a = conjointAge; a < conjointRetirementAge && a < 70; a++) {
          conjLppBalance *= (1 + lppReturn);
          if (conjHasLpp && conjSalary > 0) {
            final salary = conjSalary *
                pow(1 + salaryGrowth, (a - conjointAge).toDouble());
            final salaireCoord =
                LppCalculator.computeSalaireCoordonne(salary);
            conjLppBalance += salaireCoord * getLppBonificationRate(a);
          }
        }

        // Conjoint LPP: 100% rente (simplification)
        conjointLppMonthly = conjLppBalance * conjConvRate / 12;
      }

      // ── 3a utilisateur : projection simplifiee ────────────
      double threeABalance = profile.prevoyance.totalEpargne3a;
      final monthly3a = profile.total3aMensuel;
      for (int a = profile.age; a < retirementAgeUser; a++) {
        // Rendement conservateur pour le 3a (borne a 4%)
        threeABalance *= (1 + lppReturn.clamp(0.0, 0.04));
        threeABalance += monthly3a * 12;
      }
      final threeATax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: threeABalance,
        canton: canton,
        isMarried: isMarried,
      );
      final threeANet = threeABalance - threeATax;
      final threeAMonthly =
          threeANet > 0 ? threeANet / _threeADrawdownYears / 12 : 0.0;

      // ── 3a conjoint : projection simplifiee ───────────────
      double conjointThreeAMonthly = 0;
      if (hasConjoint && conjointAge != null) {
        final conjPrev = conjoint!.prevoyance;
        double conj3aBalance = conjPrev?.totalEpargne3a ?? 0;
        if (conj3aBalance > 0) {
          for (int a = conjointAge; a < conjointRetirementAge; a++) {
            conj3aBalance *= (1 + lppReturn.clamp(0.0, 0.04));
            // Conjoint 3a contributions: check canContribute3a
            // (simplified — no monthly contribution data on conjoint)
          }
          final conj3aTax = RetirementTaxCalculator.capitalWithdrawalTax(
            capitalBrut: conj3aBalance,
            canton: canton,
            isMarried: isMarried,
          );
          final conj3aNet = conj3aBalance - conj3aTax;
          conjointThreeAMonthly =
              conj3aNet > 0 ? conj3aNet / _threeADrawdownYears / 12 : 0.0;
        }
      }

      // ── Patrimoine libre : projection simplifiee ───────
      double libreBalance = profile.patrimoine.investissements +
          profile.patrimoine.epargneLiquide;
      final monthlyLibre = profile.totalEpargneLibreMensuel;
      for (int a = profile.age; a < retirementAgeUser; a++) {
        libreBalance *= (1 + libreReturn);
        libreBalance += monthlyLibre * 12;
      }

      // ── Boucle post-retraite annee par annee ───────────
      for (int y = 0; y < _projectionYears; y++) {
        final currentAge = retirementAgeUser + y;

        // AVS indexee chaque annee — seulement apres le delai d'anticipation
        final avsUserThisYear = y >= yearsUntilAvsUser
            ? avsUserMonthly * pow(1 + avsIndexation, y.toDouble())
            : 0.0;
        // Conjoint AVS: starts immediately (conjoint retires at 65)
        final avsConjointThisYear = hasConjoint
            ? avsConjointMonthly * pow(1 + avsIndexation, y.toDouble())
            : 0.0;

        // LPP rente : fixe (pas d'indexation legale en Suisse)
        final lppRenteThisYear = lppMonthly;

        // LPP capital SWR (si strategie capital)
        double lppCapitalMonthly = 0;
        if (lppCapitalPct > 0 && lppCapitalNet > 0) {
          lppCapitalMonthly = lppCapitalNet * _safeWithdrawalRate / 12;
          lppCapitalNet *= (1 + libreReturn - _safeWithdrawalRate);
          if (lppCapitalNet < 0) lppCapitalNet = 0;
        }

        // 3a : versement fixe sur 20 ans, puis 0
        final threeAThisYear = y < _threeADrawdownYears ? threeAMonthly : 0.0;
        final conjThreeAThisYear =
            y < _threeADrawdownYears ? conjointThreeAMonthly : 0.0;

        // Patrimoine libre : SWR 4%
        double libreMonthly = 0;
        if (libreBalance > 0) {
          libreMonthly = libreBalance * _safeWithdrawalRate / 12;
          libreBalance *= (1 + libreReturn - _safeWithdrawalRate);
          if (libreBalance < 0) libreBalance = 0;
        }

        // Si on a depasse l'esperance de vie, on perd les revenus de capital
        // (simplification : seule l'AVS continue pour les heritiers implicites)
        final isAlive = currentAge <= lifeExpectancy;

        final totalMonthly = isAlive
            ? (avsUserThisYear +
                avsConjointThisYear +
                lppRenteThisYear +
                conjointLppMonthly +
                lppCapitalMonthly +
                threeAThisYear +
                conjThreeAThisYear +
                libreMonthly)
            : 0.0;

        yearlyIncome.add(totalMonthly);

        // Ruine : revenu < 50% des depenses indexees, avant 90 ans
        // Bug fix: ne pas compter les simulations ou la personne est decedee
        if (!simRuined && y < yearsTo90 && isAlive) {
          final inflatedExpense =
              expenses * pow(1 + inflationRate, y.toDouble());
          if (totalMonthly < inflatedExpense * 0.5) {
            simRuined = true;
          }
        }
      }

      if (simRuined) ruinCount++;
      results.add(yearlyIncome);
    }

    // ── Calcul des percentiles par annee ─────────────────
    final projection = <MonteCarloPoint>[];
    for (int y = 0; y < _projectionYears; y++) {
      final values = results.map((sim) => sim[y]).toList()..sort();
      projection.add(MonteCarloPoint(
        year: retirementYear + y,
        age: retirementAgeUser + y,
        p10: _percentile(values, 0.10),
        p25: _percentile(values, 0.25),
        p50: _percentile(values, 0.50),
        p75: _percentile(values, 0.75),
        p90: _percentile(values, 0.90),
      ));
    }

    // ── Probabilite de ruine ─────────────────────────────
    final ruinProbability =
        numSimulations > 0 ? ruinCount / numSimulations : 0.0;

    // ── Mediane et extremes au depart de la retraite ─────
    final valuesAtRetirement = results.map((sim) => sim[0]).toList()..sort();

    // ── Alertes contextuelles ────────────────────────────
    final alertes = <String>[];
    if (ruinProbability > 0.30) {
      alertes.add(
        'Probabilite de deficit elevee (>30%). '
        'Envisage d\'augmenter ton epargne ou de repousser ta retraite.',
      );
    }
    if (retirementAgeUser < 63) {
      alertes.add(
        'Retraite anticipee avant 63 ans : aucune rente AVS durant '
        '${63 - retirementAgeUser} an(s). Prevois une epargne-relais.',
      );
    }
    if (ruinProbability > 0.15 && ruinProbability <= 0.30) {
      alertes.add(
        'Risque d\'epuisement modere (${(ruinProbability * 100).round()}%). '
        'Un rachat LPP ou un versement 3a supplementaire pourrait aider.',
      );
    }

    return MonteCarloResult(
      projection: projection,
      medianAt65: _percentile(valuesAtRetirement, 0.50),
      p10At65: _percentile(valuesAtRetirement, 0.10),
      p90At65: _percentile(valuesAtRetirement, 0.90),
      ruinProbability: ruinProbability,
      numSimulations: numSimulations,
      disclaimer: _disclaimer,
      retirementAge: retirementAgeUser,
      sources: _sources,
      alertes: alertes,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  /// Box-Muller transform pour generer une variable normale.
  static double _normalRandom(Random rng, {double mean = 0, double sd = 1}) {
    final u1 = rng.nextDouble();
    final u2 = rng.nextDouble();
    // Eviter log(0) qui donne -infinity
    final safeU1 = u1 < 1e-10 ? 1e-10 : u1;
    final z = sqrt(-2 * log(safeU1)) * cos(2 * pi * u2);
    return mean + sd * z;
  }

  /// Percentile par interpolation lineaire sur une liste triee.
  static double _percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted[0];
    final index = p * (sorted.length - 1);
    final lower = index.floor();
    final upper = index.ceil();
    if (lower == upper) return sorted[lower];
    final fraction = index - lower;
    return sorted[lower] * (1 - fraction) + sorted[upper] * fraction;
  }

  /// Estimation des depenses mensuelles a la retraite.
  static double _estimateExpenses(CoachProfile profile) {
    final householdNet = profile.salaireBrutMensuel * 0.87 +
        (profile.conjoint?.salaireBrutMensuel ?? 0) * 0.87;
    final current = profile.depenses.totalMensuel;
    if (current > 0) {
      return max(current * 0.85, householdNet * 0.70);
    }
    return householdNet > 0 ? householdNet * 0.75 : 5000;
  }
}
