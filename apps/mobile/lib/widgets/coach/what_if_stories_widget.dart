import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  WHAT-IF STORIES WIDGET — P1-E / S42 UX Redesign
// ────────────────────────────────────────────────────────────
//
//  Remplace le tornado chart par 3 micro-histoires cliquables.
//  Chaque histoire montre l'impact d'un changement concret.
//
//  Widget pur — aucune dependance Provider.
//  Lois : L4 (raconte, ne montre pas) + L5 (une action)
// ────────────────────────────────────────────────────────────

/// Single "what if" story card data.
class WhatIfStory {
  /// Emoji icon for the story.
  final String emoji;

  /// Story question (e.g., "Et si ta caisse LPP passait de 1% a 2% ?")
  final String question;

  /// Monthly impact in CHF (positive = gain).
  final double monthlyImpactChf;

  /// Short explanation of the impact.
  final String explanation;

  /// Actionable next step.
  final String? actionLabel;

  /// Target route when tapped.
  final String? route;

  const WhatIfStory({
    required this.emoji,
    required this.question,
    required this.monthlyImpactChf,
    required this.explanation,
    this.actionLabel,
    this.route,
  });
}

class WhatIfStoriesWidget extends StatelessWidget {
  /// The stories to display (max 3 recommended).
  final List<WhatIfStory> stories;

  /// Callback when user taps a story.
  final ValueChanged<int>? onStoryTapped;

  const WhatIfStoriesWidget({
    super.key,
    required this.stories,
    this.onStoryTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: 'Histoires "et si" \u2014 ${stories.length} sc\u00e9narios.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ce qui pourrait tout changer',
              style: MintTextStyles.bodyLarge(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            ...stories
                .take(3)
                .toList()
                .asMap()
                .entries
                .map((e) => _buildStoryCard(context, e.key, e.value)),
            const SizedBox(height: 8),
            Text(
              'Estimations \u00e9ducatives \u2014 ne constitue pas un conseil financier (LSFin).',
              style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.normal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCard(BuildContext context, int index, WhatIfStory story) {
    final isPositive = story.monthlyImpactChf >= 0;
    final impactColor =
        isPositive ? MintColors.scoreExcellent : MintColors.scoreCritique;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onStoryTapped != null
            ? () => onStoryTapped!(index)
            : story.route != null
                ? () => context.push(story.route!)
                : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(story.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      story.question,
                      style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600, height: 1.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Impact
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPositive
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 16,
                          color: impactColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${isPositive ? "+" : ""}${formatChfWithPrefix(story.monthlyImpactChf)}/mois \u00e0 65 ans',
                          style: MintTextStyles.bodySmall(color: impactColor).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      story.explanation,
                      style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.3),
                    ),
                    if (story.actionLabel != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.arrow_forward,
                              size: 12, color: MintColors.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              story.actionLabel!,
                              style: MintTextStyles.labelMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
