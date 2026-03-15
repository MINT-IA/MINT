import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/educational/educational_insert_widget.dart';
import 'package:google_fonts/google_fonts.dart';

/// Insert didactique pour q_emergency_fund
/// Calculateur de fonds d'urgence (3-6 mois de charges)
class EmergencyFundInsertWidget extends StatefulWidget {
  final double? monthlyExpenses;
  final double? currentSavings;
  final VoidCallback? onLearnMore;

  const EmergencyFundInsertWidget({
    super.key,
    this.monthlyExpenses,
    this.currentSavings,
    this.onLearnMore,
  });

  @override
  State<EmergencyFundInsertWidget> createState() => _EmergencyFundInsertWidgetState();
}

class _EmergencyFundInsertWidgetState extends State<EmergencyFundInsertWidget> {
  late double _monthlyExpenses;
  double _targetMonths = 4;
  
  final _currencyFormat = NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _monthlyExpenses = widget.monthlyExpenses ?? 3500;
  }

  double get _targetAmount => _monthlyExpenses * _targetMonths;
  double get _currentProgress => widget.currentSavings != null 
      ? (widget.currentSavings! / _targetAmount).clamp(0, 1) 
      : 0;

  @override
  Widget build(BuildContext context) {
    return EducationalInsertWidget(
      title: 'Ton filet de sécurité',
      subtitle: 'Calcule ton fonds d\'urgence idéal',
      disclaimer: 'L\'objectif de 3-6 mois est une recommandation générale. Ta situation personnelle peut nécessiter un montant différent.',
      hypotheses: const [
        'Charges fixes = loyer + assurances + abonnements + crédits',
        'Objectif recommandé : 3 mois (minimum) à 6 mois (confort)',
        'Placement suggéré : compte épargne accessible, non investi',
      ],
      onLearnMore: widget.onLearnMore,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slider charges mensuelles
          const Text(
            'Tes charges fixes mensuelles',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Loyer + assurances + abonnements + crédits',
            style: TextStyle(fontSize: 12, color: MintColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _monthlyExpenses,
                  min: 1000,
                  max: 8000,
                  divisions: 70,
                  activeColor: MintColors.primary,
                  onChanged: (v) => setState(() => _monthlyExpenses = v),
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  _currencyFormat.format(_monthlyExpenses),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Slider mois cible
          const Text(
            'Objectif en mois de sécurité',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _targetMonths,
                  min: 3,
                  max: 6,
                  divisions: 3,
                  activeColor: MintColors.primary,
                  onChanged: (v) => setState(() => _targetMonths = v),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  '${_targetMonths.toInt()} mois',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          
          // Labels
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Minimum', style: TextStyle(fontSize: 11, color: MintColors.textSecondary)),
                Text('Confort', style: TextStyle(fontSize: 11, color: MintColors.textSecondary)),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Résultat
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: MintColors.primary.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield, color: MintColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ton objectif de fonds d\'urgence',
                          style: TextStyle(fontSize: 13, color: MintColors.textSecondary),
                        ),
                        Text(
                          _currencyFormat.format(_targetAmount),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: MintColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                if (widget.currentSavings != null) ...[
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ta progression'),
                          Text('${(_currentProgress * 100).toInt()}%'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _currentProgress,
                        backgroundColor: MintColors.lightBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _currentProgress >= 1 ? MintColors.success : MintColors.primary,
                        ),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      if (_currentProgress < 1)
                        Text(
                          'Il te manque ${_currencyFormat.format(_targetAmount - widget.currentSavings!)}',
                          style: const TextStyle(fontSize: 13, color: MintColors.warning),
                        )
                      else
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: MintColors.success, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Objectif atteint ! 🎉',
                              style: GoogleFonts.inter(fontSize: 13, color: MintColors.success, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Pourquoi c'est important
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.security_rounded, color: MintColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ce fonds te protège des imprévus (perte d\'emploi, maladie, réparations) sans toucher à tes investissements.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
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
