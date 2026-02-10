import 'dart:math';

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
  final String chiffreChoc;
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
    required this.chiffreChoc,
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
  static const double _gainAssureMax = 12350.0;

  /// Salary threshold for enhanced rate (CHF 3'797).
  static const double _salaryThresholdEnhanced = 3797.0;

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
        chiffreChoc: '',
        timeline: _buildTimeline(),
      );
    }

    // 2. Determine rate
    final taux =
        _determineRate(gainAssureMensuel, hasChildren, hasDisability);

    // 3. Cap gain assure
    final gainRetenu = min(gainAssureMensuel, _gainAssureMax);

    // 4. Calculate benefits
    final indemniteJournaliere =
        (gainRetenu * taux) / _workingDaysPerMonth;
    final indemniteMensuelle =
        indemniteJournaliere * _workingDaysPerMonth;

    // 5. Duration
    final nombreIndemnites = _calculateDuration(age, moisCotisation);
    final dureeMois = nombreIndemnites / _workingDaysPerMonth;

    // 6. Chiffre choc
    final perteMensuelle = gainAssureMensuel - indemniteMensuelle;
    final pctPerte = ((1 - taux) * 100).toStringAsFixed(0);
    final chiffreChoc =
        'Tu perdras ~${formatChf(perteMensuelle)}/mois '
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
      chiffreChoc: chiffreChoc,
      timeline: _buildTimeline(),
    );
  }

  /// Determine indemnity rate based on salary, children, disability.
  static double _determineRate(
      double gain, bool children, bool disability) {
    if (children || disability || gain < _salaryThresholdEnhanced) {
      return _rateEnhanced;
    }
    return _rateBase;
  }

  /// Calculate the number of daily indemnities based on age and contributions.
  static int _calculateDuration(int age, int moisCotisation) {
    if (age >= 60 && moisCotisation >= 22) return 520;
    if (age >= 55 && moisCotisation >= 22) return 400;
    if (age >= 25 && moisCotisation >= 18) return 260;
    if (moisCotisation >= 12) return 200;
    return 0;
  }

  /// Build the unemployment action timeline.
  static List<UnemploymentTimelineItem> _buildTimeline() {
    return const [
      UnemploymentTimelineItem(
        jour: 0,
        action: 'Inscription ORP',
        description:
            'S\'inscrire a l\'Office regional de placement',
        urgence: 'immediate',
      ),
      UnemploymentTimelineItem(
        jour: 1,
        action: 'Demande d\'indemnites',
        description:
            'Deposer le dossier aupres de la caisse de chomage',
        urgence: 'immediate',
      ),
      UnemploymentTimelineItem(
        jour: 5,
        action: 'Fin delai de carence',
        description:
            'Les 5 premiers jours ne sont pas indemnises',
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
        description:
            'Transferer ton avoir LPP sur un compte de libre passage',
        urgence: 'mois1',
      ),
      UnemploymentTimelineItem(
        jour: 30,
        action: 'Pause 3a',
        description:
            'Plus de cotisation 3a sans revenu lucratif',
        urgence: 'mois1',
      ),
      UnemploymentTimelineItem(
        jour: 60,
        action: 'Revision LAMal',
        description:
            'Verifier tes droits a une reduction de prime',
        urgence: 'mois3',
      ),
      UnemploymentTimelineItem(
        jour: 90,
        action: 'Bilan ORP',
        description: 'Premier bilan avec ton conseiller ORP',
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
