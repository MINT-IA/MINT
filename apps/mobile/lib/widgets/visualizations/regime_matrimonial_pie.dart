import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  REGIME MATRIMONIAL PIE CHART (ANIMATED DONUT)
// ────────────────────────────────────────────────────────────
//
//  Animated donut chart showing asset split per regime:
//    - Participation aux acquets: 50/50
//    - Separation de biens: each keeps their own
//    - Communaute de biens: everything shared
//  Features:
//    - Smooth sweep animation when switching regimes
//    - Donut style with CHF amounts in center
//    - Touch-to-highlight segments
//    - Legend with colored dots
// ────────────────────────────────────────────────────────────

/// Available matrimonial regimes in Swiss law.
enum RegimeMatrimonial {
  participationAcquets,
  separationBiens,
  communauteBiens,
}

extension RegimeMatrimonialLabel on RegimeMatrimonial {
  String get label {
    switch (this) {
      case RegimeMatrimonial.participationAcquets:
        return 'Participation aux acquets';
      case RegimeMatrimonial.separationBiens:
        return 'Separation de biens';
      case RegimeMatrimonial.communauteBiens:
        return 'Communaute de biens';
    }
  }

  String get shortLabel {
    switch (this) {
      case RegimeMatrimonial.participationAcquets:
        return '50/50';
      case RegimeMatrimonial.separationBiens:
        return 'Separe';
      case RegimeMatrimonial.communauteBiens:
        return 'Commun';
    }
  }

  String get description {
    switch (this) {
      case RegimeMatrimonial.participationAcquets:
        return 'Les acquets sont partages a parts egales.';
      case RegimeMatrimonial.separationBiens:
        return 'Chacun conserve ses biens propres.';
      case RegimeMatrimonial.communauteBiens:
        return 'Tous les biens sont mis en commun.';
    }
  }
}

/// Format a number with Swiss apostrophe thousands separator.
String _formatChf(double value) {
  final abs = value.abs().round();
  final str = abs.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
    buffer.write(str[i]);
  }
  return 'CHF $buffer';
}

class RegimeMatrimonialPie extends StatefulWidget {
  /// Total assets of Person 1.
  final double assetsPersonne1;

  /// Total assets of Person 2.
  final double assetsPersonne2;

  /// Name labels.
  final String labelPersonne1;
  final String labelPersonne2;

  /// Currently selected regime.
  final RegimeMatrimonial regime;

  /// Callback when regime is changed.
  final ValueChanged<RegimeMatrimonial>? onRegimeChanged;

  const RegimeMatrimonialPie({
    super.key,
    required this.assetsPersonne1,
    required this.assetsPersonne2,
    this.labelPersonne1 = 'Personne 1',
    this.labelPersonne2 = 'Personne 2',
    this.regime = RegimeMatrimonial.participationAcquets,
    this.onRegimeChanged,
  });

  @override
  State<RegimeMatrimonialPie> createState() => _RegimeMatrimonialPieState();
}

class _RegimeMatrimonialPieState extends State<RegimeMatrimonialPie>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sweepAnimation;
  int? _highlightedSegment; // 0 = person1, 1 = person2

  // Animated share values
  double _animFromShare1 = 0.5;
  double _animToShare1 = 0.5;
  double _animFromShare2 = 0.5;
  double _animToShare2 = 0.5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _sweepAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _updateShares(animate: false);
    _controller.forward();
  }

  @override
  void didUpdateWidget(RegimeMatrimonialPie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.regime != widget.regime ||
        oldWidget.assetsPersonne1 != widget.assetsPersonne1 ||
        oldWidget.assetsPersonne2 != widget.assetsPersonne2) {
      _updateShares(animate: true);
    }
  }

  void _updateShares({required bool animate}) {
    final total = widget.assetsPersonne1 + widget.assetsPersonne2;
    if (total == 0) return;

    double newShare1;
    double newShare2;

    switch (widget.regime) {
      case RegimeMatrimonial.participationAcquets:
        newShare1 = 0.5;
        newShare2 = 0.5;
      case RegimeMatrimonial.separationBiens:
        newShare1 = widget.assetsPersonne1 / total;
        newShare2 = widget.assetsPersonne2 / total;
      case RegimeMatrimonial.communauteBiens:
        newShare1 = 0.5;
        newShare2 = 0.5;
    }

    if (animate) {
      // Tween from current to new
      _animFromShare1 =
          _animFromShare1 +
          (_animToShare1 - _animFromShare1) * _sweepAnimation.value;
      _animFromShare2 =
          _animFromShare2 +
          (_animToShare2 - _animFromShare2) * _sweepAnimation.value;
    } else {
      _animFromShare1 = newShare1;
      _animFromShare2 = newShare2;
    }

    _animToShare1 = newShare1;
    _animToShare2 = newShare2;

    if (animate) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _total => widget.assetsPersonne1 + widget.assetsPersonne2;

  double _currentShare1(double t) => _animFromShare1 + (_animToShare1 - _animFromShare1) * t;
  double _currentShare2(double t) => _animFromShare2 + (_animToShare2 - _animFromShare2) * t;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Graphique du regime matrimonial: ${widget.regime.label}. '
          '${widget.labelPersonne1}: ${_formatChf(widget.assetsPersonne1)}, '
          '${widget.labelPersonne2}: ${_formatChf(widget.assetsPersonne2)}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pieSize = min(constraints.maxWidth - 80, 220.0);
          return Container(
            width: constraints.maxWidth,
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
                _buildRegimeSelector(),
                const SizedBox(height: 16),
                _buildPieChart(pieSize),
                const SizedBox(height: 16),
                _buildLegend(),
                _buildDescription(),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.12),
              borderRadius: const Borderconst Radius.circular(12),
            ),
            child: const Icon(
              Icons.pie_chart_outline,
              color: MintColors.info,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Regime matrimonial',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                Text(
                  'Repartition des biens',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegimeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: const Borderconst Radius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: RegimeMatrimonial.values.map((regime) {
            final isSelected = widget.regime == regime;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (widget.onRegimeChanged != null) {
                    widget.onRegimeChanged!(regime);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: const Borderconst Radius.circular(10),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color:
                                  MintColors.primary.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    regime.shortLabel,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? MintColors.textPrimary
                          : MintColors.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPieChart(double size) {
    return AnimatedBuilder(
      animation: _sweepAnimation,
      builder: (context, _) {
        final t = _sweepAnimation.value;
        final share1 = _currentShare1(t);
        final share2 = _currentShare2(t);
        final amount1 = _total * share1;
        final amount2 = _total * share2;

        return GestureDetector(
          onTapDown: (details) {
            // Determine which segment was tapped based on angle
            final center = Offset(size / 2, size / 2);
            final tap = details.localPosition;
            final angle = atan2(tap.dy - center.dy, tap.dx - center.dx);
            final normalizedAngle = (angle + pi / 2) % (2 * pi);
            final share1Angle = share1 * 2 * pi;
            setState(() {
              _highlightedSegment =
                  normalizedAngle < share1Angle ? 0 : 1;
            });
          },
          onTapUp: (_) {
            // Clear highlight after brief delay
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() => _highlightedSegment = null);
              }
            });
          },
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _PieChartPainter(
                share1: share1,
                share2: share2,
                color1: MintColors.info,
                color2: const Color(0xFF7C4DFF), // Deep purple
                highlightedSegment: _highlightedSegment,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatChf(_total),
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textMuted,
                      ),
                    ),
                    if (_highlightedSegment != null) ...[
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _highlightedSegment == 0
                              ? _formatChf(amount1)
                              : _formatChf(amount2),
                          key: ValueKey(_highlightedSegment),
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _highlightedSegment == 0
                                ? MintColors.info
                                : const Color(0xFF7C4DFF),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return AnimatedBuilder(
      animation: _sweepAnimation,
      builder: (context, _) {
        final t = _sweepAnimation.value;
        final share1 = _currentShare1(t);
        final share2 = _currentShare2(t);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _buildLegendItem(
                color: MintColors.info,
                label: widget.labelPersonne1,
                percentage: (share1 * 100).round(),
                amount: _total * share1,
              ),
              const Spacer(),
              _buildLegendItem(
                color: const Color(0xFF7C4DFF),
                label: widget.labelPersonne2,
                percentage: (share2 * 100).round(),
                amount: _total * share2,
                crossAlignment: CrossAxisAlignment.end,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required int percentage,
    required double amount,
    CrossAxisAlignment crossAlignment = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: crossAlignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$percentage% — ${_formatChf(amount)}',
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey(widget.regime),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: const Borderconst Radius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: MintColors.info,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.regime.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  PIE CHART CUSTOM PAINTER (DONUT)
// ────────────────────────────────────────────────────────────

class _PieChartPainter extends CustomPainter {
  final double share1;
  final double share2;
  final Color color1;
  final Color color2;
  final int? highlightedSegment;

  _PieChartPainter({
    required this.share1,
    required this.share2,
    required this.color1,
    required this.color2,
    this.highlightedSegment,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    const donutWidth = 28.0;
    final innerRadius = radius - donutWidth;

    // Background ring
    final bgPaint = Paint()
      ..color = const Color(0xFFF0F0F2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = donutWidth;
    canvas.drawCircle(center, innerRadius + donutWidth / 2, bgPaint);

    // Start from top (-pi/2)
    const startAngle = -pi / 2;
    final sweep1 = share1 * 2 * pi;
    final sweep2 = share2 * 2 * pi;

    // Segment 1
    final isHighlight1 = highlightedSegment == 0;
    final paint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHighlight1 ? donutWidth + 6 : donutWidth
      ..strokeCap = StrokeCap.butt
      ..color = color1;
    if (sweep1 > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(
            center: center, radius: innerRadius + donutWidth / 2),
        startAngle,
        sweep1,
        false,
        paint1,
      );
    }

    // Segment 2
    final isHighlight2 = highlightedSegment == 1;
    final paint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHighlight2 ? donutWidth + 6 : donutWidth
      ..strokeCap = StrokeCap.butt
      ..color = color2;
    if (sweep2 > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(
            center: center, radius: innerRadius + donutWidth / 2),
        startAngle + sweep1,
        sweep2,
        false,
        paint2,
      );
    }

    // Glow effect on highlighted segment
    if (highlightedSegment != null) {
      final glowColor =
          highlightedSegment == 0 ? color1 : color2;
      final glowAngle =
          highlightedSegment == 0 ? startAngle : startAngle + sweep1;
      final glowSweep = highlightedSegment == 0 ? sweep1 : sweep2;
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = donutWidth + 16
        ..strokeCap = StrokeCap.butt
        ..color = glowColor.withValues(alpha: 0.15);
      if (glowSweep > 0.001) {
        canvas.drawArc(
          Rect.fromCircle(
              center: center, radius: innerRadius + donutWidth / 2),
          glowAngle,
          glowSweep,
          false,
          glowPaint,
        );
      }
    }

    // Thin separator lines at segment boundaries
    final separatorPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    // Line at boundary 1-2
    final angle1 = startAngle + sweep1;
    final outerPoint1 = Offset(
      center.dx + (radius + 2) * cos(angle1),
      center.dy + (radius + 2) * sin(angle1),
    );
    final innerPoint1 = Offset(
      center.dx + (innerRadius - 2) * cos(angle1),
      center.dy + (innerRadius - 2) * sin(angle1),
    );
    canvas.drawLine(innerPoint1, outerPoint1, separatorPaint);
    // Line at start
    final outerPoint0 = Offset(
      center.dx + (radius + 2) * cos(startAngle),
      center.dy + (radius + 2) * sin(startAngle),
    );
    final innerPoint0 = Offset(
      center.dx + (innerRadius - 2) * cos(startAngle),
      center.dy + (innerRadius - 2) * sin(startAngle),
    );
    canvas.drawLine(innerPoint0, outerPoint0, separatorPaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.share1 != share1 ||
        oldDelegate.share2 != share2 ||
        oldDelegate.highlightedSegment != highlightedSegment;
  }
}
