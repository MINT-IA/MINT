// Phase 29-04 — BatchValidationBubble (PRIV-08).
//
// Anti-fatigue replacement for the per-field review flow when the
// pipeline produced <=5 fields with no humanReview flag and no reject.
// "MINT a lu N chiffres. Tout bon ?" — swipe right = confirm all,
// tap a row = open FieldCorrectionSheet for that single field,
// swipe left = reject all.
//
// Ties into:
//   - document_understanding_result.dart (ExtractedField + FieldStatus)
//   - field_correction_sheet.dart
//   - render_mode_handler.dart (routes `confirm` here by default)
//
// Visual rules (CLAUDE.md §7):
//   - MintColors tokens only.
//   - No emoji. Status icons via Material icons.
//   - Inclusive copy through i18n keys.
//   - Never auto-confirms; user action is mandatory (PRIV-08).

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/document_understanding_result.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/document/field_correction_sheet.dart';

typedef LabelResolver = String Function(String fieldName);

class BatchValidationBubble extends StatefulWidget {
  /// Fields to validate. Each row starts as needs_review regardless of
  /// pipeline confidence (PRIV-08).
  final List<ExtractedField> fields;

  /// Swipe right (or tap "tout bon") — callback receives the full list
  /// with status set to userValidated.
  final void Function(List<ExtractedField> validated) onConfirmAll;

  /// Swipe left — callback receives fields with status=rejected.
  final void Function(List<ExtractedField> rejected) onRejectAll;

  /// Single-field correction — callback receives the new value.
  final void Function(ExtractedField corrected) onCorrectOne;

  /// Optional label resolver (fieldName -> human label).
  final LabelResolver? labelFor;

  const BatchValidationBubble({
    super.key,
    required this.fields,
    required this.onConfirmAll,
    required this.onRejectAll,
    required this.onCorrectOne,
    this.labelFor,
  });

  @override
  State<BatchValidationBubble> createState() => _BatchValidationBubbleState();
}

class _BatchValidationBubbleState extends State<BatchValidationBubble> {
  late List<ExtractedField> _fields;

  @override
  void initState() {
    super.initState();
    // Defense in depth (PRIV-08): force needs_review regardless of what
    // the caller passed — bubble never inherits a silent auto-confirm.
    _fields = widget.fields
        .map((f) => f.copyWith(status: FieldStatus.needsReview))
        .toList(growable: false);
  }

  void _confirmAll() {
    final validated = _fields
        .map((f) => f.copyWith(status: FieldStatus.userValidated))
        .toList(growable: false);
    widget.onConfirmAll(validated);
  }

  void _rejectAll() {
    final rejected = _fields
        .map((f) => f.copyWith(status: FieldStatus.rejected))
        .toList(growable: false);
    widget.onRejectAll(rejected);
  }

  Future<void> _correctField(int index) async {
    final f = _fields[index];
    final corrected = await showModalBottomSheet<ExtractedField>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FieldCorrectionSheet(
        field: f,
        labelFor: widget.labelFor,
      ),
    );
    if (corrected != null) {
      setState(() {
        _fields[index] = corrected;
      });
      widget.onCorrectOne(corrected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Semantics(
      container: true,
      label: s.batchValidationTitle(_fields.length),
      child: Dismissible(
        key: const ValueKey('batchValidationDismissible'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            _confirmAll();
          } else {
            _rejectAll();
          }
          // Never actually dismiss — the bubble stays in chat history.
          return false;
        },
        background: _SwipeHint(
          color: MintColors.primary.withValues(alpha: 0.15),
          icon: Icons.check_rounded,
          alignment: Alignment.centerLeft,
          label: s.batchValidationConfirmAll,
        ),
        secondaryBackground: _SwipeHint(
          color: MintColors.textSecondary.withValues(alpha: 0.15),
          icon: Icons.close_rounded,
          alignment: Alignment.centerRight,
          label: s.batchValidationRejectAll,
        ),
        child: Container(
          key: const Key('batchValidationBubble'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.coachBubble,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.batchValidationTitle(_fields.length),
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _fields.length; i++)
                _Row(
                  field: _fields[i],
                  label: (widget.labelFor ?? (n) => n)(_fields[i].fieldName),
                  onTap: () => _correctField(i),
                  humanReviewBadge: _fields[i].humanReviewFlag
                      ? s.humanReviewBadge
                      : null,
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ChipButton(
                      label: s.batchValidationConfirmAll,
                      primary: true,
                      icon: Icons.check_rounded,
                      onTap: _confirmAll,
                      keyValue: 'batchConfirmAllBtn',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChipButton(
                      label: s.batchValidationCorrectOne,
                      primary: false,
                      onTap: () async {
                        if (_fields.isNotEmpty) await _correctField(0);
                      },
                      keyValue: 'batchCorrectOneBtn',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('batchRejectAllBtn'),
                  onPressed: _rejectAll,
                  child: Text(
                    s.batchValidationRejectAll,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final ExtractedField field;
  final String label;
  final VoidCallback onTap;
  final String? humanReviewBadge;

  const _Row({
    required this.field,
    required this.label,
    required this.onTap,
    this.humanReviewBadge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('batchRow_${field.fieldName}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                  if (humanReviewBadge != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      humanReviewBadge!,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Text(
                _format(field.value),
                textAlign: TextAlign.right,
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                    .copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.edit_outlined,
              size: 16,
              color: MintColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  String _format(dynamic v) {
    if (v == null) return '—';
    if (v is num) {
      final asInt = v.truncate();
      if (v == asInt) {
        final str = asInt.toString();
        final buf = StringBuffer();
        for (int i = 0; i < str.length; i++) {
          if (i > 0 && (str.length - i) % 3 == 0) buf.write("'");
          buf.write(str[i]);
        }
        return buf.toString();
      }
      return v.toString();
    }
    return v.toString();
  }
}

class _SwipeHint extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Alignment alignment;
  final String label;

  const _SwipeHint({
    required this.color,
    required this.icon,
    required this.alignment,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: MintColors.textPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final bool primary;
  final IconData? icon;
  final VoidCallback onTap;
  final String keyValue;

  const _ChipButton({
    required this.label,
    required this.primary,
    required this.onTap,
    required this.keyValue,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary ? MintColors.background : MintColors.textPrimary;
    final bg = primary ? MintColors.primary : MintColors.background;
    final border = primary ? MintColors.primary : MintColors.border;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: Key(keyValue),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
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
      ),
    );
  }
}
