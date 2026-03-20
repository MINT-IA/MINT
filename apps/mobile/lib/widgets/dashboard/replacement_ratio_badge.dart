import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  REPLACEMENT RATIO BADGE — Chantier 2 / Retirement Cockpit
// ────────────────────────────────────────────────────────────
//
//  Affiche le taux de remplacement de maniere prominente.
//  Code couleur :
//    >= 70% → vert (confortable)
//    55-69% → ambre (attention)
//    < 55%  → rouge (critique)
//
//  S'integre dans la zone du HeroRetirementCard ou juste en dessous.
//  Widget pur — aucune dependance Provider.
//  Aucun terme banni (garanti, certain, optimal, meilleur…).
// ────────────────────────────────────────────────────────────

class ReplacementRatioBadge extends StatelessWidget {
  /// Taux de remplacement en pourcentage (0-200).
  final double ratio;

  const ReplacementRatioBadge({super.key, required this.ratio});

  @override
  Widget build(BuildContext context) {
    final color = _colorForRatio(ratio);
    final icon = _iconForRatio(ratio);
    final message = _messageForRatio(ratio);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          // Circular progress indicator
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (ratio / 100).clamp(0.0, 1.0),
                  strokeWidth: 5,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Text(
                  '${ratio.round()}%',
                  style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      'Taux de remplacement',
                      style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${ratio.toStringAsFixed(0)}% de ton revenu actuel',
                  style: MintTextStyles.headlineMedium(color: color).copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _colorForRatio(double ratio) {
    if (ratio >= 70) return MintColors.success;
    if (ratio >= 55) return MintColors.warning;
    return MintColors.error;
  }

  static IconData _iconForRatio(double ratio) {
    if (ratio >= 70) return Icons.check_circle_outline;
    if (ratio >= 55) return Icons.info_outline;
    return Icons.warning_amber_outlined;
  }

  static String _messageForRatio(double ratio) {
    if (ratio >= 80) {
      return 'Couverture confortable. Le niveau de vie peut \u00eatre maintenu.';
    }
    if (ratio >= 70) {
      return 'Bon niveau. Quelques ajustements mineurs pourraient suffire.';
    }
    if (ratio >= 55) {
      return 'Niveau moyen. Des compl\u00e9ments (3a, \u00e9pargne) pourraient aider.';
    }
    return 'Niveau bas. Des actions de pr\u00e9voyance sont a envisager.';
  }
}
