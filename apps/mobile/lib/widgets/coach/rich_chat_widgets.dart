import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/mint_custom_paint_mask.dart';

// ────────────────────────────────────────────────────────────
//  RICH CHAT WIDGETS — S56
// ────────────────────────────────────────────────────────────
//
//  Interactive, visual widgets that live INSIDE the coach chat.
//  Inspired by Cleo's inline insights: glass-like, transparent,
//  warm, with real data visualization.
//
//  The coach shows these after answering a question.
//  They replace flat text responses with living, visual answers.
// ────────────────────────────────────────────────────────────

/// A glass-style inline chart showing a value comparison.
/// Used for: "Combien à la retraite?" → shows today vs retirement.
class ChatComparisonCard extends StatelessWidget {
  final String title;
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  final double leftAmount;
  final double rightAmount;
  final String? narrative;
  final VoidCallback? onTap;

  const ChatComparisonCard({
    super.key,
    required this.title,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    required this.leftAmount,
    required this.rightAmount,
    this.narrative,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxAmount = max(leftAmount, rightAmount);
    final leftRatio = maxAmount > 0 ? leftAmount / maxAmount : 0.5;
    final rightRatio = maxAmount > 0 ? rightAmount / maxAmount : 0.5;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: MintSpacing.sm),
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.porcelaine.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: MintColors.border.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
            const SizedBox(height: MintSpacing.lg),

            // Left bar
            _buildBar(leftLabel, leftValue, leftRatio,
                MintColors.saugeClaire, MintColors.success),
            const SizedBox(height: MintSpacing.md),

            // Right bar
            _buildBar(rightLabel, rightValue, rightRatio,
                MintColors.pecheDouce, MintColors.corailDiscret),

            if (narrative != null) ...[
              const SizedBox(height: MintSpacing.lg),
              Text(
                narrative!,
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
              ),
            ],

            if (onTap != null) ...[
              const SizedBox(height: MintSpacing.md),
              Row(
                children: [
                  Text(
                    'Affiner',
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: MintColors.textPrimary),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBar(String label, String value, double ratio,
      Color barColor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: MintTextStyles.bodySmall(color: MintColors.textMuted)),
            Text(value,
                style: MintTextStyles.titleMedium(color: textColor)
                    .copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: MintColors.border.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(barColor.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }
}

/// An inline gauge showing a score or percentage.
/// Used for: "Mon score fitness?" → shows FRI with arc.
class ChatGaugeCard extends StatelessWidget {
  final String title;
  final double value;
  final double maxValue;
  final String valueLabel;
  final String? subtitle;
  final String? narrative;
  final VoidCallback? onTap;

  const ChatGaugeCard({
    super.key,
    required this.title,
    required this.value,
    this.maxValue = 100,
    required this.valueLabel,
    this.subtitle,
    this.narrative,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (value / maxValue).clamp(0.0, 1.0);
    final color = progress >= 0.7
        ? MintColors.success
        : progress >= 0.4
            ? MintColors.corailDiscret
            : MintColors.error;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: MintSpacing.sm),
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.porcelaine.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: MintColors.border.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
            const SizedBox(height: MintSpacing.lg),

            // Gauge
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Semantics(
                    label: 'Score gauge chart',
                    child: MintCustomPaintMask(
                      child: CustomPaint(
                        size: const Size(120, 120),
                        painter: _GaugePainter(
                          progress: progress,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        valueLabel,
                        style: MintTextStyles.displaySmall(color: color)
                            ,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: MintTextStyles.labelSmall(
                              color: MintColors.textMuted),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            if (narrative != null) ...[
              const SizedBox(height: MintSpacing.lg),
              Text(
                narrative!,
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = 0.75 * pi;
    const sweepTotal = 1.5 * pi;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      Paint()
        ..color = MintColors.border.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color;
}

/// A simple fact card for inline insights.
/// Used for: "Combien je paie d'impôts?" → single number + context.
class ChatFactCard extends StatelessWidget {
  final String eyebrow;
  final String value;
  final String description;
  final Color? accentColor;
  final VoidCallback? onTap;

  const ChatFactCard({
    super.key,
    required this.eyebrow,
    required this.value,
    required this.description,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? MintColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: MintSpacing.sm),
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.porcelaine.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: MintColors.border.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              value,
              style: MintTextStyles.displaySmall(color: color)
                  ,
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              description,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            if (onTap != null) ...[
              const SizedBox(height: MintSpacing.md),
              Row(
                children: [
                  Text(
                    'Explorer',
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: MintColors.textPrimary),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A comparison between two choices inline.
/// Used for: "Rente ou capital?" → two options side by side.
class ChatChoiceComparison extends StatelessWidget {
  final String title;
  final String leftTitle;
  final String leftValue;
  final String leftDescription;
  final String rightTitle;
  final String rightValue;
  final String rightDescription;
  final VoidCallback? onTap;

  const ChatChoiceComparison({
    super.key,
    required this.title,
    required this.leftTitle,
    required this.leftValue,
    required this.leftDescription,
    required this.rightTitle,
    required this.rightValue,
    required this.rightDescription,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: MintSpacing.sm),
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.porcelaine.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: MintColors.border.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
            const SizedBox(height: MintSpacing.lg),
            Row(
              children: [
                Expanded(child: _buildSide(
                  leftTitle, leftValue, leftDescription,
                  MintColors.saugeClaire,
                )),
                Container(
                  width: 1,
                  height: 80,
                  margin: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
                  color: MintColors.border.withValues(alpha: 0.2),
                ),
                Expanded(child: _buildSide(
                  rightTitle, rightValue, rightDescription,
                  MintColors.pecheDouce,
                )),
              ],
            ),
            if (onTap != null) ...[
              const SizedBox(height: MintSpacing.lg),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Comparer en détail',
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 14, color: MintColors.textPrimary),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSide(String title, String value, String desc, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted)),
          const SizedBox(height: 6),
          Text(value,
              style: MintTextStyles.titleMedium()
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(desc,
              style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
        ],
      ),
    );
  }
}
