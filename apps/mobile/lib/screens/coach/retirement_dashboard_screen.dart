import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/coach/confidence_bar.dart';
import 'package:mint_mobile/widgets/coach/data_quality_card.dart';
import 'package:mint_mobile/widgets/coach/early_retirement_comparison.dart';
import 'package:mint_mobile/widgets/coach/explore_hub.dart';
import 'package:mint_mobile/widgets/coach/hero_retirement_card.dart';
import 'package:mint_mobile/widgets/coach/impact_mint_card.dart';
import 'package:mint_mobile/widgets/coach/low_confidence_card.dart';
import 'package:mint_mobile/widgets/coach/mint_score_gauge.dart';
import 'package:mint_mobile/widgets/coach/pillar_decomposition.dart';
import 'package:mint_mobile/widgets/coach/trajectory_card.dart';
import 'package:mint_mobile/widgets/dashboard/arbitrage_teaser_card.dart';
import 'package:mint_mobile/widgets/dashboard/budget_gap_card.dart';
import 'package:mint_mobile/widgets/dashboard/couple_phase_timeline.dart';
import 'package:mint_mobile/widgets/dashboard/document_scan_cta.dart';
import 'package:mint_mobile/widgets/dashboard/replacement_ratio_badge.dart';
import 'package:mint_mobile/widgets/dashboard/retirement_checklist_card.dart';

// ────────────────────────────────────────────────────────────
//  RETIREMENT DASHBOARD SCREEN — LOT 4 / MINT Coach
// ────────────────────────────────────────────────────────────
//
//  Orchestrateur du tableau de bord retraite a 3 etats :
//
//  STATE A (confiance >= 70%) — Tableau de bord complet (cockpit)
//    ConfidenceBar + HeroRetirementCard (full) + ReplacementRatioBadge
//    + TrajectoryCard + PillarDecomposition + BudgetGapCard
//    + ArbitrageTeaserSection (age >= 45)
//    + CouplePhaseTimeline (si couple)
//    + RetirementChecklistCard
//    + ImpactMintCard + EarlyRetirementComparison
//    + MintScoreGauge + ExploreHub
//
//  STATE B (confiance 40-69%) — Projection partielle + enrichissement
//    ConfidenceBar + HeroRetirementCard (range) + DocumentScanCta
//    + DataQualityCard + LowConfidenceCard + ExploreHub
//
//  STATE C (confiance < 40% ou pas de profil) — Educatif, aucun chiffre
//    HeroRetirementCard (educational) + ExploreHub
//
//  Chantier 2 : Retirement Cockpit — unified command center.
//
//  Aucun terme banni (garanti, certain, optimal, meilleur…).
//  Tous les chiffres sont calcules a partir du profil reel.
// ────────────────────────────────────────────────────────────

class RetirementDashboardScreen extends StatefulWidget {
  const RetirementDashboardScreen({super.key});

  @override
  State<RetirementDashboardScreen> createState() =>
      _RetirementDashboardScreenState();
}

class _RetirementDashboardScreenState
    extends State<RetirementDashboardScreen> {
  CoachProfile? _profile;
  FinancialFitnessScore? _score;
  ProjectionResult? _projection;
  ProjectionResult? _baselineProjection;
  RetirementProjectionResult? _retirementProjection;
  double _confidenceScore = 0;
  ProjectionConfidence? _confidence;

  // ────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ────────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<CoachProfileProvider>();
    if (!provider.hasProfile) {
      _profile = null;
      _projection = null;
      _confidence = null;
      _confidenceScore = 0;
      return;
    }

    final newProfile = provider.profile!;
    if (_profile == newProfile) return;

    _profile = newProfile;
    try {
      _score = FinancialFitnessService.calculate(
        profile: _profile!,
        previousScore: provider.previousScore,
      );
      _projection = ForecasterService.project(profile: _profile!);
      _confidence = ConfidenceScorer.score(_profile!);
      _confidenceScore = _confidence!.score;

      // Detailed retirement projection (budget gap, phases, etc.)
      _retirementProjection =
          RetirementProjectionService.project(profile: _profile!);

      // Baseline sans contributions pour calcul delta MINT
      if (_profile!.plannedContributions.isNotEmpty) {
        final profileSans = _profile!.copyWithContributions(const []);
        _baselineProjection =
            ForecasterService.project(profile: profileSans);
      } else {
        _baselineProjection = null;
      }
    } catch (e) {
      debugPrint('RetirementDashboard: projection error: $e');
      _projection = null;
      _confidence = null;
      _confidenceScore = 0;
    }
  }

  // ────────────────────────────────────────────────────────────
  //  BUILD — DISPATCH SELON L'ETAT
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CoachProfileProvider>();

    if (!provider.hasProfile || _projection == null) {
      return _buildStateC();
    }

    if (_confidenceScore >= 70 && _score != null) {
      return _buildStateA();
    }
    if (_confidenceScore >= 40 && _score != null) {
      return _buildStateB();
    }
    return _buildStateC();
  }

  // ────────────────────────────────────────────────────────────
  //  STATE A — Profil riche (>= 70% confiance)
  // ────────────────────────────────────────────────────────────

  Widget _buildStateA() {
    final proj = _projection!;
    final profile = _profile!;
    final score = _score!;
    final retProj = _retirementProjection;

    // Revenu mensuel base scenario
    final monthlyIncome = proj.base.revenuAnnuelRetraite / 12;
    final monthlyPrudent = proj.prudent.revenuAnnuelRetraite / 12;
    final monthlyOptimiste = proj.optimiste.revenuAnnuelRetraite / 12;

    // Decomposition par pilier (scenario base)
    final decoBase = proj.base.decomposition;
    final avsMonthly =
        ((decoBase['avs'] ?? 0)) / 12;
    final lppMonthly =
        (((decoBase['lpp_user'] ?? 0) + (decoBase['lpp_conjoint'] ?? 0))) / 12;
    final threeAMonthly = ((decoBase['3a'] ?? 0)) / 12;
    final freeMonthly = ((decoBase['libre'] ?? 0)) / 12;

    // ImpactMintCard
    final baselineMonthly = _baselineProjection != null
        ? _baselineProjection!.base.revenuAnnuelRetraite / 12
        : monthlyIncome;
    final impactDescription = _buildImpactDescription();

    // Couple phase data
    final isCouple = profile.isCouple && profile.conjoint?.birthYear != null;
    final hasPhases =
        retProj != null && retProj.phases.length >= 2;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(profile.firstName),
          SliverPadding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ConfidenceBar(score: _confidenceScore),
                const SizedBox(height: 16),

                // 1. Hero number (monthly income at retirement)
                HeroRetirementCard(
                  mode: HeroCardMode.full,
                  monthlyIncome: monthlyIncome,
                  replacementRatio: proj.tauxRemplacementBase,
                  rangeMin: monthlyPrudent,
                  rangeMax: monthlyOptimiste,
                ),
                const SizedBox(height: 12),

                // 2. Replacement ratio badge (prominent)
                ReplacementRatioBadge(
                  ratio: proj.tauxRemplacementBase,
                ),
                const SizedBox(height: 16),

                // 3. Budget gap card
                if (retProj != null) ...[
                  BudgetGapCard(budgetGap: retProj.budgetGap),
                  const SizedBox(height: 16),
                ],

                // 4. Trajectory card
                TrajectoryCard(
                  profile: profile,
                  projection: proj,
                ),
                const SizedBox(height: 16),

                // 5. Pillar decomposition
                PillarDecomposition(
                  avsMonthly: avsMonthly,
                  lppMonthly: lppMonthly,
                  threeAMonthly: threeAMonthly,
                  freeMonthly: freeMonthly,
                ),
                const SizedBox(height: 16),

                // 6. Arbitrage teasers (age >= 45)
                if (profile.age >= 45) ...[
                  ArbitrageTeaserSection(profile: profile),
                  const SizedBox(height: 16),
                ],

                // 7. Couple phase timeline
                if (isCouple && hasPhases) ...[
                  CouplePhaseTimeline(
                    userName: profile.firstName ?? 'Toi',
                    conjointName:
                        profile.conjoint!.firstName ?? 'Conjoint\u00b7e',
                    userRetirementYear: profile.birthYear + 65,
                    conjointRetirementYear:
                        profile.conjoint!.birthYear! + 65,
                    phases: retProj.phases,
                  ),
                  const SizedBox(height: 16),
                ],

                // 8. Personalized checklist
                RetirementChecklistCard(profile: profile),
                const SizedBox(height: 16),

                // 9. Impact MINT card
                ImpactMintCard(
                  withoutOptimization: baselineMonthly,
                  withOptimization: monthlyIncome,
                  description: impactDescription,
                ),
                if (profile.age >= 45) ...[
                  const SizedBox(height: 16),
                  EarlyRetirementComparison(profile: profile),
                ],
                const SizedBox(height: 16),

                // 10. MINT Score
                MintScoreGauge(
                  score: score.global,
                  budgetScore: score.budget.score,
                  prevoyanceScore: score.prevoyance.score,
                  patrimoineScore: score.patrimoine.score,
                  trend: score.trend.name,
                  previousScore: score.deltaVsPreviousMonth != null
                      ? score.global - (score.deltaVsPreviousMonth ?? 0)
                      : null,
                  onTap: () => context.push('/coach/dashboard'),
                ),
                const SizedBox(height: 16),

                // 11. Explore hub
                const ExploreHub(),
                const SizedBox(height: 24),
                _buildDisclaimer(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  STATE B — Profil partiel (40-69% confiance)
  // ────────────────────────────────────────────────────────────

  Widget _buildStateB() {
    final proj = _projection!;
    final profile = _profile!;
    final score = _score!;

    final monthlyPrudent = proj.prudent.revenuAnnuelRetraite / 12;
    final monthlyOptimiste = proj.optimiste.revenuAnnuelRetraite / 12;

    final knownFields = _buildKnownFields(profile);
    final missingFields = _buildMissingFields();
    final totalImpact = _confidence?.prompts
        .take(3)
        .fold<int>(0, (sum, p) => sum + p.impact) ?? 0;

    // Estimate confidence improvement from LPP scan
    final hasLppData = (profile.prevoyance.avoirLppTotal ?? 0) > 0;
    final estimatedAfterScan = hasLppData
        ? (_confidenceScore + 10).clamp(0.0, 95.0)
        : (_confidenceScore + 20).clamp(0.0, 95.0);

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(profile.firstName),
          SliverPadding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ConfidenceBar(score: _confidenceScore),
                const SizedBox(height: 16),
                HeroRetirementCard(
                  mode: HeroCardMode.range,
                  rangeMin: monthlyPrudent,
                  rangeMax: monthlyOptimiste,
                ),
                const SizedBox(height: 16),

                // Document Scan CTA (prominent in State B)
                DocumentScanCta(
                  currentConfidence: _confidenceScore,
                  estimatedConfidenceAfterScan: estimatedAfterScan,
                ),
                const SizedBox(height: 16),

                DataQualityCard(
                  knownFields: knownFields,
                  missingFields: missingFields,
                  enrichImpact:
                      totalImpact > 0 ? '+$totalImpact% pr\u00e9cision' : null,
                  onEnrich: () => context.push('/onboarding/smart'),
                ),
                const SizedBox(height: 16),
                LowConfidenceCard(profile: profile),
                const SizedBox(height: 16),
                MintScoreGauge(
                  score: score.global,
                  budgetScore: score.budget.score,
                  prevoyanceScore: score.prevoyance.score,
                  patrimoineScore: score.patrimoine.score,
                  trend: score.trend.name,
                  previousScore: score.deltaVsPreviousMonth != null
                      ? score.global - (score.deltaVsPreviousMonth ?? 0)
                      : null,
                  onTap: () => context.push('/coach/dashboard'),
                ),
                const SizedBox(height: 16),
                const ExploreHub(),
                const SizedBox(height: 24),
                _buildDisclaimer(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  STATE C — Donnees insuffisantes / pas de profil (< 40%)
  // ────────────────────────────────────────────────────────────

  Widget _buildStateC() {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(null),
          SliverPadding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                HeroRetirementCard(
                  mode: HeroCardMode.educational,
                  onCompleteProfil: () => context.push('/onboarding/smart'),
                ),
                const SizedBox(height: 16),
                _buildEducationalSection(),
                const SizedBox(height: 16),
                const ExploreHub(),
                const SizedBox(height: 24),
                _buildDisclaimer(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  APPBAR
  // ────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(String? firstName) {
    final greeting = firstName != null && firstName.isNotEmpty
        ? 'Retraite · $firstName'
        : 'Ma retraite';

    return SliverAppBar(
      expandedHeight: 80,
      floating: true,
      snap: true,
      backgroundColor: MintColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          greeting,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 12),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined,
              color: MintColors.textSecondary),
          onPressed: () => context.push('/onboarding/smart'),
          tooltip: 'Modifier le profil',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  EDUCATIONAL SECTION (STATE C)
  // ────────────────────────────────────────────────────────────

  Widget _buildEducationalSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Le syst\u00e8me de retraite suisse',
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _buildEducationalPoint(
            icon: Icons.shield_outlined,
            color: MintColors.retirementAvs,
            title: '1er pilier — AVS',
            text: 'Base obligatoire pour tous. Finan\u00e7\u00e9 par tes cotisations (LAVS art. 21).',
          ),
          const SizedBox(height: 8),
          _buildEducationalPoint(
            icon: Icons.account_balance_outlined,
            color: MintColors.retirementLpp,
            title: '2\u00e8me pilier — LPP',
            text: 'Pr\u00e9voyance professionnelle via ta caisse de pension (LPP art. 14).',
          ),
          const SizedBox(height: 8),
          _buildEducationalPoint(
            icon: Icons.savings_outlined,
            color: MintColors.retirement3a,
            title: '3\u00e8me pilier — 3a',
            text: '\u00c9pargne volontaire avec d\u00e9duction fiscale jusqu\u00e0 CHF\u00a07\'258/an (OPP3 art. 7).',
          ),
        ],
      ),
    );
  }

  Widget _buildEducationalPoint({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  DISCLAIMER
  // ────────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Text(
      'Outil \u00e9ducatif simplifi\u00e9. Ne constitue pas un conseil financier (LSFin). '
      'Sources\u00a0: LAVS art. 21-29, LPP art. 14, OPP3 art. 7.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textMuted,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  HELPERS
  // ────────────────────────────────────────────────────────────

  /// Description de l'impact MINT (bases sur les contributions planifiees).
  String _buildImpactDescription() {
    final profile = _profile;
    if (profile == null) return 'gr\u00e2ce \u00e0 tes actions de pr\u00e9voyance';

    final has3a = profile.total3aMensuel > 0;
    final hasLpp = profile.totalLppBuybackMensuel > 0;

    if (has3a && hasLpp) {
      return 'gr\u00e2ce au 3e pilier et au rachat LPP';
    } else if (has3a) {
      return 'gr\u00e2ce au 3e pilier';
    } else if (hasLpp) {
      return 'gr\u00e2ce au rachat LPP';
    }
    return 'gr\u00e2ce \u00e0 tes contributions planifi\u00e9es';
  }

  /// Champs connus du profil pour DataQualityCard.
  List<String> _buildKnownFields(CoachProfile profile) {
    final fields = <String>[];

    if (profile.salaireBrutMensuel > 0) {
      fields.add(
          'Salaire\u00a0: CHF\u00a0${formatChf(profile.salaireBrutMensuel)}/mois');
    }
    if (profile.canton.isNotEmpty) {
      fields.add('Canton\u00a0: ${profile.canton}');
    }
    if (profile.age > 0) {
      fields.add('Age\u00a0: ${profile.age} ans');
    }
    if ((profile.prevoyance.avoirLppTotal ?? 0) > 0) {
      fields.add(
          'LPP\u00a0: CHF\u00a0${formatChf(profile.prevoyance.avoirLppTotal!)}');
    }
    if (profile.prevoyance.totalEpargne3a > 0) {
      fields.add(
          '3e pilier\u00a0: CHF\u00a0${formatChf(profile.prevoyance.totalEpargne3a)}');
    }

    return fields;
  }

  /// Champs manquants a partir des prompts de confiance.
  List<String> _buildMissingFields() {
    if (_confidence == null) return [];
    return _confidence!.prompts
        .take(4)
        .map((p) => p.label)
        .toList();
  }

}
