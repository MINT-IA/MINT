// Phase 28-04 — ExtractionReviewSheet
//
// Bottom sheet (snap 0.3 / 0.6 / 0.95) surfaced ONLY for high-stakes
// reviews: high-stakes low-confidence fields, plan 1e, coherence
// warnings, or overall confidence < 0.75. Replaces the old full-screen
// modal route for the 80% happy path while keeping the legacy route as
// deep-link fallback.
//
// Snap behaviour:
//   0.30 — preview top 2 fields visible (peek)
//   0.60 — all fields visible, read-only
//   0.95 — inline edit mode (each row opens a TextField in place; no
//          dialog, per Apple HIG 2024 / Wise pattern)
//
// Primary action: "C'est à moi" (NOT "Confirmer" — cliché per
// `feedback_no_cliche_ever.md`).

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/document_understanding_result.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Backend-mirrored predicate: returns true when the document warrants the
/// full review surface (sheet or legacy screen) instead of the inline
/// chat bubble.
bool needsFullReview(DocumentUnderstandingResult r) {
  const highStakes = <String>{
    'avoirLppTotal',
    'tauxConversion',
    'rachatMaximum',
    'salaireAssure',
    'revenuImposable',
    'fortuneImposable',
  };
  final hasHighStakesLowConf = r.extractedFields.any(
    (f) => highStakes.contains(f.fieldName) &&
        f.confidence != ConfidenceLevel.high,
  );
  return hasHighStakesLowConf ||
      r.coherenceWarnings.isNotEmpty ||
      r.planType == '1e' ||
      r.overallConfidence < 0.75;
}

class ExtractionReviewSheet extends StatefulWidget {
  final DocumentUnderstandingResult result;

  /// Called with the (possibly edited) field list when user taps "C'est à moi".
  final ValueChanged<List<ExtractedField>> onConfirm;

  /// Called when user taps "Ce n'est pas moi".
  final VoidCallback onReject;

  /// Called when user taps "Je corrige" (UI hint only — sheet stays open).
  final VoidCallback? onCorrect;

  /// Optional label resolver (defaults to fieldName).
  final String Function(String fieldName)? labelFor;

  const ExtractionReviewSheet({
    super.key,
    required this.result,
    required this.onConfirm,
    required this.onReject,
    this.onCorrect,
    this.labelFor,
  });

  /// Convenience: open as a modal bottom sheet with snap points.
  static Future<T?> show<T>(
    BuildContext context, {
    required DocumentUnderstandingResult result,
    required ValueChanged<List<ExtractedField>> onConfirm,
    required VoidCallback onReject,
    VoidCallback? onCorrect,
    String Function(String fieldName)? labelFor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.3,
        minChildSize: 0.2,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.3, 0.6, 0.95],
        expand: false,
        builder: (_, scrollCtrl) => ExtractionReviewSheet(
          result: result,
          onConfirm: onConfirm,
          onReject: onReject,
          onCorrect: onCorrect,
          labelFor: labelFor,
        ),
      ),
    );
  }

  @override
  State<ExtractionReviewSheet> createState() => _ExtractionReviewSheetState();
}

class _ExtractionReviewSheetState extends State<ExtractionReviewSheet> {
  late List<_EditableField> _fields;
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _fields = widget.result.extractedFields
        .map(_EditableField.fromExtracted)
        .toList();
  }

  @override
  void dispose() {
    for (final f in _fields) {
      f.controller.dispose();
    }
    super.dispose();
  }

  void _toggleEdit() {
    setState(() => _editMode = true);
    widget.onCorrect?.call();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final r = widget.result;
    return Container(
      key: const Key('extractionReviewSheet'),
      decoration: const BoxDecoration(
        color: MintColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: MintColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Top chip row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _Chip(
                    label: s.documentReviewMineButton,
                    primary: true,
                    icon: Icons.check_rounded,
                    onTap: () {
                      widget.onConfirm(_fields.map((e) => e.toExtracted()).toList());
                    },
                    keyValue: 'sheetConfirm',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Chip(
                    label: s.documentReviewCorrectButton,
                    onTap: _toggleEdit,
                    keyValue: 'sheetCorrect',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Chip(
                    label: s.documentReviewNotMineButton,
                    onTap: widget.onReject,
                    keyValue: 'sheetReject',
                  ),
                ),
              ],
            ),
          ),
          // Optional banners
          if (r.planType == '1e')
            _Banner(
              icon: Icons.info_outline,
              text:
                  r.planTypeWarning ?? 'Plan 1e détecté — vérifie attentivement.',
            ),
          if (r.coherenceWarnings.isNotEmpty)
            _Banner(
              icon: Icons.warning_amber_outlined,
              text: r.coherenceWarnings.first.message,
            ),
          // Field list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _fields.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: MintColors.lightBorder),
              itemBuilder: (_, i) {
                final f = _fields[i];
                final label = (widget.labelFor ?? (n) => n)(f.fieldName);
                return _EditableRow(
                  key: Key('sheetRow_${f.fieldName}'),
                  label: label,
                  field: f,
                  editing: _editMode,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableField {
  final String fieldName;
  dynamic value;
  final ConfidenceLevel confidence;
  final String sourceText;
  final TextEditingController controller;

  _EditableField({
    required this.fieldName,
    required this.value,
    required this.confidence,
    required this.sourceText,
  }) : controller = TextEditingController(text: value?.toString() ?? '');

  factory _EditableField.fromExtracted(ExtractedField e) => _EditableField(
        fieldName: e.fieldName,
        value: e.value,
        confidence: e.confidence,
        sourceText: e.sourceText,
      );

  ExtractedField toExtracted() {
    final raw = controller.text.trim();
    dynamic v = raw;
    final asNum = num.tryParse(raw.replaceAll("'", '').replaceAll(' ', ''));
    if (asNum != null) v = asNum;
    return ExtractedField(
      fieldName: fieldName,
      value: v,
      confidence: confidence,
      sourceText: sourceText,
    );
  }
}

class _EditableRow extends StatelessWidget {
  final String label;
  final _EditableField field;
  final bool editing;

  const _EditableRow({
    super.key,
    required this.label,
    required this.field,
    required this.editing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: editing
                ? TextField(
                    controller: field.controller,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    style: MintTextStyles.bodyMedium(
                            color: MintColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w600),
                  )
                : Text(
                    field.value?.toString() ?? '—',
                    textAlign: TextAlign.right,
                    style: MintTextStyles.bodyMedium(
                            color: MintColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool primary;
  final IconData? icon;
  final VoidCallback onTap;
  final String keyValue;

  const _Chip({
    required this.label,
    required this.onTap,
    required this.keyValue,
    this.primary = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary ? MintColors.background : MintColors.textPrimary;
    final bg = primary ? MintColors.primary : MintColors.background;
    final border = primary ? MintColors.primary : MintColors.border;
    return InkWell(
      key: Key(keyValue),
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: MintTextStyles.bodySmall(color: fg)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Banner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: MintColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
