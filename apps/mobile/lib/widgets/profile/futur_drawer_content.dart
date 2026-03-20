// Outil educatif — ne constitue pas un conseil financier (LSFin).
// Projection basee sur les donnees declarees. Les rentes AVS/LPP
// sont des estimations (LAVS art. 21-40, LPP art. 14-16).

import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
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
          style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 13),
        ),
      );
    }

    final breakdown = NetIncomeBreakdown.compute(
      grossSalary: gross,
      canton: p.canton.isNotEmpty ? p.canton : 'ZH',
      age: p.age,
    );

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

    // Conjoint disposable income (couple only)
    double? disposableCouple;
    if (p.isCouple && conjoint != null) {
      final conjointExtra = conjoint.revenuBrutAnnuel > 0
          ? NetIncomeBreakdown.compute(
              grossSalary: conjoint.revenuBrutAnnuel,
              canton: p.canton,
              age: conjoint.age ?? 45,
            ).disposableIncome /
            12
          : 0.0;
      disposableCouple = breakdown.disposableIncome / 12 + conjointExtra;
    }

    return FuturProjectionCard(
      firstName: p.firstName ?? S.of(context)!.financialSummaryToi,
      conjointFirstName: p.isCouple ? conjoint?.firstName : null,
      ageRetraite: p.effectiveRetirementAge,
      conjointAgeRetraite: conjoint?.effectiveRetirementAge,
      renteAvsUser: prev.renteAVSEstimeeMensuelle ?? 0,
      renteAvsConjoint:
          p.isCouple ? (cp?.renteAVSEstimeeMensuelle ?? 0) : null,
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
      disposableActuel: breakdown.disposableIncome / 12,
      disposableCouple: disposableCouple,
      confidenceScore: confidence,
    );
  }
}
