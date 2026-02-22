import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/forecaster_service.dart';

// ────────────────────────────────────────────────────────────
//  MINT TRAJECTORY CHART — Sprint C4 / MINT Coach
// ────────────────────────────────────────────────────────────
//
//  Graphique interactif a 3 scenarios (piece maitresse).
//
//  3 courbes en eventail :
//    - Optimiste (vert, pointille) — ligne du haut
//    - Base (bleu, trait plein, plus epais) — ligne du milieu
//    - Prudent (orange, pointille) — ligne du bas
//    - Zone de remplissage degrade entre optimiste et prudent
//
//  Axe X : temps (annees depuis maintenant jusqu'a la cible)
//  Axe Y : capital en CHF (mise a l'echelle auto, format suisse)
//  Position actuelle : point anime avec pulse sur la ligne base a x=0
//  Marqueur Goal A : ligne verticale pointillee a la date cible
//  Milestones : petits points sur la ligne base
//  Labels de capital en bout de ligne
//
//  Animation draw-in de gauche a droite au premier affichage.
//  Interaction : tap pour afficher un tooltip date + capital.
//
//  Widget pur — pas de Provider, uniquement des props.
// ────────────────────────────────────────────────────────────

class MintTrajectoryChart extends StatefulWidget {
  /// Resultat de projection 3 scenarios
  final ProjectionResult result;

  /// Label du Goal A (ex: "Retraite")
  final String? goalALabel;

  /// Callback au tap
  final VoidCallback? onTap;

  const MintTrajectoryChart({
    super.key,
    required this.result,
    this.goalALabel,
    this.onTap,
  });

  @override
  State<MintTrajectoryChart> createState() => _MintTrajectoryChartState();
}

class _MintTrajectoryChartState extends State<MintTrajectoryChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _drawAnimation;

  /// Index du point le plus proche apres un tap ou un drag
  int? _selectedPointIndex;

  /// True while the user is dragging/scrubbing across the chart
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _drawAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(MintTrajectoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      _selectedPointIndex = null;
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
    final s = S.of(context);
    final hasPoints = widget.result.base.points.isNotEmpty;

    return Semantics(
      label: 'Graphique de trajectoire financière. '
          'Scénario base : ${_formatChf(widget.result.base.capitalFinal)}. '
          'Taux de remplacement estimé : ${widget.result.tauxRemplacementBase.round()} pour cent.',
      child: GestureDetector(
        onTap: hasPoints ? _handleTap : widget.onTap,
        onTapDown: hasPoints ? _handleTapDown : null,
        onPanStart: hasPoints ? _handlePanStart : null,
        onPanUpdate: hasPoints ? _handlePanUpdate : null,
        onPanEnd: hasPoints ? _handlePanEnd : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
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
                  const SizedBox(height: 16),
                  if (hasPoints) ...[
                    _buildChart(constraints.maxWidth - 48),
                    const SizedBox(height: 16),
                    _buildLegend(),
                    if (_selectedPointIndex == null) _buildScrubHint(),
                    const SizedBox(height: 12),
                    _buildTauxRemplacement(),
                  ] else
                    _buildEmptyState(),
                  const SizedBox(height: 12),
                  _buildDisclaimer(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  GESTURE HANDLING (tap + drag/scrub)
  // ────────────────────────────────────────────────────────────

  /// Converts an x-position (in local widget coordinates) to the nearest
  /// point index on the base scenario line. Returns null if out of bounds.
  int? _pointIndexFromX(double dx) {
    final points = widget.result.base.points;
    if (points.isEmpty) return null;

    final chartLeft = 48.0; // approx left margin
    final chartRight = (context.size?.width ?? 300) - 48 - 16;
    final chartWidth = chartRight - chartLeft;

    if (chartWidth <= 0) return null;

    final relativeX =
        ((dx - chartLeft) / chartWidth).clamp(0.0, 1.0);
    final pointIndex = (relativeX * (points.length - 1)).round();
    return pointIndex.clamp(0, points.length - 1);
  }

  void _handleTapDown(TapDownDetails details) {
    final index = _pointIndexFromX(details.localPosition.dx);
    if (index == null) return;
    setState(() {
      _selectedPointIndex = index;
    });
  }

  void _handleTap() {
    if (_isDragging) return;
    // If a point is already selected, dismiss the tooltip; otherwise forward onTap
    if (_selectedPointIndex != null) {
      setState(() {
        _selectedPointIndex = null;
      });
    } else {
      widget.onTap?.call();
    }
  }

  void _handlePanStart(DragStartDetails details) {
    _isDragging = true;
    final index = _pointIndexFromX(details.localPosition.dx);
    if (index == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPointIndex = index;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final index = _pointIndexFromX(details.localPosition.dx);
    if (index == null) return;
    if (index != _selectedPointIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedPointIndex = index;
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _isDragging = false;
  }

  // ────────────────────────────────────────────────────────────
  //  HEADER
  // ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final s = S.of(context);
    final yearsToTarget = _yearsToTarget();
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MintColors.trajectoryBase.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.show_chart,
            color: MintColors.trajectoryBase,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s?.trajectoryTitle ?? 'Ta trajectoire',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                s?.trajectorySubtitle(yearsToTarget.toString()) ?? '3 scénarios · $yearsToTarget ans',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Capital cible badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: MintColors.trajectoryBase.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _formatChf(widget.result.base.capitalFinal),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MintColors.trajectoryBase,
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  CHART (CustomPaint + animated draw-in)
  // ────────────────────────────────────────────────────────────

  Widget _buildChart(double availableWidth) {
    const chartHeight = 220.0;

    return AnimatedBuilder(
      animation: _drawAnimation,
      builder: (context, _) {
        return SizedBox(
          width: availableWidth,
          height: chartHeight,
          child: Stack(
            children: [
              // Main chart
              CustomPaint(
                painter: _TrajectoryPainter(
                  prudentPoints: widget.result.prudent.points,
                  basePoints: widget.result.base.points,
                  optimistePoints: widget.result.optimiste.points,
                  milestones: widget.result.milestones,
                  progress: _drawAnimation.value,
                  goalALabel: widget.goalALabel,
                  selectedIndex: _selectedPointIndex,
                  prudentLabel: S.of(context)?.trajectoryPrudent ?? 'Prudent',
                  baseLabel: S.of(context)?.trajectoryBase ?? 'Base',
                  optimisteLabel: S.of(context)?.trajectoryOptimiste ?? 'Optimiste',
                  goalLabel: S.of(context)?.trajectoryGoalLabel ?? 'Cible',
                ),
                size: Size(availableWidth, chartHeight),
              ),
              // Tooltip overlay
              if (_selectedPointIndex != null &&
                  _selectedPointIndex! < widget.result.base.points.length)
                _buildTooltip(availableWidth, chartHeight),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTooltip(double chartWidth, double chartHeight) {
    final points = widget.result.base.points;
    final index = _selectedPointIndex!;
    final basePoint = points[index];
    final prudentPoint = widget.result.prudent.points.length > index
        ? widget.result.prudent.points[index]
        : null;
    final optimistePoint = widget.result.optimiste.points.length > index
        ? widget.result.optimiste.points[index]
        : null;

    // Compute approximate x position
    final xFraction = points.length > 1 ? index / (points.length - 1) : 0.0;
    final chartAreaLeft = 48.0;
    final chartAreaWidth = chartWidth - chartAreaLeft - 16;
    final xPos = chartAreaLeft + xFraction * chartAreaWidth;

    // Position tooltip above chart center, clamped to bounds
    final tooltipWidth = 180.0;
    final tooltipLeft =
        (xPos - tooltipWidth / 2).clamp(0.0, chartWidth - tooltipWidth);

    final dateLabel = _formatDate(basePoint.date);

    final s = S.of(context);
    final optimisteLabel = s?.trajectoryOptimiste ?? 'Optimiste';
    final baseLabel = s?.trajectoryBase ?? 'Base';
    final prudentLabel = s?.trajectoryPrudent ?? 'Prudent';

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      left: tooltipLeft,
      top: 0,
      child: Container(
        width: tooltipWidth,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MintColors.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: MintColors.primary.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateLabel,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            if (optimistePoint != null)
              _buildTooltipLine(
                optimisteLabel,
                _formatChf(optimistePoint.capitalCumule),
                MintColors.trajectoryOptimiste,
              ),
            _buildTooltipLine(
              baseLabel,
              _formatChf(basePoint.capitalCumule),
              MintColors.trajectoryBase,
            ),
            if (prudentPoint != null)
              _buildTooltipLine(
                prudentLabel,
                _formatChf(prudentPoint.capitalCumule),
                MintColors.trajectoryPrudent,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltipLine(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  LEGEND
  // ────────────────────────────────────────────────────────────

  Widget _buildLegend() {
    final s = S.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(
          s?.trajectoryOptimiste ?? 'Optimiste',
          MintColors.trajectoryOptimiste,
          dashed: true,
        ),
        const SizedBox(width: 16),
        _buildLegendItem(
          s?.trajectoryBase ?? 'Base',
          MintColors.trajectoryBase,
          dashed: false,
        ),
        const SizedBox(width: 16),
        _buildLegendItem(
          s?.trajectoryPrudent ?? 'Prudent',
          MintColors.trajectoryPrudent,
          dashed: true,
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, {required bool dashed}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 10,
          child: CustomPaint(
            painter: _LegendLinePainter(color: color, dashed: dashed),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: MintColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  SCRUB HINT
  // ────────────────────────────────────────────────────────────

  Widget _buildScrubHint() {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        s?.trajectoryDragHint ?? 'Glisse pour explorer',
        style: GoogleFonts.inter(
          fontSize: 10,
          color: MintColors.textMuted.withValues(alpha: 0.6),
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  TAUX DE REMPLACEMENT
  // ────────────────────────────────────────────────────────────

  Widget _buildTauxRemplacement() {
    final s = S.of(context);
    final taux = widget.result.tauxRemplacementBase.clamp(0.0, 200.0);
    final isGood = taux >= 60;
    final icon = isGood ? Icons.check_circle_outline : Icons.warning_amber;
    final color = isGood ? MintColors.scoreExcellent : MintColors.scoreAttention;

    return AnimatedBuilder(
      animation: _drawAnimation,
      builder: (context, _) {
        final show = _drawAnimation.value > 0.7;
        return AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textPrimary,
                      ),
                      children: [
                        TextSpan(text: s?.trajectoryTauxRemplacement ?? 'Taux de remplacement estimé : '),
                        TextSpan(
                          text: '${taux.round()}%',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  //  EMPTY STATE
  // ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final s = S.of(context);
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timeline,
            size: 40,
            color: MintColors.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            s?.trajectoryEmpty ?? 'Pas encore de projection disponible',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s?.trajectoryEmptySub ?? 'Complète ton profil pour voir ta trajectoire',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textMuted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  DISCLAIMER
  // ────────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    final s = S.of(context);
    return Text(
      s?.trajectoryDisclaimer ?? 'Estimations \u00e9ducatives \u2014 ne constitue pas un conseil financier.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textMuted,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  HELPERS
  // ────────────────────────────────────────────────────────────

  int _yearsToTarget() {
    final points = widget.result.base.points;
    if (points.isEmpty) return 0;
    final first = points.first.date;
    final last = points.last.date;
    return ((last.difference(first).inDays) / 365.25).round();
  }

  static String _formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }

  static String _formatDate(DateTime date) {
    const months = [
      'janv.', 'fevr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'aout', 'sept.', 'oct.', 'nov.', 'dec.',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

// ════════════════════════════════════════════════════════════════
//  TRAJECTORY CUSTOM PAINTER
// ════════════════════════════════════════════════════════════════
//
//  Dessine les 3 courbes, la zone de remplissage, les axes,
//  les milestones, le point actuel et le marqueur Goal A.
// ════════════════════════════════════════════════════════════════

class _TrajectoryPainter extends CustomPainter {
  final List<ProjectionPoint> prudentPoints;
  final List<ProjectionPoint> basePoints;
  final List<ProjectionPoint> optimistePoints;
  final List<ProjectionMilestone> milestones;
  final double progress; // 0.0 -> 1.0 (draw-in animation)
  final String? goalALabel;
  final int? selectedIndex;

  // i18n labels passed from the widget (CustomPainter has no BuildContext)
  final String prudentLabel;
  final String baseLabel;
  final String optimisteLabel;
  final String goalLabel;

  _TrajectoryPainter({
    required this.prudentPoints,
    required this.basePoints,
    required this.optimistePoints,
    required this.milestones,
    required this.progress,
    required this.prudentLabel,
    required this.baseLabel,
    required this.optimisteLabel,
    required this.goalLabel,
    this.goalALabel,
    this.selectedIndex,
  });

  // Chart margins
  static const double _marginLeft = 48;
  static const double _marginRight = 16;
  static const double _marginTop = 16;
  static const double _marginBottom = 28;

  @override
  void paint(Canvas canvas, Size size) {
    if (basePoints.isEmpty) return;

    final chartLeft = _marginLeft;
    final chartRight = size.width - _marginRight;
    final chartTop = _marginTop;
    final chartBottom = size.height - _marginBottom;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // ── Compute Y scale from all 3 scenarios ──
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final pts in [prudentPoints, basePoints, optimistePoints]) {
      for (final p in pts) {
        if (p.capitalCumule < minY) minY = p.capitalCumule;
        if (p.capitalCumule > maxY) maxY = p.capitalCumule;
      }
    }

    // Add padding
    final yRange = maxY - minY;
    minY = minY - yRange * 0.05;
    maxY = maxY + yRange * 0.05;
    if (minY < 0) minY = 0;
    if (maxY <= minY) maxY = minY + 1;

    // Total points (use base as reference)
    final totalPoints = basePoints.length;
    final visiblePoints = (totalPoints * progress).round().clamp(1, totalPoints);

    // ── Draw axes ──
    _drawAxes(canvas, size, chartLeft, chartTop, chartRight, chartBottom,
        minY, maxY);

    // ── Draw filled region between optimiste and prudent ──
    if (optimistePoints.isNotEmpty && prudentPoints.isNotEmpty) {
      _drawFillRegion(
        canvas,
        chartLeft, chartTop, chartWidth, chartHeight,
        minY, maxY, visiblePoints,
      );
    }

    // ── Draw 3 scenario lines ──
    // Prudent (orange, dashed)
    if (prudentPoints.isNotEmpty) {
      _drawCurve(
        canvas,
        prudentPoints,
        MintColors.trajectoryPrudent,
        chartLeft, chartTop, chartWidth, chartHeight,
        minY, maxY, visiblePoints,
        dashed: true,
        strokeWidth: 2.0,
      );
    }

    // Base (blue, solid, thicker)
    _drawCurve(
      canvas,
      basePoints,
      MintColors.trajectoryBase,
      chartLeft, chartTop, chartWidth, chartHeight,
      minY, maxY, visiblePoints,
      dashed: false,
      strokeWidth: 3.0,
    );

    // Optimiste (green, dashed)
    if (optimistePoints.isNotEmpty) {
      _drawCurve(
        canvas,
        optimistePoints,
        MintColors.trajectoryOptimiste,
        chartLeft, chartTop, chartWidth, chartHeight,
        minY, maxY, visiblePoints,
        dashed: true,
        strokeWidth: 2.0,
      );
    }

    // ── Milestone markers on base line ──
    _drawMilestones(
      canvas,
      chartLeft, chartTop, chartWidth, chartHeight,
      minY, maxY, visiblePoints,
    );

    // ── Goal A marker (vertical dashed line at end) ──
    if (progress > 0.8) {
      _drawGoalAMarker(canvas, chartRight, chartTop, chartBottom);
    }

    // ── Current position dot (animated pulse at x=0) ──
    _drawCurrentPositionDot(
      canvas, chartLeft, chartTop, chartHeight, minY, maxY,
    );

    // ── Capital labels at end of each line ──
    if (visiblePoints >= totalPoints && progress > 0.9) {
      _drawEndLabels(
        canvas, size,
        chartLeft, chartTop, chartWidth, chartHeight,
        minY, maxY,
      );
    }

    // ── Selected point vertical line ──
    if (selectedIndex != null &&
        selectedIndex! < visiblePoints &&
        selectedIndex! < basePoints.length) {
      _drawSelectedLine(
        canvas,
        chartLeft, chartTop, chartWidth, chartHeight, chartBottom,
        minY, maxY,
      );
    }
  }

  // ── AXES ──

  void _drawAxes(
    Canvas canvas,
    Size size,
    double chartLeft,
    double chartTop,
    double chartRight,
    double chartBottom,
    double minY,
    double maxY,
  ) {
    final chartHeight = chartBottom - chartTop;

    // Y axis: horizontal grid lines + labels
    const yGridCount = 4;
    for (int i = 0; i <= yGridCount; i++) {
      final fraction = i / yGridCount;
      final y = chartBottom - fraction * chartHeight;
      final value = minY + fraction * (maxY - minY);

      // Grid line
      final gridPaint = Paint()
        ..color = MintColors.lightBorder.withValues(alpha: 0.6)
        ..strokeWidth = 0.5;
      canvas.drawLine(
        Offset(chartLeft, y),
        Offset(chartRight, y),
        gridPaint,
      );

      // Y label (CHF with Swiss apostrophe)
      final label = _formatAxisValue(value);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: MintColors.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(chartLeft - tp.width - 6, y - tp.height / 2));
    }

    // X axis: year labels
    if (basePoints.isNotEmpty) {
      final firstYear = basePoints.first.date.year;
      final lastYear = basePoints.last.date.year;
      final totalMonths = basePoints.length;
      final chartWidth = chartRight - chartLeft;

      // Show year labels at regular intervals
      final yearSpan = lastYear - firstYear;
      final yearStep = yearSpan <= 10 ? 2 : yearSpan <= 20 ? 5 : 10;

      for (int year = firstYear; year <= lastYear; year += yearStep) {
        // Find the approximate index for this year
        final monthsFromStart = (year - firstYear) * 12;
        if (monthsFromStart < 0 || monthsFromStart >= totalMonths) continue;

        final xFraction = monthsFromStart / (totalMonths - 1);
        final x = chartLeft + xFraction * chartWidth;

        final tp = TextPainter(
          text: TextSpan(
            text: '$year',
            style: GoogleFonts.inter(
              fontSize: 9,
              color: MintColors.textMuted,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chartBottom + 6));
      }

      // Always show last year
      final lastXTp = TextPainter(
        text: TextSpan(
          text: '$lastYear',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: MintColors.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      lastXTp.layout();
      lastXTp.paint(
        canvas,
        Offset(chartRight - lastXTp.width / 2, chartBottom + 6),
      );
    }
  }

  // ── FILL REGION (between optimiste and prudent) ──

  void _drawFillRegion(
    Canvas canvas,
    double chartLeft,
    double chartTop,
    double chartWidth,
    double chartHeight,
    double minY,
    double maxY,
    int visiblePoints,
  ) {
    final optiLen = min(visiblePoints, optimistePoints.length);
    final prudLen = min(visiblePoints, prudentPoints.length);
    final len = min(optiLen, prudLen);
    if (len < 2) return;

    final path = Path();

    // Top edge (optimiste, left to right)
    for (int i = 0; i < len; i++) {
      final x = chartLeft + (i / (basePoints.length - 1)) * chartWidth;
      final yFrac =
          (optimistePoints[i].capitalCumule - minY) / (maxY - minY);
      final y = chartTop + chartHeight - yFrac * chartHeight;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Bottom edge (prudent, right to left)
    for (int i = len - 1; i >= 0; i--) {
      final x = chartLeft + (i / (basePoints.length - 1)) * chartWidth;
      final yFrac =
          (prudentPoints[i].capitalCumule - minY) / (maxY - minY);
      final y = chartTop + chartHeight - yFrac * chartHeight;
      path.lineTo(x, y);
    }

    path.close();

    final fillPaint = Paint()
      ..color = MintColors.trajectoryBase.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);
  }

  // ── CURVE DRAWING ──

  void _drawCurve(
    Canvas canvas,
    List<ProjectionPoint> points,
    Color color,
    double chartLeft,
    double chartTop,
    double chartWidth,
    double chartHeight,
    double minY,
    double maxY,
    int visiblePoints, {
    required bool dashed,
    required double strokeWidth,
  }) {
    final len = min(visiblePoints, points.length);
    if (len < 2) return;

    final path = Path();

    for (int i = 0; i < len; i++) {
      final x = chartLeft + (i / (basePoints.length - 1)) * chartWidth;
      final yFrac = (points[i].capitalCumule - minY) / (maxY - minY);
      final y = chartTop + chartHeight - yFrac * chartHeight;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (dashed) {
      _drawDashedPath(canvas, path, color, strokeWidth);
    } else {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Color color,
    double strokeWidth,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      const dashLength = 6.0;
      const dashGap = 4.0;
      bool draw = true;

      while (distance < metric.length) {
        final length = draw ? dashLength : dashGap;
        final end = min(distance + length, metric.length);
        if (draw) {
          final extractPath = metric.extractPath(distance, end);
          canvas.drawPath(extractPath, paint);
        }
        distance = end;
        draw = !draw;
      }
    }
  }

  // ── MILESTONES ──

  void _drawMilestones(
    Canvas canvas,
    double chartLeft,
    double chartTop,
    double chartWidth,
    double chartHeight,
    double minY,
    double maxY,
    int visiblePoints,
  ) {
    if (milestones.isEmpty || basePoints.isEmpty) return;

    final firstDate = basePoints.first.date;
    final totalMonths = basePoints.length;

    for (final milestone in milestones) {
      // Find the month index for this milestone
      final monthsFromStart =
          (milestone.date.year - firstDate.year) * 12 +
          (milestone.date.month - firstDate.month);

      if (monthsFromStart < 0 || monthsFromStart >= visiblePoints) continue;
      if (monthsFromStart >= basePoints.length) continue;

      final x = chartLeft + (monthsFromStart / (totalMonths - 1)) * chartWidth;
      final yFrac =
          (basePoints[monthsFromStart].capitalCumule - minY) / (maxY - minY);
      final y = chartTop + chartHeight - yFrac * chartHeight;

      // Small dot
      final dotPaint = Paint()..color = MintColors.trajectoryBase;
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);

      // White inner
      final innerPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(x, y), 1.5, innerPaint);
    }
  }

  // ── GOAL A MARKER ──

  void _drawGoalAMarker(
    Canvas canvas,
    double chartRight,
    double chartTop,
    double chartBottom,
  ) {
    // Vertical dashed line
    final dashPaint = Paint()
      ..color = MintColors.textMuted.withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    const dashLen = 5.0;
    const dashGap = 4.0;
    double y = chartTop;
    while (y < chartBottom) {
      final endY = min(y + dashLen, chartBottom);
      canvas.drawLine(
        Offset(chartRight, y),
        Offset(chartRight, endY),
        dashPaint,
      );
      y += dashLen + dashGap;
    }

    // Goal label
    final label = goalALabel ?? goalLabel;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: MintColors.textSecondary,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(chartRight - tp.width - 4, chartTop - 14));
  }

  // ── CURRENT POSITION DOT (pulse effect at x=0) ──

  void _drawCurrentPositionDot(
    Canvas canvas,
    double chartLeft,
    double chartTop,
    double chartHeight,
    double minY,
    double maxY,
  ) {
    if (basePoints.isEmpty) return;

    final yFrac = (basePoints.first.capitalCumule - minY) / (maxY - minY);
    final y = chartTop + chartHeight - yFrac * chartHeight;
    final center = Offset(chartLeft, y);

    // Pulse ring (animated with progress)
    final pulseRadius = 8 + 4 * sin(progress * pi * 2);
    final pulsePaint = Paint()
      ..color = MintColors.trajectoryBase.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Solid dot
    final dotPaint = Paint()..color = MintColors.trajectoryBase;
    canvas.drawCircle(center, 5, dotPaint);

    // White inner
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 2, innerPaint);
  }

  // ── END LABELS (capital at end of each line) ──

  void _drawEndLabels(
    Canvas canvas,
    Size size,
    double chartLeft,
    double chartTop,
    double chartWidth,
    double chartHeight,
    double minY,
    double maxY,
  ) {
    final scenarios = [
      (optimistePoints, MintColors.trajectoryOptimiste, optimisteLabel),
      (basePoints, MintColors.trajectoryBase, baseLabel),
      (prudentPoints, MintColors.trajectoryPrudent, prudentLabel),
    ];

    for (final (points, color, _) in scenarios) {
      if (points.isEmpty) continue;

      final lastPoint = points.last;
      final yFrac = (lastPoint.capitalCumule - minY) / (maxY - minY);
      final y = chartTop + chartHeight - yFrac * chartHeight;

      final label = _formatCompactChf(lastPoint.capitalCumule);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: GoogleFonts.montserrat(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();

      // Draw to the right of chart end, shifted up a bit
      final xPos = chartLeft + chartWidth + 2;
      if (xPos + tp.width <= size.width) {
        tp.paint(canvas, Offset(xPos, y - tp.height / 2));
      }
    }
  }

  // ── SELECTED POINT VERTICAL LINE ──

  void _drawSelectedLine(
    Canvas canvas,
    double chartLeft,
    double chartTop,
    double chartWidth,
    double chartHeight,
    double chartBottom,
    double minY,
    double maxY,
  ) {
    final index = selectedIndex!;
    final x = chartLeft + (index / (basePoints.length - 1)) * chartWidth;

    // Vertical line
    final linePaint = Paint()
      ..color = MintColors.textMuted.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(x, chartTop),
      Offset(x, chartBottom),
      linePaint,
    );

    // Dots on each line
    for (final (points, color) in [
      (optimistePoints, MintColors.trajectoryOptimiste),
      (basePoints, MintColors.trajectoryBase),
      (prudentPoints, MintColors.trajectoryPrudent),
    ]) {
      if (index >= points.length) continue;
      final yFrac = (points[index].capitalCumule - minY) / (maxY - minY);
      final y = chartTop + chartHeight - yFrac * chartHeight;

      final dotPaint = Paint()..color = color;
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      final innerPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(x, y), 2, innerPaint);
    }
  }

  // ── HELPERS ──

  String _formatAxisValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return "${(value / 1000).round()}'000";
    }
    return value.round().toString();
  }

  String _formatCompactChf(double value) {
    if (value >= 1000000) {
      return "${(value / 1000000).toStringAsFixed(1)}M";
    }
    if (value >= 1000) {
      final intVal = value.round();
      final str = intVal.toString();
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
        buffer.write(str[i]);
      }
      return buffer.toString();
    }
    return value.round().toString();
  }

  @override
  bool shouldRepaint(covariant _TrajectoryPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.basePoints != basePoints ||
        oldDelegate.prudentPoints != prudentPoints ||
        oldDelegate.optimistePoints != optimistePoints ||
        oldDelegate.prudentLabel != prudentLabel ||
        oldDelegate.baseLabel != baseLabel ||
        oldDelegate.optimisteLabel != optimisteLabel ||
        oldDelegate.goalLabel != goalLabel;
  }
}

// ════════════════════════════════════════════════════════════════
//  LEGEND LINE PAINTER (small line in legend row)
// ════════════════════════════════════════════════════════════════

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;

  _LegendLinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = dashed ? 2.0 : 2.5
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;

    if (dashed) {
      const dashLen = 4.0;
      const dashGap = 3.0;
      double x = 0;
      while (x < size.width) {
        final endX = min(x + dashLen, size.width);
        canvas.drawLine(Offset(x, y), Offset(endX, y), paint);
        x += dashLen + dashGap;
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dashed != dashed;
  }
}
