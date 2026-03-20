import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class MintSelectableCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? description;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;

  const MintSelectableCard({
    super.key,
    required this.icon,
    required this.label,
    this.description,
    required this.isSelected,
    required this.onTap,
    this.selectedColor = MintColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:
              isSelected ? selectedColor.withValues(alpha: 0.08) : MintColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? selectedColor : MintColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? selectedColor : MintColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MintTextStyles.bodyMedium(color: isSelected ? selectedColor : MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: selectedColor, size: 20),
          ],
        ),
      ),
    ),
    );
  }
}

class MintQuickPickChips<T> extends StatelessWidget {
  final List<T> options;
  final T? selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;

  const MintQuickPickChips({
    super.key,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected == option;
        return Semantics(
          label: labelBuilder(option),
          button: true,
          child: GestureDetector(
            onTap: () => onSelected(option),
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? MintColors.primary.withValues(alpha: 0.10)
                  : MintColors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? MintColors.primary : MintColors.lightBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              labelBuilder(option),
              style: MintTextStyles.bodySmall(color: isSelected ? MintColors.primary : MintColors.textSecondary).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        );
      }).toList(),
    );
  }
}

class MintChfInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool optional;

  const MintChfInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.onChanged,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          optional ? '$label (optionnel)' : label,
          style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: 'CHF  ',
            prefixStyle: MintTextStyles.bodyMedium(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w500),
            filled: true,
            fillColor: MintColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MintColors.lightBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MintColors.lightBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: MintColors.primary, width: 1.8),
            ),
          ),
          style: MintTextStyles.bodyLarge(color: MintColors.textPrimary).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class OnboardingInsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? footer;

  const OnboardingInsightCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: MintColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 12, height: 1.35),
          ),
          if (footer != null) ...[
            const SizedBox(height: 8),
            footer!,
          ],
        ],
      ),
    );
  }
}

class OnboardingStepHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const OnboardingStepHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: MintTextStyles.headlineLarge(color: MintColors.textPrimary).copyWith(letterSpacing: -0.5, height: 1.2),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
        ),
      ],
    );
  }
}

class OnboardingContinueButton extends StatelessWidget {
  final bool enabled;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;

  const OnboardingContinueButton({
    super.key,
    required this.enabled,
    required this.label,
    this.icon = Icons.arrow_forward,
    required this.onPressed,
    this.backgroundColor = MintColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          disabledBackgroundColor: MintColors.textMuted.withValues(alpha: 0.15),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: MintTextStyles.titleMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 18),
          ],
        ),
      ),
    );
  }
}

/// "Voici ce que ton coach a déduit" — confirmation card for wizard.
/// Shows computed/inferred data so the user can confirm or correct.
class CoachDeductionCard extends StatelessWidget {
  final List<DeductionItem> items;
  final VoidCallback onConfirm;
  final VoidCallback onCorrect;

  const CoachDeductionCard({
    super.key,
    required this.items,
    required this.onConfirm,
    required this.onCorrect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 20, color: MintColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Voici ce que ton coach a déduit',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  item.isPositive ? Icons.check_circle : Icons.warning_amber,
                  size: 16,
                  color: item.isPositive ? MintColors.success : MintColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        item.value,
                        style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  item.source,
                  style: MintTextStyles.micro(color: MintColors.textMuted),
                ),
              ],
            ),
          )),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCorrect,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: MintColors.lightBorder),
                  ),
                  child: Text(
                    'Corriger',
                    style: MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'C\'est correct',
                    style: MintTextStyles.bodyMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DeductionItem {
  final String label;
  final String value;
  final String source;
  final bool isPositive;

  const DeductionItem({
    required this.label,
    required this.value,
    required this.source,
    this.isPositive = true,
  });
}
