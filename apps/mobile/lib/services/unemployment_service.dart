import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';

// ────────────────────────────────────────────────────────────
//  UNEMPLOYMENT SERVICE — Sprint S19 / Chomage (LACI) + Premier emploi
// ────────────────────────────────────────────────────────────
//
// Pure Dart service for unemployment benefits (LACI art. 28-30).
//   1. calculateBenefits — eligibility, rate, duration, timeline
//
// All constants match the backend exactly.
// No banned terms ("garanti", "certain", "assuré", "sans risque").
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
      reg('ac.max_insured_salary', acPlafondSalaireAssure) / 12;

  /// Salary threshold for enhanced rate (CHF 3'797).
  static double get _salaryThresholdEnhanced =>
      reg('ac.enhanced_rate_threshold', acSeuilSalaireMajore);

  /// Standard waiting period (5 days).
  static const int _delaiCarenceStandard = 5;

  /// Working days per month.
  static const double _workingDaysPerMonth = 21.75;

  // ════════════════════════════════════════════════════════════
  //  CALCULATION
  // ════════════════════════════════════════════════════════════

  /// Calculate unemployment benefits (LACI art. 28-30).
  static UnemploymentResult calculateBenefits({
    required double gainAssureMensuel,
    required int age,
    required int moisCotisation,
    bool hasChildren = false,
    bool hasDisability = false,
  }) {
    // 0. Validate gain assure > 0 (aligned with backend)
    if (gainAssureMensuel <= 0) {
      return UnemploymentResult(
        eligible: false,
        raisonNonEligible:
            'Le gain assuré mensuel doit être supérieur à 0 CHF. '
            'Vérifie le montant de ton dernier salaire.',
        tauxIndemnite: 0,
        gainAssureRetenu: 0,
        indemniteJournaliere: 0,
        indemniteMensuelle: 0,
        nombreIndemnites: 0,
        dureeMois: 0,
        delaiCarenceJours: _delaiCarenceStandard,
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
            'Minimum 12 mois de cotisation requis (tu as $moisCotisation mois)',
        tauxIndemnite: 0,
        gainAssureRetenu: 0,
        indemniteJournaliere: 0,
        indemniteMensuelle: 0,
        nombreIndemnites: 0,
        dureeMois: 0,
        delaiCarenceJours: _delaiCarenceStandard,
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
    final nombreIndemnites = _calculateDuration(age, moisCotisation,
        hasChildren: hasChildren, hasDisability: hasDisability);
    final dureeMois = nombreIndemnites / _workingDaysPerMonth;

    // 6. Chiffre choc
    final perteMensuelle = gainAssureMensuel - indemniteMensuelle;
    final pctPerte = ((1 - taux) * 100).toStringAsFixed(0);
    final premierEclairage = 'Tu perdras ~${formatChf(perteMensuelle)}/mois '
        'soit $pctPerte% de ton salaire';

    return UnemploymentResult(
      eligible: true,
      tauxIndemnite: taux,
      gainAssureRetenu: gainRetenu,
      indemniteJournaliere: indemniteJournaliere,
      indemniteMensuelle: indemniteMensuelle,
      nombreIndemnites: nombreIndemnites,
      dureeMois: dureeMois,
      delaiCarenceJours: _delaiCarenceStandard,
      perteMensuelle: perteMensuelle,
      premierEclairage: premierEclairage,
      timeline: _buildTimeline(),
    );
  }

  /// Determine indemnity rate based on salary, children, disability.
  ///
  /// Borne INCLUSIVE (review #986) : le SECO donne 80% lorsque le gain
  /// assuré NE DÉPASSE PAS 3'797 CHF (OACI art. 33) — un gain d'exactement
  /// 3'797 touche 80%.
  static double _determineRate(double gain, bool children, bool disability) {
    if (children || disability || gain <= _salaryThresholdEnhanced) {
      return _rateEnhanced;
    }
    return _rateBase;
  }

  /// Nombre d'indemnités journalières — barème OFFICIEL LACI art. 27.
  ///
  /// Beads MINT_nosync-4za : l'ancien mapping servait 260 jours pour
  /// 18 mois (officiel : 400) et 200 pour 12 mois (officiel : 260) —
  /// sous-estimation systématique du droit de l'utilisateur.
  /// [hasChildren] proxy de l'obligation d'entretien pour le plafond
  /// jeunes (< 25 ans sans obligation → 200 jours max). [hasDisability]
  /// ouvre aussi les 520 jours (let. c : 22 mois ET (55 ans OU invalidité
  /// >= 40%)) — review #986. Cas non modélisés (dits, pas « inéligibles ») :
  /// libérés de cotisation (art. 14, 90-180 jours) et 120 jours
  /// supplémentaires en fin de droit avant la retraite (art. 27 al. 3).
  static int _calculateDuration(int age, int moisCotisation,
      {bool hasChildren = false, bool hasDisability = false}) {
    int base;
    if (moisCotisation >= 22 &&
        (hasDisability ||
            age >=
                reg('ac.senior_age_threshold', acAgeSeuillSenior.toDouble())
                    .toInt())) {
      base = reg('ac.days_22_months_senior', acJours22MoisSenior.toDouble())
          .toInt(); // 520 (al. 2 let. c)
    } else if (moisCotisation >= 18) {
      base = reg('ac.days_18_months', acJours18MoisCotisation.toDouble())
          .toInt(); // 400 (al. 2 let. b)
    } else if (moisCotisation >= 12) {
      base = reg('ac.days_12_months', acJours12MoisCotisation.toDouble())
          .toInt(); // 260 (al. 2 let. a)
    } else {
      // Moins de 12 mois : droit NON MODÉLISÉ ici (les libérés de
      // cotisation art. 14 LACI ont un droit réel de 90-180 jours).
      return 0;
    }
    if (age < 25 && !hasChildren) {
      final cap =
          reg('ac.days_under25_cap', acJoursPlafondJeunes.toDouble()).toInt();
      return base > cap ? cap : base;
    }
    return base;
  }

  /// Build the unemployment action timeline.
  static List<UnemploymentTimelineItem> _buildTimeline() {
    return const [
      UnemploymentTimelineItem(
        jour: 0,
        action: 'Inscription ORP',
        description: 'S\'inscrire a l\'Office regional de placement',
        urgence: 'immediate',
      ),
      UnemploymentTimelineItem(
        jour: 1,
        action: 'Demande d\'indemnites',
        description: 'Deposer le dossier aupres de la caisse de chomage',
        urgence: 'immediate',
      ),
      UnemploymentTimelineItem(
        jour: 5,
        action: 'Fin delai de carence',
        description: 'Les 5 premiers jours ne sont pas indemnises',
        urgence: 'semaine1',
      ),
      UnemploymentTimelineItem(
        jour: 7,
        action: 'Bilan budgetaire',
        description: 'Adapter ton budget au nouveau revenu',
        urgence: 'semaine1',
      ),
      UnemploymentTimelineItem(
        jour: 30,
        action: 'Transfert LPP',
        description: 'Transferer ton avoir LPP sur un compte de libre passage',
        urgence: 'mois1',
      ),
      UnemploymentTimelineItem(
        jour: 30,
        action: 'Pause 3a',
        description: 'Plus de cotisation 3a sans revenu lucratif',
        urgence: 'mois1',
      ),
      UnemploymentTimelineItem(
        jour: 60,
        action: 'Revision LAMal',
        description: 'Verifier tes droits a une reduction de prime',
        urgence: 'mois3',
      ),
      UnemploymentTimelineItem(
        jour: 90,
        action: 'Bilan ORP',
        description: 'Premier bilan avec ton ou ta spécialiste ORP',
        urgence: 'mois3',
      ),
    ];
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
