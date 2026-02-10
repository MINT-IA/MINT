import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/retirement_service.dart';

// ────────────────────────────────────────────────────────────
//  BUDGET GAUGE WIDGET — Sprint S21
// ────────────────────────────────────────────────────────────
//
// Circular gauge showing taux de remplacement:
//   Green zone:  60-80%+
//   Orange zone: 40-60%
//   Red zone:    <40%
//   Center: percentage number
// ────────────────────────────────────────────────────────────

class BudgetGaugeWidget extends StatelessWidget {
  final double revenus;
  final double depenses;
  final double tauxRemplacement;

  const BudgetGaugeWidget({
    super.key,
    required this.revenus,
    required this.depenses,
    required this.tauxRemplacement,
  });

  Color get _gaugeColor {
    if (tauxRemplacement >= 60) return MintColors.success;
    if (tauxRemplacement >= 40) return MintColors.warning;
    return MintColors.error;
  }

  String get _gaugeLabel {
    if (tauxRemplacement >= 80) return 'Excellent';
    if (tauxRemplacement >= 60) return 'Suffisant';
    if (tauxRemplacement >= 40) return 'Insuffisant';
    return 'Critique';
  }

  @override
  Widget build(BuildContext context) {
    final solde = revenus - depenses;
    final isSurplus = solde >= 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          // ── Gauge ──────────────────────────────────────
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _GaugePainter(
                percentage: tauxRemplacement.clamp(0, 120),
                color: _gaugeColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${tauxRemplacement.toStringAsFixed(0)}%',
                      style: GoogleFonts.montserrat(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: _gaugeColor,
                      ),
                    ),
                    Text(
                      _gaugeLabel,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _gaugeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Taux de remplacement',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Objectif : 60-80% du revenu pre-retraite',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),

          // ── Revenus vs Depenses bars ──────────────────
          _buildComparisonBar(
            label: 'Revenus retraite',
            value: revenus,
            maxValue: max(revenus, depenses),
            color: MintColors.success,
          ),
          const SizedBox(height: 10),
          _buildComparisonBar(
            label: 'Depenses mensuelles',
            value: depenses,
            maxValue: max(revenus, depenses),
            color: MintColors.error,
          ),
          const SizedBox(height: 16),

          // ── Solde ──────────────────────────────────────
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSurplus ? 'Excedent mensuel' : 'Deficit mensuel',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                '${isSurplus ? '+' : ''}${RetirementService.formatChf(solde)}',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isSurplus ? MintColors.success : MintColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBar({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
  }) {
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
            Text(
              RetirementService.formatChf(value),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: MintColors.appleSurface,
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  CUSTOM GAUGE PAINTER
// ────────────────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  final double percentage;
  final Color color;

  _GaugePainter({
    required this.percentage,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;

    // Background arc
    final bgPaint = Paint()
      ..color = MintColors.appleSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    const startAngle = 0.75 * pi;
    const sweepAngle = 1.5 * pi;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Value arc
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final valueSweep = sweepAngle * (percentage / 120).clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      valueSweep,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.color != color;
  }
}
