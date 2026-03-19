import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/screens/pulse/pulse_screen.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

// ────────────────────────────────────────────────────────────
//  CAP CARD — "Cap du jour" widget for Aujourd'hui
// ────────────────────────────────────────────────────────────
//
//  Displays CapEngine output as a single, calm, actionable card.
//  Contract (MINT_UX_GRAAL_MASTERPLAN.md §10):
//  - headline: 4-9 words
//  - why_now: 1 sentence
//  - cta: 3-5 words
//  - expected_impact: 2-8 words
//  - lisible en 3 secondes
//
//  Narrative → action → proof accessible.
//  No badge. No border left. No mini-dashboard feel.
// ────────────────────────────────────────────────────────────

class CapCard extends StatelessWidget {
  final CapDecision cap;

  /// Optional: recent action feedback (e.g. "Ajouté hier").
  final String? recentActionLabel;

  const CapCard({
    super.key,
    required this.cap,
    this.recentActionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${cap.headline} — ${cap.whyNow}',
      button: true,
      child: GestureDetector(
        onTap: () => _handleCta(context),
        child: Container(
          padding: const EdgeInsets.all(MintSpacing.lg),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: MintColors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Recent action feedback
              if (recentActionLabel != null) ...[
                _buildFeedbackPill(),
                const SizedBox(height: MintSpacing.sm + 4),
              ],

              // Kind pill
              _buildKindPill(),
              const SizedBox(height: MintSpacing.sm + 4),

              // Headline
              Text(
                cap.headline,
                style: MintTextStyles.headlineMedium(),
                maxLines: 2,
              ),
              const SizedBox(height: MintSpacing.sm),

              // Why now
              Text(
                cap.whyNow,
                style: MintTextStyles.bodyMedium(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // Expected impact
              if (cap.expectedImpact != null) ...[
                const SizedBox(height: MintSpacing.sm + 4),
                Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 16,
                      color: MintColors.success.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cap.expectedImpact!,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.success,
                        ).copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: MintSpacing.md + 4),

              // CTA button
              _buildCta(context),

              // Confidence label
              if (cap.confidenceLabel != null) ...[
                const SizedBox(height: MintSpacing.sm + 4),
                Text(
                  cap.confidenceLabel!,
                  style: MintTextStyles.micro(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKindPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kindColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _kindLabel,
        style: MintTextStyles.labelSmall(color: _kindColor),
      ),
    );
  }

  Widget _buildFeedbackPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: MintColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: MintColors.success.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            recentActionLabel!,
            style: MintTextStyles.labelSmall(color: MintColors.success),
          ),
        ],
      ),
    );
  }

  Widget _buildCta(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Semantics(
        button: true,
        label: cap.ctaLabel,
        child: GestureDetector(
          onTap: () => _handleCta(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  cap.ctaLabel,
                  style: MintTextStyles.titleMedium(color: MintColors.white)
                      .copyWith(fontSize: 15),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: MintColors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCta(BuildContext context) {
    switch (cap.ctaMode) {
      case CtaMode.route:
        if (cap.ctaRoute != null) {
          context.push(cap.ctaRoute!);
        }
      case CtaMode.coach:
        // Switch to coach tab (index 1) — prompt injection handled by caller
        NavigationShellState.switchTab(1);
      case CtaMode.capture:
        // Open enrichment flow — for now, go to profile
        context.push('/onboarding/enrichment');
    }
  }

  // ── COMPUTED ──────────────────────────────────────────────

  String get _kindLabel => switch (cap.kind) {
        CapKind.complete => 'Compléter',
        CapKind.correct => 'Corriger',
        CapKind.optimize => 'Optimiser',
        CapKind.secure => 'Sécuriser',
        CapKind.prepare => 'Préparer',
      };

  Color get _kindColor => switch (cap.kind) {
        CapKind.complete => MintColors.info,
        CapKind.correct => MintColors.warning,
        CapKind.optimize => MintColors.success,
        CapKind.secure => MintColors.error,
        CapKind.prepare => MintColors.primary,
      };
}
