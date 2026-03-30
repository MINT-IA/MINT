import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// A tappable tile that opens a CupertinoPicker bottom sheet for
/// discrete integer selection (age, years, count).
///
/// Replaces imprecise sliders for integer inputs with small ranges.
class MintPickerTile extends StatelessWidget {
  final String label;
  final int value;
  final int minValue;
  final int maxValue;
  final String Function(int) formatValue;
  final ValueChanged<int> onChanged;

  const MintPickerTile({
    super.key,
    required this.label,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.formatValue,
    required this.onChanged,
  });

  void _openPicker(BuildContext context) {
    int selected = value;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: MintColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: 300,
        child: Column(
          children: [
            // Header with done button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.md,
                vertical: MintSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onChanged(selected);
                      Navigator.of(ctx).pop();
                    },
                    child: Text(
                      'OK',
                      style: MintTextStyles.titleMedium(
                        color: MintColors.primary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: MintColors.lightBorder),
            // Picker
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: value - minValue,
                ),
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  selected = minValue + index;
                },
                children: List.generate(
                  maxValue - minValue + 1,
                  (i) => Center(
                    child: Text(
                      formatValue(minValue + i),
                      style: MintTextStyles.headlineMedium(
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label\u00a0: ${formatValue(value)}',
      button: true,
      child: GestureDetector(
        onTap: () => _openPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md,
            vertical: MintSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatValue(value),
                    style: MintTextStyles.bodyMedium(color: MintColors.primary)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.unfold_more,
                    size: 16,
                    color: MintColors.textMuted.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
