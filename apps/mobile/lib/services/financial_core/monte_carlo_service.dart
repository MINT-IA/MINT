import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/housing_cost_calculator.dart';
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
  static const double _3aDrawdownYears = 20.0;

  // ════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ════════════════════════════════════════════════════════════

  /// Lance une simulation Monte Carlo de retraite.
  ///
  /// [profile] : profil financier complet de l'utilisateur.
  /// [s] : localized strings (pass `S.of(context)!` from the caller).
  /// [retirementAgeUser] : age de depart a la retraite (defaut 65).
  /// [lppCapitalPct] : fraction du LPP retiree en capital (0.0 = 100% rente).
  /// [depensesMensuelles] : depenses mensuelles estimees a la retraite.
  /// [numSimulations] : nombre de simulations (defaut 500).
  /// [seed] : graine pour le generateur aleatoire (tests reproductibles).
  static MonteCarloResult simulate({
    required CoachProfile profile,
    required S s,
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
    final expenses = depensesMensuelles ??
        _estimateExpenses(profile, retirementAge: retirementAgeUser);
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
      // Sim-level draws (stable over lifetime — reasonable simplification):
      final inflationRate =
          _normalRandom(random, mean: 0.012, sd: 0.005).clamp(0.0, 0.05);
      final lifeExpectancy = 82 + random.nextInt(14); // 82-95
      final avsIndexation =
          _normalRandom(random, mean: 0.01, sd: 0.005).clamp(0.0, 0.03);
      // Annual draws for market-sensitive returns (captures sequence-of-returns risk):
      // lppReturn, libreReturn, salaryGrowth are drawn per-year inside loops below.

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
      // Inclut bonifications annuelles + rachats LPP planifies (LPP art. 79b)
      double lppBalance = profile.prevoyance.avoirLppTotal ?? 0;
      final userHasLpp =
          lppBalance > 0 || profile.employmentStatus != 'independant';
      final annualBuyback = profile.totalLppBuybackMensuel * 12;
      final maxBuyback = profile.prevoyance.lacuneRachatRestante;
      double cumulBuyback = 0;
      for (int a = profile.age; a < retirementAgeUser && a < 70; a++) {
        final lppReturnYear =
            _normalRandom(random, mean: 0.02, sd: 0.03);
        final salaryGrowthYear =
            _normalRandom(random, mean: 0.01, sd: 0.015).clamp(-0.02, 0.05);
        lppBalance *= (1 + lppReturnYear);
        if (userHasLpp) {
          final salary = profile.revenuBrutAnnuel *
              pow(1 + salaryGrowthYear, (a - profile.age).toDouble());
          final salaireCoord = LppCalculator.computeSalaireCoordonne(salary);
          lppBalance += salaireCoord * getLppBonificationRate(a);
        }
        // Rachats LPP planifies, plafonnes a la lacune restante
        if (annualBuyback > 0 && cumulBuyback < maxBuyback) {
          final buybackThisYear =
              annualBuyback.clamp(0.0, maxBuyback - cumulBuyback);
          lppBalance += buybackThisYear;
          cumulBuyback += buybackThisYear;
        }
      }

      // ── LPP utilisateur : rente et/ou capital ─────────────
      double lppMonthly;
      double lppCapitalNet = 0;
      // Adjusted conversion rate for early retirement (LPP art. 13 al. 2)
      final conversionRate = LppCalculator.adjustedConversionRate(
        baseRate: profile.prevoyance.tauxConversion,
        retirementAge: retirementAgeUser,
      );

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

      // ── LPP conjoint : projection avec rachats planifies ──
      double conjointLppMonthly = 0;
      if (hasConjoint && conjointAge != null) {
        double conjLppBalance = conjoint!.prevoyance?.avoirLppTotal ?? 0;
        final conjHasLpp = conjLppBalance > 0 ||
            conjoint.employmentStatus != 'independant';
        final conjSalary = conjoint.revenuBrutAnnuel;
        // Adjusted conversion rate for early retirement (LPP art. 13 al. 2)
        final conjConvRate = LppCalculator.adjustedConversionRate(
          baseRate: conjoint.prevoyance?.tauxConversion ?? lppTauxConversionMinDecimal,
          retirementAge: conjointRetirementAge,
        );
        // Rachats LPP conjoint: contributions dont l'id/label contient
        // le prenom du conjoint (ex: 'lpp_buyback_lauren').
        // Guard: si firstName est null/vide, on ne peut pas matcher → 0.
        final conjName = conjoint.firstName?.toLowerCase() ?? '';
        final double conjAnnualBuyback;
        if (conjName.isEmpty) {
          conjAnnualBuyback = 0;
        } else {
          conjAnnualBuyback = profile.plannedContributions
              .where((c) =>
                  c.category == 'lpp_buyback' &&
                  (c.id.toLowerCase().contains(conjName) ||
                      c.label.toLowerCase().contains(conjName)))
              .fold(0.0, (sum, c) => sum + c.amount) * 12;
        }
        final conjMaxBuyback =
            conjoint.prevoyance?.lacuneRachatRestante ?? 0;
        double conjCumulBuyback = 0;

        for (int a = conjointAge; a < conjointRetirementAge && a < 70; a++) {
          final lppReturnYear =
              _normalRandom(random, mean: 0.02, sd: 0.03);
          final salaryGrowthYear =
              _normalRandom(random, mean: 0.01, sd: 0.015).clamp(-0.02, 0.05);
          conjLppBalance *= (1 + lppReturnYear);
          if (conjHasLpp && conjSalary > 0) {
            final salary = conjSalary *
                pow(1 + salaryGrowthYear, (a - conjointAge).toDouble());
            final salaireCoord =
                LppCalculator.computeSalaireCoordonne(salary);
            conjLppBalance += salaireCoord * getLppBonificationRate(a);
          }
          // Rachats LPP conjoint, plafonnes a la lacune
          if (conjAnnualBuyback > 0 && conjCumulBuyback < conjMaxBuyback) {
            final buyback =
                conjAnnualBuyback.clamp(0.0, conjMaxBuyback - conjCumulBuyback);
            conjLppBalance += buyback;
            conjCumulBuyback += buyback;
          }
        }

        // Conjoint LPP: 100% rente (simplification)
        conjointLppMonthly = conjLppBalance * conjConvRate / 12;
      }

      // ── 3a utilisateur : projection simplifiee ────────────
      // Utilise le rendement moyen pondere des comptes 3a (ex: VIAC 5%, cash 2%)
      // avec un bruit stochastique proportionnel.
      double threeABalance = profile.prevoyance.totalEpargne3a;
      final monthly3a = profile.total3aMensuel;
      final baseReturn3a = profile.prevoyance.rendementMoyen3a;
      final threeAReturn =
          _normalRandom(random, mean: baseReturn3a, sd: baseReturn3a * 0.5)
              .clamp(0.0, 0.10);
      for (int a = profile.age; a < retirementAgeUser; a++) {
        threeABalance *= (1 + threeAReturn);
        threeABalance += monthly3a * 12;
      }
      final threeATax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: threeABalance,
        canton: canton,
        isMarried: isMarried,
      );
      final threeANet = threeABalance - threeATax;
      final threeAMonthly =
          threeANet > 0 ? threeANet / _3aDrawdownYears / 12 : 0.0;

      // ── 3a conjoint : projection avec rendement propre + contributions ─
      // Skip if conjoint cannot contribute to 3a (e.g. FATCA US persons)
      double conjointThreeAMonthly = 0;
      final conjointCan3a =
          conjoint?.prevoyance?.canContribute3a ?? true;
      if (hasConjoint && conjointAge != null && conjointCan3a) {
        final conjPrev = conjoint!.prevoyance;
        double conj3aBalance = conjPrev?.totalEpargne3a ?? 0;
        // Rendement propre du conjoint (ex: FATCA → cash 2%, VIAC → 5%)
        final conjBase3aReturn = conjPrev?.rendementMoyen3a ?? 0.02;
        final conj3aReturn = _normalRandom(
          random,
          mean: conjBase3aReturn,
          sd: conjBase3aReturn * 0.5,
        ).clamp(0.0, 0.10);
        // Contributions 3a mensuelles du conjoint: depuis plannedContributions
        // dont l'id/label contient le prenom du conjoint (ex: '3a_lauren').
        // Guard: si firstName est null/vide, on ne peut pas matcher → 0.
        final conjNameLower = conjoint.firstName?.toLowerCase() ?? '';
        final double conj3aMonthlyContrib;
        if (conjNameLower.isEmpty) {
          conj3aMonthlyContrib = 0;
        } else {
          conj3aMonthlyContrib = profile.plannedContributions
              .where((c) =>
                  c.category == '3a' &&
                  (c.id.toLowerCase().contains(conjNameLower) ||
                      c.label.toLowerCase().contains(conjNameLower)))
              .fold(0.0, (sum, c) => sum + c.amount);
        }
        if (conj3aBalance > 0 || conj3aMonthlyContrib > 0) {
          for (int a = conjointAge; a < conjointRetirementAge; a++) {
            conj3aBalance *= (1 + conj3aReturn);
            conj3aBalance += conj3aMonthlyContrib * 12;
          }
          final conj3aTax = RetirementTaxCalculator.capitalWithdrawalTax(
            capitalBrut: conj3aBalance,
            canton: canton,
            isMarried: isMarried,
          );
          final conj3aNet = conj3aBalance - conj3aTax;
          conjointThreeAMonthly =
              conj3aNet > 0 ? conj3aNet / _3aDrawdownYears / 12 : 0.0;
        }
      }

      // ── Patrimoine libre : projection simplifiee ───────
      double libreBalance = profile.patrimoine.investissements +
          profile.patrimoine.epargneLiquide;
      final monthlyLibre = profile.totalEpargneLibreMensuel;
      for (int a = profile.age; a < retirementAgeUser; a++) {
        final libreReturnYear =
            _normalRandom(random, mean: 0.04, sd: 0.08);
        libreBalance *= (1 + libreReturnYear);
        libreBalance += monthlyLibre * 12;
      }

      // ── Boucle post-retraite annee par annee ───────────
      for (int y = 0; y < _projectionYears; y++) {
        final currentAge = retirementAgeUser + y;

        // Annual market return draw (sequence-of-returns risk)
        final libreReturnYear =
            _normalRandom(random, mean: 0.04, sd: 0.08);

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
          lppCapitalNet *= (1 + libreReturnYear - _safeWithdrawalRate);
          if (lppCapitalNet < 0) lppCapitalNet = 0;
        }

        // 3a : versement fixe sur 20 ans, puis 0
        final threeAThisYear = y < _3aDrawdownYears ? threeAMonthly : 0.0;
        final conjThreeAThisYear =
            y < _3aDrawdownYears ? conjointThreeAMonthly : 0.0;

        // Patrimoine libre : SWR 4%
        double libreMonthly = 0;
        if (libreBalance > 0) {
          libreMonthly = libreBalance * _safeWithdrawalRate / 12;
          libreBalance *= (1 + libreReturnYear - _safeWithdrawalRate);
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
      alertes.add(s.monteCarloAlerteRuinHigh);
    }
    if (retirementAgeUser < 63) {
      alertes.add(s.monteCarloAlerteEarlyRetirement(63 - retirementAgeUser));
    }
    if (ruinProbability > 0.15 && ruinProbability <= 0.30) {
      alertes.add(s.monteCarloAlerteRuinModerate((ruinProbability * 100).round()));
    }

    return MonteCarloResult(
      projection: projection,
      medianAt65: _percentile(valuesAtRetirement, 0.50),
      p10At65: _percentile(valuesAtRetirement, 0.10),
      p90At65: _percentile(valuesAtRetirement, 0.90),
      ruinProbability: ruinProbability,
      numSimulations: numSimulations,
      disclaimer: s.monteCarloServiceDisclaimer,
      retirementAge: retirementAgeUser,
      sources: [
        s.monteCarloSourceLpp,
        s.monteCarloSourceLavs,
        s.monteCarloSourceLifd,
        s.monteCarloSourceOpp3,
      ],
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
  /// Delegates to HousingCostCalculator (single source of truth).
  static double _estimateExpenses(
    CoachProfile profile, {
    int? retirementAge,
  }) {
    return HousingCostCalculator.estimateRetirementExpenses(
      salaireBrutMensuel: profile.salaireBrutMensuel,
      conjointSalaireBrutMensuel:
          profile.conjoint?.salaireBrutMensuel ?? 0,
      currentExpenses: profile.depenses.totalMensuel,
      housingStatus: profile.housingStatus,
      canton: profile.canton.isNotEmpty
          ? profile.canton.toUpperCase()
          : 'ZH',
      currentAge: profile.age,
      targetRetirementAge:
          retirementAge ?? profile.targetRetirementAge ?? 65,
      propertyMarketValue: profile.patrimoine.propertyMarketValue,
      mortgageBalance: profile.patrimoine.mortgageBalance,
      mortgageRate: profile.patrimoine.mortgageRate,
      monthlyRent: profile.patrimoine.monthlyRent,
    );
  }
}
