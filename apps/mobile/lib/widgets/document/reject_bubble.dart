// Phase 28-04 — RejectBubble
//
// Surfaced when the backend (or the local pre-reject classifier) decides
// the upload is not a financial document. Anti-shame doctrine
// (`feedback_anti_shame_situated_learning.md`):
//   - NEVER use red / error colour palette here.
//   - NEVER imply user did something wrong.
//   - Always offer a one-tap retry path.

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class RejectBubble extends StatelessWidget {
  /// Optional reason override (rarely used — default i18n copy is the
  /// gentlest version). Backend can pass a more specific hint.
  final String? reason;

  /// User taps "Réessayer".
  final VoidCallback onRetry;

  const RejectBubble({
    super.key,
    this.reason,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Container(
      key: const Key('rejectBubble'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reason ?? s.documentBubbleRejectMessage,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary)
                .copyWith(height: 1.5),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('rejectRetryButton'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded,
                  size: 18, color: MintColors.textPrimary),
              label: Text(
                s.documentBubbleRejectRetry,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                backgroundColor: MintColors.background,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: MintColors.border),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
