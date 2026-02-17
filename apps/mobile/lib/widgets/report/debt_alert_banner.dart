import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

class DebtAlertBanner extends StatelessWidget {
  final double? monthlyPayment;
  final double? totalBalance;
  final VoidCallback? onTap;

  const DebtAlertBanner({
    super.key,
    this.monthlyPayment,
    this.totalBalance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MintColors.error.withValues(alpha: 0.12), MintColors.error.withValues(alpha: 0.06)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, color: MintColors.error, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Priorit\u00e9 : r\u00e9duire tes dettes',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MintColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (totalBalance != null && totalBalance! > 0)
            Text(
              'Solde restant : CHF ${totalBalance!.toStringAsFixed(0)}',
              style: GoogleFonts.inter(fontSize: 13, color: MintColors.textPrimary),
            ),
          if (monthlyPayment != null && monthlyPayment! > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Remboursement : CHF ${monthlyPayment!.toStringAsFixed(0)}/mois',
              style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(
                'Voir le plan de sortie',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
