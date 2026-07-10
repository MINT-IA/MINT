// Cantonal Benchmark Screen — S60
//
// Displays anonymized cantonal financial benchmarks (OFS data).
// Opt-in only. ZERO ranked comparisons, ZERO social comparison.

import 'package:flutter/material.dart';
import 'package:mint_mobile/widgets/premium/mint_loading_skeleton.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/cantonal_benchmark_service.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

class CantonalBenchmarkScreen extends StatefulWidget {
  const CantonalBenchmarkScreen({super.key});

  @override
  State<CantonalBenchmarkScreen> createState() =>
      _CantonalBenchmarkScreenState();
}

class _CantonalBenchmarkScreenState extends State<CantonalBenchmarkScreen> {
  bool _optedIn = false;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadOptIn();
  }

  Future<void> _loadOptIn() async {
    try {
      final value = await CantonalBenchmarkService.getOptedIn();
      if (mounted) {
        setState(() {
          _optedIn = value;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _retryLoadOptIn() async {
    setState(() {
      _hasError = false;
      _loading = true;
    });
    await _loadOptIn();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<CoachProfileProvider>();
    final profile = profileProvider.profile;
    final ledgerFacts = _ledgerFacts(profile);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: MintColors.textPrimary,
                  ),
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/coach/chat'),
                ),
                title: Text(
                  S.of(context)!.benchmarkAppBarTitle,
                  style: MintTextStyles.headlineMedium(),
                ),
                backgroundColor: MintColors.white,
                surfaceTintColor: MintColors.white,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: MintLoadingSkeleton(),
                        )
                      : _hasError
                          ? _buildErrorCard()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Opt-in toggle ──────────────────────────────
                                MintEntrance(child: _buildOptInCard()),
                                const SizedBox(height: 20),
                                if (!_optedIn) ...[
                                  _buildExplanationCard(),
                                ] else if (!ledgerFacts.isComplete) ...[
                                  _buildLedgerFactsCard(context, ledgerFacts),
                                ] else ...[
                                  _buildBenchmarkContent(profile!, ledgerFacts),
                                ],
                              ],
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _BenchmarkLedgerFacts _ledgerFacts(CoachProfile? profile) {
    if (profile == null) return const _BenchmarkLedgerFacts();

    final provided = profile.userProvidedFields;
    final annualIncome =
        provided.contains('salary') && profile.revenuBrutAnnuel > 0
            ? profile.revenuBrutAnnuel
            : null;
    final canton =
        provided.contains('canton') && profile.canton.trim().isNotEmpty
            ? profile.canton.trim().toUpperCase()
            : null;
    final age = provided.contains('age') ? profile.ageOrNull : null;

    return _BenchmarkLedgerFacts(
      annualIncome: annualIncome,
      canton: canton,
      age: age,
    );
  }

  Widget _buildErrorCard() {
    final s = S.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline,
                  color: MintColors.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.errorGenericBody,
                  style: MintTextStyles.bodySmall(color: MintColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Wrap(
            spacing: MintSpacing.sm,
            runSpacing: MintSpacing.xs,
            children: [
              TextButton.icon(
                key: const Key('recoveryCta'),
                onPressed: _retryLoadOptIn,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(s.commonRetry),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/coach/chat'),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text(s.tabCoach),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerFactsCard(
    BuildContext context,
    _BenchmarkLedgerFacts facts,
  ) {
    final s = S.of(context)!;
    final editRoute = facts.missingDataRoute;

    return Semantics(
      key: const Key('cantonal_benchmark_ledger_facts'),
      identifier: 'cantonal_benchmark_ledger_facts',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        padding: const EdgeInsets.all(20),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.manage_search_outlined,
                  color: MintColors.warning,
                  size: 20,
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    s.dataQualityMissingSection,
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Semantics(
                  key: const Key('cantonal_benchmark_enrich_profile_cta'),
                  identifier: 'cantonal_benchmark_enrich_profile_cta',
                  button: true,
                  child: TextButton.icon(
                    onPressed: () => context.push(editRoute),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: Text(s.dataQualityEnrich),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            _buildFactRow(
              identifier: 'cantonal_benchmark_income_fact',
              label: s.fiscalGrossAnnualIncome,
              value: facts.annualIncome == null
                  ? s.dataBlockStatusMissing
                  : 'CHF ${_fmt(facts.annualIncome!)}',
              isMissing: facts.annualIncome == null,
            ),
            const SizedBox(height: MintSpacing.xs),
            _buildFactRow(
              identifier: 'cantonal_benchmark_age_fact',
              label: s.ijmTonAge,
              value: facts.age == null
                  ? s.dataBlockStatusMissing
                  : s.unemploymentAgeValue(facts.age!),
              isMissing: facts.age == null,
            ),
            const SizedBox(height: MintSpacing.xs),
            _buildFactRow(
              identifier: 'cantonal_benchmark_canton_fact',
              label: s.fiscalCanton,
              value: facts.canton ?? s.dataBlockStatusMissing,
              isMissing: facts.canton == null,
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
      child: Row(
        children: [
          Icon(
            isMissing ? Icons.radio_button_unchecked : Icons.check_circle,
            color: isMissing ? MintColors.textMuted : MintColors.success,
            size: 16,
          ),
          const SizedBox(width: MintSpacing.xs),
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
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildOptInCard() {
    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.benchmarkOptInTitle,
                  style: MintTextStyles.titleMedium(),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  S.of(context)!.benchmarkOptInSubtitle,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            toggled: _optedIn,
            label: S.of(context)!.semanticsBenchmarkToggle,
            child: Switch.adaptive(
              value: _optedIn,
              activeTrackColor: MintColors.primary,
              onChanged: (value) async {
                await CantonalBenchmarkService.setOptedIn(value);
                if (!mounted) return;
                setState(() {
                  _optedIn = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.bar_chart_rounded,
              size: 48, color: MintColors.textMuted),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.benchmarkExplanationTitle,
            style: MintTextStyles.headlineMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            S.of(context)!.benchmarkExplanationBody,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBenchmarkContent(
    CoachProfile profile,
    _BenchmarkLedgerFacts facts,
  ) {
    final benchmark = CantonalBenchmarkService.getBenchmark(
      canton: facts.canton!,
      age: facts.age!,
    );

    if (benchmark == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: MintColors.appleSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          S.of(context)!.benchmarkNoData(
                facts.canton!,
                CantonalBenchmarkService.ageGroupForAge(facts.age!),
              ),
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    final comparison = CantonalBenchmarkService.compareToProfile(
      profile: profile,
      benchmark: benchmark,
    );

    if (comparison == null) return const SizedBox.shrink();
    final visibleMetrics =
        comparison.metrics.where(_isLedgerBackedBenchmarkMetric).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S
              .of(context)!
              .benchmarkSimilarProfiles(benchmark.canton, benchmark.ageGroup),
          style: MintTextStyles.titleMedium(),
        ),
        const SizedBox(height: 16),
        ...visibleMetrics.map(_buildMetricCard),
        const SizedBox(height: 20),
        // Source
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context)!.benchmarkSourceLabel(benchmark.source),
                style: MintTextStyles.bodySmall(color: MintColors.textMuted),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                benchmark.disclaimer,
                style: MintTextStyles.bodySmall(color: MintColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isLedgerBackedBenchmarkMetric(MetricComparison metric) {
    return metric.isLedgerBacked;
  }

  Widget _buildMetricCard(MetricComparison metric) {
    final (icon, color, text) = switch (metric.position) {
      BenchmarkPosition.withinRange => (
          Icons.check_circle_outline,
          MintColors.success,
          S.of(context)!.benchmarkWithinRange,
        ),
      BenchmarkPosition.aboveRange => (
          Icons.arrow_upward_rounded,
          MintColors.info,
          S.of(context)!.benchmarkAboveRange,
        ),
      BenchmarkPosition.belowRange => (
          Icons.arrow_downward_rounded,
          MintColors.warning,
          S.of(context)!.benchmarkBelowRange,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        label: S.of(context)!.semanticsBenchmarkMetric(metric.label, text,
            _fmt(metric.range.low), _fmt(metric.range.high)),
        child: MintSurface(
          padding: const EdgeInsets.all(16),
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(child: Icon(icon, size: 20, color: color)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      metric.label,
                      style: MintTextStyles.bodyLarge(
                              color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                text,
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                S.of(context)!.benchmarkTypicalRange(
                    _fmt(metric.range.low), _fmt(metric.range.high)),
                style: MintTextStyles.bodySmall(color: MintColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) {
      final s = v.toStringAsFixed(0);
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write("'");
        buf.write(s[i]);
      }
      return buf.toString();
    }
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

class _BenchmarkLedgerFacts {
  final double? annualIncome;
  final String? canton;
  final int? age;

  const _BenchmarkLedgerFacts({
    this.annualIncome,
    this.canton,
    this.age,
  });

  bool get isComplete => annualIncome != null && canton != null && age != null;

  String get missingDataRoute {
    if (annualIncome == null) {
      return '/data-block/revenu?inputKey=q_gross_salary_annual';
    }
    if (canton == null) {
      return '/data-block/revenu?inputKey=q_canton';
    }
    if (age == null) {
      return '/data-block/revenu?inputKey=q_birth_year';
    }
    return '/data-block/revenu';
  }
}
