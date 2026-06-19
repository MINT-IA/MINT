/// MintSceneStatutEmploi — W2 archetype-truth onboarding scene.
///
/// Asks the employment status BEFORE financial-data steps so the
/// archetype is knowable instead of presumed « salarié-avec-LPP »
/// (NEVER #7). Writes `q_employment_status` to [CoachProfileProvider]
/// via `mergeAnswers` with the EXACT internal values that
/// `CoachProfile._parseEmploymentStatus` (coach_profile.dart:2702/3454)
/// recognises:
///   - salarié      → `salarie`
///   - indépendant  → `independant`
///   - sans activité → `sans_activite`
///
/// Pattern mirrors `us_tax_person_screen.dart` (the existing archetype
/// question in the wedge): stateless, MintColors/MintUI tokens only,
/// WCAG radio-group semantics, `onAnswered` fired AFTER the provider
/// write completes so the orchestrator advances deterministically.
///
/// References:
/// - .planning/phases/mint-illogism-fixes/mint-illogism-fixes-CONTEXT.md (W2)
/// - lib/models/coach_profile.dart:2702 (q_employment_status reader)
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// Internal employment values matching `_parseEmploymentStatus` EXACTLY.
/// `sans_activite` is parsed by the W2 extension to coach_profile.dart so
/// a non-active user is NOT silently coerced to `salarie`.
const String kEmploymentSalarie = 'salarie';
const String kEmploymentIndependant = 'independant';
const String kEmploymentSansActivite = 'sans_activite';

class MintSceneStatutEmploi extends StatelessWidget {
  const MintSceneStatutEmploi({
    super.key,
    required this.onAnswered,
  });

  /// Called with the chosen `q_employment_status` value AFTER the provider
  /// write completes. The parent orchestrator advances on this callback.
  final void Function(String employmentStatus) onAnswered;

  Future<void> _answer(BuildContext context, String value) async {
    final provider = context.read<CoachProfileProvider>();
    await provider.mergeAnswers(<String, dynamic>{
      'q_employment_status': value,
    });
    onAnswered(value);
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    // (value, label, key, semantics position hint)
    final options = <(String, String, String, String)>[
      (
        kEmploymentSalarie,
        l.onboardingEmploymentSalarie,
        'onboarding-employment-salarie',
        '1 / 3',
      ),
      (
        kEmploymentIndependant,
        l.onboardingEmploymentIndependant,
        'onboarding-employment-independant',
        '2 / 3',
      ),
      (
        kEmploymentSansActivite,
        l.onboardingEmploymentSansActivite,
        'onboarding-employment-sans-activite',
        '3 / 3',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.onboardingEmploymentPrompt,
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
                  label: l.onboardingEmploymentPrompt,
                  child: Column(
                    children: [
                      for (final (value, label, key, hint) in options) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Semantics(
                            inMutuallyExclusiveGroup: true,
                            button: true,
                            label: label,
                            hint: hint,
                            child: FilledButton.tonal(
                              key: ValueKey(key),
                              onPressed: () => _answer(context, value),
                              style: FilledButton.styleFrom(
                                backgroundColor: MintColors.craie,
                                foregroundColor: MintColors.textPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: MintTextStyles.labelLarge(
                                  color: MintColors.textPrimary,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
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
