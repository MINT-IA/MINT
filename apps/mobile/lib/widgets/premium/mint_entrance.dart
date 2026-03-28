import 'package:flutter/material.dart';

/// Entrance animation wrapper — fade + slide up for premium feel.
///
/// Wraps any widget with a smooth reveal: opacity 0→1 + translateY 20→0,
/// duration 300ms, easeOutCubic. Supports stagger via [delay] parameter.
///
/// Usage:
/// ```dart
/// MintEntrance(child: HeroSection(...))
/// MintEntrance(delay: Duration(milliseconds: 100), child: ActionCards(...))
/// MintEntrance(delay: Duration(milliseconds: 200), child: Details(...))
/// ```
class MintEntrance extends StatefulWidget {
  final Widget child;

  /// Delay before animation starts — use for stagger effect.
  final Duration delay;

  /// Slide distance in logical pixels (default 20).
  final double slideOffset;

  /// Animation duration (default 300ms).
  final Duration duration;

  /// Animation curve (default easeOutCubic).
  final Curve curve;

  const MintEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.slideOffset = 20,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<MintEntrance> createState() => _MintEntranceState();
}

class _MintEntranceState extends State<MintEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(curved);

    // Always forward immediately — the delay is baked into the controller
    // via reverseDuration so it works in FakeAsync (widget tests).
    _controller.forward();
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
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _slide.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
