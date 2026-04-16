import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  HERO STAT CARD — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Slot 1 card: dominant financial metric with 48px display number,
// optional delta badge, and deep-link tap.
//
// Visual contract: UI-SPEC Card 1
//   MintSurface(blanc) > Column[label > value 48px > narrative > delta]
//
// Design: StatelessWidget, MintColors/MintTextStyles/MintSpacing only.
// ────────────────────────────────────────────────────────────

/// Hero stat card showing the single most impactful metric.
///
/// Always slot 1 in the Aujourd'hui feed. Shows a 48px display number
/// with label, narrative explanation, and optional delta badge.
class HeroStatCard extends StatelessWidget {
  /// The hero card data to display.
  final ContextualHeroCard card;

  /// Optional tap callback (overrides default deep-link navigation).
  final VoidCallback? onTap;

  const HeroStatCard({
    required this.card,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${card.label}: ${card.value}',
      child: GestureDetector(
        onTap: onTap ?? () => context.push(card.route),
        child: MintSurface(
          tone: MintSurfaceTone.blanc,
          padding: const EdgeInsets.all(MintSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Label ──
              Text(
                card.label,
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textMuted,
                ),
              ),

              const SizedBox(height: MintSpacing.sm),

              // ── Value (48px display number) ──
              Text(
                card.value,
                style: MintTextStyles.displayLarge(
                  color: MintColors.textPrimary,
                ),
              ),

              const SizedBox(height: MintSpacing.sm),

              // ── Narrative ──
              Text(
                card.narrative,
                style: MintTextStyles.bodyLarge(
                  color: MintColors.textSecondary,
                ),
              ),

              // ── Delta badge (optional) ──
              if (card.deltaPercent != null) ...[
                const SizedBox(height: MintSpacing.sm),
                _DeltaBadge(
                  deltaPercent: card.deltaPercent!,
                  direction: card.deltaDirection,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Delta badge showing percentage change with directional icon.
class _DeltaBadge extends StatelessWidget {
  final double deltaPercent;
  final DeltaDirection direction;

  const _DeltaBadge({
    required this.deltaPercent,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = direction == DeltaDirection.up;
    final color = isPositive ? MintColors.success : MintColors.warning;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: MintSpacing.xs),
        Text(
          '${deltaPercent.toStringAsFixed(1)}\u00a0%',
          style: MintTextStyles.bodyMedium(color: color),
        ),
      ],
    );
  }
}
