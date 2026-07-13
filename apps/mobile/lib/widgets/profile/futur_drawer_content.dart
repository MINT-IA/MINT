// Outil educatif — ne constitue pas un conseil financier (LSFin).
// Projection partielle basee sur les donnees declarees. Aucun revenu AVS
// n'est affiche sans enveloppe de rente officielle revue.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/profile/futur_projection_card.dart';

/// Content of the "Ce que tu auras" drawer — wraps [FuturProjectionCard]
/// with computation logic extracted from FinancialSummaryScreen.
class FuturDrawerContent extends StatelessWidget {
  final CoachProfile profile;

  const FuturDrawerContent({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final gross = p.revenuBrutAnnuel;
    if (gross <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          S.of(context)!.financialSummaryNoProfile,
          style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
        ),
      );
    }

    final prev = p.prevoyance;
    final conjoint = p.conjoint;
    final cp = conjoint?.prevoyance;

    // Confidence score: 7 known fields / 7
    final knownCount = [
      p.salaireBrutMensuel > 0,
      p.canton.isNotEmpty,
      prev.avoirLppTotal != null && prev.avoirLppTotal! > 0,
      prev.totalEpargne3a > 0,
      p.patrimoine.epargneLiquide > 0,
      p.depenses.loyer > 0 ||
          (p.dettes.hypotheque != null && p.dettes.hypotheque! > 0),
      p.depenses.assuranceMaladie > 0,
    ].where((b) => b).length;
    final confidence = (knownCount / 7 * 100).clamp(0.0, 100.0);

    return FuturProjectionCard(
      firstName: p.firstName ?? S.of(context)!.financialSummaryToi,
      conjointFirstName: p.isCouple ? conjoint?.firstName : null,
      ageRetraite: p.effectiveRetirementAge,
      conjointAgeRetraite: conjoint?.effectiveRetirementAge,
      renteLppUser: (prev.avoirLppTotal ?? 0) * prev.tauxConversion / 12,
      renteLppConjoint: p.isCouple
          ? (cp?.avoirLppTotal ?? 0) *
              (cp?.tauxConversion ?? lppTauxConversionMinDecimal) /
              12
          : null,
      avoirLppUser: prev.avoirLppTotal ?? 0,
      avoirLppConjoint: p.isCouple ? (cp?.avoirLppTotal ?? 0) : null,
      capital3aUser: prev.totalEpargne3a,
      capital3aConjoint: p.isCouple ? (cp?.totalEpargne3a ?? 0) : null,
      capitalLibrePassage:
          prev.totalLibrePassage > 0 ? prev.totalLibrePassage : null,
      investissementsMarche: p.patrimoine.investissements > 0
          ? p.patrimoine.investissements
          : null,
      confidenceScore: confidence,
      onAvsRecoveryTap: () => context.push('/scan/avs-guide'),
    );
  }
}
