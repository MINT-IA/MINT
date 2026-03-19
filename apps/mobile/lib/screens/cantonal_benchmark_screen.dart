// Cantonal Benchmark Screen — S60
//
// Displays anonymized cantonal financial benchmarks (OFS data).
// Opt-in only. ZERO ranked comparisons, ZERO social comparison.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/cantonal_benchmark_service.dart';

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

  /// M8: Extracted for testability. In production, uses DateTime.now().
  /// For widget tests, this could be overridden via a clock dependency.
  static int _computeAge(int birthYear) => DateTime.now().year - birthYear;

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<CoachProfileProvider>();
    final profile = profileProvider.profile;
    // M8: Age calculation uses DateTime.now() — not testable in widget tests.
    // Extracting to a method for future injection. Known limitation.
    final age = profile != null
        ? _computeAge(profile.birthYear)
        : null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
              onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
            ),
            title: Text(
              S.of(context)!.benchmarkAppBarTitle,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: MintColors.textPrimary,
              ),
            ),
            backgroundColor: MintColors.white,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _hasError
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: MintColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: MintColors.error, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text(
                                'Une erreur est survenue. Réessaie plus tard.',
                                style: GoogleFonts.inter(fontSize: 13, color: MintColors.error),
                              )),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Opt-in toggle ──────────────────────────────
                            _buildOptInCard(),
                            const SizedBox(height: 20),

                            if (!_optedIn) ...[
                              _buildExplanationCard(),
                            ] else if (profile == null || age == null) ...[
                              _buildNoProfileCard(),
                            ] else ...[
                              _buildBenchmarkContent(profile, age),
                            ],
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptInCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.benchmarkOptInTitle,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  S.of(context)!.benchmarkOptInSubtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: _optedIn,
            activeTrackColor: MintColors.primary,
            onChanged: (value) async {
              await CantonalBenchmarkService.setOptedIn(value);
              setState(() {
                _optedIn = value;
              });
            },
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
          const Icon(Icons.bar_chart_rounded, size: 48, color: MintColors.textMuted),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.benchmarkExplanationTitle,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: MintColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.benchmarkExplanationBody,
            style: const TextStyle(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoProfileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        S.of(context)!.benchmarkNoProfile,
        style: const TextStyle(
          fontSize: 14,
          color: MintColors.textSecondary,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBenchmarkContent(CoachProfile profile, int age) {
    final benchmark = CantonalBenchmarkService.getBenchmark(
      canton: profile.canton,
      age: age,
    );

    if (benchmark == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: MintColors.appleSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          S.of(context)!.benchmarkNoData(profile.canton, CantonalBenchmarkService.ageGroupForAge(age)),
          style: const TextStyle(
            fontSize: 14,
            color: MintColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final comparison = CantonalBenchmarkService.compareToProfile(
      profile: profile,
      benchmark: benchmark,
    );

    if (comparison == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.benchmarkSimilarProfiles(benchmark.canton, benchmark.ageGroup),
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        ...comparison.metrics.map(_buildMetricCard),
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
                style: const TextStyle(
                  fontSize: 12,
                  color: MintColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                benchmark.disclaimer,
                style: const TextStyle(
                  fontSize: 12,
                  color: MintColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    metric.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              S.of(context)!.benchmarkTypicalRange(_fmt(metric.range.low), _fmt(metric.range.high)),
              style: const TextStyle(
                fontSize: 12,
                color: MintColors.textMuted,
              ),
            ),
          ],
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
