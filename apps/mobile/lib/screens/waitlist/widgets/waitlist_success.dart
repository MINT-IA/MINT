import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Post-submit confirmation state for /waitlist. Shows a green check
/// icon, the success message, and a back-to-home CTA. On mount it
/// announces the success message via [SemanticsService.announce] so
/// screen-reader users get the state change (UI-SPEC §8).
class WaitlistSuccess extends StatefulWidget {
  const WaitlistSuccess({super.key});

  @override
  State<WaitlistSuccess> createState() => _WaitlistSuccessState();
}

class _WaitlistSuccessState extends State<WaitlistSuccess> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l = S.of(context)!;
    SemanticsService.announce(l.waitlistSuccessMessage, TextDirection.ltr);
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.screenH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 48,
              color: MintColors.success,
            ),
            const SizedBox(height: MintSpacing.md),
            Text(
              l.waitlistSuccessMessage,
              textAlign: TextAlign.center,
              style: MintTextStyles.bodyLarge(color: MintColors.inkPrimary),
            ),
            const SizedBox(height: MintSpacing.xl),
            FilledButton(
              key: const Key('waitlist-success-cta'),
              onPressed: () => context.go('/'),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.inkPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.xl,
                  vertical: MintSpacing.md,
                ),
              ),
              child: Text(l.waitlistSuccessCta),
            ),
          ],
        ),
      ),
    );
  }
}
