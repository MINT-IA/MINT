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
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/dossier_strip.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/us_tax_person_screen.dart';
import 'package:mint_mobile/screens/waitlist/waitlist_args.dart';
import 'package:mint_mobile/services/profile_migration_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

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
        return const _IntentsStep();
      case OnboardingStep.usTaxPerson:
        return const _UsTaxPersonStep();
      case OnboardingStep.nationality:
        return const _NationalityStep();
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
          const Spacer(),
          Semantics(
            container: true,
            label: l.nationalityPrompt,
            child: Column(
              children: [
                for (final (group, label, key, hint) in options) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: Semantics(
                      inMutuallyExclusiveGroup: true,
                      button: true,
                      label: label,
                      hint: hint,
                      child: FilledButton.tonal(
                        key: ValueKey(key),
                        onPressed: () => pick(group),
                        style: FilledButton.styleFrom(
                          backgroundColor: MintColors.craie,
                          foregroundColor: MintColors.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          label,
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
          const SizedBox(height: 12),
        ],
      ),
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
            style: MintTextStyles.headlineMedium(
              color: MintColors.textPrimary,
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
      height: 52,
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
      label: label,
      button: true,
      onTap: onPressed,
      child: ExcludeSemantics(child: button),
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
    final provider = context.read<OnboardingProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          const Spacer(),
          Text(
            'Il est temps que tu comprennes.',
            textAlign: TextAlign.center,
            style: MintTextStyles.displaySmall(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          _PrimaryButton(
            key: const ValueKey('onboarding-entry-open'),
            semanticsIdentifier: 'onboarding-entry-open',
            label: 'Ouvrir',
            onPressed: () => provider.advance(),
          ),
          const SizedBox(height: 8),
        ],
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
    final provider = context.read<OnboardingProvider>();
    const items = <(OnboardingIntent, String, String, String, Key, String)>[
      (
        OnboardingIntent.retraite,
        'RETRAITE',
        'Ce que je toucherai, vraiment.',
        'Ma retraite',
        ValueKey('onboarding-intent-retraite'),
        'onboarding-intent-retraite',
      ),
      (
        OnboardingIntent.achat,
        'ACHAT',
        'Ce que je peux viser.',
        'Acheter un lieu',
        ValueKey('onboarding-intent-achat'),
        'onboarding-intent-achat',
      ),
      (
        OnboardingIntent.impots,
        'IMPOTS',
        'Ce que je paie de trop.',
        'Mes impôts',
        ValueKey('onboarding-intent-impots'),
        'onboarding-intent-impots',
      ),
      (
        OnboardingIntent.explorer,
        'EXPLORER',
        'Je regarde d\u2019abord.',
        'Je regarde',
        ValueKey('onboarding-intent-explorer'),
        'onboarding-intent-explorer',
      ),
    ];

    return _StepScaffold(
      prompt: 'Qu\u2019est-ce qui t\u2019amène ?',
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
      button: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: MintColors.craie,
            borderRadius: BorderRadius.circular(14),
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
              const SizedBox(height: 6),
              Text(
                phrase,
                style: MintTextStyles.titleMedium(
                  color: MintColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w500),
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
  ('VD', 'Vaud'),
  ('GE', 'Genève'),
  ('VS', 'Valais'),
  ('FR', 'Fribourg'),
  ('NE', 'Neuchâtel'),
  ('JU', 'Jura'),
  ('BE', 'Berne'),
  ('ZH', 'Zurich'),
  ('BS', 'Bâle-Ville'),
  ('BL', 'Bâle-Campagne'),
  ('SO', 'Soleure'),
  ('AG', 'Argovie'),
  ('LU', 'Lucerne'),
  ('ZG', 'Zoug'),
  ('SZ', 'Schwytz'),
  ('OW', 'Obwald'),
  ('NW', 'Nidwald'),
  ('UR', 'Uri'),
  ('GL', 'Glaris'),
  ('SH', 'Schaffhouse'),
  ('AR', 'Appenzell RE'),
  ('AI', 'Appenzell RI'),
  ('SG', 'Saint-Gall'),
  ('GR', 'Grisons'),
  ('TG', 'Thurgovie'),
  ('TI', 'Tessin'),
];

class _CantonStep extends StatelessWidget {
  const _CantonStep();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    return _StepScaffold(
      prompt: 'Où tu vis ?',
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
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
            Container(
              height: 60,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: MintColors.craie,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: MintColors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  _RevenueAdjustButton(
                    key: const ValueKey('onboarding-revenue-decrease'),
                    semanticsIdentifier: 'onboarding-revenue-decrease',
                    semanticsLabel:
                        l10n.onboardingRevenueDecreaseStep(stepLabel),
                    visualLabel: '-',
                    enabled: _value > _kMinNet,
                    onPressed: () => _shiftValue(-_kStep),
                  ),
                  Expanded(
                    child: Semantics(
                      label: l10n.onboardingRevenueCurrentRange(
                        _fmt(range.low),
                        _fmt(range.high),
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          _fmt(_value.toDouble()),
                          textAlign: TextAlign.center,
                          style: MintTextStyles.titleLarge(
                            color: MintColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  _RevenueAdjustButton(
                    key: const ValueKey('onboarding-revenue-increase'),
                    semanticsIdentifier: 'onboarding-revenue-increase',
                    semanticsLabel:
                        l10n.onboardingRevenueIncreaseStep(stepLabel),
                    visualLabel: '+',
                    enabled: _value < _kMaxNet,
                    onPressed: () => _shiftValue(_kStep),
                  ),
                ],
              ),
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
      OnboardingIntent.explorer || null => MintSceneRenteTrouee(
          currentAge: age,
          netMonthly: netMonthly,
          isRange: provider.netMonthlyRange != null,
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
            label: 'Continuer',
            onPressed: () => context.read<OnboardingProvider>().advance(),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// T8 — Bifurcation [Creuser] / [Plus tard]
// ────────────────────────────────────────────────────────────────────

/// Terminal step of the wedge since 2026-04-24.
///
/// Both buttons flush the dossier to CoachProfile + navigate:
///   - Creuser   \u2192 /coach/chat (continue the conversation inline)
///   - Plus tard \u2192 /home       (enter the shell with seeded profile)
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

  Future<void> _sealAndGo({required bool deeper}) async {
    if (_sealing) return;
    final provider = context.read<OnboardingProvider>();
    final coach = context.read<CoachProfileProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = S.of(context)!;
    final router = GoRouter.of(context);

    provider.setWantsDeeper(deeper);
    setState(() => _sealing = true);
    try {
      await provider.completeAndFlushToProfile(coach);
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
            onPressed: () => _sealAndGo(deeper: deeper),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    router.go(deeper ? '/coach/chat' : '/home');
  }

  @override
  Widget build(BuildContext context) {
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
    return _StepScaffold(
      prompt: phrase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          _PrimaryButton(
            key: const ValueKey('onboarding-bifurcation-creuser'),
            label: _sealing ? 'On garde\u2026' : 'Creuser',
            onPressed: _sealing ? null : () => _sealAndGo(deeper: true),
          ),
          const SizedBox(height: 10),
          TextButton(
            // lint-ignore: prefer_mint_cta
            key: const ValueKey('onboarding-bifurcation-plus-tard'),
            onPressed: _sealing ? null : () => _sealAndGo(deeper: false),
            child: Text(
              'Plus tard',
              style: MintTextStyles.labelLarge(
                color: MintColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueAdjustButton extends StatelessWidget {
  const _RevenueAdjustButton({
    super.key,
    required this.semanticsIdentifier,
    required this.semanticsLabel,
    required this.visualLabel,
    required this.enabled,
    required this.onPressed,
  });

  final String semanticsIdentifier;
  final String semanticsLabel;
  final String visualLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: semanticsIdentifier,
      label: semanticsLabel,
      button: true,
      enabled: enabled,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 52,
          height: 52,
          child: TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: enabled ? onPressed : null,
            style: TextButton.styleFrom(
              foregroundColor: MintColors.textPrimary,
              disabledForegroundColor:
                  MintColors.textSecondary.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              visualLabel,
              style: MintTextStyles.titleLarge(
                color: enabled
                    ? MintColors.textPrimary
                    : MintColors.textSecondary.withValues(alpha: 0.35),
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
