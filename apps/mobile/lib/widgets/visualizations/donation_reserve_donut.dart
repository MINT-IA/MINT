import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  DONATION RESERVE DONUT CHART
// ────────────────────────────────────────────────────────────
//
//  Donut/pie chart showing succession reserve breakdown:
//    - Protected reserves (conjoint, descendants)
//    - Quotite disponible (freely disposable)
//    - Donation overlay showing what's being given away
//    - Animated sweep + pulse if donation exceeds quotite
//    - Central label with key figure
// ────────────────────────────────────────────────────────────

/// A segment of the donut chart.
class ReserveSegment {
  final String label;
  final double amount;
  final Color color;

  const ReserveSegment({
    required this.label,
    required this.amount,
    required this.color,
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

/// Builds the segments for the donation reserve chart.
List<ReserveSegment> buildDonationReserveSegments({
  required double fortuneTotale,
  required double reserveConjoint,
  required double reserveDescendants,
  required double quotiteDisponible,
  required double montantDonation,
}) {
  return [
    if (reserveConjoint > 0)
      ReserveSegment(
        label: 'Reserve conjoint',
        amount: reserveConjoint,
        color: MintColors.primary,
      ),
    if (reserveDescendants > 0)
      ReserveSegment(
        label: 'Reserve descendants',
        amount: reserveDescendants,
        color: MintColors.info,
      ),
    ReserveSegment(
      label: 'Quotite disponible',
      amount: quotiteDisponible,
      color: MintColors.success,
    ),
  ];
}

class DonationReserveDonut extends StatefulWidget {
  final List<ReserveSegment> segments;
  final double fortuneTotale;
  final double montantDonation;
  final double quotiteDisponible;
  final bool depasseQuotite;

  const DonationReserveDonut({
    super.key,
    required this.segments,
    required this.fortuneTotale,
    required this.montantDonation,
    required this.quotiteDisponible,
    required this.depasseQuotite,
  });

  @override
  State<DonationReserveDonut> createState() => _DonationReserveDonutState();
}

class _DonationReserveDonutState extends State<DonationReserveDonut>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sweepAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _sweepAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(DonationReserveDonut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments != widget.segments ||
        oldWidget.montantDonation != widget.montantDonation) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Graphique en anneau des reserves successorales. Quotite disponible: ${_formatChf(widget.quotiteDisponible)}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(20),
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
                _buildDonutChart(),
                _buildLegend(),
                if (widget.depasseQuotite) _buildWarningBadge(),
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
              borderRadius: BorderRadius.circular(12),
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
                  'Reserves successorales',
                  style: MintTextStyles.titleMedium(),
                ),
                Text(
                  'CC art. 470-471 (revision 2023)',
                  style: MintTextStyles.labelMedium(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart() {
    return AnimatedBuilder(
      animation: _sweepAnimation,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SizedBox(
            height: 200,
            width: 200,
            child: CustomPaint(
              painter: _DonutPainter(
                segments: widget.segments,
                fortuneTotale: widget.fortuneTotale,
                montantDonation: widget.montantDonation,
                depasseQuotite: widget.depasseQuotite,
                progress: _sweepAnimation.value,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Quotite\ndisponible',
                      textAlign: TextAlign.center,
                      style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatChf(widget.quotiteDisponible),
                      style: MintTextStyles.titleMedium(color: widget.depasseQuotite
                            ? MintColors.error
                            : MintColors.success).copyWith(fontWeight: FontWeight.w800),
                    ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (final segment in widget.segments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: segment.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      segment.label,
                      style: MintTextStyles.labelMedium(),
                    ),
                  ),
                  Text(
                    _formatChf(segment.amount),
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (widget.montantDonation > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: widget.depasseQuotite
                          ? MintColors.error
                          : MintColors.warning,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: MintColors.textSecondary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Donation envisagee',
                      style: MintTextStyles.labelMedium(
                        color: widget.depasseQuotite ? MintColors.error : MintColors.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    _formatChf(widget.montantDonation),
                    style: MintTextStyles.labelMedium(
                      color: widget.depasseQuotite
                          ? MintColors.error
                          : MintColors.warning,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWarningBadge() {
    return AnimatedBuilder(
      animation: _sweepAnimation,
      builder: (context, _) {
        final show = _sweepAnimation.value > 0.7;
        return AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: MintColors.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: MintColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cette donation depasse la quotite disponible. '
                    'Les heritiers reserves peuvent la contester.',
                    style: MintTextStyles.labelMedium(color: MintColors.error).copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────
//  DONUT CUSTOM PAINTER
// ────────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final List<ReserveSegment> segments;
  final double fortuneTotale;
  final double montantDonation;
  final bool depasseQuotite;
  final double progress;

  _DonutPainter({
    required this.segments,
    required this.fortuneTotale,
    required this.montantDonation,
    required this.depasseQuotite,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty || fortuneTotale <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    const strokeWidth = 28.0;

    // Background track
    final bgPaint = Paint()
      ..color = MintColors.lightBorder.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Draw segments
    var startAngle = -pi / 2; // Start from top
    final totalAmount = segments.fold<double>(0, (s, seg) => s + seg.amount);

    for (final segment in segments) {
      if (segment.amount <= 0) continue;

      final sweepAngle = (segment.amount / totalAmount) * 2 * pi * progress;

      final segPaint = Paint()
        ..color = segment.color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        segPaint,
      );

      startAngle += sweepAngle;
    }

    // Donation overlay arc (on top, slightly thicker)
    if (montantDonation > 0 && progress > 0.5) {
      final donationAngle = (montantDonation / totalAmount) * 2 * pi;
      final overlayProgress = ((progress - 0.5) * 2).clamp(0.0, 1.0);

      // Start from the quotite disponible segment (last segment)
      // Find where the quotite disponible segment starts
      var qStartAngle = -pi / 2;
      for (var i = 0; i < segments.length - 1; i++) {
        qStartAngle += (segments[i].amount / totalAmount) * 2 * pi;
      }

      final donPaint = Paint()
        ..color = (depasseQuotite ? MintColors.error : MintColors.warning)
            .withValues(alpha: 0.45 * overlayProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        qStartAngle,
        donationAngle * overlayProgress,
        false,
        donPaint,
      );

      // Dotted border for donation arc
      final borderPaint = Paint()
        ..color = (depasseQuotite ? MintColors.error : MintColors.warning)
            .withValues(alpha: 0.8 * overlayProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + strokeWidth / 2 + 3),
        qStartAngle,
        donationAngle * overlayProgress,
        false,
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.segments != segments ||
        oldDelegate.montantDonation != montantDonation;
  }
}
