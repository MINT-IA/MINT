import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

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
        // AESTH-06 per AUDIT_RETRAIT S5 (D-04 destructive-confirm exception:
        // debt banner is the single allowed errorAaa surface on S0-S5)
        gradient: LinearGradient(
          colors: [MintColors.errorAaa.withValues(alpha: 0.12), MintColors.errorAaa.withValues(alpha: 0.06)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.errorAaa.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // AESTH-06 per AUDIT_RETRAIT S5 (D-04 destructive-confirm exception)
              const Icon(Icons.warning_rounded, color: MintColors.errorAaa, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Priorit\u00e9 : r\u00e9duire tes dettes',
                  // AESTH-06 per AUDIT_RETRAIT S5 (D-04 destructive-confirm exception)
                  style: MintTextStyles.labelLarge(color: MintColors.errorAaa),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (totalBalance != null && totalBalance! > 0)
            Text(
              'Solde restant : ${formatChfWithPrefix(totalBalance!)}',
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          if (monthlyPayment != null && monthlyPayment! > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Remboursement : ${formatChfWithPrefix(monthlyPayment!)}/mois',
              // AESTH-05 per AUDIT_RETRAIT S5 (D-03 swap map)
              style: MintTextStyles.bodySmall(color: MintColors.textSecondaryAaa),
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
                style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                // AESTH-06 per AUDIT_RETRAIT S5 (D-04 destructive-confirm exception)
                backgroundColor: MintColors.errorAaa,
                foregroundColor: MintColors.white,
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
