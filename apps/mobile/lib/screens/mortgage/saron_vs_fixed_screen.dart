import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/mortgage_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

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
      final mortgage = profile.patrimoine.mortgageBalance;
      if (mortgage != null && mortgage > 0) {
        setState(() {
          _montantHypothecaire = mortgage.clamp(200000, 2000000);
        });
      }
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
          s.saronVsFixedAppBarTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MintSpacing.md),
        children: [
          // Chiffre choc
          _buildChiffreChocCard(result),
          const SizedBox(height: MintSpacing.lg),

          // Graphique
          _buildChartSection(s, result),
          const SizedBox(height: MintSpacing.lg),

          // Sliders
          _buildSlidersSection(s),
          const SizedBox(height: MintSpacing.lg),

          // Detail couts
          _buildCostComparisonSection(s, result),
          const SizedBox(height: MintSpacing.lg),

          // Disclaimer
          _buildDisclaimer(result.disclaimer),
          const SizedBox(height: MintSpacing.sm),

          // Source legale
          Text(
            s.saronVsFixedSource,
            style: MintTextStyles.micro(),
          ),
          const SizedBox(height: MintSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildChiffreChocCard(SaronVsFixedResult result) {
    return Semantics(
      label: 'CHF ${formatChf(result.economieSaronStable.abs())}',
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.info.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          children: [
            const Icon(Icons.compare_arrows, color: MintColors.info, size: 40),
            const SizedBox(height: MintSpacing.sm + 4),
            Text(
              'CHF ${formatChf(result.economieSaronStable.abs())}',
              style: MintTextStyles.displayMedium(color: MintColors.info),
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

  Widget _buildChartSection(S s, SaronVsFixedResult result) {
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
            s.saronVsFixedCumulativeCost(_dureeAns),
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
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
          const SizedBox(height: MintSpacing.md),
          // Legende
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(MintColors.primary, s.saronVsFixedLegendFixed),
              const SizedBox(width: MintSpacing.md),
              _buildLegendItem(MintColors.success, s.saronVsFixedLegendSaronStable),
              const SizedBox(width: MintSpacing.md),
              _buildLegendItem(MintColors.error, s.saronVsFixedLegendSaronRise),
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
            s.saronVsFixedParameters,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),

          // Montant hypothecaire
          _buildSliderRow(
            label: s.saronVsFixedMortgageAmount,
            value: _montantHypothecaire,
            min: 200000,
            max: 2000000,
            divisions: 36,
            format: 'CHF ${formatChf(_montantHypothecaire)}',
            onChanged: (v) => setState(() => _montantHypothecaire = v),
          ),
          const SizedBox(height: MintSpacing.md),

          // Duree
          Semantics(
            label: s.saronVsFixedDuration,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.saronVsFixedDuration,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm + 4),
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
                                child: Text(s.saronVsFixedYears(d),
                                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary)),
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
              Text(
                label,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
              ),
              Text(
                format,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
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
      ),
    );
  }

  Widget _buildCostComparisonSection(S s, SaronVsFixedResult result) {
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
            s.saronVsFixedCostComparison,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildCostRow(
            label: result.fixe.label,
            taux: s.saronVsFixedRate('${(result.fixe.tauxInitial * 100).toStringAsFixed(2)}%'),
            total: 'CHF ${formatChf(result.fixe.coutTotal)}',
            color: MintColors.textPrimary,
          ),
          const Divider(height: MintSpacing.md + 4),
          _buildCostRow(
            label: result.saronStable.label,
            taux: s.saronVsFixedRate('${(result.saronStable.tauxInitial * 100).toStringAsFixed(2)}%'),
            total: 'CHF ${formatChf(result.saronStable.coutTotal)}',
            color: MintColors.success,
          ),
          const Divider(height: MintSpacing.md + 4),
          _buildCostRow(
            label: result.saronHausse.label,
            taux: s.saronVsFixedRate('${(result.saronHausse.tauxInitial * 100).toStringAsFixed(2)}% initial'),
            total: 'CHF ${formatChf(result.saronHausse.coutTotal)}',
            color: MintColors.error,
          ),
          const SizedBox(height: MintSpacing.md),
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: MintColors.textMuted, size: 18),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    s.saronVsFixedInsightText,
                    style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
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
        const SizedBox(width: MintSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: MintTextStyles.bodySmall(color: color),
              ),
              Text(
                taux,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              ),
            ],
          ),
        ),
        Text(
          total,
          style: MintTextStyles.bodyMedium(color: color),
        ),
      ],
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
