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

class _CoachDashboardScreenState extends State<CoachDashboardScreen>
    with SingleTickerProviderStateMixin {
  CoachProfile? _profile;
  FinancialFitnessScore? _score;
  ProjectionResult? _projection;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coachProvider = context.watch<CoachProfileProvider>();

    // BUG FIX: Ne plus utiliser CoachProfile.buildDemo() comme fallback.
    // Si le wizard n'a pas ete complete, on affiche l'etat vide
    // (utilisateur curieux) au lieu de fausses donnees demo.
    if (coachProvider.hasProfile) {
      final newProfile = coachProvider.profile!;
      if (_profile != newProfile) {
        _profile = newProfile;
        _score = FinancialFitnessService.calculate(profile: _profile!);
        _projection = ForecasterService.project(
          profile: _profile!,
          targetDate: _profile!.goalA.targetDate,
        );
      }
    } else {
      _profile = null;
      _score = null;
      _projection = null;
    }
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

    // ── ETAT B : Utilisateur curieux (pas de profil) ──
    if (!coachProvider.hasProfile) {
      return _buildEmptyDashboard();
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
                _buildScoreSection(),
                const SizedBox(height: 24),
                _buildTrajectorySection(),
                const SizedBox(height: 24),
                _buildQuickActions(),
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

  // ════════════════════════════════════════════════════════════════
  //  ETAT B : EMPTY DASHBOARD (utilisateur curieux)
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
                _buildTeaserTrajectory(),
                const SizedBox(height: 24),
                _buildQuickWinCards(),
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
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      automaticallyImplyLeading: false,
      backgroundColor: MintColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 24, bottom: 16, right: 24),
        title: Text(
          'Bienvenue sur MINT',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ton Fitness Financier',
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
                            'Forme financiere',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: MintColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Score composite  ·  3 piliers',
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
                              color: MintColors.textMuted.withValues(alpha: 0.5),
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
                        label: 'Budget',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildEmptySubScoreBar(
                        label: 'Prevoyance',
                        icon: Icons.shield_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildEmptySubScoreBar(
                        label: 'Patrimoine',
                        icon: Icons.trending_up,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── CTA text ──
                Text(
                  'Complete ton diagnostic pour decouvrir ton score',
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
                      'Decouvrir mon score \u2014 10 min',
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
        Icon(icon, size: 16, color: MintColors.textMuted.withValues(alpha: 0.5)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ta trajectoire',
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
                              MintColors.coachAccent.withValues(alpha: glowOpacity),
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
                              color: MintColors.coachAccent.withValues(alpha: 0.10),
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
                            'Ta trajectoire financiere t\'attend',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Le savais-tu ?',
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
          fact: 'Le 3e pilier peut te faire economiser '
              'jusqu\'a CHF 2\'500 d\'impots par an, '
              'selon ton canton et ton revenu.',
          route: '/simulator/3a',
          linkLabel: 'Simuler mon economie 3a',
        ),
        const SizedBox(height: 12),
        _buildQuickWinCard(
          icon: Icons.shield_outlined,
          iconColor: MintColors.scoreAttention,
          fact: 'En Suisse, chaque annee AVS manquante = '
              '-2.3% de rente a vie. '
              'Un rattrapage est possible dans certains cas.',
          route: '/simulator/avs',
          linkLabel: 'Verifier mes annees AVS',
        ),
        const SizedBox(height: 12),
        _buildQuickWinCard(
          icon: Icons.account_balance_outlined,
          iconColor: MintColors.coachAccent,
          fact: 'Le rachat LPP est l\'un des leviers fiscaux '
              'les plus puissants pour les salarie\u00B7es en Suisse. '
              'Il est integralement deductible du revenu imposable.',
          route: '/lpp-deep/rachat',
          linkLabel: 'Explorer le rachat LPP',
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            'Rejoins les milliers d\'utilisateurs '
            'qui ont deja fait leur diagnostic financier',
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
            '10 minutes pour comprendre ta situation '
            'et recevoir des actions concretes.',
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
                'Lancer mon diagnostic',
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
    final firstName = _profile!.firstName ?? 'Coach';
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      automaticallyImplyLeading: false,
      backgroundColor: MintColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 24, bottom: 16, right: 24),
        title: Text(
          'Bonjour $firstName',
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

  Widget _buildCoachAlertCard() {
    final level = _score!.level;

    // Border color and icon based on fitness level
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
              Icon(iconData, color: borderColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _score!.coachMessage,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/report'),
              style: TextButton.styleFrom(
                foregroundColor: MintColors.coachAccent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Explorer',
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
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  3. SCORE SECTION
  // ════════════════════════════════════════════════════════════════

  Widget _buildScoreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ton Fitness Financier',
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
            onTap: () {
              // Navigate to detailed score view
              // (will be wired in a future sprint)
            },
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  4. TRAJECTORY SECTION
  // ════════════════════════════════════════════════════════════════

  Widget _buildTrajectorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ta trajectoire',
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
            result: _projection!,
            goalALabel: _profile!.goalA.label,
            onTap: () {
              // Navigate to detailed projection view
              // (will be wired in a future sprint)
            },
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  5. QUICK ACTIONS
  // ════════════════════════════════════════════════════════════════

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
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
                label: 'Check-in\nmensuel',
                route: '/coach/checkin',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionChip(
                icon: Icons.savings_outlined,
                label: 'Verser\n3a',
                route: '/simulator/3a',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionChip(
                icon: Icons.account_balance_outlined,
                label: 'Simuler\nrachat',
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
      onTap: () => GoRouter.of(context).go(route),
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
  //  6. DISCLAIMER
  // ════════════════════════════════════════════════════════════════

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Estimations educatives — ne constitue pas un conseil financier. '
        'Les rendements passes ne presagent pas des rendements futurs. '
        'Consulte un\u00B7e specialiste pour un plan personnalise. LSFin.',
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
