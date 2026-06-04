// Phase 96 Wave 1 — chat-as-verb demo screen.
//
// Wires MintCardActionBar to 2 example NON-retirement cards (CLAUDE.md
// rule 3 — MINT is not a retirement app, frame by life events). This
// screen is the W1 wiring contract demonstration: each card maintains
// a `_actionBarExpanded` bool toggled by the card's tap gesture,
// MintCardActionBar reveals 3 verbs, « Simule » deep-links to
// /explore?simulate=<card_id> (zero LLM), « Explique-moi » +
// « Rassure-moi » open MintChatOverlay with the card's
// SerializedCardContext.
//
// W1 scope: scaffold-only. Full card-screen-wide wiring of
// MintCardActionBar (beyond these 2 examples) lands in a post-v2.9
// content sprint per 96-01-PLAN.md `deferred:` block.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/serialized_card_context.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/mint_card_action_bar.dart';
import 'package:mint_mobile/widgets/mint_chat_overlay.dart';

class ChatAsVerbDemoScreen extends StatelessWidget {
  const ChatAsVerbDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.craie,
      appBar: AppBar(
        backgroundColor: MintColors.craie,
        elevation: 0,
        title: Text(
          'Cartes — chat-as-verb (W1)',
          style: MintTextStyles.titleMedium(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.lg,
          vertical: MintSpacing.md,
        ),
        children: const [
          _DemoCardWithActions(
            cardId: 'tax_marge_2026',
            cardType: 'tax_optimization',
            lifeEvent: 'tax',
            title: 'Marge fiscale 2026',
            subtitle: 'Ce qu\'il te reste à déduire cette année.',
          ),
          SizedBox(height: MintSpacing.md),
          _DemoCardWithActions(
            cardId: 'mortgage_monthly_cost',
            cardType: 'mortgage',
            lifeEvent: 'housing',
            title: 'Coût hypothèque mensuel',
            subtitle: 'Charge actuelle et bande de sensibilité au taux.',
          ),
        ],
      ),
    );
  }
}

/// A small card that demonstrates the W1 wiring pattern:
/// 1. Tap the card body → toggles `_actionBarExpanded` (StatefulWidget state).
/// 2. MintCardActionBar reveals the 3 verb chips.
/// 3. Verb taps dispatch to MintChatOverlay (explain/reassure) or
///    GoRouter (simulate) — D-06 routing contract.
class _DemoCardWithActions extends StatefulWidget {
  final String cardId;
  final String cardType;
  final String lifeEvent;
  final String title;
  final String subtitle;

  const _DemoCardWithActions({
    required this.cardId,
    required this.cardType,
    required this.lifeEvent,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_DemoCardWithActions> createState() => _DemoCardWithActionsState();
}

class _DemoCardWithActionsState extends State<_DemoCardWithActions> {
  bool _actionBarExpanded = false;

  SerializedCardContext _buildSourceCard() {
    return SerializedCardContext(
      cardId: widget.cardId,
      cardType: widget.cardType,
      lifeEvent: widget.lifeEvent,
      // computedFacts + groundingKeys stay empty in W1 — Plan 96-02
      // wires them from financial_core + CITATION_REGISTRY.
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () =>
                setState(() => _actionBarExpanded = !_actionBarExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(MintSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: MintTextStyles.titleMedium(),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    widget.subtitle,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          MintCardActionBar(
            sourceCard: _buildSourceCard(),
            expanded: _actionBarExpanded,
            onExplain: () => MintChatOverlay.show(
              context,
              sourceCard: _buildSourceCard(),
              intent: 'explain',
            ),
            onSimulate: () => context.push(
              '/explore?simulate=${widget.cardId}',
            ),
            onReassure: () => MintChatOverlay.show(
              context,
              sourceCard: _buildSourceCard(),
              intent: 'reassure',
            ),
          ),
        ],
      ),
    );
  }
}
