import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/benchmark_service.dart';

/// Displays an anonymous comparison of the user vs Swiss averages.
///
/// Uses OFS/BFS public statistics — no user data is shared.
/// Styled as a subtle insight card integrated into the dashboard.
class BenchmarkCard extends StatelessWidget {
  final BenchmarkResult benchmark;
  final String label;
  final IconData icon;

  const BenchmarkCard({
    super.key,
    required this.benchmark,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isAbove = benchmark.percentile >= 50;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: const BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(icon, color: MintColors.coachAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              // Percentile badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isAbove ? MintColors.success : MintColors.warning)
                      .withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.circular(6),
                ),
                child: Text(
                  'Top ${isAbove ? (100 - benchmark.percentile) : benchmark.percentile}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isAbove ? MintColors.success : MintColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Comparison bar
          _buildComparisonBar(isAbove),
          const SizedBox(height: 10),

          // Message
          Text(
            benchmark.message,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),

          // Source
          const SizedBox(height: 6),
          Text(
            'Source : OFS/BFS ${benchmark.bracket} ans',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBar(bool isAbove) {
    return Row(
      children: [
        // User value
        Expanded(
          flex: benchmark.percentile.clamp(10, 90),
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: isAbove ? MintColors.success : MintColors.warning,
              borderRadius: const BorderRadius.horizontal(
                left: const Radius.circular(3),
              ),
            ),
          ),
        ),
        // Remaining
        Expanded(
          flex: (100 - benchmark.percentile).clamp(10, 90),
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: MintColors.lightBorder,
              borderRadius: const BorderRadius.horizontal(
                right: const Radius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
