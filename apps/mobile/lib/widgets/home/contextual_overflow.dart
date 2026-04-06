import 'package:flutter/material.dart';

import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_motion.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/home/action_opportunity_card.dart';
import 'package:mint_mobile/widgets/home/hero_stat_card.dart';
import 'package:mint_mobile/widgets/home/progress_milestone_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  CONTEXTUAL OVERFLOW — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Expandable section for cards beyond the visible 4 slots.
//
// Visual contract: UI-SPEC Card 5
//   MintSurface(craie) > AnimatedCrossFade[collapsed header / expanded cards]
//
// Design: StatefulWidget for expand state.
// Respects MediaQuery.disableAnimations for reduced motion.
// ────────────────────────────────────────────────────────────

/// Expandable overflow section for additional contextual cards.
///
/// Shows a "Voir plus" header that expands to reveal hidden cards.
class ContextualOverflow extends StatefulWidget {
  /// The overflow card containing hidden cards.
  final ContextualOverflowCard card;

  const ContextualOverflow({
    required this.card,
    super.key,
  });

  @override
  State<ContextualOverflow> createState() => _ContextualOverflowState();
}

class _ContextualOverflowState extends State<ContextualOverflow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final count = widget.card.cards.length;

    return MintSurface(
      tone: MintSurfaceTone.craie,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row (always visible) ──
          Semantics(
            label: _expanded
                ? 'Section depliee, $count elements'
                : 'Section repliee, $count elements supplementaires',
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Text(
                      _expanded ? 'Voir moins' : 'Voir plus',
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$count element${count > 1 ? 's' : ''} supplementaire${count > 1 ? 's' : ''}',
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: MintSpacing.xs),
                    Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 20,
                      color: MintColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Expanded content ──
          if (reducedMotion)
            // Skip animation when reduced motion is enabled
            if (_expanded) _buildCardList()
            else const SizedBox.shrink()
          else
            AnimatedCrossFade(
              duration: MintMotion.standard,
              firstCurve: Curves.easeInOut,
              secondCurve: Curves.easeInOut,
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _buildCardList(),
            ),
        ],
      ),
    );
  }

  /// Build the list of overflow cards.
  Widget _buildCardList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: MintSpacing.md),
        ...widget.card.cards.map(_buildCard),
      ],
    );
  }

  /// Dispatch a ContextualCard to its correct widget.
  Widget _buildCard(ContextualCard card) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.md),
      child: switch (card) {
        ContextualHeroCard c => HeroStatCard(card: c),
        ContextualAnticipationCard _ =>
          // Anticipation cards are handled by their own widget
          // (AnticipationSignalCard) which requires dismiss/snooze callbacks.
          // In overflow, we show a simplified version.
          const SizedBox.shrink(),
        ContextualProgressCard c => ProgressMilestoneCard(card: c),
        ContextualActionCard c => ActionOpportunityCard(card: c),
        ContextualOverflowCard _ =>
          // Nested overflow not supported
          const SizedBox.shrink(),
      },
    );
  }
}
