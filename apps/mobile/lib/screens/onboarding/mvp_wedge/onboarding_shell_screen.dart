/// OnboardingShellScreen v2 — storyboard final locked (2026-04-22).
///
/// 9 tours linéaires après sélection d'un intent au tour 2. Le flow
/// commun est âge → canton → revenu net (T3/T4/T5), puis un insight N1
/// contextuel au T6, une scène N2 interactive au T7, une bifurcation
/// [Creuser]/[Plus tard] au T8, et le magic link au T9.
///
/// Doctrine : `.planning/mvp-wedge-onboarding-2026-04-21/STORYBOARD-FINAL-LOCKED.md`
library;

import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/onboarding_intent.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/discrete_adjust_control.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/dossier_strip.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_etat_civil.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_statut_emploi.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/us_tax_person_screen.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/widgets/onboarding_choice_button.dart';
import 'package:mint_mobile/screens/waitlist/waitlist_args.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/profile_migration_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

class OnboardingShellScreen extends StatelessWidget {
  const OnboardingShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sub-phase 01.5 W02-T05 Task 1 (R7) — pre-archetype guard.
    //
    // Resolve the legacy `needsUsTaxPersonReOnboarding` flag BEFORE
    // constructing OnboardingProvider so the step machine starts on
    // the US-tax-person Q for grandfathered users. New users (flag
    // absent) keep the standard entry → intents → … flow.
    //
    // The future resolves quickly (one SharedPreferences read); we
    // hide the underlying scaffold during the await to avoid a
    // single-frame flash of the entry step for legacy users.
    return FutureBuilder<bool>(
      future: ProfileMigrationService().needsUsTaxPersonReOnboarding(),
      builder: (context, snapshot) {
        // While the flag is loading, show a minimal Scaffold (same
        // background as the entry step) so there is no visible flash.
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: MintColors.warmWhite,
            body: SizedBox.shrink(),
          );
        }
        final needsReOnboarding = snapshot.data ?? false;
        return ChangeNotifierProvider(
          create: (_) => OnboardingProvider.legacyReOnboarding(
            needsUsTaxPersonReOnboarding: needsReOnboarding,
          ),
          child: const _OnboardingShellBody(),
        );
      },
    );
  }
}

class _OnboardingShellBody extends StatelessWidget {
  const _OnboardingShellBody();

  @override
  Widget build(BuildContext context) {
    final step = context.watch<OnboardingProvider>().step;
    return Scaffold(
      backgroundColor: MintColors.warmWhite,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(step),
                  child: _stepWidget(step),
                ),
              ),
            ),
            if (step != OnboardingStep.entry) const DossierStrip(),
          ],
        ),
      ),
    );
  }

  Widget _stepWidget(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.entry:
        return const _EntryStep();
      case OnboardingStep.intents:
        return FeatureFlags.enableMint2FirstExperienceEntry
            ? const _Mint2AxesStep()
            : const _IntentsStep();
      case OnboardingStep.usTaxPerson:
        return const _UsTaxPersonStep();
      case OnboardingStep.nationality:
        return const _NationalityStep();
      case OnboardingStep.employment:
        return const _EmploymentStep();
      case OnboardingStep.civilStatus:
        return const _CivilStatusStep();
      case OnboardingStep.avsLacunes:
        return const _AvsLacunesStep();
      case OnboardingStep.age:
        return const _AgeStep();
      case OnboardingStep.canton:
        return const _CantonStep();
      case OnboardingStep.revenue:
        return const _RevenueStep();
      case OnboardingStep.insight:
        return const _InsightStep();
      case OnboardingStep.scene:
        return const _SceneStep();
      case OnboardingStep.bifurcation:
        return const _BifurcationStep();
    }
  }
}

// ────────────────────────────────────────────────────────────────────
// T2.5 — US-tax-person hard-gate (Sub-phase 01.5 W02-T03)
// ────────────────────────────────────────────────────────────────────

/// Thin wrapper that connects [UsTaxPersonScreen] to the onboarding
/// step machine. The screen writes `q_us_tax_person` to
/// [CoachProfileProvider]; on answer the orchestrator advances to T3
/// (age). No additional dossier-strip entry — the FATCA flag is
/// invisible to the user post-answer, surfaced only by the route gate.
class _UsTaxPersonStep extends StatelessWidget {
  const _UsTaxPersonStep();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    return UsTaxPersonScreen(
      onAnswered: (isUsTaxPerson) {
        if (isUsTaxPerson) {
          context.go(
            '/waitlist',
            extra: const WaitlistArgs(archetype: 'expat_us'),
          );
          return;
        }
        provider.advance();
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// T2.6 — Nationality (SALVAGE-01 archetype signal)
// ────────────────────────────────────────────────────────────────────

/// Nationality capture step. Three mutually-exclusive options
/// (Suisse / UE-AELE / Autre) mapped to the CH/EU/OTHER provider group.
///
/// WCAG remediation inherited from `UsTaxPersonScreen` (the sibling FATCA
/// gate): the prompt is a `Semantics(header: true)`, the options live in a
/// labelled radio-group container, each option announces a meaningful
/// position-in-set Semantics label and has a 48px tap target. Colors are
/// MintColors tokens only (no hardcoded Color()).
///
/// Like the FATCA Q, this step writes NO dossier-strip line — nationality
/// is invisible to the user post-answer, surfaced only by the coach gate.
class _NationalityStep extends StatelessWidget {
  const _NationalityStep();

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final provider = context.read<OnboardingProvider>();

    void pick(String group) {
      provider.setNationality(group);
      provider.advance();
    }

    // (group, label, key, semantics position hint)
    final options = <(String, String, String, String)>[
      ('CH', l.nationalitySuisse, 'onboarding-nationality-ch', '1 / 3'),
      ('EU', l.nationalityEuAele, 'onboarding-nationality-eu', '2 / 3'),
      ('OTHER', l.nationalityAutre, 'onboarding-nationality-other', '3 / 3'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.nationalityPrompt,
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
                  label: l.nationalityPrompt,
                  child: Column(
                    children: [
                      for (final (group, label, key, _) in options) ...[
                        OnboardingChoiceButton(
                          key: ValueKey(key),
                          label: label,
                          onPressed: () => pick(group),
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

// ────────────────────────────────────────────────────────────────────
// T2.7-T2.9 — W2 (mint-illogism-fixes-06) archetype-truth questions
// ────────────────────────────────────────────────────────────────────

/// Thin wrappers connecting the W2 archetype scenes to the onboarding
/// step machine. Each scene writes its q_* key to CoachProfileProvider
/// (sealed by SecureWizardStore) AND records the value on the
/// OnboardingProvider so the terminal flush re-emits it deterministically.
/// On answer the orchestrator advances to the next step. Like the FATCA +
/// nationality steps, these write NO dossier-strip line — PII archetype
/// signals stay invisible to the user post-answer.
class _EmploymentStep extends StatelessWidget {
  const _EmploymentStep();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    return MintSceneStatutEmploi(
      onAnswered: (status) {
        provider.setEmploymentStatus(status);
        provider.advance();
      },
    );
  }
}

class _CivilStatusStep extends StatelessWidget {
  const _CivilStatusStep();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    return MintSceneEtatCivil(
      onAnswered: (status) {
        provider.setCivilStatus(status);
        provider.advance();
      },
    );
  }
}

class _AvsLacunesStep extends StatelessWidget {
  const _AvsLacunesStep();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    return MintSceneLacunesAvs(
      onAnswered: (status, {arrivalYear, yearsAbroad}) {
        // Mirror the captured values onto the OnboardingProvider so the
        // terminal flush re-emits them. ReportPersistenceService.saveAnswers
        // REPLACES the store, so the flush map must carry the year/count —
        // the scene's own mergeAnswers write alone would be overwritten.
        provider.setAvsLacunes(
          status,
          arrivalYear: arrivalYear,
          yearsAbroad: yearsAbroad,
        );
        provider.advance();
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Shared layout primitives
// ────────────────────────────────────────────────────────────────────

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.prompt, required this.child});
  final String prompt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt,
            style: MintTextStyles.editorialLarge(
              color: MintColors.inkPrimary,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    Key? key,
    required this.onPressed,
    required this.label,
    this.semanticsIdentifier,
  })  : buttonKey = key,
        super(key: null);

  final Key? buttonKey;
  final VoidCallback? onPressed;
  final String label;
  final String? semanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final identifier = semanticsIdentifier;
    final button = SizedBox(
      key: identifier == null ? buttonKey : null,
      width: double.infinity,
      height: 56,
      child: FilledButton(
        // lint-ignore: prefer_mint_cta
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: MintColors.textPrimary,
          disabledBackgroundColor:
              MintColors.textSecondary.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: MintTextStyles.labelLarge(color: MintColors.white)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
    if (identifier == null) return button;
    return Semantics(
      key: buttonKey,
      identifier: identifier,
      child: button,
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// T1 — Entry
// ────────────────────────────────────────────────────────────────────

class _EntryStep extends StatelessWidget {
  const _EntryStep();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final provider = context.read<OnboardingProvider>();
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 24),
                Column(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.diagnosticOnboardingEntryTitle,
                        textAlign: TextAlign.center,
                        style: MintTextStyles.displayGambarinoItalic40(
                          color: MintColors.inkPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.diagnosticOnboardingEntryBody,
                      textAlign: TextAlign.center,
                      style: MintTextStyles.bodySupreme15Regular(
                        color: MintColors.textSecondaryAaa,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    _PrimaryButton(
                      key: const ValueKey('onboarding-entry-open'),
                      semanticsIdentifier: 'onboarding-entry-open',
                      label: l10n.diagnosticOnboardingEntryCta,
                      onPressed: () => provider.advance(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// T2 — Intents (4 cartes Fraunces)
// ────────────────────────────────────────────────────────────────────

class _IntentsStep extends StatelessWidget {
  const _IntentsStep();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final provider = context.read<OnboardingProvider>();
    final items = <(OnboardingIntent, String, String, String, Key, String)>[
      (
        OnboardingIntent.achat,
        l10n.diagnosticOnboardingIntentHousingEyebrow,
        l10n.diagnosticOnboardingIntentHousingPhrase,
        l10n.diagnosticOnboardingIntentHousingHuman,
        const ValueKey('onboarding-intent-achat'),
        'onboarding-intent-achat',
      ),
      (
        OnboardingIntent.impots,
        l10n.diagnosticOnboardingIntentTaxesEyebrow,
        l10n.diagnosticOnboardingIntentTaxesPhrase,
        l10n.diagnosticOnboardingIntentTaxesHuman,
        const ValueKey('onboarding-intent-impots'),
        'onboarding-intent-impots',
      ),
      (
        OnboardingIntent.retraite,
        l10n.diagnosticOnboardingIntentPensionEyebrow,
        l10n.diagnosticOnboardingIntentPensionPhrase,
        l10n.diagnosticOnboardingIntentPensionHuman,
        const ValueKey('onboarding-intent-retraite'),
        'onboarding-intent-retraite',
      ),
      (
        OnboardingIntent.explorer,
        l10n.diagnosticOnboardingIntentExploreEyebrow,
        l10n.diagnosticOnboardingIntentExplorePhrase,
        l10n.diagnosticOnboardingIntentExploreHuman,
        const ValueKey('onboarding-intent-explorer'),
        'onboarding-intent-explorer',
      ),
    ];

    return _StepScaffold(
      prompt: l10n.diagnosticOnboardingIntentPrompt,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final (intent, eyebrow, phrase, human, key, identifier) = items[i];
          return _IntentCard(
            key: key,
            semanticsIdentifier: identifier,
            eyebrow: eyebrow,
            phrase: phrase,
            onTap: () {
              provider.setIntent(intent, human);
              provider.advance();
            },
          );
        },
      ),
    );
  }
}

class _Mint2AxesStep extends StatelessWidget {
  const _Mint2AxesStep();

  Future<void> _openLiveAxis(
    BuildContext context,
    OnboardingProvider provider,
    String label,
  ) async {
    final authProvider = context.read<AuthProvider>();
    provider.setAxisV2(OnboardingAxisV2.lppRenteCapital, label);
    final persisted = await provider.persistMint2AxisHandoff();
    if (!context.mounted) return;
    if (!persisted) {
      dev.log(
        'Mint 2 axis handoff persistence failed',
        name: 'Onboarding',
      );
      final l10n = S.of(context)!;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: MintColors.textPrimary,
          content: Text(
            l10n.onboardingSealError,
            style: MintTextStyles.bodyMedium(color: MintColors.background),
          ),
        ),
      );
      return;
    }
    await authProvider.enableLocalMode();
    if (!context.mounted) return;
    context.go('/retraite/rente-vs-capital');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final provider = context.watch<OnboardingProvider>();
    final showLiveContinuation =
        provider.axisV2 != OnboardingAxisV2.lppRenteCapital &&
            provider.signalAxesV2.isNotEmpty;
    final items = <_Mint2AxisData>[
      _Mint2AxisData(
        axis: OnboardingAxisV2.lppRenteCapital,
        label: l10n.mint2FirstExperienceLppLabel,
        body: l10n.mint2FirstExperienceLppBody,
        status: l10n.mint2FirstExperienceLiveStatus,
      ),
      _Mint2AxisData(
        axis: OnboardingAxisV2.logementSignal,
        label: l10n.mint2FirstExperienceHousingLabel,
        body: l10n.mint2FirstExperienceHousingBody,
        status: l10n.mint2FirstExperienceSignalStatus,
      ),
      _Mint2AxisData(
        axis: OnboardingAxisV2.fiscalSignal,
        label: l10n.mint2FirstExperienceFiscalLabel,
        body: l10n.mint2FirstExperienceFiscalBody,
        status: l10n.mint2FirstExperienceSignalStatus,
      ),
    ];

    return _StepScaffold(
      prompt: l10n.mint2FirstExperienceAxisPrompt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final item = items[i];
                final selected = provider.axisV2 == item.axis;
                final recorded =
                    selected || provider.signalAxesV2.contains(item.axis);
                return _Mint2AxisCard(
                  key: ValueKey('mint2-axis-${item.axis.id}'),
                  semanticsIdentifier: 'mint2-axis-${item.axis.id}',
                  label: item.label,
                  body: item.body,
                  status: item.status,
                  selected: selected,
                  recorded: recorded,
                  onTap: () {
                    if (item.axis == OnboardingAxisV2.lppRenteCapital) {
                      _openLiveAxis(context, provider, item.label);
                      return;
                    }
                    provider.setAxisV2(item.axis, item.label);
                  },
                );
              },
            ),
          ),
          if (showLiveContinuation) ...[
            const SizedBox(height: 16),
            _PrimaryButton(
              key: const ValueKey('mint2-axis-continue-live'),
              semanticsIdentifier: 'mint2-axis-continue-live',
              label: l10n.mint2FirstExperienceLppLabel,
              onPressed: () {
                _openLiveAxis(
                  context,
                  provider,
                  l10n.mint2FirstExperienceLppLabel,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Mint2AxisData {
  const _Mint2AxisData({
    required this.axis,
    required this.label,
    required this.body,
    required this.status,
  });

  final OnboardingAxisV2 axis;
  final String label;
  final String body;
  final String status;
}

class _Mint2AxisCard extends StatelessWidget {
  const _Mint2AxisCard({
    super.key,
    required this.semanticsIdentifier,
    required this.label,
    required this.body,
    required this.status,
    required this.selected,
    required this.recorded,
    required this.onTap,
  });

  final String semanticsIdentifier;
  final String label;
  final String body;
  final String status;
  final bool selected;
  final bool recorded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final savedSignalText =
        recorded && status == l10n.mint2FirstExperienceSignalStatus
            ? l10n.mint2FirstExperienceSignalSaved
            : null;
    return Semantics(
      identifier: semanticsIdentifier,
      label: savedSignalText == null
          ? '$label. $status. $body'
          : '$label. $status. $savedSignalText. $body',
      button: true,
      selected: recorded,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: MintSurface(
          tone: recorded ? MintSurfaceTone.sauge : MintSurfaceTone.craie,
          padding: const EdgeInsets.all(MintSpacing.md),
          radius: 16,
          elevated: recorded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status,
                style: MintTextStyles.labelSupreme12Uppercase025LS(
                  color: MintColors.mintForest,
                ),
              ),
              if (savedSignalText != null) ...[
                const SizedBox(height: MintSpacing.xs),
                Text(
                  savedSignalText,
                  style: MintTextStyles.labelSupreme12Uppercase025LS(
                    color: MintColors.mintForest,
                  ),
                ),
              ],
              const SizedBox(height: MintSpacing.sm),
              Text(
                label,
                style: MintTextStyles.titleGambarino18Medium(
                  color: MintColors.inkPrimary,
                ),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                body,
                style: MintTextStyles.bodySupreme15Regular(
                  color: MintColors.textSecondaryAaa,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntentCard extends StatelessWidget {
  const _IntentCard({
    Key? key,
    required this.semanticsIdentifier,
    required this.eyebrow,
    required this.phrase,
    required this.onTap,
  })  : cardKey = key,
        super(key: null);

  final Key? cardKey;
  final String semanticsIdentifier;
  final String eyebrow;
  final String phrase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: cardKey,
      identifier: semanticsIdentifier,
      label: '$eyebrow. $phrase',
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: MintSurface(
          tone: MintSurfaceTone.craie,
          padding: const EdgeInsets.all(MintSpacing.md),
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: MintTextStyles.labelSupreme12Uppercase025LS(
                  color: MintColors.mintForest,
                ),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                phrase,
                style: MintTextStyles.titleGambarino18Medium(
                  color: MintColors.inkPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// T3 — Date de naissance
// ────────────────────────────────────────────────────────────────────

class _AgeStep extends StatefulWidget {
  const _AgeStep();

  @override
  State<_AgeStep> createState() => _AgeStepState();
}

class _AgeStepState extends State<_AgeStep> {
  DateTime? _dateOfBirth;

  String get _displayDate {
    final value = _dateOfBirth;
    if (value == null) return 'Choisir ma date';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 34, 7, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (picked != null) {
      if (_dateOfBirth == null && DateUtils.isSameDay(picked, initial)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Choisis ta vraie date de naissance.')),
          );
        }
        return;
      }
      setState(() => _dateOfBirth = picked);
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    return _StepScaffold(
      prompt: 'Quelle est ta date de naissance ?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: OutlinedButton(
                // lint-ignore: prefer_mint_cta
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 64),
                  side: const BorderSide(color: MintColors.textPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _displayDate,
                  style: (_dateOfBirth == null
                          ? MintTextStyles.titleLarge(
                              color: MintColors.textPrimary,
                            )
                          : MintTextStyles.displaySmall(
                              color: MintColors.textPrimary,
                            ))
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          _PrimaryButton(
            key: const ValueKey('onboarding-dob-continue'),
            semanticsIdentifier: 'onboarding-dob-continue',
            label: 'Continuer',
            onPressed: _dateOfBirth == null
                ? null
                : () {
                    provider.setDateOfBirth(_dateOfBirth!);
                    provider.advance();
                  },
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// T4 — Canton
// ────────────────────────────────────────────────────────────────────

const _cantons = <(String, String)>[
  ('AG', 'Argovie'),
  ('AI', 'Appenzell RI'),
  ('AR', 'Appenzell RE'),
  ('BE', 'Berne'),
  ('BL', 'Bâle-Campagne'),
  ('BS', 'Bâle-Ville'),
  ('FR', 'Fribourg'),
  ('GE', 'Genève'),
  ('GL', 'Glaris'),
  ('GR', 'Grisons'),
  ('JU', 'Jura'),
  ('LU', 'Lucerne'),
  ('NE', 'Neuchâtel'),
  ('NW', 'Nidwald'),
  ('OW', 'Obwald'),
  ('SG', 'Saint-Gall'),
  ('SH', 'Schaffhouse'),
  ('SO', 'Soleure'),
  ('SZ', 'Schwytz'),
  ('TG', 'Thurgovie'),
  ('TI', 'Tessin'),
  ('UR', 'Uri'),
  ('VD', 'Vaud'),
  ('VS', 'Valais'),
  ('ZG', 'Zoug'),
  ('ZH', 'Zurich'),
];

class _CantonStep extends StatelessWidget {
  const _CantonStep();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    return _StepScaffold(
      prompt: 'Où tu vis ?',
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.9,
        ),
        itemCount: _cantons.length,
        itemBuilder: (context, i) {
          final (code, name) = _cantons[i];
          final identifier = 'onboarding-canton-${code.toLowerCase()}';
          final key = code == 'VD'
              ? const ValueKey('onboarding-canton-vd')
              : ValueKey(identifier);
          return Semantics(
            key: key,
            identifier: identifier,
            button: true,
            onTap: () {
              provider.setCanton(code, name);
              provider.advance();
            },
            child: InkWell(
              onTap: () {
                provider.setCanton(code, name);
                provider.advance();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: MintColors.textPrimary.withValues(alpha: 0.18),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  code,
                  style: MintTextStyles.labelLarge(
                    color: MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// T5 — Revenue (slider fourchette + lien exact)
// ────────────────────────────────────────────────────────────────────

// Bornes revenu net mensuel. 500 pour couvrir apprentis, étudiants
// avec bourse, temps partiels, retraités modestes. 15000+ pour les
// revenus cadres supérieurs — au-delà, l'user bascule en saisie exacte.
const _kMinNet = 500;
const _kMaxNet = 15000;
const _kStep = 500;

class _RevenueStep extends StatefulWidget {
  const _RevenueStep();

  @override
  State<_RevenueStep> createState() => _RevenueStepState();
}

class _RevenueStepState extends State<_RevenueStep> {
  int _value = 7000; // fourchette basse en CHF net mensuel
  bool _exactMode = false;
  final _exactController = TextEditingController();
  double? _exactValue;

  @override
  void dispose() {
    _exactController.dispose();
    super.dispose();
  }

  ({double low, double high}) _rangeFor(int v) => (
        low: v.toDouble(),
        high: (v + _kStep).toDouble(),
      );

  void _shiftValue(int delta) {
    final next = (_value + delta).clamp(_kMinNet, _kMaxNet).toInt();
    if (next == _value) return;
    setState(() => _value = next);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    final l10n = S.of(context)!;
    final range = _rangeFor(_value);
    final stepLabel = _fmt(_kStep.toDouble());

    return _StepScaffold(
      prompt: 'Combien te tombe net par mois ?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_exactMode) ...[
            Text(
              '${_fmt(range.low)} – ${_fmt(range.high)} CHF',
              style: MintTextStyles.displayMedium(
                color: MintColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'tu ajusteras quand tu scanneras ta fiche',
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),
            OnboardingDiscreteAdjustControl(
              decrementIdentifier: 'onboarding-revenue-decrease',
              incrementIdentifier: 'onboarding-revenue-increase',
              decrementLabel: l10n.onboardingRevenueDecreaseStep(stepLabel),
              incrementLabel: l10n.onboardingRevenueIncreaseStep(stepLabel),
              currentValueLabel: l10n.onboardingRevenueCurrentRange(
                _fmt(range.low),
                _fmt(range.high),
              ),
              visualValue: _fmt(_value.toDouble()),
              canDecrement: _value > _kMinNet,
              canIncrement: _value < _kMaxNet,
              onDecrement: () => _shiftValue(-_kStep),
              onIncrement: () => _shiftValue(_kStep),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_fmt(_kMinNet.toDouble())} CHF',
                  style: MintTextStyles.labelMedium(
                    color: MintColors.textSecondary,
                  ),
                ),
                Text(
                  '${_fmt(_kMaxNet.toDouble())} CHF',
                  style: MintTextStyles.labelMedium(
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: TextButton(
                // lint-ignore: prefer_mint_cta
                onPressed: () => setState(() => _exactMode = true),
                child: Text(
                  'Je sais le chiffre exact',
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary,
                  ).copyWith(
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
              key: const ValueKey('onboarding-revenue-range-continue'),
              semanticsIdentifier: 'onboarding-revenue-range-continue',
              label: 'Continuer',
              onPressed: () {
                provider.setNetMonthlyRange(range.low, range.high);
                provider.advance();
              },
            ),
          ] else ...[
            TextField(
              controller: _exactController,
              keyboardType: TextInputType.number,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[0-9 ']")),
              ],
              autofocus: true,
              style: MintTextStyles.displayMedium(
                color: MintColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: '7\u2019600',
                hintStyle: MintTextStyles.displayMedium(
                  color: MintColors.textSecondary.withValues(alpha: 0.35),
                ).copyWith(fontWeight: FontWeight.w600),
                suffixText: 'CHF',
                border: const UnderlineInputBorder(),
              ),
              onChanged: (raw) {
                final cleaned = raw
                    .replaceAll("'", '')
                    .replaceAll(' ', '')
                    .replaceAll('\u2019', '');
                final n = double.tryParse(cleaned);
                setState(() => _exactValue =
                    (n != null && n >= 500 && n < 30000) ? n : null);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Avant impôt, après cotisations (le chiffre que tu vois tomber).',
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ),
            ),
            const Spacer(),
            Center(
              child: TextButton(
                // lint-ignore: prefer_mint_cta
                onPressed: () => setState(() => _exactMode = false),
                child: Text(
                  'Revenir à la fourchette',
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary,
                  ).copyWith(decoration: TextDecoration.underline),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
              key: const ValueKey('onboarding-revenue-exact-continue'),
              semanticsIdentifier: 'onboarding-revenue-exact-continue',
              label: 'Continuer',
              onPressed: _exactValue == null
                  ? null
                  : () {
                      provider.setNetMonthlyExact(_exactValue!);
                      provider.advance();
                    },
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write("\u2019");
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ────────────────────────────────────────────────────────────────────
// T6 — Insight N1 (contextuel à l'intent)
// ────────────────────────────────────────────────────────────────────

class _InsightStep extends StatelessWidget {
  const _InsightStep();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    final intent = provider.intent;

    final (eyebrow, phrase) = switch (intent) {
      OnboardingIntent.retraite => (
          'UN CONSTAT',
          '63% — c\u2019est, en moyenne, ce que tu gardes à 65 ans.',
        ),
      OnboardingIntent.achat => (
          'TROIS LEVIERS',
          'Ta capacité d\u2019emprunt tient sur trois chiffres : apport, taux, charge max 33%.',
        ),
      OnboardingIntent.impots => (
          'UN LEVIER DIRECT',
          'Ton 3a n\u2019est pas une faveur. C\u2019est le levier fiscal le plus direct.',
        ),
      OnboardingIntent.explorer => (
          'MOYENNE SUISSE',
          'Trois scènes, trois chiffres — la réalité de ta tranche.',
        ),
      null => ('', ''),
    };

    return _StepScaffold(
      prompt: 'Avant de te montrer…',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: MintColors.craie,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: MintColors.textPrimary.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.corailDiscret,
                  ).copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  phrase,
                  style: MintTextStyles.titleLarge(
                    color: MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Spacer(),
          _PrimaryButton(
            key: const ValueKey('onboarding-insight-view'),
            semanticsIdentifier: 'onboarding-insight-view',
            label: 'Voir',
            onPressed: () => provider.advance(),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// T7 — Scène N2 (router par intent)
// ────────────────────────────────────────────────────────────────────

class _SceneStep extends StatelessWidget {
  const _SceneStep();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final intent = provider.intent;
    final age = provider.ageYears;
    final netMonthly = provider.netMonthlyEffective;

    if (age == null || netMonthly == null) {
      // Garde défensive — ne devrait jamais arriver en flow valide.
      return const _StepScaffold(
        prompt: 'Il manque une donnée.',
        child: SizedBox.shrink(),
      );
    }

    final Widget scene = switch (intent) {
      OnboardingIntent.retraite => MintSceneRenteTrouee(
          currentAge: age,
          netMonthly: netMonthly,
          isRange: provider.netMonthlyRange != null,
          // Plumbing du gapFactor : la scène « rente trouée » reflète
          // désormais le trou de cotisation (arrivée tardive + lacunes).
          arrivalAge: provider.avsArrivalAge,
          lacunes: provider.avsGaps,
        ),
      OnboardingIntent.achat => MintSceneCapaciteAchat(
          netMonthly: netMonthly,
          isRange: provider.netMonthlyRange != null,
        ),
      OnboardingIntent.impots => MintScene3aLevier(
          netMonthly: netMonthly,
          cantonCode: provider.cantonCode ?? 'VD',
          isRange: provider.netMonthlyRange != null,
        ),
      OnboardingIntent.explorer || null => _ExplorerOverviewScene(
          cantonCode: provider.cantonCode,
          netMonthly: netMonthly,
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: SingleChildScrollView(child: scene)),
          const SizedBox(height: 16),
          _PrimaryButton(
            key: const ValueKey('onboarding-scene-continue'),
            semanticsIdentifier: 'onboarding-scene-continue',
            label: 'Continuer',
            onPressed: () => context.read<OnboardingProvider>().advance(),
          ),
        ],
      ),
    );
  }
}

class _ExplorerOverviewScene extends StatelessWidget {
  const _ExplorerOverviewScene({
    required this.cantonCode,
    required this.netMonthly,
  });

  final String? cantonCode;
  final double netMonthly;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final knownValue = l10n.diagnosticOnboardingExploreKnownValue(
      _cantonName(cantonCode),
      _RevenueStepState._fmt(netMonthly),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: MintColors.craie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.diagnosticOnboardingExploreSceneEyebrow,
            style: MintTextStyles.labelSmall(
              color: MintColors.corailDiscret,
            ).copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              l10n.diagnosticOnboardingExploreSceneTitle,
              style: MintTextStyles.titleLarge(
                color: MintColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 18),
          _ExplorerOverviewRow(
            label: l10n.diagnosticOnboardingExploreKnownLabel,
            body: knownValue,
          ),
          const SizedBox(height: 12),
          _ExplorerOverviewRow(
            label: l10n.diagnosticOnboardingExploreAssumptionsLabel,
            body: l10n.diagnosticOnboardingExploreAssumptionsBody,
          ),
          const SizedBox(height: 12),
          _ExplorerOverviewRow(
            label: l10n.diagnosticOnboardingExploreMissingLabel,
            body: l10n.diagnosticOnboardingExploreMissingBody,
          ),
        ],
      ),
    );
  }

  static String _cantonName(String? code) {
    if (code == null) return '';
    for (final (cantonCode, name) in _cantons) {
      if (cantonCode == code) return name;
    }
    return code;
  }
}

class _ExplorerOverviewRow extends StatelessWidget {
  const _ExplorerOverviewRow({
    required this.label,
    required this.body,
  });

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: MintTextStyles.labelMedium(
                color: MintColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: MintTextStyles.bodyMedium(
                color: MintColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// T8 — Bifurcation [Creuser] / [Plus tard]
// ────────────────────────────────────────────────────────────────────

/// Terminal step of the wedge since 2026-04-24.
///
/// Terminal actions:
///   - Continuer        \u2192 seal + /coach/chat
///   - Créer un compte  \u2192 seal + /auth/register
///   - Repartir de zéro \u2192 clear pre-account diagnostic only
///   - Sortir           \u2192 seal + /home
///
/// Auth conversion happens later via the existing `auth_gate_bottom_sheet`
/// after 3 anonymous messages \u2014 no email, no "I'll see you tomorrow"
/// user-eject (killed per design panel 2026-04-24 P0-4).
class _BifurcationStep extends StatefulWidget {
  const _BifurcationStep();

  @override
  State<_BifurcationStep> createState() => _BifurcationStepState();
}

class _BifurcationStepState extends State<_BifurcationStep> {
  bool _sealing = false;

  Future<void> _sealAndGo({
    required bool deeper,
    required String route,
  }) async {
    if (_sealing) return;
    final provider = context.read<OnboardingProvider>();
    final coach = context.read<CoachProfileProvider>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = S.of(context)!;
    final router = GoRouter.of(context);

    provider.setWantsDeeper(deeper);
    setState(() => _sealing = true);
    try {
      await provider.completeAndFlushToProfile(coach);
      if (coach.hasProfile) {
        auth.markAccountProfileAvailable();
      }
    } catch (e, stack) {
      dev.log(
        'MVP wedge seal failed',
        error: e,
        stackTrace: stack,
        name: 'Onboarding',
      );
      if (!mounted) return;
      setState(() => _sealing = false);
      messenger?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: MintColors.textPrimary,
          content: Text(
            l10n.onboardingSealError,
            style: MintTextStyles.bodyMedium(color: MintColors.background),
          ),
          action: SnackBarAction(
            label: l10n.onboardingSealRetry,
            textColor: MintColors.background,
            onPressed: () => _sealAndGo(deeper: deeper, route: route),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    router.go(route);
  }

  Future<void> _resetDiagnostic() async {
    if (_sealing) return;
    final provider = context.read<OnboardingProvider>();
    setState(() => _sealing = true);
    await provider.resetDiagnostic();
    if (!mounted) return;
    setState(() => _sealing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final provider = context.read<OnboardingProvider>();
    final intent = provider.intent;
    final phrase = switch (intent) {
      OnboardingIntent.retraite =>
        'On peut le creuser quand tu veux. Je garde tout.',
      OnboardingIntent.achat =>
        'On chiffrera les frais notaire et l\u2019IFD quand tu veux.',
      OnboardingIntent.impots =>
        'Je peux chiffrer un rachat LPP aussi, quand tu veux.',
      OnboardingIntent.explorer ||
      null =>
        'On peut continuer ensemble quand tu veux.',
    };

    Widget secondaryAction({
      required Key key,
      required String semanticsIdentifier,
      required String label,
      required VoidCallback? onPressed,
    }) {
      return Semantics(
        key: key,
        identifier: semanticsIdentifier,
        label: label,
        button: true,
        onTap: onPressed,
        child: ExcludeSemantics(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              // lint-ignore: prefer_mint_cta
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: MintColors.textPrimary,
                side: BorderSide(
                  color: MintColors.textPrimary.withValues(alpha: 0.18),
                ),
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
      );
    }

    return _StepScaffold(
      prompt: phrase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: _TerminalDossierSummary()),
          const SizedBox(height: 12),
          _PrimaryButton(
            key: const ValueKey('onboarding-bifurcation-continue'),
            semanticsIdentifier: 'onboarding-bifurcation-continue',
            label: _sealing
                ? 'On garde\u2026'
                : l10n.diagnosticOnboardingTerminalContinueAction,
            onPressed: _sealing
                ? null
                : () => _sealAndGo(
                      deeper: true,
                      route: '/coach/chat',
                    ),
          ),
          const SizedBox(height: 8),
          secondaryAction(
            key: const ValueKey('onboarding-bifurcation-create-account'),
            semanticsIdentifier: 'onboarding-bifurcation-create-account',
            label: l10n.diagnosticOnboardingTerminalCreateAccountAction,
            onPressed: _sealing
                ? null
                : () => _sealAndGo(
                      deeper: false,
                      route: '/auth/register',
                    ),
          ),
          const SizedBox(height: 8),
          secondaryAction(
            key: const ValueKey('onboarding-bifurcation-reset'),
            semanticsIdentifier: 'onboarding-bifurcation-reset',
            label: l10n.diagnosticOnboardingTerminalResetAction,
            onPressed: _sealing ? null : _resetDiagnostic,
          ),
          const SizedBox(height: 8),
          secondaryAction(
            key: const ValueKey('onboarding-bifurcation-exit'),
            semanticsIdentifier: 'onboarding-bifurcation-exit',
            label: l10n.diagnosticOnboardingTerminalExitAction,
            onPressed: _sealing
                ? null
                : () => _sealAndGo(
                      deeper: false,
                      route: '/home',
                    ),
          ),
        ],
      ),
    );
  }
}

class _TerminalDossierSummary extends StatelessWidget {
  const _TerminalDossierSummary();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final onboarding = context.watch<OnboardingProvider>();
    final accountState = context.watch<AuthProvider>().accountDataState;
    final dossier = onboarding.dossier;

    return Semantics(
      container: true,
      label: l10n.diagnosticOnboardingTerminalStateTitle,
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: MintColors.craie,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: MintColors.textPrimary.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.diagnosticOnboardingTerminalStateTitle,
                style: MintTextStyles.labelSmall(
                  color: MintColors.corailDiscret,
                ).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _accountStateLabel(accountState, l10n),
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              _TerminalSummarySection(
                title: l10n.diagnosticOnboardingTerminalUnderstoodTitle,
                children: [
                  for (final entry in dossier)
                    _TerminalSummaryRow(
                      label: entry.label,
                      value: entry.value,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _TerminalSummarySection(
                title: l10n.diagnosticOnboardingTerminalMissingTitle,
                children: [
                  _TerminalSummaryBullet(
                    l10n.diagnosticOnboardingTerminalMissingLpp,
                  ),
                  _TerminalSummaryBullet(
                    l10n.diagnosticOnboardingTerminalMissingExpenses,
                  ),
                  _TerminalSummaryBullet(
                    l10n.diagnosticOnboardingTerminalMissingGoal,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _TerminalSummarySection(
                title: l10n.diagnosticOnboardingTerminalNextQuestionsTitle,
                children: [
                  _TerminalSummaryBullet(
                    l10n.diagnosticOnboardingTerminalQuestionGoal,
                  ),
                  _TerminalSummaryBullet(
                    l10n.diagnosticOnboardingTerminalQuestionExpenses,
                  ),
                  _TerminalSummaryBullet(
                    l10n.diagnosticOnboardingTerminalQuestionDocument,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _accountStateLabel(
    MintAccountDataState state,
    S l10n,
  ) {
    return switch (state) {
      MintAccountDataState.anonymousLocal =>
        l10n.diagnosticOnboardingTerminalAnonymousLocal,
      MintAccountDataState.signedOut =>
        l10n.diagnosticOnboardingTerminalSignedOut,
      MintAccountDataState.accountSyncOff =>
        l10n.diagnosticOnboardingTerminalAccountSyncOff,
      MintAccountDataState.cloudSyncOn =>
        l10n.diagnosticOnboardingTerminalCloudSyncOn,
      MintAccountDataState.deletePending =>
        l10n.diagnosticOnboardingTerminalDeletePending,
    };
  }
}

class _TerminalSummarySection extends StatelessWidget {
  const _TerminalSummarySection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: MintTextStyles.titleMedium(
            color: MintColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _TerminalSummaryRow extends StatelessWidget {
  const _TerminalSummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: MintTextStyles.bodySmall(
                color: MintColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalSummaryBullet extends StatelessWidget {
  const _TerminalSummaryBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: MintTextStyles.bodySmall(
              color: MintColors.corailDiscret,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
