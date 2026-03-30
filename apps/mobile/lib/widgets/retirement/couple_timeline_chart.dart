import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Horizontal swim-lane timeline for couples with age difference.
///
/// Shows 2 lanes (user + conjoint) with work/retirement periods.
/// Work period = amber, Retirement period = blue.
/// Overlap zone (both retired) highlighted.
/// Annotations: revenue per phase.
/// Only displayed if couple with different retirement years.
class CoupleTimelineChart extends StatefulWidget {
  final List<RetirementPhase> phases;
  final String userName;
  final String conjointName;
  final int userBirthYear;
  final int conjointBirthYear;
  final int userRetirementAge;
  final int conjointRetirementAge;

  const CoupleTimelineChart({
    super.key,
    required this.phases,
    required this.userName,
    required this.conjointName,
    required this.userBirthYear,
    required this.conjointBirthYear,
    this.userRetirementAge = 65,
    this.conjointRetirementAge = 65,
  });

  @override
  State<CoupleTimelineChart> createState() => _CoupleTimelineChartState();
}

class _CoupleTimelineChartState extends State<CoupleTimelineChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userRetireYear = widget.userBirthYear + widget.userRetirementAge;
    final conjRetireYear =
        widget.conjointBirthYear + widget.conjointRetirementAge;

    if (userRetireYear == conjRetireYear) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _CoupleTimelinePainter(
                  userName: widget.userName,
                  conjointName: widget.conjointName,
                  userRetireYear: userRetireYear,
                  conjRetireYear: conjRetireYear,
                  phases: widget.phases,
                  progress: _animation.value,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Phase income cards
        ...widget.phases.map((phase) => _buildPhaseCard(phase)),
      ],
    );
  }

  Widget _buildPhaseCard(RetirementPhase phase) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          // Color indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: phase.endYear != null ? MintColors.amber : MintColors.info,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phase.label,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  phase.endYear != null
                      ? '${phase.startYear} - ${phase.endYear}'
                      : 'Des ${phase.startYear}',
                  style: MintTextStyles.labelSmall(color: MintColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '${RetirementProjectionService.formatChf(phase.totalMonthly)}/mois',
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CoupleTimelinePainter extends CustomPainter {
  final String userName;
  final String conjointName;
  final int userRetireYear;
  final int conjRetireYear;
  final List<RetirementPhase> phases;
  final double progress;

  _CoupleTimelinePainter({
    required this.userName,
    required this.conjointName,
    required this.userRetireYear,
    required this.conjRetireYear,
    required this.phases,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const laneHeight = 40.0;
    const laneGap = 30.0;
    const chartLeft = 10.0;
    final chartRight = size.width - 10;
    final chartWidth = (chartRight - chartLeft) * progress;

    // Time range
    final firstRetire = min(userRetireYear, conjRetireYear);
    final secondRetire = max(userRetireYear, conjRetireYear);
    final rangeStart = firstRetire - 2;
    final rangeEnd = secondRetire + 5;
    final totalYears = rangeEnd - rangeStart;

    double yearToX(int year) {
      return chartLeft + (year - rangeStart) / totalYears * chartWidth;
    }

    // ── Lane 1: User ────────────────────────────────────
    const lane1Y = 50.0;
    _drawLane(
      canvas: canvas,
      name: userName,
      laneY: lane1Y,
      laneHeight: laneHeight,
      workStart: yearToX(rangeStart),
      workEnd: yearToX(userRetireYear),
      retireStart: yearToX(userRetireYear),
      retireEnd: yearToX(rangeEnd),
      retireYear: userRetireYear,
    );

    // ── Lane 2: Conjoint ────────────────────────────────
    const lane2Y = lane1Y + laneHeight + laneGap;
    _drawLane(
      canvas: canvas,
      name: conjointName,
      laneY: lane2Y,
      laneHeight: laneHeight,
      workStart: yearToX(rangeStart),
      workEnd: yearToX(conjRetireYear),
      retireStart: yearToX(conjRetireYear),
      retireEnd: yearToX(rangeEnd),
      retireYear: conjRetireYear,
    );

    // ── Overlap zone (both retired) ─────────────────────
    final overlapStart = yearToX(secondRetire);
    final overlapEnd = yearToX(rangeEnd);
    final overlapRect = Rect.fromLTRB(
      overlapStart,
      lane1Y - 10,
      overlapEnd,
      lane2Y + laneHeight + 10,
    );
    canvas.drawRect(
      overlapRect,
      Paint()..color = MintColors.info.withValues(alpha: 0.06),
    );
    // Overlap border
    canvas.drawRect(
      overlapRect,
      Paint()
        ..color = MintColors.info.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // ── Year markers ────────────────────────────────────
    const markerY = lane2Y + laneHeight + 20;
    for (int y = rangeStart; y <= rangeEnd; y++) {
      final x = yearToX(y);
      final isKey = y == userRetireYear || y == conjRetireYear;

      // Tick
      canvas.drawLine(
        Offset(x, lane2Y + laneHeight + 4),
        Offset(x, lane2Y + laneHeight + (isKey ? 12 : 8)),
        Paint()
          ..color = isKey ? MintColors.textPrimary : MintColors.lightBorder
          ..strokeWidth = isKey ? 1.5 : 0.5,
      );

      // Year label (only key years and every 2 years)
      if (isKey || y % 2 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$y',
            style: MintTextStyles.micro(color: isKey ? MintColors.textPrimary : MintColors.textMuted).copyWith(
              fontSize: isKey ? 11 : 9,
              fontWeight: isKey ? FontWeight.w700 : FontWeight.w400,
              fontStyle: FontStyle.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, markerY));
      }
    }

    // ── Transition connector ────────────────────────────
    final transitionX = yearToX(firstRetire);
    final transitionX2 = yearToX(secondRetire);

    // Vertical dashed line at first retirement
    _drawDashedLine(
      canvas,
      Offset(transitionX, lane1Y - 15),
      Offset(transitionX, lane2Y + laneHeight + 4),
      MintColors.textMuted.withValues(alpha: 0.4),
    );

    // Vertical dashed line at second retirement
    _drawDashedLine(
      canvas,
      Offset(transitionX2, lane1Y - 15),
      Offset(transitionX2, lane2Y + laneHeight + 4),
      MintColors.textMuted.withValues(alpha: 0.4),
    );

    // Phase labels at top
    if (phases.isNotEmpty) {
      final phase1Mid = (transitionX + transitionX2) / 2;
      final tp1 = TextPainter(
        text: TextSpan(
          text: 'Phase 1',
          style: MintTextStyles.micro(color: MintColors.amber).copyWith(fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp1.paint(canvas, Offset(phase1Mid - tp1.width / 2, 10));

      if (phases.length > 1) {
        final phase2Mid = (transitionX2 + yearToX(rangeEnd)) / 2;
        final tp2 = TextPainter(
          text: TextSpan(
            text: 'Phase 2',
            style: MintTextStyles.micro(color: MintColors.info).copyWith(fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp2.paint(canvas, Offset(phase2Mid - tp2.width / 2, 10));
      }
    }
  }

  void _drawLane({
    required Canvas canvas,
    required String name,
    required double laneY,
    required double laneHeight,
    required double workStart,
    required double workEnd,
    required double retireStart,
    required double retireEnd,
    required int retireYear,
  }) {
    // Work period (amber)
    final workRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(workStart, laneY, workEnd, laneY + laneHeight),
      topLeft: const Radius.circular(8),
      bottomLeft: const Radius.circular(8),
    );
    canvas.drawRRect(
      workRect,
      Paint()..color = MintColors.amber.withValues(alpha: 0.25),
    );

    // Retirement period (blue)
    final retireRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(retireStart, laneY, retireEnd, laneY + laneHeight),
      topRight: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );
    canvas.drawRRect(
      retireRect,
      Paint()..color = MintColors.info.withValues(alpha: 0.25),
    );

    // Name label
    final nameTP = TextPainter(
      text: TextSpan(
        text: name,
        style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nameTP.paint(
      canvas,
      Offset(workStart + 8, laneY + (laneHeight - nameTP.height) / 2),
    );

    // Transition marker
    canvas.drawCircle(
      Offset(retireStart, laneY + laneHeight / 2),
      5,
      Paint()..color = MintColors.info,
    );

    // Age at retirement
    final ageTP = TextPainter(
      text: TextSpan(
        text: '${65} ans',
        style: MintTextStyles.labelTiny(color: MintColors.info).copyWith(fontWeight: FontWeight.w600, fontStyle: FontStyle.normal),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    ageTP.paint(
      canvas,
      Offset(retireStart + 10, laneY + (laneHeight - ageTP.height) / 2),
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final totalLen = (end - start).distance;
    final dir = (end - start) / totalLen;
    double drawn = 0;
    while (drawn < totalLen) {
      final segEnd = min(drawn + 4, totalLen);
      canvas.drawLine(
        start + dir * drawn,
        start + dir * segEnd,
        paint,
      );
      drawn += 8;
    }
  }

  @override
  bool shouldRepaint(covariant _CoupleTimelinePainter old) =>
      old.progress != progress;
}
