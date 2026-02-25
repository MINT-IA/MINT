import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/confidence/confidence_breakdown_chart.dart';

/// Compact card wrapper for S46 confidence breakdown.
class ConfidenceBreakdownCard extends StatelessWidget {
  final double completeness;
  final double accuracy;
  final double freshness;

  const ConfidenceBreakdownCard({
    super.key,
    required this.completeness,
    required this.accuracy,
    required this.freshness,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: const Borderconst Radius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Precision des donnees',
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ConfidenceBreakdownChart(
            completeness: completeness,
            accuracy: accuracy,
            freshness: freshness,
          ),
        ],
      ),
    );
  }
}
