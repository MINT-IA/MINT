import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/domain/budget/present_budget_builder.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_loading_skeleton.dart';

/// Budget summary card for the Mon argent tab.
///
/// 4 states: loading, empty, error, data.
/// StatelessWidget — parent passes data, no internal context.watch.
class BudgetSummaryCard extends StatelessWidget {
  final BudgetSnapshot? snapshot;
  final BudgetInputs? inputs;
  final BudgetPlan? plan;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onSetup;

  const BudgetSummaryCard({
    super.key,
    this.snapshot,
    this.inputs,
    this.plan,
    this.isLoading = false,
    this.hasError = false,
    this.onTap,
    this.onRetry,
    this.onSetup,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    if (isLoading) return _buildLoading();
    if (hasError) return _buildError(l10n);
    if (snapshot != null) return _buildSnapshotData(l10n, snapshot!);
    if (inputs != null && plan != null) return _buildData(l10n);
    if (inputs == null) return _buildEmpty(l10n);
    return _buildData(l10n);
  }

  Widget _buildLoading() {
    return const MintSurface(
      child: Padding(
        padding: EdgeInsets.all(MintSpacing.lg),
        child: MintLoadingSkeleton(lineCount: 3),
      ),
    );
  }

  Widget _buildEmpty(S l10n) {
    return MintSurface(
      child: Padding(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.monArgentBudgetTitle,
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              l10n.monArgentBudgetEmpty,
              style: MintTextStyles.bodyMedium(color: MintColors.ardoise),
            ),
            const SizedBox(height: MintSpacing.md),
            // dart format off
            FilledButton(
              // lint-ignore: prefer_mint_cta
              onPressed: onSetup,
              child: Text(l10n.monArgentBudgetStart),
            ),
            // dart format on
          ],
        ),
      ),
    );
  }

  Widget _buildError(S l10n) {
    return MintSurface(
      child: Padding(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.monArgentBudgetTitle,
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              l10n.monArgentBudgetError,
              style: MintTextStyles.bodyMedium(color: MintColors.ardoise),
            ),
            const SizedBox(height: MintSpacing.md),
            // dart format off
            OutlinedButton(
              // lint-ignore: prefer_mint_cta
              onPressed: onRetry,
              child: Text(l10n.monArgentRetry),
            ),
            // dart format on
          ],
        ),
      ),
    );
  }

  Widget _buildData(S l10n) {
    final present = PresentBudgetBuilder.fromInputs(
      inputs: inputs!,
      plan: plan ??
          const BudgetPlan(
            available: 0,
            variables: 0,
            future: 0,
            stopRuleTriggered: false,
            emergencyFundMonths: 0,
          ),
    );

    return _buildRows(
      l10n: l10n,
      monthlyIncome: present.monthlyNet,
      spent: present.monthlyCharges + present.monthlySavings,
      available: present.monthlyFree,
    );
  }

  Widget _buildSnapshotData(S l10n, BudgetSnapshot snapshot) {
    final present = snapshot.present;
    return _buildRows(
      l10n: l10n,
      monthlyIncome: present.monthlyNet,
      spent: present.monthlyCharges + present.monthlySavings,
      available: present.monthlyFree,
    );
  }

  Widget _buildRows({
    required S l10n,
    required double monthlyIncome,
    required double spent,
    required double available,
  }) {
    return Semantics(
      key: const Key('mon_argent_budget_summary'),
      identifier: 'mon_argent_budget_summary',
      label: '${l10n.monArgentBudgetTitle}. '
          '${l10n.monArgentBudgetIncome} ${_formatChf(monthlyIncome)}. '
          '${l10n.monArgentBudgetSpent} ${_formatChf(spent)}. '
          '${l10n.monArgentBudgetRemaining} ${_formatChf(available)}.',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        child: MintSurface(
          child: Padding(
            padding: const EdgeInsets.all(MintSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.monArgentBudgetTitle,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MintSpacing.md),
                _BudgetFlowBar(
                  monthlyIncome: monthlyIncome,
                  spent: spent,
                  available: available,
                  l10n: l10n,
                ),
                const SizedBox(height: MintSpacing.md),
                _buildRow(l10n.monArgentBudgetIncome, monthlyIncome),
                const SizedBox(height: MintSpacing.xs),
                _buildRow(l10n.monArgentBudgetSpent, spent),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: MintSpacing.sm),
                  child: Divider(
                    height: 1,
                    color: MintColors.lightBorder,
                  ),
                ),
                _buildRow(
                  l10n.monArgentBudgetRemaining,
                  available,
                  style: MintTextStyles.titleLarge(
                    color: MintColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, double amount, {TextStyle? style}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: style ??
              MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        Text(
          _formatChf(amount),
          style:
              style ?? MintTextStyles.bodyMedium(color: MintColors.textPrimary),
        ),
      ],
    );
  }

  String _formatChf(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => "${match[1]}'",
        );
    return "$formatted\u00a0CHF";
  }
}

class _BudgetFlowBar extends StatelessWidget {
  final double monthlyIncome;
  final double spent;
  final double available;
  final S l10n;

  const _BudgetFlowBar({
    required this.monthlyIncome,
    required this.spent,
    required this.available,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final safeIncome = monthlyIncome.isFinite ? max(0.0, monthlyIncome) : 0.0;
    final safeSpent = spent.isFinite ? max(0.0, spent) : 0.0;
    final safeAvailable = available.isFinite ? max(0.0, available) : 0.0;
    final total = max(safeIncome, safeSpent + safeAvailable);
    final spentFlex = _shareFlex(safeSpent, total);
    final availableFlex = _shareFlex(safeAvailable, total);
    final reserveFlex = max(0, 100 - spentFlex - availableFlex);

    return Semantics(
      key: const Key('mon_argent_budget_flow_bar'),
      identifier: 'mon_argent_budget_flow_bar',
      container: true,
      label: '${l10n.monArgentBudgetSpent} ${_formatChf(safeSpent)}. '
          '${l10n.monArgentBudgetRemaining} ${_formatChf(safeAvailable)}.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 12,
          child: Row(
            children: [
              if (spentFlex > 0)
                Expanded(
                  flex: spentFlex,
                  child: const ColoredBox(color: MintColors.pecheDouce),
                ),
              if (availableFlex > 0)
                Expanded(
                  flex: availableFlex,
                  child: ColoredBox(
                    color: available < 0 ? MintColors.error : MintColors.sauge,
                  ),
                ),
              if (reserveFlex > 0)
                Expanded(
                  flex: reserveFlex,
                  child: const ColoredBox(color: MintColors.borderSubtle),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _shareFlex(double value, double total) {
    if (total <= 0 || value <= 0) return 0;
    return max(1, (value / total * 100).round());
  }

  String _formatChf(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => "${match[1]}'",
        );
    return "$formatted\u00a0CHF";
  }
}
