import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

// ────────────────────────────────────────────────────────────
//  CHAT INLINE INPUTS — S56
// ────────────────────────────────────────────────────────────
//
//  Input widgets that live INSIDE the coach chat conversation.
//  The coach asks a question → the user responds with a picker/
//  input that appears inline, not in a separate screen.
//
//  These replace traditional forms with conversational input.
// ────────────────────────────────────────────────────────────

/// Age picker — CupertinoPicker wheel inline in chat.
/// Smooth, tactile, modern. Replaces sliders for age input.
class ChatAgePicker extends StatefulWidget {
  final int initialAge;
  final int minAge;
  final int maxAge;
  final ValueChanged<int> onSelected;
  final String? label;

  const ChatAgePicker({
    super.key,
    this.initialAge = 35,
    this.minAge = 18,
    this.maxAge = 75,
    required this.onSelected,
    this.label,
  });

  @override
  State<ChatAgePicker> createState() => _ChatAgePickerState();
}

class _ChatAgePickerState extends State<ChatAgePicker> {
  late int _selected;
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialAge;
    _controller = FixedExtentScrollController(
      initialItem: widget.initialAge - widget.minAge,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: MintSpacing.sm),
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.porcelaine.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.border.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm),
              child: Text(
                widget.label!,
                style: MintTextStyles.bodySmall(color: MintColors.textMuted),
              ),
            ),

          // Wheel picker
          SizedBox(
            height: 150,
            child: CupertinoPicker(
              scrollController: _controller,
              itemExtent: 44,
              diameterRatio: 1.2,
              magnification: 1.1,
              squeeze: 1.0,
              selectionOverlay: Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: MintColors.primary.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                ),
              ),
              onSelectedItemChanged: (index) {
                setState(() => _selected = widget.minAge + index);
              },
              children: List.generate(
                widget.maxAge - widget.minAge + 1,
                (index) {
                  final age = widget.minAge + index;
                  final isSelected = age == _selected;
                  return Center(
                    child: Text(
                      S.of(context)!.ageYears(age),
                      style: MintTextStyles.headlineMedium(
                        color: isSelected
                            ? MintColors.textPrimary
                            : MintColors.textMuted,
                      ).copyWith(
                        fontSize: isSelected ? 24 : 18,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: MintSpacing.md),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onSelected(_selected),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                MaterialLocalizations.of(context).okButtonLabel,
                style: MintTextStyles.titleMedium(color: MintColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Numeric input for amounts (CHF) — inline in chat.
/// Auto-formats with Swiss apostrophe separator.
class ChatAmountInput extends StatefulWidget {
  final String label;
  final String? hint;
  final double? initialValue;
  final ValueChanged<double> onSubmitted;

  const ChatAmountInput({
    super.key,
    required this.label,
    this.hint,
    this.initialValue,
    required this.onSubmitted,
  });

  @override
  State<ChatAmountInput> createState() => _ChatAmountInputState();
}

class _ChatAmountInputState extends State<ChatAmountInput> {
  late final TextEditingController _controller;
  double _currentValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue != null
          ? _formatSwiss(widget.initialValue!.round())
          : '',
    );
    _currentValue = widget.initialValue ?? 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatSwiss(int value) {
    return value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => "${m[1]}'");
  }

  void _onChanged(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _currentValue = 0;
      return;
    }
    // H1: Clamp to max 10'000'000 CHF to prevent unrealistic values
    _currentValue = double.parse(digits).clamp(0, 10000000);
    final formatted = _formatSwiss(_currentValue.round());
    _controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: MintSpacing.sm),
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.porcelaine.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.border.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.sm),

          // Amount field
          Row(
            children: [
              Text(
                'CHF',
                style: MintTextStyles.headlineMedium(
                  color: MintColors.textSecondary,
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  onChanged: _onChanged,
                  style: MintTextStyles.displaySmall()
                      ,
                  decoration: InputDecoration(
                    hintText: widget.hint ?? "0",
                    hintStyle: MintTextStyles.headlineLarge(
                      color: MintColors.textMuted.withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: MintSpacing.md),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onSubmitted(_currentValue),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                MaterialLocalizations.of(context).okButtonLabel,
                style: MintTextStyles.titleMedium(color: MintColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Canton picker — grid of 26 Swiss cantons inline in chat.
class ChatCantonPicker extends StatelessWidget {
  final ValueChanged<String> onSelected;
  final String? label;

  const ChatCantonPicker({
    super.key,
    required this.onSelected,
    this.label,
  });

  static const _cantons = [
    'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR',
    'JU', 'LU', 'NE', 'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG',
    'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: MintSpacing.sm),
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.porcelaine.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.border.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.md),
              child: Text(
                label!,
                style: MintTextStyles.bodySmall(color: MintColors.textMuted),
              ),
            ),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cantons.map((canton) {
              return GestureDetector(
                onTap: () => onSelected(canton),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: MintColors.craie,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    canton,
                    style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Simple choice buttons inline — for yes/no, marié/célibataire, etc.
class ChatChoiceButtons extends StatelessWidget {
  final String? label;
  final List<String> choices;
  final ValueChanged<String> onSelected;

  const ChatChoiceButtons({
    super.key,
    this.label,
    required this.choices,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: MintSpacing.sm),
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.porcelaine.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.border.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.md),
              child: Text(
                label!,
                style: MintTextStyles.bodySmall(color: MintColors.textMuted),
              ),
            ),

          ...choices.map((choice) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => onSelected(choice),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MintColors.textPrimary,
                  side: BorderSide(
                    color: MintColors.border.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: MintColors.craie,
                ),
                child: Text(
                  choice,
                  style: MintTextStyles.titleMedium()
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }
}
