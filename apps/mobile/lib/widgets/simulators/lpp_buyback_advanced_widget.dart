import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _totalPotential = widget.initialPotential;
    _yearsToRetirement = widget.initialYearsUntilRetirement;
  }

  @override
  Widget build(BuildContext context) {
    final result = LppBuybackAdvancedSimulator.simulate(
      totalBuybackPotential: _totalPotential,
      yearsUntilRetirement: _yearsToRetirement,
      staggeringYears: _staggeringYears,
      annualInterestRate: _fundRate,
      taxableIncome: _taxableIncome,
    );

    return SimulatorCard(
      title: "Optimisation de Rachat LPP",
      subtitle: "Effet levier fiscal + Capitalisation",
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
    return Column(
      children: [
        _buildSlider(
          label: "Potentiel de rachat",
          value: _totalPotential,
          min: 50000,
          max: 500000,
          divisions: 45,
          unit: "CHF",
          onChanged: (v) => setState(() => _totalPotential = v),
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: "Années jusqu'à la retraite",
          value: _yearsToRetirement.toDouble(),
          min: 3,
          max: 25,
          divisions: 22,
          unit: "ans",
          onChanged: (v) => setState(() => _yearsToRetirement = v.toInt()),
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: "Lissage (staggering)",
          value: _staggeringYears.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          unit: "ans",
          onChanged: (v) => setState(() => _staggeringYears = v.toInt()),
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: "Taux de la caisse LPP",
          value: _fundRate * 100,
          min: 1,
          max: 4,
          divisions: 6,
          unit: "%",
          onChanged: (v) => setState(() => _fundRate = v / 100),
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: "Revenu imposable",
          value: _taxableIncome,
          min: 50000,
          max: 300000,
          divisions: 25,
          unit: "CHF",
          onChanged: (v) => setState(() => _taxableIncome = v),
        ),
      ],
    );
  }

  Widget _buildPrimaryResult(LppAdvancedResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MintColors.primary, MintColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Valeur Finale Capitalisée",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "CHF ${result.finalCapital.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}\'')}",
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Rendement Réel : ${(result.realAnnualReturn * 100).toStringAsFixed(1)}% / an",
              style: const TextStyle(
                color: Colors.white,
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
    return Row(
      children: [
        _buildSmallMetric(
          "Économie Impôts",
          "CHF ${result.totalTaxSavings.toStringAsFixed(0)}",
          Icons.savings_outlined,
          Colors.green,
        ),
        const SizedBox(width: 12),
        _buildSmallMetric(
          "Effort Net",
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
          color: color.withValues(alpha: 0.05),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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
          const Text(
            "Gain Total de l'opération",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Capital - Effort Net",
                  style:
                      TextStyle(color: MintColors.textSecondary, fontSize: 13)),
              Text(
                "+ CHF ${result.totalValueGained.toStringAsFixed(0)}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Taux LPP servi",
                  style: const TextStyle(
                      color: MintColors.textMuted, fontSize: 12)),
              Text("${(_fundRate * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Effet levier fiscal",
                  style: const TextStyle(
                      color: MintColors.textMuted, fontSize: 12)),
              Text(
                  "+${((result.realAnnualReturn - _fundRate) * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBonASavoir() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.accentPastel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MintColors.border.withValues(alpha: 0.3)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.lightbulb_outline,
              color: MintColors.primary, size: 20),
          title: Text(
            "Bon a savoir",
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: MintColors.primary,
            ),
          ),
          children: [
            _buildBonASavoirItem(
              "Le rachat LPP est l'un des rares outils de planification "
              "fiscale accessibles a tous les salarie\u00B7e\u00B7s en Suisse.",
            ),
            const SizedBox(height: 10),
            _buildBonASavoirItem(
              "Chaque franc rachete est deductible de ton revenu imposable "
              "(LIFD art. 33 al. 1 let. d).",
            ),
            const SizedBox(height: 10),
            _buildBonASavoirItem(
              "Attention : tout retrait EPL est bloque pendant 3 ans "
              "apres un rachat (LPP art. 79b al. 3).",
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
    return Text(
      "Simulation incluant l'interet de la caisse (${(_fundRate * 100).toStringAsFixed(1)}%) et l'economie d'impot lissee sur $_staggeringYears ans pour un revenu imposable de CHF ${_taxableIncome.toStringAsFixed(0)}. Le rendement reel est calcule sur ton effort net reel.",
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
            thumbColor: Colors.white,
            overlayColor: MintColors.primary.withValues(alpha: 0.1),
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
