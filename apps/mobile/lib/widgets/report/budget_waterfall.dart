import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class BudgetWaterfall extends StatelessWidget {
  final double income;
  final double housing;
  final double debt;
  final double taxes;
  final double healthInsurance;
  final double otherFixed;

  const BudgetWaterfall({
    super.key,
    required this.income,
    required this.housing,
    required this.debt,
    this.taxes = 0,
    this.healthInsurance = 0,
    this.otherFixed = 0,
  });

  double get available =>
      (income - housing - debt - taxes - healthInsurance - otherFixed)
          .clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row('Revenu net', income, MintColors.success, isPositive: true),
        const SizedBox(height: 8),
        if (housing > 0) ...[
          _row('Logement', housing, MintColors.textSecondary),
          const SizedBox(height: 8),
        ],
        if (debt > 0) ...[
          _row('Dettes', debt, MintColors.error),
          const SizedBox(height: 8),
        ],
        if (taxes > 0) ...[
          _row('Impôts (provision)', taxes, MintColors.textSecondary),
          const SizedBox(height: 8),
        ],
        if (healthInsurance > 0) ...[
          _row('Primes LAMal', healthInsurance, MintColors.textSecondary),
          const SizedBox(height: 8),
        ],
        if (otherFixed > 0) ...[
          _row('Autres fixes', otherFixed, MintColors.textSecondary),
          const SizedBox(height: 8),
        ],
        const Divider(height: 1),
        const SizedBox(height: 8),
        _row(
          'Disponible',
          available,
          available > income * 0.3
              ? MintColors.success
              : available > income * 0.1
                  ? MintColors.warning
                  : MintColors.error,
          isPositive: true,
          isBold: true,
        ),
      ],
    );
  }

  Widget _row(String label, double amount, Color color,
      {bool isPositive = false, bool isBold = false}) {
    final sign = isPositive ? '' : '\u2013 ';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: MintTextStyles.bodySmall(color: isBold ? MintColors.textPrimary : MintColors.textSecondary).copyWith(fontWeight: isBold ? FontWeight.w700 : FontWeight.w400),
            ),
          ],
        ),
        Text(
          '$sign CHF ${amount.toStringAsFixed(0)}',
          style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: isBold ? FontWeight.w700 : FontWeight.w500),
        ),
      ],
    );
  }
}
