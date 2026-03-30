import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// A tappable tile that opens a bottom-sheet text field for entering
/// monetary amounts (CHF). Replaces imprecise sliders for money inputs.
///
/// Shows label + formatted value. Tap opens a sheet with a number keyboard.
class MintAmountField extends StatelessWidget {
  final String label;
  final double value;
  final String Function(double) formatValue;
  final ValueChanged<double> onChanged;
  final String? hint;
  final double? min;
  final double? max;
  final String suffix;

  const MintAmountField({
    super.key,
    required this.label,
    required this.value,
    required this.formatValue,
    required this.onChanged,
    this.hint,
    this.min,
    this.max,
    this.suffix = 'CHF',
  });

  void _openEditor(BuildContext context) {
    final controller = TextEditingController(
      text: value.round().toString(),
    );

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
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: MintSpacing.lg,
          right: MintSpacing.lg,
          top: MintSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + MintSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            Text(
              label,
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.md),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              style: MintTextStyles.headlineMedium(color: MintColors.textPrimary),
              decoration: InputDecoration(
                suffixText: suffix,
                suffixStyle: MintTextStyles.bodyMedium(color: MintColors.textMuted),
                hintText: hint ?? '0',
                hintStyle: MintTextStyles.headlineMedium(color: MintColors.textMuted),
                filled: true,
                fillColor: MintColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MintColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.md,
                  vertical: MintSpacing.md,
                ),
              ),
              onSubmitted: (text) {
                _applyValue(text, ctx);
              },
            ),
            const SizedBox(height: MintSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _applyValue(controller.text, ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  foregroundColor: MintColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'OK',
                  style: MintTextStyles.titleMedium(color: MintColors.background),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyValue(String text, BuildContext ctx) {
    final parsed = double.tryParse(text) ?? value;
    double clamped = parsed;
    if (min != null && clamped < min!) clamped = min!;
    if (max != null && clamped > max!) clamped = max!;
    onChanged(clamped);
    Navigator.of(ctx).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label\u00a0: ${formatValue(value)}',
      button: true,
      child: GestureDetector(
        onTap: () => _openEditor(context),
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
                    Icons.edit_outlined,
                    size: 14,
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
