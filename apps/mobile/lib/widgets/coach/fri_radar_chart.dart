import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  FRI HORIZONTAL BARS — Design System compliant (radar banned)
// ────────────────────────────────────────────────────────────
//
// 4 horizontal progress bars for FRI sub-scores:
//   Liquidité    0-25   (info)
//   Flexibilité  0-25   (accent)
//   Résilience   0-25   (warning)
//   Stabilité    0-25   (success)
//
// Total score displayed above the bars.
//
// Outil éducatif — ne constitue pas un conseil financier (LSFin).
// ────────────────────────────────────────────────────────────

class FriRadarChart extends StatelessWidget {
  final double liquidity;
  final double fiscal;
  final double retirement;
  final double structural;
  final double size;

  const FriRadarChart({
    super.key,
    required this.liquidity,
    required this.fiscal,
    required this.retirement,
    required this.structural,
    this.size = 200,
  });

  double get total => liquidity + fiscal + retirement + structural;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    final bars = [
      _BarData(
        icon: Icons.water_drop_outlined,
        label: l10n.friBarLiquidity,
        value: liquidity,
        color: MintColors.info,
      ),
      _BarData(
        icon: Icons.swap_horiz,
        label: l10n.friBarFlexibility,
        value: fiscal,
        color: MintColors.accent,
      ),
      _BarData(
        icon: Icons.shield_outlined,
        label: l10n.friBarResilience,
        value: retirement,
        color: MintColors.warning,
      ),
      _BarData(
        icon: Icons.foundation,
        label: l10n.friBarStability,
        value: structural,
        color: MintColors.success,
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: MintColors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Total score ──
            Center(
              child: Column(
                children: [
                  Text(
                    l10n.friBarTitle,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    '${total.round()}\u00a0/\u00a0100',
                    style: MintTextStyles.displayMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MintSpacing.md),

            // ── Horizontal bars ──
            ...bars.map((bar) => _buildBar(bar)),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(_BarData bar) {
    final ratio = (bar.value / 25).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm),
      child: Row(
        children: [
          Icon(bar.icon, size: 18, color: bar.color),
          const SizedBox(width: MintSpacing.sm),
          SizedBox(
            width: 80,
            child: Text(
              bar.label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: MintColors.border.withAlpha(80),
                valueColor: AlwaysStoppedAnimation<Color>(bar.color),
              ),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          SizedBox(
            width: 36,
            child: Text(
              '${bar.value.round()}/25',
              style: MintTextStyles.labelSmall(
                color: MintColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarData {
  final IconData icon;
  final String label;
  final double value;
  final Color color;

  const _BarData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}
