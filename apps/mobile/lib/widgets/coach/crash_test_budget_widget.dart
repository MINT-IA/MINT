import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/budget_crash_financial_facts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P7-B  Crash-test budget — Budget actuel vs mode survie
//  Charte : L1 (CHF/mois) + L2 (Avant/Après) + L5 (1 action)
// ────────────────────────────────────────────────────────────

enum BudgetLineStatus { locked, cut, paused }

class BudgetLine {
  const BudgetLine({
    required this.label,
    required this.emoji,
    required this.normalAmount,
    required this.survivalAmount,
    required this.status,
  });

  final String label;
  final String emoji;
  final double normalAmount;
  final double survivalAmount;
  final BudgetLineStatus status;
}

class CrashTestBudgetWidget extends StatelessWidget {
  const CrashTestBudgetWidget({
    super.key,
    required this.monthlyIncome,
    required this.survivalIncome,
    required this.lines,
    this.survivalIncomeLabel = 'Survie',
    this.incomeFootnote,
    this.reserveMonths,
  });

  final double monthlyIncome;
  final double survivalIncome;
  final List<BudgetLine> lines;
  final String survivalIncomeLabel;
  final String? incomeFootnote;
  final double? reserveMonths;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final thousands = n ~/ 1000;
      final remainder = n % 1000;
      return remainder == 0
          ? "$thousands'000"
          : "$thousands'${remainder.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final totals = BudgetCrashFinancialFacts.calculate(
      monthlyIncome: monthlyIncome,
      survivalIncome: survivalIncome,
      normalAmounts: lines.map((l) => l.normalAmount),
      survivalAmounts: lines.map((l) => l.survivalAmount),
    );

    return Semantics(
      label: l10n.crashTestBudgetSemanticLabel,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(totals.saving, l10n),
            const Divider(height: 1),
            _buildColumnHeaders(l10n),
            ...lines.map((l) => _buildLine(l)),
            const Divider(height: 1),
            _buildTotalsRow(
              totals.totalNormal,
              totals.totalSurvival,
              l10n,
            ),
            _buildMarginRow(
              totals.marginNormal,
              totals.marginSurvival,
              l10n,
            ),
            if (reserveMonths != null)
              _buildReservePanel(totals.marginSurvival, l10n),
            _buildDisclaimer(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double saving, S l10n) {
    final hasAutomaticCuts = saving > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚗', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.crashTestBudgetTitle,
                  style:
                      MintTextStyles.titleMedium(color: MintColors.textPrimary)
                          .copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.crashTestBudgetSubtitle,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: MintColors.scoreCritique.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: MintColors.scoreCritique.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.content_cut,
                    color: MintColors.scoreCritique, size: 16),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(
                  hasAutomaticCuts
                      ? l10n.crashTestBudgetSavingLabel(_fmt(saving))
                      : l10n.crashTestBudgetNoAutomaticCuts,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.scoreCritique)
                          .copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders(S l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          SizedBox(
            width: 80,
            child: Text(
              l10n.crashTestBudgetNormalHeader,
              textAlign: TextAlign.center,
              style: MintTextStyles.labelSmall(color: MintColors.primary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              survivalIncomeLabel,
              textAlign: TextAlign.center,
              style: MintTextStyles.labelSmall(color: MintColors.scoreCritique)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildLine(BudgetLine line) {
    final (icon, color) = switch (line.status) {
      BudgetLineStatus.locked => ('🔒', MintColors.textSecondary),
      BudgetLineStatus.cut => ('✂️', MintColors.scoreAttention),
      BudgetLineStatus.paused => ('⏸️', MintColors.scoreCritique),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(line.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line.label,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              _fmt(line.normalAmount),
              textAlign: TextAlign.center,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              _fmt(line.survivalAmount),
              textAlign: TextAlign.center,
              style: MintTextStyles.bodySmall(
                      color: line.status == BudgetLineStatus.locked
                          ? MintColors.textSecondary
                          : color)
                  .copyWith(
                      fontWeight: line.status != BudgetLineStatus.locked
                          ? FontWeight.w700
                          : FontWeight.w400),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              icon,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsRow(double normal, double survival, S l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.crashTestBudgetTotalCharges,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              _fmt(normal),
              textAlign: TextAlign.center,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              _fmt(survival),
              textAlign: TextAlign.center,
              style: MintTextStyles.bodySmall(color: MintColors.scoreCritique)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMarginRow(double normal, double survival, S l10n) {
    final survivalColor =
        survival >= 0 ? MintColors.scoreExcellent : MintColors.scoreCritique;
    final survivalLabel =
        survival >= 0 ? '+${_fmt(survival)}' : '-${_fmt(survival.abs())}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: survivalColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: survivalColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.crashTestBudgetMonthlyMargin,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              normal >= 0 ? '+${_fmt(normal)}' : '-${_fmt(normal.abs())}',
              textAlign: TextAlign.center,
              style: MintTextStyles.bodySmall(
                      color: normal >= 0
                          ? MintColors.scoreExcellent
                          : MintColors.scoreCritique)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              survivalLabel,
              textAlign: TextAlign.center,
              style: MintTextStyles.bodySmall(color: survivalColor)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildReservePanel(double marginSurvival, S l10n) {
    final months = reserveMonths!;
    final color = months >= 6
        ? MintColors.scoreExcellent
        : months >= 3
            ? MintColors.scoreAttention
            : MintColors.scoreCritique;
    final label = months >= 6
        ? l10n.crashTestBudgetReserveSafe
        : months >= 3
            ? l10n.crashTestBudgetReserveWarning
            : l10n.crashTestBudgetReserveDanger;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.savings_outlined, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.crashTestBudgetReserveMonths(months.toStringAsFixed(1)),
                  style: MintTextStyles.bodySmall(color: color)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: MintTextStyles.labelMedium(
                      color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(S l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (incomeFootnote != null) ...[
            Text(
              incomeFootnote!,
              style: MintTextStyles.micro(color: MintColors.textSecondary),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            l10n.crashTestBudgetDisclaimer,
            style: MintTextStyles.micro(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
