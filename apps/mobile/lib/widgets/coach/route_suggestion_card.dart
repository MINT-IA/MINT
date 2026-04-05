/// RouteSuggestionCard — coach-originated navigation proposal card.
///
/// Rendered when Claude returns a `route_to_screen` tool_use block.
///
/// Design contract (MINT_UX_GRAAL_MASTERPLAN.md):
/// - The coach PROPOSES, the user DECIDES. No automatic push.
/// - Single CTA button — user must tap to navigate.
/// - Warning banner shown when readiness is partial.
/// - All text via AppLocalizations (zero hardcoded strings).
/// - MintColors, MintTextStyles, MintSpacing only — no hardcoded hex.
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
/// - [contextMessage]  — the coach's explanation from the LLM response.
/// - [route]           — the GoRouter route to push on CTA tap.
/// - [isPartial]       — when true, shows the "incomplete data" warning banner.
/// - [prefill]         — optional data to pass as GoRouter extra when navigating.
class RouteSuggestionCard extends StatelessWidget {
  final String contextMessage;
  final String route;
  final bool isPartial;
  final Map<String, dynamic>? prefill;

  const RouteSuggestionCard({
    super.key,
    required this.contextMessage,
    required this.route,
    this.isPartial = false,
    this.prefill,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(MintSpacing.sm),
        border: Border.all(color: MintColors.border),
      ),
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPartial) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.sm,
                vertical: MintSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: MintColors.warningBg,
                borderRadius: BorderRadius.circular(MintSpacing.xs),
              ),
              child: Text(
                s?.routeSuggestionPartialWarning ??
                    'Donn\u00e9es incompl\u00e8tes \u2014 les r\u00e9sultats seront estim\u00e9s',
                style: MintTextStyles.labelSmall(color: MintColors.warning),
              ),
            ),
            const SizedBox(height: MintSpacing.sm),
          ],
          if (contextMessage.isNotEmpty) ...[
            Text(
              contextMessage,
              style: MintTextStyles.bodyMedium(),
            ),
            const SizedBox(height: MintSpacing.sm),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                context.push(route, extra: prefill);
              },
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
              ),
              child: Text(
                s?.routeSuggestionCta ?? 'Voir',
                style: MintTextStyles.bodyMedium(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
