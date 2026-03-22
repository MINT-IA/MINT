import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/cap_engine.dart';
import 'package:mint_mobile/services/cap_step_title_resolver.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/gamification/community_challenge_service.dart';
import 'package:mint_mobile/services/gamification/seasonal_event_service.dart';
import 'package:mint_mobile/services/mortgage_service.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/services/goal_selection_service.dart';
import 'package:mint_mobile/widgets/pulse/action_success_sheet.dart';
import 'package:mint_mobile/widgets/pulse/cap_card.dart';
import 'package:mint_mobile/widgets/pulse/cap_sequence_card.dart';
import 'package:mint_mobile/widgets/pulse/goal_selector_sheet.dart';
import 'package:mint_mobile/widgets/pulse/pulse_disclaimer.dart';
import 'package:mint_mobile/widgets/premium/mint_count_up.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/services/nudge/nudge_engine.dart' show Nudge;
import 'package:mint_mobile/services/nudge/nudge_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Goal category resolved from active profile + MintStateProvider ──
enum _ActiveGoal { retirement, budget, housing }

// ────────────────────────────────────────────────────────
//  AUJOURD'HUI — V5 "Plan-first"
// ────────────────────────────────────────────────────────
//
//  Contrat UX (MINT_UX_GRAAL_MASTERPLAN.md §10 + §12):
//  - 1 phrase personnalisée (from Cap headline or narrative)
//  - 1 chiffre dominant (displayLarge)
//  - 1 Cap du jour (CapCard — the single priority)
//  - 2 signaux secondaires max
//  - Rien d'autre au-dessus du fold
//
//  V5 changes from V4:
//  - CapEngine replaces ResponseCardService + PulseHeroEngine glue
//  - CapCard replaces _buildMinimalActionCard
//  - CapMemory loaded async, markServed on display
//  - Narrative can come from Cap.headline (fallback: legacy)
//  - PulseHeroEngine kept only as narrative fallback
// ────────────────────────────────────────────────────────

class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  CoachProfile? _lastProfile;

  /// CapEngine memory — loaded async on first build.
  CapMemory _capMemory = const CapMemory();
  bool _capMemoryLoaded = false;

  /// The current cap decision. Recomputed when profile changes (for real l10n).
  CapDecision? _cachedCap;

  /// The current cap sequence for the user's active goal.
  CapSequence? _cachedSequence;

  /// Tracks when we last showed ActionSuccess to avoid repeat.
  DateTime? _lastSeenCompletedDate;

  /// Explicit goal tag selected by the user via GoalSelectorSheet.
  ///
  /// Null = auto-detect from MintStateProvider / profile.
  String? _selectedGoalTag;

  /// Nudge IDs dismissed in this session — optimistic UI hide while
  /// NudgePersistence writes to SharedPreferences async.
  final Set<String> _sessionDismissedNudgeIds = {};

  /// True after the first MintCountUp revelation has played.
  /// Subsequent rebuilds skip the 5-step sequence (just count-up).
  bool _hasRevealedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<CoachProfileProvider>();
    if (!provider.hasProfile) {
      if (_lastProfile != null) {
        _lastProfile = null;
        _cachedCap = null;
        _cachedSequence = null;
        // Reset CapMemory on profile disappearance so a new profile
        // doesn't inherit stale cap history.
        _capMemory = const CapMemory();
        _capMemoryLoaded = false;
      }
      return;
    }

    final profile = provider.profile!;
    if (_lastProfile == profile) return;
    _lastProfile = profile;

    // Load CapMemory once; also load explicit goal selection.
    if (!_capMemoryLoaded) {
      _capMemoryLoaded = true;
      CapMemoryStore.load().then((mem) async {
        String? selectedGoal;
        try {
          final prefs = await SharedPreferences.getInstance();
          selectedGoal = await GoalSelectionService.getSelectedGoal(prefs);
        } catch (_) {
          selectedGoal = null;
        }
        if (mounted) {
          setState(() {
            _capMemory = mem;
            _selectedGoalTag = selectedGoal;
          });
          _recomputeCap(profile);
          _checkForCompletionFeedback(profile);
        }
      });
    }

    _recomputeCap(profile);
  }

  void _recomputeCap(CoachProfile profile) {
    try {
      final l = S.of(context)!;
      // ARCH NOTE: CapEngine computed locally for i18n labels (requires BuildContext).
      // Cap ID is identical to MintUserState.currentCap — only labels differ.
      // See mint_state_engine.dart SFr() comment for architectural context.
      final cap = CapEngine.compute(
        profile: profile,
        now: DateTime.now(),
        l: l,
        memory: _capMemory,
      );
      _cachedCap = cap;
      // Read CapSequence from unified state (MintStateProvider).
      // MintStateEngine now computes capSequencePlan when a goal is selected.
      try {
        _cachedSequence =
            context.read<MintStateProvider>().state?.capSequencePlan;
      } catch (_) {
        _cachedSequence = null;
      }
      // Mark served — setState so feedback pill reflects updated memory.
      CapMemoryStore.markServed(_capMemory, cap.id).then((updated) {
        if (mounted) setState(() => _capMemory = updated);
      });
    } catch (_) {
      _cachedCap = null;
      _cachedSequence = null;
    }
  }

  /// Show ActionSuccess sheet if the user just completed a cap action
  /// and we haven't shown feedback yet.
  void _checkForCompletionFeedback(CoachProfile profile) {
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
        l: S.of(context)!,
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

    // Read unified state from MintStateProvider — single source of truth
    // for all financial computations. Graceful degradation: if the provider
    // is not in the tree (e.g. tests without full app setup), falls back
    // to null values and legacy paths throughout.
    MintUserState? mintState;
    try {
      mintState = context.watch<MintStateProvider>().state;
    } catch (_) {
      // Provider not in widget tree — all mintState paths degrade to null.
    }

    // Explicit user selection takes priority over MintStateProvider goal tag.
    final activeGoalIntentTag =
        _selectedGoalTag ?? mintState?.activeGoalIntentTag;

    // Active nudges from MintStateEngine, minus any dismissed in this session.
    final activeNudges = (mintState?.activeNudges ?? const [])
        .where((n) => !_sessionDismissedNudgeIds.contains(n.id))
        .toList();

    if (!coachProvider.hasProfile) {
      return _buildEmptyState(context);
    }

    final profile = coachProvider.profile!;
    final cap = _cachedCap ?? mintState?.currentCap;
    final l = S.of(context)!;

    // Compute the dominant number
    final dominantNumber =
        _computeDominantNumber(profile, mintState, activeGoalIntentTag);
    final dominantLabel =
        _computeDominantLabel(profile, mintState, l, activeGoalIntentTag);
    final dominantColor = _computeDominantColor(dominantNumber);
    final narrativePhrase =
        _computeNarrative(profile, cap, l, activeGoalIntentTag);

    // Recent action feedback
    final recentAction = _recentActionLabel();

    return CustomScrollView(
      slivers: [
        // ── AppBar (Pulse exception: gradient) ──
        _buildAppBar(context, profile),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: MintSpacing.xxl),

                // ── 1+2. REVELATION 5 TEMPS ──
                // Setup text (narrative) → silence → count-up → ligne → context
                // All orchestrated by MintCountUp as a single sequence.
                MintCountUp(
                  value: dominantNumber.value.abs(),
                  prefix: _dominantPrefix(dominantNumber),
                  suffix: _dominantSuffix(dominantNumber),
                  setupText: narrativePhrase,
                  contextText: dominantLabel,
                  color: dominantColor,
                  fullReveal: !_hasRevealedOnce,
                  onRevealComplete: () {
                    if (mounted && !_hasRevealedOnce) {
                      setState(() => _hasRevealedOnce = true);
                    }
                  },
                ),
                const SizedBox(height: MintSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildGoalChip(context, profile, l, activeGoalIntentTag),
                ),

                const SizedBox(height: MintSpacing.xxl),

                // ── 3. CAP DU JOUR ──
                if (cap != null)
                  CapCard(
                    cap: cap,
                    recentActionLabel: recentAction,
                  )
                else
                  _buildFallbackAction(context),

                // ── 3b. CAP SEQUENCE ──
                if (_cachedSequence != null &&
                    _cachedSequence!.hasSteps) ...[
                  const SizedBox(height: MintSpacing.md),
                  CapSequenceCard(sequence: _cachedSequence!),
                ],

                // ── 3c. PLAN PROGRESS (compact CapSequence strip) ──
                if (mintState?.capSequencePlan != null &&
                    mintState!.capSequencePlan!.totalCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: MintSpacing.lg),
                    child: _PlanProgressSection(
                      sequence: mintState.capSequencePlan!,
                    ),
                  ),

                const SizedBox(height: MintSpacing.xl),

                // ── 4. DEUX SIGNAUX SECONDAIRES ──
                _buildSecondarySignals(profile, mintState, l),

                // ── 5. NUDGE PROACTIF (S61 — JITAI) ──
                if (activeNudges.isNotEmpty) ...[
                  const SizedBox(height: MintSpacing.xl),
                  _buildNudgeCard(activeNudges.first, l),
                ],

                // ── 6. ÉVÉNEMENT SAISONNIER (S66) ──
                ..._buildSeasonalEventCard(l),

                // ── 7. DÉFI COMMUNAUTAIRE (S66) ──
                ..._buildCommunityChallenge(l),

                const SizedBox(height: MintSpacing.xxl),

                // ── Disclaimer ──
                const PulseDisclaimer(),
                const SizedBox(height: MintSpacing.xl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── ACTIVE GOAL RESOLUTION ──

  /// Resolve the user's active goal.
  ///
  /// Priority:
  ///   1. [activeGoalIntentTag] from MintStateProvider (passed in from build)
  ///   2. profile.goalA.type
  ///   3. Default: retirement
  ///
  /// [activeGoalIntentTag] is read once in build() to keep goal-resolution
  /// pure (no context.read inside helper methods).
  _ActiveGoal _resolveActiveGoal(
      CoachProfile profile, String? activeGoalIntentTag) {
    if (activeGoalIntentTag != null) {
      return _intentTagToGoal(activeGoalIntentTag);
    }
    return _goalATypeToGoal(profile.goalA.type);
  }

  _ActiveGoal _intentTagToGoal(String tag) {
    final lower = tag.toLowerCase();
    if (lower.contains('budget') || lower.contains('dette') ||
        lower == 'debt_check' || lower == 'budget_overview' ||
        lower == 'debtfree' || lower == 'debt_free') {
      return _ActiveGoal.budget;
    }
    if (lower.contains('achat') || lower.contains('immo') ||
        lower.contains('housing') || lower == 'housing_purchase' ||
        lower == 'achat_immo') {
      return _ActiveGoal.housing;
    }
    return _ActiveGoal.retirement;
  }

  _ActiveGoal _goalATypeToGoal(GoalAType type) {
    switch (type) {
      case GoalAType.achatImmo:
        return _ActiveGoal.housing;
      case GoalAType.debtFree:
      case GoalAType.retraite:
      case GoalAType.independance:
      case GoalAType.custom:
        // Budget Vivant is the default hero (Architecture Decision 2026-03-22).
        // Retirement is available via goal selector chip.
        return _ActiveGoal.budget;
    }
  }

  // ── DOMINANT NUMBER ──

  _DominantNumber _computeDominantNumber(
      CoachProfile profile,
      MintUserState? mintState,
      String? activeGoalIntentTag) {
    final goal = _resolveActiveGoal(profile, activeGoalIntentTag);

    // ── Budget goal: show monthly free margin ──
    if (goal == _ActiveGoal.budget) {
      // BudgetSnapshot from MintStateEngine — single source of truth.
      final snapshot = mintState?.budgetSnapshot;
      if (snapshot != null) {
        final libre = snapshot.present.monthlyFree;
        return _DominantNumber(
          value: libre,
          format: (v) {
            final prefix = v >= 0 ? '+' : '';
            return '$prefix${formatChf(v.abs())}\u00a0CHF';
          },
          type: _NumberType.chf,
        );
      }
      // Fallback: net minus expenses when snapshot not yet computed.
      final revenuNet = _computeRevenuNet(profile);
      if (revenuNet > 0) {
        final libre = revenuNet - profile.totalDepensesMensuelles;
        return _DominantNumber(
          value: libre,
          format: (v) {
            final prefix = v >= 0 ? '+' : '';
            return '$prefix${formatChf(v.abs())}\u00a0CHF';
          },
          type: _NumberType.chf,
        );
      }
    }

    // ── Housing goal: show purchasing capacity ──
    // ARCH NOTE: AffordabilityCalculator is called locally here because
    // housing affordability capacity is not yet part of MintUserState.
    // It is computed from profile fields synchronously (no async required)
    // and requires FINMA mortgage rules (MortgageService / AffordabilityCalculator).
    // Future: add affordabilityCapacity to MintUserState when housing goal
    // becomes a first-class state dimension in MintStateEngine.
    if (goal == _ActiveGoal.housing) {
      final revenuBrut = profile.salaireBrutMensuel * 12;
      if (revenuBrut > 0) {
        try {
          final result = AffordabilityCalculator.calculate(
            revenuBrutAnnuel: revenuBrut,
            epargneDispo: profile.patrimoine.epargneLiquide,
            avoir3a: profile.prevoyance.totalEpargne3a,
            avoirLpp: profile.prevoyance.avoirLppTotal ?? 0,
            // Use a representative price = max accessible (self-consistent)
            prixAchat: revenuBrut * 5,
            canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
          );
          if (result.prixMaxAccessible > 0) {
            return _DominantNumber(
              value: result.prixMaxAccessible,
              format: (v) => '${formatChfCompact(v)}\u00a0CHF',
              type: _NumberType.chf,
            );
          }
        } catch (_) {
          // Graceful degradation to retirement display below
        }
      }
    }

    // ── Retirement goal (default) — data from MintStateProvider ──
    // replacementRate (%) is the primary metric when we have net income.
    final replacementRate = mintState?.replacementRate;
    if (replacementRate != null) {
      final revenuNet = _computeRevenuNet(profile);
      if (revenuNet > 0) {
        return _DominantNumber(
          value: replacementRate,
          format: (v) => '${v.round()}%',
          type: _NumberType.percentage,
        );
      }
      // No net income — fall back to total monthly retirement income CHF.
      final totalRevenusMensuel = mintState?.budgetGap?.totalRevenusMensuel;
      if (totalRevenusMensuel != null && totalRevenusMensuel > 0) {
        return _DominantNumber(
          value: totalRevenusMensuel,
          format: (v) => '${formatChf(v)}\u00a0CHF',
          type: _NumberType.chf,
        );
      }
    }
    // FRI score as tertiary fallback.
    final friScore = mintState?.friScore;
    if (friScore != null) {
      return _DominantNumber(
        value: friScore,
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

  String _computeDominantLabel(
      CoachProfile profile,
      MintUserState? mintState,
      S l,
      String? activeGoalIntentTag) {
    final goal = _resolveActiveGoal(profile, activeGoalIntentTag);

    if (goal == _ActiveGoal.budget) {
      // Only show budget label if we actually have budget data.
      final snapshot = mintState?.budgetSnapshot;
      final revenuNet = _computeRevenuNet(profile);
      if (snapshot != null || revenuNet > 0) {
        return l.pulseLabelBudgetFree;
      }
    }

    if (goal == _ActiveGoal.housing) {
      final revenuBrut = profile.salaireBrutMensuel * 12;
      if (revenuBrut > 0) {
        return l.pulseLabelPurchasingCapacity;
      }
    }

    // Default: retirement
    final replacementRate = mintState?.replacementRate;
    if (replacementRate != null) {
      final revenuNet = _computeRevenuNet(profile);
      if (revenuNet > 0) {
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
      if (n.value >= 70) return MintColors.success;
      if (n.value >= 40) return MintColors.warning;
      return MintColors.error;
    }
    // CHF: budget margin — full semantic colour spectrum
    if (n.type == _NumberType.chf) {
      if (n.value > 0) return MintColors.success;
      if (n.value < 0) return MintColors.warning;
      return MintColors.textSecondary; // exactly zero = neutral
    }
    return MintColors.textPrimary;
  }

  /// Extract prefix for MintCountUp from the format function.
  String _dominantPrefix(_DominantNumber n) {
    switch (n.type) {
      case _NumberType.chf:
        if (n.value == 0) return '';
        return n.value > 0 ? '+' : '-';
      case _NumberType.percentage:
      case _NumberType.score:
        return '';
    }
  }

  /// Extract suffix for MintCountUp from the format function.
  String _dominantSuffix(_DominantNumber n) {
    switch (n.type) {
      case _NumberType.chf:
        return '\u00a0CHF';
      case _NumberType.percentage:
        return '\u00a0%';
      case _NumberType.score:
        return n.value > 0 ? '/100' : '';
    }
  }

  // ── NARRATIVE ──

  String _computeNarrative(
      CoachProfile profile, CapDecision? cap, S l, String? activeGoalIntentTag) {
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

    // Goal-specific narrative (no active cap): reference the dominant number.
    final goal = _resolveActiveGoal(profile, activeGoalIntentTag);

    if (goal == _ActiveGoal.budget) {
      // Show "ta marge mensuelle :" prefixed with name if available.
      final budgetPhrase = l.pulseNarrativeBudgetGoal;
      return prefix(budgetPhrase);
    }

    if (goal == _ActiveGoal.housing) {
      final housingPhrase = l.pulseNarrativeHousingGoal;
      return prefix(housingPhrase);
    }

    // Retirement goal: show goal-specific phrase when we have projection data,
    // otherwise fall back to time-based narrative.
    // Note: _computeNarrative doesn't receive mintState — reads via the cap
    // path above which already covers the richest narrative. For the fallback,
    // we check replacementRate availability through the caller's mintState.
    // The method intentionally remains signature-stable; the cap whyNow path
    // above supersedes this branch for profiles with data.

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
    return GestureDetector(
      onTap: () => NavigationShellState.switchTab(1),
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.white,
          border: Border.all(
            color: MintColors.border.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: MintColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: MintSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context)!.pulseEmptyCtaStart,
                    style: MintTextStyles.titleMedium(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    S.of(context)!.pulseNarrativeDefault,
                    style: MintTextStyles.bodySmall(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: MintSpacing.sm),
            const Icon(
              Icons.chevron_right_rounded,
              color: MintColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
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

  /// Build a nudge card for a JITAI proactive nudge (S61).
  Widget _buildNudgeCard(Nudge nudge, S l) {
    // Resolve i18n title and body from ARB keys via the nudge's titleKey/bodyKey.
    // Since ARB keys are resolved at compile time, we use a lookup approach.
    final title = _resolveNudgeText(nudge.titleKey, nudge.params, l);
    final body = _resolveNudgeText(nudge.bodyKey, nudge.params, l);

    return MintSurface(
      tone: MintSurfaceTone.sauge,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  size: 18, color: MintColors.primary),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              // Dismiss button — optimistic hide, async persist.
              GestureDetector(
                onTap: () async {
                  if (mounted) {
                    setState(() => _sessionDismissedNudgeIds.add(nudge.id));
                  }
                  final prefs = await SharedPreferences.getInstance();
                  await NudgePersistence.dismiss(nudge.id, nudge.trigger, prefs);
                },
                child: const Icon(Icons.close,
                    size: 16, color: MintColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            body,
            style: MintTextStyles.bodySmall(
              color: MintColors.textSecondary,
            ),
          ),
          if (nudge.intentTag.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.sm),
            GestureDetector(
              onTap: () {
                // Route to coach chat with the intent tag as initial prompt.
                context.push('/coach/chat?prompt=${Uri.encodeComponent(nudge.intentTag)}');
              },
              child: Text(
                l.routeSuggestionCta,
                style: MintTextStyles.labelSmall(
                  color: MintColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Resolve a nudge ARB key to its localized text.
  /// Handles both simple getters and parameterized methods.
  /// Falls back to the key name if not found.
  String _resolveNudgeText(String key, Map<String, String>? params, S l) {
    final p = params ?? {};
    switch (key) {
      // Simple getters
      case 'nudgeSalaryTitle': return l.nudgeSalaryTitle;
      case 'nudgeSalaryBody': return l.nudgeSalaryBody;
      case 'nudgeTaxDeadlineTitle': return l.nudgeTaxDeadlineTitle;
      case 'nudgeTaxDeadlineBody': return l.nudgeTaxDeadlineBody;
      case 'nudge3aDeadlineTitle': return l.nudge3aDeadlineTitle;
      case 'nudgeProfileTitle': return l.nudgeProfileTitle;
      case 'nudgeProfileBody': return l.nudgeProfileBody;
      case 'nudgeInactiveTitle': return l.nudgeInactiveTitle;
      case 'nudgeInactiveBody': return l.nudgeInactiveBody;
      case 'nudgeGoalProgressTitle': return l.nudgeGoalProgressTitle;
      case 'nudgeAnniversaryTitle': return l.nudgeAnniversaryTitle;
      case 'nudgeAnniversaryBody': return l.nudgeAnniversaryBody;
      case 'nudgeLppBuybackTitle': return l.nudgeLppBuybackTitle;
      case 'nudgeNewYearTitle': return l.nudgeNewYearTitle;
      // Parameterized methods
      case 'nudgeBirthdayTitle': return l.nudgeBirthdayTitle(p['age'] ?? '');
      case 'nudgeBirthdayBody': return l.nudgeBirthdayBody;
      case 'nudge3aDeadlineBody':
        return l.nudge3aDeadlineBody(
          p['days'] ?? '', p['limit'] ?? '', p['year'] ?? '');
      case 'nudgeGoalProgressBody':
        return l.nudgeGoalProgressBody(p['progress'] ?? '');
      case 'nudgeLppBuybackBody':
        return l.nudgeLppBuybackBody(p['year'] ?? '');
      case 'nudgeNewYearBody':
        return l.nudgeNewYearBody(p['year'] ?? '');
      default: return key;
    }
  }

  // ── SEASONAL EVENT CARD (S66) ─────────────────────────────────

  /// Returns a list with a spacing + card widget if an event is active,
  /// or an empty list for clean spread-operator insertion.
  List<Widget> _buildSeasonalEventCard(S l) {
    final events = SeasonalEventService.activeEvents(now: DateTime.now());
    if (events.isEmpty) return const [];

    final event = events.first;
    final String title;
    final String description;

    switch (event.titleKey) {
      case 'seasonalTaxSeasonTitle':
        title = l.seasonalTaxSeasonTitle;
        description = l.seasonalTaxSeasonDesc;
        break;
      case 'seasonal3aCountdownTitle':
        title = l.seasonal3aCountdownTitle;
        description = l.seasonal3aCountdownDesc;
        break;
      case 'seasonalNewYearResolutionsTitle':
        title = l.seasonalNewYearResolutionsTitle;
        description = l.seasonalNewYearResolutionsDesc;
        break;
      case 'seasonalMidYearReviewTitle':
        title = l.seasonalMidYearReviewTitle;
        description = l.seasonalMidYearReviewDesc;
        break;
      case 'seasonalRetirementMonthTitle':
        title = l.seasonalRetirementMonthTitle;
        description = l.seasonalRetirementMonthDesc;
        break;
      default:
        return const [];
    }

    return [
      const SizedBox(height: MintSpacing.xl),
      MintSurface(
        tone: MintSurfaceTone.peche,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_outlined,
                    size: 16, color: MintColors.textPrimary),
                const SizedBox(width: MintSpacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              description,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ),
            ),
            if (event.intentTag != null && event.intentTag!.isNotEmpty) ...[
              const SizedBox(height: MintSpacing.sm),
              GestureDetector(
                onTap: () {
                  context.push(
                    '/coach/chat?prompt=${Uri.encodeComponent(event.intentTag!)}',
                  );
                },
                child: Text(
                  l.seasonalEventCta,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  // ── COMMUNITY CHALLENGE CARD (S66) ───────────────────────────

  /// Returns a list with a spacing + card widget for the current month's
  /// community challenge, or an empty list if none found.
  List<Widget> _buildCommunityChallenge(S l) {
    final challenge = CommunityChallengeService.currentChallenge(
      now: DateTime.now(),
    );
    if (challenge == null) return const [];

    final String title;
    final String description;

    switch (challenge.titleKey) {
      case 'communityChallenge01Title': title = l.communityChallenge01Title; description = l.communityChallenge01Desc; break;
      case 'communityChallenge02Title': title = l.communityChallenge02Title; description = l.communityChallenge02Desc; break;
      case 'communityChallenge03Title': title = l.communityChallenge03Title; description = l.communityChallenge03Desc; break;
      case 'communityChallenge04Title': title = l.communityChallenge04Title; description = l.communityChallenge04Desc; break;
      case 'communityChallenge05Title': title = l.communityChallenge05Title; description = l.communityChallenge05Desc; break;
      case 'communityChallenge06Title': title = l.communityChallenge06Title; description = l.communityChallenge06Desc; break;
      case 'communityChallenge07Title': title = l.communityChallenge07Title; description = l.communityChallenge07Desc; break;
      case 'communityChallenge08Title': title = l.communityChallenge08Title; description = l.communityChallenge08Desc; break;
      case 'communityChallenge09Title': title = l.communityChallenge09Title; description = l.communityChallenge09Desc; break;
      case 'communityChallenge10Title': title = l.communityChallenge10Title; description = l.communityChallenge10Desc; break;
      case 'communityChallenge11Title': title = l.communityChallenge11Title; description = l.communityChallenge11Desc; break;
      case 'communityChallenge12Title': title = l.communityChallenge12Title; description = l.communityChallenge12Desc; break;
      default: return const [];
    }

    return [
      const SizedBox(height: MintSpacing.xl),
      MintSurface(
        tone: MintSurfaceTone.sauge,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined,
                    size: 16, color: MintColors.textPrimary),
                const SizedBox(width: MintSpacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              description,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: MintSpacing.sm),
            GestureDetector(
              onTap: () {
                final intent = challenge.intentTag;
                final prompt = intent != null && intent.isNotEmpty
                    ? intent
                    : challenge.titleKey;
                context.push(
                  '/coach/chat?prompt=${Uri.encodeComponent(prompt)}',
                );
              },
              child: Text(
                l.communityChallengeCta,
                style: MintTextStyles.labelSmall(
                  color: MintColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildSecondarySignals(
      CoachProfile profile, MintUserState? mintState, S l) {
    final signals = <Widget>[];

    // Signal 1: Budget libre — source of truth is BudgetSnapshot.present.monthlyFree.
    // Falls back to legacy estimate when snapshot is unavailable.
    final snapshot = mintState?.budgetSnapshot;
    if (snapshot != null) {
      final libre = snapshot.present.monthlyFree;
      signals.add(_SignalRow(
        label: l.pulseKeyFigBudgetLibre,
        value: libre >= 0
            ? l.pulseAmountPerMonth('+${formatChfWithPrefix(libre)}')
            : l.pulseAmountPerMonth(formatChfWithPrefix(libre)),
        color: libre >= 0 ? MintColors.success : MintColors.warning,
        onTap: () => context.push('/budget'),
      ));
    } else {
      // Legacy fallback: net income minus declared expenses.
      final revenuNet = _computeRevenuNet(profile);
      if (revenuNet > 0) {
        final dep = profile.totalDepensesMensuelles;
        final libre = revenuNet - dep;
        signals.add(_SignalRow(
          label: l.pulseKeyFigBudgetLibre,
          value: libre >= 0
              ? '+${formatChfWithPrefix(libre)}/mois'
              : '${formatChfWithPrefix(libre)}/mois',
          color: libre >= 0 ? MintColors.success : MintColors.warning,
          onTap: () => context.push('/budget'),
        ));
      }
    }

    // Signal 2: Retirement income — ONLY when fullGapVisible
    if (snapshot != null && snapshot.hasFullGap) {
      final retirementNet = snapshot.retirement!.monthlyNet;
      final rate = snapshot.gap!.replacementRate;
      final isEstimated = profile.prevoyance.isLppEstimated;
      signals.add(_SignalRow(
        label: isEstimated
            ? l.pulseRetirementIncomeEstimated
            : l.pulseRetirementIncome,
        value: l.pulseAmountPerMonth(formatChfWithPrefix(retirementNet)),
        color: rate >= 80 ? MintColors.success : MintColors.warning,
        onTap: () => isEstimated
            ? context.push('/scan')
            : context.push('/retirement'),
      ));
    }

    // Signal 3: Top cap impact — ONLY when capImpacts is non-empty
    if (snapshot != null && snapshot.capImpacts.isNotEmpty) {
      final topCap = snapshot.capImpacts.first;
      signals.add(_SignalRow(
        label: l.pulseCapImpact,
        value: l.pulseAmountPerMonth('+${formatChfWithPrefix(topCap.monthlyDelta)}'),
        color: MintColors.accent,
        onTap: () => context.push('/coach/chat'),
      ));
    }

    // Signal 4: Patrimoine
    final patrimoine = profile.patrimoine.totalPatrimoine +
        (profile.prevoyance.avoirLppTotal ?? 0) +
        profile.prevoyance.totalEpargne3a;
    if (patrimoine > 0) {
      signals.add(_SignalRow(
        label: l.pulseKeyFigPatrimoine,
        value: formatChfCompact(patrimoine),
        color: MintColors.textPrimary,
        onTap: () => context.push('/profile/bilan'),
      ));
    }

    if (signals.isEmpty) return const SizedBox.shrink();

    // Show up to 3 signals (budget libre + retirement + cap impact or patrimoine)
    const maxSignals = 3;
    return Column(
      children: [
        for (int i = 0; i < signals.length && i < maxSignals; i++) ...[
          signals[i],
          if (i < signals.length - 1 && i < maxSignals - 1)
            Divider(
              color: MintColors.border.withValues(alpha: 0.5),
              height: 1,
            ),
        ],
      ],
    );
  }

  // ── APP BAR (Pulse exception: gradient) ──

  SliverAppBar _buildAppBar(BuildContext context, CoachProfile profile) {
    final l = S.of(context)!;
    final firstName = profile.firstName ?? '';
    final greeting =
        firstName.isNotEmpty ? l.pulseGreeting(firstName) : l.tabToday;

    return SliverAppBar(
      floating: false,
      pinned: true,
      backgroundColor: MintColors.primary,
      surfaceTintColor: MintColors.primary,
      title: Text(
        greeting,
        style: MintTextStyles.titleMedium(color: MintColors.white)
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
                icon: const Icon(Icons.people_outline, color: MintColors.white),
                onPressed: () => context.push('/couple'),
              ),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MintColors.primary, MintColors.primaryLight],
            ),
          ),
        ),
      ),
    );
  }

  // ── EMPTY STATE ──

  Widget _buildEmptyState(BuildContext context) {
    final l = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.white,
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

  /// Compute monthly net income from gross salary.
  ///
  /// ARCH NOTE: This method is used only as a fallback when
  /// [MintUserState.budgetSnapshot] is null (e.g. MintStateProvider not yet
  /// computed, or profile lacking sufficient data for BudgetLivingEngine).
  /// Primary source of truth is [MintUserState.budgetSnapshot.present.monthlyNet].
  /// See: BudgetLivingEngine.compute() and MintStateEngine step 6e.
  double _computeRevenuNet(CoachProfile profile) {
    if (profile.salaireBrutMensuel <= 0) return 0.0;
    return NetIncomeBreakdown.compute(
      grossSalary: profile.salaireBrutMensuel * 12,
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      age: profile.age,
    ).monthlyNetPayslip;
  }

  // ── GOAL CHIP ────────────────────────────────────────────────────────────

  Widget _buildGoalChip(
    BuildContext context,
    CoachProfile profile,
    S l,
    String? activeGoalIntentTag,
  ) {
    final goals = GoalSelectionService.availableGoals(profile, l);
    final String goalLabel;
    if (_selectedGoalTag != null) {
      final match =
          goals.where((g) => g.intentTag == _selectedGoalTag).toList();
      goalLabel = match.isNotEmpty
          ? GoalSelectionService.resolveTitle(match.first.titleKey, l)
          : l.goalSelectorAuto;
    } else {
      goalLabel = l.goalSelectorAuto;
    }
    final chipText = l.pulseGoalChip(goalLabel);
    return Semantics(
      label: chipText,
      button: true,
      child: GestureDetector(
        onTap: () => showGoalSelectorSheet(
          context,
          profile: profile,
          currentIntentTag: _selectedGoalTag,
          onSelected: (intentTag) {
            setState(() => _selectedGoalTag = intentTag);
            try {
              context.read<MintStateProvider>().forceRecompute(profile);
            } catch (_) {}
          },
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: MintColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: MintColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chipText,
                style: MintTextStyles.labelSmall(
                  color: MintColors.primary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: MintColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PLAN PROGRESS SECTION (compact CapSequence strip) ──
//
//  Minimal, calm progress indicator — Swiss-watch simplicity.
//
//  Layout:
//    ┌──────────────────────────────────────┐
//    │  Mon plan                      3/10  │
//    │  [═══════░░░░░░░░░░░░░░░░░░░] 30%   │
//    │  Prochaine étape : Vérifier AVS      │
//    └──────────────────────────────────────┘
//
//  Tap → coach chat with current step as prompt.
//  ONLY rendered when capSequencePlan != null && totalCount > 0.

class _PlanProgressSection extends StatelessWidget {
  final CapSequence sequence;

  const _PlanProgressSection({required this.sequence});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final currentStep = sequence.currentStep;
    final stepTitle = currentStep != null
        ? resolveCapStepTitle(currentStep.titleKey, l) ?? currentStep.titleKey
        : null;

    return Semantics(
      label: '${l.pulsePlanTitle}\u00a0: '
          '${l.pulsePlanProgress(sequence.completedCount, sequence.totalCount)}',
      button: currentStep != null,
      child: GestureDetector(
        onTap: currentStep != null
            ? () {
                final prompt = stepTitle ?? currentStep.titleKey;
                context.push(
                  '/coach/chat?prompt=${Uri.encodeComponent(prompt)}',
                );
              }
            : null,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header: "Mon plan" + "3/10" ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.pulsePlanTitle,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary,
                  ),
                ),
                Text(
                  l.pulsePlanProgress(
                    sequence.completedCount,
                    sequence.totalCount,
                  ),
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: MintSpacing.xs),

            // ── Thin progress bar (3px, rounded) ──
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: sequence.progressPercent,
                backgroundColor: MintColors.lightBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  MintColors.primary,
                ),
                minHeight: 3,
              ),
            ),

            // ── Next step label ──
            if (stepTitle != null) ...[
              const SizedBox(height: MintSpacing.sm),
              Text(
                l.pulsePlanNextStep(stepTitle),
                style: MintTextStyles.bodySmall(
                  color: MintColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── SIGNAL ROW ──

class _SignalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _SignalRow({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: MintSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: MintTextStyles.bodyMedium(),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: MintTextStyles.titleMedium(color: color)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: MintColors.textMuted,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
