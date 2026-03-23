import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// "Vos deux vies" — side-by-side couple retirement comparison.
///
/// The screenshot-worthy card that shows the GAP between two partners'
/// retirement realities and the lever to close it.
///
/// Design spec: UX Expert Panel, Iteration 3.
/// "The chart someone sends to their partner."
///
/// Usage:
/// ```dart
/// DeuxViesCard(
///   userName: 'Julien',
///   userMonthly: 5820,
///   userRate: 72,
///   conjointName: 'Lauren',
///   conjointMonthly: 2685,
///   conjointRate: 48,
///   leverLabel: 'Rachat LPP Lauren',
///   leverImpact: '40%',
/// )
/// ```
class DeuxViesCard extends StatelessWidget {
  final String userName;
  final double userMonthly;
  final double userRate;
  final String conjointName;
  final double conjointMonthly;
  final double conjointRate;
  final String? leverLabel;
  final String? leverImpact;
  final VoidCallback? onTap;

  const DeuxViesCard({
    super.key,
    required this.userName,
    required this.userMonthly,
    required this.userRate,
    required this.conjointName,
    required this.conjointMonthly,
    required this.conjointRate,
    this.leverLabel,
    this.leverImpact,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final gap = (userMonthly - conjointMonthly).abs();
    final gapSign = userMonthly > conjointMonthly ? userName : conjointName;

    return GestureDetector(
      onTap: onTap,
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              l.deuxViesTitle,
              style: MintTextStyles.headlineMedium(),
            ),
            const SizedBox(height: MintSpacing.lg),

            // Side-by-side comparison
            Row(
              children: [
                // User column
                Expanded(child: _PersonColumn(
                  name: userName,
                  monthly: userMonthly,
                  rate: userRate,
                )),
                // Divider
                Container(
                  width: 1,
                  height: 100,
                  color: MintColors.border.withValues(alpha: 0.3),
                ),
                // Conjoint column
                Expanded(child: _PersonColumn(
                  name: conjointName,
                  monthly: conjointMonthly,
                  rate: conjointRate,
                )),
              ],
            ),

            const SizedBox(height: MintSpacing.lg),

            // Gap line
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: MintSpacing.sm,
                horizontal: MintSpacing.md,
              ),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l.deuxViesGap(
                  _formatChf(gap),
                  gapSign,
                ),
                style: MintTextStyles.bodySmall(
                  color: MintColors.warning,
                ).copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),

            // Lever (if available)
            if (leverLabel != null && leverImpact != null) ...[
              const SizedBox(height: MintSpacing.md),
              Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: MintColors.accent,
                  ),
                  const SizedBox(width: MintSpacing.xs),
                  Expanded(
                    child: Text(
                      l.deuxViesLever(leverLabel!, leverImpact!),
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Disclaimer
            const SizedBox(height: MintSpacing.md),
            Text(
              l.deuxViesDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatChf(double amount) {
    final rounded = amount.round();
    if (rounded >= 1000) {
      final thousands = rounded ~/ 1000;
      final remainder = rounded % 1000;
      return "CHF\u00a0$thousands'${remainder.toString().padLeft(3, '0')}";
    }
    return 'CHF\u00a0$rounded';
  }
}

class _PersonColumn extends StatelessWidget {
  final String name;
  final double monthly;
  final double rate;

  const _PersonColumn({
    required this.name,
    required this.monthly,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    final rateColor = rate >= 70
        ? MintColors.success
        : rate >= 50
            ? MintColors.warning
            : MintColors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
      child: Column(
        children: [
          // Name
          Text(
            name,
            style: MintTextStyles.titleMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MintSpacing.sm),

          // Monthly amount
          Text(
            DeuxViesCard._formatChf(monthly),
            style: MintTextStyles.headlineMedium(color: rateColor),
            textAlign: TextAlign.center,
          ),
          Text(
            '/mois',
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MintSpacing.sm),

          // Rate
          Text(
            '${rate.round()}\u00a0%',
            style: MintTextStyles.bodyMedium(color: rateColor).copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
