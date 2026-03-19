import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

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

  String _buildNarrative(S l) {
    final name = firstName ?? l.narrativeDefaultName;
    final isCouple = conjointFirstName != null;
    final hasHighPatrimoine = patrimoineNet > 500000;
    final marginStr = formatChf(freeMargin.abs());
    final patStr = formatChf(patrimoineNet);

    // Couple variant
    if (isCouple) {
      final base = freeMargin >= 0
          ? l.narrativeCouplePositiveMargin(marginStr)
          : l.narrativeCoupleTightBudget(marginStr);
      if (hasHighPatrimoine) {
        return '$base ${l.narrativeCoupleHighPatrimoine(patStr)}';
      }
      return base;
    }

    // Solo variants by health level
    if (replacementRate > 60 && freeMargin > 0) {
      final phrase = l.narrativeHighHealth(name);
      if (hasHighPatrimoine) {
        return '$phrase ${l.narrativeHighHealthPatrimoine(patStr)}';
      }
      return phrase;
    }

    if (replacementRate < 40 || freeMargin < 0) {
      final phrase = l.narrativeLowHealth(name);
      if (hasHighPatrimoine) {
        return '$phrase ${l.narrativeLowHealthPatrimoine(patStr)}';
      }
      return phrase;
    }

    // Medium health
    final phrase = l.narrativeMediumHealth(name);
    if (hasHighPatrimoine) {
      return '$phrase ${l.narrativeMediumHealthPatrimoine(patStr)}';
    }
    return phrase;
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
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
            _buildNarrative(l),
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
                l.narrativeConfidenceLabel('${clampedScore.round()}'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textMuted,
                ),
              ),
              if (boostAction != null &&
                  confidenceBoostAvailable != null) ...[
                const Spacer(),
                Semantics(
                  label: 'Améliorer la confiance',
                  button: true,
                  child: GestureDetector(
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
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
