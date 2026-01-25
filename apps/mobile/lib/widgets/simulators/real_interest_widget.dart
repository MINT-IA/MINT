import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/simulators/real_interest_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';

class RealInterestWidget extends StatefulWidget {
  final double initialAmount;
  final double marginalTaxRate;

  const RealInterestWidget({
    super.key,
    required this.initialAmount,
    required this.marginalTaxRate,
  });

  @override
  State<RealInterestWidget> createState() => _RealInterestWidgetState();
}

class _RealInterestWidgetState extends State<RealInterestWidget> {
  late double _amount;
  int _duration = 10;

  @override
  void initState() {
    super.initState();
    _amount = widget.initialAmount;
  }

  @override
  Widget build(BuildContext context) {
    // Calcul live
    final result = RealInterestCalculator.simulate(
      amountInvested: _amount,
      marginalTaxRate: widget.marginalTaxRate,
      investmentDurationYears: _duration,
    );

    return SimulatorCard(
      title: "Simulateur d'Intérêt Réel",
      subtitle: "Capital + Économie d'impôt réinvestie (Virtuel)",
      icon: Icons.auto_graph,
      child: Column(
        children: [
          // Inputs
          _buildSlider(
            label: "Montant Investi",
            value: _amount,
            min: 1000,
            max: 36000,
            divisions: 35,
            unit: "CHF",
            onChanged: (v) => setState(() => _amount = v),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: "Durée",
            value: _duration.toDouble(),
            min: 5,
            max: 30,
            divisions: 25,
            unit: "ans",
            onChanged: (v) => setState(() => _duration = v.toInt()),
          ),

          const SizedBox(height: 24),

          // Result visualization (Scenarios)
          Row(
            children: [
              _buildScenarioCard(
                  "Pessimiste", result.pessimistic, MintColors.textSecondary),
              const SizedBox(width: 12),
              _buildScenarioCard("Neutre", result.neutral, MintColors.primary,
                  isMain: true),
              const SizedBox(width: 12),
              _buildScenarioCard(
                  "Optimiste", result.optimistic, MintColors.success),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            "Hypothèses: Taux marginal ${(widget.marginalTaxRate * 100).toStringAsFixed(1)}%. Rendements marché: 2% / 4% / 6%.",
            style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioCard(
      String title, RealInterestScenario scenario, Color color,
      {bool isMain = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isMain ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: isMain ? color : MintColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(title,
                style: GoogleFonts.outfit(
                    fontSize: 12, color: MintColors.textSecondary)),
            const SizedBox(height: 8),
            Text(
              "CHF ${(scenario.totalCapital / 1000).toStringAsFixed(1)}k",
              style: GoogleFonts.outfit(
                fontSize: isMain ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "+${(scenario.effectiveYield * 100).toStringAsFixed(1)}%",
              style: GoogleFonts.inter(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
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
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w500)),
            Text(
              "${value.toInt()} $unit",
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: MintColors.primary),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.border,
            thumbColor: Colors.white,
            overlayColor: MintColors.primary.withOpacity(0.1),
            thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8, elevation: 2),
            trackHeight: 4,
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
