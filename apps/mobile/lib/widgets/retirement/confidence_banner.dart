import 'package:flutter/material.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

/// Confidence banner for retirement projections.
///
/// **Plan 08a-02 Batch C migration**: the hand-rolled gauge + level color
/// + progress bar + prompt chip list has been replaced by
/// [MintTrameConfiance.inline] / [BloomStrategy.firstAppearance]. This file
/// has zero production callers at migration time (grep verified), so the
/// API was swapped cleanly to take an optional [EnhancedConfidence] and
/// the class is marked `@Deprecated` — new code should instantiate
/// [MintTrameConfiance.inline] directly.
@Deprecated(
  'Use MintTrameConfiance.inline directly. '
  'This wrapper will be removed in Phase 11.',
)
class ConfidenceBanner extends StatelessWidget {
  /// 4-axis confidence. Null = no MTC rendered (the banner becomes a
  /// zero-height placeholder so call sites can keep an unconditional
  /// reference without a legacy fallback).
  final EnhancedConfidence? confidence;

  const ConfidenceBanner({super.key, this.confidence});

  @override
  Widget build(BuildContext context) {
    final c = confidence;
    if (c == null) return const SizedBox.shrink();
    return MintTrameConfiance.inline(
      confidence: c,
      bloomStrategy: BloomStrategy.firstAppearance,
    );
  }
}
