import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/theme/colors.dart';

class NarrativeHeader extends StatelessWidget {
  final String? firstName;
  final String? conjointFirstName;
  final double freeMargin;
  final double patrimoineNet;
  final double replacementRate;
  final double confidenceScore;
  final int? confidenceBoostAvailable;
  final String? boostAction;
  final VoidCallback? onBoostTap;

  const NarrativeHeader({
    super.key,
    this.firstName,
    this.conjointFirstName,
    required this.freeMargin,
    required this.patrimoineNet,
    required this.replacementRate,
    required this.confidenceScore,
    this.confidenceBoostAvailable,
    this.boostAction,
    this.onBoostTap,
  });

  static final _chfFormat = NumberFormat('#,##0', 'fr_CH');

  String _formatChf(double amount) => _chfFormat.format(amount.round());

  String _buildNarrative() {
    final name = firstName ?? 'Tu';
    final isCouple = conjointFirstName != null;
    final hasHighPatrimoine = patrimoineNet > 500000;

    // Couple variant
    if (isCouple) {
      final marginStr = _formatChf(freeMargin.abs());
      final base = freeMargin >= 0
          ? 'Ensemble, vous avez une marge de $marginStr CHF/mois.'
          : 'Ensemble, votre budget est serré de $marginStr CHF/mois.';
      if (hasHighPatrimoine) {
        return '$base Avec un patrimoine de ${_formatChf(patrimoineNet)} CHF, vous avez des leviers.';
      }
      return base;
    }

    // Solo variants by health level
    if (replacementRate > 60 && freeMargin > 0) {
      // High health
      final phrase =
          '$name, tu es en bonne santé financière. Continue.';
      if (hasHighPatrimoine) {
        return '$phrase Ton patrimoine de ${_formatChf(patrimoineNet)} CHF te donne une belle marge de manœuvre.';
      }
      return phrase;
    }

    if (replacementRate < 40 || freeMargin < 0) {
      // Low health
      final phrase =
          '$name, concentre-toi sur l\'essentiel. On va stabiliser ensemble.';
      if (hasHighPatrimoine) {
        return '$phrase Ton patrimoine de ${_formatChf(patrimoineNet)} CHF est un atout à protéger.';
      }
      return phrase;
    }

    // Medium health
    final phrase =
        '$name, tu as de bonnes bases. Quelques actions peuvent faire la différence.';
    if (hasHighPatrimoine) {
      return '$phrase Ton patrimoine de ${_formatChf(patrimoineNet)} CHF est un bon point de départ.';
    }
    return phrase;
  }

  @override
  Widget build(BuildContext context) {
    final clampedScore = confidenceScore.clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Narrative phrase
          Text(
            _buildNarrative(),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // Confidence bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: clampedScore / 100,
                backgroundColor: MintColors.lightBorder,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(MintColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Confidence label + boost action
          Row(
            children: [
              Text(
                'Confiance profil : ${clampedScore.round()}%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textMuted,
                ),
              ),
              if (boostAction != null &&
                  confidenceBoostAvailable != null) ...[
                const Spacer(),
                GestureDetector(
                  onTap: onBoostTap,
                  child: Text(
                    '\u{1F4C4} $boostAction (+$confidenceBoostAvailable%)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.info,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
