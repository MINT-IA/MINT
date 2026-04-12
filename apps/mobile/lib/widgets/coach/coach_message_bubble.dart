import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/coach/response_card_widget.dart';
import 'package:mint_mobile/widgets/coach/widget_renderer.dart';

// ────────────────────────────────────────────────────────────
//  COACH MESSAGE BUBBLE — extracted from coach_chat_screen.dart
// ────────────────────────────────────────────────────────────

/// Renders a single coach (assistant) message bubble with all accessories:
/// tier badge, widget call, sources, disclaimers, response cards,
/// rich widget, and suggested actions.
class CoachMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final int messageIndex;
  final bool isStreaming;
  final bool isInputAnswered;
  final void Function(int messageIndex, String field, String value)?
      onInputSubmitted;
  final void Function(String action)? onActionTap;

  const CoachMessageBubble({
    super.key,
    required this.message,
    required this.messageIndex,
    this.isStreaming = false,
    this.isInputAnswered = false,
    this.onInputSubmitted,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final msg = message;
    final isStreamingThis = isStreaming;
    final hasToolCalls = msg.hasRichToolCalls;
    final isAskUserInput = hasToolCalls &&
        msg.richToolCalls.any((tc) => tc.name == 'ask_user_input');

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // P-S3-01 (Phase 8c hot-fix): CoachAvatar removed from the
              // coach reading zone — a 24px gradient dot with an 'M' letter
              // is decorative ornament, not content. The bubble's asymmetric
              // top-left radius (6) is sufficient "coach voice" semantic.
              // The 44px left indent of downstream sections is preserved
              // by the same SizedBox width (24 + md-4 = 44).
              const SizedBox(width: 44),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MintSpacing.md,
                    vertical: MintSpacing.md,
                  ),
                  decoration: const BoxDecoration(
                    color: MintColors.porcelaine,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(22),
                      bottomLeft: Radius.circular(22),
                      bottomRight: Radius.circular(22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ACCESS-08 (P8b-03): liveRegion announces new coach
                      // output to screen readers without shifting focus.
                      // Only the Text is wrapped — focus stays where it is,
                      // only content is announced.
                      Semantics(
                        liveRegion: true,
                        container: true,
                        child: Text(
                          msg.content.isEmpty && isStreamingThis
                              ? '...'
                              : msg.content,
                          style: MintTextStyles.bodyMedium(
                                  color: MintColors.textPrimary)
                              .copyWith(height: 1.6),
                        ),
                      ),
                      // Streaming cursor
                      if (isStreamingThis) ...[
                        const SizedBox(height: MintSpacing.xs),
                        const SizedBox(
                          width: 8,
                          height: 14,
                          child: BlinkingCursor(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          // P-S3-02 (Phase 8c hot-fix): CoachTierBadge rendering removed.
          // SLM/BYOK/Fallback labels are developer-metadata leakage to
          // users — 9px micro-text at 50% alpha is decorative noise inside
          // the coach reading zone. The CoachTierBadge class is preserved
          // below for potential debug-surface reuse.
          // Rich widget or input request from Claude tool calling (S56)
          if (!isStreamingThis &&
              hasToolCalls &&
              !(isAskUserInput && isInputAnswered)) ...[
            for (final toolCall in msg.richToolCalls) ...[
              const SizedBox(height: MintSpacing.md - 4),
              Padding(
                padding: const EdgeInsets.only(left: 44, right: MintSpacing.md),
                child: WidgetRenderer.build(
                      context,
                      toolCall,
                      onInputSubmitted: (field, value) {
                        onInputSubmitted?.call(messageIndex, field, value);
                      },
                    ) ??
                    const SizedBox.shrink(),
              ),
            ],
          ],
          // Sources
          if (msg.sources.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.md - 4),
            Padding(
              padding: const EdgeInsets.only(left: 44, right: MintSpacing.xxl),
              child: CoachSourcesSection(sources: msg.sources),
            ),
          ],
          // Disclaimers (from RAG backend)
          if (msg.disclaimers.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 44, right: MintSpacing.xxl),
              child: CoachDisclaimersSection(disclaimers: msg.disclaimers),
            ),
          ],
          // Response Cards (Phase 1 — inline strip)
          if (!isStreamingThis && msg.responseCards.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.md - 4),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: ResponseCardStrip(cards: msg.responseCards),
            ),
          ],
          // Suggested actions
          if (!isStreamingThis &&
              msg.suggestedActions != null &&
              msg.suggestedActions!.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.md),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: CoachSuggestedActions(
                actions: msg.suggestedActions!,
                onActionTap: onActionTap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders a user message bubble.
class UserMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const UserMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 72),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.md,
                vertical: MintSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: MintColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Text(
                message.content,
                style: MintTextStyles.bodyMedium(color: MintColors.white)
                    .copyWith(height: 1.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a system message (centered, italic).
class SystemMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const SystemMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md - 4,
            vertical: MintSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: MintColors.porcelaine.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            // AESTH-05 per AUDIT_RETRAIT S3 (D-03 swap map)
            style: MintTextStyles.micro(color: MintColors.textMutedAaa)
                .copyWith(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Coach avatar — 24px gradient dot with 'M' letter.
class CoachAvatar extends StatelessWidget {
  const CoachAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.saugeClaire,
            MintColors.bleuAir.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'M',
          style: MintTextStyles.micro(
            color: MintColors.ardoise,
          ).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

/// Tier badge — very subtle indicator of response source.
class CoachTierBadge extends StatelessWidget {
  final ChatTier tier;

  const CoachTierBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final String label;
    final IconData icon;
    switch (tier) {
      case ChatTier.slm:
        label = s.coachBadgeSlm;
        icon = Icons.smartphone;
        break;
      case ChatTier.byok:
        label = s.coachBadgeByok;
        icon = Icons.cloud_outlined;
        break;
      case ChatTier.fallback:
        label = s.coachBadgeFallback;
        icon = Icons.wifi_off;
        break;
      default:
        return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            // AESTH-05 per AUDIT_RETRAIT S3 (D-03 swap map)
            size: 9, color: MintColors.textMutedAaa.withValues(alpha: 0.5)),
        const SizedBox(width: MintSpacing.xs),
        Text(
          label,
          style: MintTextStyles.micro(
            // AESTH-05 per AUDIT_RETRAIT S3 (D-03 swap map)
            color: MintColors.textMutedAaa.withValues(alpha: 0.5),
          ).copyWith(fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}

/// Sources section displayed under coach messages.
class CoachSourcesSection extends StatelessWidget {
  final List<RagSource> sources;

  const CoachSourcesSection({
    super.key,
    required this.sources,
  });

  void _navigateToSource(BuildContext context, RagSource source) {
    final file = source.file.toLowerCase();
    if (file.contains('3a') ||
        file.contains('opp3') ||
        file.contains('pilier')) {
      context.push('/pilier-3a');
    } else if (file.contains('lpp') || file.contains('pension')) {
      context.push('/rente-vs-capital');
    } else if (file.contains('lifd') || file.contains('fiscal')) {
      context.push('/fiscal');
    } else if (file.contains('lavs') || file.contains('avs')) {
      context.push('/retraite');
    } else if (file.contains('budget')) {
      context.push('/budget');
    } else {
      context.push('/education/hub');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.md - 4,
        vertical: MintSpacing.md - 4,
      ),
      decoration: BoxDecoration(
        color: MintColors.bleuAir.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.coachSources,
            style: MintTextStyles.micro(
              // AESTH-05 per AUDIT_RETRAIT S3 (D-03 swap map)
              color: MintColors.textMutedAaa,
            ).copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: MintSpacing.xs),
          for (final source in sources)
            Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.xs),
              child: Semantics(
                label: source.title,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _navigateToSource(context, source),
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined,
                          size: 12,
                          // AESTH-05 per AUDIT_RETRAIT S3 R1 (D-03 swap map)
                          color: MintColors.textSecondaryAaa
                              .withValues(alpha: 0.6)),
                      const SizedBox(width: MintSpacing.xs),
                      Expanded(
                        child: Text(
                          '${source.title}${source.section.isNotEmpty ? ' \u2014 ${source.section}' : ''}',
                          style: MintTextStyles.micro(
                            // AESTH-05 per AUDIT_RETRAIT S3 R1 (D-03 swap map)
                            color: MintColors.textSecondaryAaa,
                          ).copyWith(
                            decoration: TextDecoration.underline,
                            decorationColor:
                                MintColors.textSecondaryAaa.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Disclaimers section displayed under coach messages.
class CoachDisclaimersSection extends StatelessWidget {
  final List<String> disclaimers;

  const CoachDisclaimersSection({super.key, required this.disclaimers});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.md - 4,
        vertical: MintSpacing.md - 4,
      ),
      decoration: BoxDecoration(
        color: MintColors.pecheDouce.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              // AESTH-05 per AUDIT_RETRAIT S3 (D-03 swap map)
              size: 13, color: MintColors.textMutedAaa.withValues(alpha: 0.6)),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              disclaimers.join('\n'),
              style: MintTextStyles.micro(
                // AESTH-05 per AUDIT_RETRAIT S3 (D-03 swap map)
                color: MintColors.textMutedAaa,
              ).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Suggested action chips displayed under coach messages.
class CoachSuggestedActions extends StatelessWidget {
  final List<String> actions;
  final void Function(String action)? onActionTap;

  const CoachSuggestedActions({
    super.key,
    required this.actions,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: actions.map((action) {
        // "Il m'arrive quelque chose" gets a different tone
        final isLifeEvent = action.toLowerCase().contains('il m') &&
            action.toLowerCase().contains('arrive');
        return GestureDetector(
          onTap: () => onActionTap?.call(action),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md,
              vertical: MintSpacing.md - 4,
            ),
            decoration: BoxDecoration(
              color: isLifeEvent
                  ? MintColors.pecheDouce.withValues(alpha: 0.18)
                  : MintColors.porcelaine,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLifeEvent
                    ? MintColors.pecheDouce.withValues(alpha: 0.3)
                    : MintColors.border.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              action,
              style: MintTextStyles.bodySmall(
                color: MintColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w500, height: 1.3),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Isolated blinking cursor — manages its own animation lifecycle.
///
/// Avoids triggering parent [setState] for blink cycles, preventing
/// full [ListView] rebuilds during streaming.
class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor({super.key});

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reducedMotion = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    // ACCESS-07 (D-08): reduced-motion fallback per MediaQuery.disableAnimations.
    // The blinking cursor is the streaming/typing indicator. When reduced-motion
    // is on, render a static dot instead of a 600ms repeating opacity pulse.
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!_reducedMotion) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 2,
      height: 14,
      decoration: BoxDecoration(
        // AESTH-05 per AUDIT_RETRAIT S3 (D-03 swap map)
        color: MintColors.textSecondaryAaa.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(1),
      ),
    );
    if (_reducedMotion) {
      // Static glyph — no animation controller running.
      return Opacity(opacity: 0.6, child: dot);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value < 0.5 ? 1.0 : 0.0,
          child: child,
        );
      },
      child: dot,
    );
  }
}
