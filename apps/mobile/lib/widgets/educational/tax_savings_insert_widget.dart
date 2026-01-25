import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/educational/educational_insert_widget.dart';
import 'package:google_fonts/google_fonts.dart';

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
      return 7258;
    } else {
      final annual = _monthlyIncome * 12;
      return (annual * 0.20).clamp(0, 36288);
    }
  }

  double get _taxSavingsMin => _max3aContribution * _taxRateMin;
  double get _taxSavingsMax => _max3aContribution * _taxRateMax;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: MintColors.border.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // Header Gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [MintColors.primary.withOpacity(0.05), Colors.white],
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
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: MintColors.primary.withOpacity(0.1),
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
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: MintColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Ton allié fiscal',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onLearnMore != null)
                  IconButton(
                    icon: Icon(Icons.info_outline,
                        color: MintColors.primary.withOpacity(0.5)),
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
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      fontWeight: FontWeight.w500),
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
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 12, elevation: 4),
                            overlayColor: MintColors.primary.withOpacity(0.1),
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
                        color: Colors.white,
                        border: Border.all(color: MintColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _currencyFormat.format(_monthlyIncome),
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: MintColors.textPrimary),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Result Card (Hero)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MintColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669)
                            .withOpacity(0.08), // Green tint
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
                              style: GoogleFonts.inter(
                                  color: MintColors.textSecondary)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: MintColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                _currencyFormat.format(_max3aContribution),
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      Text('Économie d\'impôts annuelle',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: MintColors.textSecondary)),
                      const SizedBox(height: 8),
                      // Hero Number
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981)],
                        ).createShader(bounds),
                        child: Text(
                          '~${_currencyFormat.format((_taxSavingsMin + _taxSavingsMax) / 2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Soit ${(((_taxSavingsMin + _taxSavingsMax) / 2) / 12).toStringAsFixed(0)} CHF de plus par mois',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: MintColors.success,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Estimation basée sur taux marginal ${(_taxRateMin * 100).toInt()}-${(_taxRateMax * 100).toInt()}%',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: MintColors.textMuted),
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
