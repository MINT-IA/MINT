import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
  final BudgetInputs? inputs;
  final BudgetPlan? plan;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onSetup;

  const BudgetSummaryCard({
    super.key,
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
            FilledButton(
              onPressed: onSetup,
              child: Text(l10n.monArgentBudgetStart),
            ),
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
            OutlinedButton(
              onPressed: onRetry,
              child: Text(l10n.monArgentRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildData(S l10n) {
    final monthlyIncome = inputs!.netIncome;
    final available = plan?.available ?? 0;
    final spent = monthlyIncome - available;

    return Semantics(
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
          style: style ?? MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        Text(
          _formatChf(amount),
          style: style ?? MintTextStyles.bodyMedium(color: MintColors.textPrimary),
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
