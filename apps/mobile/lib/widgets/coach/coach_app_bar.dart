import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  COACH APP BAR — extracted from coach_chat_screen.dart
// ────────────────────────────────────────────────────────────

/// Custom app bar for the coach chat screen.
class CoachAppBar extends StatelessWidget {
  final bool isEmbeddedInTab;
  final bool hasUserMessages;
  final VoidCallback onBack;
  final VoidCallback onHistory;
  final VoidCallback onExport;
  final VoidCallback onSettings;

  const CoachAppBar({
    super.key,
    required this.isEmbeddedInTab,
    required this.hasUserMessages,
    required this.onBack,
    required this.onHistory,
    required this.onExport,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: MintColors.craie,
        border: Border(
          bottom: BorderSide(
            color: MintColors.border.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
          child: Row(
            children: [
              if (!isEmbeddedInTab) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: MintColors.textSecondary, size: 18),
                  onPressed: onBack,
                ),
              ] else
                const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'MINT',
                  style:
                      MintTextStyles.titleMedium(color: MintColors.textPrimary)
                          .copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded,
                    color: MintColors.textMuted, size: 20),
                tooltip: s.coachTooltipHistory,
                onPressed: onHistory,
              ),
              if (hasUserMessages)
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded,
                      color: MintColors.textMuted, size: 20),
                  tooltip: s.coachTooltipExport,
                  onPressed: onExport,
                ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded,
                    color: MintColors.textMuted, size: 20),
                tooltip: s.coachTooltipSettings,
                onPressed: onSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
