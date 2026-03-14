import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/domain/calculators.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/debt_repayment_widget.dart';

class ConsumerCreditSimulatorScreen extends StatefulWidget {
  const ConsumerCreditSimulatorScreen({super.key});

  @override
  State<ConsumerCreditSimulatorScreen> createState() => _ConsumerCreditSimulatorScreenState();
}

class _ConsumerCreditSimulatorScreenState extends State<ConsumerCreditSimulatorScreen> {
  double _amount = 10000;
  int _durationMonths = 24;
  double _annualRate = 9.9;
  final double _fees = 0;

  Map<String, dynamic>? _result;

  final _currencyFormat = NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);

  // Swiss legal max rates from 01.01.2026
  static const double _maxRateCashCredit = 10.0;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    setState(() {
      _result = calculateConsumerCredit(
        amount: _amount,
        durationMonths: _durationMonths,
        annualRate: _annualRate,
        fees: _fees,
      );
    });
  }

  Future<void> _exportPdf() async {
    if (_result == null) return;
    
    // TODO: Implement PDF export for consumer credit simulator
    // await PdfService.generateBilanPdf(
    //   title: 'Simulation de Crédit à la Consommation',
    //   results: results,
    //   recommendations: recommendations,
    // );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined, color: MintColors.white),
                onPressed: _exportPdf,
                tooltip: s.consumerCreditExportTooltip,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                s.consumerCreditTitle,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: MintColors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MintColors.primary, MintColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCoachSection(s),
                  const SizedBox(height: 32),
                  _buildInputSection(s),
                  const SizedBox(height: 32),
                  if (_result != null) _buildResultSection(s),
                  const SizedBox(height: 32),
                  _buildGuidanceSection(s),
                  const SizedBox(height: 32),
                  // ── P10-B : Avalanche vs Boule de neige ──────────────
                  const DebtRepaymentWidget(
                    debts: [
                      DebtEntry(
                        label: 'Carte de crédit',
                        emoji: '💳',
                        balance: 2000,
                        monthlyRate: 0.015, // 1.5%/mois = 18%/an
                        minimumPayment: 80,
                      ),
                      DebtEntry(
                        label: 'Crédit conso',
                        emoji: '🏦',
                        balance: 8000,
                        monthlyRate: 0.008, // 0.8%/mois ≈ 9.9%/an
                        minimumPayment: 200,
                      ),
                      DebtEntry(
                        label: 'BNPL (paiement différé)',
                        emoji: '🛍️',
                        balance: 1200,
                        monthlyRate: 0.0, // 0% pendant période franchise
                        minimumPayment: 100,
                      ),
                    ],
                    extraMonthly: 150,
                  ),
                  const SizedBox(height: 48),
                  _buildDisclaimer(s),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachSection(S s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: MintColors.warning, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.consumerCreditCoachTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.consumerCreditCoachBody,
            style: const TextStyle(fontSize: 14, color: MintColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(s.consumerCreditParameters),
        const SizedBox(height: 24),
        _buildSlider(
          label: s.consumerCreditBorrowAmount,
          value: _amount,
          min: 1000,
          max: 50000,
          divisions: 49,
          format: (v) => _currencyFormat.format(v),
          onChanged: (v) {
            _amount = v;
            _calculate();
          },
        ),
        const SizedBox(height: 20),
        _buildSlider(
          label: s.consumerCreditRepaymentDuration,
          value: _durationMonths.toDouble(),
          min: 6,
          max: 60,
          divisions: 54,
          format: (v) => s.consumerCreditMonths(v.toInt()),
          onChanged: (v) {
            _durationMonths = v.toInt();
            _calculate();
          },
        ),
        const SizedBox(height: 20),
        _buildSlider(
          label: s.consumerCreditEffectiveRate,
          value: _annualRate,
          min: 1,
          max: 15,
          divisions: 28,
          format: (v) => '${v.toStringAsFixed(1)}%',
          onChanged: (v) {
            _annualRate = v;
            _calculate();
          },
          isWarning: _annualRate >= _maxRateCashCredit,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: MintColors.textMuted,
        letterSpacing: 1.2,
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
    required void Function(double) onChanged,
    bool isWarning = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: MintColors.textPrimary)),
            Text(
              format(value),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isWarning ? MintColors.error : MintColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: isWarning ? MintColors.error : MintColors.primary,
            inactiveTrackColor: MintColors.border,
            thumbColor: isWarning ? MintColors.error : MintColors.primary,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection(S s) {
    final monthlyPayment = _result!['monthlyPayment'] as double;
    final totalInterest = _result!['totalInterest'] as double;
    final rateWarning = _result!['rateWarning'] as bool;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: rateWarning ? MintColors.error.withValues(alpha: 0.05) : MintColors.appleSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: rateWarning ? MintColors.error.withValues(alpha: 0.2) : MintColors.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Text(s.consumerCreditYourMonthly, style: const TextStyle(fontSize: 14, color: MintColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(monthlyPayment),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: MintColors.textPrimary),
          ),
          const SizedBox(height: 24),
          const Divider(color: MintColors.border),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.consumerCreditInterestCost, style: const TextStyle(fontSize: 14, color: MintColors.textSecondary)),
              Text(
                _currencyFormat.format(totalInterest),
                style: const TextStyle(fontWeight: FontWeight.w600, color: MintColors.error),
              ),
            ],
          ),
          if (rateWarning) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: MintColors.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.consumerCreditRateWarning,
                      style: const TextStyle(color: MintColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuidanceSection(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(s.consumerCreditMentorAdvice),
        const SizedBox(height: 24),
        _buildGuidanceItem(Icons.savings_outlined, s.consumerCreditSaveFirst, s.consumerCreditSaveFirstBody(_currencyFormat.format(_result!['totalInterest']))),
        _buildGuidanceItem(Icons.family_restroom_outlined, s.consumerCreditTrustCircle, s.consumerCreditTrustCircleBody),
        _buildGuidanceItem(Icons.help_outline_rounded, s.consumerCreditDebtCounseling, s.consumerCreditDebtCounselingBody),
      ],
    );
  }

  Widget _buildGuidanceItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: MintColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 14, color: MintColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(S s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          s.consumerCreditDisclaimer,
          style: const TextStyle(color: MintColors.textMuted, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
