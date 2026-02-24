/// Reengagement Engine — Sprint S40.
///
/// Generates personalized reengagement messages based on calendar
/// triggers and user financial data.
///
/// NEVER generic. Every message contains:
///   - A personal number (CHF or %)
///   - A time constraint (deadline, window)
///   - A deeplink to relevant simulation
///
/// BANNED:
/// - "Tu n'as pas utilise MINT depuis X jours"
/// - "Reviens decouvrir nos nouvelles fonctionnalites!"
/// - "Tu nous manques!"
///
/// Sources:
/// - OPP3 art. 7 (plafond 3a)
/// - LIFD art. 38 (taxation du capital)
/// - LPD art. 6 (principes de traitement)
library;

// ────────────────────────────────────────────────────────────
//  REENGAGEMENT ENGINE — S40 / Reengagement + Consent
// ────────────────────────────────────────────────────────────
//
// Service purement deterministe : genere des ReengagementMessage
// a partir des donnees du profil et de la date courante.
//
// Calendar mapping:
//   Jan  → Nouveaux plafonds 3a
//   Feb  → Preparation declaration fiscale
//   Mar  → Deadline declaration (canton-dependent)
//   Oct  → Countdown 3a (jours restants)
//   Nov  → Countdown 3a + economie estimee
//   Dec  → Dernier mois 3a
//   Q    → Score FRI trimestriel
//
// Conventions :
//   - Montants CHF formated avec apostrophe suisse (1'820)
//   - Toujours un chiffre personnel + contrainte temporelle + deeplink
//   - Ton pedagogique, tutoiement, pas de termes bannis
// ────────────────────────────────────────────────────────────

/// Calendar trigger types for reengagement messages.
enum ReengagementTrigger {
  /// January: new 3a ceilings for the year.
  newYear,

  /// February: tax declaration preparation.
  taxPrep,

  /// March: cantonal tax deadline approaching.
  taxDeadline,

  /// October: 3a countdown (~92 days remaining).
  threeACountdown,

  /// November: 3a urgency (~61 days + saving amount).
  threeAUrgency,

  /// December: final month for 3a contributions.
  threeAFinal,

  /// Quarterly: FRI score check-in.
  quarterlyFri,
}

/// A personalized reengagement message with personal number,
/// time constraint, and deeplink.
class ReengagementMessage {
  /// The calendar trigger that generated this message.
  final ReengagementTrigger trigger;

  /// Short title (displayed as notification/card title).
  final String title;

  /// Body text with personal number and time constraint.
  final String body;

  /// Deeplink route for GoRouter navigation on tap.
  final String deeplink;

  /// Personal number embedded in the body (e.g. "CHF 1'820").
  final String personalNumber;

  /// Time constraint embedded in the body (e.g. "92 jours").
  final String timeConstraint;

  /// Month this message applies to (1-12).
  final int month;

  const ReengagementMessage({
    required this.trigger,
    required this.title,
    required this.body,
    required this.deeplink,
    required this.personalNumber,
    required this.timeConstraint,
    required this.month,
  });
}

/// Pure, deterministic reengagement message generator.
///
/// Generates [ReengagementMessage] objects based on the current date
/// and user financial data. Each message contains a personal number,
/// a time constraint, and a deeplink — never generic encouragement.
class ReengagementEngine {
  ReengagementEngine._();

  /// Generate applicable messages for the current date.
  ///
  /// [today] — override for testing (defaults to DateTime.now()).
  /// [canton] — user's canton for tax deadline (default 'VD').
  /// [taxSaving3a] — estimated annual tax saving from 3a (CHF).
  /// [friTotal] — current FRI score (0-100).
  /// [friDelta] — FRI score change since last quarter.
  ///
  /// Returns a list of [ReengagementMessage] applicable to the
  /// current month. Multiple messages may apply (e.g. quarterly + monthly).
  static List<ReengagementMessage> generateMessages({
    DateTime? today,
    String canton = 'VD',
    double taxSaving3a = 0,
    double friTotal = 0,
    double friDelta = 0,
  }) {
    final now = today ?? DateTime.now();
    final month = now.month;
    final savingStr = _formatChf(taxSaving3a);
    final messages = <ReengagementMessage>[];

    // ── January: Nouveaux plafonds 3a ────────────────────────
    if (month == 1) {
      messages.add(ReengagementMessage(
        trigger: ReengagementTrigger.newYear,
        title: 'Nouveaux plafonds 3a',
        body: 'Nouveaux plafonds 3a : CHF 7\'258. '
            'Ton economie potentielle : CHF $savingStr.',
        deeplink: '/simulator/3a',
        personalNumber: 'CHF $savingStr',
        timeConstraint: 'Annee ${now.year}',
        month: 1,
      ));
    }

    // ── February: Preparation declaration fiscale ────────────
    if (month == 2) {
      messages.add(ReengagementMessage(
        trigger: ReengagementTrigger.taxPrep,
        title: 'Declaration fiscale',
        body: 'Prepare ta declaration : tes chiffres cles sont disponibles.',
        deeplink: '/home',
        personalNumber: 'CHF $savingStr',
        timeConstraint: 'Avant le 31 mars',
        month: 2,
      ));
    }

    // ── March: Deadline canton ───────────────────────────────
    if (month == 3) {
      final daysLeft = _daysUntilEndOfMonth(now);
      messages.add(ReengagementMessage(
        trigger: ReengagementTrigger.taxDeadline,
        title: 'Deadline fiscale',
        body: 'Deadline canton de $canton : '
            'il reste $daysLeft jours.',
        deeplink: '/home',
        personalNumber: 'CHF $savingStr',
        timeConstraint: '$daysLeft jours',
        month: 3,
      ));
    }

    // ── October: 3a countdown ────────────────────────────────
    if (month == 10) {
      final daysLeft = _daysUntilEndOfYear(now);
      messages.add(ReengagementMessage(
        trigger: ReengagementTrigger.threeACountdown,
        title: 'Deadline 3a',
        body: 'Il reste $daysLeft jours pour verser ton 3a.',
        deeplink: '/simulator/3a',
        personalNumber: 'CHF $savingStr',
        timeConstraint: '$daysLeft jours',
        month: 10,
      ));
    }

    // ── November: 3a urgency ─────────────────────────────────
    if (month == 11) {
      final daysLeft = _daysUntilEndOfYear(now);
      messages.add(ReengagementMessage(
        trigger: ReengagementTrigger.threeAUrgency,
        title: 'Deadline 3a',
        body: 'Il reste $daysLeft jours. '
            'Economie estimee : CHF $savingStr.',
        deeplink: '/simulator/3a',
        personalNumber: 'CHF $savingStr',
        timeConstraint: '$daysLeft jours',
        month: 11,
      ));
    }

    // ── December: 3a final ───────────────────────────────────
    if (month == 12) {
      messages.add(ReengagementMessage(
        trigger: ReengagementTrigger.threeAFinal,
        title: 'Dernier mois 3a',
        body: 'Dernier mois. CHF $savingStr d\'economie en jeu.',
        deeplink: '/simulator/3a',
        personalNumber: 'CHF $savingStr',
        timeConstraint: 'Dernier mois',
        month: 12,
      ));
    }

    // ── Quarterly FRI (January, April, July, October — aligned with backend)
    if ([1, 4, 7, 10].contains(month)) {
      final friStr = friTotal.toStringAsFixed(0);
      final deltaSign = friDelta >= 0 ? '+' : '';
      final deltaStr = '$deltaSign${friDelta.toStringAsFixed(0)}';
      messages.add(ReengagementMessage(
        trigger: ReengagementTrigger.quarterlyFri,
        title: 'Score de solidite',
        body: 'Ton score de solidite : $friStr '
            '($deltaStr ce trimestre).',
        deeplink: '/coach/dashboard',
        personalNumber: '$friStr points',
        timeConstraint: 'Ce trimestre',
        month: month,
      ));
    }

    return messages;
  }

  // ── Formatting helpers ─────────────────────────────────────

  /// Format a CHF amount with Swiss apostrophe as thousands separator.
  ///
  /// Example: 1820.5 -> "1'820", 7258.0 -> "7'258"
  static String _formatChf(double amount) {
    final intStr = amount.toStringAsFixed(0);
    return intStr.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}\'',
    );
  }

  /// Days remaining until end of the current month.
  static int _daysUntilEndOfMonth(DateTime date) {
    final lastDay = DateTime(date.year, date.month + 1, 0);
    return lastDay.day - date.day;
  }

  /// Days remaining until December 31 of the current year.
  static int _daysUntilEndOfYear(DateTime date) {
    final endOfYear = DateTime(date.year, 12, 31);
    return endOfYear.difference(date).inDays;
  }
}
