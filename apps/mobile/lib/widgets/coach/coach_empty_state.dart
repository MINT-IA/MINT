import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  COACH EMPTY STATE — extracted from coach_chat_screen.dart
// ────────────────────────────────────────────────────────────

/// Empty state shown when no profile is configured yet.
class CoachEmptyState extends StatelessWidget {
  const CoachEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.craie,
      appBar: AppBar(
        title: Text(
          'MINT',
          style:
              MintTextStyles.titleMedium(color: MintColors.textPrimary)
                  .copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: MintColors.textSecondary,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MintSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: MintColors.bleuAir.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(Icons.auto_awesome_outlined,
                    size: 28,
                    color:
                        MintColors.textSecondary.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: MintSpacing.lg),
              Text(
                s.coachEmptyStateMessage,
                style: MintTextStyles.bodyLarge(
                    color: MintColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MintSpacing.lg),
              FilledButton(
                onPressed: () => context.go('/onboarding/intent'),
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                ),
                child: Text(
                  s.coachEmptyStateButton,
                  style: MintTextStyles.bodyMedium(color: MintColors.white)
                      .copyWith(
                    fontWeight: FontWeight.w600,
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
