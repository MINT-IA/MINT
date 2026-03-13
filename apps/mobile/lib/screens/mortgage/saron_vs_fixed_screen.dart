import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/mortgage_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;

/// Ecran comparateur SARON vs Taux fixe.
///
/// Affiche 3 courbes (fixe, SARON stable, SARON hausse) avec CustomPainter
/// et les couts totaux par option.
/// Base legale : pratique hypothecaire suisse.
class SaronVsFixedScreen extends StatefulWidget {
  const SaronVsFixedScreen({super.key});

  @override
  State<SaronVsFixedScreen> createState() => _SaronVsFixedScreenState();
}

class _SaronVsFixedScreenState extends State<SaronVsFixedScreen> {
  double _montantHypothecaire = 800000;
  int _dureeAns = 10;

  static const _dureesDisponibles = [5, 7, 10, 15];

  SaronVsFixedResult get _result => SaronVsFixedCalculator.compare(
        montantHypothecaire: _montantHypothecaire,
        dureeAns: _dureeAns,
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      backgroundColor: MintColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.primary,
            foregroundColor: MintColors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'SARON VS FIXE',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: MintColors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Chiffre choc
                _buildChiffreChocCard(result),
                const SizedBox(height: 24),

                // Graphique
                _buildChartSection(result),
                const SizedBox(height: 24),

                // Sliders
                _buildSlidersSection(),
                const SizedBox(height: 24),

                // Detail couts
                _buildCostComparisonSection(result),
                const SizedBox(height: 24),

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: 12),

                // Source legale
                Text(
                  'Source : taux indicatifs marche suisse 2026. Ne constitue pas un conseil hypothecaire.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: MintColors.textMuted,
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChocCard(SaronVsFixedResult result) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.compare_arrows, color: MintColors.info, size: 40),
          const SizedBox(height: 12),
          Text(
            'CHF ${formatChf(result.economieSaronStable.abs())}',
            style: GoogleFonts.montserrat(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: MintColors.info,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.chiffreChocTexte,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(SaronVsFixedResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COUT CUMULE SUR $_dureeAns ANS',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: CustomPaint(
              size: Size.infinite,
              painter: _MortgageChartPainter(
                fixeData: result.fixe.annualData,
                saronStableData: result.saronStable.annualData,
                saronHausseData: result.saronHausse.annualData,
                duree: _dureeAns,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legende
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(MintColors.primary, 'Fixe'),
              const SizedBox(width: 16),
              _buildLegendItem(MintColors.success, 'SARON stable'),
              const SizedBox(width: 16),
              _buildLegendItem(MintColors.error, 'SARON hausse'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: MintColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildSlidersSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PARAMETRES',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Montant hypothecaire
          _buildSliderRow(
            label: 'Montant hypothecaire',
            value: _montantHypothecaire,
            min: 200000,
            max: 2000000,
            divisions: 36,
            format: 'CHF ${formatChf(_montantHypothecaire)}',
            onChanged: (v) => setState(() => _montantHypothecaire = v),
          ),
          const SizedBox(height: 16),

          // Duree
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Duree',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: MintColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _dureeAns,
                    items: _dureesDisponibles
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d ans',
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _dureeAns = v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String format,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
              ),
            ),
            Text(
              format,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: MintColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildCostComparisonSection(SaronVsFixedResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPARAISON DES COUTS',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          _buildCostRow(
            label: result.fixe.label,
            taux: '${(result.fixe.tauxInitial * 100).toStringAsFixed(2)}%',
            total: 'CHF ${formatChf(result.fixe.coutTotal)}',
            color: MintColors.textPrimary,
          ),
          const Divider(height: 20),
          _buildCostRow(
            label: result.saronStable.label,
            taux:
                '${(result.saronStable.tauxInitial * 100).toStringAsFixed(2)}%',
            total: 'CHF ${formatChf(result.saronStable.coutTotal)}',
            color: MintColors.success,
          ),
          const Divider(height: 20),
          _buildCostRow(
            label: result.saronHausse.label,
            taux:
                '${(result.saronHausse.tauxInitial * 100).toStringAsFixed(2)}% initial',
            total: 'CHF ${formatChf(result.saronHausse.coutTotal)}',
            color: MintColors.error,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: MintColors.textMuted, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Le SARON hausse simule +0.25%/an les 3 premieres annees. '
                    'En realite, l\'evolution depend de la politique monetaire de la BNS.',
                    style: TextStyle(
                      fontSize: 11,
                      color: MintColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow({
    required String label,
    required String taux,
    required String total,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                'Taux : $taux',
                style: const TextStyle(
                  fontSize: 11,
                  color: MintColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Text(
          total,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: MintColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              disclaimer,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: MintColors.deepOrange,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chart Painter — 3 courbes cout cumule
// ─────────────────────────────────────────────────────────────────────────────

class _MortgageChartPainter extends CustomPainter {
  final List<MortgageYearPoint> fixeData;
  final List<MortgageYearPoint> saronStableData;
  final List<MortgageYearPoint> saronHausseData;
  final int duree;

  _MortgageChartPainter({
    required this.fixeData,
    required this.saronStableData,
    required this.saronHausseData,
    required this.duree,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fixeData.isEmpty) return;

    const leftPadding = 60.0;
    const bottomPadding = 24.0;
    const topPadding = 8.0;
    const rightPadding = 16.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - bottomPadding - topPadding;

    // Find max value across all series
    double maxVal = 0;
    for (final p in fixeData) {
      maxVal = max(maxVal, p.coutCumule);
    }
    for (final p in saronStableData) {
      maxVal = max(maxVal, p.coutCumule);
    }
    for (final p in saronHausseData) {
      maxVal = max(maxVal, p.coutCumule);
    }
    maxVal *= 1.1; // 10% padding

    // Grid lines
    final gridPaint = Paint()
      ..color = MintColors.lightBorder
      ..strokeWidth = 1;

    const gridSteps = 4;
    for (int i = 0; i <= gridSteps; i++) {
      final y = topPadding + chartHeight * (1 - i / gridSteps);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      // Y-axis labels
      final val = maxVal * i / gridSteps;
      final label = '${(val / 1000).toStringAsFixed(0)}k';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 10, color: MintColors.textMuted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 8, y - tp.height / 2));
    }

    // X-axis labels
    for (int i = 0; i < duree; i++) {
      final x = leftPadding + chartWidth * i / (duree - 1);
      if (i % max(1, duree ~/ 5) == 0 || i == duree - 1) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(fontSize: 10, color: MintColors.textMuted),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, size.height - 16));
      }
    }

    // Draw curves
    _drawCurve(canvas, fixeData, MintColors.primary, maxVal, chartWidth,
        chartHeight, leftPadding, topPadding);
    _drawCurve(canvas, saronStableData, MintColors.success, maxVal,
        chartWidth, chartHeight, leftPadding, topPadding);
    _drawCurve(canvas, saronHausseData, MintColors.error, maxVal,
        chartWidth, chartHeight, leftPadding, topPadding);
  }

  void _drawCurve(
    Canvas canvas,
    List<MortgageYearPoint> data,
    Color color,
    double maxVal,
    double chartWidth,
    double chartHeight,
    double leftPadding,
    double topPadding,
  ) {
    if (data.isEmpty || maxVal <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = leftPadding + chartWidth * i / (data.length - 1);
      final y = topPadding +
          chartHeight * (1 - data[i].coutCumule / maxVal);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // End dot
    if (data.isNotEmpty) {
      final lastX =
          leftPadding + chartWidth * (data.length - 1) / (data.length - 1);
      final lastY = topPadding +
          chartHeight * (1 - data.last.coutCumule / maxVal);
      canvas.drawCircle(
        Offset(lastX, lastY),
        4,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MortgageChartPainter oldDelegate) =>
      oldDelegate.duree != duree ||
      oldDelegate.fixeData != fixeData;
}
