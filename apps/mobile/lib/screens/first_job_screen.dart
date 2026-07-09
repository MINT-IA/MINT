import 'dart:math' show pow;
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/widgets/educational/salary_breakdown_widget.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/coach/first_salary_film_widget.dart';
import 'package:mint_mobile/widgets/coach/budget_503020_widget.dart';
import 'package:mint_mobile/widgets/coach/career_timelapse_widget.dart';
import 'package:mint_mobile/widgets/coach/payslip_xray_widget.dart';
import 'package:mint_mobile/widgets/coach/job_change_checklist_widget.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

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

class _FirstJobLedgerFacts {
  const _FirstJobLedgerFacts({
    required this.monthlySalary,
    required this.age,
    required this.canton,
  });

  const _FirstJobLedgerFacts.empty()
      : monthlySalary = null,
        age = null,
        canton = null;

  final double? monthlySalary;
  final int? age;
  final String? canton;

  bool get isComplete => monthlySalary != null && age != null && canton != null;

  bool hasSameValuesAs(_FirstJobLedgerFacts other) {
    return monthlySalary == other.monthlySalary &&
        age == other.age &&
        canton == other.canton;
  }
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
  _FirstJobLedgerFacts _facts = const _FirstJobLedgerFacts.empty();

  // Checklist tracking
  final Set<int> _checkedItems = {};

  @override
  void initState() {
    super.initState();
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
    final profile = context.watch<CoachProfileProvider>().profile;
    final facts = _ledgerFactsFromProfile(profile);
    final factsChanged = !_facts.hasSameValuesAs(facts);
    _facts = facts;
    if (!facts.isComplete) {
      _result = null;
      return;
    }
    if (factsChanged) {
      _salaire = facts.monthlySalary!;
      _age = facts.age!;
      _canton = facts.canton!;
    }
    _result = _analyzeCurrentFacts();
  }

  _FirstJobLedgerFacts _ledgerFactsFromProfile(CoachProfile? profile) {
    if (profile == null) return const _FirstJobLedgerFacts.empty();
    final provided = profile.userProvidedFields;
    final monthlySalary =
        provided.contains('salary') && profile.salaireBrutMensuel > 0
            ? profile.salaireBrutMensuel
            : null;
    final age =
        provided.contains('age') && profile.age > 0 ? profile.age : null;
    final canton = provided.contains('canton') && profile.canton.isNotEmpty
        ? profile.canton
        : null;
    return _FirstJobLedgerFacts(
      monthlySalary: monthlySalary,
      age: age,
      canton: canton,
    );
  }

  FirstJobResult _analyzeCurrentFacts() {
    return FirstJobService.analyzeSalary(
      salaireBrutMensuel: _salaire,
      age: _age,
      canton: _canton,
      tauxActivite: _tauxActivite,
    );
  }

  void _calculate() {
    if (!_facts.isComplete) {
      setState(() => _result = null);
      return;
    }
    setState(() {
      _result = _analyzeCurrentFacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _emitFinalReturn();
      },
      child: Scaffold(
          backgroundColor: MintColors.background,
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
                                child: _buildHeader()),
                            const SizedBox(height: MintSpacing.md + 4),
                            MintEntrance(
                                delay: const Duration(milliseconds: 200),
                                child: _buildLedgerFactsCard(
                                    context, S.of(context)!)),
                            const SizedBox(height: MintSpacing.md + 4),
                            if (_facts.isComplete) ...[
                              MintEntrance(
                                  delay: const Duration(milliseconds: 300),
                                  child: _buildActivityRateSection()),
                              const SizedBox(height: MintSpacing.lg),
                            ],
                            if (_result != null) ...[
                              _buildPremierEclairage(),
                              const SizedBox(height: MintSpacing.lg),
                              SalaryBreakdownWidget(
                                brut: _result!.brut,
                                netEstime: _result!.netEstime,
                                cotisationsEmployeur:
                                    _result!.cotisationsEmployeur,
                                deductions: _result!.deductionItems,
                              ),
                              const SizedBox(height: MintSpacing.lg),
                              PayslipXRayWidget(
                                grossSalary: _result!.brut,
                                netSalary: _result!.netEstime,
                                employerHiddenCost: _result!.brut +
                                    _result!.cotisationsEmployeur,
                                deductions: _buildPayslipLines(_result!),
                              ),
                              const SizedBox(height: MintSpacing.lg),
                              _build3aRecommendation(),
                              const SizedBox(height: MintSpacing.lg),
                              _build3aWarning(),
                              const SizedBox(height: MintSpacing.lg),
                              _buildLamalComparison(),
                              const SizedBox(height: MintSpacing.lg),
                              _buildChecklist(),
                              const SizedBox(height: MintSpacing.lg),
                              Builder(
                                builder: (ctx) {
                                  final l = S.of(ctx)!;
                                  return JobChangeChecklistWidget(
                                    items: [
                                      ChecklistItem(
                                        deadline: l.firstJobChecklistDeadline1,
                                        emoji: '\u{1F4C4}',
                                        action: l.firstJobChecklistAction1,
                                        legalRef: 'LPP art. 3 — libre passage',
                                        consequence:
                                            l.firstJobChecklistConsequence1,
                                      ),
                                      ChecklistItem(
                                        deadline: l.firstJobChecklistDeadline2,
                                        emoji: '\u{1F3E6}',
                                        action: l.firstJobChecklistAction2,
                                        legalRef: 'OLP art. 3',
                                        consequence:
                                            l.firstJobChecklistConsequence2,
                                      ),
                                      ChecklistItem(
                                        deadline: l.firstJobChecklistDeadline3,
                                        emoji: '\u{1F6E1}\u{FE0F}',
                                        action: l.firstJobChecklistAction3,
                                        legalRef: 'LAMal art. 3',
                                      ),
                                      ChecklistItem(
                                        deadline: l.firstJobChecklistDeadline4,
                                        emoji: '\u{1F3E6}',
                                        action: l.firstJobChecklistAction4,
                                        legalRef: 'OPP3 art. 1',
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: MintSpacing.lg),
                              _buildEducation(),
                              const SizedBox(height: MintSpacing.lg),
                              _buildMintAnalysisSection(),
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

  Widget _buildHeader() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.celebration_outlined,
              color: MintColors.info, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.firstJobHeaderDesc,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ledger facts ──────────────────────────────────────────

  Widget _buildLedgerFactsCard(BuildContext context, S s) {
    final hasMissing = !_facts.isComplete;
    return Semantics(
      key: const Key('first_job_ledger_facts'),
      identifier: 'first_job_ledger_facts',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.md + 4),
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
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Semantics(
                  key: const Key('first_job_enrich_profile_cta'),
                  identifier: 'first_job_enrich_profile_cta',
                  button: true,
                  child: TextButton.icon(
                    onPressed: () {
                      _hasUserInteracted = true;
                      context.push('/data-block/revenu');
                    },
                    icon: Icon(
                      hasMissing
                          ? Icons.add_circle_outline
                          : Icons.edit_outlined,
                      size: 18,
                    ),
                    label:
                        Text(hasMissing ? s.dataQualityEnrich : s.commonEdit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            _buildFactRow(
              identifier: 'first_job_salary_fact',
              label: s.firstJobSalaryTitle,
              value: _facts.monthlySalary == null
                  ? s.dataBlockStatusMissing
                  : FirstJobService.formatChf(_facts.monthlySalary!),
              isMissing: _facts.monthlySalary == null,
            ),
            const SizedBox(height: MintSpacing.xs),
            _buildFactRow(
              identifier: 'first_job_age_fact',
              label: s.unemploymentAgeSliderTitle,
              value: _facts.age == null
                  ? s.dataBlockStatusMissing
                  : s.unemploymentAgeValue(_facts.age!),
              isMissing: _facts.age == null,
            ),
            const SizedBox(height: MintSpacing.xs),
            _buildFactRow(
              identifier: 'first_job_canton_fact',
              label: s.firstJobCantonLabel,
              value: _facts.canton ?? s.dataBlockStatusMissing,
              isMissing: _facts.canton == null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactRow({
    required String identifier,
    required String label,
    required String value,
    required bool isMissing,
  }) {
    return Semantics(
      key: Key(identifier),
      identifier: identifier,
      label: '$label, $value',
      container: true,
      child: Row(
        children: [
          Icon(
            isMissing ? Icons.help_outline : Icons.check_circle_outline,
            color: isMissing ? MintColors.warning : MintColors.success,
            size: 16,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: MintTextStyles.bodySmall(
              color: isMissing ? MintColors.warning : MintColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ── Scenario lever ────────────────────────────────────────

  Widget _buildActivityRateSection() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintPremiumSlider(
            label: S.of(context)!.firstJobActivityRate,
            value: _tauxActivite,
            min: 10,
            max: 100,
            divisions: 18,
            formatValue: (v) => '${v.toStringAsFixed(0)}\u00a0%',
            onChanged: (v) {
              _hasUserInteracted = true;
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
    return Semantics(
      key: const Key('first_job_result_cards'),
      identifier: 'first_job_result_cards',
      container: true,
      child: Container(
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
      ),
    );
  }

  List<PayslipLine> _buildPayslipLines(FirstJobResult result) {
    return result.deductionItems.map((item) {
      return PayslipLine(
        label: item.label,
        emoji: _payslipEmojiFor(item.label),
        amount: item.montant,
        percentage: item.pourcentage,
        explanation: _payslipExplanationFor(item.label),
        legalRef: _payslipLegalRefFor(item.label),
      );
    }).toList(growable: false);
  }

  String _payslipEmojiFor(String label) {
    if (label.startsWith('AVS')) return '\u{1F6E1}\u{FE0F}';
    if (label.contains('AC')) return '\u{1F4BC}';
    if (label.contains('AANP')) return '\u{1FA79}';
    if (label.contains('LPP')) return '\u{1F3E6}';
    return '\u{1F9FE}';
  }

  String _payslipExplanationFor(String label) {
    final l = S.of(context)!;
    if (label.startsWith('AVS')) return l.firstJobPayslipAvsExplanation;
    if (label.contains('AC')) return l.firstJobPayslipAcExplanation;
    if (label.contains('AANP')) return l.firstJobPayslipAanpExplanation;
    if (label.contains('LPP')) return l.firstJobPayslipLppExplanation;
    return l.firstJobPayslipOtherExplanation;
  }

  String? _payslipLegalRefFor(String label) {
    if (label.startsWith('AVS')) return 'LAVS art. 5';
    if (label.contains('AC')) return 'LACI art. 3';
    if (label.contains('AANP')) return 'LAA art. 91';
    if (label.contains('LPP')) return 'LPP art. 16';
    return null;
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
                    _hasUserInteracted = true;
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

  // ── Analyse MINT ───────────────────────────────────────────

  Widget _buildMintAnalysisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildScenarioChips(),
        const SizedBox(height: MintSpacing.md),
        FirstSalaryFilmWidget(grossMonthly: _salaire),
        const SizedBox(height: MintSpacing.md + 4),
        _buildBudget503020(),
        const SizedBox(height: MintSpacing.md + 4),
        _buildCareerTimeLapse(),
      ],
    );
  }

  /// Future Value of annuity: annual * ((1+r)^n - 1) / r
  static double _fvAnnuity(double annual, int years, {double r = 0.04}) {
    if (years <= 0) return 0;
    return annual * ((pow(1 + r, years) - 1) / r);
  }

  Widget _buildBudget503020() {
    final l10n = S.of(context)!;
    final net = _result?.netEstime ?? _salaire * 0.85;
    final annualSavings = net * 0.20 * 12;
    final years = (avsAgeReferenceHomme - _age).clamp(0, 45);
    final fv = _fvAnnuity(annualSavings, years);
    return Budget503020Widget(
      netSalary: net,
      categories: [
        BudgetCategory(
          label: l10n.firstJobBudgetBesoins,
          emoji: '\u{1F3E0}',
          percent: 50,
          amount: net * 0.50,
          examples: [
            l10n.firstJobBudgetLoyer,
            'LAMal',
            l10n.firstJobBudgetTransport,
            l10n.firstJobBudgetAlimentation,
          ],
        ),
        BudgetCategory(
          label: l10n.firstJobBudgetEnvies,
          emoji: '\u2728',
          percent: 30,
          amount: net * 0.30,
          examples: [
            l10n.firstJobBudgetLoisirs,
            l10n.firstJobBudgetRestaurants,
            l10n.firstJobBudgetVoyages,
            l10n.firstJobBudgetShopping,
          ],
        ),
        BudgetCategory(
          label: l10n.firstJobBudgetEpargne,
          emoji: '\u{1F3E6}',
          percent: 20,
          amount: net * 0.20,
          examples: [
            l10n.firstJobBudgetPilier3a,
            l10n.firstJobBudgetEpargneCourt,
            l10n.firstJobBudgetFondsUrgence,
          ],
        ),
      ],
      premierEclairage: l10n.firstJobBudgetPremierEclairage(
        '${(annualSavings.round() ~/ 1000)}\'000',
        '~${(fv.round() ~/ 1000)}\'000',
      ),
    );
  }

  Widget _buildCareerTimeLapse() {
    const monthly3a = pilier3aPlafondAvecLpp / 12;
    const annual3a = monthly3a * 12;

    final candidateAges = [22, 25, 30, 35].where((a) => a <= _age + 5).toList();
    final scenarioAges = candidateAges.isEmpty ? [_age] : candidateAges;
    final scenarios = scenarioAges
        .map((a) => TimeLapseScenario(
              startAge: a,
              capitalAt65:
                  _fvAnnuity(annual3a, (avsAgeReferenceHomme - a).clamp(0, 45)),
            ))
        .toList();

    return CareerTimeLapseWidget(
      scenarios: scenarios,
      monthly3aContribution: monthly3a,
      initialAge: _age,
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            S.of(context)!.firstJobAnalysisHeader,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.sm + 2, vertical: MintSpacing.xs),
          decoration: BoxDecoration(
            color: MintColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: MintColors.success.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            '\u{1F4CD} ${S.of(context)!.firstJobProfileBadge}',
            style: MintTextStyles.labelSmall(
              color: MintColors.success,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildScenarioChips() {
    final l10n = S.of(context)!;
    const median = 6500.0;
    final profileVal =
        (_facts.monthlySalary ?? _salaire).clamp(2000.0, 15000.0);
    final boosted = (profileVal * 1.20).clamp(2000.0, 15000.0);

    final scenarios = [
      (
        label: '\u{1F4CD} ${l10n.firstJobScenarioMySalary}',
        value: profileVal,
        active: (_salaire - profileVal).abs() < 50,
      ),
      (
        label: '\u{1F1E8}\u{1F1ED} ${l10n.firstJobScenarioMedianCH}',
        value: median,
        active: (_salaire - median).abs() < 50,
      ),
      (
        label: '\u2728 ${l10n.firstJobScenarioBoosted}',
        value: boosted,
        active: (_salaire - boosted).abs() < 50,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: scenarios.map((s) {
          return Padding(
            padding: const EdgeInsets.only(right: MintSpacing.sm),
            child: Semantics(
              label: l10n.firstJobScenarioSemantics(s.label),
              button: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _hasUserInteracted = true;
                  setState(() => _salaire = s.value);
                  _calculate();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.sm + 6, vertical: MintSpacing.sm),
                  decoration: BoxDecoration(
                    color: s.active ? MintColors.primary : MintColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: s.active ? MintColors.primary : MintColors.border,
                      width: s.active ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    '${s.label}  CHF ${FirstJobService.formatChf(s.value)}',
                    style: MintTextStyles.labelSmall(
                      color:
                          s.active ? MintColors.white : MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
