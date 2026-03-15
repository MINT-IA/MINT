import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/mortgage_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;

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
                'EPL MULTI-SOURCES',
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

                // Pie chart
                _buildPieChartSection(result),
                const SizedBox(height: 24),

                // Sliders
                _buildSlidersSection(),
                const SizedBox(height: 24),

                // Sources detail
                _buildSourcesDetail(result),
                const SizedBox(height: 24),

                // Ordre recommande
                _buildOrdreRecommande(),
                const SizedBox(height: 24),

                // Alertes
                if (result.alertes.isNotEmpty) ...[
                  _buildAlertesSection(result.alertes),
                  const SizedBox(height: 24),
                ],

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: 12),

                // Source legale
                Text(
                  'Source : LPP art. 30c (EPL), OPP3, LIFD art. 38. '
                  'Taux cantonaux estimes a titre pedagogique.',
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

  Widget _buildChiffreChocCard(EplCombinedResult result) {
    final color = result.chiffreChocPositif
        ? MintColors.success
        : MintColors.warning;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(
            result.objectifAtteint ? Icons.home_outlined : Icons.warning_amber_rounded,
            color: color,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            '${result.pourcentageCouvert.toStringAsFixed(1)}%',
            style: GoogleFonts.montserrat(
              fontSize: 48,
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
          if (!result.objectifAtteint) ...[
            const SizedBox(height: 8),
            Text(
              'Minimum requis : 20%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MintColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPieChartSection(EplCombinedResult result) {
    if (result.sources.isEmpty) {
      return const SizedBox.shrink();
    }

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
            'REPARTITION DES FONDS PROPRES',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          // Legende
          for (int i = 0; i < result.sources.length; i++)
            _buildPieLegendItem(
              color: _pieColors[i % _pieColors.length],
              label: result.sources[i].label,
              amount: 'CHF ${formatChf(result.sources[i].montant)}',
              percentage:
                  '${result.sources[i].pourcentageDuPrix.toStringAsFixed(1)}% du prix',
            ),
        ],
      ),
    );
  }

  static const _pieColors = [
    MintColors.primary, // Cash — anthracite
    MintColors.info, // 3a — blue
    MintColors.warning, // LPP — orange
  ];

  Widget _buildPieLegendItem({
    required Color color,
    required String label,
    required String amount,
    required String percentage,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                percentage,
                style: const TextStyle(
                  fontSize: 11,
                  color: MintColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
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

          // Canton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Canton',
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
                  child: DropdownButton<String>(
                    value: _canton,
                    items: EplCombinedCalculator.cantons
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: const TextStyle(fontSize: 13)),
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
          const SizedBox(height: 16),

          // Prix cible
          _buildSliderRow(
            label: 'Prix d\'achat cible',
            value: _prixCible,
            min: 200000,
            max: 3000000,
            divisions: 56,
            format: 'CHF ${formatChf(_prixCible)}',
            onChanged: (v) => setState(() => _prixCible = v),
          ),
          const SizedBox(height: 12),

          // Epargne cash
          _buildSliderRow(
            label: 'Epargne cash',
            value: _epargneCash,
            min: 0,
            max: 500000,
            divisions: 100,
            format: 'CHF ${formatChf(_epargneCash)}',
            onChanged: (v) => setState(() => _epargneCash = v),
          ),
          const SizedBox(height: 12),

          // Avoir 3a
          _buildSliderRow(
            label: 'Avoir 3a',
            value: _avoir3a,
            min: 0,
            max: 300000,
            divisions: 60,
            format: 'CHF ${formatChf(_avoir3a)}',
            onChanged: (v) => setState(() => _avoir3a = v),
          ),
          const SizedBox(height: 12),

          // Avoir LPP
          _buildSliderRow(
            label: 'Avoir LPP',
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
          activeColor: MintColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSourcesDetail(EplCombinedResult result) {
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
            'DETAIL DES SOURCES',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          for (final source in result.sources) ...[
            _buildSourceRow(source),
            const Divider(height: 16),
          ],

          // Totaux
          _buildInfoRow(
            'Total fonds propres',
            'CHF ${formatChf(result.fondsPropresTotal)}',
            isBold: true,
          ),
          _buildInfoRow(
            'Impots estimes (3a + LPP)',
            '-CHF ${formatChf(result.totalImpots)}',
            color: MintColors.error,
          ),
          _buildInfoRow(
            'Montant net total',
            'CHF ${formatChf(result.montantNetTotal)}',
            isBold: true,
            color: result.objectifAtteint
                ? MintColors.success
                : MintColors.error,
          ),
          _buildInfoRow(
            'Fonds propres requis (20%)',
            'CHF ${formatChf(result.fondsPropresRequis)}',
          ),
        ],
      ),
    );
  }

  Widget _buildSourceRow(FundingSource source) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              source.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'CHF ${formatChf(source.montant)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (source.impotEstime > 0) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Impot estime',
                style: TextStyle(
                  fontSize: 11,
                  color: MintColors.error,
                ),
              ),
              Text(
                '-CHF ${formatChf(source.impotEstime)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MintColors.error,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Net',
                style: TextStyle(fontSize: 11, color: MintColors.textMuted),
              ),
              Text(
                'CHF ${formatChf(source.montantNet)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOrdreRecommande() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: MintColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'ORDRE RECOMMANDE',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildOrderItem(
            number: '1',
            title: 'Epargne cash',
            reason: 'Aucun impot, pas d\'impact sur la prevoyance',
            color: MintColors.success,
          ),
          const SizedBox(height: 10),
          _buildOrderItem(
            number: '2',
            title: 'Retrait 3a',
            reason:
                'Impot reduit sur le retrait, impact limite sur la prevoyance vieillesse',
            color: MintColors.info,
          ),
          const SizedBox(height: 10),
          _buildOrderItem(
            number: '3',
            title: 'Retrait LPP (EPL)',
            reason:
                'Impact direct sur les prestations de risque (invalidite, deces). A utiliser en dernier recours.',
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                reason,
                style: const TextStyle(
                  fontSize: 11,
                  color: MintColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertesSection(List<String> alertes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'POINTS D\'ATTENTION',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        for (final alerte in alertes)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MintColors.disclaimerBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.yellowGold),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: MintColors.warningText, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alerte,
                    style: TextStyle(
                      fontSize: 12,
                      color: MintColors.amberDark,
                      height: 1.4,
                    ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? MintColors.textPrimary,
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
// Pie Chart Painter
// ─────────────────────────────────────────────────────────────────────────────

class _PieChartPainter extends CustomPainter {
  final List<FundingSource> sources;
  final double total;

  static const _colors = [
    MintColors.primary, // Cash — anthracite
    MintColors.info, // 3a — blue
    MintColors.warning, // LPP — orange
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
