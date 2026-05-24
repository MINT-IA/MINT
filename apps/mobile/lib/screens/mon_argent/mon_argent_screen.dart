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
      await context.read<BudgetProvider>().loadFromStorage();
    } catch (_) {
      if (mounted) setState(() => _budgetError = true);
    } finally {
      if (mounted) setState(() => _budgetLoading = false);
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
    final coachProfile = context.watch<CoachProfileProvider>().profile;
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

    return Scaffold(
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
                    if (dataSpine != null && budgetSnapshot != null) ...[
                      MintEntrance(
                        child: _MonArgentDataSpineSummary(
                          snapshot: budgetSnapshot,
                          patrimoineNet: patrimoine.net,
                          l10n: l10n,
                        ),
                      ),
                      const SizedBox(height: MintSpacing.lg),
                      MintEntrance(
                        delay: const Duration(milliseconds: 80),
                        child: _MonArgentSituationMap(
                          spine: dataSpine,
                          l10n: l10n,
                        ),
                      ),
                      const SizedBox(height: MintSpacing.lg),
                    ],

                    // Card 1: Budget
                    MintEntrance(
                      child: BudgetSummaryCard(
                        snapshot: budgetSnapshot,
                        inputs: budgetProvider.inputs,
                        plan: budgetProvider.plan,
                        isLoading: budgetSnapshot == null && _budgetLoading,
                        hasError: _budgetError,
                        onTap: () => context.push('/budget'),
                        onRetry: _loadBudget,
                        // Route the empty-state "Commencer" directly to the
                        // structured setup form rather than /budget (which
                        // loops back to the coach chat topic=budget path).
                        // See MVP-PLAN-2026-04-21 § P0-MVP-3.
                        onSetup: () => context.push('/budget/setup'),
                      ),
                    ),
                    const SizedBox(height: MintSpacing.lg),

                    // Card 2: Patrimoine
                    MintEntrance(
                      delay: const Duration(milliseconds: 100),
                      child: PatrimoineSummaryCard(
                        summary: patrimoine,
                        onTap: () => context.push('/profile/bilan'),
                        onScan: () => context.push('/scan'),
                        onTapAmount: (topic) =>
                            context.go('/coach/chat?topic=$topic'),
                      ),
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
            ),
            const SizedBox(height: MintSpacing.sm),
            _SituationValueRow(
              label: l10n.dataBlockSituationCashLabel,
              value: _valueOrMissing(situation.liquidSavings),
            ),
            const SizedBox(height: MintSpacing.sm),
            _SituationValueRow(
              label: l10n.patrimoineDettes,
              value: _valueOrMissing(situation.totalDebt),
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
              l10n: l10n,
            ),
            const SizedBox(height: MintSpacing.sm),
            _PillarValueRow(
              label: l10n.dataBlockLppTitle,
              value: _pillarMoneyOrMissing(pillars.lpp.totalBalance),
              state: pillars.lpp.totalBalance.state,
              color: MintColors.pillarLpp,
              l10n: l10n,
            ),
            const SizedBox(height: MintSpacing.sm),
            _PillarValueRow(
              label: l10n.dataBlock3aTitle,
              value: _pillarMoneyOrMissing(pillars.pillar3a.totalBalance),
              state: pillars.pillar3a.totalBalance.state,
              color: MintColors.success,
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

  String _pillarMoneyOrMissing(PillarFact<double> fact) {
    final amount = fact.value;
    return amount == null ? l10n.dataBlockStatusMissing : _formatChf(amount);
  }
}

class _SituationValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _SituationValueRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PillarValueRow extends StatelessWidget {
  final String label;
  final String value;
  final PillarFactState state;
  final Color color;
  final S l10n;

  const _PillarValueRow({
    required this.label,
    required this.value,
    required this.state,
    required this.color,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
              Text(
                _stateLabel(state),
                style: MintTextStyles.micro(color: MintColors.textMuted),
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
    );
  }

  String _stateLabel(PillarFactState state) {
    return switch (state) {
      PillarFactState.known => l10n.dataBlockStatusComplete,
      PillarFactState.estimated => l10n.dataBlockStatusPartial,
      PillarFactState.missing => l10n.dataBlockStatusMissing,
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
