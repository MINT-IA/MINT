// Phase 29-04 — FieldCorrectionSheet (PRIV-08).
//
// Single-field correction flow opened from BatchValidationBubble.
// User edits a value; on save, the widget returns a new ExtractedField
// with status=correctedByUser. No write happens without the explicit
// "save" tap.
//
// Visual rules (CLAUDE.md §7): MintColors tokens, no hardcoded hex,
// i18n via AppLocalizations.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/document_understanding_result.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

typedef LabelResolver = String Function(String fieldName);

class FieldCorrectionSheet extends StatefulWidget {
  final ExtractedField field;
  final LabelResolver? labelFor;

  const FieldCorrectionSheet({
    super.key,
    required this.field,
    this.labelFor,
  });

  @override
  State<FieldCorrectionSheet> createState() => _FieldCorrectionSheetState();
}

class _FieldCorrectionSheetState extends State<FieldCorrectionSheet> {
  late final TextEditingController _controller;
  late final bool _isNumeric;

  @override
  void initState() {
    super.initState();
    final v = widget.field.value;
    _isNumeric = v is num;
    _controller = TextEditingController(text: v?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final raw = _controller.text.trim();
    dynamic parsed = raw;
    if (_isNumeric) {
      // Tolerate Swiss thousands separator and the CHF suffix.
      final cleaned = raw.replaceAll("'", '').replaceAll(' ', '');
      parsed = num.tryParse(cleaned) ?? raw;
    }
    final updated = widget.field.copyWith(
      value: parsed,
      status: FieldStatus.correctedByUser,
    );
    Navigator.of(context).pop(updated);
  }

  void _cancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final label = (widget.labelFor ?? (n) => n)(widget.field.fieldName);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: MintColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.fieldCorrectionTitle,
              style: MintTextStyles.bodyLarge(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('fieldCorrectionInput'),
              controller: _controller,
              autofocus: true,
              keyboardType: _isNumeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              inputFormatters: _isNumeric
                  ? [FilteringTextInputFormatter.allow(RegExp(r"[0-9'\.\s]"))]
                  : null,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MintColors.border),
                ),
              ),
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('fieldCorrectionCancelBtn'),
                    onPressed: _cancel,
                    child: Text(s.fieldCorrectionCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    key: const Key('fieldCorrectionSaveBtn'),
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MintColors.primary,
                    ),
                    child: Text(
                      s.fieldCorrectionSave,
                      style: const TextStyle(color: MintColors.background),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
