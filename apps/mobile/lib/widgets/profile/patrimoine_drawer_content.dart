import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/profile/couple_patrimoine_card.dart';
import 'package:mint_mobile/widgets/profile/financial_summary_card.dart';

/// Content for the "Ce que tu as" patrimoine drawer.
///
/// Displays liquidites, immobilier, prevoyance capital, conjoint summary,
/// and patrimoine net totals. Uses [FinancialSummaryCard] for solo mode
/// and [CouplePatrimoineCard] when the profile is in couple mode.
///
/// Outil educatif -- ne constitue pas un conseil financier (LSFin).
class PatrimoineDrawerContent extends StatelessWidget {
  final CoachProfile profile;

  const PatrimoineDrawerContent({super.key, required this.profile});

  ProfileDataSource _source(String field) {
    return profile.dataSources[field] ?? ProfileDataSource.estimated;
  }

  @override
  Widget build(BuildContext context) {
    if (profile.isCouple) {
      return Column(children: [_buildCouplePatrimoine(context)]);
    }
    return Column(children: [_buildPatrimoineCard(context)]);
  }

  // ══════════════════════════════════════════════════════════════
  //  SOLO MODE — FinancialSummaryCard with FinancialLine items
  // ══════════════════════════════════════════════════════════════

  FinancialSummaryCard _buildPatrimoineCard(BuildContext context) {
    final pat = profile.patrimoine;
    final det = profile.dettes;
    final prev = profile.prevoyance;
    final lines = <FinancialLine>[];
    final l10n = S.of(context)!;

    // -- Liquidites --
    lines.add(FinancialLine(
      label: l10n.financialSummaryLiquidites,
      isSectionHeader: true,
    ));
    lines.add(FinancialLine(
      label: l10n.financialSummaryEpargneLiquide,
      formattedValue: formatChfOrDash(pat.epargneLiquide),
      source: _source('patrimoine.epargneLiquide'),
    ));
    lines.add(FinancialLine(
      label: l10n.financialSummaryInvestissements,
      formattedValue: formatChfOrDash(pat.investissements),
      source: _source('patrimoine.investissements'),
    ));

    // -- Immobilier (si renseigne) --
    final hasProperty = pat.immobilierEffectif > 0;
    if (hasProperty) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryImmobilier,
        isSectionHeader: true,
      ));
      if (pat.propertyDescription != null) {
        lines.add(FinancialLine(
          label: pat.propertyDescription!,
          formattedValue: '',
        ));
      }
      lines.add(FinancialLine(
        label: l10n.financialSummaryValeurEstimee,
        formattedValue: formatChfOrDash(pat.immobilierEffectif),
        source: _source('patrimoine.propertyMarketValue'),
      ));
      if ((pat.mortgageBalance ?? 0) > 0) {
        lines.add(FinancialLine(
          label: l10n.financialSummaryHypothequeRestante,
          formattedValue: '\u2212 ${formatChfOrDash(pat.mortgageBalance)}',
          isDeduction: true,
        ));
        lines.add(FinancialLine(
          label: l10n.financialSummaryValeurNetteImmobiliere,
          formattedValue: formatChfOrDash(pat.immobilierNet),
          isSubtotal: true,
        ));
        // LTV ratio with FINMA advice
        final ltv = pat.loanToValue;
        final ltvPct = formatPct(ltv * 100);
        lines.add(FinancialLine(
          label: ltv > 0.67
              ? l10n.financialSummaryLtvAmortissement(ltvPct)
              : ltv > 0.50
                  ? l10n.financialSummaryLtvBonneVoie(ltvPct)
                  : l10n.financialSummaryLtvExcellent(ltvPct),
          isHint: true,
        ));
      }
    }

    // -- Prevoyance capital --
    lines.add(FinancialLine(
      label: l10n.financialSummaryPrevoyanceCapital,
      isSectionHeader: true,
    ));

    // AVS
    lines.add(FinancialLine(
      label: l10n.financialSummaryAvs1erPilier,
      formattedValue: '',
    ));
    lines.add(FinancialLine(
      label: l10n.financialSummaryAnneesCotisees,
      formattedValue: prev.anneesContribuees != null
          ? l10n.financialSummaryAnneesUnit('${prev.anneesContribuees}')
          : '\u2014',
      source: _source('prevoyance.anneesContribuees'),
      indent: true,
    ));
    if (prev.lacunesAVS != null && prev.lacunesAVS! > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryLacunes,
        formattedValue:
            l10n.financialSummaryAnneesUnit('${prev.lacunesAVS}'),
        source: _source('prevoyance.lacunesAVS'),
        indent: true,
      ));
    }
    lines.add(FinancialLine(
      label: l10n.financialSummaryRenteEstimee,
      formattedValue: prev.renteAVSEstimeeMensuelle != null
          ? formatChfMonthly(prev.renteAVSEstimeeMensuelle)
          : '\u2014',
      source: _source('prevoyance.renteAVSEstimeeMensuelle'),
      indent: true,
      isLast: true,
    ));

    // LPP
    lines.add(FinancialLine(
      label: l10n.financialSummaryLpp2ePilier,
      formattedValue: '',
    ));
    if ((prev.avoirLppTotal ?? 0) > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryAvoirTotal,
        formattedValue: formatChfOrDash(prev.avoirLppTotal),
        source: _source('prevoyance.avoirLppTotal'),
        indent: true,
      ));
    }
    if (prev.avoirLppObligatoire != null) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryObligatoire,
        formattedValue: formatChfOrDash(prev.avoirLppObligatoire),
        indent: true,
      ));
    }
    if (prev.avoirLppSurobligatoire != null) {
      lines.add(FinancialLine(
        label: l10n.financialSummarySurobligatoire,
        formattedValue: formatChfOrDash(prev.avoirLppSurobligatoire),
        indent: true,
      ));
    }
    lines.add(FinancialLine(
      label: l10n.financialSummaryTauxConversion,
      formattedValue: formatPctOrDash(prev.tauxConversion),
      source: _source('prevoyance.tauxConversion'),
      indent: true,
    ));
    if (prev.lacuneRachatRestante > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryRachatPossible,
        formattedValue: formatChfOrDash(prev.lacuneRachatRestante),
        indent: true,
      ));
    }
    if (profile.totalLppBuybackMensuel > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryRachatPlanifie,
        formattedValue: formatChfMonthly(profile.totalLppBuybackMensuel),
        source: ProfileDataSource.userInput,
        indent: true,
      ));
    }
    if (prev.nomCaisse != null) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryCaisse,
        formattedValue: prev.nomCaisse!,
        indent: true,
        isLast: true,
      ));
    }

    // 3a
    lines.add(FinancialLine(
      label: l10n.financialSummary3a3ePilier,
      formattedValue: '',
    ));
    if (prev.comptes3a.isNotEmpty) {
      for (int i = 0; i < prev.comptes3a.length; i++) {
        final c = prev.comptes3a[i];
        lines.add(FinancialLine(
          label: c.provider,
          formattedValue: formatChfOrDash(c.solde),
          indent: true,
          isLast: i == prev.comptes3a.length - 1 &&
              prev.librePassage.isEmpty,
        ));
      }
    } else {
      lines.add(FinancialLine(
        label: l10n.financialSummaryNComptes('${prev.nombre3a}'),
        formattedValue: formatChfOrDash(prev.totalEpargne3a),
        source: _source('prevoyance.totalEpargne3a'),
        indent: true,
        isLast: prev.librePassage.isEmpty,
      ));
    }

    // Libre passage
    if (prev.librePassage.isNotEmpty) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryLibrePassage,
        formattedValue: '',
      ));
      for (int i = 0; i < prev.librePassage.length; i++) {
        final lp = prev.librePassage[i];
        lines.add(FinancialLine(
          label: lp.institution ??
              l10n.financialSummaryCompteN('${i + 1}'),
          formattedValue: formatChfOrDash(lp.solde),
          indent: true,
          isLast: i == prev.librePassage.length - 1,
        ));
      }
    }

    // -- Conjoint prevoyance summary --
    if (profile.isCouple && profile.conjoint?.prevoyance != null) {
      final cp = profile.conjoint!.prevoyance!;
      lines.add(FinancialLine(
        label: l10n.financialSummaryConjointLpp(
            profile.conjoint?.firstName ??
                l10n.financialSummaryDefaultConjoint),
        formattedValue: formatChfOrDash(cp.avoirLppTotal),
      ));
      if (cp.totalEpargne3a > 0) {
        lines.add(FinancialLine(
          label: l10n.financialSummaryConjoint3a(
              profile.conjoint?.firstName ??
                  l10n.financialSummaryDefaultConjoint),
          formattedValue: formatChfOrDash(cp.totalEpargne3a),
        ));
      }
      if (profile.conjoint!.isFatcaResident) {
        lines.add(FinancialLine(
          label: l10n.financialSummaryFatcaWarning,
          formattedValue: '',
          source: ProfileDataSource.estimated,
          indent: true,
        ));
      }
    }

    // -- Totaux --
    final prevCapital = (prev.avoirLppTotal ?? 0) +
        prev.totalEpargne3a +
        prev.totalLibrePassage;
    final patrimoineBrut = pat.epargneLiquide +
        pat.investissements +
        pat.immobilierEffectif +
        prevCapital;
    final patrimoineNet = patrimoineBrut - det.totalDettes;

    lines.add(FinancialLine(
      label: l10n.financialSummaryPatrimoineBrut,
      formattedValue: formatChfOrDash(patrimoineBrut),
      isSubtotal: true,
    ));
    if (det.totalDettes > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryDettesTotales,
        formattedValue: '\u2212 ${formatChfOrDash(det.totalDettes)}',
        isDeduction: true,
      ));
    }

    return FinancialSummaryCard(
      title: l10n.financialSummaryPatrimoine,
      icon: Icons.savings_outlined,
      iconColor: MintColors.success,
      lines: lines,
      totalLine: FinancialLine(
        label: l10n.financialSummaryPatrimoineTotalBloque,
        formattedValue: formatChfOrDash(patrimoineNet),
        isHero: true,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  COUPLE MODE — CouplePatrimoineCard
  // ══════════════════════════════════════════════════════════════

  Widget _buildCouplePatrimoine(BuildContext context) {
    final pat = profile.patrimoine;
    final prev = profile.prevoyance;
    final det = profile.dettes;
    final conjoint = profile.conjoint;
    final cp = conjoint?.prevoyance;

    final prevCapital = (prev.avoirLppTotal ?? 0) +
        prev.totalEpargne3a +
        prev.totalLibrePassage;
    final conjointPrevCapital = (cp?.avoirLppTotal ?? 0) +
        (cp?.totalEpargne3a ?? 0) +
        (cp?.totalLibrePassage ?? 0);
    final patrimoineBrut = pat.epargneLiquide +
        pat.investissements +
        pat.immobilierEffectif +
        prevCapital +
        conjointPrevCapital;
    final patrimoineNet = patrimoineBrut - det.totalDettes;

    return CouplePatrimoineCard(
      firstName:
          profile.firstName ?? S.of(context)!.financialSummaryToi,
      conjointFirstName: conjoint?.firstName,
      epargneLiquide: pat.epargneLiquide,
      investissements: pat.investissements,
      immobilierValeur: pat.immobilierEffectif,
      mortgageBalance: pat.mortgageBalance ?? 0,
      loanToValue: pat.loanToValue,
      propertyDescription: pat.propertyDescription,
      avoirLpp: prev.avoirLppTotal ?? 0,
      conjointAvoirLpp: cp?.avoirLppTotal ?? 0,
      capital3a: prev.totalEpargne3a,
      conjointCapital3a: cp?.totalEpargne3a ?? 0,
      librePassage: prev.totalLibrePassage,
      totalDettes: det.totalDettes,
      patrimoineBrut: patrimoineBrut,
      patrimoineNet: patrimoineNet,
      partUser: prevCapital +
          pat.epargneLiquide +
          pat.investissements +
          pat.immobilierEffectif,
      partConjoint: conjointPrevCapital,
      conjointIsEstimated: conjoint?.invitationLevel != 'linked',
    );
  }
}
