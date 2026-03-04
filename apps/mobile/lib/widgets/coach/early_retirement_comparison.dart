import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Early retirement comparison mini-table for 45-60 age group.
///
/// Shows replacement rate estimates at ages 63, 64, 65, 67, 70.
/// Only displayed for users aged 45+.
class EarlyRetirementComparison extends StatelessWidget {
  final CoachProfile profile;
  final double baseThreeAMonthly;
  final double baseLibreMonthly;

  const EarlyRetirementComparison({
    super.key,
    required this.profile,
    this.baseThreeAMonthly = 0,
    this.baseLibreMonthly = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (profile.age < 45) return const SizedBox.shrink();

    final grossMonthlySalary = profile.revenuBrutAnnuel / 12;
    if (grossMonthlySalary <= 0) return const SizedBox.shrink();

    final ages = [63, 64, 65, 67, 70];
    final rows = <_ComparisonRow>[];

    for (final retAge in ages) {
      if (retAge <= profile.age) continue;

      final avsMonthly = AvsCalculator.computeMonthlyRente(
        currentAge: profile.age,
        retirementAge: retAge,
        grossAnnualSalary: profile.revenuBrutAnnuel,
      );

      final lppBalance = profile.prevoyance.avoirLppTotal ?? 0;
      final lppRente = LppCalculator.projectToRetirement(
        currentBalance: lppBalance,
        currentAge: profile.age,
        retirementAge: retAge,
        grossAnnualSalary: profile.revenuBrutAnnuel,
        caisseReturn: profile.prevoyance.rendementCaisse,
        conversionRate: profile.prevoyance.tauxConversion,
      );
      final lppMonthly = lppRente / 12;

      final totalMonthly = avsMonthly + lppMonthly + baseThreeAMonthly + baseLibreMonthly;
      // Replacement rate on NET salary (via NetIncomeBreakdown)
      final netMonthlySalary = NetIncomeBreakdown.compute(
        grossSalary: grossMonthlySalary * 12,
        canton: profile.canton,
        age: profile.age,
      ).monthlyNetPayslip;
      final replacementRate =
          netMonthlySalary > 0 ? totalMonthly / netMonthlySalary : 0.0;

      rows.add(_ComparisonRow(
        age: retAge,
        totalMonthly: totalMonthly,
        replacementRate: replacementRate,
        isTarget: retAge == profile.effectiveRetirementAge,
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparaison retraite anticip\u00e9e',
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimation du taux de remplacement par \u00e2ge de d\u00e9part',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // Header row
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text('Age',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textMuted,
                    )),
              ),
              Expanded(
                child: Text('Revenu mensuel',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textMuted,
                    )),
              ),
              SizedBox(
                width: 70,
                child: Text('Taux',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textMuted,
                    )),
              ),
            ],
          ),
          const Divider(height: 12),
          ...rows.map((r) => _buildRow(r)),
          const SizedBox(height: 10),
          InkWell(
            onTap: null, // CTA disabled — cockpit detail screen coming in Pass 2
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Simuler ta retraite anticip\u00e9e',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward,
                    size: 16, color: MintColors.primary),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Outil \u00e9ducatif \u2014 les taux varient par caisse (LSFin).',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_ComparisonRow r) {
    final bgColor = r.isTarget
        ? MintColors.primary.withValues(alpha: 0.08)
        : Colors.transparent;
    final textWeight = r.isTarget ? FontWeight.w700 : FontWeight.w500;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Row(
              children: [
                Text(
                  '${r.age}',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: textWeight,
                    color: MintColors.textPrimary,
                  ),
                ),
                if (r.isTarget)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.star,
                        size: 12, color: MintColors.primary),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              'CHF ${r.totalMonthly.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: textWeight,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '${(r.replacementRate * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: textWeight,
                color: r.replacementRate >= 0.60
                    ? MintColors.scoreGreen
                    : r.replacementRate >= 0.45
                        ? MintColors.scoreAttention
                        : MintColors.scoreRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow {
  final int age;
  final double totalMonthly;
  final double replacementRate;
  final bool isTarget;

  const _ComparisonRow({
    required this.age,
    required this.totalMonthly,
    required this.replacementRate,
    required this.isTarget,
  });
}
