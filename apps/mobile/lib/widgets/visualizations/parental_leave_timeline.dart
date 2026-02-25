import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  PARENTAL LEAVE APG TIMELINE VISUALIZATION
// ────────────────────────────────────────────────────────────
//
//  Horizontal scrollable timeline showing:
//    - Week markers with APG daily amounts
//    - Income bridge: salary bar vs APG bar with gap highlight
//    - Running total accumulator
//    - Cap line at CHF 220/day if salary exceeds threshold
//    - Key milestone icons (birth, return-to-work)
// ────────────────────────────────────────────────────────────

/// Data for a single week in the parental leave timeline.
class ParentalLeaveWeek {
  final int weekNumber;
  final double dailyApg;
  final bool isActive;

  const ParentalLeaveWeek({
    required this.weekNumber,
    required this.dailyApg,
    this.isActive = true,
  });

  double get weeklyTotal => dailyApg * 7;
}

/// Whether the timeline represents maternity or paternity leave.
enum LeaveType { maternity, paternity }

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

class ParentalLeaveTimeline extends StatefulWidget {
  /// List of weeks with APG data.
  final List<ParentalLeaveWeek> weeks;

  /// The person's daily salary for income bridge comparison.
  final double dailySalary;

  /// Type of leave (maternity or paternity).
  final LeaveType leaveType;

  /// Maximum APG daily amount (cap).
  final double apgDailyCap;

  const ParentalLeaveTimeline({
    super.key,
    required this.weeks,
    required this.dailySalary,
    this.leaveType = LeaveType.maternity,
    this.apgDailyCap = 220,
  });

  @override
  State<ParentalLeaveTimeline> createState() => _ParentalLeaveTimelineState();
}

class _ParentalLeaveTimelineState extends State<ParentalLeaveTimeline>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  final ScrollController _scrollController = ScrollController();
  int _highlightedWeek = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _progressAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color get _themeColor =>
      widget.leaveType == LeaveType.maternity
          ? const Color(0xFFE91E63) // warm pink
          : MintColors.info; // blue

  Color get _themeColorLight =>
      widget.leaveType == LeaveType.maternity
          ? const Color(0xFFFCE4EC)
          : const Color(0xFFE3F2FD);

  bool get _isCapped => widget.dailySalary > widget.apgDailyCap;

  double get _totalApg {
    var total = 0.0;
    for (final w in widget.weeks) {
      if (w.isActive) total += w.weeklyTotal;
    }
    return total;
  }

  double get _totalSalaryLoss {
    var total = 0.0;
    for (final w in widget.weeks) {
      if (w.isActive) total += (widget.dailySalary - w.dailyApg) * 7;
    }
    return max(0, total);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Chronologie du conge ${widget.leaveType == LeaveType.maternity ? 'maternite' : 'paternite'}. Total APG: ${_formatChf(_totalApg)}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.circular(20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                _buildHeader(),
                // Timeline weeks
                _buildTimelineScroll(),
                // Income bridge
                _buildIncomeBridge(),
                // Summary footer
                _buildSummaryFooter(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _themeColor.withValues(alpha: 0.12),
            _themeColorLight.withValues(alpha: 0.3),
            Colors.white,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: const Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _themeColor.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.circular(12),
            ),
            child: Icon(
              widget.leaveType == LeaveType.maternity
                  ? Icons.child_friendly
                  : Icons.family_restroom,
              color: _themeColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.leaveType == LeaveType.maternity
                      ? 'Conge maternite'
                      : 'Conge paternite',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.weeks.length} semaines  ·  Allocations APG',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Total badge
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, _) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _themeColor,
                  borderRadius: const BorderRadius.circular(12),
                ),
                child: Text(
                  _formatChf(_totalApg * _progressAnimation.value),
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineScroll() {
    return SizedBox(
      height: 180,
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, _) {
          return ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: widget.weeks.length,
            itemBuilder: (context, index) {
              final week = widget.weeks[index];
              final isHighlighted = _highlightedWeek == index;
              final animProgress =
                  (_progressAnimation.value * widget.weeks.length - index)
                      .clamp(0.0, 1.0);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _highlightedWeek = isHighlighted ? -1 : index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 80,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? _themeColor.withValues(alpha: 0.1)
                        : MintColors.surface,
                    borderRadius: const BorderRadius.circular(14),
                    border: Border.all(
                      color: isHighlighted
                          ? _themeColor
                          : MintColors.lightBorder,
                      width: isHighlighted ? 2 : 1,
                    ),
                  ),
                  child: Opacity(
                    opacity: animProgress,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Week number
                        Text(
                          'S${week.weekNumber}',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isHighlighted
                                ? _themeColor
                                : MintColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Bar visualization
                        Expanded(
                          child: _buildWeekBar(week, animProgress),
                        ),

                        const SizedBox(height: 4),

                        // Daily amount
                        Text(
                          '${week.dailyApg.toStringAsFixed(0)}/j',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: week.isActive
                                ? _themeColor
                                : MintColors.textMuted,
                          ),
                        ),

                        // Running total
                        if (isHighlighted) ...[
                          const SizedBox(height: 2),
                          Text(
                            _formatChf(
                              widget.weeks
                                  .take(index + 1)
                                  .where((w) => w.isActive)
                                  .fold(0.0, (s, w) => s + w.weeklyTotal),
                            ),
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _themeColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWeekBar(ParentalLeaveWeek week, double animProgress) {
    final maxDaily = max(widget.dailySalary, widget.apgDailyCap);
    final barHeight = maxDaily > 0
        ? (week.dailyApg / maxDaily).clamp(0.0, 1.0) * animProgress
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullHeight = constraints.maxHeight;
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Background bar
            Container(
              width: 24,
              height: fullHeight,
              decoration: BoxDecoration(
                color: MintColors.surface,
                borderRadius: const BorderRadius.circular(6),
              ),
            ),
            // APG fill bar
            Container(
              width: 24,
              height: fullHeight * barHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _themeColor.withValues(alpha: 0.8),
                    _themeColor,
                  ],
                ),
                borderRadius: const BorderRadius.circular(6),
              ),
            ),
            // Cap line
            if (_isCapped)
              Positioned(
                bottom:
                    fullHeight * (widget.apgDailyCap / maxDaily).clamp(0.0, 1.0),
                child: Container(
                  width: 30,
                  height: 2,
                  decoration: BoxDecoration(
                    color: MintColors.warning,
                    borderRadius: const BorderRadius.circular(1),
                  ),
                ),
              ),
            // Milestone icons
            if (week.weekNumber == 1)
              Positioned(
                top: 0,
                child: Icon(
                  Icons.child_care,
                  size: 14,
                  color: _themeColor.withValues(alpha: 0.6),
                ),
              ),
            if (week.weekNumber == widget.weeks.length)
              Positioned(
                top: 0,
                child: Icon(
                  Icons.work_outline,
                  size: 14,
                  color: MintColors.textMuted.withValues(alpha: 0.6),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildIncomeBridge() {
    if (widget.dailySalary <= 0) return const SizedBox.shrink();

    final effectiveApg = widget.weeks.isNotEmpty
        ? widget.weeks.first.dailyApg
        : 0.0;
    final gap = widget.dailySalary - effectiveApg;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: const BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pont de revenu journalier',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // Salary bar
          _buildBridgeBar(
            label: 'Salaire',
            value: widget.dailySalary,
            maxValue: widget.dailySalary,
            color: MintColors.primary,
          ),
          const SizedBox(height: 8),
          // APG bar
          _buildBridgeBar(
            label: 'APG',
            value: effectiveApg,
            maxValue: widget.dailySalary,
            color: _themeColor,
          ),
          if (gap > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 14, color: MintColors.warning),
                const SizedBox(width: 6),
                Text(
                  'Ecart: ${_formatChf(gap)}/jour',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MintColors.warning,
                  ),
                ),
              ],
            ),
          ],
          if (_isCapped) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline,
                      size: 12, color: MintColors.warning),
                  const SizedBox(width: 6),
                  Text(
                    'Plafond APG: ${_formatChf(widget.apgDailyCap)}/jour',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBridgeBar({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
  }) {
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.white,
              color: color,
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value.toStringAsFixed(0),
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryFooter() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              label: 'Total APG',
              value: _formatChf(_totalApg),
              color: _themeColor,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: MintColors.lightBorder,
          ),
          Expanded(
            child: _buildSummaryItem(
              label: 'Perte de revenu',
              value: _totalSalaryLoss > 0
                  ? _formatChf(_totalSalaryLoss)
                  : 'Aucune',
              color: _totalSalaryLoss > 0
                  ? MintColors.warning
                  : MintColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
