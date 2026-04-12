import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

class NarrativeHeader extends StatelessWidget {
  final String? firstName;
  final String? conjointFirstName;
  final double freeMargin;
  final double patrimoineNet;
  final double replacementRate;

  /// 4-axis confidence (Plan 08a-02 Batch B). Optional: null = no MTC slot.
  /// Replaces the legacy `confidenceScore: double` API. Zero callers in
  /// production at the time of migration — clean API swap allowed.
  final EnhancedConfidence? confidence;

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
    this.confidence,
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
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w500, height: 1.5),
          ),
          if (confidence != null) ...[
            const SizedBox(height: 14),
            // MintTrameConfiance (Plan 08a-02 Batch B) — replaces the legacy
            // LinearProgressIndicator + percent label. Renders the WEAKEST
            // axis only via oneLineConfidenceSummary. firstAppearance because
            // the narrative header is a standalone surface.
            MintTrameConfiance.inline(
              confidence: confidence!,
              bloomStrategy: BloomStrategy.firstAppearance,
            ),
          ],
          if (boostAction != null && confidenceBoostAvailable != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                label: 'Améliorer la confiance',
                button: true,
                child: GestureDetector(
                  onTap: onBoostTap,
                  child: Text(
                    '\u{1F4C4} $boostAction (+$confidenceBoostAvailable%)',
                    style: MintTextStyles.labelMedium(color: MintColors.info).copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
