import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  ACTION OPPORTUNITY CARD — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Action card with chevron and deep-link tap.
//
// Visual contract: UI-SPEC Card 4
//   MintSurface(blanc) > Row[icon + Column[title+body] + chevron]
//
// Design: StatelessWidget, MintColors/MintTextStyles/MintSpacing only.
// ────────────────────────────────────────────────────────────

/// Action opportunity card with chevron deep-link.
///
/// Surfaces contextual next actions (scan document, complete profile).
class ActionOpportunityCard extends StatelessWidget {
  /// The action card data to display.
  final ContextualActionCard card;

  /// Optional tap callback (overrides default deep-link navigation).
  final VoidCallback? onTap;

  const ActionOpportunityCard({
    required this.card,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: card.title,
      child: GestureDetector(
        onTap: onTap ?? () => context.push(card.route),
        child: MintSurface(
          tone: MintSurfaceTone.blanc,
          padding: const EdgeInsets.all(MintSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                // ── Leading icon ──
                Icon(
                  card.icon,
                  size: 20,
                  color: MintColors.primary,
                ),

                const SizedBox(width: 12),

                // ── Title + body ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        card.title,
                        style: MintTextStyles.bodyMedium(
                          color: MintColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        card.body,
                        style: MintTextStyles.bodyLarge(
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Chevron ──
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: MintColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
