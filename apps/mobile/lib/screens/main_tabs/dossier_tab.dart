import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/benchmark/benchmark_comparison_service.dart';
import 'package:mint_mobile/services/benchmark/benchmark_opt_in_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Tab 3 — Dossier
///
/// "Mes données, mes documents, mes réglages."
/// Regroupe : Profil, Documents, Couple, Consentements, BYOK/SLM, Paramètres.
/// Inclut la section "Profils similaires" (benchmarks cantonaux S60).
///
/// Design: fond porcelaine, sections MintSurface(blanc), espacement xl.
/// Espace personnel calme — pas de couleurs vives, icônes textSecondary.
class DossierTab extends StatefulWidget {
  const DossierTab({super.key});

  @override
  State<DossierTab> createState() => _DossierTabState();
}

class _DossierTabState extends State<DossierTab> {
  bool _benchmarkOptedIn = false;
  bool _benchmarkLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBenchmarkOptIn();
  }

  Future<void> _loadBenchmarkOptIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final optedIn = await BenchmarkOptInService.isOptedIn(prefs);
      if (mounted) {
        setState(() {
          _benchmarkOptedIn = optedIn;
          _benchmarkLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _benchmarkLoaded = true);
    }
  }

  Future<void> _enableBenchmark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await BenchmarkOptInService.setOptIn(true, prefs);
      if (mounted) setState(() => _benchmarkOptedIn = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final provider = context.watch<CoachProfileProvider>();
    final firstName = provider.hasProfile
        ? (provider.profile!.firstName ?? '')
        : '';
    final canton = provider.hasProfile
        ? provider.profile!.canton
        : '';

    return ColoredBox(
      color: MintColors.porcelaine,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.porcelaine,
            surfaceTintColor: MintColors.porcelaine,
            elevation: 0,
            title: Text(
              l.tabDossier,
              style: MintTextStyles.headlineMedium(
                color: MintColors.textPrimary,
              ),
            ),
            centerTitle: false,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.lg,
              vertical: MintSpacing.md,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ═══════════════════════════════════════
                //  Mon dossier
                // ═══════════════════════════════════════
                MintSurface(
                  tone: MintSurfaceTone.blanc,
                  padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
                  child: Column(
                    children: [
                      // ── Profile ──
                      _DossierRow(
                        icon: Icons.person_outline,
                        title: firstName.isNotEmpty
                            ? firstName
                            : l.tabMoi,
                        subtitle: provider.hasProfile
                            ? l.dossierProfileCompleted((provider.profileCompleteness * 100).round())
                            : l.dossierStartProfile,
                        onTap: () => context.push('/profile'),
                      ),

                      // ── Documents ──
                      _DossierRow(
                        icon: Icons.folder_outlined,
                        title: l.dossierDocumentsTitle,
                        subtitle: l.dossierDocumentsSubtitle,
                        onTap: () => context.push('/documents'),
                      ),

                      // ── Couple ──
                      _DossierRow(
                        icon: Icons.people_outline,
                        title: l.dossierCoupleTitle,
                        subtitle: l.dossierCoupleSubtitle,
                        onTap: () => context.push('/couple'),
                      ),

                      // ── Bilan financier ──
                      _DossierRow(
                        icon: Icons.pie_chart_outline,
                        title: l.dossierBilanTitle,
                        subtitle: l.dossierBilanSubtitle,
                        onTap: () => context.push('/profile/bilan'),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: MintSpacing.xl),

                // ═══════════════════════════════════════
                //  Profils similaires (S60 Benchmarks)
                // ═══════════════════════════════════════
                if (_benchmarkLoaded) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: MintSpacing.xs,
                      bottom: MintSpacing.sm,
                    ),
                    child: Text(
                      l.benchmarkTitle,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textMuted,
                      ),
                    ),
                  ),
                  _benchmarkOptedIn && canton.isNotEmpty
                      ? _BenchmarkInsightsCard(canton: canton)
                      : _BenchmarkOptInCard(onOptIn: _enableBenchmark),
                  const SizedBox(height: MintSpacing.xl),
                ],

                // ═══════════════════════════════════════
                //  Réglages
                // ═══════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.only(
                    left: MintSpacing.xs,
                    bottom: MintSpacing.sm,
                  ),
                  child: Text(
                    l.dossierReglages,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textMuted,
                    ),
                  ),
                ),

                MintSurface(
                  tone: MintSurfaceTone.blanc,
                  padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
                  child: Column(
                    children: [
                      // ── Consentements ──
                      _DossierRow(
                        icon: Icons.verified_user_outlined,
                        title: l.dossierConsentsTitle,
                        subtitle: l.dossierConsentsSubtitle,
                        onTap: () => context.push('/profile/consent'),
                      ),

                      // ── Modèle local (SLM) ──
                      _DossierRow(
                        icon: Icons.smart_toy_outlined,
                        title: l.dossierSlmTitle,
                        subtitle: l.dossierSlmSubtitle,
                        onTap: () => context.push('/profile/slm'),
                      ),

                      // ── Clé API (BYOK) ──
                      _DossierRow(
                        icon: Icons.vpn_key_outlined,
                        title: l.dossierByokTitle,
                        subtitle: l.dossierByokSubtitle,
                        onTap: () => context.push('/profile/byok'),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: MintSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Benchmark Opt-In CTA card ──────────────────────────────────────────────

/// Shown when user has not yet opted into cantonal benchmarks.
class _BenchmarkOptInCard extends StatelessWidget {
  final VoidCallback onOptIn;

  const _BenchmarkOptInCard({required this.onOptIn});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_outlined,
                  size: 18, color: MintColors.textSecondary),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  l.benchmarkOptInTitle,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ).copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            l.benchmarkOptInBody,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: onOptIn,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.lg,
                  vertical: MintSpacing.sm,
                ),
              ),
              child: Text(
                l.benchmarkOptInButton,
                style: MintTextStyles.labelSmall(color: MintColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Benchmark Insights card ────────────────────────────────────────────────

/// Shows 2–3 key benchmark insights when user has opted in.
/// Uses [BenchmarkComparisonService] with the user's canton.
class _BenchmarkInsightsCard extends StatelessWidget {
  final String canton;

  const _BenchmarkInsightsCard({required this.canton});

  /// Resolve an observation ARB key to its localised string.
  String _resolveObservation(String key, Map<String, String>? params, S l) {
    final p = params ?? {};
    switch (key) {
      case 'benchmarkInsightIncome':
        return l.benchmarkInsightIncome(p['canton'] ?? '', p['amount'] ?? '');
      case 'benchmarkInsightSavings':
        return l.benchmarkInsightSavings(p['rate'] ?? '');
      case 'benchmarkInsightTax':
        final levelKey = p['level'] ?? 'benchmarkTaxLevelAverage';
        final String level;
        switch (levelKey) {
          case 'benchmarkTaxLevelBelow':
            level = l.benchmarkTaxLevelBelow;
            break;
          case 'benchmarkTaxLevelAbove':
            level = l.benchmarkTaxLevelAbove;
            break;
          default:
            level = l.benchmarkTaxLevelAverage;
        }
        return l.benchmarkInsightTax(p['canton'] ?? '', level);
      case 'benchmarkInsightHousing':
        return l.benchmarkInsightHousing(p['amount'] ?? '');
      case 'benchmarkInsight3a':
        return l.benchmarkInsight3a(p['rate'] ?? '');
      case 'benchmarkInsightLpp':
        return l.benchmarkInsightLpp(p['rate'] ?? '');
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    // Build comparison using a dummy profile approach — canton-level data only.
    // We pass an empty profile; the service uses it for user-side values only.
    // For display we show the canton-level factual observations (income, tax, housing).
    final provider = context.watch<CoachProfileProvider>();
    if (!provider.hasProfile) return const SizedBox.shrink();

    final comparison = BenchmarkComparisonService.compare(
      profile: provider.profile!,
      cantonCode: canton,
    );

    if (comparison == null) return const SizedBox.shrink();

    // Show first 3 insights.
    final displayed = comparison.insights.take(3).toList();

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < displayed.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: MintColors.textSecondary),
                const SizedBox(width: MintSpacing.xs),
                Expanded(
                  child: Text(
                    _resolveObservation(
                      displayed[i].observationKey,
                      displayed[i].params,
                      l,
                    ),
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (i < displayed.length - 1) ...[
              const SizedBox(height: MintSpacing.xs),
              Divider(
                height: 1,
                color: MintColors.textPrimary.withValues(alpha: 0.05),
              ),
              const SizedBox(height: MintSpacing.xs),
            ],
          ],
          const SizedBox(height: MintSpacing.sm),
          Text(
            comparison.disclaimer,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontStyle: FontStyle.italic, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// Single row inside a dossier section surface.
/// Uses spacing instead of borders between items.
class _DossierRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  const _DossierRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: MintSpacing.md,
                horizontal: MintSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(icon, color: MintColors.textSecondary, size: 20),
                  const SizedBox(width: MintSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: MintTextStyles.titleMedium(
                            color: MintColors.textPrimary,
                          ).copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: MintTextStyles.labelSmall(
                            color: MintColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: MintColors.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
              child: Divider(
                height: 1,
                color: MintColors.textPrimary.withValues(alpha: 0.05),
              ),
            ),
        ],
      ),
    );
  }
}
