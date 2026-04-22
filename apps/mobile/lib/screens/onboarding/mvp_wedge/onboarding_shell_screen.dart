/// OnboardingShellScreen v2 — storyboard final locked (2026-04-22).
///
/// 9 tours linéaires après sélection d'un intent au tour 2. Le flow
/// commun est âge → canton → revenu net (T3/T4/T5), puis un insight N1
/// contextuel au T6, une scène N2 interactive au T7, une bifurcation
/// [Creuser]/[Plus tard] au T8, et le magic link au T9.
///
/// Doctrine : `.planning/mvp-wedge-onboarding-2026-04-21/STORYBOARD-FINAL-LOCKED.md`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/models/onboarding_intent.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/dossier_strip.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart';
import 'package:mint_mobile/theme/colors.dart';

class OnboardingShellScreen extends StatelessWidget {
  const OnboardingShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OnboardingProvider(),
      child: const _OnboardingShellBody(),
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
      case OnboardingStep.magicLink:
        return const _MagicLinkStep();
    }
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
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
              height: 1.25,
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
  const _PrimaryButton({required this.onPressed, required this.label});
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
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
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
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
            'Il est temps que tu saches.',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
              height: 1.25,
            ),
          ),
          const Spacer(),
          _PrimaryButton(label: 'Ouvrir', onPressed: () => provider.advance()),
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
    const items = <(OnboardingIntent, String, String, String)>[
      (
        OnboardingIntent.retraite,
        'RETRAITE',
        'Ce que je toucherai, vraiment.',
        'Ma retraite',
      ),
      (
        OnboardingIntent.achat,
        'ACHAT',
        'Ce que je peux viser.',
        'Acheter un lieu',
      ),
      (
        OnboardingIntent.impots,
        'IMPOTS',
        'Ce que je paie de trop.',
        'Mes impôts',
      ),
      (
        OnboardingIntent.explorer,
        'EXPLORER',
        'Je regarde d\u2019abord.',
        'Je regarde',
      ),
    ];

    return _StepScaffold(
      prompt: 'Qu\u2019est-ce qui t\u2019amène ?',
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final (intent, eyebrow, phrase, human) = items[i];
          return _IntentCard(
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
    required this.eyebrow,
    required this.phrase,
    required this.onTap,
  });
  final String eyebrow;
  final String phrase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
              style: GoogleFonts.montserrat(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: MintColors.corailDiscret,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              phrase,
              style: GoogleFonts.montserrat(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// T3 — Age
// ────────────────────────────────────────────────────────────────────

class _AgeStep extends StatefulWidget {
  const _AgeStep();

  @override
  State<_AgeStep> createState() => _AgeStepState();
}

class _AgeStepState extends State<_AgeStep> {
  int _years = 34;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    return _StepScaffold(
      prompt: 'Quel âge tu as ?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: _AgePicker(
                value: _years,
                onChanged: (v) {
                  setState(() => _years = v);
                  HapticFeedback.selectionClick();
                },
              ),
            ),
          ),
          _PrimaryButton(
            label: 'Continuer',
            onPressed: () {
              provider.setAge(_years);
              provider.advance();
            },
          ),
        ],
      ),
    );
  }
}

class _AgePicker extends StatelessWidget {
  const _AgePicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListWheelScrollView.useDelegate(
        controller: FixedExtentScrollController(initialItem: value - 18),
        itemExtent: 48,
        perspective: 0.003,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) => onChanged(18 + i),
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, i) {
            final year = 18 + i;
            if (year > 75) return null;
            final isSelected = year == value;
            return Center(
              child: Text(
                '$year',
                style: GoogleFonts.montserrat(
                  fontSize: isSelected ? 36 : 22,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? MintColors.textPrimary
                      : MintColors.textSecondary,
                ),
              ),
            );
          },
        ),
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
          return InkWell(
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
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
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
  int _value = 7000; // slider handle position en CHF net mensuel
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

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    final range = _rangeFor(_value);

    return _StepScaffold(
      prompt: 'Combien te tombe net par mois ?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_exactMode) ...[
            Text(
              '${_fmt(range.low)} – ${_fmt(range.high)} CHF',
              style: GoogleFonts.montserrat(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'tu ajusteras quand tu scanneras ta fiche',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            Slider(
              value: _value.toDouble(),
              min: _kMinNet.toDouble(),
              max: _kMaxNet.toDouble(),
              divisions: (_kMaxNet - _kMinNet) ~/ _kStep,
              label: '${_fmt(range.low)} – ${_fmt(range.high)}',
              activeColor: MintColors.textPrimary,
              inactiveColor:
                  MintColors.textSecondary.withValues(alpha: 0.25),
              onChanged: (v) {
                setState(() => _value = (v / _kStep).round() * _kStep);
                HapticFeedback.selectionClick();
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_fmt(_kMinNet.toDouble())} CHF',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
                Text(
                  '${_fmt(_kMaxNet.toDouble())} CHF',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _exactMode = true),
                child: Text(
                  'Je sais le chiffre exact',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textSecondary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
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
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[0-9 ']")),
              ],
              autofocus: true,
              style: GoogleFonts.montserrat(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '7\u2019600',
                hintStyle: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color:
                      MintColors.textSecondary.withValues(alpha: 0.35),
                ),
                suffixText: 'CHF',
                border: const UnderlineInputBorder(),
              ),
              onChanged: (raw) {
                final cleaned = raw
                    .replaceAll("'", '')
                    .replaceAll(' ', '')
                    .replaceAll('\u2019', '');
                final n = double.tryParse(cleaned);
                setState(() =>
                    _exactValue = (n != null && n >= 500 && n < 30000) ? n : null);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Avant impôt, après cotisations (le chiffre que tu vois tomber).',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _exactMode = false),
                child: Text(
                  'Revenir à la fourchette',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textSecondary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
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
                  style: GoogleFonts.montserrat(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: MintColors.corailDiscret,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  phrase,
                  style: GoogleFonts.montserrat(
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _PrimaryButton(
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

class _BifurcationStep extends StatelessWidget {
  const _BifurcationStep();

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
      OnboardingIntent.explorer || null =>
        'On peut continuer ensemble quand tu veux.',
    };
    return _StepScaffold(
      prompt: phrase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          _PrimaryButton(
            label: 'Creuser',
            onPressed: () {
              provider.setWantsDeeper(true);
              provider.advance();
            },
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              provider.setWantsDeeper(false);
              provider.advance();
            },
            child: Text(
              'Plus tard',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: MintColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// T9 — Magic link (sceller le dossier)
// ────────────────────────────────────────────────────────────────────

class _MagicLinkStep extends StatefulWidget {
  const _MagicLinkStep();

  @override
  State<_MagicLinkStep> createState() => _MagicLinkStepState();
}

class _MagicLinkStepState extends State<_MagicLinkStep> {
  final _controller = TextEditingController();
  bool _saving = false;
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Regex emails RFC pragmatique : local-part autorisée (lettres,
  // chiffres, . _ % + -), @, domaine avec au moins un point + TLD 2+.
  // Match les cas courants, tolère majuscules.
  static final _emailRe = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  bool _emailValid(String v) => _emailRe.hasMatch(v.trim());

  Future<void> _seal() async {
    final provider = context.read<OnboardingProvider>();
    final coach = context.read<CoachProfileProvider>();
    provider.setEmail(_controller.text.trim());
    setState(() => _saving = true);
    await provider.completeAndFlushToProfile(coach);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return _StepScaffold(
        prompt: 'Ton dossier est scellé.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ouvre le lien qu\u2019on vient de t\u2019envoyer pour y revenir.',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: MintColors.textSecondary,
              ),
            ),
            const Spacer(),
            _PrimaryButton(
              label: 'Terminer',
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      );
    }
    return _StepScaffold(
      prompt: 'Ton dossier a besoin d\u2019une adresse.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'toi@adresse.ch',
              hintStyle: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary.withValues(alpha: 0.35),
              ),
              border: const UnderlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (!_saving && _emailValid(_controller.text)) _seal();
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Un lien, pas de mot de passe. Aucune pub, aucune relance.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
          ),
          const Spacer(),
          _PrimaryButton(
            label: _saving ? 'On envoie\u2026' : 'Sceller le dossier',
            onPressed: (!_saving && _emailValid(_controller.text)) ? _seal : null,
          ),
        ],
      ),
    );
  }
}
