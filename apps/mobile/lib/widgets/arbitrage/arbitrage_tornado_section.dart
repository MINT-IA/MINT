import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/services/financial_core/tornado_sensitivity_service.dart';
import 'package:mint_mobile/widgets/retirement/tornado_chart.dart';

/// Standard Tornado section for arbitrage screens.
///
/// Reconstructs normalized Tornado variables from `result.sensitivity`
/// using the `tornado_*` key convention.
class ArbitrageTornadoSection extends StatelessWidget {
  final ArbitrageResult result;
  final String? subtitle;

  const ArbitrageTornadoSection({
    super.key,
    required this.result,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final variables = result.tornadoVariables;
    if (variables.isEmpty) return const SizedBox.shrink();

    final base = variables.first.baseValue;
    final chartVariables = variables
        .map((v) => TornadoVariable(
              label: v.label,
              category: v.category,
              baseValue: v.baseValue,
              lowValue: v.lowValue,
              highValue: v.highValue,
              swing: v.swing,
              lowLabel: v.lowLabel,
              highLabel: v.highLabel,
            ))
        .toList();

    return TornadoChart(
      baseCase: base,
      variables: chartVariables,
      maxVariables: 8,
      title: s.arbitrageTornadoTitle,
      subtitle: subtitle ?? s.arbitrageTornadoDefaultSubtitle,
      baseCaseSuffix: '',
      disclaimerText: s.arbitrageTornadoDisclaimer,
    );
  }
}
