import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// A calm, narrative card for the Cap du jour, insights, or stories.
///
/// Shows: headline + why now + CTA. Minimal, warm, no border.
/// Inspired by Cleo's goal cards ("Build a solid emergency fund").
class MintNarrativeCard extends StatelessWidget {
  final String headline;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onTap;
  final MintSurfaceTone tone;
  final Widget? leading;
  final String? badge;

  const MintNarrativeCard({
    super.key,
    required this.headline,
    required this.body,
    this.ctaLabel,
    this.onTap,
    this.tone = MintSurfaceTone.sauge,
    this.leading,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MintSurface(
        tone: tone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: MintColors.textPrimary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: MintSpacing.md),
            ],
            if (leading != null) ...[
              leading!,
              const SizedBox(height: MintSpacing.md),
            ],
            Text(
              headline,
              style: MintTextStyles.headlineMedium(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              body,
              style: MintTextStyles.bodyMedium(
                color: MintColors.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (ctaLabel != null) ...[
              const SizedBox(height: MintSpacing.lg),
              Row(
                children: [
                  Text(
                    ctaLabel!,
                    style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: MintColors.textPrimary,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
