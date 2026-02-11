import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';

/// Input data for one LPP plan (current or new job).
class LPPPlanInput {
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
  double get effectiveSalaireAssure {
    if (salaireAssure != null) return salaireAssure!;
    final coordination = deductionCoordination ?? lppDeductionCoordination; // 2025 default
    final insured = salaireBrut - coordination;
    return insured > 0 ? insured : 0;
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
    // AVS/AI/APG: 5.3% employee share
    // AC: 1.1% employee share (up to 148'200)
    // AANP: ~0% for employee (paid by employer for occupational)
    // Total social charges: ~6.4%
    const socialChargesRate = 0.064;
    final grossMonthly = salaireBrut / 12;
    final socialCharges = grossMonthly * socialChargesRate;
    final lppMonthly = cotisationEmployeAnnuelle / 12;
    return grossMonthly - socialCharges - lppMonthly;
  }

  /// Estimate contribution rate based on age bands (LPP art. 16).
  double _estimateCotisationRate() {
    // Default employee rate assuming 50% split:
    // 25-34: 7% total -> 3.5% employee
    // 35-44: 10% total -> 5% employee
    // 45-54: 15% total -> 7.5% employee
    // 55-65: 18% total -> 9% employee
    // Use a middle-of-range default of 5% for MVP.
    const totalRate = 10.0; // mid-career default
    return totalRate * (100 - partEmployeurPct) / 100;
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
    final renteCurrent = capitalCurrent *
        current.tauxConversionSurobligatoire /
        100 /
        12;
    final renteNew = capitalNew *
        newJob.tauxConversionSurobligatoire /
        100 /
        12;
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
    // Assume 20 years of retirement (65 to 85)
    final lifetimePensionDelta = annualPensionDelta * 20;

    // Determine verdict
    final positiveCount = axes.where((a) => a.isPositive).length;
    final negativeCount = axes.where((a) => !a.isPositive).length;

    ComparisonVerdict verdict;
    String verdictDetail;

    if (positiveCount >= 5) {
      verdict = ComparisonVerdict.nouveauMeilleur;
      verdictDetail = 'Le nouveau poste est globalement meilleur';
    } else if (negativeCount >= 5) {
      verdict = ComparisonVerdict.actuelMeilleur;
      verdictDetail = 'Le poste actuel offre une meilleure protection';
    } else {
      verdict = ComparisonVerdict.comparable;
      verdictDetail = 'Les deux postes sont comparables';
    }

    // Generate alerts
    final alerts = <String>[];

    if (current.hasIjm && !newJob.hasIjm) {
      alerts.add('Tu perds la couverture IJM (indemnite journaliere maladie)');
    }

    if (deltaRente < 0 && deltaSalaireNet > 0) {
      alerts.add(
        'Attention : le gain salarial cache une perte de rente de '
        '${_formatChf(deltaRente.abs())}/mois',
      );
    }

    if (deltaCapital < -50000) {
      alerts.add(
        'Perte de capital retraite significative : '
        '${_formatChf(deltaCapital.abs())}',
      );
    }

    if (deltaDeces < -50000) {
      alerts.add(
        'Couverture deces reduite de ${_formatChf(deltaDeces.abs())}',
      );
    }

    if (deltaInvalidite < 0) {
      alerts.add(
        'Couverture invalidite reduite de '
        '${_formatChf(deltaInvalidite.abs())}/an',
      );
    }

    if (newJob.tauxConversionSurobligatoire <
        current.tauxConversionSurobligatoire) {
      alerts.add(
        'Taux de conversion inferieur : '
        '${newJob.tauxConversionSurobligatoire}% vs '
        '${current.tauxConversionSurobligatoire}%',
      );
    }

    // Checklist
    final checklist = [
      'Demander le reglement de la caisse de pension',
      'Verifier le taux de conversion surobligatoire',
      'Comparer la part employeur (50%? 60%? 65%?)',
      'Verifier la deduction de coordination',
      'Demander si IJM collective incluse',
      'Verifier le delai de carence pour le rachat',
      'Calculer l\'impact sur les prestations de risque',
      'Verifier le libre passage : transfert en 30 jours max',
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

  /// Project retirement capital at age 65 with annual contributions.
  static double _projectCapital(LPPPlanInput plan, int yearsToRetirement) {
    // Simplified projection: current avoir + yearly total contributions
    // with a conservative 1% annual return on existing capital.
    double capital = plan.avoirVieillesse;
    final annualContribution = plan.totalCotisationAnnuelle;
    const annualReturn = 0.01; // BVG minimum interest rate

    for (int i = 0; i < yearsToRetirement; i++) {
      capital = capital * (1 + annualReturn) + annualContribution;
    }
    return capital;
  }

  /// Format CHF with Swiss apostrophe.
  static String _formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }
}
