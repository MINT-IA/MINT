import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Bandeau d'honnêteté mono-revenu (beads MINT_nosync-mla volet C).
///
/// Quand un couple est déclaré (ou un partenaire household lié) mais que le
/// profil financier du conjoint est ABSENT, les surfaces couple calculaient
/// en silence sur le seul revenu de l'utilisateur — indiscernable d'un vrai
/// calcul à deux revenus. Ce bandeau rend la limite visible et pointe vers
/// la saisie (le coach capture `spouseIncomeNetMonthly` via save_fact).
///
/// Self-gated : rend `SizedBox.shrink()` sauf si
/// `profile.isMissingConjointData` (ou [forceShow] pour les surfaces dont le
/// signal vient d'ailleurs, ex. household lié sans conjoint financier).
class ConjointMissingHint extends StatelessWidget {
  const ConjointMissingHint({super.key, this.forceShow = false});

  /// Force l'affichage quand l'écran détient son propre signal (household
  /// actif) au lieu de `etatCivil` couple.
  final bool forceShow;

  @override
  Widget build(BuildContext context) {
    CoachProfile? profile;
    try {
      profile = context.watch<CoachProfileProvider>().profile;
    } catch (_) {
      // Pas de provider au-dessus (harnais isolé, deeplink froid) : le
      // bandeau se tait — jamais de crash pour un hint.
      profile = null;
    }
    final show = forceShow || (profile?.isMissingConjointData ?? false);
    if (!show) return const SizedBox.shrink();

    final s = S.of(context)!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: MintSpacing.md),
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                child: Icon(Icons.person_off_outlined,
                    size: 18, color: MintColors.textSecondary),
              ),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  s.coupleMonoIncomeHint,
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton( // lint-ignore: prefer_mint_cta
              // Tab-root -> go (jamais push, invariant shell RSoD) ;
              // '/coach' nu n'existe pas, la route est '/coach/chat'.
              onPressed: () => context.go('/coach/chat'),
              child: Text(
                s.coupleMonoIncomeCta,
                style: MintTextStyles.labelMedium(color: MintColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
