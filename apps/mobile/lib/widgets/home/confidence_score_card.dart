import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

/// Card surfacing the user's projection precision score with the single
/// best enrichment action.
///
/// Placement: Aujourd'hui tab, below [FinancialPlanCard], above check-in section.
///
/// Requirements: UXP-02 (Phase 08-01).
class ConfidenceScoreCard extends StatelessWidget {
  /// Combined confidence score (0-100), from [EnhancedConfidence.combined].
  final double score;

  /// Optional 4-axis confidence (Plan 08a-02 Batch C). When non-null it is
  /// rendered via [MintTrameConfiance.detail]. When null, synthesised from
  /// [score] via [EnhancedConfidence.fromBareScore] for back-compat with
  /// the existing single-score API (tests + legacy callers).
  final EnhancedConfidence? confidence;

  /// Sorted enrichment prompts (by impact descending), from
  /// [EnhancedConfidence.axisPrompts].
  final List<EnrichmentPrompt> enrichmentPrompts;

  /// Tap callback for the enrichment CTA — navigates to profile enrichment.
  final VoidCallback? onEnrichmentTap;

  /// Tap callback for the "Réessayer" button in error state.
  final VoidCallback? onRetry;

  /// When true, replaces the bar area with an error state.
  final bool hasError;

  const ConfidenceScoreCard({
    super.key,
    required this.score,
    this.confidence,
    this.enrichmentPrompts = const [],
    this.onEnrichmentTap,
    this.onRetry,
    this.hasError = false,
  });

  EnhancedConfidence get _resolvedConfidence =>
      confidence ?? EnhancedConfidence.fromBareScore(score);

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    // Zone label — from i18n
    final String zoneLabel;
    if (score >= 70) {
      zoneLabel = l.confidenceZoneGood;
    } else if (score >= 40) {
      zoneLabel = l.confidenceZonePartial;
    } else {
      zoneLabel = l.confidenceZoneLow;
    }

    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Score row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: title + bar (or error)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.confidenceScoreCardTitle,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    if (hasError) ...[
                      Text(
                        l.confidenceLoadError,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.scoreCritique,
                        ),
                      ),
                    ] else
                      // MintTrameConfiance (Plan 08a-02 Batch C) — replaces
                      // the hand-rolled ConfidenceBar. Home feed context →
                      // onlyIfTopOfList (MTC-03 anti bloom-storm). Detail
                      // variant carries hypotheses when available.
                      MintTrameConfiance.detail(
                        confidence: _resolvedConfidence,
                        bloomStrategy: BloomStrategy.onlyIfTopOfList,
                        hypotheses: const [],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              // Right: percentage + zone label (hidden in error state)
              if (!hasError)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score.round()}\u00a0%',
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      zoneLabel,
                      style: MintTextStyles.micro(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── Error retry button ──
          if (hasError && onRetry != null) ...[
            const SizedBox(height: MintSpacing.xs),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: MintColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l.confidenceLoadErrorRetry,
                style: MintTextStyles.bodySmall(color: MintColors.primary),
              ),
            ),
          ],

          // ── Enrichment CTA or perfect state ──
          if (!hasError) ...[
            const SizedBox(height: MintSpacing.sm),
            if (score >= 95 || enrichmentPrompts.isEmpty)
              Text(
                l.confidenceZonePerfect,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ),
              )
            else
              GestureDetector(
                onTap: onEnrichmentTap,
                child: Text(
                  '${l.confidenceEnrichmentPrefix} ${enrichmentPrompts.first.label}',
                  style: MintTextStyles.bodySmall(
                    color: MintColors.primary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
