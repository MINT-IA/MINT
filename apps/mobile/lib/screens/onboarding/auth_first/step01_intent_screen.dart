// Onboarding v2 — Step 01 INTENT.
//
// Source : `.planning/decisions/2026-05-08-coach-onboarding-redesign-panel/SYNTHESIS.md`
// Step 01 / 6. Eyebrow Supreme letterspaced « 01 — INTENTION », hero Gambarino
// italique « Qu'est-ce qui t'amène ? », 6 life-event chips (CLAUDE.md NEVER #4 —
// 18 events balanced, retraite est UN des six), CTA « Continuer » noir plein.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Canonical primaryFocus values written to CoachProfile via mergeAnswers.
/// Format `{category}_{subcategory}` per `CoachProfile.primaryFocus` contract
/// (coach_profile.dart §primaryFocus).
const String kFocusRetraite = 'comprendre_retraite';
const String kFocusAchat = 'acheter_logement';
const String kFocusFamille = 'proteger_famille';
const String kFocusCarriere = 'developper_carriere';
const String kFocusFiscalite = 'optimiser_impots';
const String kFocusDecouverte = 'decouvrir_mint';

class Step01IntentScreen extends StatefulWidget {
  const Step01IntentScreen({super.key});

  @override
  State<Step01IntentScreen> createState() => _Step01IntentScreenState();
}

class _Step01IntentScreenState extends State<Step01IntentScreen> {
  String? _selected;
  bool _submitting = false;

  /// Single-tap commit-and-advance (OTP-style per 2026-05-08 SYNTHESIS).
  /// 250 ms visual highlight before navigation so the user sees their
  /// selection acknowledged.
  Future<void> _commitAndAdvance(String focus) async {
    if (_submitting) return;
    setState(() {
      _selected = focus;
      _submitting = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    try {
      await context
          .read<CoachProfileProvider>()
          .mergeAnswers({'primaryFocus': focus});
      if (!mounted) return;
      context.go('/onboarding/profil/age');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final chips = <(String focus, String label)>[
      (kFocusRetraite, l.onboardingIntentChipRetraite),
      (kFocusAchat, l.onboardingIntentChipAchat),
      (kFocusFamille, l.onboardingIntentChipFamille),
      (kFocusCarriere, l.onboardingIntentChipCarriere),
      (kFocusFiscalite, l.onboardingIntentChipFiscalite),
      (kFocusDecouverte, l.onboardingIntentChipDecouverte),
    ];
    return Scaffold(
      backgroundColor: MintColors.warmWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MintSpacing.lg,
            MintSpacing.xl,
            MintSpacing.lg,
            MintSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Eyebrow — Supreme uppercase letterspaced.
              Semantics(
                identifier: 'onboarding_step01_eyebrow',
                child: Text(
                  l.onboardingIntentEyebrow,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textMuted,
                  ).copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: MintSpacing.md),
              // Hero — Gambarino italic.
              Semantics(
                identifier: 'onboarding_step01_hero',
                child: Text(
                  l.onboardingIntentHero,
                  style: MintTextStyles.editorialDisplay(),
                ),
              ),
              const SizedBox(height: MintSpacing.sm),
              // Sub — Supreme body anti-promiscuous.
              Text(
                l.onboardingIntentSub,
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textSecondary,
                ),
              ),
              const SizedBox(height: MintSpacing.xl),
              // Chips list — 6 life-event buckets, vertical.
              // Single-tap commit-and-advance (OTP-style) : no separate
              // Continue CTA — tap chip = decision + navigate.
              Expanded(
                child: ListView.separated(
                  itemCount: chips.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: MintSpacing.sm),
                  itemBuilder: (context, i) {
                    final (focus, label) = chips[i];
                    return _IntentChip(
                      key: Key('onboarding_intent_chip_$focus'),
                      label: label,
                      selected: _selected == focus,
                      onTap: _submitting
                          ? null
                          : () => _commitAndAdvance(focus),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntentChip extends StatelessWidget {
  const _IntentChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? MintColors.mentheVive12 : MintColors.card;
    final borderColor =
        selected ? MintColors.mentheVive : MintColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.md,
          vertical: MintSpacing.md,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: MintTextStyles.bodyLarge(
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                size: 22,
                color: MintColors.mentheVive,
              ),
          ],
        ),
      ),
    );
  }
}
