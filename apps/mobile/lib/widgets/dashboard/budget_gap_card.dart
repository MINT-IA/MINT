import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  BUDGET GAP CARD — Chantier 2 / Retirement Cockpit
// ────────────────────────────────────────────────────────────
//
//  Affiche le budget previsionnel a la retraite :
//    Total revenus - Impot estime - Depenses = Solde mensuel
//
//  Couleur : vert si excedent, rouge si deficit.
//  Alertes affichees si seuils depasses (taux remplacement < 60%, etc.)
//
//  Source : RetirementBudgetGap (RetirementProjectionService)
//  Widget pur — aucune dependance Provider.
//  Aucun terme banni (garanti, certain, optimal, meilleur…).
// ────────────────────────────────────────────────────────────

class BudgetGapCard extends StatelessWidget {
  final RetirementBudgetGap budgetGap;

  const BudgetGapCard({super.key, required this.budgetGap});

  @override
  Widget build(BuildContext context) {
    final isSurplus = budgetGap.soldeMensuel >= 0;
    final soldeColor = isSurplus ? MintColors.success : MintColors.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: soldeColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSurplus
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: soldeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Budget retraite estim\u00e9',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Budget lines
          _buildLine(
            label: 'Revenus totaux',
            amount: budgetGap.totalRevenusMensuel,
            color: MintColors.textPrimary,
          ),
          const SizedBox(height: 8),
          _buildLine(
            label: 'Imp\u00f4t estim\u00e9',
            amount: -budgetGap.impotEstimeMensuel,
            color: MintColors.textSecondary,
            isDeduction: true,
          ),
          const SizedBox(height: 8),
          _buildLine(
            label: 'D\u00e9penses estim\u00e9es',
            amount: -budgetGap.depensesMensuelles,
            color: MintColors.textSecondary,
            isDeduction: true,
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: MintColors.lightBorder),
          const SizedBox(height: 12),

          // Solde
          Row(
            children: [
              Expanded(
                child: Text(
                  isSurplus ? 'Exc\u00e9dent mensuel' : 'D\u00e9ficit mensuel',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${isSurplus ? '+' : ''}${_formatChf(budgetGap.soldeMensuel)}',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: soldeColor,
                ),
              ),
            ],
          ),

          // Alerts
          if (budgetGap.alertes.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...budgetGap.alertes.map((alerte) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: MintColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          alerte,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: MintColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildLine({
    required String label,
    required double amount,
    required Color color,
    bool isDeduction = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: color,
            ),
          ),
        ),
        Text(
          '${isDeduction ? '\u2212 ' : ''}${_formatChf(amount.abs())}',
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  static String _formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF\u00a0${buffer.toString()}';
  }
}
