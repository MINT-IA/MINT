import 'package:flutter/material.dart';
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
  static Color _getUrgencyColor(String urgence) {
    switch (urgence) {
      case 'immediate':
        return MintColors.error;
      case 'semaine1':
        return MintColors.warning;
      case 'mois1':
        return MintColors.info;
      case 'mois3':
        return MintColors.textMuted;
      default:
        return MintColors.textMuted;
    }
  }

  /// Get label for urgency level.
  static String _getUrgencyLabel(String urgence) {
    switch (urgence) {
      case 'immediate':
        return 'Urgent';
      case 'semaine1':
        return 'Semaine 1';
      case 'mois1':
        return 'Mois 1';
      case 'mois3':
        return 'Mois 2-3';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'PLAN D\'ACTION',
                style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegendItem('Urgent', MintColors.error),
              _buildLegendItem('Semaine 1', MintColors.warning),
              _buildLegendItem('Mois 1', MintColors.info),
              _buildLegendItem('Mois 2-3', MintColors.textMuted),
            ],
          ),
          const SizedBox(height: 20),
          // Timeline items
          ...List.generate(items.length, (index) {
            final item = items[index];
            final isLast = index == items.length - 1;
            return _buildTimelineItem(item, isLast);
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

  Widget _buildTimelineItem(UnemploymentTimelineItem item, bool isLast) {
    final color = _getUrgencyColor(item.urgence);
    final urgencyLabel = _getUrgencyLabel(item.urgence);

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
                    'J${item.jour}',
                    style: MintTextStyles.labelSmall(color: color).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                // Dotted vertical line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: CustomPaint(
                        painter: _DottedLinePainter(color: color.withValues(alpha: 0.3)),
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
                          item.action,
                          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
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
                          style: MintTextStyles.micro(color: color).copyWith(fontWeight: FontWeight.w600, fontStyle: FontStyle.normal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
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
