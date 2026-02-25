import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'dart:math' as math;

/// Scénario de simulation (prudence/central/stress)
class SimulationScenario {
  final String label;
  final double rate;
  final Color color;
  final String description;

  const SimulationScenario({
    required this.label,
    required this.rate,
    required this.color,
    required this.description,
  });

  static const prudence = SimulationScenario(
    label: 'Prudence',
    rate: 0.5,
    color: Colors.orange,
    description: 'Compte épargne (0.5%)',
  );

  static const central = SimulationScenario(
    label: 'Central',
    rate: 3.0,
    color: Color(0xFF81C784),
    description: '3a conservateur (3%)',
  );

  static const stress = SimulationScenario(
    label: 'Stress',
    rate: 5.0,
    color: Color(0xFF2D6A4F),
    description: '3a équilibré (5%)',
  );

  static const all = [prudence, central, stress];
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
        borderRadius: const BorderRadius.circular(20),
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
                'Projection Intérêts Composés',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'CHF ${monthlyAmount.toStringAsFixed(0)}/mois pendant $years ans',
            style: const TextStyle(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hypothèses pédagogiques (inflation $inflation%). Les rendements passés ne garantissent pas les rendements futurs.',
                    style: const TextStyle(fontSize: 11, color: Colors.orange),
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
                            scenario.label,
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
                        borderRadius: const BorderRadius.vertical(top: const Radius.circular(8)),
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
                          (data['scenario'] as SimulationScenario).description,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'CHF ${(data['futureValue'] as double).toStringAsFixed(0)} (dont CHF ${(data['interest'] as double).toStringAsFixed(0)} d\'intérêts)',
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
    final taxSavings = buybackAmount * (marginalTaxRate / 100);
    final annualPensionIncrease = buybackAmount * (conversionRate / 100);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: const BorderRadius.circular(20),
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
                'Impact Rachat LPP',
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
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Hypothèses :',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '• Taux marginal : ${marginalTaxRate.toStringAsFixed(0)}% (estimé selon canton/revenu)',
                  style: const TextStyle(fontSize: 11, color: Colors.orange),
                ),
                Text(
                  '• Taux de conversion LPP : ${conversionRate.toStringAsFixed(1)}% (hypothèse actuelle)',
                  style: const TextStyle(fontSize: 11, color: Colors.orange),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Vérifie avec ton certificat LPP et un·e spécialiste en fiscalité.',
                  style: TextStyle(fontSize: 10, color: Colors.orange, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          _buildMetric(
            'Rachat',
            'CHF ${buybackAmount.toStringAsFixed(0)}',
            Icons.trending_up,
            MintColors.primary,
          ),
          const SizedBox(height: 16),
          _buildMetric(
            'Économie fiscale immédiate',
            'CHF ${taxSavings.toStringAsFixed(0)}',
            Icons.savings,
            Colors.green,
          ),
          const SizedBox(height: 16),
          _buildMetric(
            'Augmentation rente (dès 65 ans)',
            '+CHF ${annualPensionIncrease.toStringAsFixed(0)}/an',
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
