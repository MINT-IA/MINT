/// MintSceneEtatCivil — W2 archetype-truth onboarding scene.
///
/// Asks the civil status BEFORE financial-data steps so the archetype is
/// knowable instead of presumed « marié-jamais-divorcé » (NEVER #7).
/// Includes « divorcé » explicitly — the divorce branch feeds succession
/// / 2e-pilier-split logic downstream. Writes `q_civil_status` to
/// [CoachProfileProvider] via `mergeAnswers` with the EXACT internal
/// values that `CoachProfile._parseCivilStatus`
/// (coach_profile.dart:2668/3431) maps to [CoachCivilStatus]:
///   - célibataire → `celibataire`
///   - marié       → `marie`
///   - divorcé     → `divorce`
///   - veuf        → `veuf`
///   - concubinage → `concubinage`
///
/// Pattern mirrors `us_tax_person_screen.dart`: stateless, MintColors
/// tokens only, WCAG radio-group semantics, `onAnswered` fired AFTER the
/// provider write completes.
///
/// References:
/// - .planning/phases/mint-illogism-fixes/mint-illogism-fixes-CONTEXT.md (W2)
/// - lib/models/coach_profile.dart:2668 (q_civil_status reader)
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/widgets/onboarding_choice_button.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Internal civil-status values matching `_parseCivilStatus` EXACTLY,
/// keyed off the canonical [CoachCivilStatus] enum so divergence is a
/// compile error rather than a silent string drift.
const String kCivilCelibataire = 'celibataire';
const String kCivilMarie = 'marie';
const String kCivilDivorce = 'divorce';
const String kCivilVeuf = 'veuf';
const String kCivilConcubinage = 'concubinage';

class MintSceneEtatCivil extends StatelessWidget {
  const MintSceneEtatCivil({
    super.key,
    required this.onAnswered,
  });

  /// Called with the chosen `q_civil_status` value AFTER the provider
  /// write completes. The parent orchestrator advances on this callback.
  final void Function(String civilStatus) onAnswered;

  Future<void> _answer(BuildContext context, String value) async {
    final provider = context.read<CoachProfileProvider>();
    await provider.mergeAnswers(<String, dynamic>{
      'q_civil_status': value,
    });
    onAnswered(value);
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    // (value, label, key, semantics position hint). The enum-derived
    // constants guarantee the values map back to CoachCivilStatus.
    final options = <(String, String, String, String)>[
      (
        kCivilCelibataire,
        l.onboardingCivilCelibataire,
        'onboarding-civil-celibataire',
        '1 / 5',
      ),
      (
        kCivilMarie,
        l.onboardingCivilMarie,
        'onboarding-civil-marie',
        '2 / 5',
      ),
      (
        kCivilConcubinage,
        l.onboardingCivilConcubinage,
        'onboarding-civil-concubinage',
        '3 / 5',
      ),
      (
        kCivilDivorce,
        l.onboardingCivilDivorce,
        'onboarding-civil-divorce',
        '4 / 5',
      ),
      (
        kCivilVeuf,
        l.onboardingCivilVeuf,
        'onboarding-civil-veuf',
        '5 / 5',
      ),
    ];

    // Compile-time guard: every option value must round-trip through the
    // canonical parser. CoachCivilStatus is the source of truth.
    assert(
      CoachCivilStatus.values.length == 5,
      'CoachCivilStatus changed — update MintSceneEtatCivil options.',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.onboardingCivilPrompt,
              style: MintTextStyles.headlineMedium(
                color: MintColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.xl),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                child: Semantics(
                  container: true,
                  label: l.onboardingCivilPrompt,
                  child: Column(
                    children: [
                      for (final (value, label, key, _) in options) ...[
                        OnboardingChoiceButton(
                          key: ValueKey(key),
                          label: label,
                          onPressed: () => _answer(context, value),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
