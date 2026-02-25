import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  FORFAIT FISCAL COMPARE — Expatriation & Frontaliers
// ────────────────────────────────────────────────────────────
//
//  Dramatic before/after comparison showing forfait vs ordinary
//  taxation for wealthy expatriates:
//    - Two tall bars: "Imposition ordinaire" (red-ish) vs
//      "Forfait fiscal" (green-ish)
//    - Each bar has labeled segments (federal, cantonal, communal)
//    - Animated "savings" arrow between bars
//    - Savings badge between the bars
//    - Bars animate from bottom to top
//    - Decorative Swiss cross watermark
//    - Dashed line showing the forfait base level
//    - "Economie" confetti badge at bottom
// ────────────────────────────────────────────────────────────

/// A single tax segment within a bar.
class TaxSegment {
  final String label;
  final double amount; // CHF

  const TaxSegment({
    required this.label,
    required this.amount,
  });
}

/// Format a number with Swiss apostrophe thousands separator.
String _formatChf(double value) {
  final isNeg = value < 0;
  final abs = value.abs().round();
  final str = abs.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
    buffer.write(str[i]);
  }
  return '${isNeg ? '-' : ''}CHF $buffer';
}

/// Short format for labels on bars.
String _formatChfShort(double value) {
  final abs = value.abs().round();
  if (abs >= 1000000) {
    final m = abs / 1000000;
    return '${value < 0 ? '-' : ''}${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}M';
  }
  if (abs >= 1000) {
    final k = abs / 1000;
    return '${value < 0 ? '-' : ''}${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
  }
  return '${value < 0 ? '-' : ''}$abs';
}

class ForfaitFiscalCompare extends StatefulWidget {
  /// Tax segments under ordinary taxation.
  final List<TaxSegment> ordinarySegments;

  /// Tax segments under forfait fiscal.
  final List<TaxSegment> forfaitSegments;

  /// Optional callback on tap.
  final VoidCallback? onTap;

  const ForfaitFiscalCompare({
    super.key,
    required this.ordinarySegments,
    required this.forfaitSegments,
    this.onTap,
  });

  @override
  State<ForfaitFiscalCompare> createState() => _ForfaitFiscalCompareState();
}

class _ForfaitFiscalCompareState extends State<ForfaitFiscalCompare>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _barAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _barAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(ForfaitFiscalCompare oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ordinarySegments != widget.ordinarySegments ||
        oldWidget.forfaitSegments != widget.forfaitSegments) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _ordinaryTotal =>
      widget.ordinarySegments.fold(0.0, (s, seg) => s + seg.amount);

  double get _forfaitTotal =>
      widget.forfaitSegments.fold(0.0, (s, seg) => s + seg.amount);

  double get _savings => _ordinaryTotal - _forfaitTotal;

  double get _maxTotal => max(_ordinaryTotal, _forfaitTotal);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Comparaison forfait fiscal. Imposition ordinaire: ${_formatChf(_ordinaryTotal)}. '
          'Forfait fiscal: ${_formatChf(_forfaitTotal)}. Economie: ${_formatChf(_savings)}.',
      child: GestureDetector(
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const Borderconst Radius.circular(20),
                border: Border.all(color: MintColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: MintColors.primary.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildBarChart(constraints.maxWidth - 48),
                  const SizedBox(height: 16),
                  _buildSavingsBadge(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MintColors.success.withValues(alpha: 0.12),
            borderRadius: const Borderconst Radius.circular(12),
          ),
          child: const Icon(
            Icons.balance,
            color: MintColors.success,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Forfait fiscal vs Ordinaire',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                'Comparaison annuelle  ·  Expatries',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(double availableWidth) {
    return AnimatedBuilder(
      animation: _barAnimation,
      builder: (context, _) {
        return SizedBox(
          width: availableWidth,
          height: 320,
          child: CustomPaint(
            painter: _ForfaitBarPainter(
              ordinarySegments: widget.ordinarySegments,
              forfaitSegments: widget.forfaitSegments,
              ordinaryTotal: _ordinaryTotal,
              forfaitTotal: _forfaitTotal,
              maxTotal: _maxTotal,
              savings: _savings,
              progress: _barAnimation.value,
            ),
            size: Size(availableWidth, 320),
          ),
        );
      },
    );
  }

  Widget _buildSavingsBadge() {
    final isSaving = _savings > 0;
    final color = isSaving ? MintColors.success : MintColors.error;

    return AnimatedBuilder(
      animation: _barAnimation,
      builder: (context, _) {
        final show = _barAnimation.value > 0.75;
        return AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: AnimatedScale(
            scale: show ? 1.0 : 0.85,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: const Borderconst Radius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildConfettiDots(color),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      Text(
                        isSaving ? 'Economie forfait' : 'Surcout forfait',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatChf(_savings.abs()),
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      Text(
                        'par annee',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: color.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  _buildConfettiDots(color),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfettiDots(Color color) {
    return SizedBox(
      width: 24,
      height: 44,
      child: Stack(
        children: [
          Positioned(
            left: 2, top: 4,
            child: _dot(color, 5),
          ),
          Positioned(
            left: 14, top: 0,
            child: _dot(MintColors.warning, 4),
          ),
          Positioned(
            left: 8, top: 16,
            child: _dot(MintColors.info, 3),
          ),
          Positioned(
            left: 0, top: 28,
            child: _dot(color, 4),
          ),
          Positioned(
            left: 16, top: 34,
            child: _dot(MintColors.warning, 3),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  FORFAIT BAR CHART CUSTOM PAINTER
// ────────────────────────────────────────────────────────────

class _ForfaitBarPainter extends CustomPainter {
  final List<TaxSegment> ordinarySegments;
  final List<TaxSegment> forfaitSegments;
  final double ordinaryTotal;
  final double forfaitTotal;
  final double maxTotal;
  final double savings;
  final double progress;

  // Segment colors for stacked bars
  static const _ordinaryColors = [
    Color(0xFFFF6B6B), // federal — coral red
    Color(0xFFEE5A24), // cantonal — darker orange-red
    Color(0xFFFF9F43), // communal — warm orange
    Color(0xFFFFBE76), // other — light orange
  ];

  static const _forfaitColors = [
    Color(0xFF2ECC71), // federal — green
    Color(0xFF27AE60), // cantonal — darker green
    Color(0xFF55E6C1), // communal — teal-green
    Color(0xFF7BED9F), // other — light green
  ];

  _ForfaitBarPainter({
    required this.ordinarySegments,
    required this.forfaitSegments,
    required this.ordinaryTotal,
    required this.forfaitTotal,
    required this.maxTotal,
    required this.savings,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (maxTotal <= 0) return;

    const topPadding = 30.0;
    const bottomPadding = 30.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartBottom = size.height - bottomPadding;

    // Bar geometry
    final barWidth = min(size.width * 0.28, 90.0);
    final gap = size.width * 0.2;
    final ordinaryX = (size.width - 2 * barWidth - gap) / 2;
    final forfaitX = ordinaryX + barWidth + gap;

    // ── Swiss cross watermark ──
    _drawSwissCross(canvas, size);

    // ── Draw ordinary bar (left, red) ──
    _drawStackedBar(
      canvas,
      segments: ordinarySegments,
      total: ordinaryTotal,
      colors: _ordinaryColors,
      x: ordinaryX,
      barWidth: barWidth,
      chartHeight: chartHeight,
      chartBottom: chartBottom,
      topPadding: topPadding,
    );

    // ── Draw forfait bar (right, green) ──
    _drawStackedBar(
      canvas,
      segments: forfaitSegments,
      total: forfaitTotal,
      colors: _forfaitColors,
      x: forfaitX,
      barWidth: barWidth,
      chartHeight: chartHeight,
      chartBottom: chartBottom,
      topPadding: topPadding,
    );

    // ── Bar labels at bottom ──
    _drawBarLabel(canvas, 'Imposition\nordinaire', ordinaryX, barWidth,
        chartBottom + 6, MintColors.error);
    _drawBarLabel(canvas, 'Forfait\nfiscal', forfaitX, barWidth,
        chartBottom + 6, MintColors.success);

    // ── Total labels at top ──
    _drawTotalLabel(canvas, ordinaryTotal, ordinaryX, barWidth,
        topPadding - 4, MintColors.error);
    _drawTotalLabel(canvas, forfaitTotal, forfaitX, barWidth,
        topPadding - 4, MintColors.success);

    // ── Dashed forfait base line ──
    if (progress > 0.5) {
      final forfaitBarHeight =
          (forfaitTotal / maxTotal) * chartHeight * progress;
      final forfaitTopY = chartBottom - forfaitBarHeight;
      _drawDashedLine(
        canvas,
        Offset(ordinaryX - 10, forfaitTopY),
        Offset(forfaitX + barWidth + 10, forfaitTopY),
        MintColors.textMuted.withValues(alpha: 0.4),
      );

      // Label for dashed line
      final lineLabelTp = TextPainter(
        text: TextSpan(
          text: 'Base forfaitaire',
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: MintColors.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      lineLabelTp.layout();
      lineLabelTp.paint(
        canvas,
        Offset(forfaitX + barWidth + 14,
            forfaitTopY - lineLabelTp.height / 2),
      );
    }

    // ── Savings arrow between bars ──
    if (progress > 0.6 && savings > 0) {
      _drawSavingsArrow(
        canvas,
        ordinaryX: ordinaryX,
        forfaitX: forfaitX,
        barWidth: barWidth,
        chartHeight: chartHeight,
        chartBottom: chartBottom,
      );
    }
  }

  void _drawStackedBar(
    Canvas canvas, {
    required List<TaxSegment> segments,
    required double total,
    required List<Color> colors,
    required double x,
    required double barWidth,
    required double chartHeight,
    required double chartBottom,
    required double topPadding,
  }) {
    if (total <= 0) return;

    final barHeight = (total / maxTotal) * chartHeight * progress;
    var currentY = chartBottom;

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final segHeight = (seg.amount / total) * barHeight;
      final segTop = currentY - segHeight;
      final color = colors[i % colors.length];

      // Segment fill
      final segPaint = Paint()..color = color.withValues(alpha: 0.85);
      final radius = i == segments.length - 1
          ? const BorderRadius.vertical(top: const Radius.circular(6))
          : BorderRadius.zero;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, segTop, barWidth, segHeight),
          topLeft: radius.topLeft,
          topRight: radius.topRight,
          bottomLeft: i == 0 ? const Radius.circular(2) : Radius.zero,
          bottomRight: i == 0 ? const Radius.circular(2) : Radius.zero,
        ),
        segPaint,
      );

      // Segment label inside bar if tall enough
      if (segHeight > 28 && progress > 0.5) {
        final segLabelTp = TextPainter(
          text: TextSpan(
            text: seg.label,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        segLabelTp.layout(maxWidth: barWidth - 8);
        segLabelTp.paint(
          canvas,
          Offset(x + 6, segTop + 4),
        );

        // Amount label
        final amtTp = TextPainter(
          text: TextSpan(
            text: _formatChfShort(seg.amount),
            style: GoogleFonts.montserrat(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        amtTp.layout();
        amtTp.paint(
          canvas,
          Offset(x + 6, segTop + segLabelTp.height + 4),
        );
      }

      currentY = segTop;
    }

    // Bar border
    final borderPaint = Paint()
      ..color = MintColors.border.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chartBottom - barHeight, barWidth, barHeight),
        const Radius.circular(6),
      ),
      borderPaint,
    );
  }

  void _drawSwissCross(Canvas canvas, Size size) {
    const crossSize = 50.0;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = MintColors.error.withValues(alpha: 0.04);

    // Vertical arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: crossSize * 0.3,
          height: crossSize,
        ),
        const Radius.circular(3),
      ),
      paint,
    );
    // Horizontal arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: crossSize,
          height: crossSize * 0.3,
        ),
        const Radius.circular(3),
      ),
      paint,
    );
  }

  void _drawDashedLine(
      Canvas canvas, Offset start, Offset end, Color color) {
    final dashPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final direction = end - start;
    final length = direction.distance;
    final unitVector = Offset(
      direction.dx / length,
      direction.dy / length,
    );

    var currentDistance = 0.0;
    while (currentDistance < length) {
      final dashEnd = min(currentDistance + dashWidth, length);
      canvas.drawLine(
        start + unitVector * currentDistance,
        start + unitVector * dashEnd,
        dashPaint,
      );
      currentDistance += dashWidth + dashSpace;
    }
  }

  void _drawSavingsArrow(
    Canvas canvas, {
    required double ordinaryX,
    required double forfaitX,
    required double barWidth,
    required double chartHeight,
    required double chartBottom,
  }) {
    final ordinaryBarHeight =
        (ordinaryTotal / maxTotal) * chartHeight * progress;
    final forfaitBarHeight =
        (forfaitTotal / maxTotal) * chartHeight * progress;
    final ordinaryTopY = chartBottom - ordinaryBarHeight;
    final forfaitTopY = chartBottom - forfaitBarHeight;

    // Arrow midpoint
    final arrowX = (ordinaryX + barWidth + forfaitX) / 2;
    final arrowTopY = ordinaryTopY;
    final arrowBottomY = forfaitTopY;

    if ((arrowBottomY - arrowTopY).abs() < 10) return;

    // Arrow line
    final arrowPaint = Paint()
      ..color = MintColors.success.withValues(alpha: 0.7)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(arrowX, arrowTopY),
      Offset(arrowX, arrowBottomY - 8),
      arrowPaint,
    );

    // Arrow head
    final arrowHeadPath = Path()
      ..moveTo(arrowX - 6, arrowBottomY - 14)
      ..lineTo(arrowX, arrowBottomY - 4)
      ..lineTo(arrowX + 6, arrowBottomY - 14)
      ..close();
    final headPaint = Paint()
      ..color = MintColors.success.withValues(alpha: 0.7);
    canvas.drawPath(arrowHeadPath, headPaint);

    // Savings label next to arrow
    final savingsTp = TextPainter(
      text: TextSpan(
        text: '-${_formatChfShort(savings)}',
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: MintColors.success,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    savingsTp.layout();

    // Background pill for label
    final labelY = (arrowTopY + arrowBottomY) / 2 - savingsTp.height / 2;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        arrowX + 8,
        labelY - 4,
        savingsTp.width + 12,
        savingsTp.height + 8,
      ),
      const Radius.circular(8),
    );
    final pillPaint = Paint()
      ..color = MintColors.success.withValues(alpha: 0.1);
    canvas.drawRRect(pillRect, pillPaint);
    final pillBorder = Paint()
      ..color = MintColors.success.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(pillRect, pillBorder);

    savingsTp.paint(canvas, Offset(arrowX + 14, labelY));
  }

  void _drawBarLabel(Canvas canvas, String text, double x, double barWidth,
      double y, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout(maxWidth: barWidth + 20);
    tp.paint(
      canvas,
      Offset(x + barWidth / 2 - tp.width / 2, y),
    );
  }

  void _drawTotalLabel(Canvas canvas, double total, double x,
      double barWidth, double y, Color color) {
    if (progress < 0.3) return;

    final tp = TextPainter(
      text: TextSpan(
        text: _formatChf(total * progress),
        style: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(x + barWidth / 2 - tp.width / 2, y - tp.height),
    );
  }

  @override
  bool shouldRepaint(covariant _ForfaitBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ordinarySegments != ordinarySegments ||
        oldDelegate.forfaitSegments != forfaitSegments ||
        oldDelegate.maxTotal != maxTotal;
  }
}
