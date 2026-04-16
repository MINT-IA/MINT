import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

/// Banner displayed when projection confidence is below 70%.
///
/// Shows:
/// - Warning icon + "Resultat indicatif" text
/// - Mini confidence gauge (0-100%)
/// - CTA to the most impactful data enrichment block
///
/// Hidden when confidence >= 70%.
class IndicatifBanner extends StatelessWidget {
  final double confidenceScore;

  /// Optional 4-axis enhanced confidence. When provided it is threaded
  /// into [MintTrameConfiance.inline] as-is. When null, the banner
  /// synthesises a minimal [EnhancedConfidence] from [confidenceScore]
  /// via [EnhancedConfidence.fromBareScore] so the 3 existing bare-double
  /// arbitrage call sites (Plan 08a-02 Batch A clarification, option b)
  /// keep working unchanged.
  final EnhancedConfidence? confidence;

  /// The most impactful enrichment prompt's category, used for the CTA.
  /// Falls back to 'lpp' if null.
  final String? topEnrichmentCategory;

  const IndicatifBanner({
    super.key,
    required this.confidenceScore,
    this.confidence,
    this.topEnrichmentCategory,
  });

  /// Maps enrichment categories to data block route types.
  static const _categoryToRoute = {
    'income': 'revenu',
    'lpp': 'lpp',
    'avs': 'avs',
    '3a': '3a',
    'patrimoine': 'patrimoine',
    'objectif_retraite': 'objectifRetraite',
    'menage': 'compositionMenage',
  };

  @override
  Widget build(BuildContext context) {
    if (confidenceScore >= 70) return const SizedBox.shrink();

    final route = _categoryToRoute[topEnrichmentCategory] ?? 'lpp';
    final pct = confidenceScore.round();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.accent.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.accent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 18, color: MintColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  S.of(context)!.indicativeBannerTitle(pct.toString()),
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // MintTrameConfiance (Plan 08a-02 Batch A) — replaces the
          // hand-rolled mini gauge. BloomStrategy.firstAppearance because
          // the banner is a standalone surface, not a feed item.
          MintTrameConfiance.inline(
            confidence: confidence ??
                EnhancedConfidence.fromBareScore(confidenceScore),
            bloomStrategy: BloomStrategy.firstAppearance,
          ),
          const SizedBox(height: 10),
          Text(
            S.of(context)!.indicativeBannerBody,
            style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push('/data-block/$route'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(
                S.of(context)!.indicativeBannerCta,
                style: MintTextStyles.bodySmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: MintColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
