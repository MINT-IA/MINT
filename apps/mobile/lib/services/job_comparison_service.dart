import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/utils/chf_formatter.dart' as chf;

/// Input data for one LPP plan (current or new job).
class LPPPlanInput {
  final int age;
  final double salaireBrut;
  final double? salaireAssure;
  final double? deductionCoordination;
  final double tauxCotisationEmploye;
  final double tauxCotisationEmployeur;
  final double partEmployeurPct; // 50, 55, 60, 65
  final double avoirVieillesse;
  final double tauxConversionObligatoire;
  final double tauxConversionSurobligatoire;
  final double renteInvaliditePct;
  final double capitalDeces;
  final double rachatMaximum;
  final bool hasIjm;

  const LPPPlanInput({
    required this.age,
    required this.salaireBrut,
    this.salaireAssure,
    this.deductionCoordination,
    this.tauxCotisationEmploye = 0.0,
    this.tauxCotisationEmployeur = 0.0,
    this.partEmployeurPct = 50.0,
    this.avoirVieillesse = 0.0,
    this.tauxConversionObligatoire = 6.8,
    this.tauxConversionSurobligatoire = 5.2,
    this.renteInvaliditePct = 40.0,
    this.capitalDeces = 0.0,
    this.rachatMaximum = 0.0,
    this.hasIjm = true,
  });

  /// Effective insured salary, applying coordination deduction.
  /// Aligned with backend: seuil d'entrée, min/max coordonné (LPP art. 7, 8).
  double get effectiveSalaireAssure {
    if (salaireAssure != null) return salaireAssure!;
    // Below LPP entry threshold: no coverage (LPP art. 7)
    if (salaireBrut < reg('lpp.entry_threshold', lppSeuilEntree)) return 0.0;
    final coordination = deductionCoordination ??
        reg('lpp.coordination_deduction', lppDeductionCoordination);
    final insured = salaireBrut - coordination;
    // Apply min/max coordinated salary (LPP art. 8 al. 2)
    if (insured <= 0) {
      return reg('lpp.min_coordinated_salary', lppSalaireCoordMin);
    }
    return insured.clamp(reg('lpp.min_coordinated_salary', lppSalaireCoordMin),
        reg('lpp.max_coordinated_salary', lppSalaireCoordMax));
  }

  /// Total annual LPP contribution (employee + employer).
  double get totalCotisationAnnuelle {
    final employeeRate = tauxCotisationEmploye > 0
        ? tauxCotisationEmploye
        : _estimateCotisationRate();
    final employerRate = tauxCotisationEmployeur > 0
        ? tauxCotisationEmployeur
        : employeeRate * (partEmployeurPct / (100 - partEmployeurPct));
    return effectiveSalaireAssure * (employeeRate + employerRate) / 100;
  }

  /// Employee-only annual LPP contribution.
  double get cotisationEmployeAnnuelle {
    final employeeRate = tauxCotisationEmploye > 0
        ? tauxCotisationEmploye
        : _estimateCotisationRate();
    return effectiveSalaireAssure * employeeRate / 100;
  }

  /// Estimated annual pension (rente).
  double get renteAnnuelle {
    // Use weighted conversion rate (simplified: use surobligatoire rate as
    // the enveloping rate since we don't split obligatoire/surobligatoire).
    return avoirVieillesse * tauxConversionSurobligatoire / 100;
  }

  /// Monthly pension.
  double get renteMensuelle => renteAnnuelle / 12;

  /// Estimated net monthly salary (gross - social charges - LPP employee).
  double get salaireNetMensuel {
    final grossMonthly = salaireBrut / 12;
    final socialCharges = grossMonthly * cotisationsSalarieTotal;
    final lppMonthly = cotisationEmployeAnnuelle / 12;
    return grossMonthly - socialCharges - lppMonthly;
  }

  /// Estimate contribution rate based on age bands (LPP art. 16).
  double _estimateCotisationRate() {
    return LppContributionCalculator.estimateEmployeeRatePct(
      age: age,
      employerSharePct: partEmployeurPct,
    );
  }
}

/// Result for one comparison axis.
class ComparisonAxis {
  final String name;
  final String nameKey; // i18n key
  final double currentValue;
  final double newValue;
  final double delta;
  final String unit; // 'CHF', 'CHF/mois', '%'
  final bool isPositive; // true if delta direction is favorable

  const ComparisonAxis({
    required this.name,
    required this.nameKey,
    required this.currentValue,
    required this.newValue,
    required this.delta,
    required this.unit,
    required this.isPositive,
  });
}

/// Verdict for the comparison.
enum ComparisonVerdict {
  nouveauMeilleur,
  actuelMeilleur,
  comparable,
}

class JobComparisonCopy {
  const JobComparisonCopy._();

  static const disclaimer = 'jobCompareDisclaimer';
  static const sourceLppAgingCredits = 'LPP_ART_15_16';
  static const sourceLppBuyback = 'LPP_ART_79B';
  static const sourceLppCoverage = 'LPP_ART_2_7_8';
  static const sourceLifdDeduction = 'LIFD_ART_33_1_D';
  static const sourceLflpVestedBenefits = 'LFLP_ART_17_18';

  static const verdictNewBetter = 'jobCompareVerdictNewBetter';
  static const verdictCurrentBetter = 'jobCompareVerdictCurrentBetter';
  static const verdictComparable = 'jobCompareVerdictComparable';

  static const alertLostIjm = 'jobCompareAlertLostIjm';
  static const alertPensionLoss = 'jobCompareAlertPensionLoss';
  static const alertCapitalLoss = 'jobCompareAlertCapitalLoss';
  static const alertDeathCoverageLoss = 'jobCompareAlertDeathCoverageLoss';
  static const alertDisabilityCoverageLoss =
      'jobCompareAlertDisabilityCoverageLoss';
  static const alertLowerConversionRate = 'jobCompareAlertLowerConversionRate';

  static const checklistAskPensionReglement =
      'jobCompareChecklistAskPensionReglement';
  static const checklistVerifyConversionRate =
      'jobCompareChecklistVerifyConversionRate';
  static const checklistCompareEmployerShare =
      'jobCompareChecklistCompareEmployerShare';
  static const checklistVerifyCoordinationDeduction =
      'jobCompareChecklistVerifyCoordinationDeduction';
  static const checklistAskCollectiveIjm =
      'jobCompareChecklistAskCollectiveIjm';
  static const checklistVerifyBuybackDelay =
      'jobCompareChecklistVerifyBuybackDelay';
  static const checklistCalculateRiskBenefits =
      'jobCompareChecklistCalculateRiskBenefits';
  static const checklistVerifyVestedBenefits =
      'jobCompareChecklistVerifyVestedBenefits';
}

/// Full comparison result.
class JobComparisonResult {
  final List<ComparisonAxis> axes;
  final ComparisonVerdict verdict;
  final String verdictDetail;
  final List<String> alerts;
  final List<String> checklist;
  final double annualPensionDelta;
  final double lifetimePensionDelta; // over 20 years of retirement

  const JobComparisonResult({
    required this.axes,
    required this.verdict,
    required this.verdictDetail,
    required this.alerts,
    required this.checklist,
    required this.annualPensionDelta,
    required this.lifetimePensionDelta,
  });
}

/// Service for comparing two LPP plans (job change scenario).
class JobComparisonService {
  static const String disclaimer = JobComparisonCopy.disclaimer;

  static const List<String> sources = [
    JobComparisonCopy.sourceLppAgingCredits,
    JobComparisonCopy.sourceLppBuyback,
    JobComparisonCopy.sourceLppCoverage,
    JobComparisonCopy.sourceLifdDeduction,
    JobComparisonCopy.sourceLflpVestedBenefits,
  ];

  /// Compare current job vs new job across 7 axes.
  static JobComparisonResult compare({
    required LPPPlanInput current,
    required LPPPlanInput newJob,
    required int age,
  }) {
    // ---- Axis 1: Salaire net mensuel ----
    final salaireNetCurrent = current.salaireNetMensuel;
    final salaireNetNew = newJob.salaireNetMensuel;
    final deltaSalaireNet = salaireNetNew - salaireNetCurrent;

    // ---- Axis 2: Cotisation LPP employe (negative = cost) ----
    final cotisationCurrent = current.cotisationEmployeAnnuelle / 12;
    final cotisationNew = newJob.cotisationEmployeAnnuelle / 12;
    // Less cotisation = more cash in pocket, so delta is current - new
    final deltaCotisation = cotisationCurrent - cotisationNew;

    // ---- Axis 3: Capital retraite projete ----
    final yearsToRetirement = max(0, 65 - age);
    final capitalCurrent = _projectCapital(current, yearsToRetirement);
    final capitalNew = _projectCapital(newJob, yearsToRetirement);
    final deltaCapital = capitalNew - capitalCurrent;

    // ---- Axis 4: Rente mensuelle projetee ----
    final renteCurrent =
        capitalCurrent * current.tauxConversionSurobligatoire / 100 / 12;
    final renteNew =
        capitalNew * newJob.tauxConversionSurobligatoire / 100 / 12;
    final deltaRente = renteNew - renteCurrent;

    // ---- Axis 5: Couverture deces ----
    final decesCurrent = current.capitalDeces;
    final decesNew = newJob.capitalDeces;
    final deltaDeces = decesNew - decesCurrent;

    // ---- Axis 6: Couverture invalidite (annual) ----
    final invaliditeCurrent =
        current.effectiveSalaireAssure * current.renteInvaliditePct / 100;
    final invaliditeNew =
        newJob.effectiveSalaireAssure * newJob.renteInvaliditePct / 100;
    final deltaInvalidite = invaliditeNew - invaliditeCurrent;

    // ---- Axis 7: Rachat maximum ----
    final rachatCurrent = current.rachatMaximum;
    final rachatNew = newJob.rachatMaximum;
    final deltaRachat = rachatNew - rachatCurrent;

    // Build axes
    final axes = [
      ComparisonAxis(
        name: 'Salaire net',
        nameKey: 'jobCompareSalaireNet',
        currentValue: salaireNetCurrent,
        newValue: salaireNetNew,
        delta: deltaSalaireNet,
        unit: 'CHF/mois',
        isPositive: deltaSalaireNet >= 0,
      ),
      ComparisonAxis(
        name: 'Cotis. LPP',
        nameKey: 'jobCompareCotisLpp',
        currentValue: -cotisationCurrent,
        newValue: -cotisationNew,
        delta: deltaCotisation,
        unit: 'CHF/mois',
        isPositive: deltaCotisation >= 0,
      ),
      ComparisonAxis(
        name: 'Capital retraite',
        nameKey: 'jobCompareCapitalRetraite',
        currentValue: capitalCurrent,
        newValue: capitalNew,
        delta: deltaCapital,
        unit: 'CHF',
        isPositive: deltaCapital >= 0,
      ),
      ComparisonAxis(
        name: 'Rente/mois',
        nameKey: 'jobCompareRenteMois',
        currentValue: renteCurrent,
        newValue: renteNew,
        delta: deltaRente,
        unit: 'CHF/mois',
        isPositive: deltaRente >= 0,
      ),
      ComparisonAxis(
        name: 'Couverture deces',
        nameKey: 'jobCompareCouvertureDeces',
        currentValue: decesCurrent,
        newValue: decesNew,
        delta: deltaDeces,
        unit: 'CHF',
        isPositive: deltaDeces >= 0,
      ),
      ComparisonAxis(
        name: 'Couverture invalidite',
        nameKey: 'jobCompareInvalidite',
        currentValue: invaliditeCurrent,
        newValue: invaliditeNew,
        delta: deltaInvalidite,
        unit: 'CHF/an',
        isPositive: deltaInvalidite >= 0,
      ),
      ComparisonAxis(
        name: 'Rachat max',
        nameKey: 'jobCompareRachat',
        currentValue: rachatCurrent,
        newValue: rachatNew,
        delta: deltaRachat,
        unit: 'CHF',
        isPositive: deltaRachat >= 0,
      ),
    ];

    // Compute pension delta
    final annualPensionDelta = deltaRente * 12;
    // Assume 20 years of retirement (avsAgeReferenceHomme to 85)
    final lifetimePensionDelta = annualPensionDelta * 20;

    // Determine verdict. Neutral zero-delta axes must not turn an identical
    // plan into a false "new job is better" recommendation.
    final positiveCount = axes.where((a) => a.delta > 0).length;
    final negativeCount = axes.where((a) => a.delta < 0).length;

    ComparisonVerdict verdict;
    String verdictDetail;

    if (positiveCount >= 5) {
      verdict = ComparisonVerdict.nouveauMeilleur;
      verdictDetail = JobComparisonCopy.verdictNewBetter;
    } else if (negativeCount >= 5) {
      verdict = ComparisonVerdict.actuelMeilleur;
      verdictDetail = JobComparisonCopy.verdictCurrentBetter;
    } else {
      verdict = ComparisonVerdict.comparable;
      verdictDetail = JobComparisonCopy.verdictComparable;
    }

    // Generate alerts
    final alerts = <String>[];

    if (current.hasIjm && !newJob.hasIjm) {
      alerts.add(JobComparisonCopy.alertLostIjm);
    }

    if (deltaRente < 0 && deltaSalaireNet > 0) {
      alerts.add(
        '${JobComparisonCopy.alertPensionLoss}|'
        '${chf.formatChfWithPrefix(deltaRente.abs())}',
      );
    }

    if (deltaCapital < -50000) {
      alerts.add(
        '${JobComparisonCopy.alertCapitalLoss}|'
        '${chf.formatChfWithPrefix(deltaCapital.abs())}',
      );
    }

    if (deltaDeces < -50000) {
      alerts.add(
        '${JobComparisonCopy.alertDeathCoverageLoss}|'
        '${chf.formatChfWithPrefix(deltaDeces.abs())}',
      );
    }

    if (deltaInvalidite < 0) {
      alerts.add(
        '${JobComparisonCopy.alertDisabilityCoverageLoss}|'
        '${chf.formatChfWithPrefix(deltaInvalidite.abs())}',
      );
    }

    if (newJob.tauxConversionSurobligatoire <
        current.tauxConversionSurobligatoire) {
      alerts.add(
        '${JobComparisonCopy.alertLowerConversionRate}|'
        '${newJob.tauxConversionSurobligatoire}|'
        '${current.tauxConversionSurobligatoire}',
      );
    }

    // Checklist
    final checklist = [
      JobComparisonCopy.checklistAskPensionReglement,
      JobComparisonCopy.checklistVerifyConversionRate,
      JobComparisonCopy.checklistCompareEmployerShare,
      JobComparisonCopy.checklistVerifyCoordinationDeduction,
      JobComparisonCopy.checklistAskCollectiveIjm,
      JobComparisonCopy.checklistVerifyBuybackDelay,
      JobComparisonCopy.checklistCalculateRiskBenefits,
      JobComparisonCopy.checklistVerifyVestedBenefits,
    ];

    return JobComparisonResult(
      axes: axes,
      verdict: verdict,
      verdictDetail: verdictDetail,
      alerts: alerts,
      checklist: checklist,
      annualPensionDelta: annualPensionDelta,
      lifetimePensionDelta: lifetimePensionDelta,
    );
  }

  /// Project retirement capital at retirement age with annual contributions.
  /// Delegates to LppCalculator.projectToRetirement() from financial_core.
  static double _projectCapital(LPPPlanInput plan, int yearsToRetirement) {
    final refAgeJob =
        reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble()).toInt();
    final currentAge = refAgeJob - yearsToRetirement;
    final salaireAssure = plan.effectiveSalaireAssure;
    // Compute effective bonification rate from plan's total contribution
    // (employee + employer) relative to the insured salary.
    final bonificationRate =
        salaireAssure > 0 ? plan.totalCotisationAnnuelle / salaireAssure : 0.0;

    // Use conversionRate=1.0 to get raw projected capital (not rente).
    return LppCalculator.projectToRetirement(
      currentBalance: plan.avoirVieillesse,
      currentAge: currentAge,
      retirementAge: refAgeJob,
      grossAnnualSalary: plan.salaireBrut,
      caisseReturn: 0.0125, // BVG minimum interest rate
      conversionRate: 1.0, // Return raw capital, not rente
      bonificationRateOverride: bonificationRate,
      salaireAssureOverride: salaireAssure,
    );
  }
}
