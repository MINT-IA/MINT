/// DocumentCard — displays a generated pre-filled document in the coach chat.
///
/// Rendered when Claude returns a `generate_document` tool_use block and the
/// Flutter app generates the document via [FormPrefillService] or
/// [LetterGenerationService], validated through [AgentValidationGate].
///
/// Design contract (MINT_UX_GRAAL_MASTERPLAN.md):
/// - Read-only posture: MINT generates, never submits.
/// - [AgentValidationGate] MUST approve before display.
/// - All text via S (zero hardcoded strings).
/// - MintColors, MintTextStyles, MintSpacing only — no hardcoded hex.
///
/// Compliance:
/// - LSFin art. 3/8 (educational tool, not advice)
/// - LPD art. 6 (no PII in pre-filled values — ranges only)
///
/// See docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/agent/form_prefill_service.dart';
import 'package:mint_mobile/services/agent/letter_generation_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/coach/chat_card_entrance.dart';

// ════════════════════════════════════════════════════════════════
//  DOCUMENT CARD — pre-filled form or generated letter in chat
// ════════════════════════════════════════════════════════════════

/// A card rendered in the coach chat displaying a generated document.
///
/// Supports two display modes:
/// - [FormPrefill] — tabular field list with labels, values, and estimated flags.
/// - [GeneratedLetter] — letter body with placeholder markers.
///
/// Both modes show a disclaimer and a "read-only" badge.
class DocumentCard extends StatelessWidget {
  /// Pre-filled form (mutually exclusive with [letter]).
  final FormPrefill? formPrefill;

  /// Generated letter (mutually exclusive with [formPrefill]).
  final GeneratedLetter? letter;

  /// Callback when the user taps the "View document" CTA.
  /// Optional — when null, the card expands inline.
  final VoidCallback? onView;

  const DocumentCard({
    super.key,
    this.formPrefill,
    this.letter,
    this.onView,
  }) : assert(
          formPrefill != null || letter != null,
          'DocumentCard requires either formPrefill or letter',
        );

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final isForm = formPrefill != null;
    final title = isForm ? _formTypeLabel(formPrefill!.formType, l) : letter!.subject;
    final disclaimer = isForm ? formPrefill!.disclaimer : letter!.disclaimer;

    return ChatCardEntrance(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MintColors.primary.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(MintSpacing.md),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isForm ? Icons.description_outlined : Icons.mail_outline,
                    color: MintColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.docCardTitle,
                          style: MintTextStyles.labelSmall().copyWith(fontWeight: FontWeight.w700).copyWith(
                            color: MintColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: MintTextStyles.bodyMedium().copyWith(
                            color: MintColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────
            if (isForm) _buildFormFields(formPrefill!, l),
            if (!isForm) _buildLetterPreview(letter!, l),

            // ── Footer ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MintSpacing.md,
                MintSpacing.xs,
                MintSpacing.md,
                MintSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: MintColors.textSecondary,
                  ),
                  const SizedBox(width: MintSpacing.xs),
                  Expanded(
                    child: Text(
                      l.docCardReadOnly,
                      style: MintTextStyles.labelSmall().copyWith(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Disclaimer ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MintSpacing.md,
                0,
                MintSpacing.md,
                MintSpacing.md,
              ),
              child: Text(
                disclaimer,
                style: MintTextStyles.labelSmall().copyWith(
                  color: MintColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  FORM FIELDS — tabular display
  // ──────────────────────────────────────────────────────────────

  Widget _buildFormFields(FormPrefill form, S l) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.md,
        vertical: MintSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field count badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: MintColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l.docCardFieldCount(form.fields.length),
              style: MintTextStyles.labelSmall().copyWith(
                color: MintColors.primary,
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          // Field list
          ...form.fields.map(
            (field) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      field.label,
                      style: MintTextStyles.labelSmall().copyWith(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            field.value,
                            style: MintTextStyles.bodySmall().copyWith(
                              color: MintColors.textPrimary,
                            ),
                          ),
                        ),
                        if (field.isEstimated) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.edit_note,
                            size: 14,
                            color: MintColors.warning,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  LETTER PREVIEW — truncated body + placeholder count
  // ──────────────────────────────────────────────────────────────

  Widget _buildLetterPreview(GeneratedLetter letter, S l) {
    // Show first ~200 chars of body as preview
    final preview = letter.body.length > 200
        ? '${letter.body.substring(0, 200)}\u2026'
        : letter.body;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.md,
        vertical: MintSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Placeholder count badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: MintColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l.docCardFieldCount(letter.placeholders.length),
              style: MintTextStyles.labelSmall().copyWith(
                color: MintColors.primary,
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          // Letter body preview
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm),
            decoration: BoxDecoration(
              color: MintColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: MintColors.border,
              ),
            ),
            child: Text(
              preview,
              style: MintTextStyles.labelSmall().copyWith(
                color: MintColors.textPrimary,
                height: 1.5,
              ),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  HELPERS
  // ──────────────────────────────────────────────────────────────

  /// Map a form type ID to a human-readable i18n label.
  static String _formTypeLabel(String formType, S l) {
    return switch (formType) {
      'taxDeclaration' => l.docCardFiscalDeclaration,
      'lppBuyback' => l.docCardLppBuybackRequest,
      '3a' => l.docCardFiscalDeclaration,
      _ => l.docCardTitle,
    };
  }
}
