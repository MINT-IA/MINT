/// FRI Action Suggestion — Sprint S39.
///
/// Shows the most impactful action to improve the user's FRI score.
/// Educational tone, no prescriptive language. Never uses banned terms.
///
/// Display:
///   - Lightbulb icon
///   - Action text (French, informal "tu")
///   - "+X pts" badge showing estimated improvement
///   - Optional tap handler for navigation
///
/// References:
///   - ONBOARDING_ARBITRAGE_ENGINE.md § V
///   - LSFin compliance (education only, not advice)
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Card showing the top FRI improvement action with estimated delta.
///
/// Always uses educational tone. Never prescriptive.
/// Example: "Verser dans ton 3a pourrait renforcer ta solidite" (+4 pts).
class FriActionSuggestion extends StatelessWidget {
  /// French text describing the suggested action.
  final String actionText;

  /// Estimated FRI point improvement if the action is taken.
  final double estimatedDelta;

  /// Callback when the user taps the suggestion card.
  final VoidCallback? onTap;

  const FriActionSuggestion({
    super.key,
    required this.actionText,
    required this.estimatedDelta,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$actionText, plus ${estimatedDelta.toStringAsFixed(0)} points',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.info.withAlpha(10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MintColors.info.withAlpha(30)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lightbulb icon
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: MintColors.info.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: MintColors.info,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),

              // Action text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Piste de progression',
                      style: MintTextStyles.bodySmall(color: MintColors.info).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      actionText,
                      style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Delta badge
              _DeltaBadge(delta: estimatedDelta),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small badge showing the estimated FRI improvement.
class _DeltaBadge extends StatelessWidget {
  final double delta;
  const _DeltaBadge({required this.delta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: MintColors.success.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '+${delta.toStringAsFixed(0)} pts',
        style: MintTextStyles.bodySmall(color: MintColors.success).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
