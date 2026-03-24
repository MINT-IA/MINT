import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/independants_service.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
    });
    _calculate();
  }

  void _initializeFromProfile() {
    try {
      final profile = context.read<CoachProfileProvider>().profile;
      if (profile == null) return;
      bool changed = false;
      if (profile.revenuBrutAnnuel > 0) {
        _benefice = profile.revenuBrutAnnuel.clamp(0, 500000);
        changed = true;
      }
      if (profile.revenuBrutAnnuel > 0) {
        _tauxMarginal = RetirementTaxCalculator.estimateMarginalRate(
          profile.revenuBrutAnnuel,
          profile.canton,
        );
        changed = true;
      }
      if (changed) _calculate();
    } catch (_) {
      // Provider not available
    }
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
                MintEntrance(child: _buildHeader()),
                const SizedBox(height: 20),
                MintEntrance(delay: const Duration(milliseconds: 100), child: _buildBeneficeSlider()),
                const SizedBox(height: 20),
                MintEntrance(delay: const Duration(milliseconds: 200), child: _buildPartSalaireSlider()),
                const SizedBox(height: 20),
                MintEntrance(delay: const Duration(milliseconds: 300), child: _buildTauxSlider()),
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
                MintEntrance(delay: const Duration(milliseconds: 400), child: _buildDisclaimer()),
                const SizedBox(height: 16),
                _buildCantonalDisclaimer(),
                const SizedBox(height: 16),
                _buildComplianceFooter(),
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
      backgroundColor: MintColors.white,
      foregroundColor: MintColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(S.of(context)!.dividendeVsSalaireTitle, style: MintTextStyles.headlineMedium()),
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
              'Si tu possèdes une SA ou Sàrl, tu peux te verser une '
              'combinaison de salaire et de dividendes. Le dividende '
              'est imposé à 50% (participation qualifiante) et échappe '
              'aux cotisations AVS. Trouve le split le plus adapte.',
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliders ────────────────────────────────────────────────

  Widget _buildBeneficeSlider() {
    return _buildSliderCard(
      title: S.of(context)!.dividendeBeneficeTotal,
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
      title: S.of(context)!.dividendePartSalaire,
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
      title: S.of(context)!.dividendeTauxMarginal,
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
    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintPremiumSlider(
            label: title,
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            formatValue: (_) => valueLabel,
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel, style: MintTextStyles.micro(color: MintColors.textMuted)),
              Text(maxLabel, style: MintTextStyles.micro(color: MintColors.textMuted)),
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
          Semantics(
            label: IndependantsService.formatChf(saving),
            child: Text(
              IndependantsService.formatChf(saving),
              style: MintTextStyles.displayMedium(color: saving > 0 ? MintColors.white : MintColors.primary),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            saving > 0
                ? S.of(context)!.dividendeVsSalaireChiffreChocPositive(IndependantsService.formatChf(saving))
                : S.of(context)!.dividendeVsSalaireChiffreChocNeutral,
            style: MintTextStyles.bodyMedium(color: saving > 0 ? MintColors.white.withValues(alpha: 0.9) : MintColors.textSecondary),
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
                  S.of(context)!.dividendeVsSalaireRequalificationTitle,
                  style: MintTextStyles.bodyMedium(color: MintColors.error).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  S.of(context)!.dividendeVsSalaireRequalificationBody,
                  style: MintTextStyles.bodySmall(color: MintColors.error.withValues(alpha: 0.8)),
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
    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildResultRow(
            S.of(context)!.dividendeVsSalairePartSalaireLabel,
            IndependantsService.formatChf(r.partSalaire),
            subtitle: S.of(context)!.dividendeVsSalairePctBenefice(_partSalairePct.toInt()),
          ),
          const SizedBox(height: 12),
          _buildResultRow(
            S.of(context)!.dividendeVsSalairePartDividende,
            IndependantsService.formatChf(r.partDividende),
            subtitle: S.of(context)!.dividendeVsSalairePctBenefice((100 - _partSalairePct).toInt()),
          ),
          const Divider(height: 24),
          _buildResultRow(
            S.of(context)!.dividendeVsSalaireChargeSalaire,
            IndependantsService.formatChf(r.chargeSalaire),
            color: MintColors.error,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            S.of(context)!.dividendeVsSalaireChargeDividende,
            IndependantsService.formatChf(r.chargeDividende),
            color: MintColors.info,
          ),
          const Divider(height: 24),
          _buildResultRow(
            S.of(context)!.dividendeVsSalaireChargeTotalSplit,
            IndependantsService.formatChf(r.chargeTotal),
            bold: true,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            S.of(context)!.dividendeVsSalaireCharge100Salaire,
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
              style: MintTextStyles.bodyMedium(color: color ?? MintColors.textSecondary).copyWith(fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
          ],
        ),
        Text(
          value,
          style: MintTextStyles.bodyMedium(color: bold ? MintColors.primary : (color ?? MintColors.textPrimary)).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ── Curve Chart ────────────────────────────────────────────

  Widget _buildCurveChart() {
    final r = _result!;
    if (r.sensitivity.isEmpty) return const SizedBox.shrink();

    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'CHARGE TOTALE PAR SPLIT',
                style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(letterSpacing: 1, fontWeight: FontWeight.w700),
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
              Text(S.of(context)!.dividendeSplitMin, style: MintTextStyles.micro(color: MintColors.textMuted)),
              Text(S.of(context)!.dividendeSplitMax, style: MintTextStyles.micro(color: MintColors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            children: [
              _buildChartLegend(MintColors.primary, S.of(context)!.dividendeVsSalaireChargeTotale),
              const SizedBox(width: 16),
              _buildChartLegend(MintColors.success, S.of(context)!.dividendeVsSalaireSplitAdapte),
              const SizedBox(width: 16),
              _buildChartLegend(MintColors.info, S.of(context)!.dividendeVsSalairePositionActuelle),
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
          style: MintTextStyles.micro(color: MintColors.textSecondary),
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
              S.of(context)!.dividendeVsSalaireARetenir,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(letterSpacing: 1, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEduCard(
          Icons.account_balance_outlined,
          S.of(context)!.dividendeVsSalaireEduImpotTitle,
          S.of(context)!.dividendeVsSalaireEduImpotBody,
        ),
        _buildEduCard(
          Icons.people_outline,
          S.of(context)!.dividendeVsSalaireEduAvsTitle,
          S.of(context)!.dividendeVsSalaireEduAvsBody,
        ),
        _buildEduCard(
          Icons.gavel_outlined,
          S.of(context)!.dividendeVsSalaireEduCantonalTitle,
          S.of(context)!.dividendeVsSalaireEduCantonalBody,
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
            MintSurface(
              padding: const EdgeInsets.all(8),
              radius: 10,
              child: Icon(icon, size: 18, color: MintColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    body,
                    style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
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
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Simulation simplifiée. L\'impôt sur le bénéfice de la société, '
              'les déductions personnelles et les règles cantonales ne sont '
              'pas intégrés dans ce calcul. Consulte un\u00B7e spécialiste '
              'pour une analyse complète.',
              style: MintTextStyles.bodySmall(color: MintColors.deepOrange),
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
        'L\'impact fiscal dépend de la pratique cantonale. '
        'Les seuils de requalification varient d\'un canton à l\'autre.',
        style: MintTextStyles.micro(color: MintColors.textMuted),
        textAlign: TextAlign.center,
      ),
    );
  }
  // ── Compliance Footer ─────────────────────────────────────

  Widget _buildComplianceFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Outil éducatif — ne constitue pas un conseil financier (LSFin).',
            style: MintTextStyles.micro(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            'Sources\u00a0: LIFD art.\u00a018, 20, 33\u00a0; CO art.\u00a0660',
            style: MintTextStyles.micro(color: MintColors.textMuted),
          ),
        ],
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
        ..color = MintColors.white
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
        ..color = MintColors.white
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
