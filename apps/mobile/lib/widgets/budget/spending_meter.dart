import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SpendingMeter extends StatelessWidget {
  final double variablesAmount;
  final double futureAmount;
  final double totalAvailable;
  final String currency;

  const SpendingMeter({
    super.key,
    required this.variablesAmount,
    required this.futureAmount,
    required this.totalAvailable,
    this.currency = 'CHF',
  });

  @override
  Widget build(BuildContext context) {
    // Si tout est à 0 (cas edge)
    if (totalAvailable <= 0) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("Budget non disponible")),
      );
    }

    final double variablesPercent = (variablesAmount / totalAvailable) * 100;
    final double futurePercent = (futureAmount / totalAvailable) * 100;

    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              startDegreeOffset: 270, // Start from top
              sections: [
                PieChartSectionData(
                  color: Colors.tealAccent.shade400,
                  value: variablesAmount,
                  title: '${variablesPercent.toStringAsFixed(0)}%',
                  radius: 25,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                PieChartSectionData(
                  color: Colors.indigo.shade300,
                  value: futureAmount,
                  title: futurePercent > 0
                      ? '${futurePercent.toStringAsFixed(0)}%'
                      : '',
                  radius: 20,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Variables',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$currency ${variablesAmount.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.tealAccent.shade700,
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
