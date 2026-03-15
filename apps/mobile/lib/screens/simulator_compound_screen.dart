import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/domain/calculators.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/theme/colors.dart';
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
                tooltip: s.simulatorCompoundExportTooltip,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                s.simulatorCompoundTitle,
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
                  _buildCoachSection(),
                  const SizedBox(height: 32),
                  _buildInputSection(),
                  const SizedBox(height: 32),
                  if (_result != null) _buildResultSection(),
                  const SizedBox(height: 32),
                  _buildLessonSection(),
                  const SizedBox(height: 48),
                  _buildDisclaimer(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachSection() {
    final s = S.of(context)!;
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
              const Icon(Icons.auto_awesome_outlined, color: MintColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(s.simulatorCompoundCoachTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: MintColors.textSecondary, height: 1.5),
              children: [
                TextSpan(text: s.simulatorCompoundCoachBodyPart1),
                const WidgetSpan(child: InfoTooltip(term: 'int\u00e9r\u00eat compos\u00e9')),
                TextSpan(text: s.simulatorCompoundCoachBodyPart2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    final s = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(s.simulatorCompoundConfiguration),
        const SizedBox(height: 24),
        _buildSlider(
          label: s.simulatorCompoundInitialCapital,
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
        const SizedBox(height: 20),
        _buildSlider(
          label: s.simulatorCompoundMonthlySavings,
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
        const SizedBox(height: 20),
        _buildSlider(
          label: s.simulatorCompoundAnnualRate,
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
        const SizedBox(height: 20),
        _buildSlider(
          label: s.simulatorCompoundTimeHorizon,
          value: _years.toDouble(),
          min: 1,
          max: 40,
          divisions: 39,
          format: (v) => s.simulatorCompoundYears(v.toInt()),
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: MintColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
    final s = S.of(context)!;
    final finalValue = _result!['finalValue']!;
    final gains = _result!['gains']!;
    final gainPercentage = (gains / finalValue * 100);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.appleSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(s.simulatorCompoundFinalValue, style: const TextStyle(fontSize: 14, color: MintColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(finalValue),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: MintColors.textPrimary),
          ),
          const SizedBox(height: 24),
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
            s.simulatorCompoundGainsPercent(gainPercentage.toStringAsFixed(0)),
            style: const TextStyle(fontSize: 13, color: MintColors.success, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLessonSection() {
    final s = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(s.simulatorCompoundLessonsHeader),
        const SizedBox(height: 24),
        _buildLessonItem(Icons.timer_outlined, s.simulatorCompoundLessonTimeTitle, s.simulatorCompoundLessonTimeBody),
        _buildLessonItem(Icons.auto_graph_outlined, s.simulatorCompoundLessonLeverageTitle, s.simulatorCompoundLessonLeverageBody),
        _buildLessonItem(Icons.psychology_outlined, s.simulatorCompoundLessonDisciplineTitle, s.simulatorCompoundLessonDisciplineBody),
      ],
    );
  }

  Widget _buildLessonItem(IconData icon, String title, String subtitle) {
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

  Widget _buildDisclaimer() {
    final s = S.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          s.simulatorCompoundDisclaimer,
          style: const TextStyle(color: MintColors.textMuted, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
