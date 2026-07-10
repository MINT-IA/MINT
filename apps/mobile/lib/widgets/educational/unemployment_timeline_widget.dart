import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/unemployment_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  UNEMPLOYMENT TIMELINE WIDGET — Sprint S19
// ────────────────────────────────────────────────────────────
//
// Reusable vertical timeline widget for unemployment action steps.
// Each item shows a colored dot (by urgence), day badge,
// action title, description, connected by a dotted vertical line.
// ────────────────────────────────────────────────────────────

class UnemploymentTimelineWidget extends StatelessWidget {
  final List<UnemploymentTimelineItem> items;

  const UnemploymentTimelineWidget({
    super.key,
    required this.items,
  });

  /// Get color for urgency level.
  static Color _getUrgencyColor(UnemploymentTimelineUrgency urgence) {
    switch (urgence) {
      case UnemploymentTimelineUrgency.immediate:
        return MintColors.error;
      case UnemploymentTimelineUrgency.week1:
        return MintColors.warning;
      case UnemploymentTimelineUrgency.month1:
        return MintColors.info;
      case UnemploymentTimelineUrgency.months2to3:
        return MintColors.textMuted;
    }
  }

  /// Get label for urgency level.
  static String _getUrgencyLabel(
    S l10n,
    UnemploymentTimelineUrgency urgence,
  ) {
    switch (urgence) {
      case UnemploymentTimelineUrgency.immediate:
        return l10n.unemploymentTimelineUrgent;
      case UnemploymentTimelineUrgency.week1:
        return l10n.unemploymentTimelineWeek1;
      case UnemploymentTimelineUrgency.month1:
        return l10n.unemploymentTimelineMonth1;
      case UnemploymentTimelineUrgency.months2to3:
        return l10n.unemploymentTimelineMonths2to3;
    }
  }

  static String _actionLabel(S l10n, UnemploymentTimelineStep step) {
    switch (step) {
      case UnemploymentTimelineStep.registerOrp:
        return l10n.unemploymentTimelineRegisterOrpAction;
      case UnemploymentTimelineStep.fileClaim:
        return l10n.unemploymentTimelineFileClaimAction;
      case UnemploymentTimelineStep.waitingPeriodEnds:
        return l10n.unemploymentTimelineWaitingPeriodAction;
      case UnemploymentTimelineStep.budgetReview:
        return l10n.unemploymentTimelineBudgetAction;
      case UnemploymentTimelineStep.lppTransfer:
        return l10n.unemploymentTimelineLppAction;
      case UnemploymentTimelineStep.pause3a:
        return l10n.unemploymentTimelinePause3aAction;
      case UnemploymentTimelineStep.lamalReview:
        return l10n.unemploymentTimelineLamalAction;
      case UnemploymentTimelineStep.orpReview:
        return l10n.unemploymentTimelineOrpReviewAction;
    }
  }

  static String _descriptionLabel(S l10n, UnemploymentTimelineStep step) {
    switch (step) {
      case UnemploymentTimelineStep.registerOrp:
        return l10n.unemploymentTimelineRegisterOrpDescription;
      case UnemploymentTimelineStep.fileClaim:
        return l10n.unemploymentTimelineFileClaimDescription;
      case UnemploymentTimelineStep.waitingPeriodEnds:
        return l10n.unemploymentTimelineWaitingPeriodDescription;
      case UnemploymentTimelineStep.budgetReview:
        return l10n.unemploymentTimelineBudgetDescription;
      case UnemploymentTimelineStep.lppTransfer:
        return l10n.unemploymentTimelineLppDescription;
      case UnemploymentTimelineStep.pause3a:
        return l10n.unemploymentTimelinePause3aDescription;
      case UnemploymentTimelineStep.lamalReview:
        return l10n.unemploymentTimelineLamalDescription;
      case UnemploymentTimelineStep.orpReview:
        return l10n.unemploymentTimelineOrpReviewDescription;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                l10n.unemploymentTimelineTitle,
                style: MintTextStyles.labelMedium(color: MintColors.textMuted)
                    .copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                l10n.unemploymentTimelineUrgent,
                MintColors.error,
              ),
              _buildLegendItem(
                l10n.unemploymentTimelineWeek1,
                MintColors.warning,
              ),
              _buildLegendItem(
                l10n.unemploymentTimelineMonth1,
                MintColors.info,
              ),
              _buildLegendItem(
                l10n.unemploymentTimelineMonths2to3,
                MintColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Timeline items
          ...List.generate(items.length, (index) {
            final item = items[index];
            final isLast = index == items.length - 1;
            return _buildTimelineItem(l10n, item, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    S l10n,
    UnemploymentTimelineItem item,
    bool isLast,
  ) {
    final color = _getUrgencyColor(item.urgence);
    final urgencyLabel = _getUrgencyLabel(l10n, item.urgence);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: dot + line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Day badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.unemploymentTimelineDayBadge(item.jour),
                    style: MintTextStyles.labelSmall(color: color)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                // Dotted vertical line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: CustomPaint(
                        painter: _DottedLinePainter(
                            color: color.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right column: content
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border(
                  left: BorderSide(color: color, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _actionLabel(l10n, item.step),
                          style: MintTextStyles.bodyMedium(
                            color: MintColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          urgencyLabel,
                          style: MintTextStyles.micro(color: color).copyWith(
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _descriptionLabel(l10n, item.step),
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ).copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for dotted vertical line.
class _DottedLinePainter extends CustomPainter {
  final Color color;

  _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dashHeight = 4.0;
    const dashSpace = 4.0;
    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
