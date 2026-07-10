import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/job_comparison_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';
import 'package:mint_mobile/widgets/coach/job_change_comparison_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_count_up.dart';
import 'package:provider/provider.dart';

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

class _JobComparisonLedgerFacts {
  const _JobComparisonLedgerFacts({
    required this.currentSalaryAnnual,
    required this.age,
    required this.currentSalaryNeedsConfirmation,
  });

  const _JobComparisonLedgerFacts.empty()
      : currentSalaryAnnual = null,
        age = null,
        currentSalaryNeedsConfirmation = false;

  final double? currentSalaryAnnual;
  final int? age;
  final bool currentSalaryNeedsConfirmation;

  bool get hasRequired => currentSalaryAnnual != null && age != null;

  bool hasSameValuesAs(_JobComparisonLedgerFacts other) {
    return currentSalaryAnnual == other.currentSalaryAnnual &&
        age == other.age &&
        currentSalaryNeedsConfirmation == other.currentSalaryNeedsConfirmation;
  }
}

class _JobComparisonScreenState extends State<JobComparisonScreen> {
  // Scroll controller for smooth scroll to results
  final _scrollController = ScrollController();
  final _resultsKey = GlobalKey();
  _JobComparisonLedgerFacts _facts = const _JobComparisonLedgerFacts.empty();

  // Shared
  int get _age => _facts.age!;

  // Current job inputs
  double get _currentSalaireBrut => _facts.currentSalaryAnnual!;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final facts = _ledgerFactsFromProfile(
      Provider.of<CoachProfileProvider>(context).profile,
    );
    if (_facts.hasSameValuesAs(facts)) return;
    _facts = facts;
    _result = null;
    _checklistState = [];
  }

  _JobComparisonLedgerFacts _ledgerFactsFromProfile(CoachProfile? profile) {
    if (profile == null) return const _JobComparisonLedgerFacts.empty();
    final provided = profile.userProvidedFields;
    final currentSalary =
        provided.contains('salary') && profile.revenuBrutAnnuel > 0
            ? profile.revenuBrutAnnuel
            : null;
    final salarySource = profile.dataSources['salaireBrutMensuel'];
    final salaryNeedsConfirmation = currentSalary != null &&
        salarySource != ProfileDataSource.certificate &&
        salarySource != ProfileDataSource.crossValidated &&
        salarySource != ProfileDataSource.openBanking;
    final age = provided.contains('age') ? profile.ageOrNull : null;
    return _JobComparisonLedgerFacts(
      currentSalaryAnnual: currentSalary,
      age: age,
      currentSalaryNeedsConfirmation: salaryNeedsConfirmation,
    );
  }

  void _compare() {
    if (!_facts.hasRequired) return;
    final current = _currentPlanInput();
    final newJob = _newPlanInput();

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

  LPPPlanInput _currentPlanInput() {
    return LPPPlanInput(
      salaireBrut: _currentSalaireBrut,
      partEmployeurPct: _currentPartEmployeur,
      tauxConversionSurobligatoire: _currentTauxConversion,
      avoirVieillesse: _currentAvoirVieillesse,
      renteInvaliditePct: _currentCouvertureInvalidite,
      capitalDeces: _currentCapitalDeces,
      rachatMaximum: _currentRachatMax,
      hasIjm: _currentHasIjm,
    );
  }

  LPPPlanInput _newPlanInput() {
    return LPPPlanInput(
      salaireBrut: _newSalaireBrut,
      partEmployeurPct: _newPartEmployeur,
      tauxConversionSurobligatoire: _newTauxConversion,
      avoirVieillesse: _newAvoirVieillesse,
      renteInvaliditePct: _newCouvertureInvalidite,
      capitalDeces: _newCapitalDeces,
      rachatMaximum: _newRachatMax,
      hasIjm: _newHasIjm,
    );
  }

  double get _currentLppMonthlyContribution =>
      _currentPlanInput().totalCotisationAnnuelle / 12;

  double get _newLppMonthlyContribution =>
      _newPlanInput().totalCotisationAnnuelle / 12;

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
        key: const Key('job_compare_scroll'),
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.lg,
          vertical: MintSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MintEntrance(child: _buildHeader()),
            const SizedBox(height: MintSpacing.lg),
            MintEntrance(
              delay: const Duration(milliseconds: 100),
              child: _buildIntroCard(),
            ),
            const SizedBox(height: MintSpacing.lg),
            MintEntrance(
              delay: const Duration(milliseconds: 150),
              child: _buildLedgerFactsCard(),
            ),
            const SizedBox(height: MintSpacing.lg),
            if (_facts.hasRequired) ...[
              MintEntrance(
                delay: const Duration(milliseconds: 200),
                child: _buildJobSection(
                  title: S.of(context)!.jobCompareCurrentJob,
                  expanded: _currentJobExpanded,
                  onToggle: () => setState(
                      () => _currentJobExpanded = !_currentJobExpanded),
                  salaireBrut: _currentSalaireBrut,
                  onSalaireBrutChanged: null,
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
              ),
              const SizedBox(height: MintSpacing.lg),
              MintEntrance(
                delay: const Duration(milliseconds: 250),
                child: _buildJobSection(
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
                  onRachatMaxChanged: (v) => setState(() => _newRachatMax = v),
                  hasIjm: _newHasIjm,
                  onIjmChanged: (v) => setState(() => _newHasIjm = v),
                  accentColor: MintColors.deepOrange,
                  icon: Icons.work_outline,
                ),
              ),
              const SizedBox(height: MintSpacing.lg),
              _buildCompareButton(),
              const SizedBox(height: MintSpacing.lg),
            ],
            if (_result != null) ...[
              Container(key: _resultsKey),
              KeyedSubtree(
                key: const Key('job_compare_result'),
                child: MintEntrance(child: _buildVerdictCard()),
              ),
              const SizedBox(height: MintSpacing.lg),
              MintEntrance(
                delay: const Duration(milliseconds: 100),
                child: _buildComparisonTable(),
              ),
              const SizedBox(height: MintSpacing.lg),
              MintEntrance(
                delay: const Duration(milliseconds: 200),
                child: _buildLifetimeImpactCard(),
              ),
              const SizedBox(height: MintSpacing.lg),
              if (_result!.alerts.isNotEmpty) ...[
                MintEntrance(
                  delay: const Duration(milliseconds: 300),
                  child: _buildAlertsSection(),
                ),
                const SizedBox(height: MintSpacing.lg),
              ],
              MintEntrance(
                delay: const Duration(milliseconds: 350),
                child: _buildChecklistSection(),
              ),
              const SizedBox(height: MintSpacing.lg),
            ],
            _buildEducationalFooter(),
            const SizedBox(height: MintSpacing.lg),
            // P11-A : Le prix du changement
            if (_facts.hasRequired) ...[
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
                    currentValue: _currentLppMonthlyContribution,
                    newValue: _newLppMonthlyContribution,
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
            ],
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
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
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

  Widget _buildLedgerFactsCard() {
    final s = S.of(context)!;
    final hasMissing = !_facts.hasRequired;
    final salary = _facts.currentSalaryAnnual;
    final age = _facts.age;
    final inputKey = salary == null
        ? 'q_gross_salary_annual'
        : age == null
            ? 'q_birth_year'
            : null;
    final route = inputKey == null
        ? '/data-block/revenu'
        : '/data-block/revenu?inputKey=$inputKey';

    return Semantics(
      key: const Key('job_compare_ledger_facts'),
      identifier: 'job_compare_ledger_facts',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasMissing
                      ? Icons.manage_search_outlined
                      : Icons.check_circle_outline,
                  color: hasMissing ? MintColors.warning : MintColors.success,
                  size: 20,
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    hasMissing
                        ? s.dataQualityMissingSection
                        : s.dataQualityKnownSection,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  key: const Key('job_compare_ledger_fact_cta'),
                  onPressed: () => context.push(route),
                  icon: Icon(
                    hasMissing ? Icons.add_circle_outline : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: Text(hasMissing ? s.dataQualityEnrich : s.commonEdit),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            _buildLedgerFactRow(
              key: const Key('job_compare_current_salary_fact'),
              identifier: 'job_compare_current_salary_fact',
              label: s.jobCompareSalaryLabel,
              value:
                  salary == null ? s.dataBlockStatusMissing : _chfFmt(salary),
              isMissing: salary == null,
              status: _facts.currentSalaryNeedsConfirmation
                  ? s.agentFormEstimated
                  : null,
            ),
            const SizedBox(height: MintSpacing.xs),
            _buildLedgerFactRow(
              key: const Key('job_compare_age_fact'),
              identifier: 'job_compare_age_fact',
              label: s.jobCompareAgeTitle,
              value: age == null ? s.dataBlockStatusMissing : '$age ans',
              isMissing: age == null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerFactRow({
    required Key key,
    required String identifier,
    required String label,
    required String value,
    required bool isMissing,
    String? status,
  }) {
    final isEstimated = status != null && !isMissing;
    return Semantics(
      key: key,
      identifier: identifier,
      label: status == null ? '$label, $value' : '$label, $value, $status',
      container: true,
      child: Row(
        children: [
          Icon(
            isMissing
                ? Icons.help_outline
                : isEstimated
                    ? Icons.info_outline
                    : Icons.check_circle_outline,
            color: isMissing || isEstimated
                ? MintColors.warning
                : MintColors.success,
            size: 16,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: MintTextStyles.bodySmall(
                    color:
                        isMissing ? MintColors.warning : MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                if (status != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    status,
                    textAlign: TextAlign.end,
                    style: MintTextStyles.labelSmall(
                      color: MintColors.warning,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Job Section (Collapsible) ---
  Widget _buildJobSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required double salaireBrut,
    required ValueChanged<double>? onSalaireBrutChanged,
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
            label: expanded
                ? S.of(context)!.jobCompareReduce
                : S.of(context)!.jobCompareShowDetails,
            button: true,
            child: InkWell(
              onTap: onToggle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    expanded
                        ? S.of(context)!.jobCompareReduce
                        : S.of(context)!.jobCompareShowDetails,
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
            if (onSalaireBrutChanged == null)
              _buildReadOnlySalaryRow(salaireBrut)
            else
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
              onChanged: (v) =>
                  setState(() => onCouvertureInvaliditeChanged(v)),
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

  Widget _buildReadOnlySalaryRow(double salaireBrut) {
    return Semantics(
      key: const Key('job_compare_current_salary_readonly'),
      identifier: 'job_compare_current_salary_readonly',
      container: true,
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 12,
        child: Row(
          children: [
            const Icon(Icons.lock_outline,
                color: MintColors.textMuted, size: 18),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Text(
                S.of(context)!.jobCompareSalaryLabel,
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary),
              ),
            ),
            Text(
              _chfFmt(salaireBrut),
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? accentColor.withValues(alpha: 0.1)
                            : MintColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? accentColor : MintColors.border,
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
    return Semantics(
      label: S.of(context)!.jobCompareButton,
      button: true,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('job_compare_submit'),
          onPressed: () {
            HapticFeedback.lightImpact();
            _compare();
          },
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

    final salaryDelta = _newSalaireBrut - _currentSalaireBrut;

    return Semantics(
      label: r.verdictDetail,
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        elevated: true,
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
                        style:
                            MintTextStyles.labelSmall(color: MintColors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.md),
            MintCountUp(
              value: salaryDelta.abs(),
              prefix: '${salaryDelta >= 0 ? '+' : '-'}CHF\u00a0',
              color: verdictColor,
              showLigne: false,
              contextText: S.of(context)!.jobCompareAxisSalary,
              semanticsLabel:
                  '${_deltaFmt(salaryDelta)} CHF — ${r.verdictDetail}',
            ),
            const SizedBox(height: MintSpacing.md),
            Text(
              r.verdictDetail,
              style: MintTextStyles.bodyLarge(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w500),
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
            padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.sm, vertical: 10),
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
              padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.sm, vertical: 12),
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
                            style: MintTextStyles.labelSmall(
                                color: MintColors.textPrimary),
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
                      style: MintTextStyles.labelSmall(
                          color: MintColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatChfSwiss(axis.newValue),
                      textAlign: TextAlign.right,
                      style: MintTextStyles.labelSmall(
                          color: MintColors.textSecondary),
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
      child: MintSurface(
        tone: MintSurfaceTone.bleu,
        elevated: true,
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
                    isPositive
                        ? S.of(context)!.jobCompareNewJob
                        : S.of(context)!.jobCompareCurrentJob,
                    _chfFmt(annualDelta.abs()),
                    _chfFmt(monthlyDelta.abs()),
                  ),
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              S.of(context)!.jobCompareLifetime20Years(
                  _chfFmt(r.lifetimePensionDelta.abs())),
              style: MintTextStyles.titleLarge(color: MintColors.info),
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
                        style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary),
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
          tilePadding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md, vertical: MintSpacing.xs),
          childrenPadding: const EdgeInsets.fromLTRB(
              MintSpacing.md, 0, MintSpacing.md, MintSpacing.md),
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
