/// Couple Optimizer — cross-person financial optimization for Swiss households.
///
/// Analyses:
///   1. LPP buyback order: who buys back first? (highest marginal tax rate wins)
///   2. 3a contribution order: who contributes first? (same logic + FATCA check)
///   3. Marriage penalty: is being married more or less tax-efficient?
///
/// Tax calculations delegate to [TaxCalculator] and [RetirementTaxCalculator].
/// AVS is deliberately unavailable from salary/age profile proxies; callers
/// must use [AvsCalculator.computeCouplePensions] with official person-owned
/// pension evidence.
///
/// Compliance:
///   - LSFin art. 3: results shown as trade-offs, never ranked as "optimal"
///   - Each result includes a [tradeOff] disclaimer
///   - FATCA-aware: US residents may not contribute to 3a
///
/// Sources:
///   - LPP art. 33 (rachat)
///   - LIFD art. 33 (3a deduction)
///   - OPP3 art. 7 (3a ceiling)
library;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

// ────────────────────────────────────────────────────────────
//  Result models
// ────────────────────────────────────────────────────────────

/// Who should act first in a couple optimization.
enum CoupleWinner { mainUser, conjoint, noPreference }

/// Result of a single couple optimization analysis.
class CoupleAnalysisResult {
  /// Who benefits more from acting first.
  final CoupleWinner winner;

  /// Absolute CHF savings difference between the two scenarios.
  /// When winner == noPreference, delta is near zero.
  final double savingDelta;

  /// Human-readable reason (internal, for coach context — not user-facing).
  final String reason;

  /// Compliance trade-off text (ALWAYS present per LSFin).
  final String tradeOff;

  const CoupleAnalysisResult({
    required this.winner,
    required this.savingDelta,
    required this.reason,
    required this.tradeOff,
  });
}

/// Marriage penalty analysis result.
class MarriagePenaltyResult {
  /// True if married couple pays MORE tax than two singles with same income.
  final bool hasPenalty;

  /// Annual delta: positive = penalty (married pays more), negative = bonus.
  final double annualDelta;

  /// Trade-off text.
  final String tradeOff;

  const MarriagePenaltyResult({
    required this.hasPenalty,
    required this.annualDelta,
    required this.tradeOff,
  });
}

/// Complete couple optimization output.
class CoupleOptimizationResult {
  final CoupleAnalysisResult? lppBuybackOrder;
  final CoupleAnalysisResult? pillar3aOrder;

  /// Always null from [CoupleOptimizer.optimize]. Salary and age are not
  /// evidence for an official AVS pension or a legal couple cap.
  final AvsCouplePensionResult? avsCap;
  final MarriagePenaltyResult? marriagePenalty;

  const CoupleOptimizationResult({
    this.lppBuybackOrder,
    this.pillar3aOrder,
    this.avsCap,
    this.marriagePenalty,
  });

  /// Returns an empty result when no conjoint data is available.
  const CoupleOptimizationResult.empty()
      : lppBuybackOrder = null,
        pillar3aOrder = null,
        avsCap = null,
        marriagePenalty = null;

  /// True when at least one analysis produced a result.
  bool get hasResults =>
      lppBuybackOrder != null ||
      pillar3aOrder != null ||
      avsCap != null ||
      marriagePenalty != null;
}

// ────────────────────────────────────────────────────────────
//  Service
// ────────────────────────────────────────────────────────────

/// Couple financial optimizer — compares "user first" vs "conjoint first"
/// scenarios for LPP buyback and 3a contributions, and evaluates marriage
/// penalty. It never manufactures an AVS pension from salary and age.
///
/// Pure functions only. No side effects.
class CoupleOptimizer {
  CoupleOptimizer._();

  /// Minimum savings delta (CHF) to declare a winner.
  /// Below this, declare [CoupleWinner.noPreference].
  static const double _minDelta = 100.0;

  /// Run all 3 couple analyses.
  ///
  /// Returns [CoupleOptimizationResult] with nullable fields — each
  /// analysis is skipped when insufficient data is available.
  ///
  /// Returns [CoupleOptimizationResult.empty] when [conjoint] is null
  /// or has no usable income data (avoids crash on single-user profiles).
  static CoupleOptimizationResult optimize({
    required CoachProfile mainUser,
    ConjointProfile? conjoint,
  }) {
    // Guard: no conjoint → nothing to optimize.
    if (conjoint == null) return const CoupleOptimizationResult.empty();

    // Guard: both incomes zero → nothing to optimize.
    // If only one partner has income, the tax analyses can still apply.
    final userIncome = mainUser.salaireBrutMensuel * mainUser.nombreDeMois;
    final conjointIncome = conjoint.revenuBrutAnnuel;
    if (userIncome <= 0 && conjointIncome <= 0) {
      return const CoupleOptimizationResult.empty();
    }

    return CoupleOptimizationResult(
      lppBuybackOrder: _analyzeLppBuybackOrder(mainUser, conjoint),
      pillar3aOrder: _analyze3aContributionOrder(mainUser, conjoint),
      marriagePenalty: _analyzeMarriagePenalty(mainUser, conjoint),
    );
  }

  // ── Analysis 1: LPP buyback order ──────────────────────────

  static CoupleAnalysisResult? _analyzeLppBuybackOrder(
    CoachProfile user,
    ConjointProfile conjoint,
  ) {
    final userRachat = user.prevoyance.lacuneRachatRestante;
    final conjointRachat = conjoint.prevoyance?.lacuneRachatRestante ?? 0;

    // Both must have a buyback possibility
    if (userRachat <= 0 && conjointRachat <= 0) return null;

    final userIncome = user.salaireBrutMensuel * user.nombreDeMois;
    final conjointIncome = conjoint.revenuBrutAnnuel;
    if (userIncome <= 0 && conjointIncome <= 0) return null;

    // Estimate tax saving for a reference rachat amount (10'000 CHF)
    const referenceAmount = 10000.0;
    final canton = user.canton;

    // Couple context → isMarried: true for tax splitting
    final children = user.nombreEnfants;
    final userSaving = userIncome > 0 && userRachat > 0
        ? RetirementTaxCalculator.estimateTaxSaving(
            income: userIncome,
            deduction: referenceAmount.clamp(0, userRachat),
            canton: canton,
            isMarried: user.etatCivil == CoachCivilStatus.marie,
            children: children,
          )
        : 0.0;

    final conjointSaving = conjointIncome > 0 && conjointRachat > 0
        ? RetirementTaxCalculator.estimateTaxSaving(
            income: conjointIncome,
            deduction: referenceAmount.clamp(0, conjointRachat),
            canton: canton,
            isMarried: user.etatCivil == CoachCivilStatus.marie,
            children: children,
          )
        : 0.0;

    final delta = (userSaving - conjointSaving).abs();
    final CoupleWinner winner;
    final String reason;

    if (delta < _minDelta) {
      winner = CoupleWinner.noPreference;
      reason = 'Taux marginaux similaires — pas de préférence.';
    } else if (userSaving > conjointSaving) {
      winner = CoupleWinner.mainUser;
      reason = 'Taux marginal plus élevé → économie fiscale supérieure par CHF racheté.';
    } else {
      winner = CoupleWinner.conjoint;
      reason = 'Taux marginal plus élevé → économie fiscale supérieure par CHF racheté.';
    }

    return CoupleAnalysisResult(
      winner: winner,
      savingDelta: delta,
      reason: reason,
      tradeOff: 'Le rachat LPP est bloqué 3 ans avant le retrait (LPP art. 79b al. 3). '
          'Le timing dépend aussi de l\'âge de chaque personne.',
    );
  }

  // ── Analysis 2: 3a contribution order ─────────────────────

  static CoupleAnalysisResult? _analyze3aContributionOrder(
    CoachProfile user,
    ConjointProfile conjoint,
  ) {
    final userIncome = user.salaireBrutMensuel * user.nombreDeMois;
    final conjointIncome = conjoint.revenuBrutAnnuel;
    if (userIncome <= 0 && conjointIncome <= 0) return null;

    // FATCA check: US resident conjoint may not contribute to 3a
    final conjointCanContribute = conjoint.canContribute3a;

    if (!conjointCanContribute) {
      return const CoupleAnalysisResult(
        winner: CoupleWinner.mainUser,
        savingDelta: 0,
        reason: 'Le\u00b7la conjoint\u00b7e est résident\u00b7e FATCA '
            '— le versement 3a n\'est pas possible pour cette personne.',
        tradeOff: 'FATCA (Foreign Account Tax Compliance Act) '
            'restreint l\'accès à certains produits 3a pour les résidents US.',
      );
    }

    final canton = user.canton;
    final ceiling = reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);
    final children3a = user.nombreEnfants;

    final userSaving = userIncome > 0
        ? RetirementTaxCalculator.estimateTaxSaving(
            income: userIncome,
            deduction: ceiling,
            canton: canton,
            isMarried: user.etatCivil == CoachCivilStatus.marie,
            children: children3a,
          )
        : 0.0;

    final conjointSaving = conjointIncome > 0
        ? RetirementTaxCalculator.estimateTaxSaving(
            income: conjointIncome,
            deduction: ceiling,
            canton: canton,
            isMarried: user.etatCivil == CoachCivilStatus.marie,
            children: children3a,
          )
        : 0.0;

    final delta = (userSaving - conjointSaving).abs();
    final CoupleWinner winner;
    final String reason;

    if (delta < _minDelta) {
      winner = CoupleWinner.noPreference;
      reason = 'Taux marginaux similaires — les deux bénéficient '
          'de manière comparable.';
    } else if (userSaving > conjointSaving) {
      winner = CoupleWinner.mainUser;
      reason = 'Revenu imposable plus élevé → déduction 3a plus avantageuse.';
    } else {
      winner = CoupleWinner.conjoint;
      reason = 'Revenu imposable plus élevé → déduction 3a plus avantageuse.';
    }

    return CoupleAnalysisResult(
      winner: winner,
      savingDelta: delta,
      reason: reason,
      tradeOff: 'Le plafond 3a est individuel (CHF\u00a0${ceiling.round()}/an). '
          'Les deux partenaires peuvent verser chacun le maximum.',
    );
  }

  // ── Analysis 3: Marriage penalty ──────────────────────────

  static MarriagePenaltyResult? _analyzeMarriagePenalty(
    CoachProfile user,
    ConjointProfile conjoint,
  ) {
    final userIncome = user.salaireBrutMensuel * user.nombreDeMois;
    final conjointIncome = conjoint.revenuBrutAnnuel;
    // Need at least one income to compute marriage penalty
    if (userIncome <= 0 && conjointIncome <= 0) return null;

    final canton = user.canton;
    final enfants = user.nombreEnfants;

    // Tax as married couple (joint filing — children counted once)
    final taxMarried = RetirementTaxCalculator.estimateMonthlyIncomeTax(
      revenuAnnuelImposable: userIncome + conjointIncome,
      canton: canton,
      etatCivil: 'marie',
      nombreEnfants: enfants,
    ) * 12;

    // Tax as two singles — children assigned to the higher earner
    // (Swiss practice: deductions go to the parent with higher income)
    final userHasKids = userIncome >= conjointIncome;
    final taxUserSingle = RetirementTaxCalculator.estimateMonthlyIncomeTax(
      revenuAnnuelImposable: userIncome,
      canton: canton,
      etatCivil: 'celibataire',
      nombreEnfants: userHasKids ? enfants : 0,
    ) * 12;
    final taxConjointSingle = RetirementTaxCalculator.estimateMonthlyIncomeTax(
      revenuAnnuelImposable: conjointIncome,
      canton: canton,
      etatCivil: 'celibataire',
      nombreEnfants: userHasKids ? 0 : enfants,
    ) * 12;

    final annualDelta = taxMarried - (taxUserSingle + taxConjointSingle);

    return MarriagePenaltyResult(
      hasPenalty: annualDelta > 0,
      annualDelta: annualDelta,
      tradeOff: annualDelta > 0
          ? 'Le mariage crée une surcharge fiscale de '
              'CHF\u00a0${annualDelta.round()}/an dans le canton $canton. '
              'Cet écart varie selon les cantons et les niveaux de revenu.'
          : 'Le mariage crée un avantage fiscal de '
              'CHF\u00a0${annualDelta.abs().round()}/an dans le canton $canton. '
              'Cet avantage est dû au splitting pour les couples mariés.',
    );
  }
}
