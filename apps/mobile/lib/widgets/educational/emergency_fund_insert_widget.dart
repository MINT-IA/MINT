import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/educational/educational_insert_widget.dart';

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
    final s = S.of(context)!;
    return EducationalInsertWidget(
      title: s.emergencyFundTitle,
      subtitle: s.emergencyFundSubtitle,
      disclaimer: s.emergencyFundDisclaimer,
      hypotheses: [
        s.emergencyFundHyp1,
        s.emergencyFundHyp2,
        s.emergencyFundHyp3,
      ],
      onLearnMore: widget.onLearnMore,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slider charges mensuelles
          Text(
            s.emergencyFundChargesLabel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            s.emergencyFundChargesDesc,
            style: const TextStyle(fontSize: 12, color: MintColors.textSecondary),
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
          Text(
            s.emergencyFundObjectifLabel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                  s.emergencyFundMoisUnit(_targetMonths.toInt()),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          
          // Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.emergencyFundMinimum, style: const TextStyle(fontSize: 11, color: MintColors.textSecondary)),
                Text(s.emergencyFundConfort, style: const TextStyle(fontSize: 11, color: MintColors.textSecondary)),
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
                        Text(
                          s.emergencyFundObjectifTitle,
                          style: const TextStyle(fontSize: 13, color: MintColors.textSecondary),
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
                          Text(s.emergencyFundProgression),
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
                          s.emergencyFundManque(_currencyFormat.format(_targetAmount - widget.currentSavings!)),
                          style: const TextStyle(fontSize: 13, color: MintColors.warning),
                        )
                      else
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: MintColors.success, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              s.emergencyFundAtteint,
                              style: MintTextStyles.bodySmall(color: MintColors.success).copyWith(fontWeight: FontWeight.bold),
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
                    s.emergencyFundExplication,
                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w500),
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
