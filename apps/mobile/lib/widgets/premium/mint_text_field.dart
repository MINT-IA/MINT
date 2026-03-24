import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Premium text field — replaces raw TextField/TextFormField in MINT screens.
///
/// Design: surface background, border radius 12, label above (bodySmall w600),
/// hint textMuted, inline error. Matches the Chloe/Aesop aesthetic.
///
/// Usage:
/// ```dart
/// MintTextField(
///   label: l.fieldSalary,
///   controller: _salaryCtrl,
///   keyboardType: TextInputType.number,
///   suffix: Text('CHF'),
/// )
/// ```
class MintTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? error;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Widget? prefix;
  final Widget? suffix;
  final bool readOnly;
  final bool autofocus;
  final int? maxLines;
  final FocusNode? focusNode;

  const MintTextField({
    super.key,
    this.label,
    this.hint,
    this.error,
    this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onTap,
    this.prefix,
    this.suffix,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: MintSpacing.xs),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onTap: onTap,
          readOnly: readOnly,
          autofocus: autofocus,
          maxLines: maxLines,
          focusNode: focusNode,
          style: MintTextStyles.bodyMedium(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: MintTextStyles.bodyMedium(color: MintColors.textMuted),
            errorText: error,
            errorStyle: MintTextStyles.labelSmall()
                .copyWith(color: MintColors.error),
            prefixIcon: prefix != null
                ? Padding(
                    padding:
                        const EdgeInsets.only(left: 12, right: MintSpacing.sm),
                    child: prefix,
                  )
                : null,
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: suffix != null
                ? Padding(
                    padding:
                        const EdgeInsets.only(right: 12, left: MintSpacing.sm),
                    child: suffix,
                  )
                : null,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: MintColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MintColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MintColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: MintColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MintColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: MintColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
