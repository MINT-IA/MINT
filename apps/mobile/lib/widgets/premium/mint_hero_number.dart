import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// A dominant number displayed as the focal point of a hero screen.
///
/// Inspired by Cleo's "$396 left to spend" pattern:
/// one massive number, one caption, maximum whitespace.
class MintHeroNumber extends StatelessWidget {
  final String value;
  final String caption;
  final Color? color;
  final String? semanticsLabel;

  const MintHeroNumber({
    super.key,
    required this.value,
    required this.caption,
    this.color,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? MintColors.textPrimary;

    return Semantics(
      label: semanticsLabel ?? '$value — $caption',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, opacity, child) => Opacity(
              opacity: opacity,
              child: child,
            ),
            child: Text(
              value,
              style: MintTextStyles.displayLarge(color: effectiveColor)
                  .copyWith(height: 1.0),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            caption,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
