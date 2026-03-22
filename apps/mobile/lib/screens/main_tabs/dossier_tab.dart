import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/benchmark/benchmark_comparison_service.dart';
import 'package:mint_mobile/services/benchmark/benchmark_opt_in_service.dart';
import 'package:mint_mobile/services/expert/advisor_specialization.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Tab 3 — Dossier
///
/// "Mes données, mes documents, mes réglages."
/// Mirror unifié de l'état utilisateur via [MintUserState].
/// Six sections : Mon profil, Mon plan, Mes données, Comparaison cantonale,
/// Spécialiste + Documents préparés, Réglages.
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
    final mintState = context.watch<MintStateProvider>().state;
    final provider = context.watch<CoachProfileProvider>();

    // Derived from MintUserState when available; fall back to CoachProfileProvider.
    final firstName = mintState?.profile.firstName
        ?? (provider.hasProfile ? (provider.profile!.firstName ?? '') : '');
    final canton = mintState?.profile.canton
        ?? (provider.hasProfile ? provider.profile!.canton : '');
    final confidenceScore = mintState?.confidenceScore ?? 0.0;
    final confidencePct = (confidenceScore * 100).round().clamp(0, 100);

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
                //  Section 1 — Mon profil
                // ═══════════════════════════════════════
                _SectionLabel(l.dossierProfileSection),
                _ProfileSection(
                  mintState: mintState,
                  provider: provider,
                  firstName: firstName,
                  confidencePct: confidencePct,
                  l: l,
                ),

                const SizedBox(height: MintSpacing.xl),

                // ═══════════════════════════════════════
                //  Section 2 — Mon plan (CapSequence)
                // ═══════════════════════════════════════
                _SectionLabel(l.dossierPlanSection),
                _PlanSection(mintState: mintState, l: l),

                const SizedBox(height: MintSpacing.xl),

                // ═══════════════════════════════════════
                //  Section 3 — Mes données
                // ═══════════════════════════════════════
                _SectionLabel(l.dossierDataSection),
                _DataSection(mintState: mintState, provider: provider, l: l),

                const SizedBox(height: MintSpacing.xl),

                // ═══════════════════════════════════════
                //  Section 4 — Comparaison cantonale (S60 Benchmarks)
                // ═══════════════════════════════════════
                if (_benchmarkLoaded) ...[
                  _SectionLabel(l.benchmarkTitle),
                  _benchmarkOptedIn && canton.isNotEmpty
                      ? _BenchmarkInsightsCard(canton: canton)
                      : _BenchmarkOptInCard(onOptIn: _enableBenchmark),
                  const SizedBox(height: MintSpacing.xl),
                ],

                // ═══════════════════════════════════════
                //  Section 5 — Spécialiste + Documents préparés
                // ═══════════════════════════════════════
                _ExpertTierSection(provider: provider),

                const SizedBox(height: MintSpacing.xl),

                const _AgentAutonomeSection(),

                const SizedBox(height: MintSpacing.xl),

                // ═══════════════════════════════════════
                //  Outils
                // ═══════════════════════════════════════
                _SectionLabel(l.dossierToolsSection),

                MintSurface(
                  tone: MintSurfaceTone.blanc,
                  padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
                  child: _DossierRow(
                    icon: Icons.build_outlined,
                    title: l.dossierToolsSection,
                    subtitle: l.dossierToolsCta,
                    onTap: () => context.push('/tools'),
                    showDivider: false,
                  ),
                ),

                const SizedBox(height: MintSpacing.xl),

                // ═══════════════════════════════════════
                //  Section 6 — Réglages
                // ═══════════════════════════════════════
                _SectionLabel(l.dossierReglages),

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

// ── Section label ─────────────────────────────────────────────────────────────

/// Thin label above each dossier section (e.g. "Mon profil", "Mon plan").
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: MintSpacing.xs,
        bottom: MintSpacing.sm,
      ),
      child: Text(
        text,
        style: MintTextStyles.bodySmall(color: MintColors.textMuted),
      ),
    );
  }
}

// ── Section 1 — Mon profil ────────────────────────────────────────────────────

/// Identity card + confidence score with progress bar.
/// Shows "Compléter mon profil" CTA when confidence < 60.
class _ProfileSection extends StatelessWidget {
  final MintUserState? mintState;
  final CoachProfileProvider provider;
  final String firstName;
  final int confidencePct;
  final S l;

  const _ProfileSection({
    required this.mintState,
    required this.provider,
    required this.firstName,
    required this.confidencePct,
    required this.l,
  });

  /// Derive archetype display label from [FinancialArchetype].
  String _archetypeLabel(FinancialArchetype archetype) {
    return switch (archetype) {
      FinancialArchetype.swissNative => 'Résident·e suisse',
      FinancialArchetype.expatEu => 'Expat EU/AELE',
      FinancialArchetype.expatNonEu => 'Expat hors EU',
      FinancialArchetype.expatUs => 'Résident·e US (FATCA)',
      FinancialArchetype.independentWithLpp => 'Indépendant·e avec LPP',
      FinancialArchetype.independentNoLpp => 'Indépendant·e sans LPP',
      FinancialArchetype.crossBorder => 'Frontalier·ère',
      FinancialArchetype.returningSwiss => 'Suisse de retour',
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = provider.hasProfile || mintState != null;
    final profile = mintState?.profile ?? provider.profile;
    final age = profile?.age;
    final canton = profile?.canton ?? '';
    final archetype = mintState?.archetype ?? profile?.archetype;
    final confidenceLow = confidencePct < 60;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Name + meta ──
          InkWell(
            onTap: () => context.push('/profile'),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MintColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      firstName.isNotEmpty
                          ? firstName[0].toUpperCase()
                          : '?',
                      style: MintTextStyles.titleMedium(
                        color: MintColors.primary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: MintSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName.isNotEmpty ? firstName : l.tabMoi,
                        style: MintTextStyles.titleMedium(
                          color: MintColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (age != null || canton.isNotEmpty)
                        Text(
                          [
                            if (age != null) '$age ans',
                            if (canton.isNotEmpty) canton,
                          ].join(' · '),
                          style: MintTextStyles.labelSmall(
                            color: MintColors.textMuted,
                          ),
                        ),
                      if (archetype != null)
                        Text(
                          _archetypeLabel(archetype),
                          style: MintTextStyles.labelSmall(
                            color: MintColors.textSecondary,
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

          const SizedBox(height: MintSpacing.md),
          Divider(height: 1, color: MintColors.textPrimary.withValues(alpha: 0.06)),
          const SizedBox(height: MintSpacing.md),

          // ── Confidence score ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.dossierConfidenceLabel,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ),
              ),
              Text(
                l.dossierConfidencePct(confidencePct),
                style: MintTextStyles.titleMedium(
                  color: confidencePct >= 60
                      ? MintColors.success
                      : MintColors.warning,
                ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidencePct / 100,
              backgroundColor: MintColors.textPrimary.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                confidencePct >= 60 ? MintColors.success : MintColors.warning,
              ),
              minHeight: 4,
            ),
          ),

          // ── CTA when confidence is low ──
          if (hasProfile && confidenceLow) ...[
            const SizedBox(height: MintSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/profile'),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: Text(l.dossierCompleteCta),
                style: TextButton.styleFrom(
                  foregroundColor: MintColors.primary,
                  textStyle: MintTextStyles.labelSmall(
                    color: MintColors.primary,
                  ).copyWith(fontWeight: FontWeight.w500),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section 2 — Mon plan ──────────────────────────────────────────────────────

/// CapSequence progress: X/Y étapes, current step, next step, change goal chip.
/// Falls back to "Choisir un objectif" CTA when no goal is selected.
class _PlanSection extends StatelessWidget {
  final MintUserState? mintState;
  final S l;

  const _PlanSection({required this.mintState, required this.l});

  @override
  Widget build(BuildContext context) {
    final plan = mintState?.capSequencePlan;
    final hasGoal = plan != null && plan.hasSteps;

    if (!hasGoal) {
      return MintSurface(
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined,
                size: 20, color: MintColors.textSecondary),
            const SizedBox(width: MintSpacing.md),
            Expanded(
              child: Text(
                l.dossierChooseGoalCta,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/pulse'),
              style: TextButton.styleFrom(
                foregroundColor: MintColors.primary,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l.dossierChooseGoalCta,
                style: MintTextStyles.labelSmall(
                  color: MintColors.primary,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    final currentStep = plan.currentStep;
    final nextStep = plan.nextStep;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Progress header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.dossierPlanProgress(plan.completedCount, plan.totalCount),
                style: MintTextStyles.titleMedium(
                  color: MintColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              ActionChip(
                label: Text(
                  l.dossierPlanChangeGoal,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textSecondary,
                  ),
                ),
                onPressed: () => context.push('/pulse'),
                backgroundColor:
                    MintColors.textPrimary.withValues(alpha: 0.05),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.xs,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: plan.progressPercent,
              backgroundColor: MintColors.textPrimary.withValues(alpha: 0.08),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(MintColors.primary),
              minHeight: 4,
            ),
          ),

          // ── Current step ──
          if (currentStep != null) ...[
            const SizedBox(height: MintSpacing.md),
            Divider(
                height: 1,
                color: MintColors.textPrimary.withValues(alpha: 0.06)),
            const SizedBox(height: MintSpacing.md),
            _PlanStepRow(
              label: l.dossierPlanCurrentStep,
              stepTitleKey: currentStep.titleKey,
              isActive: true,
              onTap: currentStep.intentTag != null
                  ? () => context.push(currentStep.intentTag!)
                  : null,
            ),
          ],

          // ── Next step ──
          if (nextStep != null) ...[
            const SizedBox(height: MintSpacing.sm),
            _PlanStepRow(
              label: l.dossierPlanNextStep,
              stepTitleKey: nextStep.titleKey,
              isActive: false,
              onTap: null,
            ),
          ],
        ],
      ),
    );
  }
}

/// A single plan step row inside [_PlanSection].
class _PlanStepRow extends StatelessWidget {
  final String label;
  final String stepTitleKey;
  final bool isActive;
  final VoidCallback? onTap;

  const _PlanStepRow({
    required this.label,
    required this.stepTitleKey,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    // Resolve step title from ARB key. The key is stored in the CapStep model.
    // We use a dynamic lookup via the generated AppLocalizations.
    final title = _resolveStepTitle(stepTitleKey, l);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 16,
            color: isActive ? MintColors.primary : MintColors.textMuted,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMuted,
                  ).copyWith(fontSize: 10),
                ),
                Text(
                  title,
                  style: MintTextStyles.bodySmall(
                    color: isActive
                        ? MintColors.textPrimary
                        : MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              color: MintColors.textMuted,
              size: 16,
            ),
        ],
      ),
    );
  }

  /// Resolve an ARB key stored in a [CapStep.titleKey] to a display string.
  ///
  /// Falls back to the raw key when no match is found (should never happen
  /// in production if ARB files are kept in sync with CapSequenceEngine).
  static String _resolveStepTitle(String key, S l) {
    return switch (key) {
      'capStepRetirement01Title' => l.capStepRetirement01Title,
      'capStepRetirement02Title' => l.capStepRetirement02Title,
      'capStepRetirement03Title' => l.capStepRetirement03Title,
      'capStepRetirement04Title' => l.capStepRetirement04Title,
      'capStepRetirement05Title' => l.capStepRetirement05Title,
      _ => key,
    };
  }
}

// ── Section 3 — Mes données ───────────────────────────────────────────────────

/// Shows what MINT knows: revenue, LPP, 3a, monthly margin, documents.
/// Data sourced from [MintUserState] / [CoachProfile] — no service calls.
class _DataSection extends StatelessWidget {
  final MintUserState? mintState;
  final CoachProfileProvider provider;
  final S l;

  const _DataSection({
    required this.mintState,
    required this.provider,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final profile = mintState?.profile ?? provider.profile;
    final prev = profile?.prevoyance;

    // Revenue: formatted range or exact.
    final revenuBrut = profile?.revenuBrutAnnuel;
    final revenuStr = revenuBrut != null && revenuBrut > 0
        ? formatChfWithPrefix(revenuBrut)
        : l.dossierDataUnknown;

    // LPP avoir.
    final lppAvoir = prev?.avoirLppTotal;
    final lppStr = lppAvoir != null && lppAvoir > 0
        ? formatChfWithPrefix(lppAvoir)
        : null;

    // 3a total.
    final total3a = prev?.totalEpargne3a ?? 0.0;
    final str3a = total3a > 0
        ? formatChfWithPrefix(total3a)
        : l.dossierDataUnknown;

    // Monthly free margin from BudgetSnapshot.
    final monthlyFree = mintState?.monthlyFree;
    final budgetStr = monthlyFree != null
        ? formatChfMonthly(monthlyFree)
        : l.dossierDataUnknown;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Column(
        children: [
          // ── Revenu ──
          _DataRow(
            icon: Icons.work_outline,
            label: l.dossierDataRevenu,
            value: revenuStr,
            onTap: () => context.push('/profile'),
          ),

          // ── LPP ──
          lppStr != null
              ? _DataRow(
                  icon: Icons.account_balance_outlined,
                  label: l.dossierDataLpp,
                  value: lppStr,
                  onTap: () => context.push('/lpp'),
                )
              : _DataRow(
                  icon: Icons.account_balance_outlined,
                  label: l.dossierDataLpp,
                  value: l.dossierDataUnknown,
                  cta: l.dossierScanLppCta,
                  onTap: () => context.push('/documents'),
                ),

          // ── 3a ──
          _DataRow(
            icon: Icons.savings_outlined,
            label: l.dossierData3a,
            value: str3a,
            onTap: () => context.push('/pilier-3a'),
          ),

          // ── Budget mensuel ──
          _DataRow(
            icon: Icons.bar_chart_outlined,
            label: l.dossierDataBudget,
            value: budgetStr,
            onTap: () => context.push('/budget'),
          ),

          // ── Documents ──
          _DossierRow(
            icon: Icons.folder_outlined,
            title: l.dossierDocumentsTitle,
            subtitle: l.dossierDocumentsSubtitle,
            onTap: () => context.push('/documents'),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

/// Compact read-only data row for Section 3 — Mes données.
class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// Optional CTA label shown in accent colour instead of [value].
  final String? cta;
  final VoidCallback onTap;

  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: MintSpacing.sm,
              horizontal: MintSpacing.md,
            ),
            child: Row(
              children: [
                Icon(icon, color: MintColors.textSecondary, size: 18),
                const SizedBox(width: MintSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                cta != null
                    ? Text(
                        cta!,
                        style: MintTextStyles.labelSmall(
                          color: MintColors.primary,
                        ).copyWith(fontWeight: FontWeight.w500),
                      )
                    : Text(
                        value,
                        style: MintTextStyles.titleMedium(
                          color: MintColors.textPrimary,
                        ).copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                const SizedBox(width: MintSpacing.xs),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: MintColors.textMuted,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
          child: Divider(
            height: 1,
            color: MintColors.textPrimary.withValues(alpha: 0.05),
          ),
        ),
      ],
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

// ── Expert Tier Section (S65) ──────────────────────────────────────────────

/// Shows the "Consulter un·e spécialiste" section.
///
/// Displays the suggested [AdvisorSpecialization] chips based on the user's
/// profile (e.g. retirement if age > 55, divorce if civil status is divorced).
/// The CTA routes to the coach chat with the `specialist` prompt pre-loaded.
///
/// Design: MintSurface blanc, section label above, chevron CTA below chips.
class _ExpertTierSection extends StatelessWidget {
  final CoachProfileProvider provider;

  const _ExpertTierSection({required this.provider});

  /// Derive up to 3 suggested specializations from the profile.
  List<AdvisorSpecialization> _suggestedSpecs(BuildContext context) {
    if (!provider.hasProfile) return [AdvisorSpecialization.retirement];
    final profile = provider.profile!;
    final age = DateTime.now().year - profile.birthYear;
    final suggestions = <AdvisorSpecialization>[];

    // Retirement priority for users approaching retirement age.
    if (age >= 45) suggestions.add(AdvisorSpecialization.retirement);

    // Divorce / separation situation.
    if (profile.etatCivil == CoachCivilStatus.divorce) {
      suggestions.add(AdvisorSpecialization.divorce);
    }

    // Tax optimization if LPP buyback potential.
    if ((profile.prevoyance.lacuneRachatRestante) > 0) {
      suggestions.add(AdvisorSpecialization.taxOptimization);
    }

    // Real estate if high equity or existing mortgage.
    if (profile.patrimoine.immobilierEffectif > 0 ||
        (profile.patrimoine.epargneLiquide + profile.patrimoine.investissements) >
            100000) {
      if (!suggestions.contains(AdvisorSpecialization.taxOptimization)) {
        suggestions.add(AdvisorSpecialization.realEstate);
      }
    }

    // Succession for users with patrimoine or children.
    if (profile.patrimoine.totalPatrimoine > 200000 || profile.nombreEnfants > 0) {
      if (suggestions.length < 3) suggestions.add(AdvisorSpecialization.succession);
    }

    // Self-employment specialization.
    if (profile.employmentStatus == 'independant') {
      suggestions.insert(0, AdvisorSpecialization.selfEmployment);
    }

    // Expat flag.
    if (profile.archetype == FinancialArchetype.expatUs ||
        profile.archetype == FinancialArchetype.expatEu ||
        profile.archetype == FinancialArchetype.expatNonEu) {
      if (suggestions.length < 3) suggestions.add(AdvisorSpecialization.expatriation);
    }

    if (suggestions.isEmpty) suggestions.add(AdvisorSpecialization.retirement);
    return suggestions.take(3).toList();
  }

  String _specLabel(AdvisorSpecialization spec, S l) {
    return switch (spec) {
      AdvisorSpecialization.retirement => l.expertSpecRetirement,
      AdvisorSpecialization.succession => l.expertSpecSuccession,
      AdvisorSpecialization.expatriation => l.expertSpecExpatriation,
      AdvisorSpecialization.divorce => l.expertSpecDivorce,
      AdvisorSpecialization.selfEmployment => l.expertSpecSelfEmployment,
      AdvisorSpecialization.realEstate => l.expertSpecRealEstate,
      AdvisorSpecialization.taxOptimization => l.expertSpecTax,
      AdvisorSpecialization.debtManagement => l.expertSpecDebt,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final specs = _suggestedSpecs(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: MintSpacing.xs,
            bottom: MintSpacing.sm,
          ),
          child: Text(
            l.dossierExpertSectionTitle,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
        ),
        MintSurface(
          tone: MintSurfaceTone.blanc,
          padding: const EdgeInsets.all(MintSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.expertSubtitle,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ),
              ),
              const SizedBox(height: MintSpacing.sm),
              Wrap(
                spacing: MintSpacing.xs,
                runSpacing: MintSpacing.xs,
                children: specs
                    .map(
                      (spec) => Chip(
                        label: Text(
                          _specLabel(spec, l),
                          style: MintTextStyles.labelSmall(
                            color: MintColors.textPrimary,
                          ),
                        ),
                        backgroundColor:
                            MintColors.primary.withValues(alpha: 0.08),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(
                          horizontal: MintSpacing.xs,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: MintSpacing.md),
              Divider(
                height: 1,
                color: MintColors.textPrimary.withValues(alpha: 0.05),
              ),
              const SizedBox(height: MintSpacing.xs),
              _DossierRow(
                icon: Icons.person_search_outlined,
                title: l.expertPrepareDossierCta,
                subtitle: l.expertDisclaimer,
                onTap: () => context.push('/coach/chat?prompt=specialist'),
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Agent Autonome Section (S68) ───────────────────────────────────────────

/// Shows the "Documents préparés" section.
///
/// Three rows — tax declaration, AVS extract letter, LPP transfer letter —
/// each routing to the coach chat with the appropriate pre-loaded prompt.
/// The coach generates the document via [FormPrefillService] /
/// [LetterGenerationService] during the conversation.
///
/// No services are called here: wiring is purely navigational.
/// Actual generation happens in the coach chat tool pipeline.
class _AgentAutonomeSection extends StatelessWidget {
  const _AgentAutonomeSection();

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: MintSpacing.xs,
            bottom: MintSpacing.sm,
          ),
          child: Text(
            l.dossierAgentSectionTitle,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
        ),
        MintSurface(
          tone: MintSurfaceTone.blanc,
          padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
          child: Column(
            children: [
              _DossierRow(
                icon: Icons.receipt_long_outlined,
                title: l.agentFormsTaxCta,
                subtitle: l.agentFormsTaxSubtitle,
                onTap: () =>
                    context.push('/coach/chat?prompt=tax_declaration'),
              ),
              _DossierRow(
                icon: Icons.assignment_ind_outlined,
                title: l.agentFormsAvsCta,
                subtitle: l.agentFormsAvsSubtitle,
                onTap: () => context.push('/coach/chat?prompt=avs_extract'),
              ),
              _DossierRow(
                icon: Icons.send_outlined,
                title: l.agentFormsLppCta,
                subtitle: l.agentFormsLppSubtitle,
                onTap: () => context.push('/coach/chat?prompt=lpp_transfer'),
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
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
