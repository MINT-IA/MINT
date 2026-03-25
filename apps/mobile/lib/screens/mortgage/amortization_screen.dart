import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/mortgage_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:provider/provider.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
    });
  }

  void _initializeFromProfile() {
    try {
      final profile = context.read<CoachProfileProvider>().profile;
      if (profile == null) return;
      bool changed = false;
      final mortgage = profile.patrimoine.mortgageBalance;
      if (mortgage != null && mortgage > 0) {
        _montantHypothecaire = mortgage.clamp(200000, 2000000);
        changed = true;
      }
      final rate = profile.patrimoine.mortgageRate;
      if (rate != null && rate > 0) {
        _tauxInteret = (rate / 100).clamp(0.01, 0.05);
        changed = true;
      }
      if (profile.revenuBrutAnnuel > 0) {
        _tauxMarginal = RetirementTaxCalculator.estimateMarginalRate(
          profile.revenuBrutAnnuel,
          profile.canton,
        ).clamp(0.15, 0.45);
        changed = true;
      }
      if (changed) setState(() {});
    } catch (_) {
      // Provider not available
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final result = _result;

    return Scaffold(
      backgroundColor: MintColors.surface,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        title: Text(
          s.amortizationAppBarTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: ListView(
        padding: const EdgeInsets.all(MintSpacing.md),
        children: [
          // Intro pedagogique
          MintEntrance(child: _buildIntroCard(s)),
          const SizedBox(height: MintSpacing.lg),

          // Chiffre choc
          MintEntrance(delay: const Duration(milliseconds: 100), child: _buildChiffreChocCard(s, result)),
          const SizedBox(height: MintSpacing.lg),

          // Graphique
          MintEntrance(delay: const Duration(milliseconds: 200), child: _buildChartSection(s, result)),
          const SizedBox(height: MintSpacing.lg),

          // Sliders
          MintEntrance(delay: const Duration(milliseconds: 300), child: _buildSlidersSection(s)),
          const SizedBox(height: MintSpacing.lg),

          // Comparaison detaillee
          MintEntrance(delay: const Duration(milliseconds: 400), child: _buildComparisonSection(s, result)),
          const SizedBox(height: MintSpacing.lg),

          // Disclaimer
          _buildDisclaimer(result.disclaimer),
          const SizedBox(height: MintSpacing.sm),

          // Source legale
          Text(
            s.amortizationSource,
            style: MintTextStyles.micro(),
          ),
          const SizedBox(height: MintSpacing.xl),
        ],
      ))),
    );
  }

  Widget _buildIntroCard(S s) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.amortizationIntroTitle,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            s.amortizationIntroBody,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildMethodCard(
                  title: s.amortizationDirect,
                  description: s.amortizationDirectDesc,
                  icon: Icons.trending_down,
                  color: MintColors.info,
                ),
              ),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: _buildMethodCard(
                  title: s.amortizationIndirect,
                  description: s.amortizationIndirectDesc,
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
      padding: const EdgeInsets.all(MintSpacing.sm + 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: MintSpacing.sm),
          Text(
            title,
            style: MintTextStyles.bodySmall(color: color),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            description,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChocCard(S s, AmortizationResult result) {
    final isPositive = result.chiffreChocPositif;
    final color = isPositive ? MintColors.success : MintColors.info;

    return Semantics(
      label: 'CHF ${formatChf(result.economieIndirect.abs())}',
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.lg),
        radius: 16,
        child: Column(
          children: [
            Icon(Icons.compare_arrows, color: color, size: 40),
            const SizedBox(height: MintSpacing.sm + 4),
            Text(
              'CHF ${formatChf(result.economieIndirect.abs())}',
              style: MintTextStyles.displayMedium(color: color),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              result.chiffreChocTexte,
              textAlign: TextAlign.center,
              style: MintTextStyles.bodyMedium(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(S s, AmortizationResult result) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.amortizationEvolutionTitle(_dureeAns),
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
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
          const SizedBox(height: MintSpacing.md),
          // Legende
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(MintColors.info, s.amortizationLegendDebtDirect),
              const SizedBox(width: MintSpacing.sm + 4),
              _buildLegendItem(MintColors.textPrimary, s.amortizationLegendDebtIndirect),
              const SizedBox(width: MintSpacing.sm + 4),
              _buildLegendItem(MintColors.success, s.amortizationLegendCapital3a),
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
        const SizedBox(width: MintSpacing.xs),
        Text(
          label,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildSlidersSection(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.amortizationParameters,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),

          // Montant hypothecaire
          _buildSliderRow(
            label: s.amortizationMortgageAmount,
            value: _montantHypothecaire,
            min: 200000,
            max: 2000000,
            divisions: 36,
            format: 'CHF ${formatChf(_montantHypothecaire)}',
            onChanged: (v) => setState(() => _montantHypothecaire = v),
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Taux d'interet
          _buildSliderRow(
            label: s.amortizationInterestRate,
            value: _tauxInteret,
            min: 0.01,
            max: 0.05,
            divisions: 40,
            format: '${(_tauxInteret * 100).toStringAsFixed(2)}%',
            onChanged: (v) => setState(() => _tauxInteret = v),
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Duree
          _buildSliderRow(
            label: s.amortizationDuration,
            value: _dureeAns.toDouble(),
            min: 5,
            max: 30,
            divisions: 25,
            format: '$_dureeAns ans',
            onChanged: (v) => setState(() => _dureeAns = v.round()),
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Taux marginal
          _buildSliderRow(
            label: s.amortizationMarginalRate,
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
    return Semantics(
      label: '$label: $format',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
              ),
              Text(
                format,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
              ),
            ],
          ),
          MintPremiumSlider(
            label: label,
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            formatValue: (_) => format,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonSection(S s, AmortizationResult result) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.amortizationDetailedComparison,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),

          // Direct
          _buildComparisonCard(
            title: s.amortizationDirectTitle,
            color: MintColors.info,
            rows: [
              _compRow(s.amortizationTotalInterest,
                  'CHF ${formatChf(result.totalInteretsDirect)}'),
              _compRow(s.amortizationNetCost,
                  'CHF ${formatChf(result.coutNetDirect)}'),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          // Indirect
          _buildComparisonCard(
            title: s.amortizationIndirectTitle,
            color: MintColors.success,
            rows: [
              _compRow(s.amortizationTotalInterest,
                  'CHF ${formatChf(result.totalInteretsIndirect)}'),
              _compRow(s.amortizationCapital3aAccumulated,
                  'CHF ${formatChf(result.capital3aFinal)}'),
              _compRow(s.amortizationNetCost,
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
      padding: const EdgeInsets.all(MintSpacing.md),
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
            style: MintTextStyles.bodySmall(color: color),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          ...rows,
        ],
      ),
    );
  }

  Widget _compRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: MintTextStyles.labelSmall()),
          Text(
            value,
            style: MintTextStyles.labelSmall(color: MintColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              disclaimer,
              style: MintTextStyles.micro(color: MintColors.textSecondary),
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
      ..color = MintColors.border
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
          style: const TextStyle(fontSize: 10, color: MintColors.textMuted),
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
            style: const TextStyle(fontSize: 10, color: MintColors.textMuted),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, size.height - 16));
      }
    }

    // Draw debt curves
    _drawCurve(canvas, directPlan.map((p) => p.detteRestante).toList(),
        MintColors.info, maxVal, chartWidth, chartHeight, leftPadding, topPadding);
    _drawCurve(canvas, indirectPlan.map((p) => p.detteRestante).toList(),
        MintColors.primary, maxVal, chartWidth, chartHeight, leftPadding, topPadding);

    // Draw 3a capital curve
    _drawCurve(canvas, indirectPlan.map((p) => p.capital3a).toList(),
        MintColors.success, maxVal, chartWidth, chartHeight, leftPadding, topPadding);
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
