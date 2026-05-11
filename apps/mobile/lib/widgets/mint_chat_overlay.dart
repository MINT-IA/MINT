// Phase 96 D-04 + D-06 — modal opened by MintCardActionBar verbs
// « Explique-moi » and « Rassure-moi ». DraggableScrollableSheet pattern
// per DESIGN_SYSTEM.md §4.6 (bottom-sheet handle 40×4dp, radius top 20dp).
//
// W7 (Phase 97 fix iter 1, 2026-05-11) — ChatInputBar + local-state turn
// counter + simulated narrator response. Closes bug F001 (Maestro
// testIDs `chat_input_field`, `chat_send_button`, `chat_turn_counter`
// + root `mint_chat_overlay` Key) by promoting the widget from
// StatelessWidget to StatefulWidget. Local state holds the
// chatMessages list, the turn counter, and the TextEditingController.
//
// Backend wiring (real coach_chat POST, NarrativeSleeve render,
// server-side turn_cap enforcement per Phase 96 D-08) is OUT OF SCOPE
// for F001 — deferred to a follow-up bug (F-NEXT). The local counter
// here is UI-only for testID stability ; the canonical enforcement
// gate lives server-side in `services/backend/app/services/coach/
// turn_cap.py` (Phase 96 W2).
//
// Karpathy #2 (simplicity-first) : ZERO new dependencies, ZERO new
// providers. Local Stateful state only. Existing MintColors +
// MintTextStyles + MintSpacing tokens only. ZERO hardcoded ARGB
// literals or fontSize literals (D-26 grep gate enforced).
//
// Karpathy #3 (surgical) : ONLY mint_chat_overlay.dart + the 6
// chatInputHint ARB rows touched ; NarrativeSleeveCard kept identical ;
// no provider/route/feature-flag changes ; coach_chat_screen.dart and
// the wiring screens (chat_as_verb_demo_screen.dart) untouched.

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/narrative_sleeve.dart';
import 'package:mint_mobile/models/serialized_card_context.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Maximum turns per (user_id, source_card_id) per Phase 96 D-08.
/// This is the UI-display ceiling ; the canonical enforcement lives
/// server-side. Locked to 3 to match
/// services/backend/app/services/coach/turn_cap.py:MAX_TURNS_PER_CARD.
const int kChatMaxTurns = 3;

class MintChatOverlay extends StatefulWidget {
  /// Card snapshot. Plan 96-02 ships this to the coach_chat endpoint
  /// as CoachChatRequest.source_card. F-NEXT will wire the POST.
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
  State<MintChatOverlay> createState() => _MintChatOverlayState();
}

class _MintChatOverlayState extends State<MintChatOverlay> {
  /// Locally-held chat messages. Each entry is a single user OR
  /// simulated-narrator turn. Backend wiring (F-NEXT) replaces this
  /// with a streamed CoachChatResponse history.
  final List<_ChatTurn> _chatMessages = <_ChatTurn>[];

  /// Local turn counter (0..kChatMaxTurns). Increments on each
  /// successful send. Server-side turn_cap is the canonical gate
  /// (Phase 96 D-08) ; this is UI-only.
  int _turnCount = 0;

  /// TextField controller. Source of truth for the send button's
  /// enabled state (button disabled when text is empty).
  late final TextEditingController _inputController;

  /// True when the TextField currently has non-empty text. Drives the
  /// send button enabled/disabled visual.
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _inputController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (hasText != _hasInput) {
      setState(() => _hasInput = hasText);
    }
  }

  void _onSendPressed() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (_turnCount >= kChatMaxTurns) return;
    setState(() {
      _chatMessages.add(_ChatTurn(text: text, fromUser: true));
      // Simulated narrator response — backend wiring deferred to F-NEXT.
      // Generic phrasing (no archetype assumption, no LSFin banned terms
      // per CLAUDE.md rule 1 — no « garanti / optimal / parfait »).
      _chatMessages.add(const _ChatTurn(
        text: 'Réponse coach (simulée — backend wiring en attente backlog 999.X).',
        fromUser: false,
      ));
      _turnCount += 1;
      _inputController.clear();
      _hasInput = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return FocusScope(
          child: Container(
            // F001 — root Key for Maestro `assertVisible: { id: mint_chat_overlay }`.
            key: const Key('mint_chat_overlay'),
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
                // Header — intent label + turn counter. Two slots in a Row
                // per UI-SPEC §Component Anatomy Summary.
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MintSpacing.lg,
                    vertical: MintSpacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.intent,
                        key: const Key('chat_overlay_intent_label'),
                        style: MintTextStyles.labelSmall(
                          color: MintColors.textMuted,
                        ),
                      ),
                      Text(
                        '$_turnCount / $kChatMaxTurns',
                        key: const Key('chat_turn_counter'),
                        style: MintTextStyles.labelSmall(
                          color: MintColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Body — chat message list.
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.lg,
                    ),
                    itemCount: _chatMessages.length,
                    itemBuilder: (_, i) => _ChatBubble(turn: _chatMessages[i]),
                  ),
                ),
                // ChatInputBar — TextField + send button. F001 testIDs live here.
                _ChatInputBar(
                  controller: _inputController,
                  hint: l.chatInputHint,
                  enabled: _turnCount < kChatMaxTurns,
                  sendEnabled: _hasInput && _turnCount < kChatMaxTurns,
                  onSend: _onSendPressed,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A single chat turn (user OR simulated narrator). Local-only ;
/// F-NEXT replaces with the backend CoachChatResponse envelope.
class _ChatTurn {
  final String text;
  final bool fromUser;
  const _ChatTurn({required this.text, required this.fromUser});
}

/// Renders a single message bubble. Minimal styling per Karpathy #2
/// — backend wiring (F-NEXT) brings NarrativeSleeveCard rendering for
/// narrator turns ; for now both sides use a simple bodyMedium Text.
class _ChatBubble extends StatelessWidget {
  final _ChatTurn turn;
  const _ChatBubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Align(
        alignment:
            turn.fromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md,
            vertical: MintSpacing.sm,
          ),
          decoration: BoxDecoration(
            color:
                turn.fromUser ? MintColors.mentheVive12 : MintColors.craieHandoff,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            turn.text,
            style: MintTextStyles.bodyMedium(
              color: MintColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// F001 — ChatInputBar : TextField + send IconButton.
///
/// Send button is DISABLED when (a) TextField is empty OR (b) turn
/// counter has reached `kChatMaxTurns`. Disabled visual = MintColors.
/// textMuted ; enabled = MintColors.mintForest.
class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final bool sendEnabled;
  final VoidCallback onSend;

  const _ChatInputBar({
    required this.controller,
    required this.hint,
    required this.enabled,
    required this.sendEnabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MintSpacing.lg,
        MintSpacing.sm,
        MintSpacing.lg,
        MintSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('chat_input_field'),
              controller: controller,
              enabled: enabled,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (sendEnabled) onSend();
              },
              style: MintTextStyles.bodyMedium(
                color: MintColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: MintTextStyles.bodyMedium(
                  color: MintColors.textMuted,
                ),
                filled: true,
                fillColor: MintColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MintColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MintColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MintColors.mintForest),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.md,
                  vertical: MintSpacing.sm,
                ),
              ),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Semantics(
            button: true,
            label: 'Envoyer le message',
            child: IconButton(
              key: const Key('chat_send_button'),
              icon: const Icon(Icons.send),
              color: sendEnabled
                  ? MintColors.mintForest
                  : MintColors.textMuted,
              onPressed: sendEnabled ? onSend : null,
            ),
          ),
        ],
      ),
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
