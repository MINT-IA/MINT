import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/coach/rich_chat_widgets.dart';

// ────────────────────────────────────────────────────────────
//  COACH RICH WIDGETS — extracted from coach_chat_screen.dart
// ────────────────────────────────────────────────────────────

/// Builds rich inline widgets based on user message context and profile data.
///
/// Returns null if no widget is appropriate or required data is missing.
class CoachRichWidgetBuilder {
  const CoachRichWidgetBuilder._();

  /// Build an optional rich inline widget based on the user's message
  /// and profile data. Returns null if no widget is appropriate or if
  /// required data is missing.
  static Widget? build(
      BuildContext context, String userMessage, CoachProfile profile) {
    final lower = userMessage.toLowerCase();

    // --- Rente vs Capital ---
    if ((lower.contains('rente') && lower.contains('capital')) ||
        lower.contains('rente ou capital') ||
        lower.contains('capital ou rente')) {
      return _buildRenteVsCapitalWidget(context, profile);
    }

    // --- Retirement projection ---
    if (lower.contains('retraite') ||
        lower.contains('pension') ||
        lower.contains('combien a la retraite') ||
        lower.contains('combien à la retraite')) {
      return _buildRetirementComparisonWidget(context, profile);
    }

    // --- Financial fitness score ---
    if (lower.contains('score') ||
        lower.contains('fitness') ||
        lower.contains('forme financ') ||
        lower.contains('fri')) {
      return _buildFitnessGaugeWidget(context, profile);
    }

    // --- Tax / 3a ---
    if (lower.contains('impot') ||
        lower.contains('impôt') ||
        lower.contains('fiscal') ||
        lower.contains('3a') ||
        lower.contains('déduction')) {
      return _buildTaxFactWidget(context, profile);
    }

    // --- Budget ---
    if (lower.contains('budget') ||
        lower.contains('dépense') ||
        lower.contains('depense') ||
        lower.contains('épargne') ||
        lower.contains('epargne')) {
      return _buildBudgetComparisonWidget(context, profile);
    }

    return null;
  }

  /// Retirement comparison: current monthly income vs projected retirement income.
  static Widget? _buildRetirementComparisonWidget(
      BuildContext context, CoachProfile profile) {
    try {
      final breakdown = NetIncomeBreakdown.compute(
        grossSalary: profile.salaireBrutMensuel * 12,
        canton: profile.canton,
        age: profile.age,
      );
      final netMensuel = breakdown.monthlyNetPayslip;
      if (netMensuel <= 0) return null;

      final proj = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      final revenuRetraite = proj.base.revenuAnnuelRetraite / 12;
      final taux = proj.tauxRemplacementBase;

      return ChatComparisonCard(
        title: 'Revenus\u00a0: aujourd\u2019hui vs retraite',
        leftLabel: 'Aujourd\u2019hui',
        leftValue: formatChfWithPrefix(netMensuel),
        rightLabel: 'Retraite (sc. base)',
        rightValue: formatChfWithPrefix(revenuRetraite),
        leftAmount: netMensuel,
        rightAmount: revenuRetraite,
        narrative: 'Taux de remplacement\u00a0: '
            '${(taux * 100).toStringAsFixed(0)}\u00a0% '
            'de ton revenu actuel.',
        onTap: () => context.push('/retraite'),
      );
    } catch (_) {
      return null;
    }
  }

  /// FRI gauge widget.
  static Widget? _buildFitnessGaugeWidget(
      BuildContext context, CoachProfile profile) {
    try {
      final score = FinancialFitnessService.calculate(profile: profile);
      return ChatGaugeCard(
        title: 'Forme financi\u00e8re',
        value: score.global.toDouble(),
        maxValue: 100,
        valueLabel: '${score.global}',
        subtitle: score.level.shortLabel,
        narrative: score.coachMessage,
        onTap: () => context.push('/confidence'),
      );
    } catch (_) {
      return null;
    }
  }

  /// Rente vs Capital comparison widget.
  static Widget? _buildRenteVsCapitalWidget(
      BuildContext context, CoachProfile profile) {
    try {
      final proj = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      final capitalTotal = proj.base.capitalFinal;
      if (capitalTotal <= 0) return null;

      // Rente: use LPP conversion rate on the LPP portion
      final lppPortion = proj.base.decomposition['lpp'] ?? 0;
      final tauxConversion = profile.prevoyance.tauxConversion;
      final renteMensuelle = (lppPortion * tauxConversion) / 12;

      return ChatChoiceComparison(
        title: 'Rente vs Capital (sc. base)',
        leftTitle: 'Rente LPP',
        leftValue: '${formatChf(renteMensuelle)}/mois',
        leftDescription: 'Revenu r\u00e9gulier \u00e0 vie, imposable',
        rightTitle: 'Capital',
        rightValue: formatChfWithPrefix(capitalTotal),
        rightDescription: 'Tax\u00e9 au retrait, flexibilit\u00e9',
        onTap: () => context.push('/rente-vs-capital'),
      );
    } catch (_) {
      return null;
    }
  }

  /// Tax savings fact card (3a deduction).
  static Widget? _buildTaxFactWidget(
      BuildContext context, CoachProfile profile) {
    try {
      // Max 3a deduction for salaried with LPP
      const max3a = 7258.0;

      // Estimate marginal tax savings
      final breakdown = NetIncomeBreakdown.compute(
        grossSalary: profile.salaireBrutMensuel * 12,
        canton: profile.canton,
        age: profile.age,
      );
      final netAnnuel = breakdown.netPayslip;
      // Approximate marginal rate (25-35% depending on canton/income)
      final marginalRate = netAnnuel > 100000 ? 0.32 : 0.25;
      final economieFiscale = max3a * marginalRate;

      return ChatFactCard(
        eyebrow: '\u00c9conomie fiscale 3a',
        value: '${formatChf(economieFiscale)}\u00a0CHF/an',
        description: 'En versant le maximum 3a '
            '(${formatChf(max3a)}\u00a0CHF), '
            'tu pourrais r\u00e9duire tes imp\u00f4ts d\u2019environ '
            'ce montant chaque ann\u00e9e.',
        accentColor: MintColors.success,
        onTap: () => context.push('/pilier-3a'),
      );
    } catch (_) {
      return null;
    }
  }

  /// Budget comparison: income vs expenses.
  static Widget? _buildBudgetComparisonWidget(
      BuildContext context, CoachProfile profile) {
    try {
      final breakdown = NetIncomeBreakdown.compute(
        grossSalary: profile.salaireBrutMensuel * 12,
        canton: profile.canton,
        age: profile.age,
      );
      final netMensuel = breakdown.monthlyNetPayslip;
      if (netMensuel <= 0) return null;

      final depenses = profile.totalDepensesMensuelles;
      if (depenses <= 0) return null;

      final epargne = netMensuel - depenses;
      final tauxEpargne = epargne / netMensuel;

      return ChatComparisonCard(
        title: 'Budget mensuel',
        leftLabel: 'Revenu net',
        leftValue: formatChfWithPrefix(netMensuel),
        rightLabel: 'D\u00e9penses',
        rightValue: formatChfWithPrefix(depenses),
        leftAmount: netMensuel,
        rightAmount: depenses,
        narrative: epargne > 0
            ? '\u00c9pargne\u00a0: ${formatChf(epargne)}\u00a0CHF/mois '
                '(${(tauxEpargne * 100).toStringAsFixed(0)}\u00a0% du net)'
            : 'Tes d\u00e9penses d\u00e9passent ton revenu net. '
                'Le coach peut t\u2019aider \u00e0 identifier des leviers.',
        onTap: () => context.push('/budget'),
      );
    } catch (_) {
      return null;
    }
  }
}
