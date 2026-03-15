import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'dart:math' as math;

/// Scénario de simulation (prudence/central/stress)
class SimulationScenario {
  final String Function(S) labelResolver;
  final double rate;
  final Color color;
  final String Function(S) descriptionResolver;

  const SimulationScenario({
    required this.labelResolver,
    required this.rate,
    required this.color,
    required this.descriptionResolver,
  });

  String label(S s) => labelResolver(s);
  String description(S s) => descriptionResolver(s);

  static final prudence = SimulationScenario(
    labelResolver: (s) => s.simulationScenarioPrudenceLabel,
    rate: 0.5,
    color: MintColors.warning,
    descriptionResolver: (s) => s.simulationScenarioPrudenceDesc,
  );

  static final central = SimulationScenario(
    labelResolver: (s) => s.simulationScenarioCentralLabel,
    rate: 3.0,
    color: MintColors.centralScenarioLight,
    descriptionResolver: (s) => s.simulationScenarioCentralDesc,
  );

  static final stress = SimulationScenario(
    labelResolver: (s) => s.simulationScenarioStressLabel,
    rate: 5.0,
    color: MintColors.stressScenario,
    descriptionResolver: (s) => s.simulationScenarioStressDesc,
  );

  static final all = [prudence, central, stress];
}

/// Graphique d'intérêts composés (scénarios prudence/central/stress)
class CompoundInterestChart extends StatelessWidget {
  final double monthlyAmount;
  final int years;
  final double inflation;

  const CompoundInterestChart({
    super.key,
    required this.monthlyAmount,
    required this.years,
    this.inflation = 1.5,
  });

  double _calculateFutureValue(double monthly, double annualRate, int years) {
    final monthlyRate = annualRate / 12 / 100;
    final months = years * 12;
    if (monthlyRate == 0) return monthly * months;
    return monthly * ((math.pow(1 + monthlyRate, months) - 1) / monthlyRate);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final scenarios = SimulationScenario.all.map((scenario) {
      final futureValue = _calculateFutureValue(monthlyAmount, scenario.rate, years);
      final totalContributions = monthlyAmount * years * 12;
      final interest = futureValue - totalContributions;

      return {
        'scenario': scenario,
        'futureValue': futureValue,
        'contributions': totalContributions,
        'interest': interest,
      };
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: MintColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                s.simulationCompoundTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.simulationCompoundSubtitle(monthlyAmount.toStringAsFixed(0), years.toString()),
            style: const TextStyle(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.warningBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MintColors.orangeRetroWarm),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: MintColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.simulationCompoundDisclaimer(inflation.toString()),
                    style: const TextStyle(fontSize: 11, color: MintColors.warning),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Graphique
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (scenarios.last['futureValue'] as double) * 1.1,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= scenarios.length) return const SizedBox();
                        final scenario = scenarios[value.toInt()]['scenario'] as SimulationScenario;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            scenario.label(s),
                            style: const TextStyle(fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          'CHF ${(value / 1000).toStringAsFixed(0)}k',
                          style: const TextStyle(fontSize: 10, color: MintColors.textMuted),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50000,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: MintColors.border,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: scenarios.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final data = entry.value;
                  final scenario = data['scenario'] as SimulationScenario;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: data['futureValue'] as double,
                        color: scenario.color,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Détails
          for (var data in scenarios)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: (data['scenario'] as SimulationScenario).color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (data['scenario'] as SimulationScenario).description(s),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          s.simulationCompoundDetail((data['futureValue'] as double).toStringAsFixed(0), (data['interest'] as double).toStringAsFixed(0)),
                          style: const TextStyle(fontSize: 12, color: MintColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Simulation rachat LPP (avec hypothèses explicites)
class LppBuybackSimulation extends StatelessWidget {
  final double buybackAmount;
  final double marginalTaxRate;
  final double conversionRate;

  const LppBuybackSimulation({
    super.key,
    required this.buybackAmount,
    required this.marginalTaxRate,
    this.conversionRate = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final taxSavings = buybackAmount * (marginalTaxRate / 100);
    final annualPensionIncrease = buybackAmount * (conversionRate / 100);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance, color: MintColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                s.simulationLppBuybackTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.warningBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MintColors.orangeRetroWarm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: MintColors.warning),
                    const SizedBox(width: 8),
                    Text(
                      s.simulationLppHypothesesLabel,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: MintColors.warning),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  s.simulationLppHypothesisTaux(marginalTaxRate.toStringAsFixed(0)),
                  style: const TextStyle(fontSize: 11, color: MintColors.warning),
                ),
                Text(
                  s.simulationLppHypothesisConversion(conversionRate.toStringAsFixed(1)),
                  style: const TextStyle(fontSize: 11, color: MintColors.warning),
                ),
                const SizedBox(height: 4),
                Text(
                  s.simulationLppHypothesisVerifie,
                  style: const TextStyle(fontSize: 10, color: MintColors.warning, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildMetric(
            s.simulationLppMetricRachat,
            'CHF ${buybackAmount.toStringAsFixed(0)}',
            Icons.trending_up,
            MintColors.primary,
          ),
          const SizedBox(height: 16),
          _buildMetric(
            s.simulationLppMetricEconomie,
            'CHF ${taxSavings.toStringAsFixed(0)}',
            Icons.savings,
            MintColors.success,
          ),
          const SizedBox(height: 16),
          _buildMetric(
            s.simulationLppMetricAugmentation,
            s.simulationLppMetricAugmentationValue(annualPensionIncrease.toStringAsFixed(0)),
            Icons.trending_up,
            MintColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: MintColors.textSecondary),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
