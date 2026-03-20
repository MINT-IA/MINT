import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Insert didactique pour q_has_3a
/// Mini-simulateur d'économie fiscale 3a avec sliders
class TaxSavingsInsertWidget extends StatefulWidget {
  final double? initialIncome;
  final bool hasPensionFund;
  final VoidCallback? onLearnMore;

  const TaxSavingsInsertWidget({
    super.key,
    this.initialIncome,
    this.hasPensionFund = true,
    this.onLearnMore,
  });

  @override
  State<TaxSavingsInsertWidget> createState() => _TaxSavingsInsertWidgetState();
}

class _TaxSavingsInsertWidgetState extends State<TaxSavingsInsertWidget> {
  late double _monthlyIncome;
  double _taxRateMin = 0.20;
  double _taxRateMax = 0.30;

  final _currencyFormat =
      NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _monthlyIncome = widget.initialIncome ?? 6000;
    _updateTaxRate();
  }

  void _updateTaxRate() {
    final annual = _monthlyIncome * 12;
    if (annual > 150000) {
      _taxRateMin = 0.30;
      _taxRateMax = 0.40;
    } else if (annual > 100000) {
      _taxRateMin = 0.25;
      _taxRateMax = 0.35;
    } else if (annual > 60000) {
      _taxRateMin = 0.20;
      _taxRateMax = 0.30;
    } else {
      _taxRateMin = 0.15;
      _taxRateMax = 0.25;
    }
  }

  double get _max3aContribution {
    if (widget.hasPensionFund) {
      return pilier3aPlafondAvecLpp;
    } else {
      final annual = _monthlyIncome * 12;
      return (annual * 0.20).clamp(0, pilier3aPlafondSansLpp);
    }
  }

  double get _taxSavingsMin => _max3aContribution * _taxRateMin;
  double get _taxSavingsMax => _max3aContribution * _taxRateMax;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: MintColors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Header Gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [MintColors.primary.withValues(alpha: 0.05), MintColors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MintColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: MintColors.primary.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.savings_outlined,
                      color: MintColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Optimisation 3a',
                        style: MintTextStyles.headlineMedium(color: MintColors.textPrimary).copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Ton allié fiscal',
                        style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (widget.onLearnMore != null)
                  IconButton(
                    icon: Icon(Icons.info_outline,
                        color: MintColors.primary.withValues(alpha: 0.5)),
                    onPressed: widget.onLearnMore,
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Input Section
                Text(
                  'Ton revenu mensuel net',
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: MintColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: MintColors.primary,
                            inactiveTrackColor: MintColors.border,
                            thumbColor: MintColors.white,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 12, elevation: 4),
                            overlayColor: MintColors.primary.withValues(alpha: 0.1),
                            trackHeight: 6,
                          ),
                          child: Slider(
                            value: _monthlyIncome.clamp(2000, 15000),
                            min: 2000,
                            max: 15000,
                            divisions: 130,
                            onChanged: (v) {
                              setState(() {
                                _monthlyIncome = v;
                                _updateTaxRate();
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: MintColors.white,
                        border: Border.all(color: MintColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _currencyFormat.format(_monthlyIncome),
                        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Result Card (Hero)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: MintColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MintColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: MintColors.primary.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Capacité 3a',
                              style: MintTextStyles.bodyMedium(color: MintColors.textSecondary)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: MintColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                _currencyFormat.format(_max3aContribution),
                                style: MintTextStyles.bodySmall().copyWith(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      Text('Économie d\'impôts annuelle',
                          style: MintTextStyles.bodySmall(color: MintColors.textSecondary)),
                      const SizedBox(height: 8),
                      // Hero Number - Clean Anthracite
                      Text(
                        '~${_currencyFormat.format((_taxSavingsMin + _taxSavingsMax) / 2)}',
                        style: MintTextStyles.displayMedium(color: MintColors.textPrimary).copyWith(fontSize: 38, fontWeight: FontWeight.bold, letterSpacing: -1.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Soit ${(((_taxSavingsMin + _taxSavingsMax) / 2) / 12).toStringAsFixed(0)} CHF de plus par mois',
                        style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Estimation basée sur taux marginal ${(_taxRateMin * 100).toInt()}-${(_taxRateMax * 100).toInt()}%',
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted),
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
