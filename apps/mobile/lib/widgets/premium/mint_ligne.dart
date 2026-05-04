import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_motion.dart';
import 'package:mint_mobile/widgets/mint_custom_paint_mask.dart';

// ────────────────────────────────────────────────────────────
//  MINT LIGNE — The signature horizontal line
// ────────────────────────────────────────────────────────────
//
//  1px horizontal, ardoise at 15% alpha, draws left-to-right.
//  "L'equivalent des index sur un cadran de montre suisse."
//
//  Design Manifesto 2027 — validated by UX audit.
//
//  Enhancements:
//  - Dashed when confidence < 50% (4px dash, 4px gap)
//  - Color-aware: tints based on dominant number's sentiment
//
//  Usage:
//  ```dart
//  MintLigne()                                // animated, full width
//  MintLigne(animate: false)                  // static, no draw animation
//  MintLigne(width: 200)                      // fixed width
//  MintLigne(confidence: 0.35)                // dashed (low confidence)
//  MintLigne(rate: 0.80)                      // success tint
//  MintLigne(rate: 0.55, confidence: 0.40)    // warning + dashed
//  ```
// ────────────────────────────────────────────────────────────

/// Sentiment zone derived from a rate value.
enum _LigneSentiment { success, warning, error }

class MintLigne extends StatefulWidget {
  /// Whether to animate the draw from left to right.
  final bool animate;

  /// Fixed width. If null, expands to parent width.
  final double? width;

  /// Line thickness. Defaults to 1px.
  final double thickness;

  /// Override color. Defaults to sentiment-aware or ardoise at 15% alpha.
  final Color? color;

  /// Animation duration. Defaults to 400ms.
  final Duration duration;

  /// Confidence score (0.0–1.0). When < 0.50, the line draws dashed
  /// (4px dash, 4px gap) instead of solid.
  final double? confidence;

  /// Dominant number's rate (0.0–1.0) for color-aware tinting.
  /// - >= 0.70 → success: ardoise at 0.15 alpha (default)
  /// - 0.50–0.70 → warning: corailDiscret at 0.12 alpha
  /// - < 0.50 → error: error at 0.10 alpha
  final double? rate;

  const MintLigne({
    super.key,
    this.animate = true,
    this.width,
    this.thickness = 1.0,
    this.color,
    this.duration = const Duration(milliseconds: 400),
    this.confidence,
    this.rate,
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

  /// Resolve the line color: explicit override > sentiment-aware > default.
  Color _resolveColor() {
    if (widget.color != null) return widget.color!;

    if (widget.rate != null) {
      final sentiment = _sentimentFromRate(widget.rate!);
      switch (sentiment) {
        case _LigneSentiment.success:
          return MintColors.ardoise.withValues(alpha: 0.15);
        case _LigneSentiment.warning:
          return MintColors.corailDiscret.withValues(alpha: 0.12);
        case _LigneSentiment.error:
          return MintColors.error.withValues(alpha: 0.10);
      }
    }

    // Default: ardoise at 15% alpha.
    return MintColors.ardoise.withValues(alpha: 0.15);
  }

  static _LigneSentiment _sentimentFromRate(double rate) {
    if (rate >= 0.70) return _LigneSentiment.success;
    if (rate >= 0.50) return _LigneSentiment.warning;
    return _LigneSentiment.error;
  }

  /// Whether the line should draw dashed (confidence < 50%).
  bool get _isDashed =>
      widget.confidence != null && widget.confidence! < 0.50;

  @override
  Widget build(BuildContext context) {
    final lineColor = _resolveColor();

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _widthFraction,
        builder: (context, _) {
          return SizedBox(
            width: widget.width,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _widthFraction.value,
              child: _isDashed
                  ? MintCustomPaintMask(
                      child: CustomPaint(
                        size: Size(double.infinity, widget.thickness),
                        painter: _DashedLinePainter(
                          color: lineColor,
                          thickness: widget.thickness,
                          dashWidth: 4.0,
                          gapWidth: 4.0,
                        ),
                      ),
                    )
                  : Container(
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

/// Paints a horizontal dashed line.
class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double thickness;
  final double dashWidth;
  final double gapWidth;

  const _DashedLinePainter({
    required this.color,
    required this.thickness,
    required this.dashWidth,
    required this.gapWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);

    final dashedPath = _createDashedPath(path, dashWidth, gapWidth);
    canvas.drawPath(dashedPath, paint);
  }

  /// Convert a [Path] to a dashed variant using [PathMetric].
  static Path _createDashedPath(
    Path source,
    double dashWidth,
    double gapWidth,
  ) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        result.addPath(
          metric.extractPath(distance, end),
          Offset.zero,
        );
        distance += dashWidth + gapWidth;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      color != oldDelegate.color ||
      thickness != oldDelegate.thickness ||
      dashWidth != oldDelegate.dashWidth ||
      gapWidth != oldDelegate.gapWidth;
}
