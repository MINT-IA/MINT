import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/mortgage_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/coach/mortgage_journey_widget.dart';

/// Ecran de capacite d'achat immobilier.
///
/// Affiche le prix max accessible, la jauge fonds propres et le ratio charges.
/// Base legale : directive ASB sur le credit hypothecaire.
class AffordabilityScreen extends StatefulWidget {
  const AffordabilityScreen({super.key});

  @override
  State<AffordabilityScreen> createState() => _AffordabilityScreenState();
}

class _AffordabilityScreenState extends State<AffordabilityScreen> {
  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('mortgage');
  }

  double _revenuBrut = 120000;
  double _prixAchat = 800000;
  double _epargneDispo = 100000;
  double _avoir3a = 50000;
  double _avoirLpp = 200000;
  String _canton = 'VD';

  static const _cantons = [
    'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR',
    'JU', 'LU', 'NE', 'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG',
    'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
  ];

  AffordabilityResult _computeResult(S s) => AffordabilityCalculator.calculate(
        revenuBrutAnnuel: _revenuBrut,
        epargneDispo: _epargneDispo,
        avoir3a: _avoir3a,
        avoirLpp: _avoirLpp,
        prixAchat: _prixAchat,
        canton: _canton,
        s: s,
      );

  @override
  Widget build(BuildContext context) {
    final result = _computeResult(S.of(context)!);

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
                S.of(context)!.affordabilityTitle,
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

                // Jauges
                _buildGaugesSection(result),
                const SizedBox(height: 24),

                // Sliders
                _buildSlidersSection(),
                const SizedBox(height: 24),

                // Detail resultats
                _buildDetailSection(result),
                const SizedBox(height: 24),

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: 24),

                // ── P3-E : Parcours achat immobilier ────────────
                const MortgageJourneyWidget(),
                const SizedBox(height: 12),

                // Source legale
                Text(
                  S.of(context)!.affordabilitySource,
                  style: const TextStyle(
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

  Widget _buildChiffreChocCard(AffordabilityResult result) {
    final color = result.chiffreChocPositif
        ? MintColors.success
        : MintColors.error;

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
            result.chiffreChocPositif
                ? Icons.check_circle_outline
                : Icons.warning_amber_rounded,
            color: color,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            result.chiffreChocPositif
                ? 'CHF ${formatChf(result.prixMaxAccessible)}'
                : 'CHF ${formatChf(result.manqueFondsPropres)}',
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

  Widget _buildGaugesSection(AffordabilityResult result) {
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
            S.of(context)!.affordabilityIndicators,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),

          // Ratio charges
          _buildGaugeRow(
            label: S.of(context)!.affordabilityChargesRatio,
            value: result.ratioCharges,
            maxValue: 0.50,
            threshold: 0.33,
            displayValue: '${(result.ratioCharges * 100).toStringAsFixed(1)}%',
            thresholdLabel: S.of(context)?.affordabilityMax33 ?? 'Max 33\u00a0%',
            isOk: result.capaciteOk,
          ),
          const SizedBox(height: 24),

          // Fonds propres
          _buildGaugeRow(
            label: S.of(context)!.affordabilityEquityRatio,
            value: result.fondsPropresTotal / max(result.fondsPropresRequis, 1),
            maxValue: 1.5,
            threshold: 1.0,
            displayValue:
                'CHF ${formatChf(result.fondsPropresTotal)} / ${formatChf(result.fondsPropresRequis)}',
            thresholdLabel: S.of(context)?.affordabilityMin20 ?? 'Min 20\u00a0%',
            isOk: result.fondsPropresOk,
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeRow({
    required String label,
    required double value,
    required double maxValue,
    required double threshold,
    required String displayValue,
    required String thresholdLabel,
    required bool isOk,
  }) {
    final progress = (value / maxValue).clamp(0.0, 1.0);
    final thresholdPos = (threshold / maxValue).clamp(0.0, 1.0);
    final color = isOk ? MintColors.success : MintColors.error;

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
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isOk ? S.of(context)!.affordabilityOk : S.of(context)!.affordabilityExceeded,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            // Background
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: MintColors.lightBorder,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            // Progress
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            // Threshold marker
            Positioned(
              left: thresholdPos *
                  (MediaQuery.of(context).size.width - 72 - 2),
              top: 0,
              bottom: 0,
              child: Container(
                width: 2,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              thresholdLabel,
              style: const TextStyle(
                fontSize: 11,
                color: MintColors.textMuted,
              ),
            ),
          ],
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
            S.of(context)!.affordabilityParameters,
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
              Text(
                S.of(context)!.affordabilityCanton,
                style: const TextStyle(
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
                    items: _cantons
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

          // Revenu brut annuel
          _buildSliderRow(
            label: S.of(context)!.affordabilityGrossIncome,
            value: _revenuBrut,
            min: 50000,
            max: 300000,
            divisions: 50,
            format: 'CHF ${formatChf(_revenuBrut)}',
            onChanged: (v) => setState(() => _revenuBrut = v),
          ),
          const SizedBox(height: 12),

          // Prix d'achat
          _buildSliderRow(
            label: S.of(context)!.affordabilityTargetPrice,
            value: _prixAchat,
            min: 200000,
            max: 3000000,
            divisions: 56,
            format: 'CHF ${formatChf(_prixAchat)}',
            onChanged: (v) => setState(() => _prixAchat = v),
          ),
          const SizedBox(height: 12),

          // Epargne disponible
          _buildSliderRow(
            label: S.of(context)!.affordabilityAvailableSavings,
            value: _epargneDispo,
            min: 0,
            max: 500000,
            divisions: 100,
            format: 'CHF ${formatChf(_epargneDispo)}',
            onChanged: (v) => setState(() => _epargneDispo = v),
          ),
          const SizedBox(height: 12),

          // Avoir 3a
          _buildSliderRow(
            label: S.of(context)!.affordabilityPillar3a,
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
            label: S.of(context)!.affordabilityPillarLpp,
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
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Text(
              format,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.border,
            thumbColor: MintColors.primary,
            overlayColor: MintColors.primary.withValues(alpha: 0.1),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(AffordabilityResult result) {
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
            S.of(context)!.affordabilityCalculationDetail,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(S.of(context)!.affordabilityTargetPrice,
              'CHF ${formatChf(_prixAchat)}'),
          _buildInfoRow(S.of(context)!.affordabilityEquityRequired,
              'CHF ${formatChf(result.fondsPropresRequis)}'),
          const Divider(height: 20),
          _buildInfoRow(S.of(context)!.affordabilitySavingsLabel,
              'CHF ${formatChf(_epargneDispo)}'),
          _buildInfoRow(S.of(context)!.affordabilityPillar3a,
              'CHF ${formatChf(_avoir3a)}'),
          _buildInfoRow(
              S.of(context)!.affordabilityLppMax10,
              'CHF ${formatChf(min(_avoirLpp, _prixAchat * 0.10))}'),
          _buildInfoRow(S.of(context)!.affordabilityTotalEquity,
              'CHF ${formatChf(result.fondsPropresTotal)}',
              isBold: true,
              color: result.fondsPropresOk
                  ? MintColors.success
                  : MintColors.error),
          const Divider(height: 20),
          () {
            final hypothequeReelle = max(0.0, _prixAchat - result.fondsPropresTotal);
            final ltvPct = _prixAchat > 0 ? (hypothequeReelle / _prixAchat * 100).toStringAsFixed(0) : '0';
            return _buildInfoRow(
              S.of(context)!.affordabilityMortgagePercent(ltvPct),
              'CHF ${formatChf(hypothequeReelle)}',
            );
          }(),
          _buildInfoRow(S.of(context)!.affordabilityMonthlyCharges,
              'CHF ${formatChf(result.chargesTheoriquesMensuelles)}'),
          _buildInfoRow(
            S.of(context)!.affordabilityChargesRatio,
            '${(result.ratioCharges * 100).toStringAsFixed(1)}%',
            isBold: true,
            color: result.capaciteOk
                ? MintColors.success
                : MintColors.error,
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.affordabilityCalculationNote,
            style: const TextStyle(
              fontSize: 11,
              color: MintColors.textMuted,
              height: 1.4,
            ),
          ),
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
          const Icon(Icons.info_outline, color: MintColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              disclaimer,
              style: const TextStyle(
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
