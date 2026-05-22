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
import 'package:mint_mobile/theme/colors.dart';

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
            style: const TextStyle(
              fontFamily: 'Supreme',
              fontSize: 15,
              color: MintColors.inkPrimary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                MaterialLocalizations.of(ctx).okButtonLabel,
                style: const TextStyle(
                  fontFamily: 'Supreme',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MintColors.inkPrimary,
                ),
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
                        style: const TextStyle(
                          fontFamily: 'Supreme',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: MintColors.inkPrimary,
                          height: 1.25,
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
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.tonal(
                  key: const ValueKey('us-tax-person-yes'),
                  onPressed: () => _answer(context, true),
                  child: Text(
                    l.waitlistUsTaxPersonYes,
                    style: const TextStyle(
                      fontFamily: 'Supreme',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.tonal(
                  key: const ValueKey('us-tax-person-no'),
                  onPressed: () => _answer(context, false),
                  child: Text(
                    l.waitlistUsTaxPersonNo,
                    style: const TextStyle(
                      fontFamily: 'Supreme',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
