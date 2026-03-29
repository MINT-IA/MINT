import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/job_comparison_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';
import 'package:mint_mobile/widgets/coach/job_change_comparison_widget.dart';

/// Swiss CHF formatter with apostrophe grouping.
String _formatChfSwiss(double value) {
  final intVal = value.round();
  final isNeg = intVal < 0;
  final str = intVal.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write("'");
    }
    buffer.write(str[i]);
  }
  return '${isNeg ? '-' : ''}${buffer.toString()}';
}

/// Swiss CHF formatter with prefix.
String _chfFmt(double value) {
  return 'CHF\u00A0${_formatChfSwiss(value)}';
}

/// Delta formatted with sign.
String _deltaFmt(double value) {
  final prefix = value >= 0 ? '+' : '';
  return '$prefix${_formatChfSwiss(value)}';
}

class JobComparisonScreen extends StatefulWidget {
  const JobComparisonScreen({super.key});

  @override
  State<JobComparisonScreen> createState() => _JobComparisonScreenState();
}

class _JobComparisonScreenState extends State<JobComparisonScreen> {
  // Scroll controller for smooth scroll to results
  final _scrollController = ScrollController();
  final _resultsKey = GlobalKey();

  // Shared
  int _age = 35;

  // Current job inputs
  double _currentSalaireBrut = 85000;
  double _currentPartEmployeur = 50;
  double _currentTauxConversion = 5.2;
  double _currentAvoirVieillesse = 120000;
  double _currentCouvertureInvalidite = 40;
  double _currentCapitalDeces = 200000;
  double _currentRachatMax = 80000;
  bool _currentHasIjm = true;

  // New job inputs
  double _newSalaireBrut = 95000;
  double _newPartEmployeur = 50;
  double _newTauxConversion = 5.2;
  double _newAvoirVieillesse = 120000;
  double _newCouvertureInvalidite = 40;
  double _newCapitalDeces = 150000;
  double _newRachatMax = 40000;
  bool _newHasIjm = true;

  // Collapsible state
  bool _currentJobExpanded = true;
  bool _newJobExpanded = true;

  // Result
  JobComparisonResult? _result;

  // Checklist state (local only)
  List<bool> _checklistState = [];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _compare() {
    final current = LPPPlanInput(
      salaireBrut: _currentSalaireBrut,
      partEmployeurPct: _currentPartEmployeur,
      tauxConversionSurobligatoire: _currentTauxConversion,
      avoirVieillesse: _currentAvoirVieillesse,
      renteInvaliditePct: _currentCouvertureInvalidite,
      capitalDeces: _currentCapitalDeces,
      rachatMaximum: _currentRachatMax,
      hasIjm: _currentHasIjm,
    );

    final newJob = LPPPlanInput(
      salaireBrut: _newSalaireBrut,
      partEmployeurPct: _newPartEmployeur,
      tauxConversionSurobligatoire: _newTauxConversion,
      avoirVieillesse: _newAvoirVieillesse,
      renteInvaliditePct: _newCouvertureInvalidite,
      capitalDeces: _newCapitalDeces,
      rachatMaximum: _newRachatMax,
      hasIjm: _newHasIjm,
    );

    setState(() {
      _result = JobComparisonService.compare(
        current: current,
        newJob: newJob,
        age: _age,
      );
      _checklistState = List.filled(_result!.checklist.length, false);
    });

    // Smooth scroll to results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resultsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _resultsKey.currentContext!,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          S.of(context)!.jobCompareTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.lg,
          vertical: MintSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: MintSpacing.lg),
            _buildIntroCard(),
            const SizedBox(height: MintSpacing.lg),
            _buildAgeSlider(),
            const SizedBox(height: MintSpacing.lg),
            _buildJobSection(
              title: S.of(context)!.jobCompareCurrentJob,
              expanded: _currentJobExpanded,
              onToggle: () =>
                  setState(() => _currentJobExpanded = !_currentJobExpanded),
              salaireBrut: _currentSalaireBrut,
              onSalaireBrutChanged: (v) =>
                  setState(() => _currentSalaireBrut = v),
              partEmployeur: _currentPartEmployeur,
              onPartEmployeurChanged: (v) =>
                  setState(() => _currentPartEmployeur = v),
              tauxConversion: _currentTauxConversion,
              onTauxConversionChanged: (v) =>
                  setState(() => _currentTauxConversion = v),
              avoirVieillesse: _currentAvoirVieillesse,
              onAvoirVieillesseChanged: (v) =>
                  setState(() => _currentAvoirVieillesse = v),
              couvertureInvalidite: _currentCouvertureInvalidite,
              onCouvertureInvaliditeChanged: (v) =>
                  setState(() => _currentCouvertureInvalidite = v),
              capitalDeces: _currentCapitalDeces,
              onCapitalDecesChanged: (v) =>
                  setState(() => _currentCapitalDeces = v),
              rachatMax: _currentRachatMax,
              onRachatMaxChanged: (v) =>
                  setState(() => _currentRachatMax = v),
              hasIjm: _currentHasIjm,
              onIjmChanged: (v) => setState(() => _currentHasIjm = v),
              accentColor: MintColors.primary,
              icon: Icons.business,
            ),
            const SizedBox(height: MintSpacing.lg),
            _buildJobSection(
              title: S.of(context)!.jobCompareNewJob,
              expanded: _newJobExpanded,
              onToggle: () =>
                  setState(() => _newJobExpanded = !_newJobExpanded),
              salaireBrut: _newSalaireBrut,
              onSalaireBrutChanged: (v) =>
                  setState(() => _newSalaireBrut = v),
              partEmployeur: _newPartEmployeur,
              onPartEmployeurChanged: (v) =>
                  setState(() => _newPartEmployeur = v),
              tauxConversion: _newTauxConversion,
              onTauxConversionChanged: (v) =>
                  setState(() => _newTauxConversion = v),
              avoirVieillesse: _newAvoirVieillesse,
              onAvoirVieillesseChanged: (v) =>
                  setState(() => _newAvoirVieillesse = v),
              couvertureInvalidite: _newCouvertureInvalidite,
              onCouvertureInvaliditeChanged: (v) =>
                  setState(() => _newCouvertureInvalidite = v),
              capitalDeces: _newCapitalDeces,
              onCapitalDecesChanged: (v) =>
                  setState(() => _newCapitalDeces = v),
              rachatMax: _newRachatMax,
              onRachatMaxChanged: (v) =>
                  setState(() => _newRachatMax = v),
              hasIjm: _newHasIjm,
              onIjmChanged: (v) => setState(() => _newHasIjm = v),
              accentColor: MintColors.deepOrange,
              icon: Icons.work_outline,
            ),
            const SizedBox(height: MintSpacing.lg),
            _buildCompareButton(),
            const SizedBox(height: MintSpacing.lg),
            if (_result != null) ...[
              Container(key: _resultsKey),
              _buildVerdictCard(),
              const SizedBox(height: MintSpacing.lg),
              _buildComparisonTable(),
              const SizedBox(height: MintSpacing.lg),
              _buildLifetimeImpactCard(),
              const SizedBox(height: MintSpacing.lg),
              if (_result!.alerts.isNotEmpty) ...[
                _buildAlertsSection(),
                const SizedBox(height: MintSpacing.lg),
              ],
              _buildChecklistSection(),
              const SizedBox(height: MintSpacing.lg),
            ],
            _buildEducationalFooter(),
            const SizedBox(height: MintSpacing.lg),
            // P11-A : Le prix du changement
            JobChangeComparisonWidget(
              currentJobLabel: S.of(context)!.jobCompareCurrentJobWidget,
              newJobLabel: S.of(context)!.jobCompareNewJobWidget,
              axes: [
                JobAxis(
                  label: S.of(context)!.jobCompareAxisSalary,
                  emoji: '\u{1F4B0}',
                  currentValue: _currentSalaireBrut / 12,
                  newValue: _newSalaireBrut / 12,
                  unit: 'CHF/mois',
                ),
                JobAxis(
                  label: S.of(context)!.jobCompareAxisLpp,
                  emoji: '\u{1F3E6}',
                  currentValue: _currentSalaireBrut * 0.18 / 12,
                  newValue: _newSalaireBrut * 0.18 / 12,
                  unit: 'CHF/mois',
                ),
                JobAxis(
                  label: S.of(context)!.jobCompareAxisDistance,
                  emoji: '\u{1F686}',
                  currentValue: 15,
                  newValue: 30,
                  unit: 'km',
                  higherIsBetter: false,
                ),
                JobAxis(
                  label: S.of(context)!.jobCompareAxisVacation,
                  emoji: '\u{1F3D6}\u{FE0F}',
                  currentValue: 20,
                  newValue: 25,
                  unit: 'jours',
                ),
                JobAxis(
                  label: S.of(context)!.jobCompareAxisWeeklyHours,
                  emoji: '\u{23F0}',
                  currentValue: 42,
                  newValue: 40,
                  unit: 'h',
                  higherIsBetter: false,
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.lg),
            _buildDisclaimer(),
            const SizedBox(height: MintSpacing.xl),
          ],
        ),
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MintColors.deepOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.swap_horiz,
                color: MintColors.deepOrange, size: 24),
          ),
          const SizedBox(width: MintSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.jobCompareTitle,
                  style: MintTextStyles.titleMedium(),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  S.of(context)!.jobCompareSubtitle,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Introduction Card ---
  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.deepOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.deepOrange.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              size: 20, color: MintColors.deepOrange.withValues(alpha: 0.8)),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              S.of(context)!.jobCompareIntro,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // --- Age Slider ---
  Widget _buildAgeSlider() {
    return SimulatorCard(
      title: S.of(context)!.jobCompareAgeTitle,
      subtitle: S.of(context)!.jobCompareAgeSubtitle,
      icon: Icons.person_outline,
      child: MintPickerTile(
        label: 'Age',
        value: _age,
        minValue: 25,
        maxValue: 64,
        formatValue: (v) => '$v ans',
        onChanged: (v) => setState(() => _age = v),
      ),
    );
  }

  // --- Job Section (Collapsible) ---
  Widget _buildJobSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required double salaireBrut,
    required ValueChanged<double> onSalaireBrutChanged,
    required double partEmployeur,
    required ValueChanged<double> onPartEmployeurChanged,
    required double tauxConversion,
    required ValueChanged<double> onTauxConversionChanged,
    required double avoirVieillesse,
    required ValueChanged<double> onAvoirVieillesseChanged,
    required double couvertureInvalidite,
    required ValueChanged<double> onCouvertureInvaliditeChanged,
    required double capitalDeces,
    required ValueChanged<double> onCapitalDecesChanged,
    required double rachatMax,
    required ValueChanged<double> onRachatMaxChanged,
    required bool hasIjm,
    required ValueChanged<bool> onIjmChanged,
    required Color accentColor,
    required IconData icon,
  }) {
    return SimulatorCard(
      title: title,
      subtitle: _chfFmt(salaireBrut),
      icon: icon,
      accentColor: accentColor,
      child: Column(
        children: [
          // Collapse toggle
          Semantics(
            label: expanded ? S.of(context)!.jobCompareReduce : S.of(context)!.jobCompareShowDetails,
            button: true,
            child: InkWell(
              onTap: onToggle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    expanded ? S.of(context)!.jobCompareReduce : S.of(context)!.jobCompareShowDetails,
                  style: MintTextStyles.labelSmall(color: accentColor),
                ),
                const SizedBox(width: MintSpacing.xs),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: accentColor,
                ),
              ],
            ),
          ),
          ),
          if (expanded) ...[
            const SizedBox(height: MintSpacing.md),
            MintAmountField(
              label: S.of(context)!.jobCompareSalaryLabel,
              value: salaireBrut,
              formatValue: (v) => _chfFmt(v),
              onChanged: (v) => setState(() => onSalaireBrutChanged(v)),
              min: 40000,
              max: 250000,
            ),
            const SizedBox(height: MintSpacing.md),
            _buildPartEmployeurChips(
              value: partEmployeur,
              onChanged: onPartEmployeurChanged,
              accentColor: accentColor,
            ),
            const SizedBox(height: MintSpacing.md),
            MintPremiumSlider(
              label: S.of(context)!.jobCompareConversionRate,
              value: tauxConversion,
              min: 4.0,
              max: 6.8,
              divisions: 28,
              formatValue: (v) => '${v.toStringAsFixed(1)}\u00A0%',
              onChanged: (v) => setState(() => onTauxConversionChanged(v)),
            ),
            const SizedBox(height: MintSpacing.md),
            MintAmountField(
              label: S.of(context)!.jobCompareRetirementAssets,
              value: avoirVieillesse,
              formatValue: (v) => _chfFmt(v),
              onChanged: (v) => setState(() => onAvoirVieillesseChanged(v)),
              min: 0,
              max: 1000000,
            ),
            const SizedBox(height: MintSpacing.md),
            MintPremiumSlider(
              label: S.of(context)!.jobCompareDisabilityCoverage,
              value: couvertureInvalidite,
              min: 0,
              max: 80,
              divisions: 16,
              formatValue: (v) => '${v.toInt()}\u00A0%',
              onChanged: (v) => setState(() => onCouvertureInvaliditeChanged(v)),
            ),
            const SizedBox(height: MintSpacing.md),
            MintAmountField(
              label: S.of(context)!.jobCompareDeathCapital,
              value: capitalDeces,
              formatValue: (v) => _chfFmt(v),
              onChanged: (v) => setState(() => onCapitalDecesChanged(v)),
              min: 0,
              max: 500000,
            ),
            const SizedBox(height: MintSpacing.md),
            MintAmountField(
              label: S.of(context)!.jobCompareMaxBuyback,
              value: rachatMax,
              formatValue: (v) => _chfFmt(v),
              onChanged: (v) => setState(() => onRachatMaxChanged(v)),
              min: 0,
              max: 500000,
            ),
            const SizedBox(height: MintSpacing.md),
            _buildIjmSwitch(
              value: hasIjm,
              onChanged: onIjmChanged,
            ),
          ],
        ],
      ),
    );
  }

  // --- Part Employeur Chips ---
  Widget _buildPartEmployeurChips({
    required double value,
    required ValueChanged<double> onChanged,
    required Color accentColor,
  }) {
    final options = [50.0, 55.0, 60.0, 65.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              S.of(context)!.jobCompareEmployerShare,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
            Text(
              '${value.toInt()}%',
              style: MintTextStyles.bodySmall(color: accentColor),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm),
        Row(
          children: options.map((opt) {
            final selected = value == opt;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: opt != options.last ? MintSpacing.sm : 0,
                ),
                child: Semantics(
                  label: '${opt.toInt()}% part employeur',
                  button: true,
                  selected: selected,
                  child: GestureDetector(
                    onTap: () => onChanged(opt),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? accentColor.withValues(alpha: 0.1)
                          : MintColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? accentColor
                            : MintColors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${opt.toInt()}%',
                        style: MintTextStyles.bodySmall(
                          color: selected
                              ? accentColor
                              : MintColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- IJM Switch ---
  Widget _buildIjmSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Semantics(
      label: S.of(context)!.jobCompareIjm,
      toggled: value,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              S.of(context)!.jobCompareIjm,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: MintColors.primary,
          ),
        ],
      ),
    );
  }

  // --- Compare Button ---
  Widget _buildCompareButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _compare,
        icon: const Icon(Icons.compare_arrows, size: 20),
        label: Text(
          S.of(context)!.jobCompareButton,
          style: MintTextStyles.titleMedium(color: MintColors.white),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: MintColors.primary,
          foregroundColor: MintColors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // --- Verdict Card ---
  Widget _buildVerdictCard() {
    final r = _result!;
    Color verdictColor;
    IconData verdictIcon;

    switch (r.verdict) {
      case ComparisonVerdict.nouveauMeilleur:
        verdictColor = MintColors.success;
        verdictIcon = Icons.thumb_up_outlined;
      case ComparisonVerdict.actuelMeilleur:
        verdictColor = MintColors.error;
        verdictIcon = Icons.warning_amber_rounded;
      case ComparisonVerdict.comparable:
        verdictColor = MintColors.warning;
        verdictIcon = Icons.balance;
    }

    return Semantics(
      label: r.verdictDetail,
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              verdictColor.withValues(alpha: 0.08),
              verdictColor.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: verdictColor.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: verdictColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(verdictIcon, color: MintColors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        S.of(context)!.jobCompareVerdictLabel,
                        style: MintTextStyles.labelSmall(color: MintColors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.md),
            Text(
              r.verdictDetail,
              style: MintTextStyles.headlineMedium().copyWith(fontSize: 20),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              S.of(context)!.jobCompareAxesFavorable(
                '${r.axes.where((a) => a.isPositive).length}',
                '${r.axes.length}',
              ),
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // --- 7-Axis Comparison Table ---
  Widget _buildComparisonTable() {
    final r = _result!;
    return SimulatorCard(
      title: S.of(context)!.jobCompareDetailedTitle,
      subtitle: S.of(context)!.jobCompareDetailedSubtitle,
      icon: Icons.table_chart_outlined,
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm, vertical: 10),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    S.of(context)!.jobCompareAxisLabel,
                    style: MintTextStyles.labelSmall(),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    S.of(context)!.jobCompareCurrentLabel,
                    textAlign: TextAlign.right,
                    style: MintTextStyles.labelSmall(),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    S.of(context)!.jobCompareNewLabel,
                    textAlign: TextAlign.right,
                    style: MintTextStyles.labelSmall(),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    S.of(context)!.jobCompareDeltaLabel,
                    textAlign: TextAlign.right,
                    style: MintTextStyles.labelSmall(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.xs),
          // Data rows
          ...List.generate(r.axes.length, (index) {
            final axis = r.axes[index];
            final isEven = index % 2 == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm, vertical: 12),
              decoration: BoxDecoration(
                color: isEven
                    ? MintColors.transparent
                    : MintColors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(
                    color: axis.isPositive
                        ? MintColors.success.withValues(alpha: 0.5)
                        : MintColors.error.withValues(alpha: 0.5),
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Icon(
                          axis.isPositive
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          size: 14,
                          color: axis.isPositive
                              ? MintColors.success
                              : MintColors.error,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            axis.name,
                            style: MintTextStyles.labelSmall(color: MintColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatChfSwiss(axis.currentValue),
                      textAlign: TextAlign.right,
                      style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatChfSwiss(axis.newValue),
                      textAlign: TextAlign.right,
                      style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _deltaFmt(axis.delta),
                      textAlign: TextAlign.right,
                      style: MintTextStyles.labelSmall(
                        color: axis.isPositive
                            ? MintColors.success
                            : MintColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- Lifetime Impact Card ---
  Widget _buildLifetimeImpactCard() {
    final r = _result!;
    final annualDelta = r.annualPensionDelta;
    final monthlyDelta = annualDelta / 12;
    final isPositive = annualDelta >= 0;
    return Semantics(
      label: S.of(context)!.jobCompareRetirementImpact,
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.info.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, color: MintColors.info, size: 18),
                const SizedBox(width: MintSpacing.sm),
                Text(
                  S.of(context)!.jobCompareRetirementImpact,
                  style: MintTextStyles.labelSmall(color: MintColors.info),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.md),
            Text(
              S.of(context)!.jobCompareRetirementBody(
                isPositive ? S.of(context)!.jobCompareNewJob : S.of(context)!.jobCompareCurrentJob,
                _chfFmt(annualDelta.abs()),
                _chfFmt(monthlyDelta.abs()),
              ),
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              S.of(context)!.jobCompareLifetime20Years(_chfFmt(r.lifetimePensionDelta.abs())),
              style: MintTextStyles.headlineMedium(color: MintColors.info).copyWith(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  // --- Alerts Section ---
  Widget _buildAlertsSection() {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.jobCompareAttentionPoints,
          style: MintTextStyles.labelSmall(),
        ),
        const SizedBox(height: MintSpacing.sm),
        ...r.alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MintColors.warning.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: MintColors.warning.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: MintColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        alert,
                        style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // --- Checklist Section ---
  Widget _buildChecklistSection() {
    final r = _result!;
    return SimulatorCard(
      title: S.of(context)!.jobCompareChecklistTitle,
      subtitle: S.of(context)!.jobCompareChecklistSub,
      icon: Icons.checklist,
      accentColor: MintColors.primary,
      child: Column(
        children: List.generate(r.checklist.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: MintSpacing.sm),
            child: Semantics(
              label: r.checklist[index],
              button: true,
              toggled: _checklistState[index],
              child: InkWell(
                onTap: () {
                  setState(() {
                    _checklistState[index] = !_checklistState[index];
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _checklistState[index]
                        ? MintColors.success.withValues(alpha: 0.06)
                        : MintColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _checklistState[index]
                          ? MintColors.success.withValues(alpha: 0.3)
                          : MintColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _checklistState[index]
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                        color: _checklistState[index]
                            ? MintColors.success
                            : MintColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          r.checklist[index],
                          style: MintTextStyles.bodySmall(
                            color: _checklistState[index]
                                ? MintColors.textSecondary
                                : MintColors.textPrimary,
                          ).copyWith(
                            decoration: _checklistState[index]
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
              ),
            ),
            ),
          );
        }),
      ),
    );
  }

  // --- Educational Footer ---
  Widget _buildEducationalFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.jobCompareUnderstandHeader,
          style: MintTextStyles.labelSmall(),
        ),
        const SizedBox(height: MintSpacing.sm),
        _buildExpandableTile(
          S.of(context)!.jobCompareEduInvisibleTitle,
          S.of(context)!.jobCompareEduInvisibleBody,
        ),
        const SizedBox(height: MintSpacing.sm),
        _buildExpandableTile(
          S.of(context)!.jobCompareEduCertTitle,
          S.of(context)!.jobCompareEduCertBody,
        ),
      ],
    );
  }

  // --- Expandable Tile ---
  Widget _buildExpandableTile(String title, String content) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: MintColors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: MintSpacing.md, vertical: MintSpacing.xs),
          childrenPadding: const EdgeInsets.fromLTRB(MintSpacing.md, 0, MintSpacing.md, MintSpacing.md),
          title: Text(
            title,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
          children: [
            Text(
              content,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // --- Disclaimer ---
  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: MintColors.warning),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              S.of(context)!.jobCompareDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

}
