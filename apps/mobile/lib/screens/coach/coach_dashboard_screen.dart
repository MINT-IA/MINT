import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/widgets/coach/mint_score_gauge.dart';
import 'package:mint_mobile/widgets/coach/mint_trajectory_chart.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/benchmark_service.dart';
import 'package:mint_mobile/services/streak_service.dart';
import 'package:mint_mobile/services/subscription_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/coach/chiffre_choc_card.dart';
import 'package:mint_mobile/widgets/coach/benchmark_card.dart';
import 'package:mint_mobile/widgets/coach/coach_helpers.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  COACH DASHBOARD SCREEN — Sprint C5 / MINT Coach
// ────────────────────────────────────────────────────────────
//
// Ecran principal du MINT Coach — premiere chose que l'utilisateur voit.
//
// DEUX ETATS :
//
// A) Profil existe (wizard complete) — dashboard complet :
//   1. SliverAppBar — "Bonjour {firstName}"
//   2. Coach Alert Card — message contextuel du coach
//   3. MintScoreGauge — Financial Fitness Score
//   4. MintTrajectoryChart — projection a 3 scenarios
//   5. Quick Actions — check-in, 3a, rachat LPP
//   + Disclaimer legal en bas
//
// B) Pas de profil (utilisateur curieux, "Je veux juste explorer") :
//   1. SliverAppBar — "Bienvenue"
//   2. Empty Score Card — jauge grisee avec "?"
//   3. Teaser Trajectory — graphique floute avec overlay
//   4. Quick Win Cards — faits educatifs avec liens
//   5. Motivation banner — incitation a completer le diagnostic
//   + Disclaimer legal en bas
//
// Toutes les donnees sont calculees localement via les services.
// Aucun appel reseau.
// Tous les textes en francais (informel "tu").
// Aucun terme banni (pas de "garanti", "certain", "optimal", etc.).
// ────────────────────────────────────────────────────────────

class CoachDashboardScreen extends StatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

enum _DashboardResetAction { resetHistory, resetDiagnostic }

class _CoachDashboardScreenState extends State<CoachDashboardScreen>
    with SingleTickerProviderStateMixin {
  CoachProfile? _profile;
  FinancialFitnessScore? _score;
  ProjectionResult? _projection;
  ProjectionResult? _baselineProjection; // projection sans contributions
  List<CoachingTip> _coachingTips = [];
  List<Map<String, dynamic>>? _scoreHistory;
  Map<String, dynamic> _onboarding30PlanState = const {};
  bool _onboarding30PlanLoaded = false;

  // "Et si..." state
  bool _etSiExpanded = false;
  double _etSiLppReturn = 0.02; // base default
  double _etSiThreeAReturn = 0.045; // base default
  double _etSiInvestReturn = 0.06; // base default
  double _etSiInflation = 0.015; // base default
  ProjectionResult? _etSiProjection;

  // Animation controller for the empty state pulsing glow
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    unawaited(_loadOnboarding30PlanState());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_loadOnboarding30PlanState());
    final coachProvider = context.watch<CoachProfileProvider>();

    // BUG FIX: Ne plus utiliser CoachProfile.buildDemo() comme fallback.
    // Si le wizard n'a pas ete complete, on affiche l'etat vide
    // (utilisateur curieux) au lieu de fausses donnees demo.
    if (coachProvider.hasProfile) {
      final newProfile = coachProvider.profile!;
      if (_profile != newProfile) {
        _profile = newProfile;
        _etSiProjection = null; // Reset "Et si..." on profile change
        _score = FinancialFitnessService.calculate(
          profile: _profile!,
          previousScore: coachProvider.previousScore,
        );
        _projection = ForecasterService.project(
          profile: _profile!,
          targetDate: _profile!.goalA.targetDate,
        );

        // Projection baseline (sans contributions) pour "Now vs With MINT"
        if (_profile!.plannedContributions.isNotEmpty) {
          final profileSans = _profile!.copyWithContributions(const []);
          _baselineProjection = ForecasterService.project(
            profile: profileSans,
            targetDate: _profile!.goalA.targetDate,
          );
        } else {
          _baselineProjection = null;
        }

        // Coaching tips caches (evite le recalcul a chaque rebuild)
        _coachingTips = CoachingService.generateTips(
          profile: _profile!.toCoachingProfile(),
        );
      }
      // Charger l'historique des scores depuis le provider
      _scoreHistory = coachProvider.scoreHistory;
    } else {
      _profile = null;
      _score = null;
      _projection = null;
      _baselineProjection = null;
      _coachingTips = [];
      _scoreHistory = null;
    }
  }

  Future<void> _loadOnboarding30PlanState() async {
    final state = await ReportPersistenceService.loadOnboarding30PlanState();
    if (!mounted) return;
    setState(() {
      _onboarding30PlanState = state;
      _onboarding30PlanLoaded = true;
    });
  }

  bool _hasOnboarding30PlanToResume() {
    if (!_onboarding30PlanLoaded) return false;
    final startedAt = _onboarding30PlanState['started_at'];
    final completed = _onboarding30PlanState['completed'] == true;
    return startedAt != null && !completed;
  }

  int _onboarding30OpenedCount() {
    final opened = _onboarding30PlanState['opened_routes'];
    if (opened is List) return opened.length;
    return 0;
  }

  String _onboarding30ResumeRoute() {
    final lastRoute = _onboarding30PlanState['last_route'];
    if (lastRoute is String && lastRoute.isNotEmpty) return lastRoute;
    return '/advisor/plan-30-days';
  }

  Widget _buildResumePlan30Card() {
    if (!_hasOnboarding30PlanToResume()) return const SizedBox.shrink();
    final openedCount = _onboarding30OpenedCount();
    final progress = (openedCount / 3).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_repeat_rounded,
                  size: 18,
                  color: MintColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reprendre mon plan 30 jours',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: MintColors.lightBorder,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(MintColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$openedCount/3 etapes ouvertes',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final route = _onboarding30ResumeRoute();
                await context.push(route);
                if (!mounted) return;
                await _loadOnboarding30PlanState();
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Continuer'),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coachProvider = context.watch<CoachProfileProvider>();

    // Loading state — provider hasn't finished loading yet
    if (coachProvider.isLoading || !coachProvider.isLoaded) {
      return const Scaffold(
        backgroundColor: MintColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ── ETAT C : Utilisateur curieux (pas de profil) ──
    if (!coachProvider.hasProfile) {
      return _buildEmptyDashboard();
    }

    // ── ETAT B : Profil partiel (mini-onboarding) ──
    if (coachProvider.isPartialProfile) {
      return _buildPartialDashboard();
    }

    // ── ETAT A : Dashboard complet (profil existe) ──
    if (_profile == null || _score == null || _projection == null) {
      return const Scaffold(
        backgroundColor: MintColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildCoachAlertCard(),
                const SizedBox(height: 24),
                _buildResumePlan30Card(),
                if (_hasOnboarding30PlanToResume()) const SizedBox(height: 24),
                _buildScoreSection(),
                _buildScoreHistorySection(),
                const SizedBox(height: 24),
                _buildNowVsWithCard(),
                _buildChiffreChocSection(),
                const SizedBox(height: 24),
                _buildTrajectorySection(),
                const SizedBox(height: 12),
                _buildEtSiPanel(),
                const SizedBox(height: 24),
                _buildBenchmarkSection(),
                const SizedBox(height: 24),
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildStreakMilestoneSection(),
                const SizedBox(height: 24),
                _buildAskMintCard(),
                const SizedBox(height: 32),
                _buildDisclaimer(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetMenuButton() {
    return PopupMenuButton<_DashboardResetAction>(
      tooltip: 'Réinitialiser',
      icon: const Icon(Icons.tune, color: Colors.white),
      onSelected: (value) => _handleResetAction(value),
      itemBuilder: (_) => const [
        PopupMenuItem<_DashboardResetAction>(
          value: _DashboardResetAction.resetHistory,
          child: Text('Réinitialiser mon historique coach'),
        ),
        PopupMenuItem<_DashboardResetAction>(
          value: _DashboardResetAction.resetDiagnostic,
          child: Text('Recommencer mon diagnostic'),
        ),
      ],
    );
  }

  Future<void> _handleResetAction(_DashboardResetAction action) async {
    if (action == _DashboardResetAction.resetHistory) {
      final confirmed = await _confirmResetDialog(
        title: 'Réinitialiser ton historique coach ?',
        message:
            'Cela supprime tes check-ins, ton historique de score et la progression des simulateurs.',
        cta: 'Réinitialiser',
      );
      if (confirmed != true || !mounted) return;

      await ReportPersistenceService.clearCoachHistory();
      if (!mounted) return;
      await context.read<CoachProfileProvider>().loadFromWizard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historique coach réinitialisé.')),
      );
      return;
    }

    final confirmed = await _confirmResetDialog(
      title: 'Recommencer ton diagnostic ?',
      message:
          'Cela supprime ton diagnostic actuel et tes réponses mini-onboarding.',
      cta: 'Recommencer',
    );
    if (confirmed != true || !mounted) return;

    await ReportPersistenceService.clearDiagnostic();
    await ReportPersistenceService.clearCoachHistory();
    if (!mounted) return;
    context.read<CoachProfileProvider>().clear();
    context.go('/advisor');
  }

  Future<bool?> _confirmResetDialog({
    required String title,
    required String message,
    required String cta,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(cta),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  ETAT B : PARTIAL DASHBOARD (mini-onboarding complete)
  // ════════════════════════════════════════════════════════════════
  //
  // Affiche un chiffre choc personnalise + score estimatif
  // avec un badge precision + CTA "Enrichir" vers le wizard.
  // ════════════════════════════════════════════════════════════════

  Widget _buildPartialDashboard() {
    final provider = context.watch<CoachProfileProvider>();
    final completeness = provider.profileCompleteness;
    final dataPoints = provider.dataPointsCount;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Precision badge
                _buildPrecisionBadge(completeness, dataPoints),
                const SizedBox(height: 20),
                _buildResumePlan30Card(),
                if (_hasOnboarding30PlanToResume()) const SizedBox(height: 20),
                // Chiffre choc (main value proposition)
                _buildChiffreChocSection(),
                const SizedBox(height: 24),
                // Estimated score with "enrichir" prompt
                _buildPartialScoreCard(),
                const SizedBox(height: 24),
                // Teaser trajectory (blurred, but less aggressive)
                _buildTeaserTrajectory(),
                const SizedBox(height: 24),
                // Quick win cards
                _buildQuickWinCards(),
                const SizedBox(height: 24),
                // Enrichir CTA
                _buildEnrichirBanner(),
                const SizedBox(height: 24),
                // Ask MINT
                _buildAskMintCard(),
                const SizedBox(height: 32),
                _buildDisclaimer(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B.1 PRECISION BADGE
  // ────────────────────────────────────────────────────────────

  Widget _buildPrecisionBadge(double completeness, int dataPoints) {
    final percentage = (completeness * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MintColors.scoreAttention.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.tune,
              color: MintColors.scoreAttention,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Precision : $percentage%',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Base sur $dataPoints donnees — enrichis ton profil pour plus de precision',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Mini progress ring
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: completeness,
                  strokeWidth: 3,
                  backgroundColor: MintColors.lightBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      MintColors.scoreAttention),
                ),
                Text(
                  '$percentage',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B.2 PARTIAL SCORE CARD — score estimatif avec badge
  // ────────────────────────────────────────────────────────────

  Widget _buildPartialScoreCard() {
    if (_score == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ton Fitness Financier (estimatif)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              MintScoreGauge(
                score: _score!.global,
                budgetScore: _score!.budget.score,
                prevoyanceScore: _score!.prevoyance.score,
                patrimoineScore: _score!.patrimoine.score,
                trend: _score!.trend.name,
                previousScore: null,
                onTap: () {},
              ),
              const SizedBox(height: 16),
              // Estimation disclaimer
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: MintColors.scoreAttention.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: MintColors.scoreAttention, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Score estimatif base sur 4 donnees. '
                        'Complete le diagnostic pour un score precis.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/advisor/wizard'),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    'Enrichir mon profil',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MintColors.primary,
                    side:
                        const BorderSide(color: MintColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B.3 ENRICHIR BANNER
  // ────────────────────────────────────────────────────────────

  Widget _buildEnrichirBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.primary,
            MintColors.primary.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Passe de 15% a 60% de precision',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Le diagnostic complet prend 10 minutes '
            'et deverrouille ta trajectoire personnalisee.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/advisor/wizard'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: MintColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Completer mon diagnostic',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  ETAT C : EMPTY DASHBOARD (utilisateur curieux)
  // ════════════════════════════════════════════════════════════════

  Widget _buildEmptyDashboard() {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildEmptyAppBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildEmptyScoreCard(),
                const SizedBox(height: 24),
                _buildResumePlan30Card(),
                if (_hasOnboarding30PlanToResume()) const SizedBox(height: 24),
                _buildTeaserTrajectory(),
                const SizedBox(height: 24),
                _buildQuickWinCards(),
                const SizedBox(height: 24),
                _buildAskMintCard(),
                const SizedBox(height: 24),
                _buildMotivationBanner(),
                const SizedBox(height: 32),
                _buildDisclaimer(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B1. EMPTY APP BAR
  // ────────────────────────────────────────────────────────────

  Widget _buildEmptyAppBar() {
    final l10n = S.of(context);
    return SliverAppBar(
      pinned: true,
      expandedHeight: 90,
      toolbarHeight: 48,
      automaticallyImplyLeading: false,
      backgroundColor: MintColors.primary,
      actions: [
        _buildResetMenuButton(),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 24, bottom: 12, right: 24),
        title: Text(
          l10n?.coachWelcome ?? 'Bienvenue sur MINT',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MintColors.primary,
                MintColors.primary.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B2. EMPTY SCORE CARD — jauge grisee avec "?"
  // ────────────────────────────────────────────────────────────

  Widget _buildEmptyScoreCard() {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.coachFitnessTitle ?? 'Ton Fitness Financier',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.push('/advisor'),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: MintColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // ── Header ──
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: MintColors.border.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: MintColors.textMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.coachFinancialForm ?? 'Forme financière',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: MintColors.textPrimary,
                            ),
                          ),
                          Text(
                            l10n?.coachScoreComposite ??
                                'Score composite · 3 piliers',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: MintColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MintColors.border.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '?',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Grayed-out gauge with "?" ──
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CustomPaint(
                    painter: _EmptyGaugePainter(),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '?',
                            style: GoogleFonts.montserrat(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              color: MintColors.border,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '/100',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color:
                                  MintColors.textMuted.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Grayed-out sub-score bars ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MintColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _buildEmptySubScoreBar(
                        label: l10n?.coachPillarBudget ?? 'Budget',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildEmptySubScoreBar(
                        label: l10n?.coachPillarPrevoyance ?? 'Prévoyance',
                        icon: Icons.shield_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildEmptySubScoreBar(
                        label: l10n?.coachPillarPatrimoine ?? 'Patrimoine',
                        icon: Icons.trending_up,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── CTA text ──
                Text(
                  l10n?.coachCompletePrompt ??
                      'Complète ton diagnostic pour découvrir ton score',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // ── CTA button ──
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/advisor'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text(
                      l10n?.coachDiscoverScore ??
                          'Découvrir mon score \u2014 10 min',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySubScoreBar({
    required String label,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon,
            size: 16, color: MintColors.textMuted.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: MintColors.textMuted.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: 0,
                backgroundColor: MintColors.lightBorder,
                color: MintColors.border,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text(
            '--',
            textAlign: TextAlign.right,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B3. TEASER TRAJECTORY — graphique floute avec overlay
  // ────────────────────────────────────────────────────────────

  Widget _buildTeaserTrajectory() {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.coachTrajectory ?? 'Ta trajectoire',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.push('/advisor'),
          child: Container(
            decoration: BoxDecoration(
              color: MintColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // ── Placeholder chart (blurred) ──
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _PlaceholderTrajectoryPainter(),
                      ),
                    ),
                  ),
                ),

                // ── Overlay with pulsing glow ──
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final glowOpacity = 0.03 + (_pulseAnimation.value * 0.05);
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.8,
                            colors: [
                              MintColors.coachAccent
                                  .withValues(alpha: glowOpacity),
                              Colors.white.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── Text overlay ──
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: MintColors.coachAccent
                                  .withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.timeline_rounded,
                              color: MintColors.coachAccent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n?.coachTrajectoryPrompt ??
                                'Ta trajectoire financière t\'attend',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: MintColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '3 scenarios personnalises selon ta situation',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: MintColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B4. QUICK WIN CARDS — faits educatifs
  // ────────────────────────────────────────────────────────────

  Widget _buildQuickWinCards() {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.coachDidYouKnow ?? 'Le savais-tu ?',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildQuickWinCard(
          icon: Icons.savings_outlined,
          iconColor: MintColors.scoreExcellent,
          fact: l10n?.coachFact3a ??
              'Le 3e pilier peut te faire économiser jusqu\'à CHF 2\'500 d\'impôts par an, selon ton canton et ton revenu.',
          route: '/simulator/3a',
          linkLabel: l10n?.coachFact3aLink ?? 'Simuler mon économie 3a',
        ),
        const SizedBox(height: 12),
        _buildQuickWinCard(
          icon: Icons.shield_outlined,
          iconColor: MintColors.scoreAttention,
          fact: l10n?.coachFactAvs ??
              'En Suisse, chaque année AVS manquante = −2.3% de rente à vie. Un rattrapage est possible dans certains cas.',
          route: '/retirement',
          linkLabel: l10n?.coachFactAvsLink ?? 'Vérifier mes années AVS',
        ),
        const SizedBox(height: 12),
        _buildQuickWinCard(
          icon: Icons.account_balance_outlined,
          iconColor: MintColors.coachAccent,
          fact: l10n?.coachFactLpp ??
              'Le rachat LPP est l\'un des leviers fiscaux les plus puissants pour les salarié·es en Suisse. Il est intégralement déductible du revenu imposable.',
          route: '/lpp-deep/rachat',
          linkLabel: l10n?.coachFactLppLink ?? 'Explorer le rachat LPP',
        ),
      ],
    );
  }

  Widget _buildQuickWinCard({
    required IconData icon,
    required Color iconColor,
    required String fact,
    required String route,
    required String linkLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fact,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: MintColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(route),
              style: TextButton.styleFrom(
                foregroundColor: MintColors.coachAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    linkLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B5. MOTIVATION BANNER
  // ────────────────────────────────────────────────────────────

  Widget _buildMotivationBanner() {
    final l10n = S.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.primary,
            MintColors.primary.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.coachMotivation ??
                'Rejoins les milliers d\'utilisateurs qui ont déjà fait leur diagnostic financier',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.coachMotivationSub ?? 'et recevoir des actions concrètes.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/advisor'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: MintColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n?.coachLaunchDiagnostic ?? 'Lancer mon diagnostic',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  ETAT A : DASHBOARD COMPLET (profil existe)
  // ════════════════════════════════════════════════════════════════

  // ════════════════════════════════════════════════════════════════
  //  1. SLIVER APP BAR
  // ════════════════════════════════════════════════════════════════

  Widget _buildAppBar() {
    final l10n = S.of(context);
    final firstName = _profile!.firstName ?? 'Coach';
    return SliverAppBar(
      pinned: true,
      expandedHeight: 90,
      toolbarHeight: 48,
      automaticallyImplyLeading: false,
      backgroundColor: MintColors.primary,
      actions: [
        _buildResetMenuButton(),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 24, bottom: 12, right: 24),
        title: Text(
          l10n?.coachHello(firstName) ?? 'Bonjour $firstName',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MintColors.primary,
                MintColors.primary.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  2. COACH ALERT CARD
  // ════════════════════════════════════════════════════════════════

  /// Build a dynamic coaching card based on the user's biggest gap.
  ///
  /// Instead of a generic message per fitness level, this surfaces
  /// the most impactful coaching tip with a specific CHF amount
  /// and a direct CTA to the relevant simulator.
  Widget _buildCoachAlertCard() {
    final level = _score!.level;

    // Utiliser les tips caches depuis didChangeDependencies
    final tips = _coachingTips;
    final topTip = tips.isNotEmpty ? tips.first : null;

    // Border color based on fitness level
    final Color borderColor;
    final IconData iconData;
    switch (level) {
      case FitnessLevel.excellent:
        borderColor = MintColors.scoreExcellent;
        iconData = Icons.check_circle_outline;
      case FitnessLevel.bon:
        borderColor = MintColors.scoreBon;
        iconData = Icons.lightbulb_outline;
      case FitnessLevel.attention:
        borderColor = MintColors.scoreAttention;
        iconData = Icons.warning_amber_outlined;
      case FitnessLevel.critique:
        borderColor = MintColors.scoreCritique;
        iconData = Icons.error_outline;
    }

    // Use the top coaching tip if available; fallback to generic message
    final String message;
    final String? ctaLabel;
    final String? ctaRoute;
    if (topTip != null) {
      message = topTip.message;
      ctaLabel = topTip.action;
      ctaRoute = tipRoute(topTip);
    } else {
      message = _score!.coachMessage;
      ctaLabel = null;
      ctaRoute = null;
    }

    return Container(
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(topTip?.icon ?? iconData, color: borderColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (topTip != null) ...[
                      Text(
                        topTip.title,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: MintColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    if (topTip?.estimatedImpactChf != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Impact estimé : ~CHF ${topTip!.estimatedImpactChf!.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: borderColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Autres recommandations badge
              if (tips.length > 1)
                GestureDetector(
                  onTap: () => context.push('/coach/agir'),
                  child: Text(
                    '${tips.length - 1} autre${tips.length > 2 ? 's' : ''} recommandation${tips.length > 2 ? 's' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push(ctaRoute ?? '/report'),
                style: TextButton.styleFrom(
                  foregroundColor: MintColors.coachAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ctaLabel ?? 'Explorer',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  2B. NOW VS WITH MINT ACTIONS
  // ════════════════════════════════════════════════════════════════

  Widget _buildNowVsWithCard() {
    if (_baselineProjection == null || _projection == null) {
      return const SizedBox.shrink();
    }

    final capitalSans = _baselineProjection!.base.capitalFinal;
    final capitalAvec = _projection!.base.capitalFinal;
    final deltaCapital = capitalAvec - capitalSans;

    final tauxSans = _baselineProjection!.tauxRemplacementBase;
    final tauxAvec = _projection!.tauxRemplacementBase;
    final deltaTaux = tauxAvec - tauxSans;

    if (deltaCapital <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: MintColors.success.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: MintColors.success.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MintColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: MintColors.success,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ton impact MINT',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Avec tes actions vs sans rien faire',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Capital row
            _buildNowVsRow(
              label: 'Capital retraite',
              valueSans: capitalSans,
              valueAvec: capitalAvec,
              delta: deltaCapital,
              isCurrency: true,
            ),
            const SizedBox(height: 14),
            // Taux de remplacement row
            _buildNowVsRow(
              label: 'Taux de remplacement',
              valueSans: tauxSans,
              valueAvec: tauxAvec,
              delta: deltaTaux,
              isCurrency: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNowVsRow({
    required String label,
    required double valueSans,
    required double valueAvec,
    required double delta,
    required bool isCurrency,
  }) {
    String fmt(double v) => isCurrency
        ? ForecasterService.formatChf(v)
        : '${v.toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Sans
            Text(
              fmt(valueSans),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textMuted,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward,
                size: 14, color: MintColors.success),
            const SizedBox(width: 8),
            // Avec
            Text(
              fmt(valueAvec),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const Spacer(),
            // Delta badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MintColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${fmt(delta)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.success,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  3. SCORE SECTION
  // ════════════════════════════════════════════════════════════════

  Widget _buildScoreSection() {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.coachFitnessTitle ?? 'Ton Fitness Financier',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: MintScoreGauge(
            score: _score!.global,
            budgetScore: _score!.budget.score,
            prevoyanceScore: _score!.prevoyance.score,
            patrimoineScore: _score!.patrimoine.score,
            trend: _score!.trend.name,
            previousScore: _score!.deltaVsPreviousMonth != null
                ? _score!.global - _score!.deltaVsPreviousMonth!
                : null,
            onTap: () => context.push('/report'),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  3a. SCORE HISTORY MINI-CHART — Evolution mensuelle du score
  // ════════════════════════════════════════════════════════════════

  /// Mois abreges en francais pour l'axe X du mini-chart.
  static const _monthLabelsFr = [
    'Jan',
    'Fev',
    'Mar',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Aou',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  Widget _buildScoreHistorySection() {
    if (_scoreHistory == null || _scoreHistory!.length < 2) {
      return const SizedBox.shrink();
    }

    final history = _scoreHistory!;

    // Determiner la tendance (amelioration ou degradation)
    final firstScore = (history.first['score'] as num?)?.toInt() ?? 0;
    final lastScore = (history.last['score'] as num?)?.toInt() ?? 0;
    final isImproving = lastScore >= firstScore;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Evolution de ton score',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
                // Badge tendance
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isImproving
                        ? MintColors.success.withValues(alpha: 0.12)
                        : MintColors.scoreAttention.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isImproving ? Icons.trending_up : Icons.trending_down,
                        size: 14,
                        color: isImproving
                            ? MintColors.success
                            : MintColors.scoreAttention,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${lastScore - firstScore > 0 ? '+' : ''}${lastScore - firstScore} pts',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isImproving
                              ? MintColors.success
                              : MintColors.scoreAttention,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Mini-chart
            SizedBox(
              height: 80,
              width: double.infinity,
              child: CustomPaint(
                painter: _ScoreHistoryPainter(
                  history: history,
                  isImproving: isImproving,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Labels X-axis (premier et dernier mois)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatMonthLabel(history.first['month'] as String? ?? ''),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                  ),
                ),
                Text(
                  _formatMonthLabel(history.last['month'] as String? ?? ''),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Formate "2026-02" en "Fev 2026".
  String _formatMonthLabel(String monthKey) {
    if (monthKey.length < 7) return monthKey;
    try {
      final parts = monthKey.split('-');
      final year = parts[0];
      final monthIndex = int.parse(parts[1]);
      if (monthIndex < 1 || monthIndex > 12) return monthKey;
      return '${_monthLabelsFr[monthIndex - 1]} $year';
    } catch (_) {
      return monthKey;
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  3b. CHIFFRES CHOC SECTION — Personalized shock figures
  // ════════════════════════════════════════════════════════════════

  Widget _buildChiffreChocSection() {
    final revenuBrutAnnuel = _profile!.revenuBrutAnnuel;
    final cards = <Widget>[];

    // 1. 3a tax savings gap — if not maxing out the pillar 3a
    final cotisation3aAnnuelle = _profile!.total3aMensuel * 12;
    const plafond3a = 7258.0; // OPP3 art. 7
    if (cotisation3aAnnuelle < plafond3a &&
        _profile!.prevoyance.canContribute3a) {
      final tauxMarginal =
          _estimateMarginalTaxRate(revenuBrutAnnuel, _profile!.canton);
      final economiePotentielle =
          (plafond3a - cotisation3aAnnuelle) * tauxMarginal;
      final anneesRestantes = _profile!.anneesAvantRetraite;
      final economieTotale = economiePotentielle * anneesRestantes;

      if (economieTotale > 500) {
        cards.add(ChiffreChocCard(
          value: economieTotale,
          message: 'Économies d\'impôts potentielles d\'ici ta retraite en '
              'maximisant ton 3a chaque année.',
          source: 'OPP3 art. 7 · LIFD',
          ctaLabel: 'Simuler mon 3a',
          ctaRoute: '/simulator/3a',
          icon: Icons.savings,
          color: const Color(0xFF4F46E5),
        ));
      }
    }

    // 2. LPP buyback tax deduction potential
    final lacuneLpp = _profile!.prevoyance.lacuneRachatRestante;
    if (lacuneLpp > 5000) {
      final tauxMarginal =
          _estimateMarginalTaxRate(revenuBrutAnnuel, _profile!.canton);
      final economieRachat = lacuneLpp * tauxMarginal;

      cards.add(ChiffreChocCard(
        value: economieRachat,
        message: 'Déduction fiscale potentielle en rachetant '
            'ta lacune LPP de CHF ${_formatChf(lacuneLpp)}.',
        source: 'LPP art. 79b',
        ctaLabel: 'Explorer le rachat',
        ctaRoute: '/lpp-deep/rachat',
        icon: Icons.account_balance,
        color: MintColors.coachAccent,
      ));
    }

    // 3. AVS gap cost — each missing year = -1/44 of max rente (LAVS art. 29ter)
    final lacunesAVS = _profile!.prevoyance.lacunesAVS ?? 0;
    if (lacunesAVS > 0) {
      // 30'240 CHF/an = rente AVS max (LAVS art. 34)
      const reductionParAnnee = 1.0 / avsDureeCotisationComplete;
      final perteTotaleAnnuelle = lacunesAVS * reductionParAnnee * 30240;
      // Over ~20 years of retirement
      final perteTotaleRetraite = perteTotaleAnnuelle * 20;

      cards.add(ChiffreChocCard(
        value: perteTotaleRetraite,
        message: 'Rente AVS perdue sur 20 ans de retraite avec '
            '$lacunesAVS année${lacunesAVS > 1 ? 's' : ''} '
            'de cotisation manquante${lacunesAVS > 1 ? 's' : ''}.',
        source: 'LAVS art. 29',
        ctaLabel: 'Vérifier mes lacunes',
        ctaRoute: '/retirement',
        icon: Icons.shield_outlined,
        color: MintColors.scoreAttention,
      ));
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tes chiffres-chocs',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Des montants personnalisés pour éclairer tes décisions',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        ...cards.expand((card) => [card, const SizedBox(height: 12)]),
      ],
    );
  }

  /// Simplified marginal tax rate estimation by canton bracket.
  /// Source: AFC taux marginaux d'imposition 2025
  /// Combined rates (fédéral + cantonal + communal).
  double _estimateMarginalTaxRate(double revenuBrutAnnuel, String canton) {
    const highTaxCantons = {'GE', 'VD', 'BS', 'BE', 'NE', 'JU', 'FR', 'VS'};
    const lowTaxCantons = {'ZG', 'SZ', 'NW', 'OW', 'AI', 'AR', 'UR'};

    double baseRate;
    if (revenuBrutAnnuel > 200000) {
      baseRate = 0.38;
    } else if (revenuBrutAnnuel > 120000) {
      baseRate = 0.32;
    } else if (revenuBrutAnnuel > 80000) {
      baseRate = 0.28;
    } else {
      baseRate = 0.22;
    }

    if (highTaxCantons.contains(canton)) return baseRate * 1.1;
    if (lowTaxCantons.contains(canton)) return baseRate * 0.75;
    return baseRate;
  }

  String _formatChf(double amount) {
    final formatted = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = formatted.length - 1; i >= 0; i--) {
      buffer.write(formatted[i]);
      count++;
      if (count % 3 == 0 && i > 0) buffer.write("'");
    }
    return buffer.toString().split('').reversed.join();
  }

  // ════════════════════════════════════════════════════════════════
  //  4. TRAJECTORY SECTION
  // ════════════════════════════════════════════════════════════════

  Widget _buildTrajectorySection() {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.coachTrajectory ?? 'Ta trajectoire',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: MintTrajectoryChart(
            result: _etSiProjection ?? _projection!,
            goalALabel: _profile!.goalA.label,
            onTap: () => context.push('/retirement/projection'),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  4a. "ET SI..." INTERACTIVE SLIDER PANEL
  // ════════════════════════════════════════════════════════════════

  Widget _buildEtSiPanel() {
    // Gate: if no subscription access, show teaser
    if (!SubscriptionService.hasAccess(CoachFeature.scenariosEtSi)) {
      return _buildEtSiTeaser();
    }

    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          // Header — expandable
          InkWell(
            onTap: () => setState(() {
              _etSiExpanded = !_etSiExpanded;
              if (!_etSiExpanded) {
                // Reset to defaults
                _etSiLppReturn = ScenarioAssumptions.base.lppReturn;
                _etSiThreeAReturn = ScenarioAssumptions.base.threeAReturn;
                _etSiInvestReturn = ScenarioAssumptions.base.investmentReturn;
                _etSiInflation = ScenarioAssumptions.base.inflation;
                _etSiProjection = null;
              }
            }),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MintColors.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.tune,
                      color: MintColors.info,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Et si... ?',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    _etSiExpanded ? 'Replier' : 'Ajuster les hypotheses',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _etSiExpanded ? Icons.expand_less : Icons.expand_more,
                    color: MintColors.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content — sliders
          if (_etSiExpanded) ...[
            const Divider(height: 1, color: MintColors.lightBorder),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajuste les hypotheses de rendement du scenario Base.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _etSiSlider(
                    label: 'Rendement LPP',
                    value: _etSiLppReturn * 100,
                    min: 0,
                    max: 5,
                    suffix: '%',
                    decimals: 1,
                    onChanged: (v) =>
                        _updateEtSi(() => _etSiLppReturn = v / 100),
                  ),
                  const SizedBox(height: 12),
                  _etSiSlider(
                    label: 'Rendement 3a',
                    value: _etSiThreeAReturn * 100,
                    min: 0,
                    max: 10,
                    suffix: '%',
                    decimals: 1,
                    onChanged: (v) =>
                        _updateEtSi(() => _etSiThreeAReturn = v / 100),
                  ),
                  const SizedBox(height: 12),
                  _etSiSlider(
                    label: 'Rendement investissements',
                    value: _etSiInvestReturn * 100,
                    min: 0,
                    max: 15,
                    suffix: '%',
                    decimals: 1,
                    onChanged: (v) =>
                        _updateEtSi(() => _etSiInvestReturn = v / 100),
                  ),
                  const SizedBox(height: 12),
                  _etSiSlider(
                    label: 'Inflation',
                    value: _etSiInflation * 100,
                    min: 0,
                    max: 4,
                    suffix: '%',
                    decimals: 1,
                    onChanged: (v) =>
                        _updateEtSi(() => _etSiInflation = v / 100),
                  ),
                  const SizedBox(height: 16),

                  // Impact summary
                  if (_etSiProjection != null) _buildEtSiImpact(),

                  // Reset button
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _updateEtSi(() {
                        _etSiLppReturn = ScenarioAssumptions.base.lppReturn;
                        _etSiThreeAReturn =
                            ScenarioAssumptions.base.threeAReturn;
                        _etSiInvestReturn =
                            ScenarioAssumptions.base.investmentReturn;
                        _etSiInflation = ScenarioAssumptions.base.inflation;
                      }),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(
                        'Reinitialiser',
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                    ),
                  ),

                  // Disclaimer
                  const SizedBox(height: 8),
                  Text(
                    'Simulation educative. Les rendements sont des hypotheses '
                    'et ne presagent pas des performances futures (LSFin).',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: MintColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _etSiSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    int decimals = 1,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
            Text(
              '${value.toStringAsFixed(decimals)}$suffix',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) * 10).round(), // 0.1% steps
            activeColor: MintColors.info,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _updateEtSi(VoidCallback update) {
    setState(() {
      update();
      _etSiProjection = ForecasterService.projectEtSi(
        profile: _profile!,
        customBase: ScenarioAssumptions(
          label: 'Et si...',
          lppReturn: _etSiLppReturn,
          threeAReturn: _etSiThreeAReturn,
          investmentReturn: _etSiInvestReturn,
          savingsReturn: ScenarioAssumptions.base.savingsReturn,
          inflation: _etSiInflation,
        ),
      );
    });
  }

  Widget _buildEtSiImpact() {
    final baseCapital = _projection!.base.capitalFinal;
    final etSiCapital = _etSiProjection!.base.capitalFinal;
    final delta = etSiCapital - baseCapital;
    final isPositive = delta >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            (isPositive ? MintColors.scoreExcellent : MintColors.scoreCritique)
                .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: isPositive
                ? MintColors.scoreExcellent
                : MintColors.scoreCritique,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impact sur ton capital a la retraite',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isPositive ? "+" : "\u2212"}\u00A0${ForecasterService.formatChf(delta.abs())}',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isPositive
                        ? MintColors.scoreExcellent
                        : MintColors.scoreCritique,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtSiTeaser() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune, color: MintColors.info, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Et si... ?',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ajuste tes hypotheses de rendement pour explorer differents scenarios.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, color: MintColors.textMuted, size: 18),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  4b. BENCHMARK SECTION — Anonymous Swiss comparison
  // ════════════════════════════════════════════════════════════════

  Widget _buildBenchmarkSection() {
    final age = _profile!.age;
    final netMensuel = _profile!.salaireBrutMensuel * 0.87;
    final epargneMensuelle = _profile!.totalContributionsMensuelles;

    // Savings rate benchmark
    final savingsBenchmark = BenchmarkService.compareSavings(
      age: age,
      monthlyNetIncome: netMensuel,
      monthlySavings: epargneMensuelle,
    );

    // 3a participation benchmark
    final has3a = _profile!.prevoyance.nombre3a > 0;
    final annualContribution3a = _profile!.total3aMensuel * 12;
    final benchmark3a = BenchmarkService.compare3a(
      age: age,
      has3a: has3a,
      annualContribution: annualContribution3a,
    );

    // Emergency fund benchmark
    final chargesMensuelles = _profile!.depenses.totalMensuel;
    final epargneLiquide = _profile!.patrimoine.epargneLiquide;
    final emergencyMonths =
        chargesMensuelles > 0 ? epargneLiquide / chargesMensuelles : 0.0;
    final emergencyBenchmark = BenchmarkService.compareEmergencyFund(
      age: age,
      emergencyFundMonths: emergencyMonths,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toi vs la Suisse',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Comparaison anonyme avec les statistiques OFS',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        BenchmarkCard(
          benchmark: savingsBenchmark,
          label: 'Taux d\'épargne',
          icon: Icons.savings_outlined,
        ),
        const SizedBox(height: 12),
        BenchmarkCard(
          benchmark: benchmark3a,
          label: 'Prévoyance 3a',
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 12),
        BenchmarkCard(
          benchmark: emergencyBenchmark,
          label: 'Fonds d\'urgence',
          icon: Icons.health_and_safety_outlined,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  5. QUICK ACTIONS
  // ════════════════════════════════════════════════════════════════

  Widget _buildQuickActions() {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.coachQuickActions ?? 'Actions rapides',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionChip(
                icon: Icons.calendar_today_outlined,
                label: l10n?.coachCheckin ?? 'Check-in\nmensuel',
                route: '/coach/checkin',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionChip(
                icon: Icons.savings_outlined,
                label: l10n?.coachVerse3a ?? 'Verser\n3a',
                route: '/simulator/3a',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionChip(
                icon: Icons.account_balance_outlined,
                label: l10n?.coachSimBuyback ?? 'Simuler\nrachat',
                route: '/lpp-deep/rachat',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MintColors.lightBorder,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: MintColors.coachAccent,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  5a. STREAK + MILESTONES SECTION
  // ════════════════════════════════════════════════════════════════

  Widget _buildStreakMilestoneSection() {
    if (_profile == null) return const SizedBox.shrink();

    final streakResult = StreakService.compute(_profile!);
    final milestones = StreakService.computeMilestones(_profile!);
    final reachedCount = milestones.where((m) => m.isReached).length;

    // Nothing to show if no streak and no milestones reached
    if (streakResult.currentStreak == 0 && reachedCount == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tes jalons',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.lightBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left: fire icon + streak count
              if (streakResult.currentStreak > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Color(0xFFFF6D00),
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${streakResult.currentStreak}',
                            style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFF6D00),
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'mois',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFFF6D00),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],
              // Right: milestone icons in a row
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: milestones.map((milestone) {
                    return Tooltip(
                      message: milestone.label,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: milestone.isReached
                            ? MintColors.primary.withValues(alpha: 0.12)
                            : MintColors.lightBorder,
                        child: Icon(
                          milestone.icon,
                          size: 16,
                          color: milestone.isReached
                              ? MintColors.primary
                              : MintColors.textMuted.withValues(alpha: 0.4),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  5b. ASK MINT CARD — Contextual AI entry point
  // ════════════════════════════════════════════════════════════════

  Widget _buildAskMintCard() {
    final byok = context.watch<ByokProvider>();

    if (byok.isConfigured) {
      return _buildAskMintCardActive();
    }
    return _buildAskMintCardSetup();
  }

  /// BYOK configured — "Ton IA est pr\u00eate, pose ta question"
  Widget _buildAskMintCardActive() {
    return GestureDetector(
      onTap: () => context.push('/ask-mint'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1D1D1F),
              Color(0xFF2D2D30),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: MintColors.primary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Ask MINT',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: MintColors.success.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ACTIF',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: MintColors.success,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pose ta question sur la finance suisse',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// BYOK not configured — "Active l'IA"
  Widget _buildAskMintCardSetup() {
    return GestureDetector(
      onTap: () => context.push('/profile/byok'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.accentPastel,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: MintColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask MINT',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Active l\'IA pour des r\u00e9ponses personnalis\u00e9es',
                    style: TextStyle(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: MintColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Configurer',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  6. DISCLAIMER
  // ════════════════════════════════════════════════════════════════

  Widget _buildDisclaimer() {
    final l10n = S.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        l10n?.coachDisclaimer ??
            'Estimations éducatives \u2014 ne constitue pas un conseil financier. Les rendements passés ne présagent pas des rendements futurs. Consulte un\u00B7e spécialiste pour un plan personnalisé. LSFin.',
        style: GoogleFonts.inter(
          fontSize: 11,
          color: MintColors.textMuted,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  EMPTY GAUGE CUSTOM PAINTER
// ════════════════════════════════════════════════════════════════
//
// Jauge grisee identique a la vraie MintScoreGauge mais
// sans arc rempli — seulement le track (fond).
// Utilisee dans l'etat vide (utilisateur curieux).
// ════════════════════════════════════════════════════════════════

class _EmptyGaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 16;
    const strokeWidth = 14.0;
    const startAngle = 0.75 * pi;
    const totalSweep = 1.5 * pi;

    // ── Background track (grayed out) ──
    final trackPaint = Paint()
      ..color = MintColors.lightBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // ── Tick marks (grayed out) ──
    final tickRadius = radius + strokeWidth / 2 + 4;
    for (int i = 0; i <= 4; i++) {
      final fraction = i / 4;
      final angle = startAngle + totalSweep * fraction;
      final innerPoint = Offset(
        center.dx + tickRadius * cos(angle),
        center.dy + tickRadius * sin(angle),
      );
      final outerPoint = Offset(
        center.dx + (tickRadius + 5) * cos(angle),
        center.dy + (tickRadius + 5) * sin(angle),
      );

      final tickPaint = Paint()
        ..color = MintColors.border.withValues(alpha: 0.30)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(innerPoint, outerPoint, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmptyGaugePainter oldDelegate) => false;
}

// ════════════════════════════════════════════════════════════════
//  PLACEHOLDER TRAJECTORY PAINTER
// ════════════════════════════════════════════════════════════════
//
// Dessine 3 courbes simulees (optimiste, base, prudent)
// qui seront floutees en surcouche. Purement decoratif.
// ════════════════════════════════════════════════════════════════

class _PlaceholderTrajectoryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Grid lines ──
    final gridPaint = Paint()
      ..color = MintColors.lightBorder.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;

    for (int i = 1; i <= 4; i++) {
      final y = h * i / 5;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // ── Optimistic curve (green, rising steeply) ──
    _drawSmoothCurve(
      canvas,
      size,
      color: MintColors.trajectoryOptimiste.withValues(alpha: 0.7),
      points: [
        Offset(0, h * 0.65),
        Offset(w * 0.2, h * 0.55),
        Offset(w * 0.4, h * 0.42),
        Offset(w * 0.6, h * 0.30),
        Offset(w * 0.8, h * 0.20),
        Offset(w, h * 0.12),
      ],
    );

    // ── Base curve (blue, moderate rise) ──
    _drawSmoothCurve(
      canvas,
      size,
      color: MintColors.trajectoryBase.withValues(alpha: 0.7),
      points: [
        Offset(0, h * 0.65),
        Offset(w * 0.2, h * 0.60),
        Offset(w * 0.4, h * 0.52),
        Offset(w * 0.6, h * 0.45),
        Offset(w * 0.8, h * 0.40),
        Offset(w, h * 0.35),
      ],
    );

    // ── Prudent curve (orange, gentle rise) ──
    _drawSmoothCurve(
      canvas,
      size,
      color: MintColors.trajectoryPrudent.withValues(alpha: 0.7),
      points: [
        Offset(0, h * 0.65),
        Offset(w * 0.2, h * 0.63),
        Offset(w * 0.4, h * 0.60),
        Offset(w * 0.6, h * 0.58),
        Offset(w * 0.8, h * 0.57),
        Offset(w, h * 0.55),
      ],
    );
  }

  void _drawSmoothCurve(
    Canvas canvas,
    Size size, {
    required Color color,
    required List<Offset> points,
  }) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final controlX = (current.dx + next.dx) / 2;
      path.cubicTo(
        controlX,
        current.dy,
        controlX,
        next.dy,
        next.dx,
        next.dy,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PlaceholderTrajectoryPainter oldDelegate) =>
      false;
}

// ════════════════════════════════════════════════════════════════
//  SCORE HISTORY MINI-CHART PAINTER
// ════════════════════════════════════════════════════════════════
//
// Dessine une courbe lissee reliant les scores mensuels (max 24).
// Gradient sous la courbe (vert si amelioration, orange sinon).
// Points aux donnees, point final mis en evidence.
// ════════════════════════════════════════════════════════════════

class _ScoreHistoryPainter extends CustomPainter {
  final List<Map<String, dynamic>> history;
  final bool isImproving;

  _ScoreHistoryPainter({
    required this.history,
    required this.isImproving,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    final w = size.width;
    final h = size.height;
    const padding = 8.0;
    final chartW = w - padding * 2;
    final chartH = h - padding * 2;

    // Convertir les scores en points
    final scores =
        history.map((e) => (e['score'] as num?)?.toDouble() ?? 0.0).toList();
    final count = scores.length;

    // Y-axis: 0 a 100 (scores de fitness)
    const minY = 0.0;
    const maxY = 100.0;

    List<Offset> points = [];
    for (int i = 0; i < count; i++) {
      final x = padding + (i / (count - 1)) * chartW;
      final normalizedY = (scores[i] - minY) / (maxY - minY);
      final y = padding + chartH - (normalizedY * chartH);
      points.add(Offset(x, y));
    }

    // ── Couleur principale ──
    final lineColor =
        isImproving ? MintColors.success : MintColors.scoreAttention;

    // ── Dessiner le gradient sous la courbe ──
    final gradientPath = _buildSmoothPath(points);
    final fillPath = Path.from(gradientPath)
      ..lineTo(points.last.dx, padding + chartH)
      ..lineTo(points.first.dx, padding + chartH)
      ..close();

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, gradientPaint);

    // ── Dessiner la ligne ──
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(gradientPath, linePaint);

    // ── Points aux donnees ──
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      final dotRadius = isLast ? 5.0 : 3.0;
      final borderRadius = isLast ? 7.0 : 0.0;

      if (isLast) {
        // Bordure blanche pour le dernier point
        canvas.drawCircle(points[i], borderRadius, dotBorderPaint);
      }
      canvas.drawCircle(points[i], dotRadius, dotPaint);
    }
  }

  /// Construit un path lisse (courbe cubique) a travers les points.
  Path _buildSmoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final controlX = (current.dx + next.dx) / 2;
      path.cubicTo(
        controlX,
        current.dy,
        controlX,
        next.dy,
        next.dx,
        next.dy,
      );
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant _ScoreHistoryPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.isImproving != isImproving;
  }
}
