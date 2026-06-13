import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Conversion bottom sheet shown after the 3rd anonymous coach message.
///
/// Feels like a natural continuation of the conversation (coach avatar +
/// conversational copy), NOT a system interrupt. Offers Apple Sign-In
/// and magic link, with a soft "Plus tard" dismiss.
class AuthGateBottomSheet extends StatelessWidget {
  /// Called when the user taps "Plus tard" (dismiss).
  final VoidCallback? onDismissed;
  final String redirectPath;

  const AuthGateBottomSheet({
    super.key,
    this.redirectPath = '/home',
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    // Handoff 2 alignment 2026-05-03 :
    //  - sheet bg : porcelaineHero (#F4F1EC) au lieu de surface cool grey
    //  - hairline : borderSubtle (#E8E4DE) warm
    //  - coach icon halo : sauge (positive signal) au lieu de slate
    //  - primary CTA : inkPrimary (#1A1A1A) warm près-noir, pas anthracite cool
    //  - coach message : Fraunces editorial italic (Handoff 2 §grammaire)
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: const BoxDecoration(
        color: MintColors.porcelaineHero,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar — warm hairline
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MintColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Coach avatar — sauge halo, forest icon (positive signal)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MintColors.craieHandoff,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MintColors.sauge,
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: MintColors.mintForest,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),

                // Coach message — editorial italic (Fraunces) per Handoff 2.
                Text(
                  l.authGateConversionMessage,
                  textAlign: TextAlign.center,
                  style: MintTextStyles.editorialBody(
                    color: MintColors.inkPrimary,
                  ),
                ),
                const SizedBox(height: 28),

                // Primary CTA — warm near-black ink (Handoff 2 ink-primary).
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Cassure #6 (2026-05-13): capture the router BEFORE
                      // pop, otherwise `context.push` runs against the
                      // popped bottom-sheet context and silently falls
                      // through to /auth/login instead of /auth/register.
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      router.push(
                        '/auth/register?redirect=${Uri.encodeComponent(redirectPath)}',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MintColors.inkPrimary,
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

                // Secondary CTA — outlined, warm hairline.
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    // lint-ignore: prefer_mint_cta
                    onPressed: () {
                      // Cassure #6 sibling: same capture-before-pop pattern.
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      router.push(
                        '/auth/login?redirect=${Uri.encodeComponent(redirectPath)}',
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: MintColors.inkPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: MintColors.borderSubtle),
                      ),
                    ),
                    child: Text(
                      l.authGateLogin,
                      style: MintTextStyles.bodyMedium(
                              color: MintColors.inkPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Dismiss — "Plus tard"
                TextButton(
                  // lint-ignore: prefer_mint_cta
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDismissed?.call();
                  },
                  child: Text(
                    l.authGateLater,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondaryAaa,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
