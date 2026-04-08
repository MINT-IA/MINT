import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// A selectable choice card for decision screens.
///
/// Used in Rente vs Capital (Rente / Capital / Mixte) and potentially
/// other multi-option screens. Calm, warm, no checkbox — selection
/// is shown through subtle border + background shift.
class MintChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const MintChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = selectedColor ?? MintColors.primary;

    return Semantics(
      label: '$title — $subtitle',
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.all(MintSpacing.lg),
          decoration: BoxDecoration(
            color: selected
                ? effectiveColor.withValues(alpha: 0.06)
                : MintColors.craie,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? effectiveColor.withValues(alpha: 0.3)
                  : MintColors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MintTextStyles.titleMedium(
                        color: selected
                            ? effectiveColor
                            : MintColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 22,
                  color: effectiveColor.withValues(alpha: 0.7),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
