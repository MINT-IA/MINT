import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  CHECK-IN SUMMARY CARD — Phase 5 / Suivi & Check-in
// ────────────────────────────────────────────────────────────
//
// Inline chat card displayed when the LLM calls record_check_in.
// Shows coach summary message, versements breakdown, and total.
//
// Outil éducatif — ne constitue pas un conseil financier (LSFin).
// ────────────────────────────────────────────────────────────

class CheckInSummaryCard extends StatelessWidget {
  /// Summary message from the LLM (already compliance-checked).
  final String summaryMessage;

  /// Map of contribution_id → amount (CHF).
  final Map<String, double> versements;

  /// Month string in YYYY-MM format.
  final String month;

  const CheckInSummaryCard({
    super.key,
    required this.summaryMessage,
    required this.versements,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final total = versements.values.fold(0.0, (sum, v) => sum + v);

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Summary message from LLM ──
          Text(
            summaryMessage,
            style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
          ),

          const SizedBox(height: MintSpacing.md),

          // ── Divider ──
          Divider(
            height: 1,
            thickness: 0.5,
            color: MintColors.textMuted.withValues(alpha: 0.4),
          ),

          const SizedBox(height: MintSpacing.md),

          // ── Versements breakdown ──
          if (versements.isNotEmpty) ...[
            ...versements.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      e.key,
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary,
                      ),
                    ),
                    Text(
                      formatChf(e.value),
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: MintSpacing.sm),

            // ── Divider before total ──
            Divider(
              height: 1,
              thickness: 0.5,
              color: MintColors.textMuted.withValues(alpha: 0.4),
            ),

            const SizedBox(height: MintSpacing.sm),

            // ── Total ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.checkInTotalLabel,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  formatChf(total),
                  style: MintTextStyles.titleMedium(
                    color: MintColors.primary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
