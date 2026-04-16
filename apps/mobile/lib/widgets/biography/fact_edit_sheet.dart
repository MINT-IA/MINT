import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/biography/fact_card.dart';

/// Bottom sheet for inline editing of a [BiographyFact] value.
///
/// Shows the fact label, current value/source/date, a text input
/// pre-filled with the current value, and a save button. On save,
/// the source will be changed to [FactSource.userEdit] by the provider.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => FactEditSheet(
///     fact: fact,
///     onSave: (newValue) => provider.updateFactValue(fact.id, newValue),
///   ),
/// );
/// ```
///
/// See: BIO-05, UI-SPEC Screen 2.
class FactEditSheet extends StatefulWidget {
  /// The fact being edited.
  final BiographyFact fact;

  /// Called with the new value when the user taps save.
  final ValueChanged<String> onSave;

  const FactEditSheet({
    super.key,
    required this.fact,
    required this.onSave,
  });

  @override
  State<FactEditSheet> createState() => _FactEditSheetState();
}

class _FactEditSheetState extends State<FactEditSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.fact.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MintColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: MintSpacing.lg),

              // Title: fact label
              Text(
                FactCard.factLabel(widget.fact.factType, l),
                style: MintTextStyles.headlineSmall(
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: MintSpacing.md),

              // Current value display
              Text(
                '${widget.fact.value} \u2014 ${_sourceLabel(widget.fact.source, l)} \u2014 ${DateFormat.yMMMd().format(widget.fact.updatedAt)}',
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ),
              ),
              const SizedBox(height: MintSpacing.lg),

              // Input field
              TextFormField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
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
                    borderSide: const BorderSide(
                      color: MintColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: MintSpacing.md,
                    vertical: MintSpacing.md,
                  ),
                ),
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: MintSpacing.sm),

              // Source note
              Text(
                l.privacyControlEditSourceNote,
                style: MintTextStyles.labelSmall(
                  color: MintColors.textMuted,
                ),
              ),
              const SizedBox(height: MintSpacing.lg),

              // Save button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final newValue = _controller.text.trim();
                    if (newValue.isNotEmpty && newValue != widget.fact.value) {
                      widget.onSave(newValue);
                    }
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l.privacyControlSave,
                    style: MintTextStyles.titleMedium(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: MintSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceLabel(FactSource source, S l) {
    switch (source) {
      case FactSource.document:
        return l.privacyControlSourceDocument;
      case FactSource.userInput:
        return l.privacyControlSourceUserInput;
      case FactSource.userEdit:
        return l.privacyControlSourceUserEdit;
      case FactSource.coach:
        return l.privacyControlSourceCoach;
    }
  }
}
