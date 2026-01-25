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

class _CreditCostInsertWidgetState extends State<CreditCostInsertWidget> {
  late double _amount;
  late double _rate;
  late int _months;
  
  final _currencyFormat = NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _amount = widget.creditAmount ?? 10000;
    _rate = widget.interestRate ?? 9.9;
    _months = widget.durationMonths ?? 36;
  }

  double get _totalInterest {
    // Calcul simplifié
    return _amount * (_rate / 100) * (_months / 12);
  }

  double get _totalCost => _amount + _totalInterest;
  double get _monthlyPayment => _totalCost / _months;

  @override
  Widget build(BuildContext context) {
    return EducationalInsertWidget(
      title: 'Le vrai coût de ton crédit',
      subtitle: 'Comprendre combien tu paies réellement',
      disclaimer: 'Calcul simplifié basé sur un remboursement linéaire. Le coût réel peut varier selon les conditions de votre contrat.',
      hypotheses: const [
        'Taux effectif global annuel (TAEG)',
        'Remboursement mensuel constant (simplification)',
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
            onChanged: (v) => setState(() => _amount = v),
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
            onChanged: (v) => setState(() => _rate = v),
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
            onChanged: (v) => setState(() => _months = v.toInt()),
          ),
          
          const SizedBox(height: 24),
          
          // Résultat avec alerte
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade300, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red.shade700, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Coût total des intérêts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _currencyFormat.format(_totalInterest),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'soit ${(_totalInterest / _amount * 100).toStringAsFixed(0)}% du montant emprunté',
                  style: TextStyle(fontSize: 14, color: Colors.red.shade600),
                ),
                
                const Divider(height: 24),
                
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
                    const Text('Mensualité'),
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
              color: MintColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: MintColors.primary, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Conseil Mint',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: MintColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Rembourser ce crédit en priorité est souvent ta meilleure décision financière. '
                  'L\'économie d\'intérêts est garantie, contrairement aux rendements d\'investissement.',
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
                activeColor: isWarning ? Colors.red : MintColors.primary,
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                format(value),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isWarning ? Colors.red : null,
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
