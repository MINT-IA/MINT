import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Conversion bottom sheet shown after the 3rd anonymous coach message.
///
/// Feels like a natural continuation of the conversation (coach avatar +
/// conversational copy), NOT a system interrupt. Offers Apple Sign-In
/// and magic link, with a soft "Plus tard" dismiss.
class AuthGateBottomSheet extends StatelessWidget {
  /// Called when the user successfully authenticates.
  final ValueChanged<String>? onAuthenticated;

  /// Called when the user taps "Plus tard" (dismiss).
  final VoidCallback? onDismissed;

  const AuthGateBottomSheet({
    super.key,
    this.onAuthenticated,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: const BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Coach avatar
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MintColors.coachBubble,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MintColors.coachAccent.withValues(alpha: 0.15),
                  ),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: MintColors.coachAccent,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),

              // Coach message — conversational, not system-like
              Text(
                l.authGateConversionMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: MintColors.textPrimary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Primary CTA — Create account
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/auth/register?redirect=/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l.anonymousChatCreateAccount,
                    style: MintTextStyles.titleMedium(color: MintColors.white)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary CTA — Login
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/auth/login?redirect=/home');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: MintColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: MintColors.border),
                    ),
                  ),
                  child: Text(
                    l.authGateLogin,
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Dismiss — "Plus tard"
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismissed?.call();
                },
                child: Text(
                  l.authGateLater,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textMuted,
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
