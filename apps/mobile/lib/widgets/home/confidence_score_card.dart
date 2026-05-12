import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart'
    show CoachProfile, FinancialArchetypeBackendName;
import 'package:mint_mobile/models/serialized_card_context.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/mint_card_action_bar.dart';
import 'package:mint_mobile/widgets/mint_chat_overlay.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

/// Stable card identifier for Maestro reachability + SerializedCardContext.
/// Locked per PHASE97_AUJOURDHUI_CARD_INVENTORY.md row 3 (Phase 97.5 W3-T1
/// P002 perimeter). Mirrors the cap_du_jour_banner.dart W7 pattern.
const String _kCardId = 'confidence_score';

/// Card surfacing the user's projection precision score with the single
/// best enrichment action.
///
/// Placement: Aujourd'hui tab, below [FinancialPlanCard], above check-in section.
///
/// Requirements: UXP-02 (Phase 08-01).
/// Phase 97.5 W3-T1 P002 — wrapped with Semantics(identifier:) +
/// Key('card_confidence_score') + appended MintCardActionBar (3 verbs).
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

  /// Phase 97.5 W3-T1 — optional « Simule » tap handler. When null, the
  /// action bar falls back to a no-op (Explorer simulate deep-link is the
  /// canonical W3-T1 behaviour ; the parent screen owns navigation in
  /// production but tests can substitute their own router).
  final VoidCallback? onSimulate;

  const ConfidenceScoreCard({
    super.key,
    required this.score,
    this.confidence,
    this.enrichmentPrompts = const [],
    this.onEnrichmentTap,
    this.onRetry,
    this.hasError = false,
    this.onSimulate,
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

    // Phase 97.5 W3-T1 P002 — wrap the surface in
    // Semantics(identifier: 'card_confidence_score') + Key for Maestro
    // reachability. Mirrors cap_du_jour_banner.dart W7.
    return Semantics(
      identifier: 'card_$_kCardId',
      container: true,
      child: Container(
        key: const Key('card_$_kCardId'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MintSurface(
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
                              // MintTrameConfiance (Plan 08a-02 Batch C) —
                              // replaces the hand-rolled ConfidenceBar.
                              // Home feed context → onlyIfTopOfList
                              // (MTC-03 anti bloom-storm). Detail variant
                              // carries hypotheses when available.
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
                              '${score.round()} %',
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
                        style: MintTextStyles.bodySmall(
                          color: MintColors.primary,
                        ),
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
            ),
            // Phase 97.5 W3-T1 P002 — MintCardActionBar wired with the
            // 3 verbs from PHASE97_AUJOURDHUI_CARD_INVENTORY row 3.
            // The chip text is the generic ARB verbs (Explique-moi /
            // Simule / Rassure-moi) ; the card-specific phrasing
            // (« Explique-moi ce score de confiance », « Rassure-moi
            // sur les axes encore manquants ») lives in the
            // SerializedCardContext.cardType + intent dispatch, not
            // the chip label, per the cap_du_jour pattern.
            MintCardActionBar(
              // Key allows Maestro `assertVisible: { id }` to resolve
              // the action-bar surface (mirrors cap_du_jour_banner).
              key: const Key('mint_card_action_bar'),
              sourceCard: _buildCardContext(context),
              expanded: true,
              onExplain: () => MintChatOverlay.show(
                context,
                sourceCard: _buildCardContext(context),
                intent: 'explain',
              ),
              onSimulate: onSimulate ?? () {},
              onReassure: () => MintChatOverlay.show(
                context,
                sourceCard: _buildCardContext(context),
                intent: 'reassure',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Phase 97.5 W3-T1 — build the SerializedCardContext from
  /// financial_core values only (combined confidence score + 4-axis
  /// breakdown when available). NO PII per CLAUDE.md NEVER #8 +
  /// Phase 96 D-12 (frozen+forbid backend mirror).
  ///
  /// Karpathy #3 surgical : the CoachProfileProvider lookup is
  /// guarded so legacy callers (existing widget tests for the
  /// non-action-bar surface) keep working without provider scaffolding.
  /// In production the provider is always in scope (AppScaffold).
  SerializedCardContext _buildCardContext(BuildContext context) {
    CoachProfile? profile;
    try {
      profile = Provider.of<CoachProfileProvider>(
        context,
        listen: false,
      ).profile;
    } catch (_) {
      // Provider absent in the widget tree (legacy test harness).
      profile = null;
    }
    final c = _resolvedConfidence;
    final Map<String, dynamic> facts = <String, dynamic>{
      'combined': c.combined,
      'completeness': c.completeness,
      'accuracy': c.accuracy,
      'freshness': c.freshness,
      'understanding': c.understanding,
    };
    return SerializedCardContext(
      cardId: _kCardId,
      cardType: 'confidence_axis',
      computedFacts: facts,
      groundingKeys: const <String>[],
      lifeEvent: 'general',
      canton: profile?.canton,
      archetype: profile?.archetype.backendName,
    );
  }
}
