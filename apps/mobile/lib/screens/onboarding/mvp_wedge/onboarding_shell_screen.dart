/// OnboardingShellScreen — le wizard MVP wedge hors-tabs.
///
/// Enveloppe les 7 pas (entry → birth → canton → proStatus → salary →
/// pension → household) et garde la [DossierStrip] ancrée en bas
/// de l'écran à partir du pas 2.
///
/// Doctrine : `.planning/mvp-wedge-onboarding-2026-04-21/ONBOARDING-DOCTRINE-V2.md`.
/// Tranché par le panel : valeur continue, aucun aha forcé.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/dossier_strip.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_provider.dart';
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
      case OnboardingStep.birth:
        return const _BirthStep();
      case OnboardingStep.canton:
        return const _CantonStep();
      case OnboardingStep.proStatus:
        return const _ProStatusStep();
      case OnboardingStep.salary:
        return const _SalaryStep();
      case OnboardingStep.pension:
        return const _PensionStep();
      case OnboardingStep.household:
        return const _HouseholdStep();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Shared prompt layout
// ─────────────────────────────────────────────────────────────────────

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.prompt,
    required this.child,
  });

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
          disabledBackgroundColor: MintColors.textSecondary.withValues(alpha: 0.25),
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

// ─────────────────────────────────────────────────────────────────────
//  STEP 1 — Entry
// ─────────────────────────────────────────────────────────────────────

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
            'Ton dossier commence ici.',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Quelques lignes, pas de pub, pas de jugement.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'Ouvrir',
            onPressed: () => provider.advance(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  STEP 2 — Birth year
// ─────────────────────────────────────────────────────────────────────

class _BirthStep extends StatefulWidget {
  const _BirthStep();

  @override
  State<_BirthStep> createState() => _BirthStepState();
}

class _BirthStepState extends State<_BirthStep> {
  final _controller = TextEditingController();
  int? _parsed;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final n = int.tryParse(value);
    final nowYear = DateTime.now().year;
    final ok = n != null && n >= 1900 && n <= nowYear;
    setState(() => _parsed = ok ? n : null);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    return _StepScaffold(
      prompt: 'Ton année de naissance.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            autofocus: true,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '1992',
              hintStyle: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: MintColors.textSecondary.withValues(alpha: 0.35),
              ),
              border: const UnderlineInputBorder(),
            ),
            onChanged: _onChanged,
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'Continuer',
            onPressed: _parsed == null
                ? null
                : () {
                    provider.setBirthYear(_parsed!);
                    provider.advance();
                  },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  STEP 3 — Canton
// ─────────────────────────────────────────────────────────────────────

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
      prompt: 'Où tu habites.',
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

// ─────────────────────────────────────────────────────────────────────
//  STEP 4 — Pro status
// ─────────────────────────────────────────────────────────────────────

class _ProStatusStep extends StatelessWidget {
  const _ProStatusStep();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    final options = [
      (ProStatus.salaried, 'Salarié·e'),
      (ProStatus.selfEmployed, 'Indépendant·e'),
      (ProStatus.crossBorder, 'Frontalier·ère'),
      (ProStatus.other, 'Autre'),
    ];
    return _StepScaffold(
      prompt: 'Ta situation pro.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (status, label) in options) ...[
            _StatusTile(
              label: label,
              onTap: () {
                provider.setProStatus(status, label);
                provider.advance();
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(
            color: MintColors.textPrimary.withValues(alpha: 0.18),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: MintColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  STEP 5 — Salary
// ─────────────────────────────────────────────────────────────────────

class _SalaryStep extends StatefulWidget {
  const _SalaryStep();

  @override
  State<_SalaryStep> createState() => _SalaryStepState();
}

class _SalaryStepState extends State<_SalaryStep> {
  final _controller = TextEditingController();
  double? _value;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final cleaned = raw.replaceAll("'", '').replaceAll(' ', '');
    final n = double.tryParse(cleaned);
    setState(() => _value = (n != null && n >= 1000 && n < 1000000) ? n : null);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    return _StepScaffold(
      prompt: 'Ton salaire brut annuel.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[0-9 ']")),
            ],
            autofocus: true,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '90 000',
              hintStyle: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: MintColors.textSecondary.withValues(alpha: 0.35),
              ),
              suffixText: 'CHF',
              suffixStyle: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary,
              ),
              border: const UnderlineInputBorder(),
            ),
            onChanged: _onChanged,
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'Continuer',
            onPressed: _value == null
                ? null
                : () {
                    provider.setSalaryAnnual(_value!);
                    provider.advance();
                  },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  STEP 6 — Pension
// ─────────────────────────────────────────────────────────────────────

class _PensionStep extends StatefulWidget {
  const _PensionStep();

  @override
  State<_PensionStep> createState() => _PensionStepState();
}

class _PensionStepState extends State<_PensionStep> {
  final _controller = TextEditingController();
  double? _value;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final cleaned = raw.replaceAll("'", '').replaceAll(' ', '');
    final n = double.tryParse(cleaned);
    setState(() => _value = (n != null && n >= 0 && n < 10000000) ? n : null);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    return _StepScaffold(
      prompt: 'Ton avoir de caisse de pension.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Le montant total sur ton certificat de prévoyance LPP. "
            'Pas là ? Tu complèteras plus tard.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[0-9 ']")),
            ],
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '143 000',
              hintStyle: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: MintColors.textSecondary.withValues(alpha: 0.35),
              ),
              suffixText: 'CHF',
              suffixStyle: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary,
              ),
              border: const UnderlineInputBorder(),
            ),
            onChanged: _onChanged,
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'Continuer',
            onPressed: _value == null
                ? null
                : () {
                    provider.setPensionBalance(_value!);
                    provider.advance();
                  },
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              provider.skipPension();
              provider.advance();
            },
            child: Text(
              'Je complèterai plus tard',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  STEP 7 — Household + close
// ─────────────────────────────────────────────────────────────────────

class _HouseholdStep extends StatefulWidget {
  const _HouseholdStep();

  @override
  State<_HouseholdStep> createState() => _HouseholdStepState();
}

class _HouseholdStepState extends State<_HouseholdStep> {
  bool _closing = false;

  Future<void> _choose(bool couple, String label) async {
    final onb = context.read<OnboardingProvider>();
    final coach = context.read<CoachProfileProvider>();
    onb.setHousehold(couple, label);
    setState(() => _closing = true);
    await onb.completeAndFlushToProfile(coach);
    if (!mounted) return;
    // Deliberate: we stay on this screen and route on with GoRouter.
    // The next milestone plugs the post-onboarding surface here.
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (_closing) {
      return _StepScaffold(
        prompt: 'Ton dossier est ouvert.',
        child: Center(
          child: Text(
            'On y va.',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: MintColors.textSecondary,
            ),
          ),
        ),
      );
    }
    return _StepScaffold(
      prompt: 'Tu vis en couple.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusTile(label: 'Oui', onTap: () => _choose(true, 'Oui')),
          const SizedBox(height: 10),
          _StatusTile(label: 'Non', onTap: () => _choose(false, 'Non')),
        ],
      ),
    );
  }
}
