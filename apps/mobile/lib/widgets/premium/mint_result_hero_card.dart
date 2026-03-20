import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// A revelation card that shows the consequence of a financial situation.
///
/// Used in Quick Start (first retirement preview) and Decision Canvas
/// screens (rente vs capital comparison). The primary value is the
/// emotional center of the screen — large, warm, undeniable.
///
/// Structure:
/// - eyebrow label (small, muted)
/// - primary value (displayMedium, dominant)
/// - primary label
/// - optional secondary value + label (comparison)
/// - narrative sentence (the "so what")
class MintResultHeroCard extends StatelessWidget {
  final String eyebrow;
  final String primaryValue;
  final String primaryLabel;
  final String? secondaryValue;
  final String? secondaryLabel;
  final String narrative;
  final Color accentColor;
  final MintSurfaceTone tone;

  const MintResultHeroCard({
    super.key,
    required this.eyebrow,
    required this.primaryValue,
    required this.primaryLabel,
    this.secondaryValue,
    this.secondaryLabel,
    required this.narrative,
    this.accentColor = MintColors.textPrimary,
    this.tone = MintSurfaceTone.porcelaine,
  });

  @override
  Widget build(BuildContext context) {
    return MintSurface(
      tone: tone,
      padding: const EdgeInsets.all(MintSpacing.lg + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow
          Text(
            eyebrow,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.lg),

          // Primary value — the star
          Text(
            primaryValue,
            style: MintTextStyles.displayMedium(color: accentColor)
                .copyWith(fontSize: 36, height: 1.0),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            primaryLabel,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),

          // Secondary comparison
          if (secondaryValue != null && secondaryLabel != null) ...[
            const SizedBox(height: MintSpacing.lg),
            Divider(
              color: MintColors.border.withValues(alpha: 0.3),
              height: 1,
            ),
            const SizedBox(height: MintSpacing.lg),
            Text(
              secondaryValue!,
              style: MintTextStyles.headlineMedium(
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              secondaryLabel!,
              style: MintTextStyles.bodySmall(color: MintColors.textMuted),
            ),
          ],

          // Narrative — the "so what"
          const SizedBox(height: MintSpacing.lg),
          Text(
            narrative,
            style: MintTextStyles.bodyLarge(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w500, height: 1.4),
          ),
        ],
      ),
    );
  }
}
