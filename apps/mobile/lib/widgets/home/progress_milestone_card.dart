import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/coach/animated_progress_bar.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  PROGRESS MILESTONE CARD — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Shows a progress milestone with animated bar on peche surface.
//
// Visual contract: UI-SPEC Card 3
//   MintSurface(peche) > Column[icon+title > description > AnimatedProgressBar]
//
// Design: StatelessWidget, MintColors/MintTextStyles/MintSpacing only.
// ────────────────────────────────────────────────────────────

/// Progress milestone card with animated progress bar.
///
/// Shows profile completeness or biography milestones.
class ProgressMilestoneCard extends StatelessWidget {
  /// The progress card data to display.
  final ContextualProgressCard card;

  /// Optional tap callback (overrides default deep-link navigation).
  final VoidCallback? onTap;

  const ProgressMilestoneCard({
    required this.card,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${card.title}, ${card.percent.toInt()}\u00a0%',
      child: GestureDetector(
        onTap: onTap ?? () => context.push(card.route),
        child: MintSurface(
          tone: MintSurfaceTone.peche,
          padding: const EdgeInsets.all(MintSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon + Title row ──
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    size: 24,
                    color: MintColors.textPrimary,
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Text(
                      card.title,
                      style: MintTextStyles.bodyLarge(
                        color: MintColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: MintSpacing.sm),

              // ── Description ──
              Text(
                card.description,
                style: MintTextStyles.bodyLarge(
                  color: MintColors.textSecondary,
                ),
              ),

              const SizedBox(height: 12),

              // ── Animated progress bar ──
              AnimatedProgressBar(
                progress: card.percent / 100,
                color: MintColors.success,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
