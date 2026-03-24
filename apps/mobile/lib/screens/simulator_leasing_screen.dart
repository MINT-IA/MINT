import 'package:flutter/material.dart';
import 'package:mint_mobile/domain/calculators.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/coach/leasing_cost_widget.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

class SimulatorLeasingScreen extends StatefulWidget {
  const SimulatorLeasingScreen({super.key});

  @override
  State<SimulatorLeasingScreen> createState() => _SimulatorLeasingScreenState();
}

class _SimulatorLeasingScreenState extends State<SimulatorLeasingScreen> {
  double _monthlyPayment = 400;
  int _durationMonths = 48;
  double _alternativeRate = 5.0;

  Map<String, dynamic>? _result;

  final _currencyFormat = NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);

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
      final profile = context.read<CoachProfileProvider>().profile;
      if (profile == null) return;
      // Leasing is a generic calculator — check if dettes.leasing informs
      // a better monthly payment default
      final leasingDebt = profile.dettes.mensualiteLeasing;
      if (leasingDebt != null && leasingDebt > 0) {
        _monthlyPayment = leasingDebt.clamp(100, 1500);
        _calculate();
      }
    } catch (_) {
      // Provider not available
    }
  }

  void _calculate() {
    setState(() {
      _result = calculateLeasingOpportunityCost(
        monthlyPayment: _monthlyPayment,
        durationMonths: _durationMonths,
        alternativeAnnualRate: _alternativeRate,
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
        title: Text(S.of(context)!.leasingTitle, style: MintTextStyles.headlineMedium()),
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
            // ── P10-D : Le vrai coût du leasing ─────────────────
            LeasingCostWidget(
              vehiclePrice: _monthlyPayment * _durationMonths / 0.55,
              monthlyLeasing: _monthlyPayment,
              leasingDurationMonths: _durationMonths,
              annualReturnRate: _alternativeRate / 100,
            ),
            const SizedBox(height: MintSpacing.xl),
            _buildAlternativesSection(),
            const SizedBox(height: MintSpacing.xxl),
            _buildDisclaimer(),
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
              const Icon(Icons.auto_awesome_outlined, color: MintColors.primary, size: 24),
              const SizedBox(width: MintSpacing.sm),
              Text(S.of(context)!.leasingMentorTitle, style: MintTextStyles.titleMedium()),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            S.of(context)!.leasingMentorBody,
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
        _buildSectionHeader(S.of(context)!.leasingDonneesContrat),
        const SizedBox(height: MintSpacing.lg),
        _buildSlider(
          label: S.of(context)!.leasingMensualitePrevue,
          value: _monthlyPayment,
          min: 100,
          max: 1500,
          divisions: 28,
          format: (v) => _currencyFormat.format(v),
          onChanged: (v) {
            _monthlyPayment = v;
            _calculate();
          },
        ),
        const SizedBox(height: MintSpacing.md),
        _buildSlider(
          label: S.of(context)!.leasingDuree,
          value: _durationMonths.toDouble(),
          min: 12,
          max: 60,
          divisions: 4,
          format: (v) => '${v.toInt()} mois',
          onChanged: (v) {
            _durationMonths = v.toInt();
            _calculate();
          },
        ),
        const SizedBox(height: MintSpacing.md),
        _buildSlider(
          label: S.of(context)!.leasingRendementAlternatif,
          value: _alternativeRate,
          min: 1,
          max: 10,
          divisions: 18,
          format: (v) => '${v.toStringAsFixed(1)}%',
          onChanged: (v) {
            _alternativeRate = v;
            _calculate();
          },
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
              style: MintTextStyles.bodyMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.border,
            thumbColor: MintColors.primary,
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
    final opportunityCost20 = _result!['opportunityCost']['20y'] as double;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(S.of(context)!.leasingCoutOpportunite20, style: MintTextStyles.bodyMedium()),
          const SizedBox(height: MintSpacing.sm),
          Text(
            _currencyFormat.format(opportunityCost20),
            style: MintTextStyles.displayMedium(color: MintColors.error),
          ),
          const SizedBox(height: MintSpacing.lg),
          Text(
            S.of(context)!.leasingInvestirAuLieu,
            style: MintTextStyles.bodySmall(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MintSpacing.md),
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.home_work_outlined, color: MintColors.error, size: 20),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    S.of(context)!.leasingFondsPropres(_currencyFormat.format(opportunityCost20 * 0.2)),
                    style: MintTextStyles.bodySmall(color: MintColors.error).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(S.of(context)!.leasingAlternativesTitle),
        const SizedBox(height: MintSpacing.lg),
        _buildAltItem(Icons.directions_car_outlined, S.of(context)!.leasingOccasion, S.of(context)!.leasingOccasionBody),
        _buildAltItem(Icons.train_outlined, S.of(context)!.leasingAboGeneral, S.of(context)!.leasingAboGeneralBody),
        _buildAltItem(Icons.share_outlined, S.of(context)!.leasingMobility, S.of(context)!.leasingMobilityBody),
      ],
    );
  }

  Widget _buildAltItem(IconData icon, String title, String subtitle) {
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
          S.of(context)!.leasingDisclaimer,
          style: MintTextStyles.micro(),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
