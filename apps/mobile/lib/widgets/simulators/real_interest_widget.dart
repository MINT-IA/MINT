import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
      title: S.of(context)!.realInterestSimulatorTitle,
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

          const SizedBox(height: 20),

          // Educational footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.info.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.info.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_outlined,
                        color: MintColors.info, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Comprendre le rendement réel",
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: MintColors.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBulletPoint(
                  "Le rendement réel = rendement nominal \u2212 inflation \u2212 frais",
                ),
                const SizedBox(height: 6),
                _buildBulletPoint(
                  "Un placement à 3% avec 1.5% d'inflation et 0.5% de frais rapporte seulement 1% en réel",
                ),
                const SizedBox(height: 6),
                _buildBulletPoint(
                  "Sur 30 ans, cette différence peut représenter des dizaines de milliers de francs",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: MintColors.info,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
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
                style: GoogleFonts.montserrat(
                    fontSize: 12, color: MintColors.textSecondary)),
            const SizedBox(height: 8),
            Text(
              "CHF ${(scenario.totalCapital / 1000).toStringAsFixed(1)}k",
              style: GoogleFonts.montserrat(
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
              style: GoogleFonts.montserrat(
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
            thumbColor: MintColors.white,
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
