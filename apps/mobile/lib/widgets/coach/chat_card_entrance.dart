import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/mint_motion.dart';

// ────────────────────────────────────────────────────────────
//  CHAT CARD ENTRANCE — slide-in + fade reveal
// ────────────────────────────────────────────────────────────
//
//  A wrapper that plays a single-shot entrance animation when the
//  widget first appears in the chat column:
//    - Slides from Offset(0.08, 0) → Offset.zero  (subtle rightward nudge)
//    - Fades from opacity 0 → 1
//
//  Both animations share the same controller and duration so they
//  arrive together as one unified motion.
//
//  Use [delay] to stagger multiple cards in the same chat turn:
//  ```dart
//  ChatCardEntrance(delay: Duration(milliseconds: 0),   child: card1),
//  ChatCardEntrance(delay: Duration(milliseconds: 80),  child: card2),
//  ChatCardEntrance(delay: Duration(milliseconds: 160), child: card3),
//  ```
//
//  Motion principles (MINT_UX_GRAAL_MASTERPLAN §6):
//  - Duration 600 ms (MintMotion.slow) — calm, not urgent
//  - Curve: easeOutQuart (MintMotion.curveEnter) — fast start, soft landing
//  - Offset: 0.08 horizontal — barely perceptible, purely tactile
//  - No bounce, no overshoot, no spring
// ────────────────────────────────────────────────────────────

class ChatCardEntrance extends StatefulWidget {
  /// The widget to animate in.
  final Widget child;

  /// Optional delay before the animation starts. Use to stagger multiple
  /// cards. Defaults to [Duration.zero].
  final Duration delay;

  /// Animation duration. Defaults to 600 ms (MintMotion.slow).
  final Duration duration;

  const ChatCardEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = MintMotion.slow,
  });

  @override
  State<ChatCardEntrance> createState() => _ChatCardEntranceState();
}

class _ChatCardEntranceState extends State<ChatCardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: MintMotion.curveEnter, // easeOutQuart
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(curved);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(curved);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
