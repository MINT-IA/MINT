import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_motion.dart';

// ────────────────────────────────────────────────────────────
//  MINT LIGNE — The signature horizontal line
// ────────────────────────────────────────────────────────────
//
//  1px horizontal, ardoise at 15% alpha, draws left-to-right.
//  "L'equivalent des index sur un cadran de montre suisse."
//
//  Design Manifesto 2027 — validated by UX audit.
//
//  Usage:
//  ```dart
//  MintLigne()                    // animated, full width
//  MintLigne(animate: false)      // static, no draw animation
//  MintLigne(width: 200)          // fixed width
//  ```
// ────────────────────────────────────────────────────────────

class MintLigne extends StatefulWidget {
  /// Whether to animate the draw from left to right.
  final bool animate;

  /// Fixed width. If null, expands to parent width.
  final double? width;

  /// Line thickness. Defaults to 1px.
  final double thickness;

  /// Override color. Defaults to ardoise at 15% alpha.
  final Color? color;

  /// Animation duration. Defaults to 400ms.
  final Duration duration;

  const MintLigne({
    super.key,
    this.animate = true,
    this.width,
    this.thickness = 1.0,
    this.color,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<MintLigne> createState() => _MintLigneState();
}

class _MintLigneState extends State<MintLigne>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthFraction;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _widthFraction = CurvedAnimation(
      parent: _controller,
      curve: MintMotion.curveEnter,
    );

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = widget.color ?? MintColors.ardoise.withValues(alpha: 0.15);

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _widthFraction,
        builder: (context, _) {
          return SizedBox(
            width: widget.width,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _widthFraction.value,
              child: Container(
                height: widget.thickness,
                color: lineColor,
              ),
            ),
          );
        },
      ),
    );
  }
}
