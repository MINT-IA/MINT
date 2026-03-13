import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/pulse_hero_engine.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/pulse/focus_selector.dart';
import 'package:mint_mobile/widgets/pulse/pulse_disclaimer.dart';

// ────────────────────────────────────────────────────────
//  PULSE SCREEN — V3 "Le Thermomètre"
// ────────────────────────────────────────────────────────
//
//  1 hero adaptatif + 3 pastilles + 1 score de préparation
//  + 1 signal action
//
//  Propriété exclusive de Pulse :
//  - Le hero adaptatif (PulseHeroEngine)
//  - Le delta temporel (vs dernier check-in)
//  - Les 3 pastilles (retraite, budget, patrimoine)
//  - Le score de préparation (FRI compact)
//
//  Tout le reste vit ailleurs :
//  - Actions → Agir tab
//  - Enrichment/Data quality → Profil tab
//  - Coach insight → Agir tab
//  - Couple détail → Profil tab
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

  // ────────────────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final coachProvider = context.watch<CoachProfileProvider>();

    if (!coachProvider.hasProfile) {
      return _buildEmptyState(context);
    }

    final profile = coachProvider.profile!;
    final hero = PulseHeroEngine.compute(profile);

    return CustomScrollView(
      slivers: [
        _buildAppBar(context, profile),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Hero card OR FocusSelector
                if (hero != null)
                  _HeroCard(
                    hero: hero,
                    onChangeFocus: () => _showFocusPicker(context, profile),
                  )
                else
                  FocusSelector(
                    profile: profile,
                    onFocusSelected: (focus) => _setFocus(context, focus),
                  ),
                const SizedBox(height: 20),

                // 3 pastilles
                _buildPastilles(profile),
                const SizedBox(height: 20),

                // Score de préparation (FRI compact)
                _buildReadinessScore(profile),
                const SizedBox(height: 16),

                // Action signal → Agir
                _buildActionSignal(profile),
                const SizedBox(height: 20),

                // Disclaimer (1 line)
                const PulseDisclaimer(),
                const SizedBox(height: 80), // FAB clearance
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  //  3 PASTILLES
  // ────────────────────────────────────────────────────────

  Widget _buildPastilles(CoachProfile profile) {
    final l = S.of(context)!;

    // Retirement
    double? retraiteEstimee;
    double? tauxRemplacement;
    if (_cachedProjection != null) {
      retraiteEstimee = _cachedProjection!.base.revenuAnnuelRetraite / 12;
      final revenuActuel = _computeRevenuNet(profile);
      if (revenuActuel > 0) {
        tauxRemplacement = (retraiteEstimee / revenuActuel * 100);
      }
    }

    // Budget libre
    final depMensuelles = profile.totalDepensesMensuelles;
    final revenuNet = _computeRevenuNet(profile);
    final budgetLibre = revenuNet - depMensuelles;

    // Patrimoine total
    final patrimoine = profile.patrimoine.totalPatrimoine +
        (profile.prevoyance.avoirLppTotal ?? 0) +
        profile.prevoyance.totalEpargne3a;

    return Row(
      children: [
        Expanded(
          child: _PastilleCard(
            label: l.pulseKeyFigRetraite,
            value: retraiteEstimee != null
                ? formatChfWithPrefix(retraiteEstimee)
                : '\u2014',
            subtitle: tauxRemplacement != null
                ? l.pulseKeyFigRetraitePct('${tauxRemplacement.round()}')
                : null,
            icon: Icons.beach_access_outlined,
            color: MintColors.primary,
            onTap: () => context.push('/retirement'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PastilleCard(
            label: l.pulseKeyFigBudgetLibre,
            value: budgetLibre > 0
                ? '+${formatChfWithPrefix(budgetLibre)}'
                : formatChfWithPrefix(budgetLibre),
            icon: Icons.account_balance_wallet_outlined,
            color: budgetLibre >= 0 ? MintColors.success : MintColors.warning,
            onTap: () => context.push('/budget'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PastilleCard(
            label: l.pulseKeyFigPatrimoine,
            value: formatChfCompact(patrimoine),
            icon: Icons.trending_up_outlined,
            color: MintColors.info,
            onTap: () => context.push('/profile/bilan'),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  //  SCORE DE PRÉPARATION (FRI compact)
  // ────────────────────────────────────────────────────────

  Widget _buildReadinessScore(CoachProfile profile) {
    final fri = _cachedFri;
    if (fri == null) return const SizedBox.shrink();

    final score = fri.global;
    final color = score >= 70
        ? MintColors.success
        : score >= 40
            ? MintColors.warning
            : MintColors.error;
    final l = S.of(context)!;
    final label = score >= 70
        ? l.pulseReadinessGood
        : score >= 40
            ? l.pulseReadinessProgress
            : l.pulseReadinessWeak;

    return GestureDetector(
      onTap: () => context.push('/coach/cockpit'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Circular score indicator
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 4,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Text(
                    '${score.round()}',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.pulseReadinessTitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$label · ${_readinessDetail(profile)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: MintColors.textMuted),
          ],
        ),
      ),
    );
  }

  String _readinessDetail(CoachProfile profile) {
    final l = S.of(context)!;
    final age = profile.age;
    final yearsToRetire = profile.effectiveRetirementAge - age;
    if (yearsToRetire <= 5) return l.pulseReadinessRetireIn(yearsToRetire);
    if (yearsToRetire <= 15) return l.pulseReadinessYearsToAct(yearsToRetire);
    return l.pulseReadinessActNow;
  }

  // ────────────────────────────────────────────────────────
  //  ACTION SIGNAL → Agir tab
  // ────────────────────────────────────────────────────────

  Widget _buildActionSignal(CoachProfile profile) {
    int urgentCount;
    try {
      final tips = CoachingService.generateTips(
        profile: profile.toCoachingProfile(),
      );
      urgentCount = tips
          .where((t) => t.priority == CoachingPriority.haute)
          .length;
    } catch (_) {
      urgentCount = 0;
    }

    if (urgentCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        // Navigate to Agir tab (index 1) via shell
        NavigationShellState.switchTab(1);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: MintColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MintColors.error.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: MintColors.error,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$urgentCount',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MintColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                urgentCount == 1
                    ? S.of(context)!.pulseActionSignalSingular
                    : S.of(context)!.pulseActionSignalPlural('$urgentCount'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_rounded,
                size: 18, color: MintColors.error),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  //  HELPERS
  // ────────────────────────────────────────────────────────

  double _computeRevenuNet(CoachProfile profile) {
    if (profile.salaireBrutMensuel <= 0) return 0.0;
    return NetIncomeBreakdown.compute(
      grossSalary: profile.salaireBrutMensuel * 12,
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      age: DateTime.now().year - profile.birthYear,
    ).monthlyNetPayslip;
  }

  // ────────────────────────────────────────────────────────
  //  FOCUS PICKER
  // ────────────────────────────────────────────────────────

  void _showFocusPicker(BuildContext context, CoachProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MintColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 32),
                child: FocusSelector(
                  profile: profile,
                  onFocusSelected: (focus) {
                    Navigator.of(ctx).pop();
                    _setFocus(context, focus);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _setFocus(BuildContext context, String focus) {
    context.read<CoachProfileProvider>().updatePrimaryFocus(focus);
  }

  // ────────────────────────────────────────────────────────
  //  APP BAR
  // ────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(BuildContext context, CoachProfile profile) {
    final l = S.of(context)!;
    final firstName = profile.firstName ?? 'toi';
    final greeting = profile.isCouple && profile.conjoint?.firstName != null
        ? l.pulseGreetingCouple(firstName, profile.conjoint!.firstName!)
        : l.pulseGreeting(firstName);

    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: MintColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Text(
          greeting,
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: MintColors.white,
          ),
        ),
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

  // ────────────────────────────────────────────────────────
  //  EMPTY STATE
  // ────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final l = S.of(context)!;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 100,
          floating: false,
          pinned: true,
          backgroundColor: MintColors.primary,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
            title: Text(
              l.pulseWelcome,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: MintColors.white,
              ),
            ),
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
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 64,
                    color: MintColors.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l.pulseEmptyTitle,
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.pulseEmptySubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => context.push('/onboarding/quick'),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(l.pulseEmptyCtaStart),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      foregroundColor: MintColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const PulseDisclaimer(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────
//  HERO CARD — Adaptive, focus-driven
// ────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final PulseHero hero;
  final VoidCallback onChangeFocus;

  const _HeroCard({required this.hero, required this.onChangeFocus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hero.color, hero.color.withValues(alpha: 0.85)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: hero.color.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(hero.icon,
                  size: 22, color: MintColors.white.withValues(alpha: 0.9)),
              const Spacer(),
              GestureDetector(
                onTap: onChangeFocus,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: MintColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded,
                          size: 14,
                          color: MintColors.white.withValues(alpha: 0.9)),
                      const SizedBox(width: 4),
                      Text(
                        S.of(context)!.pulseHeroChangeBtn,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: MintColors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hero.title,
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: MintColors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hero.subtitle,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: MintColors.white.withValues(alpha: 0.9),
              height: 1.3,
            ),
          ),
          if (hero.detail != null) ...[
            const SizedBox(height: 8),
            Text(
              hero.detail!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.white.withValues(alpha: 0.7),
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.push(hero.ctaRoute),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: MintColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hero.ctaLabel,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hero.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
//  PASTILLE CARD (compact key figure)
// ────────────────────────────────────────────────────────

class _PastilleCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _PastilleCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: MintColors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
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

// ────────────────────────────────────────────────────────
//  NAVIGATION SHELL STATE (for tab switching)
// ────────────────────────────────────────────────────────

/// Mixin interface for the MainNavigationShell to allow child
/// tabs to programmatically switch tabs via ancestor lookup.
/// Callback for tab switching — set by MainNavigationShell.
class NavigationShellState {
  NavigationShellState._();
  static void Function(int index)? _switchTab;

  /// Register the tab switcher (called by MainNavigationShell).
  static void register(void Function(int index) callback) {
    _switchTab = callback;
  }

  /// Unregister the callback (called in MainNavigationShell.dispose).
  static void unregister() {
    _switchTab = null;
  }

  /// Switch to a specific tab index.
  static void switchTab(int index) {
    _switchTab?.call(index);
  }
}
