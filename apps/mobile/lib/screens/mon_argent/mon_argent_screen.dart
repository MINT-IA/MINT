import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/domain/budget/present_budget_builder.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/data_spine_snapshot.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/mon_argent/patrimoine_aggregator.dart';
import 'package:mint_mobile/services/mon_argent/coach_whisper_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
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
  const MonArgentScreen({
    super.key,
    this.initialSection,
  });

  final String? initialSection;

  @override
  State<MonArgentScreen> createState() => _MonArgentScreenState();
}

class _MonArgentScreenState extends State<MonArgentScreen> {
  bool _budgetLoading = true;
  bool _budgetError = false;
  late _MonArgentSection _section;

  @override
  void initState() {
    super.initState();
    _section = _sectionFromName(widget.initialSection);
    _loadBudget();
  }

  @override
  void didUpdateWidget(covariant MonArgentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSection != oldWidget.initialSection) {
      _section = _sectionFromName(widget.initialSection);
    }
  }

  _MonArgentSection _sectionFromName(String? name) {
    return switch (name) {
      'month' || 'mois' => _MonArgentSection.month,
      'wealth' || 'patrimoine' => _MonArgentSection.wealth,
      'pension' || 'prevoyance' || 'prévoyance' => _MonArgentSection.pension,
      'future' || 'futur' => _MonArgentSection.future,
      _ => _MonArgentSection.today,
    };
  }

  Future<void> _loadBudget() async {
    setState(() {
      _budgetLoading = true;
      _budgetError = false;
    });
    try {
      final budgetProvider = context.read<BudgetProvider>();
      final profileProvider = _readCoachProfileProviderIfAvailable();
      await budgetProvider.hydrateFromProfileState(
        profile: profileProvider?.profile,
        isPartialProfile: profileProvider?.isPartialProfile ?? false,
      );
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
    final housingFact = _watchCoachProfileProviderIfAvailable()?.housingFact;
    final domicileFact =
        _watchCoachProfileProviderIfAvailable()?.domicileFact;
    final mintState = context.watch<MintStateProvider>().state;
    final dataSpine = mintState?.dataSpineSnapshot;
    final budgetSnapshot = dataSpine?.budget ?? mintState?.budgetSnapshot;
    final providerPresentBudget =
        budgetProvider.hasFreshInputs && budgetProvider.inputs != null
            ? PresentBudgetBuilder.fromInputs(
                inputs: budgetProvider.inputs!,
                plan: budgetProvider.plan ??
                    const BudgetPlan(
                      available: 0,
                      variables: 0,
                      future: 0,
                      stopRuleTriggered: false,
                      emergencyFundMonths: 0,
                    ),
              )
            : null;
    final preferProfileBudgetProvider =
        budgetProvider.source == BudgetDataSource.profile &&
            providerPresentBudget != null &&
            (budgetSnapshot == null ||
                !_hasSameMonthlyBudgetBase(
                  budgetSnapshot.present,
                  providerPresentBudget,
                ) ||
                _providerCarriesFutureOverride(
                  budgetSnapshot.present,
                  providerPresentBudget,
                ));
    final budgetSnapshotForBudgetCard =
        preferProfileBudgetProvider ? null : budgetSnapshot;
    final budgetConfidenceScore = preferProfileBudgetProvider
        ? 80.0
        : budgetSnapshot?.confidenceScore ?? 0.0;
    final patrimoine = dataSpine != null
        ? PatrimoineAggregator.computeFromDataSpine(dataSpine)
        : PatrimoineAggregator.compute(coachProfile);
    final whisper = CoachWhisperService.evaluate(
      budgetSnapshot: budgetSnapshotForBudgetCard,
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
                        budgetSnapshot: budgetSnapshotForBudgetCard,
                        budgetConfidenceScore: budgetConfidenceScore,
                        patrimoine: patrimoine,
                        housingFact: housingFact,
                        domicileFact: domicileFact,
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
                        onHousingEdit: () {
                          if (FeatureFlags.enableMintNextHousing) {
                            context.push('/mint-next/housing');
                          }
                        },
                        onHousingDelete: _deleteHousingFact,
                        onDomicileEdit: () {
                          if (FeatureFlags.enableMintNextDomicile) {
                            context.push('/mint-next/domicile');
                          }
                        },
                        onDomicileDelete: _deleteDomicileFact,
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

  Future<void> _deleteDomicileFact() async {
    final l10n = S.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mintNextDomicileDeleteTitle),
        content: Text(l10n.mintNextDomicileDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.mintNextDomicileDeleteCancel),
          ),
          Semantics(
            identifier: 'action:mon_argent.domicile.delete_confirm',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.mintNextDomicileDeleteConfirm),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<CoachProfileProvider>().deleteDomicileFact();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mintNextDomicileSaveFailed)),
      );
    }
  }

  Future<void> _deleteHousingFact() async {
    final l10n = S.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.housingSavedDeleteTitle),
        content: Text(l10n.housingSavedDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.housingSavedDeleteCancel),
          ),
          Semantics(
            identifier: 'action:mon_argent.housing.delete_confirm',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.housingSavedDeleteConfirm),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<CoachProfileProvider>().deleteHousingFact();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.housingSaveError)),
      );
    }
  }

  bool _hasSameMonthlyBudgetBase(PresentBudget a, PresentBudget b) {
    return _sameChf(a.monthlyNet, b.monthlyNet) &&
        _sameChf(a.monthlyCharges, b.monthlyCharges);
  }

  bool _providerCarriesFutureOverride(
    PresentBudget snapshot,
    PresentBudget provider,
  ) {
    return provider.monthlySavings > 0 &&
        !_sameChf(snapshot.monthlySavings, provider.monthlySavings);
  }

  bool _sameChf(double a, double b) =>
      PresentBudgetBuilder.displayChf(a) == PresentBudgetBuilder.displayChf(b);
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
        final identifier = 'mon_argent_section_chip_${section.name}';
        return Semantics(
          key: Key(identifier),
          identifier: identifier,
          selected: isSelected,
          button: true,
          child: ChoiceChip(
            selected: isSelected,
            showCheckmark: false,
            label: Text(labelFor(section)),
            labelStyle: MintTextStyles.labelMedium(
              color: isSelected
                  ? MintColors.textPrimary
                  : MintColors.textSecondary,
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
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _MonArgentSectionBody extends StatelessWidget {
  final _MonArgentSection section;
  final DataSpineSnapshot? dataSpine;
  final BudgetSnapshot? budgetSnapshot;
  final double budgetConfidenceScore;
  final PatrimoineSummary patrimoine;
  final MintNextHousingFact? housingFact;
  final MintNextDomicileFact? domicileFact;
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
  final VoidCallback onHousingEdit;
  final Future<void> Function() onHousingDelete;
  final VoidCallback onDomicileEdit;
  final Future<void> Function() onDomicileDelete;

  const _MonArgentSectionBody({
    required this.section,
    required this.dataSpine,
    required this.budgetSnapshot,
    required this.budgetConfidenceScore,
    required this.patrimoine,
    required this.housingFact,
    required this.domicileFact,
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
    required this.onHousingEdit,
    required this.onHousingDelete,
    required this.onDomicileEdit,
    required this.onDomicileDelete,
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
            budgetConfidenceScore: budgetConfidenceScore,
            budgetInputs: budgetProvider.inputs,
            budgetPlan: budgetProvider.plan,
            patrimoine: patrimoine,
            housingFact: housingFact,
            domicileFact: domicileFact,
            l10n: l10n,
            onHousingEdit: onHousingEdit,
            onHousingDelete: onHousingDelete,
            onDomicileEdit: onDomicileEdit,
            onDomicileDelete: onDomicileDelete,
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
  final double budgetConfidenceScore;
  final BudgetInputs? budgetInputs;
  final BudgetPlan? budgetPlan;
  final PatrimoineSummary patrimoine;
  final MintNextHousingFact? housingFact;
  final MintNextDomicileFact? domicileFact;
  final S l10n;
  final VoidCallback onHousingEdit;
  final Future<void> Function() onHousingDelete;
  final VoidCallback onDomicileEdit;
  final Future<void> Function() onDomicileDelete;

  const _TodaySection({
    required this.dataSpine,
    required this.budgetSnapshot,
    required this.budgetConfidenceScore,
    required this.budgetInputs,
    required this.budgetPlan,
    required this.patrimoine,
    required this.housingFact,
    required this.domicileFact,
    required this.l10n,
    required this.onHousingEdit,
    required this.onHousingDelete,
    required this.onDomicileEdit,
    required this.onDomicileDelete,
  });

  @override
  Widget build(BuildContext context) {
    final presentBudget = _presentBudget();
    if (presentBudget == null &&
        housingFact == null &&
        domicileFact == null) {
      return _MissingDataSurface(l10n: l10n);
    }
    return Column(
      children: [
        if (presentBudget != null)
          _MonArgentDataSpineSummary(
            present: presentBudget,
            confidenceScore: budgetConfidenceScore,
            patrimoineNet: patrimoine.net,
            l10n: l10n,
          ),
        if (housingFact != null) ...[
          if (presentBudget != null) const SizedBox(height: MintSpacing.md),
          _HousingFactSurface(
            fact: housingFact!,
            l10n: l10n,
            onEdit: onHousingEdit,
            onDelete: onHousingDelete,
          ),
        ],
        if (domicileFact != null) ...[
          const SizedBox(height: MintSpacing.md),
          _DomicileFactSurface(
            fact: domicileFact!,
            l10n: l10n,
            onEdit: onDomicileEdit,
            onDelete: onDomicileDelete,
          ),
        ],
        if (dataSpine != null) ...[
          const SizedBox(height: MintSpacing.md),
          _MonArgentDetailsExpansion(
            title: l10n.dataBlockSituationTitle,
            child: _MonArgentSituationMap(
              spine: dataSpine!,
              budgetInputsOverride:
                  budgetSnapshot == null ? budgetInputs : null,
              l10n: l10n,
              includeSurface: false,
              includeTitle: false,
            ),
          ),
        ],
      ],
    );
  }

  PresentBudget? _presentBudget() {
    final snapshotPresent = budgetSnapshot?.present;
    if (snapshotPresent != null) return snapshotPresent;
    final inputs = budgetInputs;
    if (inputs == null) return null;
    return PresentBudgetBuilder.fromInputs(
      inputs: inputs,
      plan: budgetPlan ??
          const BudgetPlan(
            available: 0,
            variables: 0,
            future: 0,
            stopRuleTriggered: false,
            emergencyFundMonths: 0,
          ),
    );
  }
}

class _DomicileFactSurface extends StatelessWidget {
  const _DomicileFactSurface({
    required this.fact,
    required this.l10n,
    required this.onEdit,
    required this.onDelete,
  });

  final MintNextDomicileFact fact;
  final S l10n;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final assertedDate = MaterialLocalizations.of(context)
        .formatShortDate(fact.assertedAt.toLocal());
    return Semantics(
      key: const Key('mon_argent_domicile_fact'),
      identifier: 'mon_argent_domicile_fact',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.mintNextDomicileSavedTitle,
                style:
                    MintTextStyles.titleLarge(color: MintColors.textPrimary)),
            const SizedBox(height: MintSpacing.sm),
            Text('${fact.communeName} (${fact.canton})',
                style: MintTextStyles.bodyLarge(color: MintColors.textPrimary)),
            const SizedBox(height: MintSpacing.xs),
            Text(
              l10n.mintNextDomicileReviewSource(assertedDate),
              key: const Key('mon_argent_domicile_fact_provenance'),
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: MintSpacing.md),
            ValueListenableBuilder<bool>(
              valueListenable: FeatureFlags.mintNextDomicileListenable,
              builder: (context, enabled, _) => enabled
                  ? Semantics(
                      identifier: 'action:mon_argent.domicile.edit',
                      button: true,
                      child: TextButton(
                        onPressed: onEdit,
                        child: Text(l10n.mintNextDomicileEdit),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Semantics(
              identifier: 'action:mon_argent.domicile.delete',
              button: true,
              child: TextButton(
                onPressed: onDelete,
                child: Text(l10n.mintNextDomicileDelete),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HousingFactSurface extends StatelessWidget {
  const _HousingFactSurface({
    required this.fact,
    required this.l10n,
    required this.onEdit,
    required this.onDelete,
  });

  final MintNextHousingFact fact;
  final S l10n;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final assertedDate = MaterialLocalizations.of(context)
        .formatShortDate(fact.assertedAt.toLocal());
    final source = switch (fact.source) {
      MintNextHousingFact.userDeclarationSource =>
        l10n.housingSavedSourceHousingFlow,
      _ => l10n.housingSavedSourceUnknown,
    };
    final tenure = switch (fact.tenure) {
      PrimaryHomeTenure.tenant => l10n.housingTenant,
      PrimaryHomeTenure.ownerOccupier => l10n.housingOwnerOccupier,
      PrimaryHomeTenure.other => l10n.housingOther,
      PrimaryHomeTenure.unknown => l10n.housingUnknown,
    };
    final mortgage = switch (fact.mortgageStatus) {
      HousingMortgageStatus.yes => l10n.housingMortgageYes,
      HousingMortgageStatus.no => l10n.housingMortgageNo,
      HousingMortgageStatus.unknown => l10n.housingMortgageUnknown,
      null => null,
    };
    return Semantics(
      key: const Key('mon_argent_housing_fact'),
      identifier: 'mon_argent_housing_fact',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.housingSavedTitle,
                style:
                    MintTextStyles.titleLarge(color: MintColors.textPrimary)),
            const SizedBox(height: MintSpacing.sm),
            Text(tenure,
                style: MintTextStyles.bodyLarge(color: MintColors.textPrimary)),
            const SizedBox(height: MintSpacing.xs),
            Text(
              l10n.housingSavedProvenance(source, assertedDate),
              key: const Key('mon_argent_housing_fact_provenance'),
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            if (mortgage != null) ...[
              const SizedBox(height: MintSpacing.xs),
              Text('${l10n.housingMortgageQuestion} $mortgage',
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondary)),
            ],
            if (fact.statementYear != null) ...[
              const SizedBox(height: MintSpacing.xs),
              Text(l10n.housingSavedPeriod(fact.statementYear!),
                  key: const Key('mon_argent_housing_fact_period'),
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondary)),
            ],
            const SizedBox(height: MintSpacing.sm),
            Text(l10n.housingSavedBody,
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary)),
            const SizedBox(height: MintSpacing.md),
            ValueListenableBuilder<bool>(
              valueListenable: FeatureFlags.mintNextHousingListenable,
              builder: (context, enabled, _) => enabled
                  ? Semantics(
                      identifier: 'action:mon_argent.housing.edit',
                      button: true,
                      child: TextButton(
                        onPressed: onEdit,
                        child: Text(l10n.housingSavedEdit),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Semantics(
              identifier: 'action:mon_argent.housing.delete',
              button: true,
              child: TextButton(
                onPressed: onDelete,
                child: Text(l10n.housingSavedDelete),
              ),
            ),
          ],
        ),
      ),
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

class _MonArgentDetailsExpansion extends StatelessWidget {
  final String title;
  final Widget child;

  const _MonArgentDetailsExpansion({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('mon_argent_situation_expand'),
      identifier: 'mon_argent_situation_expand',
      button: true,
      label: title,
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        tone: MintSurfaceTone.craie,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: MintColors.transparent,
            splashColor: MintColors.transparent,
            highlightColor: MintColors.transparent,
          ),
          child: Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: MintSpacing.sm),
                iconColor: MintColors.ardoise,
                collapsedIconColor: MintColors.textMuted,
                title: Text(
                  title,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                children: [child],
              )),
        ),
      ),
    );
  }
}

class _MonArgentDataSpineSummary extends StatelessWidget {
  final PresentBudget present;
  final double confidenceScore;
  final double patrimoineNet;
  final S l10n;

  const _MonArgentDataSpineSummary({
    required this.present,
    required this.confidenceScore,
    required this.patrimoineNet,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final confidence = confidenceScore.round().clamp(0, 100);
    final confidenceDetail = confidence >= 60
        ? l10n.budgetSnapshotConfidenceOk
        : l10n.budgetSnapshotConfidenceLow;

    return Semantics(
      key: const Key('mon_argent_data_spine_summary'),
      identifier: 'mon_argent_data_spine_summary',
      label: '${l10n.budgetSnapshotFreeLabel}. '
          '${_formatChf(present.monthlyFree)}. '
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
              _formatChf(present.monthlyFree),
              style: MintTextStyles.displayMedium(
                color: present.isDeficit
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
  final BudgetInputs? budgetInputsOverride;
  final S l10n;
  final bool includeSurface;
  final bool includeTitle;

  const _MonArgentSituationMap({
    required this.spine,
    this.budgetInputsOverride,
    required this.l10n,
    this.includeSurface = true,
    this.includeTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final situation = spine.situation;
    final pillars = spine.pillars;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (includeTitle) ...[
          Text(
            l10n.dataBlockSituationTitle,
            style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.md),
        ],
        _SituationGroup(
          identifier: 'mon_argent_situation_group_month',
          title: l10n.monArgentBudgetTitle,
          children: [
            _SituationValueRow(
              label: l10n.affordabilityGrossIncome,
              value: _valueOrMissing(situation.grossAnnualIncome),
              statusLabel: _fieldStatusLabel(situation.grossAnnualIncome),
              statusColor: _fieldStatusColor(situation.grossAnnualIncome),
              trustId: 'gross_income',
            ),
            _SituationValueRow(
              label: l10n.budgetHousing,
              value: _budgetInputValueOrSpine(
                budgetInputsOverride?.housingCost,
                situation.monthlyHousingCost,
              ),
              statusLabel: _budgetInputStatusOrSpine(
                budgetInputsOverride?.housingCost,
                situation.monthlyHousingCost,
              ),
              statusColor: _budgetInputStatusColorOrSpine(
                budgetInputsOverride?.housingCost,
                situation.monthlyHousingCost,
              ),
              trustId: 'housing_cost',
            ),
            _SituationValueRow(
              label: l10n.budgetHealthInsurance,
              value: _budgetInputValueOrSpine(
                budgetInputsOverride?.healthInsurance,
                situation.lamalPremiumMonthly,
              ),
              statusLabel: _budgetInputStatusOrSpine(
                budgetInputsOverride?.healthInsurance,
                situation.lamalPremiumMonthly,
              ),
              statusColor: _budgetInputStatusColorOrSpine(
                budgetInputsOverride?.healthInsurance,
                situation.lamalPremiumMonthly,
              ),
              trustId: 'lamal_premium',
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.lg),
        _SituationGroup(
          identifier: 'mon_argent_situation_group_wealth',
          title: l10n.monArgentPatrimoineTitle,
          children: [
            _SituationValueRow(
              label: l10n.dataBlockSituationCashLabel,
              value: _valueOrMissing(situation.liquidSavings),
              statusLabel: _fieldStatusLabel(situation.liquidSavings),
              statusColor: _fieldStatusColor(situation.liquidSavings),
              trustId: 'liquid_savings',
            ),
            _SituationValueRow(
              label: l10n.financialSummaryInvestissements,
              value: _valueOrMissing(situation.investments),
              statusLabel: _fieldStatusLabel(situation.investments),
              statusColor: _fieldStatusColor(situation.investments),
              trustId: 'investments',
            ),
            _SituationValueRow(
              label: l10n.patrimoineDettes,
              value: _valueOrMissing(situation.totalDebt),
              statusLabel: _fieldStatusLabel(situation.totalDebt),
              statusColor: _fieldStatusColor(situation.totalDebt),
              trustId: 'total_debt',
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.lg),
        _SituationGroup(
          identifier: 'mon_argent_situation_group_pension',
          title: l10n.dashboardGoalRetirement,
          children: [
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
            _PillarValueRow(
              label: l10n.dataBlockLppTitle,
              value: _pillarMoneyOrMissing(pillars.lpp.totalBalance),
              state: pillars.lpp.totalBalance.state,
              color: MintColors.pillarLpp,
              trustId: 'lpp_total_balance',
              l10n: l10n,
            ),
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
      ],
    );

    return Semantics(
      key: const Key('mon_argent_situation_map'),
      identifier: 'mon_argent_situation_map',
      label: l10n.dataBlockSituationTitle,
      child: includeSurface
          ? MintSurface(tone: MintSurfaceTone.craie, child: content)
          : content,
    );
  }

  String _valueOrMissing(SpineValue<double> value) {
    final amount = value.value;
    return amount == null ? l10n.dataBlockStatusMissing : _formatChf(amount);
  }

  String _budgetInputValueOrSpine(
    double? inputValue,
    SpineValue<double> spineValue,
  ) {
    if (inputValue != null && inputValue > 0) return _formatChf(inputValue);
    return _valueOrMissing(spineValue);
  }

  String _budgetInputStatusOrSpine(
    double? inputValue,
    SpineValue<double> spineValue,
  ) {
    if (inputValue != null && inputValue > 0) return l10n.budgetQualityProvided;
    return _fieldStatusLabel(spineValue);
  }

  Color _budgetInputStatusColorOrSpine(
    double? inputValue,
    SpineValue<double> spineValue,
  ) {
    if (inputValue != null && inputValue > 0) return MintColors.success;
    return _fieldStatusColor(spineValue);
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

class _SituationGroup extends StatelessWidget {
  final String identifier;
  final String title;
  final List<Widget> children;

  const _SituationGroup({
    required this.identifier,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: Key(identifier),
      identifier: identifier,
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MintTextStyles.labelMedium(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.sm),
          for (final child in children) ...[
            child,
            if (child != children.last) const SizedBox(height: MintSpacing.sm),
          ],
        ],
      ),
    );
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
