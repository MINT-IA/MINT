import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/unemployment_financial_facts.dart';

// ────────────────────────────────────────────────────────────
//  UNEMPLOYMENT SERVICE — Sprint S19 / Chomage (LACI) + Premier emploi
// ────────────────────────────────────────────────────────────
//
// Pure Dart service for unemployment benefits (LACI art. 22, 23, 27).
//   1. calculateBenefits — eligibility, rate, duration, timeline
//
// All constants match the backend exactly.
// No banned promise terms.
// ────────────────────────────────────────────────────────────

/// Result of unemployment benefits calculation.
class UnemploymentResult {
  final bool eligible;
  final String? raisonNonEligible;
  final double tauxIndemnite;
  final double gainAssureRetenu;
  final double indemniteJournaliere;
  final double indemniteMensuelle;
  final int nombreIndemnites;
  final double dureeMois;
  final int delaiCarenceJours;
  final double perteMensuelle;
  final String premierEclairage;
  final List<UnemploymentTimelineItem> timeline;

  const UnemploymentResult({
    required this.eligible,
    this.raisonNonEligible,
    required this.tauxIndemnite,
    required this.gainAssureRetenu,
    required this.indemniteJournaliere,
    required this.indemniteMensuelle,
    required this.nombreIndemnites,
    required this.dureeMois,
    required this.delaiCarenceJours,
    required this.perteMensuelle,
    required this.premierEclairage,
    required this.timeline,
  });
}

/// A single step in the unemployment timeline.
class UnemploymentTimelineItem {
  final int jour;
  final String action;
  final String description;
  final String urgence; // 'immediate', 'semaine1', 'mois1', 'mois3'

  const UnemploymentTimelineItem({
    required this.jour,
    required this.action,
    required this.description,
    required this.urgence,
  });
}

/// Service for unemployment (LACI) calculations.
///
/// All constants match the backend exactly.
class UnemploymentService {
  UnemploymentService._();

  // ════════════════════════════════════════════════════════════
  //  CONSTANTS (LACI)
  // ════════════════════════════════════════════════════════════

  /// Base indemnity rate (70%).
  static const double _rateBase = 0.70;

  /// Enhanced indemnity rate (80%).
  static const double _rateEnhanced = 0.80;

  /// Maximum gain assure mensuel (CHF 12'350).
  /// Derived from acPlafondSalaireAssure / 12.
  static double get _gainAssureMax =>
      reg('ac.max_monthly_insured_income', acGainAssureMensuelMax);

  /// Salary threshold for enhanced rate (CHF 3'797).
  static double get _salaryThresholdEnhanced =>
      reg('ac.enhanced_rate_threshold', acSeuilSalaireMajore);

  /// Working days per month.
  static const double _workingDaysPerMonth = 21.7;

  // ════════════════════════════════════════════════════════════
  //  CALCULATION
  // ════════════════════════════════════════════════════════════

  /// Calculate unemployment benefits (LACI art. 22, 23, 27).
  static UnemploymentResult calculateBenefits({
    required double gainAssureMensuel,
    required int age,
    required int moisCotisation,
    bool hasChildren = false,
    bool hasDisability = false,
    bool hasReachedAvsReferenceAge = false,
    bool isWithinFourYearsOfAvsReferenceAge = false,
  }) {
    // 0. Validate gain assure > 0 (aligned with backend)
    if (gainAssureMensuel <= 0) {
      return UnemploymentResult(
        eligible: false,
        raisonNonEligible:
            'Le gain assuré mensuel doit être supérieur à 0 CHF. ' // lint-ignore
            'Vérifie le montant de ton dernier salaire.', // lint-ignore
        tauxIndemnite: 0,
        gainAssureRetenu: 0,
        indemniteJournaliere: 0,
        indemniteMensuelle: 0,
        nombreIndemnites: 0,
        dureeMois: 0,
        delaiCarenceJours: 0,
        perteMensuelle: 0,
        premierEclairage: '',
        timeline: _buildTimeline(),
      );
    }

    // 0b. Ordinary AC entitlement ends around the AVS reference age. With only
    // an integer age available, keep this educational calculator conservative;
    // transition benefits for 60+ need their own scenario.
    if (hasReachedAvsReferenceAge || age >= 65) {
      return UnemploymentResult(
        eligible: false,
        raisonNonEligible:
            "Ce calcul LACI s'arrête à l'âge de référence AVS. " // lint-ignore
            'Analyse plutôt les prestations transitoires et la coordination ' // lint-ignore
            'AVS/LPP avec une caisse ou un ORP.', // lint-ignore
        tauxIndemnite: 0,
        gainAssureRetenu: 0,
        indemniteJournaliere: 0,
        indemniteMensuelle: 0,
        nombreIndemnites: 0,
        dureeMois: 0,
        delaiCarenceJours: 0,
        perteMensuelle: 0,
        premierEclairage: '',
        timeline: _buildTimeline(),
      );
    }

    // 1. Check eligibility: minimum 12 months
    if (moisCotisation < 12) {
      return UnemploymentResult(
        eligible: false,
        raisonNonEligible:
            'Minimum 12 mois de cotisation requis (tu as $moisCotisation mois)', // lint-ignore
        tauxIndemnite: 0,
        gainAssureRetenu: 0,
        indemniteJournaliere: 0,
        indemniteMensuelle: 0,
        nombreIndemnites: 0,
        dureeMois: 0,
        delaiCarenceJours: 0,
        perteMensuelle: 0,
        premierEclairage: '',
        timeline: _buildTimeline(),
      );
    }

    // 2. Determine rate
    final taux = _determineRate(gainAssureMensuel, hasChildren, hasDisability);

    // 3. Cap gain assure
    final gainRetenu = min(gainAssureMensuel, _gainAssureMax);

    // 4. Calculate benefits
    final indemniteJournaliere = (gainRetenu * taux) / _workingDaysPerMonth;
    final indemniteMensuelle = indemniteJournaliere * _workingDaysPerMonth;

    // 5. Duration
    final nombreIndemnites = _calculateDuration(
      age: age,
      moisCotisation: moisCotisation,
      hasChildren: hasChildren,
      hasDisability: hasDisability,
      isWithinFourYearsOfAvsReferenceAge: isWithinFourYearsOfAvsReferenceAge,
    );
    final dureeMois = nombreIndemnites / _workingDaysPerMonth;
    final delaiCarence = _calculateWaitingDays(
      annualInsuredEarnings: gainRetenu * 12,
      hasMaintenanceDuty: hasChildren,
    );

    // 6. Chiffre choc
    final perteMensuelle = gainAssureMensuel - indemniteMensuelle;
    final pctPerte = ((perteMensuelle / gainAssureMensuel) * 100).round();
    final premierEclairage =
        'Tu perdras ~${formatChf(perteMensuelle)}/mois ' // lint-ignore
        'soit $pctPerte% de ton salaire'; // lint-ignore

    return UnemploymentResult(
      eligible: true,
      tauxIndemnite: taux,
      gainAssureRetenu: gainRetenu,
      indemniteJournaliere: indemniteJournaliere,
      indemniteMensuelle: indemniteMensuelle,
      nombreIndemnites: nombreIndemnites,
      dureeMois: dureeMois,
      delaiCarenceJours: delaiCarence,
      perteMensuelle: perteMensuelle,
      premierEclairage: premierEclairage,
      timeline: _buildTimeline(delaiCarence),
    );
  }

  /// Determine indemnity rate based on salary, children, disability.
  static double _determineRate(double gain, bool children, bool disability) {
    if (children || disability || gain < _salaryThresholdEnhanced) {
      return _rateEnhanced;
    }
    return _rateBase;
  }

  /// Calculate the number of daily indemnities based on LACI duration bands.
  ///
  /// Source: ch.ch unemployment duration table / SECO brochure "Etre au
  /// chomage": 12-<18 months -> 260, 18-24 -> 400, 22-24 with 55+ or IV >=40%
  /// -> 520; +120 only with 22+ months within four years before AVS reference
  /// age; under 25 without maintenance duty stays capped at 200.
  static int _calculateDuration({
    required int age,
    required int moisCotisation,
    required bool hasChildren,
    required bool hasDisability,
    required bool isWithinFourYearsOfAvsReferenceAge,
  }) {
    // Treat a declared invalidity pension >=40% as the senior-duration exception
    // before applying the under-25/no-maintenance cap.
    if (moisCotisation >= 22 &&
        (age >=
                reg('ac.senior_age_threshold', acAgeSeuillSenior.toDouble())
                    .toInt() ||
            hasDisability)) {
      return UnemploymentFinancialFacts.withNearAvsExtraDays(
        baseDays: reg('ac.senior_days', acJoursSenior.toDouble()).toInt(),
        contributionMonths: moisCotisation,
        nearAvsReferenceAge: isWithinFourYearsOfAvsReferenceAge,
      );
    }
    if (age < 25 && !hasChildren) {
      return UnemploymentFinancialFacts.withNearAvsExtraDays(
        baseDays: reg('ac.min_days', acJoursMinCotisation.toDouble()).toInt(),
        contributionMonths: moisCotisation,
        nearAvsReferenceAge: isWithinFourYearsOfAvsReferenceAge,
      );
    }
    if (moisCotisation >= 18) {
      return UnemploymentFinancialFacts.withNearAvsExtraDays(
        baseDays: reg('ac.standard_days', acJoursStandard.toDouble()).toInt(),
        contributionMonths: moisCotisation,
        nearAvsReferenceAge: isWithinFourYearsOfAvsReferenceAge,
      );
    }
    if (moisCotisation >= 12) {
      return UnemploymentFinancialFacts.withNearAvsExtraDays(
        baseDays: reg('ac.intermediate_days',
                acJoursIntermediaireCotisation.toDouble())
            .toInt(),
        contributionMonths: moisCotisation,
        nearAvsReferenceAge: isWithinFourYearsOfAvsReferenceAge,
      );
    }
    return 0;
  }

  static int _calculateWaitingDays({
    required double annualInsuredEarnings,
    required bool hasMaintenanceDuty,
  }) =>
      UnemploymentFinancialFacts.generalWaitingDays(
        annualInsuredEarnings: annualInsuredEarnings,
        hasMaintenanceDuty: hasMaintenanceDuty,
      );

  /// Build the unemployment action timeline.
  static List<UnemploymentTimelineItem> _buildTimeline([int waitingDays = 5]) {
    final timeline = [
      const UnemploymentTimelineItem(
        jour: 0,
        action: 'Inscription ORP',
        description:
            'S\'inscrire a l\'Office regional de placement', // lint-ignore
        urgence: 'immediate',
      ),
      const UnemploymentTimelineItem(
        jour: 1,
        action: 'Demande d\'indemnites',
        description:
            'Deposer le dossier aupres de la caisse de chomage', // lint-ignore
        urgence: 'immediate',
      ),
      UnemploymentTimelineItem(
        jour: waitingDays,
        action: 'Fin delai de carence', // lint-ignore
        description:
            'Le délai d’attente général dépend du revenu assuré et de l’obligation d’entretien (OACI art. 6a / LACI art. 18)', // lint-ignore
        urgence: 'semaine1',
      ),
      const UnemploymentTimelineItem(
        jour: 7,
        action: 'Bilan budgetaire',
        description: 'Adapter ton budget au nouveau revenu', // lint-ignore
        urgence: 'semaine1',
      ),
      const UnemploymentTimelineItem(
        jour: 30,
        action: 'Transfert LPP',
        description:
            'Transferer ton avoir LPP sur un compte de libre passage', // lint-ignore
        urgence: 'mois1',
      ),
      const UnemploymentTimelineItem(
        jour: 30,
        action: 'Pause 3a',
        description:
            'Plus de cotisation 3a sans revenu lucratif', // lint-ignore
        urgence: 'mois1',
      ),
      const UnemploymentTimelineItem(
        jour: 60,
        action: 'Revision LAMal',
        description:
            'Verifier tes droits a une reduction de prime', // lint-ignore
        urgence: 'mois3',
      ),
      const UnemploymentTimelineItem(
        jour: 90,
        action: 'Bilan ORP',
        description:
            'Premier bilan avec ton ou ta spécialiste ORP', // lint-ignore
        urgence: 'mois3',
      ),
    ];
    timeline.sort((a, b) => a.jour.compareTo(b.jour));
    return timeline;
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
