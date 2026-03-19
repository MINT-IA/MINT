import 'package:flutter/material.dart';
import 'package:mint_mobile/domain/calculators.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/info_tooltip.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

class SimulatorCompoundScreen extends StatefulWidget {
  const SimulatorCompoundScreen({super.key});

  @override
  State<SimulatorCompoundScreen> createState() => _SimulatorCompoundScreenState();
}

class _SimulatorCompoundScreenState extends State<SimulatorCompoundScreen> {
  double _principal = 10000;
  double _monthlyContribution = 500;
  double _annualRate = 5.0;
  int _years = 20;

  Map<String, double>? _result;

  final _currencyFormat = NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    setState(() {
      _result = calculateCompoundInterest(
        principal: _principal,
        monthlyContribution: _monthlyContribution,
        annualRate: _annualRate,
        years: _years,
      );
    });
  }

  Future<void> _exportPdf() async {
    if (_result == null) return;
    
    // TODO: Implement PDF export for compound interest simulator
    // await PdfService.generateBilanPdf(
    //   title: 'Simulation Intérêts Composés',
    //   results: results,
    //   recommendations: recommendations,
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        title: Text(S.of(context)!.compoundTitle, style: MintTextStyles.headlineMedium()),
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
            _buildLessonSection(),
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
              Text(S.of(context)!.compoundMentorTitle, style: MintTextStyles.titleMedium()),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          RichText(
            text: TextSpan(
              style: MintTextStyles.bodyMedium(),
              children: [
                TextSpan(text: S.of(context)!.compoundMentorIntro),
                WidgetSpan(child: InfoTooltip(term: 'intérêt composé')),
                TextSpan(text: S.of(context)!.compoundMentorOutro),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(S.of(context)!.compoundConfiguration),
        const SizedBox(height: MintSpacing.lg),
        _buildSlider(
          label: S.of(context)!.compoundCapitalDepart,
          value: _principal,
          min: 0,
          max: 100000,
          divisions: 100,
          format: (v) => _currencyFormat.format(v),
          onChanged: (v) {
            _principal = v;
            _calculate();
          },
        ),
        const SizedBox(height: MintSpacing.md),
        _buildSlider(
          label: S.of(context)!.compoundEpargneMensuelle,
          value: _monthlyContribution,
          min: 0,
          max: 5000,
          divisions: 50,
          format: (v) => _currencyFormat.format(v),
          onChanged: (v) {
            _monthlyContribution = v;
            _calculate();
          },
        ),
        const SizedBox(height: MintSpacing.md),
        _buildSlider(
          label: S.of(context)!.compoundTauxRendement,
          value: _annualRate,
          min: 0,
          max: 12,
          divisions: 24,
          format: (v) => '${v.toStringAsFixed(1)}%',
          onChanged: (v) {
            _annualRate = v;
            _calculate();
          },
        ),
        const SizedBox(height: MintSpacing.md),
        _buildSlider(
          label: S.of(context)!.compoundHorizonTemps,
          value: _years.toDouble(),
          min: 1,
          max: 40,
          divisions: 39,
          format: (v) => '${v.toInt()} ans',
          onChanged: (v) {
            _years = v.toInt();
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
    final finalValue = _result!['finalValue']!;
    final gains = _result!['gains']!;
    final gainPercentage = (gains / finalValue * 100);

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.appleSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(S.of(context)!.compoundValeurFinale, style: MintTextStyles.bodyMedium()),
          const SizedBox(height: MintSpacing.sm),
          Text(
            _currencyFormat.format(finalValue),
            style: MintTextStyles.displayMedium(),
          ),
          const SizedBox(height: MintSpacing.lg),
          Row(
            children: [
              Expanded(
                flex: (100 - gainPercentage).toInt(),
                child: Container(height: 6, decoration: BoxDecoration(color: MintColors.border, borderRadius: BorderRadius.circular(3))),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: gainPercentage.toInt(),
                child: Container(height: 6, decoration: BoxDecoration(color: MintColors.success, borderRadius: BorderRadius.circular(3))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.compoundGainsPercent(gainPercentage.toStringAsFixed(0)),
            style: MintTextStyles.bodySmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLessonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(S.of(context)!.compoundLeconsTitle),
        const SizedBox(height: MintSpacing.lg),
        _buildLessonItem(Icons.timer_outlined, S.of(context)!.compoundTempsRoi, S.of(context)!.compoundTempsRoiBody),
        _buildLessonItem(Icons.auto_graph_outlined, S.of(context)!.compoundEffetLevier, S.of(context)!.compoundEffetLevierBody),
        _buildLessonItem(Icons.psychology_outlined, S.of(context)!.compoundDiscipline, S.of(context)!.compoundDisciplineBody),
      ],
    );
  }

  Widget _buildLessonItem(IconData icon, String title, String subtitle) {
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
          S.of(context)!.compoundDisclaimer,
          style: MintTextStyles.micro(),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
