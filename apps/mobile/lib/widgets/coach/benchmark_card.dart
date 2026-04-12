import 'package:flutter/material.dart';
import 'package:mint_mobile/services/benchmark_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Displays a personal progress card — user's own evolution over time.
///
/// COMPLIANCE: No social comparison (CLAUDE.md § 6 — "No-Social-Comparison").
/// No "Top X%", no percentile badge, no "autres Suisses".
/// Only compares user to their own past values.
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
    final isPositiveDelta = benchmark.delta > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
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
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              // Personal delta badge (replaces removed "Top X%" percentile badge)
              if (benchmark.delta != 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isPositiveDelta
                            ? MintColors.success
                            : MintColors.warning)
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${isPositiveDelta ? '+' : ''}${benchmark.delta.toStringAsFixed(0)}',
                    style: MintTextStyles.labelSmall(color: isPositiveDelta ? MintColors.success : MintColors.warning).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Message
          Text(
            benchmark.message,
            style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
          ),

          // Source removed — no longer referencing OFS/BFS social comparisons
        ],
      ),
    );
  }
}
