import 'dart:math' show max;
import 'package:mint_mobile/services/financial_core/income_tax_model_v2.dart';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/fiscal_service.dart';

// ALL tax calculations MUST use RetirementTaxCalculator from financial_core.
// See ADR-20260223-unified-financial-engine.md
// Do NOT create local _calculateTax() or similar methods.

/// Decomposition du revenu net — remplace * 0.87.
///
/// Two levels of "net":
/// - [netPayslip] = brut - charges sociales - LPP employe (what arrives on the payslip)
/// - [disposableIncome] = netPayslip - impot sur le revenu (what's left to live on)
///
/// ZERO hardcoded values. All constants come from:
/// - social_insurance.dart (cotisationsSalarieTotal, getLppBonificationRate, lppDeductionCoordination)
/// - fiscal_service.dart (estimateTax)
class NetIncomeBreakdown {
  final double grossSalary;
  final double socialCharges;
  final double lppEmployee;
  final double incomeTaxEstimate;
  final String canton;
  final int age;

  const NetIncomeBreakdown({
    required this.grossSalary,
    required this.socialCharges,
    required this.lppEmployee,
    required this.incomeTaxEstimate,
    required this.canton,
    required this.age,
  });

  /// Salaire net (fiche de paie) = brut - charges sociales - LPP employe.
  double get netPayslip => grossSalary - socialCharges - lppEmployee;

  /// Revenu disponible = net fiche de paie - impot sur le revenu.
  double get disposableIncome => netPayslip - incomeTaxEstimate;

  /// Ratio net/brut (replaces 0.87).
  double get netRatio => grossSalary > 0 ? netPayslip / grossSalary : 0;

  /// Ratio disponible/brut.
  double get disposableRatio =>
      grossSalary > 0 ? disposableIncome / grossSalary : 0;

  /// Monthly net payslip (convenience for the many monthly callers).
  double get monthlyNetPayslip => netPayslip / 12;

  /// Factory: compute dynamically from gross, canton, age.
  ///
  /// Formulas:
  /// - socialCharges = brut * cotisationsSalarieTotal (6.4%)
  /// - salaireCoord = clamp(brut - lppDeductionCoordination, lppSalaireCoordMin, lppSalaireCoordMax)
  /// - lppEmployee = salaireCoord * getLppBonificationRate(age) / 2
  ///   (LPP art. 66: employeur paie min 50%, employe ~50%)
  /// - incomeTax = FiscalService.estimateTax(brut, canton).chargeTotale
  factory NetIncomeBreakdown.compute({
    required double grossSalary,
    required String canton,
    required int age,
    String etatCivil = 'celibataire',
    int nombreEnfants = 0,
    // FIX-101: Cross-border workers use withholding tax (impôt à la source),
    // which is typically 10-20% lower than ordinary taxation.
    bool isCrossBorder = false,
  }) {
    if (grossSalary <= 0) {
      return NetIncomeBreakdown(
        grossSalary: 0,
        socialCharges: 0,
        lppEmployee: 0,
        incomeTaxEstimate: 0,
        canton: canton,
        age: age,
      );
    }

    // 1. Charges sociales (AVS/AI/APG combined + AC) — hors LPP
    final socialCharges = grossSalary *
        (reg('avs.contribution_rate_employee', avsCotisationSalarie) +
            acCotisationSalarie);

    // 2. LPP employe (~50% de la bonification totale sur salaire coordonne)
    double lppEmployee = 0;
    if (grossSalary >= reg('lpp.entry_threshold', lppSeuilEntree) &&
        age >= 25 &&
        age <=
            reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble())
                .toInt()) {
      final salaireCoord = (grossSalary -
              reg('lpp.coordination_deduction', lppDeductionCoordination))
          .clamp(reg('lpp.min_coordinated_salary', lppSalaireCoordMin),
              reg('lpp.max_coordinated_salary', lppSalaireCoordMax));
      final totalBonif = getLppBonificationRate(age);
      lppEmployee =
          salaireCoord * totalBonif / 2; // ~50% part employe (LPP art. 66)
    }

    // 3. Impot sur le revenu
    double incomeTax;
    if (isCrossBorder) {
      // FIX-101: Cross-border workers → impôt à la source (withholding tax).
      // Simplified: cantonal withholding rate is typically ~4.5-10% of gross.
      // Exact rates depend on canton + family situation + bilateral treaty.
      // Educational estimate only — source: Administration fédérale des contributions.
      const baseWithholdingRates = {
        'GE': 0.145,
        'VD': 0.135,
        'VS': 0.105,
        'NE': 0.125,
        'JU': 0.115,
        'FR': 0.120,
        'BS': 0.130,
        'BL': 0.125,
        'AG': 0.110,
        'ZH': 0.115,
        'TI': 0.100,
        'SG': 0.105,
        'TG': 0.100,
        'GR': 0.095,
      };
      final baseRate = baseWithholdingRates[canton.toUpperCase()] ?? 0.12;
      // Family adjustment: married -20%, per child -5%
      final familyFactor = (etatCivil == 'marie' ? 0.80 : 1.0) -
          (nombreEnfants * 0.05).clamp(0.0, 0.20);
      incomeTax = grossSalary * baseRate * familyFactor;
    } else {
      // Ordinary taxation (via FiscalService, 26 cantons)
      final taxResult = FiscalService.estimateTax(
        revenuBrut: grossSalary,
        canton: canton,
        etatCivil: etatCivil,
        nombreEnfants: nombreEnfants,
      );
      incomeTax = (taxResult['chargeTotale'] as double?) ?? 0;
    }

    return NetIncomeBreakdown(
      grossSalary: grossSalary,
      socialCharges: socialCharges,
      lppEmployee: lppEmployee,
      incomeTaxEstimate: incomeTax,
      canton: canton,
      age: age,
    );
  }

  /// Estimate brut from net payslip using Newton-Raphson iteration.
  ///
  /// Iterates over [NetIncomeBreakdown.compute] to find the gross salary
  /// that produces the target net payslip. Converges in 3-5 iterations
  /// to within ±1 CHF accuracy.
  ///
  /// Much more accurate than the old linear approximation because it
  /// correctly accounts for the LPP coordination deduction (26'460 CHF)
  /// and the coordinated salary clamp (3'780–64'260 CHF).
  static double estimateBrutFromNet(
    double netAnnual, {
    int age = 45,
    String canton = 'ZH',
    String etatCivil = 'celibataire',
    int nombreEnfants = 0,
    int maxIterations = 10,
    double tolerance = 1.0,
  }) {
    if (netAnnual <= 0) return 0;

    // Initial guess using linear approximation
    final lppRate = getLppBonificationRate(age);
    final approxDeductionRate = cotisationsSalarieTotal + lppRate / 2;
    double guess = netAnnual / max(0.5, 1 - approxDeductionRate);

    for (int i = 0; i < maxIterations; i++) {
      final breakdown = NetIncomeBreakdown.compute(
        grossSalary: guess,
        canton: canton,
        age: age,
        etatCivil: etatCivil,
        nombreEnfants: nombreEnfants,
      );
      final error = breakdown.netPayslip - netAnnual;
      if (error.abs() < tolerance) break;

      // Numerical derivative: d(netPayslip)/d(gross) ≈ Δnet/Δgross
      const delta = 100.0;
      final breakdownPlus = NetIncomeBreakdown.compute(
        grossSalary: guess + delta,
        canton: canton,
        age: age,
        etatCivil: etatCivil,
        nombreEnfants: nombreEnfants,
      );
      final derivative =
          (breakdownPlus.netPayslip - breakdown.netPayslip) / delta;
      if (derivative.abs() < 0.01) break; // Safeguard against division by ~0

      guess -= error / derivative;
      if (guess < 0) guess = netAnnual; // Reset if diverged
    }

    return guess;
  }

  Map<String, dynamic> toJson() => {
        'grossSalary': grossSalary,
        'socialCharges': socialCharges,
        'lppEmployee': lppEmployee,
        'incomeTaxEstimate': incomeTaxEstimate,
        'netPayslip': netPayslip,
        'disposableIncome': disposableIncome,
        'netRatio': netRatio,
        'canton': canton,
        'age': age,
      };
}

enum Pillar3aTaxImpactConfidence { unavailable, estimated, actualRate }

class Pillar3aTaxImpactEstimate {
  final double annualCeiling;
  final double proRatedCeiling;
  final double deductibleContribution;
  final double marginalRate;
  final double estimatedTaxSaving;
  final Pillar3aTaxImpactConfidence confidence;

  const Pillar3aTaxImpactEstimate({
    required this.annualCeiling,
    required this.proRatedCeiling,
    required this.deductibleContribution,
    required this.marginalRate,
    required this.estimatedTaxSaving,
    required this.confidence,
  });

  static const unavailable = Pillar3aTaxImpactEstimate(
    annualCeiling: 0,
    proRatedCeiling: 0,
    deductibleContribution: 0,
    marginalRate: 0,
    estimatedTaxSaving: 0,
    confidence: Pillar3aTaxImpactConfidence.unavailable,
  );
}

/// Retirement tax calculator — pure static functions.
///
/// Legal basis: LIFD art. 22 (rente taxation), LIFD art. 38 (capital withdrawal).
/// All computations are deterministic and stateless.
class RetirementTaxCalculator {
  RetirementTaxCalculator._();

  /// Disclaimer: LPP rente is taxable income (LIFD art. 22).
  ///
  /// Capital withdrawal is taxed separately at withdrawal (LIFD art. 38).
  /// SWR drawdown from withdrawn capital is consumption of own patrimony —
  /// NOT taxable income. Never double-tax capital.
  static const String renteLppTaxDisclaimer =
      'La rente LPP est imposee comme revenu (LIFD art. 22). '
      'Consulte un·e specialiste fiscal·e pour une estimation personnalisee.';

  /// Progressive capital withdrawal tax (LIFD art. 38).
  ///
  /// Brackets: 0-100k (1.0×), 100k-200k (1.15×), 200k-500k (1.30×),
  /// 500k-1M (1.50×), 1M+ (1.70×).
  /// Married couples get ~15% discount per cantonal splitting rules.
  static double capitalWithdrawalTax({
    required double capitalBrut,
    required String canton,
    bool isMarried = false,
  }) {
    if (capitalBrut <= 0) return 0;
    // Beads MINT_nosync-2i2 PR B : délégation au modèle v2 (IFD art. 38
    // exacte + interpolation sur 130 points ESTV officiels — l'ancien
    // « taux de base x multiplicateurs par tranche » approximait à ±40%
    // sur certains cantons). resolveCanton conservé (Wave 7 C1 : canton
    // invalide -> warning debug + repli ZH traçable). Le point de bascule
    // est ICI : les 11 consommateurs suivent automatiquement.
    final cantonCode = resolveCanton(canton).code;
    return estimateCapitalWithdrawalTaxV2(
      capitalBrut,
      cantonCode,
      isMarried: isMarried,
    );
  }

  /// Progressive tax on a given amount (LIFD art. 38).
  ///
  /// Brackets: 0-100k (1.0×), 100k-200k (1.15×), 200k-500k (1.30×),
  /// 500k-1M (1.50×), 1M+ (1.70×).
  static double progressiveTax(double montant, double baseRate) {
    if (montant <= 0) return 0.0;
    const brackets = [
      [0, 100000, 1.0],
      [100000, 200000, 1.15],
      [200000, 500000, 1.30],
      [500000, 1000000, 1.50],
    ];
    const lastMultiplier = 1.70;

    double totalTax = 0;
    double remaining = montant;
    for (final bracket in brackets) {
      final tranche = bracket[1] - bracket[0];
      final taxable = remaining < tranche ? remaining : tranche;
      if (taxable <= 0) break;
      totalTax += taxable * baseRate * bracket[2];
      remaining -= taxable;
    }
    if (remaining > 0) {
      totalTax += remaining * baseRate * lastMultiplier;
    }
    return totalTax;
  }


  /// Family situation adjustment (splitting + deductions).
  ///
  /// Source: AFC — Charge fiscale en Suisse 2024.
  /// Mirrors: services/backend/app/services/fiscal/cantonal_comparator.py
  static const Map<String, double> _familyAdjustment = {
    'celibataire': 1.00,
    'marie_sans_enfant': 0.85,
    'marie_1_enfant': 0.78,
    'marie_2_enfants': 0.72,
    'marie_3_enfants': 0.66,
  };

  /// Marginal tax rate by canton, income, and family situation.
  ///
  /// Uses real AFC 2024 cantonal effective rates with income-level
  /// interpolation and family adjustment. Converts effective rate to
  /// marginal rate via ×1.3 factor (marginal > effective for progressive
  /// tax systems).
  ///
  /// Source: AFC — Charge fiscale en Suisse 2024.
  /// Used for chiffre-choc estimates — NOT for precise tax returns.
  static double estimateMarginalRate(
    double revenuBrutAnnuel,
    String canton, {
    bool isMarried = false,
    int children = 0,
    double? actualRate, // From tax declaration scan — overrides estimate
  }) {
    // If user has scanned a tax declaration with the real marginal rate,
    // use it directly instead of estimating. Data source: certificate (0.95).
    if (actualRate != null && actualRate > 0 && actualRate < 0.5) {
      return actualRate;
    }

    // Beads -8p4 (PR B de -5up) : pente locale du modèle v2 — miroir de
    // couple_optimizer.py backend (PR #1005). Remplace « effectif(100k)
    // x facteur revenu x 1.3 » ; clamp [0.0, 0.50] (le plancher 5%
    // inventait une économie sous le seuil d'imposition). NB : la
    // marginale bas revenu hérite du segment linéaire documenté du v2.
    final cantonCode = resolveCanton(canton).code;
    if (revenuBrutAnnuel <= 0) return 0.0;
    final delta = revenuBrutAnnuel < 1000.0 ? revenuBrutAnnuel : 1000.0;
    final cf = _childFactor(isMarried: isMarried, children: children);
    final hi = estimateIncomeTaxV2(revenuBrutAnnuel, cantonCode,
        isMarried: isMarried);
    final lo = estimateIncomeTaxV2(revenuBrutAnnuel - delta, cantonCode,
        isMarried: isMarried);
    final marginalRate = cf * (hi - lo) / delta;
    return marginalRate.clamp(0.0, 0.50);
  }

  /// Réduction supplémentaire enfants RELATIVE à marié sans enfant —
  /// ratios de la grille _familyAdjustment (convention backend PR #997 /
  /// #1005). Célibataire avec enfants : inchangé (limite dite).
  static double _childFactor({required bool isMarried, required int children}) {
    if (!isMarried || children <= 0) return 1.0;
    final key = children >= 3
        ? 'marie_3_enfants'
        : children == 2
            ? 'marie_2_enfants'
            : 'marie_1_enfant';
    return _familyAdjustment[key]! / _familyAdjustment['marie_sans_enfant']!;
  }


  /// Estimate tax saving from a deduction using numerical integration
  /// over canton-aware marginal rates.
  ///
  /// Slices the deduction into 10 steps and sums marginal tax saved at each
  /// income level. Used by buyback simulators to estimate fiscal benefit.
  static double estimateTaxSaving({
    required double income,
    required double deduction,
    required String canton,
    bool isMarried = false,
    int children = 0,
    double? actualMarginalRate,
    int steps = 10,
  }) {
    if (deduction <= 0) return 0.0;
    if (steps <= 0) return 0.0;
    // Scan de déclaration : taux réel -> économie flat (comportement
    // conservé — la source certificat prime sur le modèle).
    if (actualMarginalRate != null &&
        actualMarginalRate > 0 &&
        actualMarginalRate < 0.5) {
      return deduction * actualMarginalRate;
    }
    // Beads -8p4 : différence EXACTE du modèle v2 (l'intégration en
    // 10 pas approximait l'aire sous la marginale que le modèle calcule
    // directement). `steps` conservé pour compat de signature (ignoré).
    final cantonCode = resolveCanton(canton).code;
    if (income <= 0) return 0.0;
    final cf = _childFactor(isMarried: isMarried, children: children);
    final saving = estimateIncomeTaxV2(income, cantonCode,
            isMarried: isMarried) -
        estimateIncomeTaxV2(max(0.0, income - deduction), cantonCode,
            isMarried: isMarried);
    return max(0.0, cf * saving);
  }

  /// Estimate 3a tax saving from annual contribution (OPP3, LIFD art. 33).
  ///
  /// [grossAnnualSalary]: declarant's gross annual salary.
  /// [canton]: for marginal rate lookup.
  /// [isMarried]: for family situation adjustment.
  /// [children]: number of dependent children.
  /// [hasLpp]: if true, ceiling = 7'258; if false, ceiling = min(20% net, 36'288).
  /// [contributionMonths]: months worked in the tax year (1-12). Pro-rates the
  ///   ceiling for partial years (e.g. new job mid-year, or first job).
  ///   OPP3 art. 7: the deductible amount is proportional to the employment duration.
  /// [contribution]: actual contribution; if null, assumes max deductible.
  ///
  /// Returns the estimated tax saving in CHF.
  ///
  /// Legal basis: OPP3 art. 7 (plafond 3a), LIFD art. 33 (deduction).
  static double estimate3aTaxSaving({
    required double grossAnnualSalary,
    required String canton,
    bool isMarried = false,
    int children = 0,
    bool hasLpp = true,
    int contributionMonths = 12,
    double? contribution,
    double? actualMarginalRate,
  }) {
    return estimate3aTaxImpact(
      grossAnnualSalary: grossAnnualSalary,
      canton: canton,
      isMarried: isMarried,
      children: children,
      hasLpp: hasLpp,
      contributionMonths: contributionMonths,
      contribution: contribution,
      actualMarginalRate: actualMarginalRate,
    ).estimatedTaxSaving;
  }

  static Pillar3aTaxImpactEstimate estimate3aTaxImpact({
    required double grossAnnualSalary,
    required String canton,
    bool isMarried = false,
    int children = 0,
    bool hasLpp = true,
    int contributionMonths = 12,
    double? contribution,
    double? actualMarginalRate,
    /// Revenu professionnel NET (indépendant sans LPP). Quand fourni, sert de
    /// base au plafond sans-LPP (OPP3 art. 7 al. 2). Si absent, le net est
    /// dérivé du brut via [NetIncomeBreakdown] — JAMAIS le brut nu.
    double? netProfessionalIncome,
    /// Âge — utilisé uniquement pour dériver le net (NetIncomeBreakdown) quand
    /// [netProfessionalIncome] est absent.
    int age = 45,
  }) {
    if (grossAnnualSalary <= 0) return Pillar3aTaxImpactEstimate.unavailable;
    final months = contributionMonths.clamp(1, 12);

    // Ceiling depends on LPP affiliation (OPP3 art. 7).
    // Sans LPP (art. 7 al. 2) : 20% du revenu professionnel NET, borné 36288.
    // Base NET fournie par l'appelant, ou dérivée du brut (NetIncomeBreakdown,
    // canton + âge aware) — JAMAIS le brut nu (finding independent_no_lpp-1).
    final double annualCeiling;
    if (hasLpp) {
      annualCeiling = reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);
    } else {
      final double netBase = netProfessionalIncome ??
          NetIncomeBreakdown.compute(
            grossSalary: grossAnnualSalary,
            canton: canton,
            age: age,
            etatCivil: isMarried ? 'marie' : 'celibataire',
            nombreEnfants: children,
          ).netPayslip;
      annualCeiling =
          (netBase * pilier3aTauxRevenuSansLpp).clamp(0.0, pilier3aPlafondSansLpp);
    }

    // Pro-rate for partial year
    final double proRatedCeiling = annualCeiling * months / 12;

    // Actual deductible = min(contribution, proRatedCeiling)
    final double deductible = contribution != null
        ? contribution.clamp(0.0, proRatedCeiling)
        : proRatedCeiling;

    final marginalRate = estimateMarginalRate(
      grossAnnualSalary - deductible / 2,
      canton,
      isMarried: isMarried,
      children: children,
      actualRate: actualMarginalRate,
    );
    final estimatedTaxSaving = estimateTaxSaving(
      income: grossAnnualSalary,
      deduction: deductible,
      canton: canton,
      isMarried: isMarried,
      children: children,
      actualMarginalRate: actualMarginalRate,
    );

    return Pillar3aTaxImpactEstimate(
      annualCeiling: annualCeiling,
      proRatedCeiling: proRatedCeiling,
      deductibleContribution: deductible,
      marginalRate: marginalRate,
      estimatedTaxSaving: estimatedTaxSaving,
      confidence: actualMarginalRate != null
          ? Pillar3aTaxImpactConfidence.actualRate
          : Pillar3aTaxImpactConfidence.estimated,
    );
  }

  /// Estimate retirement income tax (annual → monthly).
  ///
  /// CRITICAL: revenuAnnuelImposable must EXCLUDE capital SWR withdrawals.
  /// Capital is already taxed at withdrawal (LIFD art. 38).
  /// SWR drawdown is consumption of own patrimony — NOT taxable income.
  static double estimateMonthlyIncomeTax({
    required double revenuAnnuelImposable,
    required String canton,
    String etatCivil = 'celibataire',
    int nombreEnfants = 0,
  }) {
    if (revenuAnnuelImposable <= 0) return 0;
    final result = FiscalService.estimateTax(
      revenuBrut: revenuAnnuelImposable,
      canton: canton,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
    );
    return ((result['chargeTotale'] as double?) ?? 0) / 12;
  }
}
