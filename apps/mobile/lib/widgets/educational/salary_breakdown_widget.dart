import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/first_job_service.dart';

// ────────────────────────────────────────────────────────────
//  SALARY BREAKDOWN WIDGET — Sprint S19
// ────────────────────────────────────────────────────────────
//
// Reusable salary breakdown visualization:
// - Horizontal stacked bar (color segments for each deduction)
// - Legend below
// - Total net prominently displayed
// - Employer hidden contributions shown in dashed outline
// ────────────────────────────────────────────────────────────

class SalaryBreakdownWidget extends StatelessWidget {
  final double brut;
  final double netEstime;
  final double cotisationsEmployeur;
  final List<SalaryDeductionItem> deductions;

  const SalaryBreakdownWidget({
    super.key,
    required this.brut,
    required this.netEstime,
    required this.cotisationsEmployeur,
    required this.deductions,
  });

  /// Parse hex color string to Color.
  static Color _parseHexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'DECOMPOSITION DU SALAIRE',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gross → Net summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Brut',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  Text(
                    FirstJobService.formatChf(brut),
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward, size: 20, color: MintColors.textMuted),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Net estime',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  Text(
                    FirstJobService.formatChf(netEstime),
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: MintColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stacked bar
          if (brut > 0) _buildStackedBar(),
          const SizedBox(height: 16),

          // Legend
          ...deductions.map((d) => _buildLegendRow(d)),
          _buildLegendRow(
            SalaryDeductionItem(
              label: 'Net',
              montant: netEstime,
              pourcentage: (netEstime / brut) * 100,
              color: '#24B14D', // success green
            ),
            isNet: true,
          ),

          const SizedBox(height: 20),

          // Employer hidden contributions
          _buildEmployerSection(),
        ],
      ),
    );
  }

  Widget _buildStackedBar() {
    final totalDeductions =
        deductions.fold<double>(0, (sum, d) => sum + d.montant);
    final netPortion = brut - totalDeductions;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            // Deduction segments
            ...deductions.map((d) {
              final ratio = d.montant / brut;
              if (ratio <= 0) return const SizedBox.shrink();
              return Expanded(
                flex: (ratio * 1000).toInt().clamp(1, 999),
                child: Container(
                  color: _parseHexColor(d.color),
                  alignment: Alignment.center,
                  child: ratio > 0.05
                      ? Text(
                          '${d.pourcentage.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              );
            }),
            // Net portion
            Expanded(
              flex: ((netPortion / brut) * 1000).toInt().clamp(1, 999),
              child: Container(
                color: MintColors.success,
                alignment: Alignment.center,
                child: Text(
                  '${((netPortion / brut) * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(SalaryDeductionItem item, {bool isNet = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _parseHexColor(item.color),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isNet ? FontWeight.w600 : FontWeight.w400,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          Text(
            FirstJobService.formatChf(item.montant),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isNet ? MintColors.success : MintColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 45,
            child: Text(
              '${item.pourcentage.toStringAsFixed(1)}%',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textMuted,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployerSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MintColors.info.withValues(alpha: 0.4),
          width: 1.5,
          // Dashed effect simulated with a lighter style
        ),
        color: MintColors.info.withValues(alpha: 0.04),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.visibility_off_outlined, size: 18, color: MintColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contributions employeur (invisibles)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.info,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ton employeur verse ~${FirstJobService.formatChf(cotisationsEmployeur)}/mois '
                  'en plus de ton salaire brut (AVS part employeur, LPP part '
                  'employeur, LAA, etc.).',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
