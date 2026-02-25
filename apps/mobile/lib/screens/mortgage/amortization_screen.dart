import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/mortgage_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;

/// Ecran de comparaison amortissement direct vs indirect.
///
/// Affiche 2 courbes (dette restante + capital 3a) et le cout net par option.
/// Base legale : OPP3 (versements 3a), pratique hypothecaire suisse.
class AmortizationScreen extends StatefulWidget {
  const AmortizationScreen({super.key});

  @override
  State<AmortizationScreen> createState() => _AmortizationScreenState();
}

class _AmortizationScreenState extends State<AmortizationScreen> {
  double _montantHypothecaire = 700000;
  double _tauxInteret = 0.025;
  int _dureeAns = 15;
  double _tauxMarginal = 0.30;

  AmortizationResult get _result => AmortizationCalculator.compare(
        montantHypothecaire: _montantHypothecaire,
        tauxInteret: _tauxInteret,
        dureeAns: _dureeAns,
        tauxMarginal: _tauxMarginal,
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
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'DIRECT VS INDIRECT',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Intro pedagogique
                _buildIntroCard(),
                const SizedBox(height: 24),

                // Chiffre choc
                _buildChiffreChocCard(result),
                const SizedBox(height: 24),

                // Graphique
                _buildChartSection(result),
                const SizedBox(height: 24),

                // Sliders
                _buildSlidersSection(),
                const SizedBox(height: 24),

                // Comparaison detaillee
                _buildComparisonSection(result),
                const SizedBox(height: 24),

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: 12),

                // Source legale
                Text(
                  'Source : OPP3 (pilier 3a), pratique hypothecaire suisse. '
                  'Plafond 3a salarie 2026 : CHF 7\'258.',
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

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amortissement : direct ou indirect ?',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'En Suisse, l\'amortissement indirect est une specificite unique : '
            'au lieu de rembourser directement la dette, tu verses dans un '
            'pilier 3a nanti. Tu beneficies d\'une double deduction fiscale '
            '(interets + versement 3a) et ton capital reste investi.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMethodCard(
                  title: 'Direct',
                  description: 'Tu rembourses la dette chaque annee. '
                      'Les interets diminuent progressivement.',
                  icon: Icons.trending_down,
                  color: MintColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMethodCard(
                  title: 'Indirect',
                  description: 'Tu verses dans un 3a nanti. '
                      'Double deduction fiscale.',
                  icon: Icons.savings_outlined,
                  color: MintColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              color: MintColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChocCard(AmortizationResult result) {
    final isPositive = result.chiffreChocPositif;
    final color = isPositive ? MintColors.success : MintColors.info;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(Icons.compare_arrows, color: color, size: 40),
          const SizedBox(height: 12),
          Text(
            'CHF ${formatChf(result.economieIndirect.abs())}',
            style: GoogleFonts.montserrat(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: color,
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

  Widget _buildChartSection(AmortizationResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EVOLUTION SUR $_dureeAns ANS',
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
              painter: _AmortizationChartPainter(
                directPlan: result.directPlan,
                indirectPlan: result.indirectPlan,
                montantInitial: _montantHypothecaire,
                duree: _dureeAns,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legende
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(MintColors.info, 'Dette (direct)'),
              const SizedBox(width: 12),
              _buildLegendItem(MintColors.textPrimary, 'Dette (indirect)'),
              const SizedBox(width: 12),
              _buildLegendItem(MintColors.success, 'Capital 3a'),
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
          style: const TextStyle(fontSize: 10, color: MintColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildSlidersSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const SizedBox(height: 12),

          // Taux d'interet
          _buildSliderRow(
            label: 'Taux d\'interet',
            value: _tauxInteret,
            min: 0.01,
            max: 0.05,
            divisions: 40,
            format: '${(_tauxInteret * 100).toStringAsFixed(2)}%',
            onChanged: (v) => setState(() => _tauxInteret = v),
          ),
          const SizedBox(height: 12),

          // Duree
          _buildSliderRow(
            label: 'Duree',
            value: _dureeAns.toDouble(),
            min: 5,
            max: 30,
            divisions: 25,
            format: '$_dureeAns ans',
            onChanged: (v) => setState(() => _dureeAns = v.round()),
          ),
          const SizedBox(height: 12),

          // Taux marginal
          _buildSliderRow(
            label: 'Taux marginal estime',
            value: _tauxMarginal,
            min: 0.15,
            max: 0.45,
            divisions: 30,
            format: '${(_tauxMarginal * 100).toStringAsFixed(1)}%',
            onChanged: (v) => setState(() => _tauxMarginal = v),
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
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
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
          activeThumbColor: MintColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildComparisonSection(AmortizationResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPARAISON DETAILLEE',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Direct
          _buildComparisonCard(
            title: 'Amortissement direct',
            color: MintColors.info,
            rows: [
              _compRow('Total interets payes',
                  'CHF ${formatChf(result.totalInteretsDirect)}'),
              _compRow('Cout net total',
                  'CHF ${formatChf(result.coutNetDirect)}'),
            ],
          ),
          const SizedBox(height: 16),

          // Indirect
          _buildComparisonCard(
            title: 'Amortissement indirect',
            color: MintColors.success,
            rows: [
              _compRow('Total interets payes',
                  'CHF ${formatChf(result.totalInteretsIndirect)}'),
              _compRow('Capital 3a accumule',
                  'CHF ${formatChf(result.capital3aFinal)}'),
              _compRow('Cout net total',
                  'CHF ${formatChf(result.coutNetIndirect)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required Color color,
    required List<Widget> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _compRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              disclaimer,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.orange.shade800,
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
// Chart Painter — Direct vs Indirect
// ─────────────────────────────────────────────────────────────────────────────

class _AmortizationChartPainter extends CustomPainter {
  final List<AmortizationYearPoint> directPlan;
  final List<AmortizationYearPoint> indirectPlan;
  final double montantInitial;
  final int duree;

  _AmortizationChartPainter({
    required this.directPlan,
    required this.indirectPlan,
    required this.montantInitial,
    required this.duree,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (directPlan.isEmpty) return;

    const leftPadding = 60.0;
    const bottomPadding = 24.0;
    const topPadding = 8.0;
    const rightPadding = 16.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - bottomPadding - topPadding;

    // Max value = initial mortgage
    final maxVal = montantInitial * 1.1;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    const gridSteps = 4;
    for (int i = 0; i <= gridSteps; i++) {
      final y = topPadding + chartHeight * (1 - i / gridSteps);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      final val = maxVal * i / gridSteps;
      final label = '${(val / 1000).toStringAsFixed(0)}k';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF86868B)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 8, y - tp.height / 2));
    }

    // X-axis labels
    final dataLen = directPlan.length;
    for (int i = 0; i < dataLen; i++) {
      if (i % max(1, dataLen ~/ 5) == 0 || i == dataLen - 1) {
        final x = leftPadding + chartWidth * i / max(1, dataLen - 1);
        final tp = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF86868B)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, size.height - 16));
      }
    }

    // Draw debt curves
    _drawCurve(canvas, directPlan.map((p) => p.detteRestante).toList(),
        const Color(0xFF007AFF), maxVal, chartWidth, chartHeight, leftPadding, topPadding);
    _drawCurve(canvas, indirectPlan.map((p) => p.detteRestante).toList(),
        const Color(0xFF1D1D1F), maxVal, chartWidth, chartHeight, leftPadding, topPadding);

    // Draw 3a capital curve
    _drawCurve(canvas, indirectPlan.map((p) => p.capital3a).toList(),
        const Color(0xFF24B14D), maxVal, chartWidth, chartHeight, leftPadding, topPadding);
  }

  void _drawCurve(
    Canvas canvas,
    List<double> values,
    Color color,
    double maxVal,
    double chartWidth,
    double chartHeight,
    double leftPadding,
    double topPadding,
  ) {
    if (values.isEmpty || maxVal <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final len = values.length;
    for (int i = 0; i < len; i++) {
      final x = leftPadding + chartWidth * i / max(1, len - 1);
      final y = topPadding + chartHeight * (1 - values[i] / maxVal);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // End dot
    if (values.isNotEmpty) {
      final lastX = leftPadding + chartWidth;
      final lastY =
          topPadding + chartHeight * (1 - values.last / maxVal);
      canvas.drawCircle(
        Offset(lastX, lastY),
        4,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AmortizationChartPainter oldDelegate) =>
      oldDelegate.duree != duree ||
      oldDelegate.montantInitial != montantInitial;
}
