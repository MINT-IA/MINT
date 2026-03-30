/// Recap Formatter — Sprint S59.
///
/// Transforms a [WeeklyRecap] into display-ready [RecapSection] objects.
/// Accepts an [S] localizations instance so all text is resolved via i18n.
///
/// Pure static methods — no state, fully testable.
library;

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/utils/chf_formatter.dart' as chf_fmt;
import 'package:mint_mobile/services/recap/weekly_recap_service.dart';

// ════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════════════

/// Category of a recap display section.
enum RecapSectionType {
  /// Budget summary section.
  budget,

  /// Completed actions section.
  actions,

  /// Confidence/FRI progress section.
  progress,

  /// Key highlights section.
  highlights,

  /// Suggested next-week focus.
  nextFocus,
}

/// A single formatted section in the weekly recap screen.
class RecapSection {
  /// Section title (i18n resolved).
  final String title;

  /// Section body text (i18n resolved).
  final String content;

  /// Section category.
  final RecapSectionType type;

  const RecapSection({
    required this.title,
    required this.content,
    required this.type,
  });
}

// ════════════════════════════════════════════════════════════════════
//  FORMATTER
// ════════════════════════════════════════════════════════════════════

/// Formats a [WeeklyRecap] into display sections.
///
/// All user-visible strings are resolved through [S] (AppLocalizations),
/// so no hardcoded French text appears in the formatter layer.
class RecapFormatter {
  RecapFormatter._();

  /// Format a [WeeklyRecap] into ordered display sections.
  ///
  /// Empty sections are omitted (e.g. no budget section if [recap.budget] is null).
  ///
  /// [recap] — structured recap from [WeeklyRecapService].
  /// [l] — AppLocalizations instance (context-resolved by the caller).
  static List<RecapSection> format(WeeklyRecap recap, S l) {
    final sections = <RecapSection>[];

    // ── Budget ───────────────────────────────────────────────
    final budgetSection = _formatBudget(recap, l);
    if (budgetSection != null) sections.add(budgetSection);

    // ── Actions ──────────────────────────────────────────────
    sections.add(_formatActions(recap, l));

    // ── Progress ─────────────────────────────────────────────
    final progressSection = _formatProgress(recap, l);
    if (progressSection != null) sections.add(progressSection);

    // ── Highlights ───────────────────────────────────────────
    final highlightsSection = _formatHighlights(recap, l);
    if (highlightsSection != null) sections.add(highlightsSection);

    // ── Next week focus ──────────────────────────────────────
    final nextFocusSection = _formatNextFocus(recap, l);
    if (nextFocusSection != null) sections.add(nextFocusSection);

    return sections;
  }

  // ── Private section builders ───────────────────────────────────

  static RecapSection? _formatBudget(WeeklyRecap recap, S l) {
    final budget = recap.budget;
    if (budget == null) return null;

    final ratePct = (budget.savingsRate * 100).toStringAsFixed(1);
    final savedFormatted = chf_fmt.formatChf(budget.savedAmount);

    final content = '${l.recapBudgetSaved}: $savedFormatted CHF\n'
        '${l.recapBudgetRate}: $ratePct\u00a0%';

    return RecapSection(
      title: l.recapBudgetTitle,
      content: content,
      type: RecapSectionType.budget,
    );
  }

  static RecapSection _formatActions(WeeklyRecap recap, S l) {
    if (recap.actions.isEmpty) {
      return RecapSection(
        title: l.recapActionsTitle,
        content: l.recapActionsNone,
        type: RecapSectionType.actions,
      );
    }

    final count = recap.actions.length;
    // Group by day for a compact display
    final days = recap.actions.map((a) => _shortDate(a.completedAt)).toSet().toList();
    final content = '$count action${count > 1 ? 's' : ''} — ${days.join(', ')}';

    return RecapSection(
      title: l.recapActionsTitle,
      content: content,
      type: RecapSectionType.actions,
    );
  }

  static RecapSection? _formatProgress(WeeklyRecap recap, S l) {
    final progress = recap.progress;
    if (progress == null) return null;

    final sign = progress.delta >= 0 ? '+' : '';
    final deltaText = '$sign${progress.delta.toStringAsFixed(1)}';
    final content = l.recapProgressDelta(deltaText);

    return RecapSection(
      title: l.recapProgressTitle,
      content: content,
      type: RecapSectionType.progress,
    );
  }

  static RecapSection? _formatHighlights(WeeklyRecap recap, S l) {
    if (recap.highlights.isEmpty) return null;

    // highlights is a list of ARB key names — display the count
    final count = recap.highlights.length;
    if (count == 0) return null;

    return RecapSection(
      title: l.recapHighlightsTitle,
      content: '$count point${count > 1 ? 's' : ''} marquant${count > 1 ? 's' : ''}',
      type: RecapSectionType.highlights,
    );
  }

  static RecapSection? _formatNextFocus(WeeklyRecap recap, S l) {
    final focus = recap.nextWeekFocus;
    if (focus == null) return null;

    return RecapSection(
      title: l.recapNextFocusTitle,
      content: focus,
      type: RecapSectionType.nextFocus,
    );
  }

  // F3: _formatChf removed — use centralized chf_fmt.formatChf()

  /// Short date label (e.g. "lu.", "ma.").
  static String _shortDate(DateTime date) {
    const days = ['lu.', 'ma.', 'me.', 'je.', 've.', 'sa.', 'di.'];
    return days[date.weekday - 1];
  }
}
