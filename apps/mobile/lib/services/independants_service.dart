import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';

// ────────────────────────────────────────────────────────────
//  INDEPENDANTS SERVICE — Sprint S18 / Indépendants complet
// ────────────────────────────────────────────────────────────
//
// Pure Dart service with 5 calculator methods for self-employed:
//   1. calculateAvsCotisations  — AVS/AI/APG progressive barème
//   2. calculateIjm             — Income loss insurance (IJM)
//   3. calculate3aIndependant   — Pillar 3a ceilings
//   4. calculateDividendeVsSalaire — Dividend vs salary split
//   5. calculateLppVolontaire   — Voluntary LPP
//
// All constants match the backend exactly.
// No banned terms ("garanti", "certain", "assuré", "sans risque").
// ────────────────────────────────────────────────────────────

/// Result of AVS cotisation calculation.
class AvsCotisationResult {
  final double revenuNet;
  final double tauxEffectif;
  final double cotisationAnnuelle;
  final double cotisationMensuelle;
  final double cotisationSalarie; // 5.30% employee share
  final double differenceAnnuelle;
  final String tranchLabel;

  const AvsCotisationResult({
    required this.revenuNet,
    required this.tauxEffectif,
    required this.cotisationAnnuelle,
    required this.cotisationMensuelle,
    required this.cotisationSalarie,
    required this.differenceAnnuelle,
    required this.tranchLabel,
  });
}

/// Result of IJM calculation.
class IjmResult {
  final double revenuMensuel;
  final int age;
  final int delaiCarence;
  final double couverture; // 80% of monthly income
  final double indemniteJournaliere;
  final double primeMensuelle;
  final double primeAnnuelle;
  final double perteCarence; // loss during waiting period
  final double rateFor1000;
  final String ageBandLabel;
  final bool isHighRisk; // age > 50

  const IjmResult({
    required this.revenuMensuel,
    required this.age,
    required this.delaiCarence,
    required this.couverture,
    required this.indemniteJournaliere,
    required this.primeMensuelle,
    required this.primeAnnuelle,
    required this.perteCarence,
    required this.rateFor1000,
    required this.ageBandLabel,
    required this.isHighRisk,
  });
}

/// Result of 3a independant calculation.
class Pillar3aIndepResult {
  final double revenuNet;
  final bool affilieLpp;
  final double plafond; // applicable ceiling
  final double economieFiscale; // plafond * tauxMarginal
  final double plafondSalarie; // 7258 for comparison
  final double economieSalarie; // 7258 * tauxMarginal
  final double avantageSurSalarie; // difference in fiscal savings
  final double tauxMarginal;

  const Pillar3aIndepResult({
    required this.revenuNet,
    required this.affilieLpp,
    required this.plafond,
    required this.economieFiscale,
    required this.plafondSalarie,
    required this.economieSalarie,
    required this.avantageSurSalarie,
    required this.tauxMarginal,
  });
}

/// A single point in the dividende vs salaire sensitivity analysis.
class DividendeSplitPoint {
  final double partSalairePct; // 0-100
  final double chargeSalaire;
  final double chargeDividende;
  final double chargeTotal;

  const DividendeSplitPoint({
    required this.partSalairePct,
    required this.chargeSalaire,
    required this.chargeDividende,
    required this.chargeTotal,
  });
}

/// Result of dividende vs salaire calculation.
class DividendeVsSalaireResult {
  final double benefice;
  final double partSalaire;
  final double partDividende;
  final double chargeSalaire;
  final double chargeDividende;
  final double chargeTotal;
  final double chargeToutSalaire; // 100% salary scenario
  final double economie; // savings from split
  final List<DividendeSplitPoint> sensitivity;
  final double optimalSplitPct;
  final double optimalCharge;
  final bool requalificationRisk; // salary < 60%

  const DividendeVsSalaireResult({
    required this.benefice,
    required this.partSalaire,
    required this.partDividende,
    required this.chargeSalaire,
    required this.chargeDividende,
    required this.chargeTotal,
    required this.chargeToutSalaire,
    required this.economie,
    required this.sensitivity,
    required this.optimalSplitPct,
    required this.optimalCharge,
    required this.requalificationRisk,
  });
}

/// Result of LPP volontaire calculation.
class LppVolontaireResult {
  final double revenuNet;
  final int age;
  final double salaireCoordonne;
  final double tauxBonification;
  final double cotisationAnnuelle;
  final double economieFiscale;
  final double tauxMarginal;
  final double capitalisationAnnuelle; // with employer-equivalent match
  final double projectionSansLpp; // AVS only retirement estimate
  final double projectionAvecLpp; // AVS + LPP retirement estimate
  final String ageBracketLabel;

  const LppVolontaireResult({
    required this.revenuNet,
    required this.age,
    required this.salaireCoordonne,
    required this.tauxBonification,
    required this.cotisationAnnuelle,
    required this.economieFiscale,
    required this.tauxMarginal,
    required this.capitalisationAnnuelle,
    required this.projectionSansLpp,
    required this.projectionAvecLpp,
    required this.ageBracketLabel,
  });
}

/// Service for self-employed calculators.
///
/// All constants match the backend exactly.
class IndependantsService {
  IndependantsService._();

  // ════════════════════════════════════════════════════════════
  //  CONSTANTS
  // ════════════════════════════════════════════════════════════

  /// AVS/AI/APG barème progressif for self-employed.
  /// (lowerBound, upperBound, rate) — find bracket, apply single rate.
  static const List<(double, double, double)> _avsBareme = [
    (0, 10100, 0.05371),
    (10100, 17600, 0.05828),
    (17600, 22200, 0.06542),
    (22200, 27200, 0.07158),
    (27200, 32300, 0.07773),
    (32300, 37800, 0.08386),
    (37800, 43200, 0.09002),
    (43200, 48800, 0.09610),
    (48800, 54300, 0.10222),
    (54300, 60500, 0.10413),
    (60500, double.infinity, 0.10600),
  ];

  /// Cotisation minimale AVS/AI/APG for self-employed — use centralized constant.
  static const double _cotisationMinimale = avsCotisationMinIndependant;

  /// AVS employee share rate (for comparison) — use centralized constant.
  static const double _tauxAvsSalarie = avsCotisationSalarie;

  /// IJM premium rates: {ageMin-ageMax: {delaiCarence: primeFor1000}}.
  static const Map<String, Map<int, double>> _ijmRates = {
    '18-30': {30: 3.50, 60: 2.80, 90: 2.20},
    '31-40': {30: 5.00, 60: 4.00, 90: 3.20},
    '41-50': {30: 8.00, 60: 6.50, 90: 5.20},
    '51-60': {30: 14.00, 60: 11.50, 90: 9.50},
    '61-65': {30: 22.00, 60: 18.00, 90: 15.00},
  };

  /// 3a ceiling for self-employed without LPP: 20% of net income, max 36288.
  static const double _plafond3aGrand = pilier3aPlafondSansLpp;

  /// 3a ceiling for self-employed with LPP (same as salaried).
  static const double _plafond3aPetit = pilier3aPlafondAvecLpp;

  /// LPP coordination deduction (2025).
  static const double _deductionCoordination = lppDeductionCoordination;

  /// LPP minimum coordinated salary.
  static const double _minSalaireCoordonne = lppSalaireCoordMin;

  /// LPP age-based bonification rates (combined employee+employer).
  /// Used for reference and documentation; actual rates are applied
  /// via age-bracket logic in calculateLppVolontaire.
  // ignore: unused_field
  static const Map<String, double> _lppBonificationRates = {
    '25-34': 0.07,
    '35-44': 0.10,
    '45-54': 0.15,
    '55-65': 0.18,
  };

  /// AVS combined employer+employee rate for salary calculations.
  static const double _avsCombinedRate = 0.1250;

  /// LPP conversion rate at retirement — use centralized constant.
  static const double _tauxConversion = lppTauxConversionMin / 100;

  /// LPP maximum coordinated salary (LPP art. 8).
  static const double _maxSalaireCoordonne = 63540;

  /// LPP minimum interest rate (aligned with backend: 1.25%).
  static const double _projectedReturn = 0.0125;

  // ════════════════════════════════════════════════════════════
  //  1. AVS COTISATIONS
  // ════════════════════════════════════════════════════════════

  /// Calculate AVS/AI/APG cotisations for a self-employed worker.
  ///
  /// The barème works as a degressive flat-rate system:
  /// find the bracket where [revenuNet] falls, and apply that single rate
  /// to the full income (NOT progressive tranches).
  static AvsCotisationResult calculateAvsCotisations(double revenuNet) {
    if (revenuNet <= 0) {
      return const AvsCotisationResult(
        revenuNet: 0,
        tauxEffectif: 0,
        cotisationAnnuelle: 0,
        cotisationMensuelle: 0,
        cotisationSalarie: 0,
        differenceAnnuelle: 0,
        tranchLabel: '-',
      );
    }

    // Find the bracket
    double rate = _avsBareme.last.$3; // default to highest
    String tranchLabel = '';
    for (final bracket in _avsBareme) {
      if (revenuNet >= bracket.$1 && revenuNet < bracket.$2) {
        rate = bracket.$3;
        if (bracket.$2 == double.infinity) {
          tranchLabel = 'CHF ${_formatNumber(bracket.$1)}+';
        } else {
          tranchLabel =
              'CHF ${_formatNumber(bracket.$1)} - ${_formatNumber(bracket.$2)}';
        }
        break;
      }
    }
    if (tranchLabel.isEmpty) {
      tranchLabel = 'CHF ${_formatNumber(_avsBareme.last.$1)}+';
    }

    double cotisationAnnuelle = revenuNet * rate;
    // Apply minimum
    if (cotisationAnnuelle < _cotisationMinimale && revenuNet > 0) {
      cotisationAnnuelle = _cotisationMinimale;
    }

    final cotisationSalarie = revenuNet * _tauxAvsSalarie;
    final differenceAnnuelle = cotisationAnnuelle - cotisationSalarie;

    return AvsCotisationResult(
      revenuNet: revenuNet,
      tauxEffectif: (cotisationAnnuelle / revenuNet * 100),
      cotisationAnnuelle: cotisationAnnuelle,
      cotisationMensuelle: cotisationAnnuelle / 12,
      cotisationSalarie: cotisationSalarie,
      differenceAnnuelle: differenceAnnuelle,
      tranchLabel: tranchLabel,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  2. IJM (INCOME LOSS INSURANCE)
  // ════════════════════════════════════════════════════════════

  /// Calculate IJM (indemnité journalière maladie) for self-employed.
  ///
  /// Coverage: 80% of monthly income.
  /// Premium depends on age band and waiting period (délai de carence).
  static IjmResult calculateIjm(
    double revenuMensuel,
    int age,
    int delaiCarence,
  ) {
    if (revenuMensuel <= 0 || age < 18 || age > 65) {
      return IjmResult(
        revenuMensuel: revenuMensuel,
        age: age,
        delaiCarence: delaiCarence,
        couverture: 0,
        indemniteJournaliere: 0,
        primeMensuelle: 0,
        primeAnnuelle: 0,
        perteCarence: 0,
        rateFor1000: 0,
        ageBandLabel: '-',
        isHighRisk: age > 50,
      );
    }

    // Find age band
    String ageBandLabel = '';
    Map<int, double> bandRates = {};
    if (age <= 30) {
      ageBandLabel = '18-30 ans';
      bandRates = _ijmRates['18-30']!;
    } else if (age <= 40) {
      ageBandLabel = '31-40 ans';
      bandRates = _ijmRates['31-40']!;
    } else if (age <= 50) {
      ageBandLabel = '41-50 ans';
      bandRates = _ijmRates['41-50']!;
    } else if (age <= 60) {
      ageBandLabel = '51-60 ans';
      bandRates = _ijmRates['51-60']!;
    } else {
      ageBandLabel = '61-65 ans';
      bandRates = _ijmRates['61-65']!;
    }

    // Ensure valid délai de carence
    final validDelai =
        [30, 60, 90].contains(delaiCarence) ? delaiCarence : 30;

    final rateFor1000 = bandRates[validDelai] ?? bandRates[30]!;

    // Coverage: 80% of monthly income
    // Daily rate uses 21.75 working days/month (aligned with backend)
    final couverture = revenuMensuel * 0.80;
    final revenuJournalier = revenuMensuel / 21.75;
    final indemniteJournaliere = revenuJournalier * 0.80;

    // Premium: based on 80% insured amount (aligned with backend)
    final revenuAssureMensuel = revenuMensuel * 0.80;
    final primeMensuelle = (revenuAssureMensuel / 1000) * rateFor1000;
    final primeAnnuelle = primeMensuelle * 12;

    // Loss during waiting period = actual daily income * days (aligned with backend)
    final perteCarence = revenuJournalier * validDelai;

    return IjmResult(
      revenuMensuel: revenuMensuel,
      age: age,
      delaiCarence: validDelai,
      couverture: couverture,
      indemniteJournaliere: indemniteJournaliere,
      primeMensuelle: primeMensuelle,
      primeAnnuelle: primeAnnuelle,
      perteCarence: perteCarence,
      rateFor1000: rateFor1000,
      ageBandLabel: ageBandLabel,
      isHighRisk: age > 50,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  3. PILLAR 3A INDEPENDANT
  // ════════════════════════════════════════════════════════════

  /// Calculate 3a ceiling and fiscal savings for self-employed.
  ///
  /// Without LPP: plafond = min(revenuNet * 0.20, 36288).
  /// With LPP: plafond = 7258.
  static Pillar3aIndepResult calculate3aIndependant(
    double revenuNet,
    bool affilieLpp,
    double tauxMarginal,
  ) {
    const plafondSalarie = _plafond3aPetit;

    double plafond;
    if (affilieLpp) {
      plafond = _plafond3aPetit;
    } else {
      plafond = min(revenuNet * 0.20, _plafond3aGrand);
    }
    // Ensure non-negative
    plafond = max(plafond, 0);

    final economieFiscale = plafond * tauxMarginal;
    final economieSalarie = plafondSalarie * tauxMarginal;
    final avantageSurSalarie = economieFiscale - economieSalarie;

    return Pillar3aIndepResult(
      revenuNet: revenuNet,
      affilieLpp: affilieLpp,
      plafond: plafond,
      economieFiscale: economieFiscale,
      plafondSalarie: plafondSalarie,
      economieSalarie: economieSalarie,
      avantageSurSalarie: max(avantageSurSalarie, 0),
      tauxMarginal: tauxMarginal,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  4. DIVIDENDE VS SALAIRE
  // ════════════════════════════════════════════════════════════

  /// Calculate the optimal salary vs dividend split for a SA/Sàrl.
  ///
  /// Salary portion: full income tax + AVS charges (~12.5% employer+employee).
  /// Dividend portion: 50% taxation (qualifying participation), no AVS.
  /// Generates sensitivity data: charge vs split ratio (0% to 100%, step 10%).
  static DividendeVsSalaireResult calculateDividendeVsSalaire(
    double benefice,
    double partSalairePct,
    double tauxMarginal,
  ) {
    if (benefice <= 0) {
      return const DividendeVsSalaireResult(
        benefice: 0,
        partSalaire: 0,
        partDividende: 0,
        chargeSalaire: 0,
        chargeDividende: 0,
        chargeTotal: 0,
        chargeToutSalaire: 0,
        economie: 0,
        sensitivity: [],
        optimalSplitPct: 60,
        optimalCharge: 0,
        requalificationRisk: false,
      );
    }

    // Compute the current split
    final partSalaire = benefice * (partSalairePct / 100);
    final partDividende = benefice - partSalaire;

    final chargeSalaire = _computeSalaryCharge(partSalaire, tauxMarginal);
    final chargeDividende =
        _computeDividendCharge(partDividende, tauxMarginal);
    final chargeTotal = chargeSalaire + chargeDividende;

    // 100% salary scenario for comparison
    final chargeToutSalaire =
        _computeSalaryCharge(benefice, tauxMarginal);

    // Generate sensitivity data (0% to 100%, step 10%)
    final sensitivity = <DividendeSplitPoint>[];
    double optimalCharge = double.infinity;
    double optimalSplitPct = 60;

    for (int pct = 0; pct <= 100; pct += 10) {
      final sal = benefice * (pct / 100);
      final div = benefice - sal;
      final cs = _computeSalaryCharge(sal, tauxMarginal);
      final cd = _computeDividendCharge(div, tauxMarginal);
      final total = cs + cd;
      sensitivity.add(DividendeSplitPoint(
        partSalairePct: pct.toDouble(),
        chargeSalaire: cs,
        chargeDividende: cd,
        chargeTotal: total,
      ));
      if (total < optimalCharge) {
        optimalCharge = total;
        optimalSplitPct = pct.toDouble();
      }
    }

    // Economie = savings of optimal split vs all-salary (aligned with backend)
    final economie = chargeToutSalaire - optimalCharge;
    final requalificationRisk = partSalairePct < 60;

    return DividendeVsSalaireResult(
      benefice: benefice,
      partSalaire: partSalaire,
      partDividende: partDividende,
      chargeSalaire: chargeSalaire,
      chargeDividende: chargeDividende,
      chargeTotal: chargeTotal,
      chargeToutSalaire: chargeToutSalaire,
      economie: max(economie, 0),
      sensitivity: sensitivity,
      optimalSplitPct: optimalSplitPct,
      optimalCharge: optimalCharge,
      requalificationRisk: requalificationRisk,
    );
  }

  /// Compute total charge on salary portion.
  /// Full income tax + AVS combined (~12.5%).
  static double _computeSalaryCharge(double salary, double tauxMarginal) {
    if (salary <= 0) return 0;
    final impot = salary * tauxMarginal;
    final avs = salary * _avsCombinedRate;
    return impot + avs;
  }

  /// Compute total charge on dividend portion.
  /// 50% taxation (qualifying participation), no AVS.
  static double _computeDividendCharge(
      double dividend, double tauxMarginal) {
    if (dividend <= 0) return 0;
    // Only 50% is taxable (participation qualifiante)
    final impot = dividend * 0.50 * tauxMarginal;
    return impot;
  }

  // ════════════════════════════════════════════════════════════
  //  5. LPP VOLONTAIRE
  // ════════════════════════════════════════════════════════════

  /// Calculate voluntary LPP for self-employed.
  ///
  /// Salaire coordonné = max(revenuNet - 26460, 0), min for calc = 3780.
  /// Age brackets: 25-34=7%, 35-44=10%, 45-54=15%, 55-65=18%.
  static LppVolontaireResult calculateLppVolontaire(
    double revenuNet,
    int age,
    double tauxMarginal,
  ) {
    // Salaire coordonné (aligned with backend: LPP art. 8)
    // Income <= deduction => minimum coordinated salary (3780)
    double salaireCoordonne;
    if (revenuNet <= _deductionCoordination) {
      salaireCoordonne = _minSalaireCoordonne;
    } else {
      salaireCoordonne = revenuNet - _deductionCoordination;
      salaireCoordonne = max(salaireCoordonne, _minSalaireCoordonne);
      salaireCoordonne = min(salaireCoordonne, _maxSalaireCoordonne);
    }

    // Age bracket — use centralized getLppBonificationRate()
    final tauxBonification = getLppBonificationRate(age);
    String ageBracketLabel = '';
    if (age >= 55) {
      ageBracketLabel = '55-65 ans';
    } else if (age >= 45) {
      ageBracketLabel = '45-54 ans';
    } else if (age >= 35) {
      ageBracketLabel = '35-44 ans';
    } else if (age >= 25) {
      ageBracketLabel = '25-34 ans';
    } else {
      ageBracketLabel = 'Moins de 25 ans';
    }

    final cotisationAnnuelle = salaireCoordonne * tauxBonification;
    final economieFiscale = cotisationAnnuelle * tauxMarginal;

    // For self-employed, they pay both employee + employer share
    final capitalisationAnnuelle = cotisationAnnuelle;

    // Retirement projection
    final anneesRestantes = max(65 - age, 0);

    // Without LPP: AVS only (LAVS art. 34, max rente = 2520 × 12)
    const renteAvsMax = avsRenteMaxMensuelle * 12; // 30240 CHF
    final projectionSansLpp = renteAvsMax;

    // With LPP: project capital at retirement
    double capitalLpp = 0;
    for (int i = 0; i < anneesRestantes; i++) {
      final ageYear = age + i;
      double taux;
      if (ageYear >= 55) {
        taux = 0.18;
      } else if (ageYear >= 45) {
        taux = 0.15;
      } else if (ageYear >= 35) {
        taux = 0.10;
      } else if (ageYear >= 25) {
        taux = 0.07;
      } else {
        taux = 0;
      }
      capitalLpp =
          capitalLpp * (1 + _projectedReturn) + salaireCoordonne * taux;
    }
    final renteLpp = capitalLpp * _tauxConversion;
    final projectionAvecLpp = renteAvsMax + renteLpp;

    return LppVolontaireResult(
      revenuNet: revenuNet,
      age: age,
      salaireCoordonne: salaireCoordonne,
      tauxBonification: tauxBonification,
      cotisationAnnuelle: cotisationAnnuelle,
      economieFiscale: economieFiscale,
      tauxMarginal: tauxMarginal,
      capitalisationAnnuelle: capitalisationAnnuelle,
      projectionSansLpp: projectionSansLpp,
      projectionAvecLpp: projectionAvecLpp,
      ageBracketLabel: ageBracketLabel,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  /// Format a number with Swiss apostrophe separators.
  static String _formatNumber(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return '${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }

  /// Format CHF with Swiss apostrophe.
  static String formatChf(double value) {
    return 'CHF\u00A0${_formatNumber(value)}';
  }
}
