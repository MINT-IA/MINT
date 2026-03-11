import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';

/// Severity of a cross-validation alert.
enum AlertSeverity {
  /// Informational — data seems plausible but unusual.
  info,

  /// Warning — data is likely incorrect or inconsistent.
  warning,

  /// Error — data violates a hard legal or mathematical constraint.
  error,
}

/// A single cross-validation finding.
class ValidationAlert {
  /// Which data block this alert relates to (e.g. 'lpp', 'avs', '3a').
  final String block;

  /// Human-readable message (French, informal "tu").
  final String message;

  final AlertSeverity severity;

  /// Optional suggestion for the user to fix the issue.
  final String? suggestion;

  const ValidationAlert({
    required this.block,
    required this.message,
    required this.severity,
    this.suggestion,
  });
}

/// Cross-validation engine for CoachProfile data.
///
/// Checks coherence between data blocks and flags implausible
/// or inconsistent values. All rules are non-blocking (advisory).
///
/// Rules:
/// 1. LPP avoir vs age/salary — plausibility check
/// 2. 3a vs employment status — correct ceiling
/// 3. Mortgage vs revenue — Tragbarkeit (FINMA/ASB)
/// 4. AVS years vs arrival date — coherence
/// 5. Retirement age vs legal bounds (58-70)
/// 6. LPP vs employment status — independant sans LPP coherence
class CrossValidationService {
  CrossValidationService._();

  /// Validate all cross-block rules and return findings.
  static List<ValidationAlert> validate(CoachProfile profile) {
    final alerts = <ValidationAlert>[];

    _checkLppPlausibility(profile, alerts);
    _check3aCeiling(profile, alerts);
    _checkMortgageTragbarkeit(profile, alerts);
    _checkAvsCoherence(profile, alerts);
    _checkRetirementAgeBounds(profile, alerts);
    _checkLppEmploymentCoherence(profile, alerts);

    return alerts;
  }

  // ── Rule 1: LPP avoir vs age/salary plausibility ──────────────

  /// Estimates theoretical LPP capital based on age and salary,
  /// then flags if declared capital is outside ±50%.
  static void _checkLppPlausibility(
    CoachProfile profile,
    List<ValidationAlert> alerts,
  ) {
    final lppDeclared = profile.prevoyance.avoirLppTotal;
    if (lppDeclared == null || lppDeclared <= 0) return;

    // Only check for employees (independants may have voluntary LPP)
    if (profile.employmentStatus != 'salarie') return;

    final grossAnnual = profile.revenuBrutAnnuel;
    if (grossAnnual < lppSeuilEntree) return;

    // Estimate theoretical LPP: sum bonifications from start age to current age
    final startAge = profile.arrivalAge != null
        ? max(25, profile.arrivalAge!)
        : 25;
    final currentAge = profile.age;
    if (currentAge <= startAge) return;

    final salaireCoord =
        (grossAnnual - lppDeductionCoordination).clamp(lppSalaireCoordMin, lppSalaireCoordMax);

    double theoreticalLpp = 0;
    for (int age = startAge; age < currentAge; age++) {
      final rate = getLppBonificationRate(age);
      theoreticalLpp += salaireCoord * rate;
      // Simple compound: apply minimum interest
      theoreticalLpp *= (1 + lppTauxInteretMin / 100);
    }

    if (theoreticalLpp <= 0) return;

    final ratio = lppDeclared / theoreticalLpp;

    if (ratio < 0.3) {
      alerts.add(ValidationAlert(
        block: 'lpp',
        message:
            'Ton avoir LPP (${_fmtChf(lppDeclared)}) semble tres bas par '
            'rapport a ton age et salaire (estimation theorique: '
            '${_fmtChf(theoreticalLpp)}).',
        severity: AlertSeverity.warning,
        suggestion:
            'Verifie ton certificat de prevoyance. Si tu as change '
            'd\'employeur ou retire du capital (EPL), c\'est normal.',
      ));
    } else if (ratio > 2.0) {
      alerts.add(ValidationAlert(
        block: 'lpp',
        message:
            'Ton avoir LPP (${_fmtChf(lppDeclared)}) est nettement '
            'superieur a l\'estimation theorique (${_fmtChf(theoreticalLpp)}). '
            'As-tu effectue des rachats LPP importants?',
        severity: AlertSeverity.info,
        suggestion:
            'Si des rachats sont inclus, c\'est coherent. Sinon, '
            'verifie les montants sur ton certificat.',
      ));
    }
  }

  // ── Rule 2: 3a vs employment status ───────────────────────────

  /// Checks that 3a contributions respect the correct ceiling.
  static void _check3aCeiling(
    CoachProfile profile,
    List<ValidationAlert> alerts,
  ) {
    final total3a = profile.prevoyance.totalEpargne3a;
    if (total3a <= 0) return;

    // Check annual contribution rate (estimated from total and age)
    final nombre3a = profile.prevoyance.nombre3a;
    if (nombre3a <= 0) return;

    final isIndependantNoLpp =
        profile.employmentStatus == 'independant' &&
        (profile.prevoyance.avoirLppTotal == null ||
            profile.prevoyance.avoirLppTotal! <= 0);

    final plafond = isIndependantNoLpp
        ? min(profile.revenuBrutAnnuel * pilier3aTauxRevenuSansLpp,
              pilier3aPlafondSansLpp)
        : pilier3aPlafondAvecLpp;

    // If user has planned 3a contributions, check against ceiling
    final planned3aAnnuel = profile.plannedContributions
        .where((c) => c.category == '3a')
        .fold(0.0, (sum, c) => sum + c.amount) * 12;

    if (planned3aAnnuel > plafond * 1.05) {
      alerts.add(ValidationAlert(
        block: '3a',
        message:
            'Tes versements 3a planifies (${_fmtChf(planned3aAnnuel)}/an) '
            'depassent le plafond legal de ${_fmtChf(plafond)}/an '
            '(OPP3 art. 7).',
        severity: AlertSeverity.error,
        suggestion: isIndependantNoLpp
            ? 'En tant qu\'independant·e sans LPP, le plafond est de '
              '20% du revenu net, max ${_fmtChf(pilier3aPlafondSansLpp)}.'
            : 'En tant que salarie·e avec LPP, le plafond est de '
              '${_fmtChf(pilier3aPlafondAvecLpp)}/an.',
      ));
    }
  }

  // ── Rule 3: Mortgage vs revenue (Tragbarkeit) ─────────────────

  /// FINMA/ASB Tragbarkeit rule: theoretical mortgage charges at 5%
  /// must not exceed 1/3 of gross income.
  static void _checkMortgageTragbarkeit(
    CoachProfile profile,
    List<ValidationAlert> alerts,
  ) {
    final mortgage = profile.patrimoine.mortgageBalance;
    if (mortgage == null || mortgage <= 0) return;

    final propertyValue = profile.patrimoine.propertyMarketValue;
    if (propertyValue == null || propertyValue <= 0) return;

    final grossAnnual = profile.revenuBrutAnnuelCouple;
    if (grossAnnual <= 0) return;

    // Theoretical charges: 5% interest + 1% amortization + 1% maintenance
    const theoreticalRate = 0.05;
    const amortization = 0.01;
    const maintenance = 0.01;

    final annualCharges = mortgage * theoreticalRate +
        mortgage * amortization +
        propertyValue * maintenance;

    final ratio = annualCharges / grossAnnual;

    if (ratio > 0.33) {
      final pct = (ratio * 100).toStringAsFixed(0);
      alerts.add(ValidationAlert(
        block: 'patrimoine',
        message:
            'Ton taux d\'effort hypothecaire theorique est de $pct% '
            '(limite: 33%). Les banques pourraient refuser ce financement.',
        severity: ratio > 0.40
            ? AlertSeverity.error
            : AlertSeverity.warning,
        suggestion:
            'Calcul: interet theorique 5% + amortissement 1% + '
            'entretien 1% du bien. Revenu brut du menage: '
            '${_fmtChf(grossAnnual)}/an.',
      ));
    }
  }

  // ── Rule 4: AVS years vs arrival date coherence ───────────────

  /// Checks that declared AVS contribution years are coherent
  /// with the user's arrival age in Switzerland.
  static void _checkAvsCoherence(
    CoachProfile profile,
    List<ValidationAlert> alerts,
  ) {
    final declaredYears = profile.prevoyance.anneesContribuees;
    if (declaredYears == null) return;

    final currentAge = profile.age;

    // Max possible contribution years: from age 20 (or arrival) to now
    final startAge = profile.arrivalAge != null
        ? max(20, profile.arrivalAge!)
        : 20;

    final maxPossibleYears = max(0, currentAge - startAge);

    if (declaredYears > maxPossibleYears + 1) {
      alerts.add(ValidationAlert(
        block: 'avs',
        message:
            'Tu declares $declaredYears annees de cotisation AVS, '
            'mais ton age ($currentAge ans${profile.arrivalAge != null ? ', arrive a ${profile.arrivalAge} ans' : ''}) '
            'permet au maximum $maxPossibleYears annees.',
        severity: AlertSeverity.warning,
        suggestion:
            'Verifie ton extrait de compte AVS. Des annees cotisees '
            'a l\'etranger ne comptent pas directement (sauf convention '
            'bilaterale EU/AELE).',
      ));
    }

    // Also flag if declared years seem too low (>5 years gap)
    if (declaredYears < maxPossibleYears - 5 &&
        maxPossibleYears > 10 &&
        profile.arrivalAge == null) {
      final gap = maxPossibleYears - declaredYears;
      alerts.add(ValidationAlert(
        block: 'avs',
        message:
            'Tu as $gap annees de lacune AVS potentielle. As-tu '
            'sejourne a l\'etranger ou eu des periodes sans cotisation?',
        severity: AlertSeverity.info,
        suggestion:
            'Commande ton extrait CI (compte individuel) aupres de la '
            'caisse de compensation pour verifier.',
      ));
    }
  }

  // ── Rule 5: Retirement age bounds ─────────────────────────────

  /// Retirement age must be between 58 and 70 (LPP + LAVS).
  static void _checkRetirementAgeBounds(
    CoachProfile profile,
    List<ValidationAlert> alerts,
  ) {
    final target = profile.targetRetirementAge;
    if (target == null) return;

    if (target < 58) {
      alerts.add(ValidationAlert(
        block: 'objectifRetraite',
        message:
            'Un depart a $target ans n\'est pas possible: la retraite '
            'anticipee LPP commence au plus tot a 58 ans (LPP art. 13).',
        severity: AlertSeverity.error,
        suggestion:
            'Le minimum legal est 58 ans (selon le reglement de ta '
            'caisse). L\'anticipation AVS est possible des 63 ans '
            '(LAVS art. 40).',
      ));
    } else if (target > 70) {
      alerts.add(ValidationAlert(
        block: 'objectifRetraite',
        message:
            'Un depart a $target ans depasse l\'age maximal d\'ajournement '
            'AVS de 70 ans (LAVS art. 39).',
        severity: AlertSeverity.error,
        suggestion:
            'L\'ajournement AVS est limite a 5 ans apres l\'age de '
            'reference (65 + 5 = 70 ans).',
      ));
    } else if (target < 63) {
      alerts.add(ValidationAlert(
        block: 'objectifRetraite',
        message:
            'A $target ans, seule la LPP peut etre percue (selon ta '
            'caisse). L\'AVS ne peut etre anticipee qu\'a partir de '
            '63 ans (LAVS art. 40).',
        severity: AlertSeverity.info,
        suggestion:
            'Entre $target et 63 ans, tu devras financer le gap sans '
            'rente AVS. Prevois une epargne-pont.',
      ));
    }
  }

  // ── Rule 6: LPP vs employment status coherence ────────────────

  /// Flags if an independent declares significant LPP (possible but unusual)
  /// or if an employee has 0 LPP (missing data?).
  static void _checkLppEmploymentCoherence(
    CoachProfile profile,
    List<ValidationAlert> alerts,
  ) {
    final lpp = profile.prevoyance.avoirLppTotal;
    final status = profile.employmentStatus;

    // Employee with salary above threshold but no LPP declared
    if (status == 'salarie' &&
        profile.revenuBrutAnnuel >= lppSeuilEntree &&
        (lpp == null || lpp <= 0) &&
        profile.age >= 25) {
      alerts.add(ValidationAlert(
        block: 'lpp',
        message:
            'En tant que salarie·e avec un revenu au-dessus du seuil '
            'LPP (${_fmtChf(lppSeuilEntree)}), tu devrais avoir un '
            'avoir de prevoyance.',
        severity: AlertSeverity.info,
        suggestion:
            'Demande ton certificat de prevoyance a ta caisse de '
            'pension pour completer ces donnees.',
      ));
    }

    // Independent with high LPP — unusual, flag for confirmation
    if (status == 'independant' && lpp != null && lpp > 200000) {
      alerts.add(ValidationAlert(
        block: 'lpp',
        message:
            'Tu es independant·e avec un avoir LPP de ${_fmtChf(lpp)}. '
            'S\'agit-il d\'une affiliation facultative ou d\'un ancien '
            'avoir de salarie·e?',
        severity: AlertSeverity.info,
        suggestion:
            'Si c\'est un libre passage d\'un ancien emploi, deplace-le '
            'dans la section "Libre passage" pour un calcul plus precis.',
      ));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────

  static String _fmtChf(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M CHF';
    }
    if (amount >= 1000) {
      final k = (amount / 1000).toStringAsFixed(0);
      return "$k'000 CHF";
    }
    return '${amount.toStringAsFixed(0)} CHF';
  }
}
