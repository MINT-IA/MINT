import 'package:flutter/material.dart';
import 'package:mint_mobile/models/circle_score.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Widget d'affichage d'un score de cercle financier
class CircleScoreCard extends StatelessWidget {
  final CircleScore score;
  final VoidCallback? onTapDetails;

  const CircleScoreCard({
    super.key,
    required this.score,
    this.onTapDetails,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColorForLevel(score.level);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Semantics(
        label: score.circleName,
        button: true,
        child: InkWell(
          onTap: onTapDetails,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header : Numéro cercle + Nom
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${score.circleNumber}',
                        style: const TextStyle(
                          color: MintColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          score.circleName,
                          style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            Text(
                              score.level.emoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              score.level.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Score %
                  Text(
                    '${score.percentage.toInt()}%',
                    style: MintTextStyles.displayMedium(color: color).copyWith(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Barre de progression
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: score.percentage / 100,
                  minHeight: 12,
                  backgroundColor: MintColors.lightBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),

              const SizedBox(height: 16),

              // Items de score
              ...score.items.take(3).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          item.status.icon,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (item.detail != null)
                                Text(
                                  item.detail!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: MintColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),

              // Recommandations (si présentes)
              if (score.recommendations.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MintColors.disclaimerBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MintColors.yellowGold),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              size: 16, color: MintColors.warningText),
                          SizedBox(width: 8),
                          Text(
                            'Actions recommandées',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: MintColors.amberDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...score.recommendations.take(2).map((reco) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ',
                                    style: TextStyle(
                                        color: MintColors.warningText)),
                                Expanded(
                                  child: Text(
                                    reco,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: MintColors.amberDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],

              // Bouton détails
              if (onTapDetails != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: onTapDetails,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Voir les détails'),
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }

  Color _getColorForLevel(ScoreLevel level) {
    switch (level) {
      case ScoreLevel.excellent:
        return MintColors.categoryGreen;
      case ScoreLevel.good:
        return MintColors.success;
      case ScoreLevel.adequate:
        return MintColors.warning;
      case ScoreLevel.needsImprovement:
        return MintColors.deepOrange;
      case ScoreLevel.critical:
        return MintColors.redDeep;
    }
  }
}
