import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/visibility_score_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Carte principale du score de visibilite financiere.
///
/// Affiche le pourcentage global + 4 barres d'axes.
/// Le score mesure la CLARTE (ce que l'utilisateur sait),
/// pas la QUALITE de sa situation.
class VisibilityScoreCard extends StatelessWidget {
  final VisibilityScore score;

  const VisibilityScoreCard({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header : titre + score ────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  'Visibilité financière',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              _buildScoreBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            score.narrative,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // ── 4 axes ───────────────────────────────────────
          ...score.axes.map((axis) => _buildAxisBar(axis)),

          // ── Alerte couple (si applicable) ────────────────
          if (score.coupleWeakName != null &&
              score.coupleWeakScore != null &&
              (score.total - score.coupleWeakScore!).abs() > 15)
            _buildCoupleAlert(),
        ],
      ),
    );
  }

  Widget _buildScoreBadge() {
    final color = _scoreColor(score.percentage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${score.percentage}%',
        style: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAxisBar(VisibilityAxis axis) {
    final color = _axisColor(axis);
    final progress = axis.maxScore > 0 ? axis.score / axis.maxScore : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconForAxis(axis.id),
                size: 16,
                color: MintColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  axis.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${axis.score.round()}/${axis.maxScore.round()}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: MintColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoupleAlert() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MintColors.warning.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: MintColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Le profil de ${score.coupleWeakName} est à '
              '${score.coupleWeakScore?.round() ?? 0}\u00a0% de visibilité',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForAxis(String id) {
    return switch (id) {
      'liquidite' => Icons.account_balance_wallet_outlined,
      'fiscalite' => Icons.receipt_long_outlined,
      'retraite' => Icons.beach_access_outlined,
      'securite' => Icons.shield_outlined,
      _ => Icons.info_outline,
    };
  }

  Color _axisColor(VisibilityAxis axis) {
    if (axis.percentage >= 80) return MintColors.scoreExcellent;
    if (axis.percentage >= 50) return MintColors.scoreBon;
    if (axis.percentage >= 25) return MintColors.scoreAttention;
    return MintColors.scoreCritique;
  }

  static Color _scoreColor(int percentage) {
    if (percentage >= 75) return MintColors.scoreExcellent;
    if (percentage >= 60) return MintColors.scoreBon;
    if (percentage >= 40) return MintColors.scoreAttention;
    return MintColors.scoreCritique;
  }
}
