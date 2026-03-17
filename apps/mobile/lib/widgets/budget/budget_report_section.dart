import 'package:flutter/material.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/budget/spending_meter.dart';

class BudgetReportSection extends StatelessWidget {
  final BudgetPlan plan;
  final VoidCallback onEdit;

  const BudgetReportSection({
    super.key,
    required this.plan,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.budgetReportTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune, color: MintColors.info),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SpendingMeter(
                  variablesAmount: plan.variables,
                  futureAmount: plan.future,
                  totalAvailable: plan.available,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRow(context, l.budgetReportDisponible, plan.available,
                        isTotal: true),
                    const Divider(),
                    _buildRow(context, l.budgetReportVariables, plan.variables,
                        color: MintColors.success),
                    const SizedBox(height: 8),
                    _buildRow(context, l.budgetReportFutur, plan.future,
                        color: MintColors.info),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (plan.stopRuleTriggered)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: MintColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.budgetReportStopWarning,
                      style: const TextStyle(
                          fontSize: 12, color: MintColors.warning),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, double amount,
      {bool isTotal = false, Color? color}) {
    final l = S.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: MintColors.textSecondary,
          ),
        ),
        Text(
          l.budgetReportChfAmount(amount.toStringAsFixed(0)),
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: color ?? MintColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
