import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/mortgage_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/widgets/coach/mortgage_journey_widget.dart';
import 'package:mint_mobile/widgets/collapsible_section.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';

/// Ecran de capacite d'achat immobilier (Cat B — Simulator).
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
  bool _showAdvancedParams = false;

  static const _cantons = [
    'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR',
    'JU', 'LU', 'NE', 'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG',
    'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
  ];

  AffordabilityResult get _result => AffordabilityCalculator.calculate(
        revenuBrutAnnuel: _revenuBrut,
        epargneDispo: _epargneDispo,
        avoir3a: _avoir3a,
        avoirLpp: _avoirLpp,
        prixAchat: _prixAchat,
        canton: _canton,
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── White standard AppBar (Design System §4.5) ──
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.white,
            foregroundColor: MintColors.textPrimary,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                l.affordabilityTitle,
                style: MintTextStyles.headlineMedium(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(MintSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Chiffre choc with emotional framing ──
                _buildChiffreChocCard(result, l),
                const SizedBox(height: MintSpacing.lg),

                // ── Jauges ──
                _buildGaugesSection(result, l),
                const SizedBox(height: MintSpacing.md),

                // ── Insight pedagogique ──
                _buildInsightCard(result, l),
                const SizedBox(height: MintSpacing.lg),

                // ── Sliders (progressive disclosure: 3 visible + expandable) ──
                _buildSlidersSection(l),
                const SizedBox(height: MintSpacing.lg),

                // ── Detail resultats ──
                _buildDetailSection(result, l),
                const SizedBox(height: MintSpacing.lg),

                // ── Related sections (hub) ──
                _buildRelatedSections(l),
                const SizedBox(height: MintSpacing.lg),

                // ── Disclaimer ──
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: MintSpacing.lg),

                // ── P3-E : Parcours achat immobilier ──
                const MortgageJourneyWidget(),
                const SizedBox(height: MintSpacing.sm),

                // ── Source legale ──
                Semantics(
                  label: l.affordabilitySource,
                  child: Text(
                    l.affordabilitySource,
                    style: MintTextStyles.micro(),
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChocCard(AffordabilityResult result, S l) {
    final color = result.chiffreChocPositif
        ? MintColors.success
        : MintColors.error;

    // Emotional framing per VOICE_SYSTEM §5
    final emotionalLabel = result.chiffreChocPositif
        ? l.affordabilityEmotionalPositif
        : l.affordabilityEmotionalNegatif;

    return Semantics(
      label: emotionalLabel,
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          children: [
            // Emotional framing line
            Text(
              emotionalLabel,
              style: MintTextStyles.bodySmall(color: color),
            ),
            const SizedBox(height: MintSpacing.sm),
            Icon(
              result.chiffreChocPositif
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_rounded,
              color: color,
              size: 40,
            ),
            const SizedBox(height: MintSpacing.sm),
            // displayMedium for Simulator (Cat B)
            Text(
              result.chiffreChocPositif
                  ? 'CHF ${formatChf(result.prixMaxAccessible)}'
                  : 'CHF ${formatChf(result.manqueFondsPropres)}',
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

  Widget _buildGaugesSection(AffordabilityResult result, S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + MintSpacing.xs),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.affordabilityIndicators,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md + MintSpacing.xs),

          // Ratio charges
          _buildGaugeRow(
            label: l.affordabilityChargesRatio,
            value: result.ratioCharges,
            maxValue: 0.50,
            threshold: 0.33,
            displayValue: '${(result.ratioCharges * 100).toStringAsFixed(1)}%',
            thresholdLabel: 'Max 33%',
            isOk: result.capaciteOk,
          ),
          const SizedBox(height: MintSpacing.lg),

          // Fonds propres
          _buildGaugeRow(
            label: l.affordabilityEquityRatio,
            value: result.fondsPropresTotal / max(result.fondsPropresRequis, 1),
            maxValue: 1.5,
            threshold: 1.0,
            displayValue:
                'CHF ${formatChf(result.fondsPropresTotal)} / ${formatChf(result.fondsPropresRequis)}',
            thresholdLabel: 'Min 20%',
            isOk: result.fondsPropresOk,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(AffordabilityResult result, S l) {
    final lppNonUtilise = _avoirLpp - result.lppUtilise;

    // Determine insight content based on binding constraint
    final IconData icon;
    final String title;
    final String body;

    if (result.isRevenueConstrained && result.fondsPropresOk) {
      icon = Icons.lightbulb_outline;
      title = l.affordabilityInsightRevenueTitle;
      body = l.affordabilityInsightRevenueBody(
        formatChf(result.chargesTheoriquesMensuelles),
        formatChf(result.chargesReellesMensuelles),
      );
    } else if (!result.fondsPropresOk) {
      icon = Icons.account_balance_wallet_outlined;
      title = l.affordabilityInsightEquityTitle;
      body = l.affordabilityInsightEquityBody(
        formatChf(result.manqueFondsPropres),
      );
    } else {
      icon = Icons.check_circle_outline;
      title = l.affordabilityInsightOkTitle;
      body = l.affordabilityInsightOkBody;
    }

    return Semantics(
      label: title,
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.info.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: MintColors.info, size: 20),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: MintTextStyles.bodySmall(color: MintColors.info),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              body,
              style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
            ),
            if (lppNonUtilise > 0) ...[
              const SizedBox(height: MintSpacing.sm),
              Text(
                l.affordabilityInsightLppCap(
                  formatChf(result.lppUtilise),
                  formatChf(_avoirLpp),
                ),
                style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ],
          ],
        ),
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
    final l = S.of(context)!;

    return Semantics(
      label: '$label: $displayValue',
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOk ? l.affordabilityOk : l.affordabilityExceeded,
                  style: MintTextStyles.labelSmall(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
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
          const SizedBox(height: MintSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayValue,
                style: MintTextStyles.labelSmall(color: color),
              ),
              Text(
                thresholdLabel,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlidersSection(S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + MintSpacing.xs),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.affordabilityParameters,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),

          // ── Canton ──
          Semantics(
            label: l.affordabilityCanton,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.affordabilityCanton,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm + MintSpacing.xs),
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

          // ── Primary sliders (max 3 visible — Design System §2B) ──
          // Revenu brut annuel
          _buildSliderRow(
            label: l.affordabilityGrossIncome,
            value: _revenuBrut,
            min: 50000,
            max: 300000,
            divisions: 50,
            format: 'CHF ${formatChf(_revenuBrut)}',
            onChanged: (v) => setState(() => _revenuBrut = v),
          ),
          const SizedBox(height: MintSpacing.sm + MintSpacing.xs),

          // Prix d'achat
          _buildSliderRow(
            label: l.affordabilityTargetPrice,
            value: _prixAchat,
            min: 200000,
            max: 3000000,
            divisions: 56,
            format: 'CHF ${formatChf(_prixAchat)}',
            onChanged: (v) => setState(() => _prixAchat = v),
          ),
          const SizedBox(height: MintSpacing.sm + MintSpacing.xs),

          // Epargne disponible
          _buildSliderRow(
            label: l.affordabilityAvailableSavings,
            value: _epargneDispo,
            min: 0,
            max: 500000,
            divisions: 100,
            format: 'CHF ${formatChf(_epargneDispo)}',
            onChanged: (v) => setState(() => _epargneDispo = v),
          ),

          // ── Progressive disclosure: 3a + LPP behind toggle ──
          const SizedBox(height: MintSpacing.md),
          Semantics(
            button: true,
            label: l.affordabilityAdvancedParams,
            child: GestureDetector(
              onTap: () => setState(() => _showAdvancedParams = !_showAdvancedParams),
              child: Row(
                children: [
                  Icon(
                    _showAdvancedParams
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: MintColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: MintSpacing.xs),
                  Text(
                    l.affordabilityAdvancedParams,
                    style: MintTextStyles.bodySmall(color: MintColors.info),
                  ),
                ],
              ),
            ),
          ),
          if (_showAdvancedParams) ...[
            const SizedBox(height: MintSpacing.sm + MintSpacing.xs),
            // Avoir 3a
            _buildSliderRow(
              label: l.affordabilityPillar3a,
              value: _avoir3a,
              min: 0,
              max: 300000,
              divisions: 60,
              format: 'CHF ${formatChf(_avoir3a)}',
              onChanged: (v) => setState(() => _avoir3a = v),
            ),
            const SizedBox(height: MintSpacing.sm + MintSpacing.xs),

            // Avoir LPP
            _buildSliderRow(
              label: l.affordabilityPillarLpp,
              value: _avoirLpp,
              min: 0,
              max: 500000,
              divisions: 100,
              format: 'CHF ${formatChf(_avoirLpp)}',
              onChanged: (v) => setState(() => _avoirLpp = v),
            ),
          ],
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
    return MintPremiumSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      formatValue: (_) => format,
      onChanged: onChanged,
    );
  }

  Widget _buildDetailSection(AffordabilityResult result, S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + MintSpacing.xs),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.affordabilityCalculationDetail,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildInfoRow(l.affordabilityTargetPrice,
              'CHF ${formatChf(_prixAchat)}'),
          _buildInfoRow(l.affordabilityEquityRequired,
              'CHF ${formatChf(result.fondsPropresRequis)}'),
          const Divider(height: MintSpacing.md + MintSpacing.xs),
          _buildInfoRow(l.affordabilitySavingsLabel,
              'CHF ${formatChf(_epargneDispo)}'),
          _buildInfoRow(l.affordabilityPillar3a,
              'CHF ${formatChf(_avoir3a)}'),
          _buildInfoRow(
              l.affordabilityLppMax10,
              'CHF ${formatChf(min(_avoirLpp, _prixAchat * 0.10))}'),
          _buildInfoRow(l.affordabilityTotalEquity,
              'CHF ${formatChf(result.fondsPropresTotal)}',
              isBold: true,
              color: result.fondsPropresOk
                  ? MintColors.success
                  : MintColors.error),
          const Divider(height: MintSpacing.md + MintSpacing.xs),
          () {
            final hypothequeReelle = max(0.0, _prixAchat - result.fondsPropresTotal);
            final ltvPct = _prixAchat > 0 ? (hypothequeReelle / _prixAchat * 100).toStringAsFixed(0) : '0';
            return _buildInfoRow(
              l.affordabilityMortgagePercent(ltvPct),
              'CHF ${formatChf(hypothequeReelle)}',
            );
          }(),
          _buildInfoRow(l.affordabilityMonthlyCharges,
              'CHF ${formatChf(result.chargesTheoriquesMensuelles)}'),
          _buildInfoRow(
            l.affordabilityChargesRatio,
            '${(result.ratioCharges * 100).toStringAsFixed(1)}%',
            isBold: true,
            color: result.capaciteOk
                ? MintColors.success
                : MintColors.error,
          ),
          const SizedBox(height: MintSpacing.sm + MintSpacing.xs),
          Text(
            l.affordabilityCalculationNote,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
        ],
      ),
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
            style: MintTextStyles.bodySmall(
              color: color ?? MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedSections(S l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: MintSpacing.lg),
        Text(
          l.affordabilityExploreAlso,
          style: MintTextStyles.titleMedium(),
        ),
        const SizedBox(height: MintSpacing.sm + MintSpacing.xs),
        CollapsibleSection(
          title: l.affordabilityRelatedAmortTitle,
          subtitle: l.affordabilityRelatedAmortSubtitle,
          icon: Icons.compare_arrows,
          child: _buildSectionCta(l.affordabilityRelatedSimulate, '/mortgage/amortization'),
        ),
        CollapsibleSection(
          title: l.affordabilityRelatedSaronTitle,
          subtitle: l.affordabilityRelatedSaronSubtitle,
          icon: Icons.swap_horiz,
          child: _buildSectionCta(l.affordabilityRelatedCompare, '/mortgage/saron-vs-fixed'),
        ),
        CollapsibleSection(
          title: l.affordabilityRelatedValeurTitle,
          subtitle: l.affordabilityRelatedValeurSubtitle,
          icon: Icons.home_work_outlined,
          child: _buildSectionCta(l.affordabilityRelatedCalculate, '/mortgage/imputed-rental'),
        ),
        CollapsibleSection(
          title: l.affordabilityRelatedEplTitle,
          subtitle: l.affordabilityRelatedEplSubtitle,
          icon: Icons.account_balance_outlined,
          child: _buildSectionCta(l.affordabilityRelatedSimulate, '/mortgage/epl-combined'),
        ),
      ],
    );
  }

  Widget _buildSectionCta(String label, String route) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => context.push(route),
        child: Text(label),
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
          const SizedBox(width: MintSpacing.sm + MintSpacing.xs),
          Expanded(
            child: Text(
              disclaimer,
              style: MintTextStyles.micro(),
            ),
          ),
        ],
      ),
    );
  }
}
