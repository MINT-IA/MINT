import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  FINANCIAL WEATHER WIDGET — P1-D / S42 UX Redesign
// ────────────────────────────────────────────────────────────
//
//  Remplace Monte Carlo par une metaphore meteo intuitive.
//  "Personne ne comprend 10'000 simulations a 80% de succes.
//   Tout le monde comprend la meteo."
//
//  Widget pur — aucune dependance Provider.
//  Lois : L7 (metaphore bat graphique) + L4 (raconte)
// ────────────────────────────────────────────────────────────

/// Weather condition for retirement outlook.
enum FinancialWeather {
  sunny,
  partlyCloudy,
  rainy,
}

/// Single weather scenario with probability.
class WeatherScenario {
  final FinancialWeather weather;
  final double probabilityPercent;
  final double monthlyIncomeMin;
  final double monthlyIncomeMax;
  final String description;

  const WeatherScenario({
    required this.weather,
    required this.probabilityPercent,
    required this.monthlyIncomeMin,
    required this.monthlyIncomeMax,
    required this.description,
  });
}

class FinancialWeatherWidget extends StatelessWidget {
  /// The 3 weather scenarios (sunny, partly cloudy, rainy).
  final List<WeatherScenario> scenarios;

  /// Current overall outlook (which weather best describes the user).
  final FinancialWeather currentOutlook;

  /// Trend direction relative to last month.
  final FinancialWeather? trendTowards;

  const FinancialWeatherWidget({
    super.key,
    required this.scenarios,
    required this.currentOutlook,
    this.trendTowards,
  });

  String _weatherEmoji(FinancialWeather w) {
    switch (w) {
      case FinancialWeather.sunny:
        return '\u2600\ufe0f'; // ☀️
      case FinancialWeather.partlyCloudy:
        return '\u26c5'; // ⛅
      case FinancialWeather.rainy:
        return '\ud83c\udf27\ufe0f'; // 🌧️
    }
  }

  String _weatherLabel(FinancialWeather w) {
    switch (w) {
      case FinancialWeather.sunny:
        return 'Soleil';
      case FinancialWeather.partlyCloudy:
        return 'Nuageux';
      case FinancialWeather.rainy:
        return 'Pluie';
    }
  }

  Color _weatherColor(FinancialWeather w) {
    switch (w) {
      case FinancialWeather.sunny:
        return MintColors.scoreExcellent;
      case FinancialWeather.partlyCloudy:
        return MintColors.scoreAttention;
      case FinancialWeather.rainy:
        return MintColors.scoreCritique;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'M\u00e9t\u00e9o financi\u00e8re. Perspective actuelle\u00a0: ${_weatherLabel(currentOutlook)}.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Text(
              'Ta m\u00e9t\u00e9o financi\u00e8re \u00e0 la retraite',
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
            ),
            const SizedBox(height: 16),

            // ── Scenarios ──
            ...scenarios.map((s) => _buildScenarioRow(s)),

            // ── Current outlook ──
            const SizedBox(height: 16),
            _buildCurrentOutlook(),

            // ── Disclaimer ──
            const SizedBox(height: 12),
            Text(
              'Bas\u00e9 sur des sc\u00e9narios de march\u00e9 \u2014 outil \u00e9ducatif, pas un conseil (LSFin).',
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioRow(WeatherScenario scenario) {
    final color = _weatherColor(scenario.weather);
    final isActive = scenario.weather == currentOutlook;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.08)
              : MintColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: color.withValues(alpha: 0.25))
              : null,
        ),
        child: Row(
          children: [
            Text(
              _weatherEmoji(scenario.weather),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _weatherLabel(scenario.weather),
                        style: MintTextStyles.bodyMedium(color: color).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${scenario.probabilityPercent.toStringAsFixed(0)}% des cas)',
                        style: MintTextStyles.labelMedium(color: MintColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scenario.description,
                    style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatChfWithPrefix(scenario.monthlyIncomeMin)}\u2013${formatChfWithPrefix(scenario.monthlyIncomeMax)}/mois',
                    style: MintTextStyles.labelMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.arrow_back, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentOutlook() {
    final color = _weatherColor(currentOutlook);
    final trendText = trendTowards != null
        ? ' tendance ${_weatherEmoji(trendTowards!)}'
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Aujourd\u2019hui\u00a0: ${_weatherEmoji(currentOutlook)} ${_weatherLabel(currentOutlook)}$trendText',
            style: MintTextStyles.bodyMedium(color: color).copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Chaque action d\u00e9place le curseur',
            style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
