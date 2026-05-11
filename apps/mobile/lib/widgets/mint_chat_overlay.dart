// Phase 96 D-04 + D-06 — modal scaffold opened by MintCardActionBar verbs
// « Explique-moi » and « Rassure-moi ». DraggableScrollableSheet pattern
// per DESIGN_SYSTEM.md §4.6 (bottom-sheet handle 40×4dp, radius top 20dp).
//
// W1 scope: SCAFFOLD ONLY. Backend wiring (sending requests, rendering
// chat turns, turn-counter UI, terminal-template render) lands in
// Plan 96-03 after the W2 backend schemas + turn-cap endpoint exist.
// Karpathy #2 simplicity-first — do not add ChatMessage, ChatInputBar,
// or any other widget here.

import 'package:flutter/material.dart';
import 'package:mint_mobile/models/narrative_sleeve.dart';
import 'package:mint_mobile/models/serialized_card_context.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class MintChatOverlay extends StatelessWidget {
  /// Card snapshot. Plan 96-02 ships this to the coach_chat endpoint
  /// as CoachChatRequest.source_card.
  final SerializedCardContext sourceCard;

  /// 'explain' or 'reassure' (D-06). « Simule » never opens this overlay
  /// — it deep-links to Explorer directly.
  final String intent;

  const MintChatOverlay({
    super.key,
    required this.sourceCard,
    required this.intent,
  });

  /// Convenience helper used by MintCardActionBar.onExplain / onReassure.
  /// Centralises showModalBottomSheet config so callers stay terse.
  static Future<void> show(
    BuildContext context, {
    required SerializedCardContext sourceCard,
    required String intent,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MintColors.card,
      // 96-UI-SPEC §Color §Scrim — nearBlack at 60% opacity. Use the
      // existing MintColors.nearBlack token (D-26 compliant).
      barrierColor: MintColors.nearBlack.withValues(alpha: 0.6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MintChatOverlay(
        sourceCard: sourceCard,
        intent: intent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return FocusScope(
          child: Column(
            children: [
              // Drag handle 40×4dp — DESIGN_SYSTEM.md §4.6 + UI-SPEC.
              Padding(
                padding: const EdgeInsets.only(
                  top: 12,
                  bottom: MintSpacing.sm,
                ),
                child: Semantics(
                  button: true,
                  label: 'Fermer le coach',
                  child: Container(
                    key: const Key('chat_overlay_drag_handle'),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MintColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Intent label slot — keyed for test access. Plan 96-03
              // replaces this with the full overlay header (cardTitle +
              // turn counter) per UI-SPEC §Component Anatomy Summary.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.lg,
                  vertical: MintSpacing.md,
                ),
                child: Text(
                  intent,
                  key: const Key('chat_overlay_intent_label'),
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMuted,
                  ),
                ),
              ),
              // Body — scaffold placeholder. Plan 96-03 wires turn
              // history + ChatInputBar.
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MintSpacing.lg,
                  ),
                  children: const [],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Phase 96 D-14 + UI-SPEC §NarrativeSleeve renderer.
///
/// 4-field card rendered inside the chat message list when the backend
/// response carries a NarrativeSleeve envelope :
///
///   - `hook` — `MintTextStyles.headlineSmall()` on textPrimary.
///   - `caption` — `MintTextStyles.bodyLarge()` on textSecondary.
///   - `next_step` — `labelLarge(MintColors.mintForest)` with a leading
///     « › » glyph, wrapped in `Semantics(hint: 'Prochaine étape')`.
///   - `metaphor` — conditional render below a Divider, in
///     `bodySmall(MintColors.textMuted)`. Hidden when empty.
///
/// Surface : `craieHandoff` (#F8F5F0 — coach conversation surface per
/// DESIGN_SYSTEM.md). D-26 guard : zero hardcoded ARGB literals ; all
/// colors are MintColors tokens.
class NarrativeSleeveCard extends StatelessWidget {
  final NarrativeSleeve sleeve;
  const NarrativeSleeveCard({super.key, required this.sleeve});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('narrative_sleeve_card'),
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.craieHandoff,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sleeve.hook,
            key: const Key('narrative_sleeve_hook'),
            style: MintTextStyles.headlineSmall(),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            sleeve.caption,
            key: const Key('narrative_sleeve_caption'),
            style: MintTextStyles.bodyLarge(),
          ),
          const SizedBox(height: MintSpacing.md),
          Semantics(
            hint: 'Prochaine étape',
            child: Row(
              key: const Key('narrative_sleeve_next_step'),
              children: [
                Text(
                  '›',
                  style: MintTextStyles.labelLarge(
                    color: MintColors.mintForest,
                  ),
                ),
                const SizedBox(width: MintSpacing.xs),
                Expanded(
                  child: Text(
                    sleeve.nextStep,
                    style: MintTextStyles.labelLarge(
                      color: MintColors.mintForest,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (sleeve.metaphor.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.sm),
            const Divider(color: MintColors.border),
            const SizedBox(height: MintSpacing.sm),
            Text(
              sleeve.metaphor,
              key: const Key('narrative_sleeve_metaphor'),
              style: MintTextStyles.bodySmall(
                color: MintColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
