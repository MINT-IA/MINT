import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/freshness_decay_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Displays a single [BiographyFact] with source badge, date,
/// freshness indicator, and edit/delete actions.
///
/// Layout:
/// - Left column: label + value
/// - Right column: edit + delete icons (48px touch targets)
/// - Bottom row: source badge + date + freshness dot
/// - Stale facts: 4px left border in [MintColors.warning]
///
/// See: BIO-05, UI-SPEC Screen 1 Fact card.
class FactCard extends StatelessWidget {
  /// The biography fact to display.
  final BiographyFact fact;

  /// Called when user taps the edit icon.
  final VoidCallback onEdit;

  /// Called when user taps the delete icon.
  final VoidCallback onDelete;

  /// Override for testability. Defaults to [DateTime.now].
  final DateTime? now;

  const FactCard({
    super.key,
    required this.fact,
    required this.onEdit,
    required this.onDelete,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final currentTime = now ?? DateTime.now();
    final weight = FreshnessDecayService.weight(fact, currentTime);
    final isStale = weight < 0.60;
    final isAging = weight < 1.0 && !isStale;
    final monthsOld =
        (currentTime.difference(fact.updatedAt).inDays / 30.44).round();

    return Container(
      decoration: isStale
          ? const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: MintColors.warning,
                  width: 4,
                ),
              ),
            )
          : null,
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: label/value + actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: label + value
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _factTypeLabel(fact.factType, l),
                        style: MintTextStyles.bodyMedium(
                          color: MintColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        fact.value,
                        style: MintTextStyles.bodyMedium(
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right column: edit + delete icons
                SizedBox(
                  width: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        iconSize: 20,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: onEdit,
                        color: MintColors.textSecondary,
                        tooltip: l.privacyControlSave,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        iconSize: 20,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: onDelete,
                        color: MintColors.error,
                        tooltip: l.privacyControlDeleteConfirm,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm),
            // Bottom row: source badge + date + freshness dot
            Wrap(
              spacing: MintSpacing.sm,
              runSpacing: MintSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Source badge
                _sourceBadge(fact.source, l),
                // Date
                Text(
                  DateFormat.yMMMd().format(fact.updatedAt),
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMuted,
                  ),
                ),
                // Freshness indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _freshnessColor(isStale, isAging),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _freshnessLabel(l, isStale, isAging, monthsOld),
                      style: MintTextStyles.labelSmall(
                        color: _freshnessColor(isStale, isAging),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Map freshness state to color.
  Color _freshnessColor(bool isStale, bool isAging) {
    if (isStale) return MintColors.error;
    if (isAging) return MintColors.warning;
    return MintColors.success;
  }

  /// Map freshness state to localized label.
  String _freshnessLabel(S l, bool isStale, bool isAging, int monthsOld) {
    if (isStale) return l.privacyControlStale(monthsOld);
    if (isAging) return l.privacyControlAging(monthsOld);
    return l.privacyControlFresh;
  }

  /// Source badge with colored background per UI-SPEC.
  Widget _sourceBadge(FactSource source, S l) {
    final String label;
    final Color color;

    switch (source) {
      case FactSource.document:
        label = l.privacyControlSourceDocument;
        color = MintColors.bleuAir;
      case FactSource.userInput:
        label = l.privacyControlSourceUserInput;
        color = MintColors.accentPastel;
      case FactSource.userEdit:
        label = l.privacyControlSourceUserEdit;
        color = MintColors.saugeClaire;
      case FactSource.coach:
        label = l.privacyControlSourceCoach;
        color = MintColors.accentPastel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
      ),
    );
  }

  /// Map [FactType] to a localized display label.
  static String _factTypeLabel(FactType type, S l) {
    switch (type) {
      case FactType.salary:
        return 'Salaire';
      case FactType.lppCapital:
        return 'Capital LPP';
      case FactType.lppRachatMax:
        return 'Rachat max LPP';
      case FactType.threeACapital:
        return 'Capital 3a';
      case FactType.avsContributionYears:
        return 'Ann\u00e9es AVS';
      case FactType.taxRate:
        return 'Taux d\u2019imposition';
      case FactType.mortgageDebt:
        return 'Dette hypoth\u00e9caire';
      case FactType.canton:
        return 'Canton';
      case FactType.civilStatus:
        return 'Statut civil';
      case FactType.employmentStatus:
        return 'Situation professionnelle';
      case FactType.lifeEvent:
        return '\u00c9v\u00e9nement de vie';
      case FactType.userDecision:
        return 'D\u00e9cision';
      case FactType.coachPreference:
        return 'Pr\u00e9f\u00e9rence coach';
      case FactType.alertAcknowledged:
        return 'Alerte reconnue';
    }
  }

  /// Get the localized label for a [FactType]. Public for use
  /// in delete dialogs and edit sheets.
  static String factLabel(FactType type, S l) => _factTypeLabel(type, l);
}
