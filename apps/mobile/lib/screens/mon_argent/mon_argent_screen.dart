import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/data_spine_snapshot.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/mon_argent/patrimoine_aggregator.dart';
import 'package:mint_mobile/services/mon_argent/coach_whisper_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/mint_shell.dart';
import 'package:mint_mobile/widgets/mon_argent/budget_summary_card.dart';
import 'package:mint_mobile/widgets/mon_argent/patrimoine_summary_card.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Mon argent tab — financial state at a glance.
///
/// Navigation V11, Category G: Dashboard Screen.
/// Two calm numbers: budget remaining + patrimoine net.
/// Architecture A→B: ready for spending synthesis card (Phase B).
class MonArgentScreen extends StatefulWidget {
  const MonArgentScreen({super.key});

  @override
  State<MonArgentScreen> createState() => _MonArgentScreenState();
}

class _MonArgentScreenState extends State<MonArgentScreen> {
  bool _budgetLoading = true;
  bool _budgetError = false;
  _MonArgentSection _section = _MonArgentSection.today;

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    setState(() {
      _budgetLoading = true;
      _budgetError = false;
    });
    try {
      final budgetProvider = context.read<BudgetProvider>();
      final profileProvider = _readCoachProfileProviderIfAvailable();
      final profile = profileProvider?.profile;
      if (profile == null) {
        await budgetProvider.loadFromStorage();
      } else if (profileProvider!.isPartialProfile) {
        final restored = await budgetProvider.loadFromStorage();
        if (!restored) await budgetProvider.refreshFromProfile(profile);
      } else {
        await budgetProvider.refreshFromProfile(profile);
      }
    } catch (_) {
      if (mounted) setState(() => _budgetError = true);
    } finally {
      if (mounted) setState(() => _budgetLoading = false);
    }
  }

  CoachProfileProvider? _readCoachProfileProviderIfAvailable() {
    try {
      return context.read<CoachProfileProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  CoachProfileProvider? _watchCoachProfileProviderIfAvailable() {
    try {
      return context.watch<CoachProfileProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await _loadBudget();
    // CoachProfileProvider refreshes reactively via watch
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final budgetProvider = context.watch<BudgetProvider>();
    final coachProfile = _watchCoachProfileProviderIfAvailable()?.profile;
    final mintState = context.watch<MintStateProvider>().state;
    final dataSpine = mintState?.dataSpineSnapshot;
    final budgetSnapshot = dataSpine?.budget ?? mintState?.budgetSnapshot;
    final patrimoine = dataSpine != null
        ? PatrimoineAggregator.computeFromDataSpine(dataSpine)
        : PatrimoineAggregator.compute(coachProfile);
    final whisper = CoachWhisperService.evaluate(
      budgetInputs: budgetProvider.inputs,
      budgetPlan: budgetProvider.plan,
      patrimoine: patrimoine,
      profile: coachProfile,
    );

    return Semantics(
      key: const Key('mon_argent_screen'),
      identifier: 'mon_argent_screen',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: MintColors.craie,
        appBar: AppBar(
          backgroundColor: MintColors.white,
          title: Text(
            l10n.monArgentTabTitle,
            style: MintTextStyles.headlineMedium(color: MintColors.textPrimary),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => MintShell.openDrawer(context),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: MintColors.success,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(MintSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MonArgentSectionSelector(
                        selected: _section,
                        l10n: l10n,
                        onChanged: (next) => setState(() => _section = next),
                      ),
                      const SizedBox(height: MintSpacing.lg),
                      _MonArgentSectionBody(
                        section: _section,
                        dataSpine: dataSpine,
                        budgetSnapshot: budgetSnapshot,
                        patrimoine: patrimoine,
                        budgetProvider: budgetProvider,
                        budgetLoading: _budgetLoading,
                        budgetError: _budgetError,
                        l10n: l10n,
                        onBudgetTap: () => context.push('/budget'),
                        onBudgetRetry: _loadBudget,
                        onBudgetSetup: () => context.push('/budget/setup'),
                        onPatrimoineTap: () => context.push('/profile/bilan'),
                        onPatrimoineScan: () => context.push('/scan'),
                        onPatrimoineAmountTap: (topic) =>
                            context.go('/coach/chat?topic=$topic'),
                      ),

                      // Coach whisper (deterministic, may be null = silence)
                      if (whisper != null) ...[
                        const SizedBox(height: MintSpacing.lg),
                        MintEntrance(
                          delay: const Duration(milliseconds: 200),
                          child: GestureDetector(
                            onTap: () => context.go('/coach/chat?topic=budget'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: MintSpacing.sm,
                              ),
                              child: Text(
                                '\u{1F4A1} $whisper',
                                style: MintTextStyles.bodyMedium(
                                  color: MintColors.textSecondary,
                                ).copyWith(fontStyle: FontStyle.italic),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // CTA: Enrich your dossier
                      const SizedBox(height: MintSpacing.xl),
                      MintEntrance(
                        delay: const Duration(milliseconds: 300),
                        child: GestureDetector(
                          onTap: () => context.push('/scan'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.monArgentEnrichCta,
                                  style: MintTextStyles.bodyMedium(
                                    color: MintColors.ardoise,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.add_circle_outline,
                                color: MintColors.ardoise,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Phase B slot (commented, not rendered)
                      // TODO(nav-v11-phase-b): SpendingSynthesisCard goes here
                      // when Open Banking data is available.
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _MonArgentSection { today, month, wealth, pension, future }

class _MonArgentSectionSelector extends StatelessWidget {
  final _MonArgentSection selected;
  final S l10n;
  final ValueChanged<_MonArgentSection> onChanged;

  const _MonArgentSectionSelector({
    required this.selected,
    required this.l10n,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('mon_argent_section_selector'),
      identifier: 'mon_argent_section_selector',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return _CompactSectionSelector(
              selected: selected,
              labelFor: _label,
              onChanged: onChanged,
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_MonArgentSection>(
              showSelectedIcon: false,
              selected: {selected},
              onSelectionChanged: (selection) => onChanged(selection.single),
              style: SegmentedButton.styleFrom(
                backgroundColor: MintColors.white,
                selectedBackgroundColor: MintColors.saugeClaire,
                foregroundColor: MintColors.textSecondary,
                selectedForegroundColor: MintColors.textPrimary,
                side: const BorderSide(color: MintColors.borderSubtle),
                textStyle: MintTextStyles.labelMedium(),
              ),
              segments: _MonArgentSection.values
                  .map(
                    (section) => ButtonSegment(
                      value: section,
                      label: Text(_label(section)),
                    ),
                  )
                  .toList(growable: false),
            ),
          );
        },
      ),
    );
  }

  String _label(_MonArgentSection section) {
    return switch (section) {
      _MonArgentSection.today => l10n.monArgentSectionToday,
      _MonArgentSection.month => l10n.monArgentSectionMonth,
      _MonArgentSection.wealth => l10n.monArgentSectionWealth,
      _MonArgentSection.pension => l10n.monArgentSectionPension,
      _MonArgentSection.future => l10n.monArgentSectionFuture,
    };
  }
}

class _CompactSectionSelector extends StatelessWidget {
  final _MonArgentSection selected;
  final String Function(_MonArgentSection section) labelFor;
  final ValueChanged<_MonArgentSection> onChanged;

  const _CompactSectionSelector({
    required this.selected,
    required this.labelFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MintSpacing.xs,
      runSpacing: MintSpacing.xs,
      children: _MonArgentSection.values.map((section) {
        final isSelected = selected == section;
        return ChoiceChip(
          key: Key('mon_argent_section_chip_${section.name}'),
          selected: isSelected,
          showCheckmark: false,
          label: Text(labelFor(section)),
          labelStyle: MintTextStyles.labelMedium(
            color:
                isSelected ? MintColors.textPrimary : MintColors.textSecondary,
          ),
          backgroundColor: MintColors.white,
          selectedColor: MintColors.saugeClaire,
          side: const BorderSide(color: MintColors.borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          onSelected: (_) => onChanged(section),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(growable: false),
    );
  }
}

class _MonArgentSectionBody extends StatelessWidget {
  final _MonArgentSection section;
  final DataSpineSnapshot? dataSpine;
  final BudgetSnapshot? budgetSnapshot;
  final PatrimoineSummary patrimoine;
  final BudgetProvider budgetProvider;
  final bool budgetLoading;
  final bool budgetError;
  final S l10n;
  final VoidCallback onBudgetTap;
  final VoidCallback onBudgetRetry;
  final VoidCallback onBudgetSetup;
  final VoidCallback onPatrimoineTap;
  final VoidCallback onPatrimoineScan;
  final ValueChanged<String> onPatrimoineAmountTap;

  const _MonArgentSectionBody({
    required this.section,
    required this.dataSpine,
    required this.budgetSnapshot,
    required this.patrimoine,
    required this.budgetProvider,
    required this.budgetLoading,
    required this.budgetError,
    required this.l10n,
    required this.onBudgetTap,
    required this.onBudgetRetry,
    required this.onBudgetSetup,
    required this.onPatrimoineTap,
    required this.onPatrimoineScan,
    required this.onPatrimoineAmountTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: Key('mon_argent_section_${section.name}'),
      identifier: 'mon_argent_section_${section.name}',
      container: true,
      explicitChildNodes: true,
      child: switch (section) {
        _MonArgentSection.today => _TodaySection(
            dataSpine: dataSpine,
            budgetSnapshot: budgetSnapshot,
            patrimoine: patrimoine,
            l10n: l10n,
          ),
        _MonArgentSection.month => BudgetSummaryCard(
            snapshot: budgetSnapshot,
            inputs: budgetProvider.inputs,
            plan: budgetProvider.plan,
            isLoading: budgetSnapshot == null && budgetLoading,
            hasError: budgetError,
            onTap: onBudgetTap,
            onRetry: onBudgetRetry,
            onSetup: onBudgetSetup,
          ),
        _MonArgentSection.wealth => PatrimoineSummaryCard(
            summary: patrimoine,
            onTap: onPatrimoineTap,
            onScan: onPatrimoineScan,
            onTapAmount: onPatrimoineAmountTap,
          ),
        _MonArgentSection.pension => dataSpine == null
            ? _MissingDataSurface(l10n: l10n)
            : _MonArgentPensionMap(pillars: dataSpine!.pillars, l10n: l10n),
        _MonArgentSection.future => dataSpine == null
            ? _MissingDataSurface(l10n: l10n)
            : _MonArgentTrajectoryMap(
                trajectory: dataSpine!.trajectory,
                l10n: l10n,
              ),
      },
    );
  }
}

class _TodaySection extends StatelessWidget {
  final DataSpineSnapshot? dataSpine;
  final BudgetSnapshot? budgetSnapshot;
  final PatrimoineSummary patrimoine;
  final S l10n;

  const _TodaySection({
    required this.dataSpine,
    required this.budgetSnapshot,
    required this.patrimoine,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    if (dataSpine == null || budgetSnapshot == null) {
      return _MissingDataSurface(l10n: l10n);
    }
    return Column(
      children: [
        _MonArgentDataSpineSummary(
          snapshot: budgetSnapshot!,
          patrimoineNet: patrimoine.net,
          l10n: l10n,
        ),
        const SizedBox(height: MintSpacing.lg),
        _MonArgentSituationMap(
          spine: dataSpine!,
          l10n: l10n,
        ),
      ],
    );
  }
}

class _MissingDataSurface extends StatelessWidget {
  final S l10n;

  const _MissingDataSurface({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      child: Text(
        l10n.dataBlockIncomplete,
        style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
      ),
    );
  }
}

class _MonArgentDataSpineSummary extends StatelessWidget {
  final BudgetSnapshot snapshot;
  final double patrimoineNet;
  final S l10n;

  const _MonArgentDataSpineSummary({
    required this.snapshot,
    required this.patrimoineNet,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final confidence = snapshot.confidenceScore.round().clamp(0, 100);
    final confidenceDetail = confidence >= 60
        ? l10n.budgetSnapshotConfidenceOk
        : l10n.budgetSnapshotConfidenceLow;

    return Semantics(
      key: const Key('mon_argent_data_spine_summary'),
      identifier: 'mon_argent_data_spine_summary',
      label: '${l10n.budgetSnapshotFreeLabel}. '
          '${_formatChf(snapshot.present.monthlyFree)}. '
          '${l10n.budgetSnapshotConfidenceLabel} $confidence%.',
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.budgetSnapshotFreeLabel,
              style: MintTextStyles.labelLarge(color: MintColors.ardoise),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              _formatChf(snapshot.present.monthlyFree),
              style: MintTextStyles.displayMedium(
                color: snapshot.present.isDeficit
                    ? MintColors.error
                    : MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: MintSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: l10n.budgetSnapshotConfidenceLabel,
                    value: '$confidence%',
                    detail: confidenceDetail,
                  ),
                ),
                const SizedBox(width: MintSpacing.md),
                Expanded(
                  child: _SummaryMetric(
                    label: l10n.monArgentPatrimoineNet,
                    value: _formatChf(patrimoineNet),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonArgentTrajectoryMap extends StatelessWidget {
  final TrajectorySummary trajectory;
  final S l10n;

  const _MonArgentTrajectoryMap({
    required this.trajectory,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final monthlyRequired = trajectory.monthlyRequired;
    final targetAmount = trajectory.targetAmount;
    final monthlyGap = trajectory.monthlyGap;
    final progress = monthlyRequired == null || monthlyRequired <= 0
        ? 0.0
        : (trajectory.currentMonthlyCapacity / monthlyRequired).clamp(0.0, 1.0);

    return Semantics(
      key: const Key('mon_argent_trajectory_map'),
      identifier: 'mon_argent_trajectory_map',
      label: l10n.trajectoryTitle,
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.trajectoryTitle,
              style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: _trajectoryColor(trajectory.status),
                backgroundColor: MintColors.borderSubtle,
              ),
            ),
            const SizedBox(height: MintSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: l10n.trajectoryGoalLabel,
                    value: targetAmount == null
                        ? l10n.dataBlockStatusMissing
                        : _formatChf(targetAmount),
                    detail: monthlyRequired == null
                        ? null
                        : _formatChf(monthlyRequired),
                  ),
                ),
                const SizedBox(width: MintSpacing.md),
                Expanded(
                  child: _SummaryMetric(
                    label: l10n.budgetSnapshotPresentLabel,
                    value: _formatChf(trajectory.currentMonthlyFree),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.lg),
            _SituationValueRow(
              label: l10n.pulseLabelMonthlyGap,
              value: monthlyGap == null
                  ? l10n.dataBlockStatusMissing
                  : _formatChf(monthlyGap > 0 ? monthlyGap : 0),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: MintSpacing.md),
              child: Divider(color: MintColors.border),
            ),
            Text(
              l10n.trajectoryNextStepSectionTitle,
              style: MintTextStyles.labelMedium(color: MintColors.textMuted),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              l10n.trajectoryNextStepBody,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Color _trajectoryColor(TrajectoryStatus status) {
    return switch (status) {
      TrajectoryStatus.onTrack => MintColors.success,
      TrajectoryStatus.drifting => MintColors.warning,
      TrajectoryStatus.blocked => MintColors.error,
      TrajectoryStatus.insufficientData => MintColors.info,
    };
  }
}

class _MonArgentSituationMap extends StatelessWidget {
  final DataSpineSnapshot spine;
  final S l10n;

  const _MonArgentSituationMap({
    required this.spine,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final situation = spine.situation;
    final pillars = spine.pillars;

    return Semantics(
      key: const Key('mon_argent_situation_map'),
      identifier: 'mon_argent_situation_map',
      label: l10n.dataBlockSituationTitle,
      child: MintSurface(
        tone: MintSurfaceTone.craie,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.dataBlockSituationTitle,
              style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.md),
            _SituationValueRow(
              label: l10n.affordabilityGrossIncome,
              value: _valueOrMissing(situation.grossAnnualIncome),
              statusLabel: _fieldStatusLabel(situation.grossAnnualIncome),
              statusColor: _fieldStatusColor(situation.grossAnnualIncome),
              trustId: 'gross_income',
            ),
            const SizedBox(height: MintSpacing.sm),
            _SituationValueRow(
              label: l10n.budgetHousing,
              value: _valueOrMissing(situation.monthlyHousingCost),
              statusLabel: _fieldStatusLabel(situation.monthlyHousingCost),
              statusColor: _fieldStatusColor(situation.monthlyHousingCost),
              trustId: 'housing_cost',
            ),
            const SizedBox(height: MintSpacing.sm),
            _SituationValueRow(
              label: l10n.budgetHealthInsurance,
              value: _valueOrMissing(situation.lamalPremiumMonthly),
              statusLabel: _fieldStatusLabel(situation.lamalPremiumMonthly),
              statusColor: _fieldStatusColor(situation.lamalPremiumMonthly),
              trustId: 'lamal_premium',
            ),
            const SizedBox(height: MintSpacing.sm),
            _SituationValueRow(
              label: l10n.dataBlockSituationCashLabel,
              value: _valueOrMissing(situation.liquidSavings),
              statusLabel: _fieldStatusLabel(situation.liquidSavings),
              statusColor: _fieldStatusColor(situation.liquidSavings),
              trustId: 'liquid_savings',
            ),
            const SizedBox(height: MintSpacing.sm),
            _SituationValueRow(
              label: l10n.financialSummaryInvestissements,
              value: _valueOrMissing(situation.investments),
              statusLabel: _fieldStatusLabel(situation.investments),
              statusColor: _fieldStatusColor(situation.investments),
              trustId: 'investments',
            ),
            const SizedBox(height: MintSpacing.sm),
            _SituationValueRow(
              label: l10n.patrimoineDettes,
              value: _valueOrMissing(situation.totalDebt),
              statusLabel: _fieldStatusLabel(situation.totalDebt),
              statusColor: _fieldStatusColor(situation.totalDebt),
              trustId: 'total_debt',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: MintSpacing.md),
              child: Divider(color: MintColors.border),
            ),
            _PillarValueRow(
              label: l10n.dataBlockAvsTitle,
              value: _pillarMoneyOrMissing(
                pillars.avs.estimatedMonthlyPension,
              ),
              state: pillars.avs.estimatedMonthlyPension.state,
              color: MintColors.info,
              trustId: 'avs_estimated_pension',
              l10n: l10n,
            ),
            const SizedBox(height: MintSpacing.sm),
            _PillarValueRow(
              label: l10n.dataBlockLppTitle,
              value: _pillarMoneyOrMissing(pillars.lpp.totalBalance),
              state: pillars.lpp.totalBalance.state,
              color: MintColors.pillarLpp,
              trustId: 'lpp_total_balance',
              l10n: l10n,
            ),
            const SizedBox(height: MintSpacing.sm),
            _PillarValueRow(
              label: l10n.dataBlock3aTitle,
              value: _pillarMoneyOrMissing(pillars.pillar3a.totalBalance),
              state: pillars.pillar3a.totalBalance.state,
              color: MintColors.success,
              trustId: 'pillar3a_total_balance',
              l10n: l10n,
            ),
          ],
        ),
      ),
    );
  }

  String _valueOrMissing(SpineValue<double> value) {
    final amount = value.value;
    return amount == null ? l10n.dataBlockStatusMissing : _formatChf(amount);
  }

  String _fieldStatusLabel(SpineValue<double> value) {
    if (!value.hasValue) {
      return l10n.budgetQualityMissing;
    }
    return switch (value.meta.confidence) {
      FieldConfidence.known => l10n.budgetQualityProvided,
      FieldConfidence.inferred => l10n.budgetQualityEstimated,
      FieldConfidence.estimated => l10n.budgetQualityEstimated,
      FieldConfidence.stale => l10n.budgetQualityEstimated,
      FieldConfidence.missing => l10n.budgetQualityMissing,
    };
  }

  Color _fieldStatusColor(SpineValue<double> value) {
    if (!value.hasValue) {
      return MintColors.textMuted;
    }
    return switch (value.meta.confidence) {
      FieldConfidence.known => MintColors.success,
      FieldConfidence.inferred => MintColors.warning,
      FieldConfidence.estimated => MintColors.warning,
      FieldConfidence.stale => MintColors.warning,
      FieldConfidence.missing => MintColors.textMuted,
    };
  }

  String _pillarMoneyOrMissing(PillarFact<double> fact) {
    final amount = fact.value;
    return amount == null ? l10n.dataBlockStatusMissing : _formatChf(amount);
  }
}

class _MonArgentPensionMap extends StatelessWidget {
  final PillarPosition pillars;
  final S l10n;

  const _MonArgentPensionMap({
    required this.pillars,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('mon_argent_pension_map'),
      identifier: 'mon_argent_pension_map',
      label: l10n.monArgentSectionPension,
      child: MintSurface(
        tone: MintSurfaceTone.craie,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.monArgentSectionPension,
              style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.md),
            _PillarValueRow(
              label: l10n.dataBlockAvsTitle,
              value: _pillarMoneyOrMissing(
                pillars.avs.estimatedMonthlyPension,
              ),
              state: pillars.avs.estimatedMonthlyPension.state,
              color: MintColors.info,
              trustId: 'avs_estimated_pension_pension',
              l10n: l10n,
            ),
            const SizedBox(height: MintSpacing.sm),
            _PillarValueRow(
              label: l10n.dataBlockLppTitle,
              value: _pillarMoneyOrMissing(pillars.lpp.totalBalance),
              state: pillars.lpp.totalBalance.state,
              color: MintColors.pillarLpp,
              trustId: 'lpp_total_balance_pension',
              l10n: l10n,
            ),
            const SizedBox(height: MintSpacing.sm),
            _PillarValueRow(
              label: l10n.dataBlock3aTitle,
              value: _pillarMoneyOrMissing(pillars.pillar3a.totalBalance),
              state: pillars.pillar3a.totalBalance.state,
              color: MintColors.success,
              trustId: 'pillar3a_total_balance_pension',
              l10n: l10n,
            ),
          ],
        ),
      ),
    );
  }

  String _pillarMoneyOrMissing(PillarFact<double> fact) {
    final amount = fact.value;
    return amount == null ? l10n.dataBlockStatusMissing : _formatChf(amount);
  }
}

class _SituationValueRow extends StatelessWidget {
  final String label;
  final String value;
  final String? statusLabel;
  final Color? statusColor;
  final String? trustId;

  const _SituationValueRow({
    required this.label,
    required this.value,
    this.statusLabel,
    this.statusColor,
    this.trustId,
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel =
        statusLabel == null ? '$label, $value' : '$label, $value, $statusLabel';
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  label,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textSecondary,
                  ),
                ),
                if (statusLabel != null)
                  _FigureTrustChip(
                    label: statusLabel!,
                    color: statusColor ?? MintColors.textMuted,
                    trustId: trustId,
                  ),
              ],
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Text(
            value,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FigureTrustChip extends StatelessWidget {
  final String label;
  final Color color;
  final String? trustId;

  const _FigureTrustChip({
    required this.label,
    required this.color,
    this.trustId,
  });

  @override
  Widget build(BuildContext context) {
    final identifier = trustId == null ? null : 'figure_trust_chip_$trustId';
    return Semantics(
      key: identifier == null ? null : Key(identifier),
      container: true,
      identifier: identifier,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ExcludeSemantics(
          child: Text(
            label,
            style: MintTextStyles.labelSmall(color: color)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _PillarValueRow extends StatelessWidget {
  final String label;
  final String value;
  final PillarFactState state;
  final Color color;
  final String trustId;
  final S l10n;

  const _PillarValueRow({
    required this.label,
    required this.value,
    required this.state,
    required this.color,
    required this.trustId,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabel(state);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '$label, $value, $stateLabel',
      child: Row(
        children: [
          Container(
            width: 8,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.xs),
                _FigureTrustChip(
                  label: stateLabel,
                  color: _stateColor(state),
                  trustId: trustId,
                ),
              ],
            ),
          ),
          Text(
            value,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _stateLabel(PillarFactState state) {
    return switch (state) {
      PillarFactState.known => l10n.budgetQualityProvided,
      PillarFactState.estimated => l10n.budgetQualityEstimated,
      PillarFactState.missing => l10n.budgetQualityMissing,
    };
  }

  Color _stateColor(PillarFactState state) {
    return switch (state) {
      PillarFactState.known => MintColors.success,
      PillarFactState.estimated => MintColors.warning,
      PillarFactState.missing => MintColors.textMuted,
    };
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;

  const _SummaryMetric({
    required this.label,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MintTextStyles.labelMedium(color: MintColors.textMuted),
        ),
        const SizedBox(height: MintSpacing.xs),
        Text(
          value,
          style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
        ),
        if (detail != null) ...[
          const SizedBox(height: MintSpacing.xs),
          Text(
            detail!,
            style: MintTextStyles.bodySmall(color: MintColors.ardoise),
          ),
        ],
      ],
    );
  }
}

String _formatChf(double amount) {
  final formatted = amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => "${match[1]}'",
      );
  return "$formatted\u00a0CHF";
}
