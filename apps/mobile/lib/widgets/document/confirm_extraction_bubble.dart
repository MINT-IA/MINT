// Phase 28-04 — ConfirmExtractionBubble
//
// Chat-first replacement for the legacy full-screen ExtractionReviewScreen
// when render_mode = "confirm" AND `needsFullReview()` is false.
//
// Layout:
//   ┌──────────────────────────────────────────┐
//   │ {summary or "J'ai lu N données utiles."} │
//   │ ── field rows (label / value) ──         │
//   │ avoirLppTotal  …  CHF 70'377             │
//   │ salaireAssure  …  CHF 91'967             │
//   │ ...                                       │
//   │ [ Tout bon ✓ ]   [ Je corrige ]          │
//   └──────────────────────────────────────────┘
//
// Visual rules (CLAUDE.md §7):
//   - MintColors tokens only, no hardcoded hex.
//   - No emoji in source — checkmark is rendered via Icons.check.
//   - Inclusive copy ("tout bon" not "valider").

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/document_understanding_result.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class ConfirmExtractionBubble extends StatelessWidget {
  /// Already-extracted fields (from the SSE FieldEvents).
  final List<ExtractedField> fields;

  /// One-line human summary from the backend (`summary` payload).
  final String? summary;

  /// User taps "Tout bon" — values are correct as-is.
  final VoidCallback onConfirm;

  /// User taps "Je corrige" — opens the editable bottom sheet.
  final VoidCallback onCorrect;

  /// Optional label resolver. The default returns the raw fieldName so the
  /// widget stays presentation-only; a real consumer can pass a translator
  /// that maps `avoirLppTotal` to a human label.
  final String Function(String fieldName)? labelFor;

  const ConfirmExtractionBubble({
    super.key,
    required this.fields,
    required this.onConfirm,
    required this.onCorrect,
    this.summary,
    this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final headline =
        summary ?? s.documentBubbleConfirmTitle(fields.length);
    return Container(
      key: const Key('confirmExtractionBubble'),
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
            headline,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...fields.map((f) => _FieldRow(
                label: (labelFor ?? (n) => n)(f.fieldName),
                value: _formatValue(f.value),
                confidence: f.confidence,
              )),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ChipButton(
                  label: s.documentBubbleConfirmAllGood,
                  primary: true,
                  icon: Icons.check_rounded,
                  onTap: onConfirm,
                  semanticsLabel: s.documentBubbleConfirmAllGood,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChipButton(
                  label: s.documentBubbleConfirmCorrect,
                  primary: false,
                  onTap: onCorrect,
                  semanticsLabel: s.documentBubbleConfirmCorrect,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatValue(dynamic v) {
    if (v == null) return '—';
    if (v is num) {
      // light formatting — backend already normalises, this is just a
      // separator pass for readability.
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

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final ConfidenceLevel confidence;

  const _FieldRow({
    required this.label,
    required this.value,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                  .copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (confidence == ConfidenceLevel.low) ...[
            const SizedBox(width: 6),
            const Icon(Icons.help_outline, size: 14, color: MintColors.textMuted),
          ],
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
  final String semanticsLabel;

  const _ChipButton({
    required this.label,
    required this.primary,
    required this.onTap,
    required this.semanticsLabel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary ? MintColors.background : MintColors.textPrimary;
    final bg = primary ? MintColors.primary : MintColors.background;
    final border = primary ? MintColors.primary : MintColors.border;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: InkWell(
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
