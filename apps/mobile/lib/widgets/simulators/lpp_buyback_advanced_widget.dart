import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/simulators/lpp_buyback_advanced_simulator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';

class LppBuybackAdvancedWidget extends StatefulWidget {
  final double initialPotential;
  final int initialYearsUntilRetirement;

  const LppBuybackAdvancedWidget({
    super.key,
    this.initialPotential = 300000,
    this.initialYearsUntilRetirement = 13,
  });

  @override
  State<LppBuybackAdvancedWidget> createState() =>
      _LppBuybackAdvancedWidgetState();
}

class _LppBuybackAdvancedWidgetState extends State<LppBuybackAdvancedWidget> {
  late double _totalPotential;
  late int _yearsToRetirement;
  int _staggeringYears = 5;
  double _fundRate = 0.02;
  double _taxableIncome = 120000;
  final String _canton = 'ZH';

  @override
  void initState() {
    super.initState();
    _totalPotential = widget.initialPotential;
    _yearsToRetirement = widget.initialYearsUntilRetirement;
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final result = LppBuybackAdvancedSimulator.simulate(
      totalBuybackPotential: _totalPotential,
      yearsUntilRetirement: _yearsToRetirement,
      staggeringYears: _staggeringYears,
      annualInterestRate: _fundRate,
      taxableIncome: _taxableIncome,
      canton: _canton,
    );

    return SimulatorCard(
      title: l.simLppBuybackTitle,
      subtitle: l.simLppBuybackSubtitle,
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputSection(),
          const SizedBox(height: 24),
          _buildPrimaryResult(result),
          const SizedBox(height: 24),
          _buildMetricsGrid(result),
          const SizedBox(height: 24),
          _buildComparisonSection(result),
          const SizedBox(height: 24),
          _buildBonASavoir(),
          const SizedBox(height: 16),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    final l = S.of(context)!;
    return Column(
      children: [
        _buildSlider(
          label: l.simLppBuybackPotential,
          value: _totalPotential,
          min: 50000,
          max: 500000,
          divisions: 45,
          unit: l.simLppBuybackUnitChf,
          onChanged: (v) => setState(() => _totalPotential = v),
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: l.simLppBuybackYearsToRetirement,
          value: _yearsToRetirement.toDouble(),
          min: 3,
          max: 25,
          divisions: 22,
          unit: l.simLppBuybackUnitYears,
          onChanged: (v) => setState(() => _yearsToRetirement = v.toInt()),
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: l.simLppBuybackStaggering,
          value: _staggeringYears.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          unit: l.simLppBuybackUnitYears,
          onChanged: (v) => setState(() => _staggeringYears = v.toInt()),
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: l.simLppBuybackFundRate,
          value: _fundRate * 100,
          min: 1,
          max: 4,
          divisions: 6,
          unit: "%",
          onChanged: (v) => setState(() => _fundRate = v / 100),
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: l.simLppBuybackTaxableIncome,
          value: _taxableIncome,
          min: 50000,
          max: 300000,
          divisions: 25,
          unit: l.simLppBuybackUnitChf,
          onChanged: (v) => setState(() => _taxableIncome = v),
        ),
      ],
    );
  }

  Widget _buildPrimaryResult(LppAdvancedResult result) {
    final l = S.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MintColors.primary, MintColors.primary.withValues(alpha:0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha:0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            l.simLppBuybackFinalCapital,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "CHF ${result.finalCapital.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}\'')}",
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: MintColors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: MintColors.white.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l.simLppBuybackRealReturn(
                (result.realAnnualReturn * 100).toStringAsFixed(1),
              ),
              style: const TextStyle(
                color: MintColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(LppAdvancedResult result) {
    final l = S.of(context)!;
    return Row(
      children: [
        _buildSmallMetric(
          l.simLppBuybackTaxSavings,
          "CHF ${result.totalTaxSavings.toStringAsFixed(0)}",
          Icons.savings_outlined,
          MintColors.success,
        ),
        const SizedBox(width: 12),
        _buildSmallMetric(
          l.simLppBuybackNetEffort,
          "CHF ${result.netEffort.toStringAsFixed(0)}",
          Icons.payments_outlined,
          MintColors.primary,
        ),
      ],
    );
  }

  Widget _buildSmallMetric(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.05),
          border: Border.all(color: color.withValues(alpha:0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: MintColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonSection(LppAdvancedResult result) {
    final l = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.simLppBuybackTotalGain,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.simLppBuybackCapitalMinusEffort,
                  style:
                      const TextStyle(color: MintColors.textSecondary, fontSize: 13)),
              Text(
                "+ CHF ${result.totalValueGained.toStringAsFixed(0)}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: MintColors.success),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.simLppBuybackFundRateLabel,
                  style: const TextStyle(
                      color: MintColors.textMuted, fontSize: 12)),
              Text("${(_fundRate * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.simLppBuybackFiscalLeverage,
                  style: const TextStyle(
                      color: MintColors.textMuted, fontSize: 12)),
              Text(
                  "+${((result.realAnnualReturn - _fundRate) * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(
                      color: MintColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBonASavoir() {
    final l = S.of(context)!;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: MintColors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.accentPastel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MintColors.border.withValues(alpha:0.3)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.lightbulb_outline,
              color: MintColors.primary, size: 20),
          title: Text(
            l.simLppBuybackBonASavoir,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: MintColors.primary,
            ),
          ),
          children: [
            _buildBonASavoirItem(l.simLppBuybackBonASavoirItem1),
            const SizedBox(height: 10),
            _buildBonASavoirItem(l.simLppBuybackBonASavoirItem2),
            const SizedBox(height: 10),
            _buildBonASavoirItem(
              l.simLppBuybackBonASavoirItem3,
              isWarning: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonASavoirItem(String text, {bool isWarning = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 16,
            color: isWarning ? MintColors.warning : MintColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    final l = S.of(context)!;
    return Text(
      l.simLppBuybackDisclaimer(
        (_fundRate * 100).toStringAsFixed(1),
        _staggeringYears,
        _taxableIncome.toStringAsFixed(0),
      ),
      style: GoogleFonts.inter(
          fontSize: 10,
          color: MintColors.textMuted,
          fontStyle: FontStyle.italic),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text(
              "${value.toInt()} $unit",
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: MintColors.primary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.border,
            thumbColor: MintColors.white,
            overlayColor: MintColors.primary.withValues(alpha:0.1),
            thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 6, elevation: 1),
            trackHeight: 2,
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
}
