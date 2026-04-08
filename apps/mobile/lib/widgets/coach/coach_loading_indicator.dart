import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/coach/coach_message_bubble.dart';

// ────────────────────────────────────────────────────────────
//  COACH LOADING INDICATOR — extracted from coach_chat_screen.dart
// ────────────────────────────────────────────────────────────

/// Loading indicator with coach avatar and animated typing dots.
class CoachLoadingIndicator extends StatelessWidget {
  const CoachLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final loadingText = S.of(context)!.coachLoading;
    return Semantics(
      label: loadingText,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md, vertical: MintSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CoachAvatar(),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: MintColors.porcelaine,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: const _TypingDots(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated three-dot typing indicator.
class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (i) => TypingDot(delay: i * 200)),
      ),
    );
  }
}

/// Individual typing dot with staggered animation for the loading indicator.
class TypingDot extends StatefulWidget {
  final int delay;
  const TypingDot({super.key, required this.delay});

  @override
  State<TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.7),
          child: child,
        );
      },
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: MintColors.textMuted,
          borderRadius: BorderRadius.circular(2.5),
        ),
      ),
    );
  }
}
