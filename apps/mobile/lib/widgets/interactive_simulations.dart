import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/services/haptic_feedback_service.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'dart:math' as math;
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Widget interactif pour simulation 3a avec curseurs
class Interactive3aSimulation extends StatefulWidget {
  final double initialMonthlyContribution;
  final int initialYears;
  final bool isEmployee; // true = employé, false = indépendant

  const Interactive3aSimulation({
    super.key,
    required this.initialMonthlyContribution,
    required this.initialYears,
    required this.isEmployee,
  });

  @override
  State<Interactive3aSimulation> createState() =>
      _Interactive3aSimulationState();
}

class _Interactive3aSimulationState extends State<Interactive3aSimulation> {
  late double _monthlyContribution;
  late int _years;
  late double _marginalTaxRate;

  @override
  void initState() {
    super.initState();
    _monthlyContribution = widget.initialMonthlyContribution;
    _years = widget.initialYears;
    _marginalTaxRate = 25.0; // Défaut
  }

  double _calculateFutureValue(double monthly, double annualRate, int years) {
    final monthlyRate = annualRate / 12 / 100;
    final months = years * 12;
    if (monthlyRate == 0) return monthly * months;
    return monthly * ((math.pow(1 + monthlyRate, months) - 1) / monthlyRate);
  }

  double get _annualContribution => _monthlyContribution * 12;
  double get _maxAnnual => widget.isEmployee ? pilier3aPlafondAvecLpp : pilier3aPlafondSansLpp;
  bool get _exceedsLimit => _annualContribution > _maxAnnual;

  double get _taxSavings =>
      math.min(_annualContribution, _maxAnnual) * (_marginalTaxRate / 100);
  double get _realCost =>
      math.min(_annualContribution, _maxAnnual) - _taxSavings;

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final prudenceValue =
        _calculateFutureValue(_monthlyContribution, 1.0, _years);
    final centralValue =
        _calculateFutureValue(_monthlyContribution, 3.0, _years);
    final stressValue =
        _calculateFutureValue(_monthlyContribution, 5.0, _years);
    final totalTaxSavings = _taxSavings * _years;

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
              Icon(
                widget.isEmployee ? Icons.work : Icons.business_center,
                color: MintColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.isEmployee
                      ? l.taxSim3aEmployeeTitle
                      : l.taxSim3aSelfEmployedTitle,
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.taxSim3aCeiling2026(formatChfWithPrefix(_maxAnnual)),
            style:
                const TextStyle(fontSize: 12, color: MintColors.textSecondary),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Curseur 1 : Versement mensuel
          Text(
            l.taxSim3aMonthlyContribution(
                formatChfWithPrefix(_monthlyContribution)),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _monthlyContribution,
            min: 100,
            max: widget.isEmployee ? 700 : 3500,
            divisions: widget.isEmployee ? 60 : 340,
            activeColor: MintColors.primary,
            onChanged: (value) => setState(() => _monthlyContribution = value),
            onChangeEnd: (_) => HapticFeedbackService.light(),
          ),
          if (_exceedsLimit)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MintColors.warningBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      size: 16, color: MintColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.taxSim3aExceedsLimit(
                          formatChfWithPrefix(_annualContribution),
                          formatChfWithPrefix(_maxAnnual)),
                      style:
                          const TextStyle(fontSize: 11, color: MintColors.warning),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Curseur 2 : Durée
          Text(
            l.taxSim3aDuration(_years),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _years.toDouble(),
            min: 5,
            max: 40,
            divisions: 35,
            activeColor: MintColors.primary,
            onChanged: (value) => setState(() => _years = value.toInt()),
            onChangeEnd: (_) => HapticFeedbackService.light(),
          ),

          const SizedBox(height: 24),

          // Curseur 3 : Taux marginal
          Text(
            l.taxSimMarginalRate(_marginalTaxRate.toStringAsFixed(0)),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            l.taxSim3aMarginalRateHint,
            style: const TextStyle(fontSize: 11, color: MintColors.textMuted),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _marginalTaxRate,
            min: 15,
            max: 45,
            divisions: 30,
            activeColor: MintColors.primary,
            onChanged: (value) => setState(() => _marginalTaxRate = value),
            onChangeEnd: (_) => HapticFeedbackService.light(),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Résultats
          _buildMetric(
            l.taxSim3aAnnualContribution,
            formatChfWithPrefix(math.min(_annualContribution, _maxAnnual)),
            Icons.trending_up,
            MintColors.primary,
          ),
          const SizedBox(height: 16),
          _buildMetric(
            l.taxSimTaxReductionEstimated,
            '${formatChfWithPrefix(_taxSavings)}/an',
            Icons.calculate,
            MintColors.success,
          ),
          const SizedBox(height: 16),
          _buildMetric(
            l.taxSimRealCost,
            '${formatChfWithPrefix(_realCost)}/an',
            Icons.account_balance_wallet,
            MintColors.textPrimary,
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Projections
          Text(
            l.taxSim3aProjectionTitle(_years),
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildProjection(
              l.taxSim3aScenarioPrudent, prudenceValue, MintColors.warning),
          const SizedBox(height: 8),
          _buildProjection(l.taxSim3aScenarioCentral, centralValue,
              MintColors.centralScenarioLight),
          const SizedBox(height: 8),
          _buildProjection(
              l.taxSim3aScenarioStress, stressValue, MintColors.primary),

          const SizedBox(height: 16),
          _buildMetric(
            l.taxSimTaxReductionOverYears(_years),
            formatChfWithPrefix(totalTaxSavings),
            Icons.calculate,
            MintColors.amber,
          ),

          const SizedBox(height: 24),
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
                    l.interactive3aDisclaimer,
                    style: const TextStyle(fontSize: 11, color: MintColors.warning),
                  ),
                ),
              ],
            ),
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
                style: const TextStyle(
                    fontSize: 12, color: MintColors.textSecondary),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
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

  Widget _buildProjection(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          formatChfWithPrefix(value),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Widget interactif pour simulation rachat LPP
class InteractiveLppBuybackSimulation extends StatefulWidget {
  final double initialBuybackAmount;
  final double initialMarginalTaxRate;

  const InteractiveLppBuybackSimulation({
    super.key,
    required this.initialBuybackAmount,
    required this.initialMarginalTaxRate,
  });

  @override
  State<InteractiveLppBuybackSimulation> createState() =>
      _InteractiveLppBuybackSimulationState();
}

class _InteractiveLppBuybackSimulationState
    extends State<InteractiveLppBuybackSimulation> {
  late double _buybackAmount;
  late double _marginalTaxRate;
  late double _conversionRatePrudence;
  late double _conversionRateCentral;
  late double _conversionRateStress;

  @override
  void initState() {
    super.initState();
    _buybackAmount = widget.initialBuybackAmount;
    _marginalTaxRate = widget.initialMarginalTaxRate;
    _conversionRatePrudence = 5.0;
    _conversionRateCentral = 6.0;
    _conversionRateStress = 7.0;
  }

  double get _taxSavings => _buybackAmount * (_marginalTaxRate / 100);
  double get _realCost => _buybackAmount - _taxSavings;
  double get _annualPensionPrudence =>
      _buybackAmount * (_conversionRatePrudence / 100);
  double get _annualPensionCentral =>
      _buybackAmount * (_conversionRateCentral / 100);
  double get _annualPensionStress =>
      _buybackAmount * (_conversionRateStress / 100);

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
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
              const Icon(Icons.account_balance,
                  color: MintColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                l.lppBuybackTitle,
                style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Curseur 1 : Montant rachat
          Text(
            l.lppBuybackAmountLabel(formatChfWithPrefix(_buybackAmount)),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _buybackAmount,
            min: 5000,
            max: 50000,
            divisions: 90,
            activeColor: MintColors.primary,
            onChanged: (value) => setState(() => _buybackAmount = value),
            onChangeEnd: (_) => HapticFeedbackService.light(),
          ),

          const SizedBox(height: 24),

          // Curseur 2 : Taux marginal
          Text(
            l.taxSimMarginalRate(_marginalTaxRate.toStringAsFixed(0)),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            l.taxSimMarginalRateHintShort,
            style: const TextStyle(fontSize: 11, color: MintColors.textMuted),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _marginalTaxRate,
            min: 15,
            max: 45,
            divisions: 30,
            activeColor: MintColors.primary,
            onChanged: (value) => setState(() => _marginalTaxRate = value),
            onChangeEnd: (_) => HapticFeedbackService.light(),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Résultats
          _buildMetric(
            l.lppBuybackAmount,
            formatChfWithPrefix(_buybackAmount),
            Icons.trending_up,
            MintColors.primary,
          ),
          const SizedBox(height: 16),
          _buildMetric(
            l.taxSimTaxReductionEstimated,
            formatChfWithPrefix(_taxSavings),
            Icons.calculate,
            MintColors.success,
          ),
          const SizedBox(height: 16),
          _buildMetric(
            l.taxSimRealCost,
            formatChfWithPrefix(_realCost),
            Icons.account_balance_wallet,
            MintColors.textPrimary,
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Projections rente
          Text(
            l.lppBuybackPensionImpactTitle,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildPensionProjection(
            l.lppBuybackScenarioPrudent(
                _conversionRatePrudence.toStringAsFixed(1)),
            _annualPensionPrudence,
            MintColors.warning,
          ),
          const SizedBox(height: 8),
          _buildPensionProjection(
            l.lppBuybackScenarioCentral(
                _conversionRateCentral.toStringAsFixed(1)),
            _annualPensionCentral,
            MintColors.centralScenarioLight,
          ),
          const SizedBox(height: 8),
          _buildPensionProjection(
            l.lppBuybackScenarioStress(
                _conversionRateStress.toStringAsFixed(1)),
            _annualPensionStress,
            MintColors.primary,
          ),

          const SizedBox(height: 24),
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
                    const Icon(Icons.info_outline,
                        size: 16, color: MintColors.warning),
                    const SizedBox(width: 8),
                    Text(
                      l.lppBuybackAssumptionsTitle,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: MintColors.warning),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l.lppBuybackAssumptionsBody,
                  style: const TextStyle(
                      fontSize: 11, color: MintColors.warning),
                ),
              ],
            ),
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
                style: const TextStyle(
                    fontSize: 12, color: MintColors.textSecondary),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
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

  Widget _buildPensionProjection(
      String label, double annualPension, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '+${formatChfWithPrefix(annualPension)}/an',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
