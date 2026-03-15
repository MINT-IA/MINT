import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/educational/educational_insert_widget.dart';

/// Insert didactique pour q_has_leasing
/// Simulateur coût total leasing vs alternatives
class LeasingCostInsertWidget extends StatefulWidget {
  final double? monthlyPayment;
  final int? remainingMonths;
  final VoidCallback? onLearnMore;

  const LeasingCostInsertWidget({
    super.key,
    this.monthlyPayment,
    this.remainingMonths,
    this.onLearnMore,
  });

  @override
  State<LeasingCostInsertWidget> createState() => _LeasingCostInsertWidgetState();
}

class _LeasingCostInsertWidgetState extends State<LeasingCostInsertWidget> {
  late double _monthlyPayment;
  late int _remainingMonths;
  
  final _currencyFormat = NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _monthlyPayment = widget.monthlyPayment ?? 450;
    _remainingMonths = widget.remainingMonths ?? 24;
  }

  double get _totalRemaining => _monthlyPayment * _remainingMonths;
  
  // Estimation d'un véhicule d'occasion équivalent
  double get _occasionEquivalent => _totalRemaining * 0.6;

  @override
  Widget build(BuildContext context) {
    return EducationalInsertWidget(
      title: 'Leasing : combien ça te coûte vraiment ?',
      subtitle: 'Compare avec les alternatives',
      disclaimer: 'Comparaison simplifiée. Le leasing peut inclure des avantages (assurance, entretien) non pris en compte ici. Ne constitue pas une recommandation.',
      hypotheses: const [
        'Pas de rachat en fin de contrat',
        'Comparaison avec véhicule d\'occasion ~60% du coût leasing',
        'Frais d\'entretien et assurance non inclus dans la comparaison',
      ],
      onLearnMore: widget.onLearnMore,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slider mensualité
          const Text(
            'Ta mensualité leasing',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _monthlyPayment,
                  min: 200,
                  max: 1500,
                  divisions: 130,
                  activeColor: MintColors.primary,
                  onChanged: (v) => setState(() => _monthlyPayment = v),
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  _currencyFormat.format(_monthlyPayment),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Slider durée restante
          const Text(
            'Mois restants',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _remainingMonths.toDouble(),
                  min: 1,
                  max: 48,
                  divisions: 47,
                  activeColor: MintColors.primary,
                  onChanged: (v) => setState(() => _remainingMonths = v.toInt()),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  '$_remainingMonths mois',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Comparaison
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.greyBorder),
            ),
            child: Column(
              children: [
                // Coût leasing
                _buildCostRow(
                  icon: Icons.directions_car,
                  iconColor: MintColors.warning,
                  label: 'Tu vas encore payer',
                  sublabel: 'et tu ne seras pas propriétaire',
                  amount: _totalRemaining,
                  amountColor: MintColors.warning,
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('VS', style: TextStyle(color: MintColors.greyMedium)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                ),
                
                // Alternative occasion
                _buildCostRow(
                  icon: Icons.car_rental,
                  iconColor: MintColors.success,
                  label: 'Véhicule d\'occasion équivalent',
                  sublabel: 'tu en es propriétaire',
                  amount: _occasionEquivalent,
                  amountColor: MintColors.greenDark,
                ),
                
                const SizedBox(height: 16),
                
                // Économie potentielle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MintColors.successBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.savings, color: MintColors.greenDark, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Économie potentielle: ${_currencyFormat.format(_totalRemaining - _occasionEquivalent)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: MintColors.greenDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Rappel important
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.disclaimerBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: MintColors.warningText, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'À la fin du leasing, tu n\'es pas propriétaire du véhicule. Pense à anticiper la fin de contrat.',
                    style: TextStyle(fontSize: 13, color: MintColors.amberDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sublabel,
    required double amount,
    required Color amountColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(sublabel, style: const TextStyle(fontSize: 12, color: MintColors.textSecondary)),
            ],
          ),
        ),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: amountColor,
          ),
        ),
      ],
    );
  }
}
