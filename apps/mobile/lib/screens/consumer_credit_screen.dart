import 'package:flutter/material.dart';
import 'package:mint_mobile/domain/calculators.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/coach/debt_repayment_widget.dart';
import 'package:mint_mobile/widgets/common/debt_tools_nav.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
    });
    _calculate();
  }

  void _initializeFromProfile() {
    try {
      final provider = context.read<CoachProfileProvider>();
      if (!provider.hasProfile) return;
      final profile = provider.profile!;
      setState(() {
        final creditConso = profile.dettes.creditConsommation;
        if (creditConso != null && creditConso > 0) {
          _amount = creditConso;
        }
        final tauxConso = profile.dettes.tauxCreditConso;
        if (tauxConso != null && tauxConso > 0) {
          _annualRate = tauxConso;
        }
      });
      _calculate();
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        title: Text(S.of(context)!.creditTitle, style: MintTextStyles.headlineMedium()),
        // PDF export hidden — stub not yet implemented
        actions: const [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: MintSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCoachSection(),
            const SizedBox(height: MintSpacing.xl),
            _buildInputSection(),
            const SizedBox(height: MintSpacing.xl),
            if (_result != null) _buildResultSection(),
            const SizedBox(height: MintSpacing.xl),
            _buildGuidanceSection(),
            const SizedBox(height: MintSpacing.xl),
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
            const SizedBox(height: MintSpacing.xxl),
            _buildDisclaimer(),
            const SizedBox(height: MintSpacing.lg),
            const DebtToolsNav(currentRoute: '/simulator/credit'),
            const SizedBox(height: MintSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachSection() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
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
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  S.of(context)!.creditMentorTitle,
                  style: MintTextStyles.titleMedium(),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            S.of(context)!.creditMentorBody,
            style: MintTextStyles.bodyMedium(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(S.of(context)!.creditParametres),
        const SizedBox(height: MintSpacing.lg),
        _buildSlider(
          label: S.of(context)!.creditMontantEmprunter,
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
        const SizedBox(height: MintSpacing.md),
        _buildSlider(
          label: S.of(context)!.creditDureeRemboursement,
          value: _durationMonths.toDouble(),
          min: 6,
          max: 60,
          divisions: 54,
          format: (v) => '${v.toInt()} mois',
          onChanged: (v) {
            _durationMonths = v.toInt();
            _calculate();
          },
        ),
        const SizedBox(height: MintSpacing.md),
        _buildSlider(
          label: S.of(context)!.creditTauxAnnuel,
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
      style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
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
            Text(label, style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)),
            Text(
              format(value),
              style: MintTextStyles.bodyMedium(
                color: isWarning ? MintColors.error : MintColors.primary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm),
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

  Widget _buildResultSection() {
    final monthlyPayment = _result!['monthlyPayment'] as double;
    final totalInterest = _result!['totalInterest'] as double;
    final rateWarning = _result!['rateWarning'] as bool;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: rateWarning ? MintColors.error.withValues(alpha: 0.05) : MintColors.appleSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: rateWarning ? MintColors.error.withValues(alpha: 0.2) : MintColors.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Text(S.of(context)!.creditTaMensualite, style: MintTextStyles.bodyMedium()),
          const SizedBox(height: MintSpacing.sm),
          Text(
            _currencyFormat.format(monthlyPayment),
            style: MintTextStyles.displayMedium(),
          ),
          const SizedBox(height: MintSpacing.lg),
          const Divider(color: MintColors.border),
          const SizedBox(height: MintSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.of(context)!.creditCoutInterets, style: MintTextStyles.bodyMedium()),
              Text(
                _currencyFormat.format(totalInterest),
                style: MintTextStyles.bodyMedium(color: MintColors.error).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (rateWarning) ...[
            const SizedBox(height: MintSpacing.md),
            Container(
              padding: const EdgeInsets.all(MintSpacing.sm),
              decoration: BoxDecoration(
                color: MintColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: MintColors.error, size: 20),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Text(
                      S.of(context)!.creditRateWarning,
                      style: MintTextStyles.bodySmall(color: MintColors.error).copyWith(fontWeight: FontWeight.w600),
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

  Widget _buildGuidanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(S.of(context)!.creditConseilsTitle),
        const SizedBox(height: MintSpacing.lg),
        _buildGuidanceItem(Icons.savings_outlined, S.of(context)!.creditEpargnerDabord, S.of(context)!.creditEpargnerDabordBody(_currencyFormat.format(_result!['totalInterest']))),
        _buildGuidanceItem(Icons.family_restroom_outlined, S.of(context)!.creditCercleConfiance, S.of(context)!.creditCercleConfianceBody),
        _buildGuidanceItem(Icons.help_outline_rounded, S.of(context)!.creditDettesConseils, S.of(context)!.creditDettesConseilsBody),
      ],
    );
  }

  Widget _buildGuidanceItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.lg),
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
          const SizedBox(width: MintSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MintTextStyles.titleMedium()),
                const SizedBox(height: MintSpacing.xs),
                Text(subtitle, style: MintTextStyles.bodyMedium()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
        child: Text(
          S.of(context)!.creditDisclaimer,
          style: MintTextStyles.micro(),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
