import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/services/data_quest/first_salary_tax_3a_summary_service.dart';
import 'package:mint_mobile/widgets/educational/salary_breakdown_widget.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/coach/payslip_xray_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_signal_row.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  FIRST JOB SCREEN — Sprint S19 / Premier emploi
// ────────────────────────────────────────────────────────────
//
// Interactive first job salary analyzer.
// Category C — Life Event (DESIGN_SYSTEM §2C).
// ────────────────────────────────────────────────────────────

class FirstJobScreen extends StatefulWidget {
  const FirstJobScreen({super.key});

  @override
  State<FirstJobScreen> createState() => _FirstJobScreenState();
}

class _FirstJobScreenState extends State<FirstJobScreen> {
  bool _hasUserInteracted = false;
  String? _seqRunId;
  String? _seqStepId;
  bool _finalReturnEmitted = false;

  double _salaire = 5000;
  int _age = 25;
  String _canton = 'ZH';
  double _tauxActivite = 100;
  FirstJobResult? _result;
  bool _seededFromProfile = false;

  // Checklist tracking
  final Set<int> _checkedItems = {};

  // Swiss cantons
  static const List<String> _cantons = [
    'AG',
    'AI',
    'AR',
    'BE',
    'BL',
    'BS',
    'FR',
    'GE',
    'GL',
    'GR',
    'JU',
    'LU',
    'NE',
    'NW',
    'OW',
    'SG',
    'SH',
    'SO',
    'SZ',
    'TG',
    'TI',
    'UR',
    'VD',
    'VS',
    'ZG',
    'ZH',
  ];

  @override
  void initState() {
    super.initState();
    _calculate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readSequenceContext();
    });
  }

  void _readSequenceContext() {
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map<String, dynamic>) {
        _seqRunId = extra['runId'] as String?;
        _seqStepId = extra['stepId'] as String?;
      }
    } catch (_) {
      // Not navigated via GoRouter or no extra — stay Tier B.
    }
  }

  void _emitFinalReturn() {
    if (_finalReturnEmitted) return;
    if (_seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;

    if (!_hasUserInteracted) {
      final screenReturn = ScreenReturn.abandoned(
        route: '/first-job',
        runId: _seqRunId,
        stepId: _seqStepId,
        eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      ScreenCompletionTracker.markCompletedWithReturn(
          'first_job', screenReturn);
      return;
    }

    final screenReturn = ScreenReturn.completed(
      route: '/first-job',
      stepOutputs: {},
      runId: _seqRunId,
      stepId: _seqStepId,
      eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
    );
    ScreenCompletionTracker.markCompletedWithReturn('first_job', screenReturn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededFromProfile) return;
    final profile = context.read<CoachProfileProvider>().profile;
    if (profile == null) return;
    final age = DateTime.now().year - profile.birthYear;
    if (age > 30) return;
    _seededFromProfile = true;
    setState(() {
      _salaire = profile.salaireBrutMensuel.clamp(2000, 15000);
      _age = age.clamp(18, 30);
      if (profile.canton.isNotEmpty) _canton = profile.canton;
    });
    _calculate();
  }

  void _calculate() {
    setState(() {
      _result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: _salaire,
        age: _age,
        canton: _canton,
        tauxActivite: _tauxActivite,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<CoachProfileProvider>();
    final firstSalarySummary = FirstSalaryTax3aSummaryService.build(
      profile: profileProvider.profile,
      answers: profileProvider.lastAnswers,
      screenValues: FirstSalaryTax3aScreenValues(
        grossAnnualSalary: _salaire * 12,
        canton: _canton,
        age: _age,
      ),
    );
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _emitFinalReturn();
      },
      child: Scaffold(
          backgroundColor: MintColors.porcelaine,
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: CustomScrollView(
                    slivers: [
                      _buildAppBar(context),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                            MintSpacing.lg, 0, MintSpacing.lg, MintSpacing.lg),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            MintEntrance(
                                child: MintNarrativeCard(
                              headline:
                                  S.of(context)!.narrativeFirstJobHeadline,
                              body: S.of(context)!.narrativeFirstJobBody,
                              tone: MintSurfaceTone.sauge,
                              badge: S.of(context)!.narrativeFirstJobBadge,
                            )),
                            const SizedBox(height: MintSpacing.md + 4),
                            MintEntrance(
                                delay: const Duration(milliseconds: 100),
                                child: _buildSalaireSlider()),
                            const SizedBox(height: MintSpacing.md + 4),
                            MintEntrance(
                                delay: const Duration(milliseconds: 200),
                                child: _buildAgeSlider()),
                            const SizedBox(height: MintSpacing.md + 4),
                            MintEntrance(
                                delay: const Duration(milliseconds: 300),
                                child: _buildCantonAndActivity()),
                            const SizedBox(height: MintSpacing.lg),
                            MintEntrance(
                              delay: const Duration(milliseconds: 80),
                              child: _buildFirstSalaryTax3aSummary(
                                  firstSalarySummary),
                            ),
                            const SizedBox(height: MintSpacing.lg),
                            if (_result != null) ...[
                              _buildPremierEclairage(),
                              const SizedBox(height: MintSpacing.lg),
                            ],
                            if (_result != null) ...[
                              SalaryBreakdownWidget(
                                brut: _result!.brut,
                                netEstime: _result!.netEstime,
                                cotisationsEmployeur:
                                    _result!.cotisationsEmployeur,
                                deductions: _result!.deductionItems,
                              ),
                              const SizedBox(height: MintSpacing.lg),
                              _buildPayslipXRay(firstSalarySummary),
                              const SizedBox(height: MintSpacing.lg),
                              _build3aRecommendation(),
                              const SizedBox(height: MintSpacing.lg),
                              _build3aWarning(),
                              const SizedBox(height: MintSpacing.lg),
                              _buildLamalComparison(),
                              const SizedBox(height: MintSpacing.lg),
                              _buildChecklist(),
                              const SizedBox(height: MintSpacing.lg),
                              _buildEducation(),
                              const SizedBox(height: MintSpacing.lg),
                            ],
                            MintEntrance(
                                delay: const Duration(milliseconds: 400),
                                child: _buildDisclaimer()),
                            const SizedBox(height: 100),
                          ]),
                        ),
                      ),
                    ],
                  )))),
    );
  }

  // ── App Bar (white standard per DESIGN_SYSTEM §4.5) ──────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: Semantics(
        label: S.of(context)!.semanticsBackButton,
        button: true,
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () => safePop(context),
        ),
      ),
      title: Text(
        S.of(context)!.firstJobTitle,
        style: MintTextStyles.headlineMedium(),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildFirstSalaryTax3aSummary(FirstSalaryTax3aSummary summary) {
    final l = S.of(context)!;
    final result = summary.result;
    final showDataCta =
        summary.needsCoreData || summary.dataQuestAsks.isNotEmpty;

    if (result == null) {
      return MintSurface(
        key: const Key('first_salary_tax_3a_summary'),
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.lg),
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.firstJobG5Title,
              style: MintTextStyles.labelSmall(
                color: MintColors.corailDiscret,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: MintSpacing.md),
            Text(
              l.firstJobG5MissingBody,
              style: MintTextStyles.headlineSmall(
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            Wrap(
              spacing: MintSpacing.sm,
              runSpacing: MintSpacing.sm,
              children: [
                _buildFirstSalaryStatusChip(
                  key: const Key('first_salary_tax_3a_status_salary'),
                  label: l.firstJobG5StatusSalary,
                  status: summary.salaryStatus,
                ),
                _buildFirstSalaryStatusChip(
                  key: const Key('first_salary_tax_3a_status_canton'),
                  label: l.firstJobG5StatusCanton,
                  status: summary.cantonStatus,
                ),
                _buildFirstSalaryStatusChip(
                  key: const Key('first_salary_tax_3a_status_age'),
                  label: l.firstJobG5StatusAge,
                  status: summary.ageStatus,
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.lg),
            FilledButton.icon(
              key: const Key('first_salary_tax_3a_data_cta'),
              onPressed: () => context.push('/data-block/revenu'),
              icon: const Icon(Icons.edit_note_outlined, size: 18),
              label: Text(l.firstJobG5DataCta),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      key: const Key('first_salary_tax_3a_summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MintResultHeroCard(
          key: const Key('first_salary_tax_3a_room'),
          eyebrow: l.firstJobG5Title,
          primaryValue: formatChfWithPrefix(result.remaining3aRoom),
          primaryLabel: l.firstJobG5Remaining3a,
          secondaryValue: formatChfMonthly(result.netMonthlyPayslip),
          secondaryLabel: l.firstJobG5NetMonthly,
          narrative: l.firstJobG5KnownBody,
          accentColor: MintColors.textPrimary,
          tone: MintSurfaceTone.porcelaine,
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        MintSurface(
          tone: MintSurfaceTone.blanc,
          padding: const EdgeInsets.all(MintSpacing.md + 4),
          radius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: MintSpacing.sm,
                runSpacing: MintSpacing.sm,
                children: [
                  _buildFirstSalaryStatusChip(
                    key: const Key('first_salary_tax_3a_status_salary'),
                    label: l.firstJobG5StatusSalary,
                    status: summary.salaryStatus,
                  ),
                  _buildFirstSalaryStatusChip(
                    key: const Key('first_salary_tax_3a_status_canton'),
                    label: l.firstJobG5StatusCanton,
                    status: summary.cantonStatus,
                  ),
                  _buildFirstSalaryStatusChip(
                    key: const Key('first_salary_tax_3a_status_age'),
                    label: l.firstJobG5StatusAge,
                    status: summary.ageStatus,
                  ),
                  _buildFirstSalaryStatusChip(
                    key: Key(summary.pillar3aContributionStatus ==
                            FirstSalaryFactStatus.known
                        ? 'first_salary_tax_3a_status_3a_known'
                        : 'first_salary_tax_3a_status_3a_missing'),
                    label: l.firstJobG5Status3a,
                    status: summary.pillar3aContributionStatus,
                  ),
                ],
              ),
              const SizedBox(height: MintSpacing.md),
              Divider(
                color: MintColors.border.withValues(alpha: 0.35),
                height: 1,
              ),
              MintSignalRow(
                label: l.firstJobG5TaxAnnual,
                value: formatChfWithPrefix(result.income.incomeTaxEstimate),
              ),
              MintSignalRow(
                label: l.firstJobG5AdditionalSaving,
                value: formatChfWithPrefix(result.additional3aTaxSaving),
                valueColor: MintColors.successAaa,
              ),
              const SizedBox(height: MintSpacing.sm),
              Wrap(
                spacing: MintSpacing.sm,
                runSpacing: MintSpacing.sm,
                children: [
                  if (showDataCta)
                    OutlinedButton.icon(
                      key: const Key('first_salary_tax_3a_data_cta'),
                      onPressed: () => context.push('/data-block/revenu'),
                      icon: const Icon(Icons.edit_note_outlined, size: 18),
                      label: Text(l.firstJobG5DataCta),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MintColors.primary,
                        side: const BorderSide(color: MintColors.primary),
                      ),
                    ),
                  FilledButton.icon(
                    key: const Key('first_salary_tax_3a_pillar3a_cta'),
                    onPressed: () => context.push('/pilier-3a'),
                    icon: const Icon(Icons.savings_outlined, size: 18),
                    label: Text(l.firstJobG5Pillar3aCta),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      foregroundColor: MintColors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFirstSalaryStatusChip({
    required Key key,
    required String label,
    required FirstSalaryFactStatus status,
  }) {
    final statusColor = switch (status) {
      FirstSalaryFactStatus.known => MintColors.success,
      FirstSalaryFactStatus.stale => MintColors.warning,
      FirstSalaryFactStatus.missing => MintColors.textMuted,
    };
    return Container(
      key: key,
      padding:
          const EdgeInsets.symmetric(horizontal: MintSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label · ${_firstSalaryStatusText(status)}',
        style: MintTextStyles.labelSmall(color: statusColor),
      ),
    );
  }

  String _firstSalaryStatusText(FirstSalaryFactStatus status) {
    final l = S.of(context)!;
    return switch (status) {
      FirstSalaryFactStatus.known => l.firstJobG5StatusKnown,
      FirstSalaryFactStatus.stale => l.firstJobG5StatusStale,
      FirstSalaryFactStatus.missing => l.firstJobG5StatusMissing,
    };
  }

  Widget _buildPayslipXRay(FirstSalaryTax3aSummary summary) {
    final l = S.of(context)!;
    final r = _result!;
    final monthlyTax = summary.result?.monthlyIncomeTaxEstimate ?? 0;
    final deductions = <PayslipLine>[
      PayslipLine(
        label: l.firstJobPayslipAvsLabel,
        icon: Icons.security_outlined,
        amount: r.avsAiApg,
        percentage: _percentOfGross(r.avsAiApg),
        explanation: l.firstJobPayslipAvsExplanation,
        legalRef: 'LAVS art. 5',
      ),
      if (r.lppEmploye > 0)
        PayslipLine(
          label: l.firstJobPayslipLppLabel,
          icon: Icons.account_balance_outlined,
          amount: r.lppEmploye,
          percentage: _percentOfGross(r.lppEmploye),
          explanation: l.firstJobPayslipLppExplanation,
          legalRef: 'LPP art. 16',
        ),
      if (monthlyTax > 0)
        PayslipLine(
          label: l.firstJobPayslipImpotLabel,
          icon: Icons.receipt_long_outlined,
          amount: monthlyTax,
          percentage: _percentOfGross(monthlyTax),
          explanation: l.firstJobPayslipImpotExplanation,
          legalRef: 'LIFD art. 83',
        ),
    ];

    return PayslipXRayWidget(
      grossSalary: r.brut,
      netSalary: r.netEstime,
      employerHiddenCost: r.brut + r.cotisationsEmployeur,
      deductions: deductions,
    );
  }

  double _percentOfGross(double amount) {
    final gross = _result?.brut ?? 0;
    if (gross <= 0) return 0;
    return amount / gross * 100;
  }

  // ── Sliders ────────────────────────────────────────────────

  Widget _buildSalaireSlider() {
    return _buildSliderCard(
      title: S.of(context)!.firstJobSalaryTitle,
      valueLabel: FirstJobService.formatChf(_salaire),
      minLabel: S.of(context)!.firstJobSalaryMin,
      maxLabel: S.of(context)!.firstJobSalaryMax,
      value: _salaire,
      min: 2000,
      max: 15000,
      divisions: 260,
      onChanged: (v) {
        _hasUserInteracted = true;
        _salaire = v;
        _calculate();
      },
    );
  }

  Widget _buildAgeSlider() {
    return _buildSliderCard(
      title: S.of(context)!.unemploymentAgeSliderTitle,
      valueLabel: S.of(context)!.unemploymentAgeValue(_age),
      minLabel: S.of(context)!.unemploymentAgeMin,
      maxLabel: S.of(context)!.unemploymentAgeValue(30),
      value: _age.toDouble(),
      min: 18,
      max: 30,
      divisions: 12,
      onChanged: (v) {
        _hasUserInteracted = true;
        _age = v.toInt();
        _calculate();
      },
    );
  }

  Widget _buildSliderCard({
    required String title,
    required String valueLabel,
    required String minLabel,
    required String maxLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: MintPremiumSlider(
        label: title,
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        formatValue: (_) => valueLabel,
        onChanged: onChanged,
      ),
    );
  }

  // ── Canton + Activity Rate ─────────────────────────────────

  Widget _buildCantonAndActivity() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Canton dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.firstJobCantonLabel,
                style:
                    MintTextStyles.titleMedium(color: MintColors.textPrimary),
              ),
              Semantics(
                label: S.of(context)!.firstJobCantonLabel,
                button: true,
                child: MintSurface(
                  tone: MintSurfaceTone.porcelaine,
                  padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.sm + 4),
                  radius: 10,
                  child: DropdownButton<String>(
                    value: _canton,
                    underline: const SizedBox.shrink(),
                    style:
                        MintTextStyles.titleMedium(color: MintColors.primary),
                    items: _cantons.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _hasUserInteracted = true;
                        _canton = v;
                        _calculate();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md + 4),

          // Activity rate slider
          MintPremiumSlider(
            label: S.of(context)!.firstJobActivityRate,
            value: _tauxActivite,
            min: 10,
            max: 100,
            divisions: 18,
            formatValue: (v) => '${v.toStringAsFixed(0)}\u00a0%',
            onChanged: (v) {
              _tauxActivite = v;
              _calculate();
            },
          ),
        ],
      ),
    );
  }

  // ── Premier Éclairage ───────────────────────────────────────────

  Widget _buildPremierEclairage() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            FirstJobService.formatChf(r.cotisationsEmployeur),
            style: MintTextStyles.displayMedium(color: MintColors.white)
                .copyWith(fontSize: 36),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            r.premierEclairage,
            style: MintTextStyles.bodyMedium(
                color: MintColors.white.withValues(alpha: 0.9)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── 3a Recommendation ──────────────────────────────────────

  Widget _build3aRecommendation() {
    final r = _result!;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.firstJob3aHeader,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  S.of(context)!.firstJob3aAnnualCap,
                  FirstJobService.formatChf(r.plafondAnnuel3a),
                ),
              ),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: _buildMiniMetric(
                  S.of(context)!.firstJob3aMonthlySuggestion,
                  FirstJobService.formatChf(r.montantMensuelSuggere3a),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up,
                    size: 16, color: MintColors.success),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    S.of(context)!.firstJobFiscalSavings(
                        FirstJobService.formatChf(r.economieFiscaleEstimee3a)),
                    style: MintTextStyles.bodySmall(color: MintColors.success)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.sm + 6),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: MintTextStyles.titleMedium(color: MintColors.primary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── 3a WARNING ─────────────────────────────────────────────

  Widget _build3aWarning() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: MintColors.error.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: MintColors.error, size: 24),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.firstJob3aWarningTitle,
                  style: MintTextStyles.bodyMedium(color: MintColors.error)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.xs + 2),
                Text(
                  _result!.alerte3a,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── LAMal Franchise Comparison ─────────────────────────────

  Widget _buildLamalComparison() {
    final r = _result!;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.firstJobLamalHeader,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          // Franchise cards
          ...r.franchiseOptions.map((option) {
            final isRecommended = option.franchise == r.franchiseRecommandee;
            return Container(
              margin: const EdgeInsets.only(bottom: MintSpacing.sm),
              padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.sm + 6, vertical: MintSpacing.sm + 4),
              decoration: BoxDecoration(
                color: isRecommended
                    ? MintColors.success.withValues(alpha: 0.06)
                    : MintColors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isRecommended
                    ? Border.all(
                        color: MintColors.success.withValues(alpha: 0.15))
                    : Border.all(
                        color: MintColors.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  if (isRecommended)
                    Container(
                      margin: const EdgeInsets.only(right: MintSpacing.sm),
                      padding: const EdgeInsets.symmetric(
                          horizontal: MintSpacing.xs + 2, vertical: 2),
                      decoration: BoxDecoration(
                        color: MintColors.success,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        S.of(context)!.firstJobTopBadge,
                        style: MintTextStyles.labelSmall(
                                color: MintColors.white)
                            .copyWith(fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'CHF\u00a0${option.franchise}',
                      style: MintTextStyles.bodyMedium(
                        color: isRecommended
                            ? MintColors.success
                            : MintColors.textPrimary,
                      ).copyWith(
                          fontWeight: isRecommended
                              ? FontWeight.w700
                              : FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      S.of(context)!.firstJobPrimePerMonth(
                          FirstJobService.formatChf(option.primeMensuelle)),
                      style: MintTextStyles.labelSmall(
                          color: MintColors.textSecondary),
                    ),
                  ),
                  Text(
                    S.of(context)!.firstJobCoutMaxPerYear(
                        FirstJobService.formatChf(option.coutAnnuelMax)),
                    style: MintTextStyles.labelSmall(),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: MintSpacing.sm + 4),

          // Savings highlight
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined,
                    size: 16, color: MintColors.success),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    S.of(context)!.firstJobFranchiseSavings(
                        FirstJobService.formatChf(r.economieAnnuelleVs300)),
                    style: MintTextStyles.bodySmall(color: MintColors.success)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Note
          Text(
            r.noteLamal,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Checklist ──────────────────────────────────────────────

  Widget _buildChecklist() {
    final items = _result?.checklist ?? [];
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.firstJobChecklistHeader,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          ...List.generate(items.length, (index) {
            final checked = _checkedItems.contains(index);
            return Semantics(
              label: '${S.of(context)!.firstJobChecklistHeader} ${index + 1}',
              button: true,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (checked) {
                      _checkedItems.remove(index);
                    } else {
                      _checkedItems.add(index);
                    }
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: MintSpacing.sm + 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color:
                              checked ? MintColors.success : MintColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: checked
                                ? MintColors.success
                                : MintColors.border,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: checked
                            ? const Icon(Icons.check,
                                size: 16, color: MintColors.white)
                            : Text(
                                '${index + 1}',
                                style: MintTextStyles.labelSmall(
                                    color: MintColors.textSecondary),
                              ),
                      ),
                      const SizedBox(width: MintSpacing.sm + 4),
                      Expanded(
                        child: Text(
                          items[index],
                          style: MintTextStyles.bodyMedium(
                            color: checked
                                ? MintColors.textMuted
                                : MintColors.textPrimary,
                          ).copyWith(
                            decoration:
                                checked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Education ──────────────────────────────────────────────

  Widget _buildEducation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: MintSpacing.sm),
            Text(
              S.of(context)!.unemploymentGoodToKnow,
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildEduCard(
          Icons.account_balance_outlined,
          S.of(context)!.firstJobEduLppTitle,
          S.of(context)!.firstJobEduLppBody,
        ),
        _buildEduCard(
          Icons.receipt_long_outlined,
          S.of(context)!.firstJobEdu13Title,
          S.of(context)!.firstJobEdu13Body,
        ),
        _buildEduCard(
          Icons.savings_outlined,
          S.of(context)!.firstJobEduBudgetTitle,
          S.of(context)!.firstJobEduBudgetBody,
        ),
        _buildEduCard(
          Icons.description_outlined,
          S.of(context)!.firstJobEduTaxTitle,
          S.of(context)!.firstJobEduTaxBody,
        ),
      ],
    );
  }

  Widget _buildEduCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MintSurface(
              padding: const EdgeInsets.all(MintSpacing.sm),
              radius: 10,
              child: Icon(icon, size: 18, color: MintColors.primary),
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    body,
                    style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

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
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.firstJobDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
