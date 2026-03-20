import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// A calm notice about data confidence / estimation quality.
///
/// Used when projections are based on incomplete data (no LPP certificate,
/// estimated values). Shows the confidence level, a human message, and
/// optionally a CTA to improve precision.
///
/// Visual: warm surface (peche for low confidence, sauge for high),
/// no alarm colors, no aggressive badges.
class MintConfidenceNotice extends StatelessWidget {
  final int percent;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onTap;

  const MintConfidenceNotice({
    super.key,
    required this.percent,
    required this.message,
    this.ctaLabel,
    this.onTap,
  });

  bool get _isLow => percent < 50;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: _isLow
            ? MintColors.pecheDouce.withValues(alpha: 0.25)
            : MintColors.saugeClaire.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence bar
          Row(
            children: [
              Icon(
                _isLow ? Icons.tune_rounded : Icons.check_circle_outline,
                size: 16,
                color: _isLow ? MintColors.corailDiscret : MintColors.success,
              ),
              const SizedBox(width: MintSpacing.sm),
              Text(
                'Fiabilit\u00e9\u00a0: $percent\u00a0%',
                style: MintTextStyles.labelSmall(
                  color: _isLow
                      ? MintColors.corailDiscret
                      : MintColors.success,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),

          // Progress track
          const SizedBox(height: MintSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 4,
              backgroundColor: _isLow
                  ? MintColors.corailDiscret.withValues(alpha: 0.15)
                  : MintColors.success.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(
                _isLow ? MintColors.corailDiscret : MintColors.success,
              ),
            ),
          ),

          // Message
          const SizedBox(height: MintSpacing.md),
          Text(
            message,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),

          // CTA
          if (ctaLabel != null && onTap != null) ...[
            const SizedBox(height: MintSpacing.md),
            GestureDetector(
              onTap: onTap,
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: MintColors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ctaLabel!,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
