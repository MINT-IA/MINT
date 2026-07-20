import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:provider/provider.dart';

class FirstJobScreen extends StatefulWidget {
  const FirstJobScreen({super.key});

  @override
  State<FirstJobScreen> createState() => _FirstJobScreenState();
}

class _FirstJobFacts {
  const _FirstJobFacts({this.salary, this.age, this.canton});

  final double? salary;
  final int? age;
  final String? canton;

  bool get complete => salary != null && age != null && canton != null;
}

class _FirstJobScreenState extends State<FirstJobScreen> {
  bool _hasUserInteracted = false;
  bool _finalReturnEmitted = false;
  String? _seqRunId;
  String? _seqStepId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readSequenceContext());
  }

  void _readSequenceContext() {
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map<String, dynamic>) {
        _seqRunId = extra['runId'] as String?;
        _seqStepId = extra['stepId'] as String?;
      }
    } catch (_) {
      // A directly mounted widget has no GoRouter sequence context.
    }
  }

  void _emitFinalReturn() {
    if (_finalReturnEmitted || _seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;
    final eventId = 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}';
    final value = _hasUserInteracted
        ? ScreenReturn.completed(
            route: '/first-job',
            stepOutputs: const {},
            runId: _seqRunId,
            stepId: _seqStepId,
            eventId: eventId,
          )
        : ScreenReturn.abandoned(
            route: '/first-job',
            runId: _seqRunId,
            stepId: _seqStepId,
            eventId: eventId,
          );
    ScreenCompletionTracker.markCompletedWithReturn('first_job', value);
  }

  _FirstJobFacts _facts(CoachProfile? profile) {
    if (profile == null) return const _FirstJobFacts();
    final provided = profile.userProvidedFields;
    return _FirstJobFacts(
      salary: provided.contains('salary') && profile.salaireBrutMensuel > 0
          ? profile.salaireBrutMensuel
          : null,
      age: provided.contains('age') && profile.age > 0 ? profile.age : null,
      canton: provided.contains('canton') && profile.canton.isNotEmpty
          ? profile.canton
          : null,
    );
  }

  String _revenueRoute() => Uri(
        path: '/data-block/revenu',
        queryParameters: const {'returnUri': '/first-job'},
      ).toString();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final facts = _facts(context.watch<CoachProfileProvider>().profile);
    final result = facts.complete
        ? FirstJobService.analyzeSalary(
            salaireBrutMensuel: facts.salary!,
            age: facts.age!,
            canton: facts.canton!,
          )
        : null;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _emitFinalReturn();
      },
      child: Scaffold(
        backgroundColor: MintColors.background,
        appBar: AppBar(
          backgroundColor: MintColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _emitFinalReturn();
              safePop(context);
            },
          ),
          title: Text(s.firstJobTitle),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(MintSpacing.lg),
              children: [
                Text(
                  s.firstJobCoherenceIntro,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary,
                  ).copyWith(height: 1.45),
                ),
                const SizedBox(height: MintSpacing.lg),
                _enrichmentCta(context, s),
                const SizedBox(height: MintSpacing.md),
                if (result == null)
                  _missingFactsCard(context, s, facts)
                else ...[
                  _salaryAuthority(s, result, facts),
                  const SizedBox(height: MintSpacing.md),
                  _neutral3a(s),
                  const SizedBox(height: MintSpacing.md),
                  _lamalHandoff(context, s),
                  const SizedBox(height: MintSpacing.md),
                  _checklist(s),
                  const SizedBox(height: MintSpacing.md),
                  _card(
                    child: Text(
                      s.firstJobNoProjection,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ).copyWith(height: 1.45),
                    ),
                  ),
                ],
                const SizedBox(height: MintSpacing.lg),
                Text(
                  s.firstJobDisclaimer,
                  textAlign: TextAlign.center,
                  style: MintTextStyles.labelSmall(color: MintColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _missingFactsCard(BuildContext context, S s, _FirstJobFacts facts) {
    return _card(
      key: const Key('first_job_ledger_facts'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fact(
              const Key('first_job_salary_fact'),
              s.firstJobSalaryTitle,
              facts.salary == null
                  ? s.dataBlockStatusMissing
                  : formatChfWithPrefix(facts.salary!)),
          _fact(
              const Key('first_job_age_fact'),
              s.unemploymentAgeSliderTitle,
              facts.age == null
                  ? s.dataBlockStatusMissing
                  : s.unemploymentAgeValue(facts.age!)),
          _fact(const Key('first_job_canton_fact'), s.firstJobCantonLabel,
              facts.canton ?? s.dataBlockStatusMissing),
        ],
      ),
    );
  }

  Widget _enrichmentCta(BuildContext context, S s) => Semantics(
        key: const Key('first_job_enrich_profile_cta'),
        identifier: 'first_job_enrich_profile_cta',
        button: true,
        child: Container(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              _hasUserInteracted = true;
              context.push(_revenueRoute());
            },
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(s.firstJobEvidenceHint),
          ),
        ),
      );

  Widget _salaryAuthority(S s, FirstJobResult result, _FirstJobFacts facts) {
    return _card(
      key: const Key('first_job_salary_authority'),
      child: Semantics(
        identifier: 'first_job_salary_authority',
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.firstJobGrossKnown,
                style: MintTextStyles.labelMedium(
                    color: MintColors.textSecondary)),
            const SizedBox(height: MintSpacing.xs),
            Text(
              formatChfWithPrefix(result.brut),
              key: const Key('first_job_salary_fact'),
              style:
                  MintTextStyles.headlineMedium(color: MintColors.textPrimary),
            ),
            Text('${s.unemploymentAgeValue(facts.age!)} · ${facts.canton}',
                style: MintTextStyles.bodySmall(color: MintColors.textMuted)),
            const Divider(height: MintSpacing.xl),
            Text(s.firstJobKnownDeductionsIllustrative,
                style:
                    MintTextStyles.titleMedium(color: MintColors.textPrimary)),
            const SizedBox(height: MintSpacing.sm),
            ...result.deductionItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.xs),
                child: Row(
                  children: [
                    Expanded(child: Text(_deductionLabel(s, item.kind))),
                    Text('≈ ${formatChfWithPrefix(item.montant)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(s.firstJobLppExactUnknown,
                style: MintTextStyles.bodyMedium(color: MintColors.warning)),
            const SizedBox(height: MintSpacing.xs),
            Text(s.firstJobNetExactUnknown,
                style: MintTextStyles.bodyMedium(color: MintColors.warning)),
            if (result.lppAgeCreditIllustration != null) ...[
              const SizedBox(height: MintSpacing.sm),
              Text(
                s.firstJobLppIllustration(
                  formatChfWithPrefix(result.lppAgeCreditIllustration!),
                ),
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                    .copyWith(height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _neutral3a(S s) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.firstJobPillar3aNeutralTitle,
                style:
                    MintTextStyles.titleMedium(color: MintColors.textPrimary)),
            const SizedBox(height: MintSpacing.sm),
            Text(s.firstJobPillar3aNeutralBody,
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                    .copyWith(height: 1.45)),
          ],
        ),
      );

  String _deductionLabel(S s, SalaryDeductionKind kind) => switch (kind) {
        SalaryDeductionKind.avsAiApg => s.firstJobPayslipAvsLabel,
        SalaryDeductionKind.unemploymentInsurance => s.firstJobPayslipAcLabel,
      };

  Widget _lamalHandoff(BuildContext context, S s) => _card(
        key: const Key('first_job_lamal_handoff'),
        child: Semantics(
          identifier: 'first_job_lamal_handoff',
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.firstJobLamalNeutralTitle,
                  style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary)),
              const SizedBox(height: MintSpacing.sm),
              Text(s.firstJobLamalNeutralBody,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary)
                          .copyWith(height: 1.45)),
              const SizedBox(height: MintSpacing.md),
              OutlinedButton(
                onPressed: () {
                  _hasUserInteracted = true;
                  context.push('/assurances/lamal');
                },
                child: Text(s.firstJobLamalNeutralButton),
              ),
            ],
          ),
        ),
      );

  Widget _checklist(S s) {
    final items = [
      s.firstJobCoherentChecklist1,
      s.firstJobCoherentChecklist2,
      s.firstJobCoherentChecklist3,
      s.firstJobCoherentChecklist4,
      s.firstJobCoherentChecklist5,
    ];
    return Semantics(
      identifier: 'first_job_checklist',
      container: true,
      child: _card(
        key: const Key('first_job_checklist'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.firstJobChecklistCoherentTitle,
                style:
                    MintTextStyles.titleMedium(color: MintColors.textPrimary)),
            const SizedBox(height: MintSpacing.sm),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. '),
                    Expanded(child: Text(items[i])),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fact(Key key, String label, String value) => Padding(
        key: key,
        padding: const EdgeInsets.only(bottom: MintSpacing.sm),
        child: Row(children: [Expanded(child: Text(label)), Text(value)]),
      );

  Widget _card({Key? key, required Widget child}) => Container(
        key: key,
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.surface,
          border: Border.all(color: MintColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );
}
