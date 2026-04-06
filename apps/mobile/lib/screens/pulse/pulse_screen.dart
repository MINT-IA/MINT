import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/services/cap_engine.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/premium/mint_hero_number.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_signal_row.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/pulse/action_success_sheet.dart';
import 'package:mint_mobile/widgets/pulse/cap_card.dart';
import 'package:mint_mobile/widgets/pulse/pulse_disclaimer.dart';

// ────────────────────────────────────────────────────────
//  AUJOURD'HUI — V6 "Premium Calm" (Cleo-inspired)
// ────────────────────────────────────────────────────────
//
//  Contrat UX (MINT_UX_GRAAL_MASTERPLAN.md §10 + §12 + §6 Visual Graal):
//  - Fond porcelaine chaud (#F7F4EE), JAMAIS blanc froid
//  - 1 phrase narrative (cap.whyNow)
//  - 1 MintHeroNumber (56pt+), maximum d'air
//  - 1 MintNarrativeCard sauge (Cap du jour)
//  - 2 MintSignalRow (budget libre, patrimoine)
//  - Disclaimer presque invisible en bas
//  - AppBar: porcelaine, texte textPrimary, pas de gradient
//
//  V6 changes from V5:
//  - Premium widgets: MintHeroNumber, MintNarrativeCard, MintSignalRow, MintSurface
//  - AppBar: porcelaine bg, no gradient (was primary→primaryLight)
//  - Background: porcelaine (was white)
//  - CapCard replaced by MintNarrativeCard with sauge tone
//  - _SignalRow replaced by MintSignalRow (shared widget)
//  - Fallback action uses MintNarrativeCard bleu tone
//  - Empty state: porcelaine bg
//  - All business logic (CapEngine, projections, FRI) unchanged
// ────────────────────────────────────────────────────────

class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  ProjectionResult? _cachedProjection;
  FinancialFitnessScore? _cachedFri;
  CoachProfile? _lastProfile;

  /// CapEngine memory — loaded async on first build.
  CapMemory _capMemory = const CapMemory();
  bool _capMemoryLoaded = false;

  /// The current cap decision. Recomputed when profile changes.
  CapDecision? _cachedCap;

  /// Unified BudgetSnapshot — replaces trio when BudgetLivingEngine is available.
  BudgetSnapshot? _cachedSnapshot;

  /// Tracks when we last showed ActionSuccess to avoid repeat.
  DateTime? _lastSeenCompletedDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<CoachProfileProvider>();
    if (!provider.hasProfile) {
      if (_lastProfile != null) {
        _lastProfile = null;
        _cachedProjection = null;
        _cachedFri = null;
        _cachedCap = null;
        _cachedSnapshot = null;
        // H1 fix: reset CapMemory on profile disappearance
        // so a new profile doesn't inherit stale cap history.
        _capMemory = const CapMemory();
        _capMemoryLoaded = false;
      }
      return;
    }

    final profile = provider.profile!;
    if (_lastProfile == profile) return;
    _lastProfile = profile;

    final l = S.of(context)!;

    // Load CapMemory once
    if (!_capMemoryLoaded) {
      _capMemoryLoaded = true;
      CapMemoryStore.load().then((mem) {
        if (mounted) {
          final lInner = S.of(context)!;
          setState(() => _capMemory = mem);
          _recomputeSnapshot(profile);
          _recomputeCap(profile, lInner);
          _checkForCompletionFeedback(profile, lInner);
        }
      });
    }

    // Try BudgetLivingEngine first (unified snapshot).
    _recomputeSnapshot(profile);

    // Legacy fallback: compute individually if snapshot unavailable.
    if (_cachedSnapshot == null) {
      try {
        _cachedProjection = ForecasterService.project(profile: profile);
      } catch (_) {
        _cachedProjection = null;
      }

      try {
        _cachedFri = FinancialFitnessService.calculate(
          profile: profile,
          previousScore: provider.previousScore,
        );
      } catch (_) {
        _cachedFri = null;
      }
    }

    _recomputeCap(profile, l);
  }

  /// Try to compute unified BudgetSnapshot via BudgetLivingEngine.
  /// Falls back to null if the engine is not yet available (other agent
  /// creating it) or if the profile is too incomplete.
  void _recomputeSnapshot(CoachProfile profile) {
    try {
      _cachedSnapshot = BudgetLivingEngine.compute(profile);
    } catch (_) {
      // Fallback: BudgetLivingEngine not available yet or profile incomplete.
      _cachedSnapshot = null;
    }
  }

  void _recomputeCap(CoachProfile profile, S l) {
    try {
      final cap = CapEngine.compute(
        profile: profile,
        now: DateTime.now(),
        l: l,
        memory: _capMemory,
      );
      _cachedCap = cap;

      // Mark served — setState so feedback pill reflects updated memory.
      CapMemoryStore.markServed(_capMemory, cap.id).then((updated) {
        if (mounted) setState(() => _capMemory = updated);
      });
    } catch (_) {
      _cachedCap = null;
    }
  }

  /// Show ActionSuccess sheet if the user just completed a cap action
  /// and we haven't shown feedback yet.
  void _checkForCompletionFeedback(CoachProfile profile, S l) {
    final completedDate = _capMemory.lastCompletedDate;
    if (completedDate == null) return;
    if (_lastSeenCompletedDate == completedDate) return;

    // Only show if completed within the last 5 minutes (fresh return)
    final minutesSince = DateTime.now().difference(completedDate).inMinutes;
    if (minutesSince > 5) {
      _lastSeenCompletedDate = completedDate;
      return;
    }

    _lastSeenCompletedDate = completedDate;

    // Show feedback after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final completedCap = _cachedCap;
      if (completedCap == null) return;

      // Compute next cap for the "what's next" section
      final nextCap = CapEngine.compute(
        profile: profile,
        now: DateTime.now(),
        l: l,
        memory: _capMemory,
      );

      showActionSuccessSheet(
        context,
        ActionSuccessData.fromCap(
          completedCap: completedCap,
          nextCap: nextCap.id != completedCap.id ? nextCap : null,
        ),
      );
    });
  }

  // ── BUILD ──

  @override
  Widget build(BuildContext context) {
    final coachProvider = context.watch<CoachProfileProvider>();

    if (!coachProvider.hasProfile) {
      return _buildEmptyState(context);
    }

    final profile = coachProvider.profile!;
    // Use separately computed _cachedCap (BudgetSnapshot has no cap getter).
    final cap = _cachedCap;
    final l = S.of(context)!;

    // Compute the dominant number
    final dominantNumber = _computeDominantNumber(profile);
    final dominantLabel = _computeDominantLabel(profile, l);
    final dominantColor = _computeDominantColor(dominantNumber);
    final narrativePhrase = _computeNarrative(profile, cap, l);

    // Recent action feedback
    final recentAction = _recentActionLabel();

    return Container(
      color: MintColors.porcelaine,
      child: CustomScrollView(
        slivers: [
          // ── AppBar — warm porcelaine, no gradient ──
          _buildAppBar(context, profile),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: MintSpacing.xxl + MintSpacing.lg),

                  // ── 1. NARRATIVE PHRASE ──
                  Text(
                    narrativePhrase,
                    style: MintTextStyles.bodyLarge(
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: MintSpacing.lg),

                  // ── 2. HERO NUMBER (56pt, Cleo-style) ──
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: dominantNumber.value),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) => MintHeroNumber(
                      value: dominantNumber.format(value),
                      caption: dominantLabel,
                      color: dominantColor,
                    ),
                  ),

                  const SizedBox(height: MintSpacing.xxl + MintSpacing.md),

                  // ── 3. CAP DU JOUR (MintNarrativeCard) ──
                  if (cap != null)
                    _buildCapNarrativeCard(context, cap, recentAction, l)
                  else
                    _buildFallbackAction(context),

                  // ── 3b. CAP IMPACT (from BudgetSnapshot) ──
                  if (_cachedSnapshot != null && _cachedSnapshot!.capImpacts.isNotEmpty)
                    _buildCapImpact(_cachedSnapshot!.capImpacts.first, l),

                  const SizedBox(height: MintSpacing.xl),

                  // ── 4. SECONDARY SIGNALS (MintSignalRow) ──
                  _buildSecondarySignals(profile, l),

                  const SizedBox(height: MintSpacing.xxl + MintSpacing.lg),

                  // ── Disclaimer — almost invisible ──
                  const PulseDisclaimer(),
                  const SizedBox(height: MintSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CAP NARRATIVE CARD (premium) ──

  Widget _buildCapNarrativeCard(
    BuildContext context,
    CapDecision cap,
    String? recentAction,
    S l,
  ) {
    final kindLabel = switch (cap.kind) {
      CapKind.complete => l.capKindComplete,
      CapKind.correct => l.capKindCorrect,
      CapKind.optimize => l.capKindOptimize,
      CapKind.secure => l.capKindSecure,
      CapKind.prepare => l.capKindPrepare,
      CapKind.alert => l.capKindAlert,
    };

    return MintNarrativeCard(
      headline: cap.headline,
      body: cap.whyNow,
      ctaLabel: cap.ctaLabel,
      tone: MintSurfaceTone.sauge,
      badge: recentAction ?? kindLabel,
      leading: cap.expectedImpact != null
          ? Row(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  size: 16,
                  color: MintColors.success.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cap.expectedImpact!,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.success,
                    ).copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : null,
      onTap: () => _handleCapTap(context, cap),
    );
  }

  void _handleCapTap(BuildContext context, CapDecision cap) {
    switch (cap.ctaMode) {
      case CtaMode.route:
        if (cap.ctaRoute != null) {
          context.push<void>(cap.ctaRoute!);
        }
      case CtaMode.coach:
        if (cap.coachPrompt != null && cap.coachPrompt!.isNotEmpty) {
          CapCoachBridge.pendingPrompt = cap.coachPrompt;
        }
        NavigationShellState.switchTab(1);
      case CtaMode.capture:
        final route = switch (cap.captureType) {
          'lpp' => '/document-scan',
          'avs' => '/document-scan/avs',
          'profile' => '/onboarding/enrichment',
          _ => '/onboarding/enrichment',
        };
        context.push<void>(route);
    }
  }

  // ── DOMINANT NUMBER ──

  _DominantNumber _computeDominantNumber(CoachProfile profile) {
    // ── Snapshot-driven hero (goal-contextual) ──
    final snap = _cachedSnapshot;
    if (snap != null) {
      final goalType = profile.goalA.type;
      switch (goalType) {
        case GoalAType.retraite:
          // Prefer gap if visible, else retirement net income.
          if (snap.gap != null) {
            return _DominantNumber(
              value: snap.gap!.monthlyGap,
              format: (v) => '${formatChf(v)} CHF',
              type: _NumberType.chf,
            );
          }
          if (snap.retirement != null) {
            return _DominantNumber(
              value: snap.retirement!.monthlyNet,
              format: (v) => '${formatChf(v)} CHF',
              type: _NumberType.chf,
            );
          }
        case GoalAType.debtFree:
          return _DominantNumber(
            value: snap.present.monthlyFree,
            format: (v) => '${formatChf(v)} CHF',
            type: _NumberType.chf,
          );
        case GoalAType.achatImmo:
          // Use present free as proxy (capacity computed elsewhere).
          return _DominantNumber(
            value: snap.present.monthlyFree,
            format: (v) => '${formatChf(v)} CHF',
            type: _NumberType.chf,
          );
        default:
          // No declared goal or custom — show present monthly free.
          return _DominantNumber(
            value: snap.present.monthlyFree,
            format: (v) => '${formatChf(v)} CHF',
            type: _NumberType.chf,
          );
      }
    }

    // ── Legacy path (no snapshot) ──
    if (_cachedProjection != null) {
      // Use tauxRemplacementBase from ForecasterService — single source of truth.
      // This divides household retirement income by household current income,
      // avoiding the previous bug where household retirement was divided by
      // individual income only.
      final taux = _cachedProjection!.tauxRemplacementBase;
      if (taux > 0) {
        return _DominantNumber(
          value: taux,
          format: (v) => '${v.round()}\u00a0%',
          type: _NumberType.percentage,
        );
      }
      final retraite = _cachedProjection!.base.revenuAnnuelRetraite / 12;
      if (retraite > 0) {
        return _DominantNumber(
          value: retraite,
          format: (v) => '${formatChf(v)} CHF',
          type: _NumberType.chf,
        );
      }
    }
    final fri = _cachedFri;
    if (fri != null) {
      return _DominantNumber(
        value: fri.global.toDouble(),
        format: (v) => '${v.round()}/100',
        type: _NumberType.score,
      );
    }
    return _DominantNumber(
      value: 0,
      format: (_) => '—',
      type: _NumberType.score,
    );
  }

  String _computeDominantLabel(CoachProfile profile, S l) {
    // ── Snapshot-driven label ──
    final snap = _cachedSnapshot;
    if (snap != null) {
      final goalType = profile.goalA.type;
      switch (goalType) {
        case GoalAType.retraite:
          if (snap.gap != null) return l.pulseLabelMonthlyGap;
          if (snap.retirement != null) return l.pulseLabelRetirementFree;
          return l.pulseLabelMonthlyFree;
        case GoalAType.debtFree:
          return l.pulseLabelMonthlyFree;
        case GoalAType.achatImmo:
          return l.pulseLabelMonthlyFree;
        default:
          return l.pulseLabelMonthlyFree;
      }
    }

    // ── Legacy path ──
    if (_cachedProjection != null) {
      final taux = _cachedProjection!.tauxRemplacementBase;
      if (taux > 0) {
        return l.pulseLabelReplacementRate;
      }
      return l.pulseLabelRetirementIncome;
    }
    return l.pulseLabelFinancialScore;
  }

  Color _computeDominantColor(_DominantNumber n) {
    if (n.type == _NumberType.percentage) {
      if (n.value >= 70) return MintColors.success;
      if (n.value >= 50) return MintColors.warning;
      return MintColors.error;
    }
    if (n.type == _NumberType.score) {
      if (n.value >= friThresholdBon) return MintColors.success;
      if (n.value >= friThresholdAttention) return MintColors.warning;
      return MintColors.error;
    }
    // CHF values from snapshot: negative = warning/error.
    if (n.type == _NumberType.chf && _cachedSnapshot != null) {
      if (n.value < 0) return MintColors.warning;
      if (n.value > 0) return MintColors.success;
    }
    return MintColors.textPrimary;
  }

  // ── NARRATIVE ──

  String _computeNarrative(
      CoachProfile profile, CapDecision? cap, S l) {
    final firstName = profile.firstName;
    final yearsToRetire = profile.effectiveRetirementAge - profile.age;
    final hasName = firstName != null && firstName.trim().isNotEmpty;

    String prefix(String msg) => hasName ? '$firstName, $msg' : msg;

    // Cap whyNow as narrative source (plan-first).
    // headline is shown in CapCard below — using whyNow here avoids
    // duplicating the same text above the fold (M3 fix).
    if (cap != null) {
      final w = cap.whyNow;
      return hasName
          ? '$firstName, ${w[0].toLowerCase()}${w.substring(1)}'
          : w;
    }

    // Fallback: time-based narrative
    if (yearsToRetire <= 5) {
      return prefix(l.pulseNarrativeRetirementClose);
    }
    if (yearsToRetire <= 15) {
      return prefix(l.pulseNarrativeYearsToAct(yearsToRetire));
    }
    if (yearsToRetire <= 25) {
      return prefix(l.pulseNarrativeTimeToBuild);
    }
    return prefix(l.pulseNarrativeDefault);
  }

  // ── FALLBACK ACTION (no cap) ──

  Widget _buildFallbackAction(BuildContext context) {
    return MintNarrativeCard(
      headline: S.of(context)!.pulseEmptyCtaStart,
      body: S.of(context)!.pulseNarrativeDefault,
      ctaLabel: S.of(context)!.pulseEmptyCtaStart,
      tone: MintSurfaceTone.bleu,
      onTap: () => NavigationShellState.switchTab(1),
    );
  }

  // ── RECENT ACTION FEEDBACK ──

  String? _recentActionLabel() {
    if (_capMemory.completedActions.isEmpty) return null;
    // H2 fix: use lastCompletedDate (stamped on actual action completion),
    // not lastCapDate (stamped on cap served).
    if (_capMemory.lastCompletedDate == null) return null;

    final hoursSince =
        DateTime.now().difference(_capMemory.lastCompletedDate!).inHours;
    if (hoursSince > 48) return null;

    // M4 fix: use l10n keys instead of hardcoded FR strings.
    final l = S.of(context)!;
    return hoursSince < 24
        ? l.pulseFeedbackRecalculated
        : l.pulseFeedbackAddedRecently;
  }

  // ── SECONDARY SIGNALS (max 2) ──

  Widget _buildSecondarySignals(CoachProfile profile, S l) {
    final signals = <Widget>[];
    final snap = _cachedSnapshot;

    // Signal 1: Budget libre (snapshot-aware)
    if (snap != null) {
      final libre = snap.present.monthlyFree;
      signals.add(MintSignalRow(
        label: l.pulseKeyFigBudgetLibre,
        value: libre >= 0
            ? '+${formatChfWithPrefix(libre)}/mois'
            : '${formatChfWithPrefix(libre)}/mois',
        valueColor: libre >= 0 ? MintColors.success : MintColors.warning,
        onTap: () => context.push('/budget'),
      ));
    } else {
      // Legacy fallback
      final revenuNet = _computeRevenuNet(profile);
      if (revenuNet > 0) {
        final dep = profile.totalDepensesMensuelles;
        final libre = revenuNet - dep;
        signals.add(MintSignalRow(
          label: l.pulseKeyFigBudgetLibre,
          value: libre >= 0
              ? '+${formatChfWithPrefix(libre)}/mois'
              : '${formatChfWithPrefix(libre)}/mois',
          valueColor: libre >= 0 ? MintColors.success : MintColors.warning,
          onTap: () => context.push('/budget'),
        ));
      }
    }

    // Signal 2: Patrimoine (unchanged — not in snapshot scope)
    final patrimoine = profile.patrimoine.totalPatrimoine +
        (profile.prevoyance.avoirLppTotal ?? 0) +
        profile.prevoyance.totalEpargne3a;
    if (patrimoine > 0) {
      signals.add(MintSignalRow(
        label: l.pulseKeyFigPatrimoine,
        value: formatChfCompact(patrimoine),
        valueColor: MintColors.textPrimary,
        onTap: () => context.push('/profile/bilan'),
      ));
    }

    if (signals.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (int i = 0; i < signals.length && i < 2; i++) ...[
          signals[i],
          if (i < signals.length - 1 && i < 1)
            Divider(
              color: MintColors.border.withValues(alpha: 0.2),
              height: 1,
            ),
        ],
      ],
    );
  }

  // ── CAP IMPACT (from BudgetSnapshot.capImpacts) ──

  Widget _buildCapImpact(BudgetCapImpact impact, S l) {
    // TODO(P2): re-enable rich now/later display when BudgetCapImpact API expanded
    return Padding(
      padding: const EdgeInsets.only(top: MintSpacing.sm),
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        child: Row(
          children: [
            Icon(
              Icons.trending_up_rounded,
              size: 16,
              color: MintColors.success.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '+${impact.monthlyDelta.round()} CHF/mois',
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── APP BAR (porcelaine, no gradient — premium calm) ──

  SliverAppBar _buildAppBar(BuildContext context, CoachProfile profile) {
    final l = S.of(context)!;
    final firstName = profile.firstName ?? '';
    final greeting =
        firstName.isNotEmpty ? l.pulseGreeting(firstName) : l.tabToday;

    return SliverAppBar(
      floating: false,
      pinned: true,
      backgroundColor: MintColors.porcelaine,
      surfaceTintColor: MintColors.porcelaine,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        greeting,
        style: MintTextStyles.titleMedium(color: MintColors.textPrimary)
            .copyWith(fontSize: 20),
      ),
      centerTitle: false,
      actions: [
        if (profile.isCouple)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              label: 'Solo / Duo',
              button: true,
              child: IconButton(
                icon: const Icon(
                  Icons.people_outline,
                  color: MintColors.textPrimary,
                ),
                onPressed: () => context.push('/couple'),
              ),
            ),
          ),
      ],
    );
  }

  // ── EMPTY STATE ──

  Widget _buildEmptyState(BuildContext context) {
    final l = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.visibility_outlined,
                size: 56,
                color: MintColors.textMuted.withValues(alpha: 0.3),
              ),
              const SizedBox(height: MintSpacing.lg),
              Text(
                l.pulseEmptyTitle,
                style: MintTextStyles.headlineLarge(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                l.pulseEmptySubtitle,
                style: MintTextStyles.bodyMedium(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MintSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => context.push('/onboarding/quick'),
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l.pulseEmptyCtaStart,
                    style: MintTextStyles.titleMedium(),
                  ),
                ),
              ),
              const Spacer(flex: 3),
              const PulseDisclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  // ── HELPERS ──

  double _computeRevenuNet(CoachProfile profile) {
    if (profile.salaireBrutMensuel <= 0) return 0.0;
    return NetIncomeBreakdown.compute(
      grossSalary: profile.salaireBrutMensuel * 12,
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      age: profile.age,
    ).monthlyNetPayslip;
  }
}

// ── DOMINANT NUMBER MODEL ──

enum _NumberType { percentage, chf, score }

class _DominantNumber {
  final double value;
  final String Function(double) format;
  final _NumberType type;

  const _DominantNumber({
    required this.value,
    required this.format,
    required this.type,
  });
}

// ── NAVIGATION SHELL STATE (kept here for import compatibility) ──

class NavigationShellState {
  NavigationShellState._();
  static void Function(int index)? _switchTab;

  static void register(void Function(int index) callback) {
    _switchTab = callback;
  }

  static void unregister() {
    _switchTab = null;
  }

  static void switchTab(int index) {
    _switchTab?.call(index);
  }
}
