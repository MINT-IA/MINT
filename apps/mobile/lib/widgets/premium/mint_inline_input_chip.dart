import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// A compact, tappable input chip for quick data entry.
///
/// Used in Quick Start to replace full-width sliders with a lighter
/// touch: tap to edit via bottom sheet or modal. Shows label + current
/// value in a single compact row.
class MintInlineInputChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? icon;

  const MintInlineInputChip({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md,
            vertical: MintSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            color: MintColors.craie,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: MintColors.textMuted),
                const SizedBox(width: MintSpacing.sm),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: MintTextStyles.labelSmall(
                      color: MintColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(width: MintSpacing.sm),
              Icon(
                Icons.edit_outlined,
                size: 14,
                color: MintColors.textMuted.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
