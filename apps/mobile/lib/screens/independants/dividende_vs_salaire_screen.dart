import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/independants_service.dart';

// ────────────────────────────────────────────────────────────
//  DIVIDENDE VS SALAIRE SCREEN — Sprint S18
// ────────────────────────────────────────────────────────────
//
// Salary vs dividend split optimizer for SA/Sarl.
// Custom painted curve chart showing total charge vs split ratio.
// Requalification risk alert if salary < 60%.
// ────────────────────────────────────────────────────────────

class DividendeVsSalaireScreen extends StatefulWidget {
  const DividendeVsSalaireScreen({super.key});

  @override
  State<DividendeVsSalaireScreen> createState() =>
      _DividendeVsSalaireScreenState();
}

class _DividendeVsSalaireScreenState extends State<DividendeVsSalaireScreen> {
  double _benefice = 200000;
  double _partSalairePct = 70;
  double _tauxMarginal = 0.30;
  DividendeVsSalaireResult? _result;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    setState(() {
      _result = IndependantsService.calculateDividendeVsSalaire(
        _benefice,
        _partSalairePct,
        _tauxMarginal,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(),
                const SizedBox(height: 20),
                _buildBeneficeSlider(),
                const SizedBox(height: 20),
                _buildPartSalaireSlider(),
                const SizedBox(height: 20),
                _buildTauxSlider(),
                const SizedBox(height: 24),
                if (_result != null) ...[
                  _buildChiffreChoc(),
                  const SizedBox(height: 24),
                  if (_result!.requalificationRisk) ...[
                    _buildRequalificationAlert(),
                    const SizedBox(height: 20),
                  ],
                  _buildResultSection(),
                  const SizedBox(height: 24),
                  _buildCurveChart(),
                  const SizedBox(height: 24),
                  _buildEducation(),
                  const SizedBox(height: 24),
                ],
                _buildDisclaimer(),
                const SizedBox(height: 16),
                _buildCantonalDisclaimer(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: MintColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
        title: Text(
          'Dividende vs Salaire',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MintColors.primary,
                MintColors.primary.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Si tu possedes une SA ou Sarl, tu peux te verser une '
              'combinaison de salaire et de dividendes. Le dividende '
              'est impose a 50% (participation qualifiante) et echappe '
              'aux cotisations AVS. Trouve le split optimal.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliders ────────────────────────────────────────────────

  Widget _buildBeneficeSlider() {
    return _buildSliderCard(
      title: 'Benefice total',
      valueLabel: IndependantsService.formatChf(_benefice),
      minLabel: 'CHF 0',
      maxLabel: "CHF 500'000",
      value: _benefice,
      min: 0,
      max: 500000,
      divisions: 500,
      onChanged: (v) {
        _benefice = v;
        _calculate();
      },
    );
  }

  Widget _buildPartSalaireSlider() {
    return _buildSliderCard(
      title: 'Part salaire',
      valueLabel: '${_partSalairePct.toInt()}%',
      minLabel: '0%',
      maxLabel: '100%',
      value: _partSalairePct,
      min: 0,
      max: 100,
      divisions: 100,
      onChanged: (v) {
        _partSalairePct = v;
        _calculate();
      },
    );
  }

  Widget _buildTauxSlider() {
    return _buildSliderCard(
      title: 'Taux marginal d\'imposition',
      valueLabel: '${(_tauxMarginal * 100).toStringAsFixed(0)}%',
      minLabel: '10%',
      maxLabel: '45%',
      value: _tauxMarginal * 100,
      min: 10,
      max: 45,
      divisions: 35,
      onChanged: (v) {
        _tauxMarginal = v / 100;
        _calculate();
      },
    );
  }

  Widget _buildSliderCard({
    required String title,
    required String valueLabel,
    required String minLabel,
    required String maxLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                valueLabel,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withValues(alpha: 0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text(maxLabel, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Chiffre Choc ───────────────────────────────────────────

  Widget _buildChiffreChoc() {
    final r = _result!;
    final saving = r.economie;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: saving > 0 ? MintColors.success : MintColors.appleSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            IndependantsService.formatChf(saving),
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: saving > 0 ? Colors.white : MintColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            saving > 0
                ? 'Le split optimal te fait economiser '
                  '${IndependantsService.formatChf(saving)}/an '
                  'par rapport a 100% salaire'
                : 'Ajuste le split pour trouver une economie',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: saving > 0
                  ? Colors.white.withValues(alpha: 0.9)
                  : MintColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Requalification Alert ──────────────────────────────────

  Widget _buildRequalificationAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: MintColors.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risque de requalification',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Si la part salaire est inferieure a ~60% du benefice, '
                  'l\'administration fiscale peut requalifier une partie '
                  'des dividendes en salaire (pratique cantonale variable). '
                  'Cela entraine des cotisations AVS retroactives.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.error.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Result Section ─────────────────────────────────────────

  Widget _buildResultSection() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          _buildResultRow(
            'Part salaire',
            IndependantsService.formatChf(r.partSalaire),
            subtitle: '${_partSalairePct.toInt()}% du benefice',
          ),
          const SizedBox(height: 12),
          _buildResultRow(
            'Part dividende',
            IndependantsService.formatChf(r.partDividende),
            subtitle: '${(100 - _partSalairePct).toInt()}% du benefice',
          ),
          const Divider(height: 24),
          _buildResultRow(
            'Charge sur salaire',
            IndependantsService.formatChf(r.chargeSalaire),
            color: MintColors.error,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Charge sur dividende',
            IndependantsService.formatChf(r.chargeDividende),
            color: MintColors.info,
          ),
          const Divider(height: 24),
          _buildResultRow(
            'Charge totale (split)',
            IndependantsService.formatChf(r.chargeTotal),
            bold: true,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Charge si 100% salaire',
            IndependantsService.formatChf(r.chargeToutSalaire),
            color: MintColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(
    String label,
    String value, {
    Color? color,
    String? subtitle,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                color: color ?? MintColors.textSecondary,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted),
              ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: bold ? MintColors.primary : (color ?? MintColors.textPrimary),
          ),
        ),
      ],
    );
  }

  // ── Curve Chart ────────────────────────────────────────────

  Widget _buildCurveChart() {
    final r = _result!;
    if (r.sensitivity.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'CHARGE TOTALE PAR SPLIT',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 200,
            child: CustomPaint(
              size: Size.infinite,
              painter: _ChargeCurvePainter(
                points: r.sensitivity,
                currentPct: _partSalairePct,
                optimalPct: r.optimalSplitPct,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Axis labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0% salaire', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text('100% salaire', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            children: [
              _buildChartLegend(MintColors.primary, 'Charge totale'),
              const SizedBox(width: 16),
              _buildChartLegend(MintColors.success, 'Split optimal'),
              const SizedBox(width: 16),
              _buildChartLegend(MintColors.info, 'Position actuelle'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
        ),
      ],
    );
  }

  // ── Education ──────────────────────────────────────────────

  Widget _buildEducation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'A RETENIR',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEduCard(
          Icons.account_balance_outlined,
          'Impot sur le benefice',
          'Rappelle-toi que le benefice distribue en dividende est '
          'impose d\'abord au niveau de la societe (impot sur le benefice), '
          'puis au niveau personnel (double imposition economique).',
        ),
        _buildEduCard(
          Icons.people_outline,
          'AVS uniquement sur le salaire',
          'Les cotisations AVS (environ 12.5% au total) ne s\'appliquent '
          'qu\'a la part salaire. Le dividende echappe aux charges sociales, '
          'd\'ou l\'interet d\'optimiser le split.',
        ),
        _buildEduCard(
          Icons.gavel_outlined,
          'Pratique cantonale',
          'Les autorites fiscales surveillent les distributions excessives '
          'de dividendes. Un salaire "conforme au marche" est attendu. '
          'La limite varie selon les cantons.',
        ),
      ],
    );
  }

  Widget _buildEduCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.appleSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: MintColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Disclaimers ────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Simulation simplifiee. L\'impot sur le benefice de la societe, '
              'les deductions personnelles et les regles cantonales ne sont '
              'pas integres dans ce calcul. Consulte un\u00B7e specialiste '
              'pour une analyse complete.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.orange.shade800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCantonalDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'L\'optimisation fiscale depend de la pratique cantonale. '
        'Les seuils de requalification varient d\'un canton a l\'autre.',
        style: GoogleFonts.inter(
          fontSize: 11,
          color: MintColors.textMuted,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  CUSTOM PAINTER — Charge curve
// ════════════════════════════════════════════════════════════

class _ChargeCurvePainter extends CustomPainter {
  final List<DividendeSplitPoint> points;
  final double currentPct;
  final double optimalPct;

  _ChargeCurvePainter({
    required this.points,
    required this.currentPct,
    required this.optimalPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxCharge =
        points.map((p) => p.chargeTotal).reduce(max);
    if (maxCharge <= 0) return;

    final paint = Paint()
      ..color = MintColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          MintColors.primary.withValues(alpha: 0.15),
          MintColors.primary.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = (points[i].partSalairePct / 100) * size.width;
      final y = size.height - (points[i].chargeTotal / maxCharge) * size.height * 0.9;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw optimal point
    final optimalX = (optimalPct / 100) * size.width;
    final optimalPoint = points.firstWhere(
      (p) => p.partSalairePct == optimalPct,
      orElse: () => points.first,
    );
    final optimalY =
        size.height - (optimalPoint.chargeTotal / maxCharge) * size.height * 0.9;

    final optimalDotPaint = Paint()
      ..color = MintColors.success
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(optimalX, optimalY), 6, optimalDotPaint);
    canvas.drawCircle(
      Offset(optimalX, optimalY),
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw current position
    final currentX = (currentPct / 100) * size.width;
    // Interpolate y for current position
    double currentY = size.height / 2;
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (currentPct >= p1.partSalairePct && currentPct <= p2.partSalairePct) {
        final t = (currentPct - p1.partSalairePct) /
            (p2.partSalairePct - p1.partSalairePct);
        final charge = p1.chargeTotal + (p2.chargeTotal - p1.chargeTotal) * t;
        currentY = size.height - (charge / maxCharge) * size.height * 0.9;
        break;
      }
    }

    final currentDotPaint = Paint()
      ..color = MintColors.info
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(currentX, currentY), 6, currentDotPaint);
    canvas.drawCircle(
      Offset(currentX, currentY),
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw requalification zone (< 60%)
    final zonePaint = Paint()
      ..color = MintColors.error.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * 0.6, size.height),
      zonePaint,
    );

    // 60% vertical dashed line
    final dashedPaint = Paint()
      ..color = MintColors.error.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final dashX = size.width * 0.6;
    for (double dy = 0; dy < size.height; dy += 8) {
      canvas.drawLine(
        Offset(dashX, dy),
        Offset(dashX, (dy + 4).clamp(0, size.height)),
        dashedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChargeCurvePainter oldDelegate) {
    return oldDelegate.currentPct != currentPct ||
        oldDelegate.optimalPct != optimalPct ||
        oldDelegate.points != points;
  }
}
