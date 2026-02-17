import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

class BudgetWaterfall extends StatelessWidget {
  final double income;
  final double housing;
  final double debt;

  const BudgetWaterfall({
    super.key,
    required this.income,
    required this.housing,
    required this.debt,
  });

  double get available => (income - housing - debt).clamp(0, double.infinity);

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
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                color: isBold ? MintColors.textPrimary : MintColors.textSecondary,
              ),
            ),
          ],
        ),
        Text(
          '$sign CHF ${amount.toStringAsFixed(0)}',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
