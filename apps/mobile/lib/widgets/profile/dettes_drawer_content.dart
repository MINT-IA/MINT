import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/profile/financial_summary_card.dart';

/// Content widget for the "Ce que tu dois" drawer in the Apercu Financier.
///
/// Displays structured debt information: hypotheque, consumer debt,
/// and a total line. Designed to be used as the `content` of a
/// [FinancialDrawer].
class DettesDrawerContent extends StatelessWidget {
  final CoachProfile profile;

  const DettesDrawerContent({super.key, required this.profile});

  ProfileDataSource _source(String field) {
    return profile.dataSources[field] ?? ProfileDataSource.estimated;
  }

  @override
  Widget build(BuildContext context) {
    final det = profile.dettes;
    final l10n = S.of(context)!;

    // ── Empty state ──
    if (!det.hasDette) {
      return FinancialSummaryCard(
        title: l10n.financialSummaryDettes,
        icon: Icons.credit_card_outlined,
        iconColor: MintColors.textMuted,
        lines: [
          FinancialLine(
            label: l10n.financialSummaryAucuneDetteDeclaree,
            formattedValue: '\u2014',
          ),
        ],
      );
    }

    final lines = <FinancialLine>[];

    // ── Dette structurelle (hypotheque) ──
    if (det.detteStructurelle > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryDetteStructurelle,
        isSectionHeader: true,
      ));

      final hypoLabel = det.rangHypotheque != null
          ? (det.rangHypotheque == 1
              ? l10n.financialSummaryHypotheque1erRang
              : l10n.financialSummaryHypotheque2emeRang)
          : l10n.financialSummaryHypotheque;
      final hypoDetail = det.tauxHypotheque != null
          ? ' (${formatPct(det.tauxHypotheque!)}\u00a0%)'
          : '';
      lines.add(FinancialLine(
        label: '$hypoLabel$hypoDetail',
        formattedValue: formatChfOrDash(det.hypotheque),
        source: _source('dettes.hypotheque'),
      ));

      if (det.mensualiteHypotheque != null) {
        lines.add(FinancialLine(
          label: l10n.financialSummaryChargeMensuelle,
          formattedValue: formatChfMonthly(det.mensualiteHypotheque),
          indent: true,
        ));
      }

      if (det.echeanceHypotheque != null) {
        final remaining =
            det.echeanceHypotheque!.difference(DateTime.now()).inDays;
        final years = (remaining / 365).ceil();
        lines.add(FinancialLine(
          label: l10n.financialSummaryEcheance(
            DateFormat('MM/yyyy').format(det.echeanceHypotheque!),
            '$years',
          ),
          formattedValue: '',
          indent: true,
          isLast: true,
        ));
      }

      if (det.tauxHypotheque != null) {
        final interets = det.interetsHypothecairesAnnuels;
        lines.add(FinancialLine(
          label: l10n.financialSummaryInteretsDeductibles(
              formatChfOrDash(interets)),
          isHint: true,
        ));
      }
    }

    // ── Dette a la consommation ──
    if (det.detteConsommation > 0 || (det.autresDettes ?? 0) > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryDetteConsommation,
        isSectionHeader: true,
      ));

      if (det.creditConsommation != null && det.creditConsommation! > 0) {
        final tauxLabel = det.tauxCreditConso != null
            ? ' (${formatPct(det.tauxCreditConso!)}\u00a0%)'
            : '';
        lines.add(FinancialLine(
          label: '${l10n.financialSummaryCreditConsommation}$tauxLabel',
          formattedValue: formatChfOrDash(det.creditConsommation),
          source: _source('dettes.creditConsommation'),
        ));
        if (det.mensualiteCreditConso != null) {
          lines.add(FinancialLine(
            label: l10n.financialSummaryMensualite,
            formattedValue: formatChfMonthly(det.mensualiteCreditConso),
            indent: true,
            isLast: det.echeanceCreditConso == null,
          ));
        }
      }

      if (det.leasing != null && det.leasing! > 0) {
        final tauxLabel = det.tauxLeasing != null
            ? ' (${formatPct(det.tauxLeasing!)}\u00a0%)'
            : '';
        lines.add(FinancialLine(
          label: '${l10n.financialSummaryLeasing}$tauxLabel',
          formattedValue: formatChfOrDash(det.leasing),
          source: _source('dettes.leasing'),
        ));
        if (det.mensualiteLeasing != null) {
          lines.add(FinancialLine(
            label: l10n.financialSummaryMensualite,
            formattedValue: formatChfMonthly(det.mensualiteLeasing),
            indent: true,
            isLast: true,
          ));
        }
      }

      if (det.autresDettes != null && det.autresDettes! > 0) {
        lines.add(FinancialLine(
          label: l10n.financialSummaryAutresDettes,
          formattedValue: formatChfOrDash(det.autresDettes),
          source: _source('dettes.autresDettes'),
        ));
      }

      // Conseil priorite remboursement si taux > 3%
      final tauxMax = det.tauxMaxConsommation;
      if (tauxMax != null && tauxMax > 3) {
        lines.add(FinancialLine(
          label: l10n.financialSummaryConseilRemboursement(formatPct(tauxMax)),
          isHint: true,
        ));
      }
    }

    final totalMensualite = det.totalMensualite;

    return FinancialSummaryCard(
      title: l10n.financialSummaryDettes,
      icon: Icons.credit_card_outlined,
      iconColor: MintColors.error,
      lines: lines,
      totalLine: FinancialLine(
        label: l10n.financialSummaryTotalDettes,
        formattedValue:
            '${formatChfOrDash(det.totalDettes)}${totalMensualite > 0 ? " (${formatChfMonthly(totalMensualite)})" : ""}',
      ),
    );
  }
}
