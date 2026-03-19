import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/pulse_hero_engine.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/pulse/pulse_disclaimer.dart';
import 'package:mint_mobile/services/response_card_service.dart';

// ────────────────────────────────────────────────────────
//  AUJOURD'HUI — V4 "Radical Simplicity"
// ────────────────────────────────────────────────────────
//
//  Contrat UX (NAVIGATION_GRAAL_V10.md) :
//  - 1 phrase personnalisée
//  - 1 chiffre dominant (displayLarge)
//  - 1 action prioritaire
//  - 2 signaux secondaires max
//  - Rien d'autre au-dessus du fold
//
//  Removed from V3:
//  - FocusSelector 2×2 grid (pattern interdit)
//  - CircularProgressIndicator (pattern interdit)
//  - Enrichir section (moved to Dossier)
//  - Heavy gradient hero card
//  - Action signal badge
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<CoachProfileProvider>();
    if (!provider.hasProfile) {
      if (_lastProfile != null) {
        _lastProfile = null;
        _cachedProjection = null;
        _cachedFri = null;
      }
      return;
    }

    final profile = provider.profile!;
    if (_lastProfile == profile) return;
    _lastProfile = profile;

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

  // ── BUILD ──

  @override
  Widget build(BuildContext context) {
    final coachProvider = context.watch<CoachProfileProvider>();

    if (!coachProvider.hasProfile) {
      return _buildEmptyState(context);
    }

    final profile = coachProvider.profile!;
    final hero = PulseHeroEngine.compute(profile);
    final l = S.of(context)!;

    // Compute the dominant number
    final dominantNumber = _computeDominantNumber(profile);
    final dominantLabel = _computeDominantLabel(profile, l);
    final dominantColor = _computeDominantColor(dominantNumber);
    final narrativePhrase = _computeNarrative(profile, hero, l);

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

                // ── 3. ACTION PRIORITAIRE ──
                _buildPriorityAction(profile, hero),

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
    // Priority: replacement rate > FHS score > retirement estimate
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

  String _computeNarrative(CoachProfile profile, PulseHero? hero, S l) {
    final firstName = profile.firstName;
    final yearsToRetire = profile.effectiveRetirementAge - profile.age;
    final hasName = firstName != null && firstName.trim().isNotEmpty;

    // Prefix with name if available
    String prefix(String msg) => hasName ? '$firstName, $msg' : msg;

    if (hero != null && hero.subtitle.isNotEmpty) {
      return hasName
          ? '$firstName, ${hero.subtitle[0].toLowerCase()}${hero.subtitle.substring(1)}'
          : hero.subtitle;
    }
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

  // ── PRIORITY ACTION ──

  Widget _buildPriorityAction(CoachProfile profile, PulseHero? hero) {
    // Try response card first (most contextual) — render as minimal action card
    final cards = ResponseCardService.generateForPulse(profile, limit: 1);
    if (cards.isNotEmpty) {
      final card = cards.first;
      return _buildMinimalActionCard(
        title: card.title,
        subtitle: card.subtitle,
        icon: Icons.arrow_forward_rounded,
        onTap: () => context.push(card.cta.route),
      );
    }

    // Fallback to hero CTA
    if (hero != null) {
      return _buildMinimalActionCard(
        title: hero.ctaLabel,
        subtitle: 'Le prochain levier',
        icon: Icons.arrow_forward_rounded,
        onTap: () => context.push(hero.ctaRoute),
      );
    }

    // Last resort: go to coach
    return _buildMinimalActionCard(
      title: S.of(context)!.pulseEmptyCtaStart,
      subtitle: 'On peut commencer ici',
      icon: Icons.arrow_forward_rounded,
      onTap: () => NavigationShellState.switchTab(1),
    );
  }

  Widget _buildMinimalActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
              child: Icon(
                icon,
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
                    title,
                    style: MintTextStyles.titleMedium(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
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
        // Couple switcher
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
