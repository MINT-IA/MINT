import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/debt_prevention_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

/// Ecran de diagnostic du ratio d'endettement.
///
/// Affiche une gauge visuelle (semi-cercle vert/orange/rouge) avec le ratio,
/// le minimum vital et des recommandations.
/// Base legale : LP art. 93 (minimum vital), LCC.
class DebtRatioScreen extends StatefulWidget {
  const DebtRatioScreen({super.key});

  @override
  State<DebtRatioScreen> createState() => _DebtRatioScreenState();
}

class _DebtRatioScreenState extends State<DebtRatioScreen> {
  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('debt');
  }

  double _revenusMensuels = 6000;
  double _chargesDetteMensuelles = 500;
  double _loyer = 1500;
  double _autresCharges = 300;
  bool _estCelibataire = true;
  int _nombreEnfants = 0;

  DebtRatioResult get _result => DebtRatioCalculator.calculate(
        revenusMensuels: _revenusMensuels,
        chargesDetteMensuelles: _chargesDetteMensuelles,
        loyer: _loyer,
        autresChargesFixes: _autresCharges,
        estCelibataire: _estCelibataire,
        nombreEnfants: _nombreEnfants,
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;

    final isSafeMode = result.niveau == DebtRiskLevel.rouge;
    final appBarColor = isSafeMode ? MintColors.warning : MintColors.primary;

    return Scaffold(
      backgroundColor: MintColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: appBarColor,
            foregroundColor: MintColors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'DIAGNOSTIC DETTE',
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
                // Chiffre choc gauge
                _buildGaugeSection(result),
                const SizedBox(height: 24),

                // Sliders
                _buildSlidersSection(),
                const SizedBox(height: 24),

                // Minimum vital
                _buildMinimumVitalCard(result),
                const SizedBox(height: 24),

                // Recommandations
                _buildRecommandationsSection(result),
                const SizedBox(height: 24),

                // Aide professionnelle
                if (result.niveau == DebtRiskLevel.rouge) ...[
                  _buildAideProfessionnelleSection(),
                  const SizedBox(height: 24),
                ],

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeSection(DebtRatioResult result) {
    final color = switch (result.niveau) {
      DebtRiskLevel.vert => MintColors.success,
      DebtRiskLevel.orange => MintColors.warning,
      DebtRiskLevel.rouge => MintColors.error,
    };

    final label = switch (result.niveau) {
      DebtRiskLevel.vert => 'SAIN',
      DebtRiskLevel.orange => 'ATTENTION',
      DebtRiskLevel.rouge => 'CRITIQUE',
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        children: [
          // Semi-circle gauge
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: const Size(200, 150),
              painter: _GaugePainter(
                ratio: result.ratio,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.ratio.toStringAsFixed(1)}%',
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ratio dette / revenus',
            style: const TextStyle(
              fontSize: 12,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          // Legende
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(MintColors.success, '< 15%'),
              const SizedBox(width: 16),
              _buildLegendDot(MintColors.warning, '15-30%'),
              const SizedBox(width: 16),
              _buildLegendDot(MintColors.error, '> 30%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
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

          // Revenu mensuel
          _buildSliderRow(
            label: 'Revenu mensuel net',
            value: _revenusMensuels,
            min: 2000,
            max: 20000,
            divisions: 36,
            format: 'CHF ${formatChf(_revenusMensuels)}',
            onChanged: (v) => setState(() => _revenusMensuels = v),
          ),
          const SizedBox(height: 12),

          // Charges dette
          _buildSliderRow(
            label: 'Charges de dette mensuelles',
            value: _chargesDetteMensuelles,
            min: 0,
            max: 10000,
            divisions: 100,
            format: 'CHF ${formatChf(_chargesDetteMensuelles)}',
            onChanged: (v) =>
                setState(() => _chargesDetteMensuelles = v),
          ),
          const SizedBox(height: 12),

          // Loyer
          _buildSliderRow(
            label: 'Loyer',
            value: _loyer,
            min: 0,
            max: 5000,
            divisions: 50,
            format: 'CHF ${formatChf(_loyer)}',
            onChanged: (v) => setState(() => _loyer = v),
          ),
          const SizedBox(height: 12),

          // Autres charges
          _buildSliderRow(
            label: 'Autres charges fixes',
            value: _autresCharges,
            min: 0,
            max: 3000,
            divisions: 30,
            format: 'CHF ${formatChf(_autresCharges)}',
            onChanged: (v) => setState(() => _autresCharges = v),
          ),
          const SizedBox(height: 16),

          // Situation personnelle
          Row(
            children: [
              Expanded(
                child: const Text(
                  'Celibataire',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: _estCelibataire,
                activeColor: MintColors.primary,
                onChanged: (v) => setState(() => _estCelibataire = v),
              ),
            ],
          ),

          _buildSliderRow(
            label: 'Nombre d\'enfants',
            value: _nombreEnfants.toDouble(),
            min: 0,
            max: 6,
            divisions: 6,
            format: '$_nombreEnfants',
            onChanged: (v) => setState(() => _nombreEnfants = v.round()),
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

  Widget _buildMinimumVitalCard(DebtRatioResult result) {
    final isMenace = result.minimumVitalMenace;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isMenace ? MintColors.urgentBg : MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMenace ? MintColors.coralLight : MintColors.border,
          width: isMenace ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MINIMUM VITAL (LP ART. 93)',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isMenace ? MintColors.redMedium : MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Minimum vital',
            'CHF ${formatChf(result.minimumVital)} / mois',
          ),
          const Divider(height: 20),
          _buildInfoRow(
            'Marge disponible',
            'CHF ${formatChf(result.margeDisponible)} / mois',
            color: result.margeDisponible > result.minimumVital
                ? MintColors.success
                : MintColors.error,
            isBold: true,
          ),
          if (isMenace) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.redBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: MintColors.redMedium, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Votre marge residuelle est inferieure au minimum vital. '
                      'Contactez un service d\'aide professionnelle.',
                      style: TextStyle(
                        fontSize: 12,
                        color: MintColors.redDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildRecommandationsSection(DebtRatioResult result) {
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
            'RECOMMANDATIONS',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          for (final reco in result.recommandations)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_forward,
                      color: MintColors.primary, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reco,
                      style: const TextStyle(
                        fontSize: 13,
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

  Widget _buildAideProfessionnelleSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MintColors.urgentBg, MintColors.warningBg],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.redBg, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent, color: MintColors.redMedium, size: 24),
              const SizedBox(width: 12),
              Text(
                'AIDE PROFESSIONNELLE',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MintColors.redDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dettes Conseils
          _buildResourceLink(
            nom: 'Dettes Conseils Suisse',
            description: 'Conseil gratuit et confidentiel',
            url: 'https://www.dettes.ch',
            telephone: '0800 40 40 40',
          ),
          const SizedBox(height: 12),

          // Caritas
          _buildResourceLink(
            nom: 'Caritas — Aide aux dettes',
            description: 'Aide au desendettement et negociation',
            url: 'https://www.caritas.ch/dettes',
            telephone: '0800 708 708',
          ),
        ],
      ),
    );
  }

  Widget _buildResourceLink({
    required String nom,
    required String description,
    required String url,
    String? telephone,
  }) {
    return InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MintColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nom,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  if (telephone != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      telephone,
                      style: TextStyle(
                        fontSize: 12,
                        color: MintColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.open_in_new,
                color: MintColors.textMuted, size: 18),
          ],
        ),
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
                color: MintColors.deepOrange,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gauge Painter (semi-cercle)
// ─────────────────────────────────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  final double ratio;
  final Color color;

  _GaugePainter({required this.ratio, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2.5;

    // Background arc (gray)
    final bgPaint = Paint()
      ..color = MintColors.lightBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      bgPaint,
    );

    // Green zone (0-15%)
    final greenPaint = Paint()
      ..color = MintColors.success.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi * 0.5, // 0-15% = first half
      false,
      greenPaint,
    );

    // Orange zone (15-30%)
    final orangePaint = Paint()
      ..color = MintColors.warning.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi + pi * 0.5,
      pi * 0.25,
      false,
      orangePaint,
    );

    // Red zone (30%+)
    final redPaint = Paint()
      ..color = MintColors.error.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi + pi * 0.75,
      pi * 0.25,
      false,
      redPaint,
    );

    // Needle position (ratio mapped to 0-pi)
    final clampedRatio = ratio.clamp(0.0, 50.0);
    final angle = pi + (clampedRatio / 50.0) * pi;

    // Needle
    final needlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final needleLength = radius - 10;
    final needleEnd = Offset(
      center.dx + needleLength * cos(angle),
      center.dy + needleLength * sin(angle),
    );

    canvas.drawLine(center, needleEnd, needlePaint);

    // Center dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.ratio != ratio || oldDelegate.color != color;
}
