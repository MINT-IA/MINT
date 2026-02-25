import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/educational/educational_insert_widget.dart';

/// Insert didactique pour q_has_consumer_credit
/// Alerte coût réel du crédit consommation
class CreditCostInsertWidget extends StatefulWidget {
  final double? creditAmount;
  final double? interestRate;
  final int? durationMonths;
  final VoidCallback? onLearnMore;

  const CreditCostInsertWidget({
    super.key,
    this.creditAmount,
    this.interestRate,
    this.durationMonths,
    this.onLearnMore,
  });

  @override
  State<CreditCostInsertWidget> createState() => _CreditCostInsertWidgetState();
}

class _CreditCostInsertWidgetState extends State<CreditCostInsertWidget>
    with SingleTickerProviderStateMixin {
  late double _amount;
  late double _rate;
  late int _months;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final _currencyFormat = NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _amount = widget.creditAmount ?? 10000;
    _rate = widget.interestRate ?? 9.9;
    _months = widget.durationMonths ?? 36;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onValueChanged(VoidCallback update) {
    setState(update);
    _pulseController.forward(from: 0);
  }

  double get _monthlyPayment {
    final r = (_rate / 100) / 12; // monthly rate
    final n = _months;
    if (r == 0) return _amount / n;
    return _amount * (r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
  }

  double get _totalCost => _monthlyPayment * _months;
  double get _totalInterest => _totalCost - _amount;

  @override
  Widget build(BuildContext context) {
    return EducationalInsertWidget(
      title: 'Le vrai coût de ton crédit',
      subtitle: 'Comprendre combien tu paies réellement',
      disclaimer: 'Calcul par annuites constantes (amortissement). Le cout reel peut varier selon les conditions de ton contrat.',
      hypotheses: const [
        'Taux effectif global annuel (TAEG)',
        'Amortissement par annuites constantes (methode bancaire standard)',
        'Pas de frais de dossier inclus',
      ],
      onLearnMore: widget.onLearnMore,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slider montant
          _buildSlider(
            label: 'Montant emprunté',
            value: _amount,
            min: 1000,
            max: 50000,
            divisions: 49,
            format: (v) => _currencyFormat.format(v),
            onChanged: (v) => _onValueChanged(() => _amount = v),
          ),

          const SizedBox(height: 16),

          // Slider taux
          _buildSlider(
            label: 'Taux d\'intérêt (TAEG)',
            value: _rate,
            min: 4,
            max: 15,
            divisions: 22,
            format: (v) => '${v.toStringAsFixed(1)}%',
            onChanged: (v) => _onValueChanged(() => _rate = v),
            isWarning: _rate > 10,
          ),

          const SizedBox(height: 16),

          // Slider durée
          _buildSlider(
            label: 'Durée du crédit',
            value: _months.toDouble(),
            min: 12,
            max: 84,
            divisions: 12,
            format: (v) => '${v.toInt()} mois',
            onChanged: (v) => _onValueChanged(() => _months = v.toInt()),
          ),
          
          const SizedBox(height: 24),
          
          // Chiffre choc — prominent interest cost
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: MintColors.error,
                borderRadius: const Borderconst Radius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: MintColors.error.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Cout total des interets',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currencyFormat.format(_totalInterest),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const Borderconst Radius.circular(20),
                    ),
                    child: Text(
                      'soit ${(_totalInterest / _amount * 100).toStringAsFixed(0)}% du montant emprunte',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Details section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.05),
              borderRadius: const Borderconst Radius.circular(12),
              border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tu rembourses au total'),
                    Text(
                      _currencyFormat.format(_totalCost),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mensualite'),
                    Text(
                      '${_currencyFormat.format(_monthlyPayment)} / mois',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Conseil
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.primary.withValues(alpha: 0.1),
              borderRadius: const Borderconst Radius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: MintColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Conseil Mint',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: MintColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Rembourser ce credit en priorite est souvent la decision financiere la plus efficace. '
                  'L\'economie d\'interets est acquise, contrairement aux rendements d\'investissement.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required ValueChanged<double> onChanged,
    bool isWarning = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                activeThumbColor: isWarning ? MintColors.error : MintColors.primary,
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                format(value),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isWarning ? MintColors.error : null,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
