/// The Promise Screen — the golden path landing page.
///
/// Wire Spec V2 §3.2 state [S1]: Value proposition + single CTA.
/// Single exit: [Commencer] -> /login
///
/// Text adapts based on birthYear from OnboardingProvider:
///   18-24: "Ton premier job. Ton premier appart. Tes impots."
///   25-34: "Acheter ? Economiser ? On demele tout ca ensemble."
///   35+:   "Retraite. Impots. Patrimoine. Tes chiffres, tes decisions."
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/onboarding_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Determines which body text variant to show based on age.
enum _LifecycleBracket { young, mid, senior }

class PromiseScreen extends StatelessWidget {
  const PromiseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final onboarding = context.read<OnboardingProvider>();
    final bracket = _bracketFrom(onboarding.birthYear);

    return Scaffold(
      backgroundColor: MintColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // -- Headline --
              Text(
                l10n.promiseHeadline,
                style: MintTextStyles.headlineLarge(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // -- Adapted body text --
              Text(
                _bodyText(l10n, bracket),
                style: MintTextStyles.bodyLarge(
                  color: MintColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              // -- Footer --
              Text(
                l10n.promiseFooter,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // -- CTA: Commencer (primary) --
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => context.go('/login'),
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: MintTextStyles.titleMedium(
                      color: MintColors.white,
                    ),
                  ),
                  child: Text(l10n.promiseCta),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // -- Helpers --

  static _LifecycleBracket _bracketFrom(int? birthYear) {
    if (birthYear == null) return _LifecycleBracket.senior;
    final currentYear = DateTime.now().year;
    final age = currentYear - birthYear;
    if (age < 25) return _LifecycleBracket.young;
    if (age < 35) return _LifecycleBracket.mid;
    return _LifecycleBracket.senior;
  }

  static String _bodyText(S l10n, _LifecycleBracket bracket) {
    switch (bracket) {
      case _LifecycleBracket.young:
        return l10n.promiseBodyYoung;
      case _LifecycleBracket.mid:
        return l10n.promiseBodyMid;
      case _LifecycleBracket.senior:
        return l10n.promiseBodySenior;
    }
  }
}
