import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// A premium surface container with warm background and subtle depth.
///
/// Replaces cold white cards with warm, textured surfaces.
/// No borders — depth comes from color difference and very subtle shadow.
enum MintSurfaceTone {
  /// Warm porcelain — for hero backgrounds.
  porcelaine,
  /// Cream — for coach/conversation backgrounds.
  craie,
  /// Sage — for positive/success surfaces (cap completed, in good shape).
  sauge,
  /// Air blue — for informational/coach surfaces.
  bleu,
  /// Peach — for warm accents, milestones, progression.
  peche,
  /// Pure white — standard card.
  blanc,
}

class MintSurface extends StatelessWidget {
  final Widget child;
  final MintSurfaceTone tone;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool elevated;

  const MintSurface({
    super.key,
    required this.child,
    this.tone = MintSurfaceTone.blanc,
    this.width,
    this.padding,
    this.radius = 20,
    this.elevated = false,
  });

  Color get _backgroundColor => switch (tone) {
    MintSurfaceTone.porcelaine => MintColors.porcelaine,
    MintSurfaceTone.craie => MintColors.craie,
    MintSurfaceTone.sauge => MintColors.saugeClaire.withValues(alpha: 0.4),
    MintSurfaceTone.bleu => MintColors.bleuAir.withValues(alpha: 0.3),
    MintSurfaceTone.peche => MintColors.pecheDouce.withValues(alpha: 0.25),
    MintSurfaceTone.blanc => MintColors.white,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      padding: padding ?? const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: MintColors.textPrimary.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}
