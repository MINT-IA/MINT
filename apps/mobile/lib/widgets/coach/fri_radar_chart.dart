import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  FRI RADAR CHART — Phase 5 / Dashboard Assembly
// ────────────────────────────────────────────────────────────
//
// Spider/radar chart pour les 4 sous-scores du FRI :
//   L (Liquidité)   0-25
//   F (Fiscal)      0-25
//   R (Retraite)    0-25
//   S (Structurel)  0-25
//
// CustomPainter avec grille concentrique, axes, polygone rempli.
//
// Outil éducatif — ne constitue pas un conseil financier (LSFin).
// ────────────────────────────────────────────────────────────

class FriRadarChart extends StatelessWidget {
  final double liquidity;
  final double fiscal;
  final double retirement;
  final double structural;
  final double size;

  const FriRadarChart({
    super.key,
    required this.liquidity,
    required this.fiscal,
    required this.retirement,
    required this.structural,
    this.size = 200,
  });

  double get total => liquidity + fiscal + retirement + structural;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Résilience financière',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${total.round()} / 100',
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _RadarPainter(
                  values: [liquidity, fiscal, retirement, structural],
                  maxValue: 25,
                  gridColor: MintColors.border,
                  fillColor: MintColors.primary.withAlpha(50),
                  strokeColor: MintColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final items = [
      _LegendItem('L – Liquidité', liquidity),
      _LegendItem('F – Fiscal', fiscal),
      _LegendItem('R – Retraite', retirement),
      _LegendItem('S – Structurel', structural),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${item.value.round()}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _LegendItem {
  final String label;
  final double value;
  const _LegendItem(this.label, this.value);
}

// ────────────────────────────────────────────────────────────
//  CUSTOM PAINTER — Spider / Radar
// ────────────────────────────────────────────────────────────

class _RadarPainter extends CustomPainter {
  final List<double> values; // 4 values
  final double maxValue;
  final Color gridColor;
  final Color fillColor;
  final Color strokeColor;

  _RadarPainter({
    required this.values,
    required this.maxValue,
    required this.gridColor,
    required this.fillColor,
    required this.strokeColor,
  });

  static const _labels = ['L', 'F', 'R', 'S'];
  static const _sides = 4;
  // Start from top (-π/2) and go clockwise
  static const _startAngle = -pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 24; // padding for labels

    // Grid paint
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw concentric grid polygons (5 levels: 5, 10, 15, 20, 25)
    for (int level = 1; level <= 5; level++) {
      final r = radius * level / 5;
      final path = Path();
      for (int i = 0; i < _sides; i++) {
        final angle = _startAngle + (2 * pi * i / _sides);
        final point = Offset(
          center.dx + r * cos(angle),
          center.dy + r * sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw axes
    for (int i = 0; i < _sides; i++) {
      final angle = _startAngle + (2 * pi * i / _sides);
      final end = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(center, end, gridPaint);
    }

    // Draw data polygon
    final dataPath = Path();
    for (int i = 0; i < _sides; i++) {
      final angle = _startAngle + (2 * pi * i / _sides);
      final ratio = (values[i] / maxValue).clamp(0.0, 1.0);
      final point = Offset(
        center.dx + radius * ratio * cos(angle),
        center.dy + radius * ratio * sin(angle),
      );
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    // Fill
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    // Stroke
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw dots at data points
    for (int i = 0; i < _sides; i++) {
      final angle = _startAngle + (2 * pi * i / _sides);
      final ratio = (values[i] / maxValue).clamp(0.0, 1.0);
      final point = Offset(
        center.dx + radius * ratio * cos(angle),
        center.dy + radius * ratio * sin(angle),
      );
      canvas.drawCircle(
        point,
        4,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.fill,
      );
    }

    // Draw axis labels
    final textStyle = TextStyle(
      color: MintColors.greyDark,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    for (int i = 0; i < _sides; i++) {
      final angle = _startAngle + (2 * pi * i / _sides);
      final labelRadius = radius + 16;
      final point = Offset(
        center.dx + labelRadius * cos(angle),
        center.dy + labelRadius * sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(text: _labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(point.dx - tp.width / 2, point.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.values != values || old.maxValue != maxValue;
}
