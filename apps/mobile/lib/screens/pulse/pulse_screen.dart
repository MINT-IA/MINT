import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/cap_engine.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/pulse/cap_card.dart';
import 'package:mint_mobile/widgets/pulse/pulse_disclaimer.dart';

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
  ProjectionResult? _cachedProjection;
  FinancialFitnessScore? _cachedFri;
  CoachProfile? _lastProfile;

  /// CapEngine memory — loaded async on first build.
  CapMemory _capMemory = const CapMemory();
  bool _capMemoryLoaded = false;

  /// The current cap decision. Recomputed when profile changes.
  CapDecision? _cachedCap;

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

    // Load CapMemory once
    if (!_capMemoryLoaded) {
      _capMemoryLoaded = true;
      CapMemoryStore.load().then((mem) {
        if (mounted) {
          setState(() => _capMemory = mem);
          _recomputeCap(profile);
        }
      });
    }

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

    _recomputeCap(profile);
  }

  void _recomputeCap(CoachProfile profile) {
    try {
      final cap = CapEngine.compute(
        profile: profile,
        now: DateTime.now(),
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

  // ── BUILD ──

  @override
  Widget build(BuildContext context) {
    final coachProvider = context.watch<CoachProfileProvider>();

    if (!coachProvider.hasProfile) {
      return _buildEmptyState(context);
    }

    final profile = coachProvider.profile!;
    final cap = _cachedCap;
    final l = S.of(context)!;

    // Compute the dominant number
    final dominantNumber = _computeDominantNumber(profile);
    final dominantLabel = _computeDominantLabel(profile, l);
    final dominantColor = _computeDominantColor(dominantNumber);
    final narrativePhrase = _computeNarrative(profile, cap, l);

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

                // ── 1. PHRASE PERSONNALISÉE ──
                Text(
                  narrativePhrase,
                  style: MintTextStyles.bodyLarge(
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── 2. CHIFFRE DOMINANT ──
                TweenAnimationBuilder<double>(
                  tween: Tween(end: dominantNumber.value),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => Text(
                    dominantNumber.format(value),
                    style: MintTextStyles.displayLarge(
                      color: dominantColor,
                    ),
                  ),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  dominantLabel,
                  style: MintTextStyles.bodySmall(),
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

                const SizedBox(height: MintSpacing.xl),

                // ── 4. DEUX SIGNAUX SECONDAIRES ──
                _buildSecondarySignals(profile, l),

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

  // ── DOMINANT NUMBER ──

  _DominantNumber _computeDominantNumber(CoachProfile profile) {
    if (_cachedProjection != null) {
      final retraite = _cachedProjection!.base.revenuAnnuelRetraite / 12;
      final revenuNet = _computeRevenuNet(profile);
      if (revenuNet > 0) {
        final taux = (retraite / revenuNet * 100);
        return _DominantNumber(
          value: taux,
          format: (v) => '${v.round()}%',
          type: _NumberType.percentage,
        );
      }
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
    if (_cachedProjection != null) {
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

  Widget _buildSecondarySignals(CoachProfile profile, S l) {
    final signals = <Widget>[];

    // Signal 1: Budget libre
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

    // Signal 2: Patrimoine
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

    return Column(
      children: [
        for (int i = 0; i < signals.length && i < 2; i++) ...[
          signals[i],
          if (i < signals.length - 1 && i < 1)
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
        style: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: MintColors.white,
        ),
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
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
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
