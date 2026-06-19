/// UsTaxPersonScreen — Sub-phase 01.5 Wave 02 Plan 03.
///
/// Pre-signup hard-gate question: « Es-tu citoyen ou résident fiscal
/// aux États-Unis ? » asked BEFORE any financial-data step
/// (Security §4 nLPD art. 6 minimization). Yes → writes
/// `q_us_tax_person: true` to `CoachProfileProvider` via `mergeAnswers`,
/// which `CoachProfile.fromWizardAnswers` reads into `usTaxPerson`. The
/// archetype getter (plan 02-01) then short-circuits to `expatUs`, and
/// the coach-entry gate (this plan task 4) routes to `/waitlist`.
///
/// References:
/// - .planning/phases/01.5-archetype-hard-gate-fatca/01.5-SECURITY-fatca-scope.md §4
/// - .planning/phases/01.5-archetype-hard-gate-fatca/01.5-UI-waitlist-spec.md §10
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/profile_migration_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Binary Yes/No US-tax-person question screen.
///
/// Stateless. The `onAnswered` callback is invoked AFTER the provider
/// write completes so the parent onboarding orchestrator can advance the
/// step machine deterministically.
class UsTaxPersonScreen extends StatelessWidget {
  const UsTaxPersonScreen({
    super.key,
    required this.onAnswered,
  });

  /// Called with `true` on Yes, `false` on No, AFTER the provider write
  /// completes. The parent orchestrator (`onboarding_provider.dart` task 2)
  /// advances the step machine on this callback.
  final void Function(bool answer) onAnswered;

  Future<void> _answer(BuildContext context, bool value) async {
    final provider = context.read<CoachProfileProvider>();
    // Surgical write: only writes `q_us_tax_person`. The provider's
    // `mergeAnswers` already deep-loads the on-disk answers, merges,
    // rebuilds `CoachProfile.fromWizardAnswers` (which reads
    // `q_us_tax_person` into `usTaxPerson`), persists, and notifies.
    await provider.mergeAnswers(<String, dynamic>{
      'q_us_tax_person': value,
    });
    // Sub-phase 01.5 W02-T05 Task 1 (R7) — consume the legacy re-onboarding
    // flag set by ProfileMigrationService on cold start. After this clear,
    // the orchestrator's pre-archetype guard (plan 03 Task 2) stops
    // forcing this screen and the archetype getter resolves from the
    // fresh user-declared FATCA signal. Idempotent — safe when the flag
    // is already absent (new users, post-fix flow).
    await ProfileMigrationService().clearReOnboardingFlag();
    onAnswered(value);
  }

  void _showFatcaTooltip(BuildContext context) {
    final l = S.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: MintColors.craieHandoff,
          content: Text(
            l.waitlistUsTaxPersonTooltip,
            style: MintTextStyles.labelLarge(
              color: MintColors.inkPrimary,
            ),
          ),
          actions: [
            TextButton(
              // lint-ignore: prefer_mint_cta
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                MaterialLocalizations.of(ctx).okButtonLabel,
                style: MintTextStyles.bodyMedium(
                  color: MintColors.inkPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.craieHandoff,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.waitlistUsTaxPersonQuestion,
                        style: MintTextStyles.headlineMedium(
                          color: MintColors.inkPrimary,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('us-tax-person-info'),
                    icon: const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: MintColors.textSecondary,
                    ),
                    tooltip: l.waitlistUsTaxPersonTooltip,
                    onPressed: () => _showFatcaTooltip(context),
                  ),
                ],
              ),
              const Spacer(),
              // Sub-phase 01.5 W02-NN-PATCH-A11Y (H4, WCAG 1.3.1 / 4.1.2):
              // Wrap the binary Yes/No in a Semantics container marked as
              // radio group with explicit position-in-set hints (1/2, 2/2)
              // and `inMutuallyExclusiveGroup: true`. Without this, screen
              // readers announce two unrelated buttons instead of a binary
              // radio group, leaving users without context about the choice
              // structure.
              Semantics(
                container: true,
                label: l.waitlistUsTaxPersonQuestion,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Semantics(
                        inMutuallyExclusiveGroup: true,
                        button: true,
                        label: l.waitlistUsTaxPersonYes,
                        hint: '1 / 2',
                        child: FilledButton.tonal(
                          key: const ValueKey('us-tax-person-yes'),
                          onPressed: () => _answer(context, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: MintColors.inkPrimary,
                            foregroundColor: MintColors.craie,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            l.waitlistUsTaxPersonYes,
                            textAlign: TextAlign.center,
                            style: MintTextStyles.labelLarge(
                              color: MintColors.craie,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Semantics(
                        inMutuallyExclusiveGroup: true,
                        button: true,
                        label: l.waitlistUsTaxPersonNo,
                        hint: '2 / 2',
                        child: FilledButton.tonal(
                          key: const ValueKey('us-tax-person-no'),
                          onPressed: () => _answer(context, false),
                          style: FilledButton.styleFrom(
                            backgroundColor: MintColors.inkPrimary,
                            foregroundColor: MintColors.craie,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            l.waitlistUsTaxPersonNo,
                            textAlign: TextAlign.center,
                            style: MintTextStyles.labelLarge(
                              color: MintColors.craie,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
