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
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Ecran de financement EPL multi-sources.
///
/// Affiche la repartition des fonds propres par source (cash, 3a, LPP)
/// avec pie chart, alertes et impots estimes.
/// Base legale : LPP art. 30c (EPL), OPP3, LIFD art. 38.
class EplCombinedScreen extends StatefulWidget {
  const EplCombinedScreen({super.key});

  @override
  State<EplCombinedScreen> createState() => _EplCombinedScreenState();
}

class _EplCombinedScreenState extends State<EplCombinedScreen> {
  double _epargneCash = 100000;
  double _avoir3a = 60000;
  double _avoirLpp = 200000;
  double _prixCible = 900000;
  String _canton = 'VD';

  EplCombinedResult get _result => EplCombinedCalculator.calculate(
        epargneCash: _epargneCash,
        avoir3a: _avoir3a,
        avoirLpp: _avoirLpp,
        prixCible: _prixCible,
        canton: _canton,
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
      if (profile.patrimoine.epargneLiquide > 0) {
        _epargneCash = profile.patrimoine.epargneLiquide.clamp(0, 500000);
        changed = true;
      }
      if (profile.prevoyance.totalEpargne3a > 0) {
        _avoir3a = profile.prevoyance.totalEpargne3a.clamp(0, 300000);
        changed = true;
      }
      final lpp = profile.prevoyance.avoirLppTotal;
      if (lpp != null && lpp > 0) {
        _avoirLpp = lpp.clamp(0, 500000);
        changed = true;
      }
      final propertyValue = profile.patrimoine.propertyMarketValue;
      if (propertyValue != null && propertyValue > 0) {
        _prixCible = propertyValue.clamp(200000, 3000000);
        changed = true;
      }
      if (profile.canton.isNotEmpty) {
        _canton = profile.canton.toUpperCase();
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
          s.eplCombinedAppBarTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MintSpacing.md),
        children: [
          // Chiffre choc
          MintEntrance(child: _buildChiffreChocCard(s, result)),
          const SizedBox(height: MintSpacing.lg),

          // Pie chart
          MintEntrance(delay: const Duration(milliseconds: 100), child: _buildPieChartSection(s, result)),
          const SizedBox(height: MintSpacing.lg),

          // Sliders
          MintEntrance(delay: const Duration(milliseconds: 200), child: _buildSlidersSection(s)),
          const SizedBox(height: MintSpacing.lg),

          // Sources detail
          MintEntrance(delay: const Duration(milliseconds: 300), child: _buildSourcesDetail(s, result)),
          const SizedBox(height: MintSpacing.lg),

          // Ordre recommande
          MintEntrance(delay: const Duration(milliseconds: 400), child: _buildOrdreRecommande(s)),
          const SizedBox(height: MintSpacing.lg),

          // Alertes
          if (result.alertes.isNotEmpty) ...[
            _buildAlertesSection(s, result.alertes),
            const SizedBox(height: MintSpacing.lg),
          ],

          // Disclaimer
          _buildDisclaimer(result.disclaimer),
          const SizedBox(height: MintSpacing.sm),

          // Source legale
          Text(
            s.eplCombinedSource,
            style: MintTextStyles.micro(),
          ),
          const SizedBox(height: MintSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildChiffreChocCard(S s, EplCombinedResult result) {
    final color = result.chiffreChocPositif
        ? MintColors.success
        : MintColors.warning;

    return Semantics(
      label: '${result.pourcentageCouvert.toStringAsFixed(1)}%',
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.lg),
        radius: 16,
        child: Column(
          children: [
            Icon(
              result.objectifAtteint ? Icons.home_outlined : Icons.warning_amber_rounded,
              color: color,
              size: 40,
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            Text(
              '${result.pourcentageCouvert.toStringAsFixed(1)}%',
              style: MintTextStyles.displayLarge(color: color),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              result.chiffreChocTexte,
              textAlign: TextAlign.center,
              style: MintTextStyles.bodyMedium(),
            ),
            if (!result.objectifAtteint) ...[
              const SizedBox(height: MintSpacing.sm),
              Text(
                s.eplCombinedMinRequired,
                style: MintTextStyles.labelSmall(color: MintColors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartSection(S s, EplCombinedResult result) {
    if (result.sources.isEmpty) {
      return const SizedBox.shrink();
    }

    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.eplCombinedFundsBreakdown,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md + 4),
          Center(
            child: SizedBox(
              height: 180,
              width: 180,
              child: CustomPaint(
                size: const Size(180, 180),
                painter: _PieChartPainter(
                  sources: result.sources,
                  total: result.fondsPropresTotal,
                ),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.md + 4),
          // Legende
          for (int i = 0; i < result.sources.length; i++)
            _buildPieLegendItem(
              color: _pieColors[i % _pieColors.length],
              label: result.sources[i].label,
              amount: 'CHF ${formatChf(result.sources[i].montant)}',
              percentage:
                  '${result.sources[i].pourcentageDuPrix.toStringAsFixed(1)}% ${s.eplCombinedPriceOfProperty}',
            ),
        ],
      ),
    );
  }

  static const _pieColors = [
    MintColors.primary, // Cash
    MintColors.info, // 3a
    MintColors.warning, // LPP
  ];

  Widget _buildPieLegendItem({
    required Color color,
    required String label,
    required String amount,
    required String percentage,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs + 2),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: MintSpacing.sm + 2),
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
              ),
              Text(
                percentage,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlidersSection(S s) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.eplCombinedParameters,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),

          // Canton
          Semantics(
            label: s.eplCombinedCanton,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.eplCombinedCanton,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm + 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: MintColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _canton,
                      items: EplCombinedCalculator.cantons
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _canton = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.md),

          // Prix cible
          _buildSliderRow(
            label: s.eplCombinedTargetPrice,
            value: _prixCible,
            min: 200000,
            max: 3000000,
            divisions: 56,
            format: 'CHF ${formatChf(_prixCible)}',
            onChanged: (v) => setState(() => _prixCible = v),
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Epargne cash
          _buildSliderRow(
            label: s.eplCombinedCashSavings,
            value: _epargneCash,
            min: 0,
            max: 500000,
            divisions: 100,
            format: 'CHF ${formatChf(_epargneCash)}',
            onChanged: (v) => setState(() => _epargneCash = v),
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Avoir 3a
          _buildSliderRow(
            label: s.eplCombinedAvoir3a,
            value: _avoir3a,
            min: 0,
            max: 300000,
            divisions: 60,
            format: 'CHF ${formatChf(_avoir3a)}',
            onChanged: (v) => setState(() => _avoir3a = v),
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Avoir LPP
          _buildSliderRow(
            label: s.eplCombinedAvoirLpp,
            value: _avoirLpp,
            min: 0,
            max: 500000,
            divisions: 100,
            format: 'CHF ${formatChf(_avoirLpp)}',
            onChanged: (v) => setState(() => _avoirLpp = v),
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

  Widget _buildSourcesDetail(S s, EplCombinedResult result) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.eplCombinedSourcesDetail,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),

          for (final source in result.sources) ...[
            _buildSourceRow(s, source),
            const Divider(height: MintSpacing.md),
          ],

          // Totaux
          _buildInfoRow(
            s.eplCombinedTotalEquity,
            'CHF ${formatChf(result.fondsPropresTotal)}',
            isBold: true,
          ),
          _buildInfoRow(
            s.eplCombinedEstimatedTaxes,
            '-CHF ${formatChf(result.totalImpots)}',
            color: MintColors.error,
          ),
          _buildInfoRow(
            s.eplCombinedNetTotal,
            'CHF ${formatChf(result.montantNetTotal)}',
            isBold: true,
            color: result.objectifAtteint
                ? MintColors.success
                : MintColors.error,
          ),
          _buildInfoRow(
            s.eplCombinedRequiredEquity,
            'CHF ${formatChf(result.fondsPropresRequis)}',
          ),
        ],
      ),
    );
  }

  Widget _buildSourceRow(S s, FundingSource source) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              source.label,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
            Text(
              'CHF ${formatChf(source.montant)}',
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          ],
        ),
        if (source.impotEstime > 0) ...[
          const SizedBox(height: MintSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.eplCombinedEstimatedTax,
                style: MintTextStyles.labelSmall(color: MintColors.error),
              ),
              Text(
                '-CHF ${formatChf(source.impotEstime)}',
                style: MintTextStyles.labelSmall(color: MintColors.error),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.eplCombinedNet,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              ),
              Text(
                'CHF ${formatChf(source.montantNet)}',
                style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOrdreRecommande(S s) {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: MintColors.primary, size: 20),
              const SizedBox(width: MintSpacing.sm),
              Text(
                s.eplCombinedRecommendedOrder,
                style: MintTextStyles.bodySmall(color: MintColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          _buildOrderItem(
            number: '1',
            title: s.eplCombinedOrderCashTitle,
            reason: s.eplCombinedOrderCashReason,
            color: MintColors.success,
          ),
          const SizedBox(height: MintSpacing.sm + 2),
          _buildOrderItem(
            number: '2',
            title: s.eplCombinedOrder3aTitle,
            reason: s.eplCombinedOrder3aReason,
            color: MintColors.info,
          ),
          const SizedBox(height: MintSpacing.sm + 2),
          _buildOrderItem(
            number: '3',
            title: s.eplCombinedOrderLppTitle,
            reason: s.eplCombinedOrderLppReason,
            color: MintColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem({
    required String number,
    required String title,
    required String reason,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: MintTextStyles.labelSmall(color: MintColors.white),
          ),
        ),
        const SizedBox(width: MintSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                reason,
                style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertesSection(S s, List<String> alertes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.eplCombinedAttentionPoints,
          style: MintTextStyles.bodySmall(color: MintColors.textMuted),
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        for (final alerte in alertes)
          Container(
            margin: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
            padding: const EdgeInsets.all(MintSpacing.md - 2),
            decoration: BoxDecoration(
              color: MintColors.warning.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: MintColors.warning, size: 20),
                const SizedBox(width: MintSpacing.sm + 2),
                Expanded(
                  child: Text(
                    alerte,
                    style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: isBold
                  ? MintTextStyles.bodySmall(color: MintColors.textPrimary)
                  : MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: isBold
                ? MintTextStyles.bodySmall(color: color ?? MintColors.textPrimary)
                : MintTextStyles.labelSmall(color: color ?? MintColors.textPrimary),
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
// Pie Chart Painter
// ─────────────────────────────────────────────────────────────────────────────

class _PieChartPainter extends CustomPainter {
  final List<FundingSource> sources;
  final double total;

  static const _colors = [
    MintColors.primary, // Cash
    MintColors.info, // 3a
    MintColors.warning, // LPP
  ];

  _PieChartPainter({
    required this.sources,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (sources.isEmpty || total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;

    double startAngle = -pi / 2; // Start from top

    for (int i = 0; i < sources.length; i++) {
      final fraction = sources[i].montant / total;
      final sweepAngle = fraction * 2 * pi;

      final paint = Paint()
        ..color = _colors[i % _colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // White separator
      final separatorPaint = Paint()
        ..color = MintColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        separatorPaint,
      );

      startAngle += sweepAngle;
    }

    // Center circle (donut hole)
    final holePaint = Paint()
      ..color = MintColors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.55, holePaint);

    // Center text
    final tp = TextPainter(
      text: TextSpan(
        text: 'CHF\n${formatChf(total)}',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: MintColors.primary,
          height: 1.3,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: radius * 1.0);
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.total != total || oldDelegate.sources != sources;
}
