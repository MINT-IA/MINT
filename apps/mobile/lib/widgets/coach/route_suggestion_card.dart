/// RouteSuggestionCard — coach-originated navigation proposal card.
///
/// Rendered when Claude returns a `route_to_screen` tool_use block and the
/// [RoutePlanner] resolves to [RouteAction.openScreen] or
/// [RouteAction.openWithWarning].
///
/// Design contract (MINT_UX_GRAAL_MASTERPLAN.md):
/// - The coach PROPOSES, the user DECIDES. No automatic push.
/// - Single CTA button — user must tap to navigate.
/// - Warning banner shown when readiness is partial.
/// - All text via AppLocalizations (zero hardcoded strings).
/// - MintColors, MintTextStyles, MintSpacing only — no hardcoded hex.
///
/// See docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §7
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ════════════════════════════════════════════════════════════════
//  ROUTE SUGGESTION CARD
// ════════════════════════════════════════════════════════════════

/// A card rendered in the coach chat when Claude suggests navigating to a
/// screen.
///
/// Parameters:
/// - [contextMessage] — the coach's explanation from the LLM response.
/// - [route]          — the GoRouter route to push on CTA tap.
/// - [isPartial]      — when true, shows the "incomplete data" warning banner.
/// - [onReturn]       — called after the user returns from the target screen.
///
/// Usage:
/// ```dart
/// RouteSuggestionCard(
///   contextMessage: 'Voici ton simulateur rente vs capital.',
///   route: '/rente-vs-capital',
///   isPartial: true,
///   onReturn: () { /* acknowledge return */ },
/// )
/// ```
class RouteSuggestionCard extends StatelessWidget {
  /// The coach's narrative message explaining why this screen is relevant.
  final String contextMessage;

  /// The canonical GoRouter route to navigate to on CTA tap.
  final String route;

  /// When true, renders a yellow warning banner ("Estimation — données
  /// incomplètes") to inform the user that some data is missing.
  final bool isPartial;

  /// Called after [context.push(route)] completes (i.e. user comes back).
  ///
  /// The card calls [onReturn] in the `.then()` of the push so the parent
  /// chat screen can add a coach acknowledgement message.
  final VoidCallback? onReturn;

  const RouteSuggestionCard({
    super.key,
    required this.contextMessage,
    required this.route,
    this.isPartial = false,
    this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.coachAccent.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Partial-readiness warning banner ─────────────────────
          if (isPartial) _PartialWarningBanner(label: s.routeSuggestionPartialWarning),

          // ── Context message ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MintSpacing.md,
              MintSpacing.md,
              MintSpacing.md,
              MintSpacing.sm,
            ),
            child: Text(
              contextMessage,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
          ),

          // ── CTA row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MintSpacing.md,
              0,
              MintSpacing.md,
              MintSpacing.md,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: _CtaButton(
                label: s.routeSuggestionCta,
                onTap: () => _navigateAndReturn(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateAndReturn(BuildContext context) async {
    await context.push(route);
    if (context.mounted) {
      onReturn?.call();
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  PRIVATE HELPERS
// ════════════════════════════════════════════════════════════════

/// Yellow warning banner shown when readiness is partial.
class _PartialWarningBanner extends StatelessWidget {
  final String label;
  const _PartialWarningBanner({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.md,
        vertical: MintSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: MintColors.warningBgWarm,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: MintColors.warning.withValues(alpha: 0.9),
          ),
          const SizedBox(width: MintSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.labelSmall(
                color: MintColors.warning.withValues(alpha: 0.9),
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filled CTA button for the navigation action.
class _CtaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CtaButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: MintColors.coachAccent,
        foregroundColor: MintColors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.md,
          vertical: MintSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        textStyle: MintTextStyles.labelSmall(color: MintColors.white)
            .copyWith(fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.arrow_forward, size: 16),
      label: Text(label),
    );
  }
}
