import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  ANTICIPATION SIGNAL CARD — Phase 04 / Moteur d'Anticipation
// ────────────────────────────────────────────────────────────
//
// Educational card for proactive anticipation signals on
// the Aujourd'hui tab (ANT-03 format).
//
// Structure:
//   Icon + Title
//   Educational fact (body text)
//   Legal source reference
//   "En savoir plus" CTA -> simulator
//   "Compris" / "Plus tard" dismiss/snooze buttons
//
// All text via AppLocalizations (zero hardcoded strings).
// ────────────────────────────────────────────────────────────

/// A card displaying a single anticipation signal with educational format.
///
/// Shows title, educational fact, legal source reference,
/// and action buttons (CTA, dismiss, snooze).
///
/// Follows MintSurface pattern for premium visual consistency.
class AnticipationSignalCard extends StatelessWidget {
  /// The anticipation signal to display.
  final AnticipationSignal signal;

  /// Called when user taps "Compris" (Got it) — dismisses the signal.
  final VoidCallback onDismiss;

  /// Called when user taps "Plus tard" (Remind me later) — snoozes the signal.
  final VoidCallback onSnooze;

  const AnticipationSignalCard({
    required this.signal,
    required this.onDismiss,
    required this.onSnooze,
    super.key,
  });

  /// Map template type to a semantic icon.
  IconData _iconForTemplate(AlertTemplate template) {
    switch (template) {
      case AlertTemplate.fiscal3aDeadline:
        return Icons.savings_outlined;
      case AlertTemplate.cantonalTaxDeadline:
        return Icons.description_outlined;
      case AlertTemplate.lppRachatWindow:
        return Icons.account_balance_outlined;
      case AlertTemplate.salaryIncrease3aRecalc:
        return Icons.trending_up_outlined;
      case AlertTemplate.ageMilestoneLppBonification:
        return Icons.cake_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title row: Icon + Title ──
          Row(
            children: [
              Icon(
                _iconForTemplate(signal.template),
                size: 20,
                color: MintColors.primary,
              ),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  _resolveTitle(l),
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: MintSpacing.sm),

          // ── Educational fact ──
          Text(
            _resolveFact(l),
            style: MintTextStyles.bodySmall(
              color: MintColors.textSecondary,
            ),
          ),

          const SizedBox(height: MintSpacing.xs),

          // ── Source reference ──
          Text(
            signal.sourceRef,
            style: MintTextStyles.micro(
              color: MintColors.textMuted,
            ),
          ),

          const SizedBox(height: MintSpacing.sm),

          // ── CTA: En savoir plus ──
          GestureDetector(
            onTap: () => context.push(signal.simulatorLink),
            child: Text(
              l.anticipationLearnMore,
              style: MintTextStyles.bodySmall(
                color: MintColors.primary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: MintSpacing.sm),

          // ── Dismiss / Snooze row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onSnooze,
                style: TextButton.styleFrom(
                  foregroundColor: MintColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MintSpacing.sm,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l.anticipationRemindLater,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: MintColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MintSpacing.sm,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l.anticipationGotIt,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.primary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Title/fact resolution helpers ──────────────────────────

  /// Resolve the title ARB key with parameters.
  ///
  /// Delegates to the appropriate S method based on [signal.titleKey].
  /// Falls back to the raw key if no matching method found.
  String _resolveTitle(S l) {
    final p = signal.params ?? {};
    switch (signal.titleKey) {
      case 'anticipation3aDeadlineTitle':
        return l.anticipation3aDeadlineTitle(p['days'] ?? '');
      case 'anticipationTaxDeadlineTitle':
        return l.anticipationTaxDeadlineTitle(p['canton'] ?? '');
      case 'anticipationLppRachatTitle':
        return l.anticipationLppRachatTitle;
      case 'anticipationSalaryIncreaseTitle':
        return l.anticipationSalaryIncreaseTitle;
      case 'anticipationAgeMilestoneTitle':
        return l.anticipationAgeMilestoneTitle(p['age'] ?? '');
      default:
        return signal.titleKey;
    }
  }

  /// Resolve the fact ARB key with parameters.
  String _resolveFact(S l) {
    final p = signal.params ?? {};
    switch (signal.factKey) {
      case 'anticipation3aDeadlineFact':
        return l.anticipation3aDeadlineFact(
          p['limit'] ?? '',
          p['year'] ?? '',
        );
      case 'anticipationTaxDeadlineFact':
        return l.anticipationTaxDeadlineFact(
          p['canton'] ?? '',
          p['deadline'] ?? '',
        );
      case 'anticipationLppRachatFact':
        return l.anticipationLppRachatFact;
      case 'anticipationSalaryIncreaseFact':
        return l.anticipationSalaryIncreaseFact(p['newMax'] ?? '');
      case 'anticipationAgeMilestoneFact':
        return l.anticipationAgeMilestoneFact(
          p['oldRate'] ?? '',
          p['newRate'] ?? '',
        );
      default:
        return signal.factKey;
    }
  }
}
