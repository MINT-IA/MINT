import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/coach_narrative_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/temporal_priority_service.dart';
import 'package:mint_mobile/services/response_card_service.dart';
import 'package:mint_mobile/services/micro_action_engine.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/visibility_score_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/coach_briefing_card.dart';
import 'package:mint_mobile/widgets/coach/micro_action_card.dart';
import 'package:mint_mobile/widgets/coach/response_card_widget.dart';
import 'package:mint_mobile/widgets/coach/temporal_strip.dart';
import 'package:mint_mobile/widgets/pulse/visibility_score_card.dart';
import 'package:mint_mobile/widgets/pulse/comprendre_section.dart';
import 'package:mint_mobile/widgets/pulse/pulse_disclaimer.dart';

// ────────────────────────────────────────────────────────────
//  PULSE SCREEN — S48 / Phase 0
// ────────────────────────────────────────────────────────────
//
//  Dashboard scannable : l'utilisateur voit sa situation
//  SANS rien taper. Data-first, pas chat-first.
//
//  Contenu :
//  1. Coach briefing (narrative LLM/templates, async)
//  2. Score de visibilite financiere (4 axes, 25/25/25/25)
//  3. Temporal strip (echeances urgentes : 3a, fiscal, etc.)
//  4. Actions prioritaires (max 3 enrichment prompts)
//  5. Section "Comprendre" (liens vers simulateurs)
//  6. Micro-disclaimer inline (toujours visible)
//
//  Couple mode : si isCouple + conjoint renseigne,
//  affiche le score couple + alerte point faible.
//
//  Le score mesure ce que l'utilisateur SAIT de sa situation,
//  pas la qualite de sa situation. "Visibilite", pas "sante".
//
//  Aucun terme banni (garanti, certain, optimal, meilleur...).
//  CTA educatifs : "Simuler", "Explorer", jamais prescriptif.
// ────────────────────────────────────────────────────────────

class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  // ── Async state ───────────────────────────────────────────
  CoachNarrative? _narrative;
  int _narrativeGeneration = 0;
  List<TemporalItem> _temporalItems = const [];

  // ── Profile tracking (avoid unnecessary recomputation) ───
  CoachProfile? _lastProfile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final provider = context.watch<CoachProfileProvider>();
    if (!provider.hasProfile) {
      if (_lastProfile != null) {
        _lastProfile = null;
        _narrativeGeneration++;
        _narrative = null;
        _temporalItems = const [];
      }
      return;
    }

    final profile = provider.profile!;
    if (_lastProfile == profile) return;
    _lastProfile = profile;

    // ── Compute temporal items (synchronous) ──────────────
    _computeTemporalItems(profile);

    // ── Generate narrative (async, non-blocking) ──────────
    final tips = _buildCoachingTips(profile);
    unawaited(_generateNarrative(profile, tips, provider.scoreHistory));
  }

  // ────────────────────────────────────────────────────────
  //  TEMPORAL ITEMS
  // ────────────────────────────────────────────────────────

  void _computeTemporalItems(CoachProfile profile) {
    final taxSaving3a = profile.salaireBrutMensuel > 0
        ? pilier3aPlafondAvecLpp *
            RetirementTaxCalculator.estimateMarginalRate(
                profile.revenuBrutAnnuel, profile.canton)
        : 0.0;

    _temporalItems = TemporalPriorityService.prioritize(
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      taxSaving3a: taxSaving3a,
      friTotal: 0,
      friDelta: 0,
      limit: 4,
    );
  }

  // ────────────────────────────────────────────────────────
  //  COACH NARRATIVE (async)
  // ────────────────────────────────────────────────────────

  List<CoachingTip> _buildCoachingTips(CoachProfile profile) {
    try {
      return CoachingService.generateTips(
        profile: profile.toCoachingProfile(),
      );
    } catch (e) {
      debugPrint('PulseScreen: tips error: $e');
      return [];
    }
  }

  Future<void> _generateNarrative(
    CoachProfile profile,
    List<CoachingTip> tips,
    List<Map<String, dynamic>> scoreHistory,
  ) async {
    final gen = ++_narrativeGeneration;

    try {
      LlmConfig? byokConfig;
      if (mounted) {
        final byok = context.read<ByokProvider>();
        if (byok.isConfigured && byok.apiKey != null && byok.provider != null) {
          final provider = switch (byok.provider) {
            'claude' => LlmProvider.anthropic,
            'mistral' => LlmProvider.mistral,
            'openai' => LlmProvider.openai,
            _ => null,
          };
          if (provider != null) {
            byokConfig = LlmConfig(
              apiKey: byok.apiKey!,
              provider: provider,
            );
          }
        }
      }

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
        byokConfig: byokConfig,
      );

      if (mounted && gen == _narrativeGeneration) {
        setState(() => _narrative = narrative);
      }
    } catch (e) {
      debugPrint('PulseScreen: narrative error: $e');
      if (mounted && gen == _narrativeGeneration) {
        setState(() => _narrative = null);
      }
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

    // ── Compute visibility score (couple-aware) ──────────
    final visibilityScore = _computeVisibilityScore(profile);

    // ── Response cards (computed once, not per-build) ────
    final cards = _responseCards(profile, visibilityScore);

    return CustomScrollView(
      slivers: [
        _buildAppBar(context, profile),

        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // 1. Coach briefing (narrative)
              if (_narrative != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: CoachBriefingCard(
                    narrative: _narrative,
                    confidenceScore: visibilityScore.total,
                    isLlmGenerated: _narrative?.isLlmGenerated ?? false,
                    onEnrich: () => context.push('/profile/bilan'),
                  ),
                ),
              if (_narrative != null) const SizedBox(height: 16),

              // 2. Score de visibilite
              VisibilityScoreCard(score: visibilityScore),
              const SizedBox(height: 16),

              // 3. Key figures (retraite + budget + patrimoine)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildKeyFigures(profile),
              ),
              const SizedBox(height: 16),

              // 3b. Couple card (first-class, if applicable)
              if (profile.isCouple && profile.conjoint != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildCoupleCard(profile),
                ),
              if (profile.isCouple && profile.conjoint != null)
                const SizedBox(height: 16),

              // 4. Temporal strip (echeances urgentes)
              if (_temporalItems.isNotEmpty) ...[
                TemporalStrip(items: _temporalItems),
                const SizedBox(height: 20),
              ],

              // 4b. Micro-actions (Coach Vivant)
              Builder(builder: (context) {
                final actions = MicroActionEngine.suggest(profile: profile);
                if (actions.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      MicroActionSection(actions: actions),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              }),

              // 5. Response Cards dynamiques (Phase 1)
              if (cards.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Tes priorites',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Actions personnalisees selon ton profil',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ResponseCardStrip(cards: cards),
                const SizedBox(height: 24),
              ],

              // 5. Section Comprendre
              const ComprendreSection(),
              const SizedBox(height: 24),

              // 6. Disclaimer (toujours visible)
              const PulseDisclaimer(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  //  KEY FIGURES — retraite, budget, patrimoine
  // ────────────────────────────────────────────────────────

  Widget _buildKeyFigures(CoachProfile profile) {
    // Retirement projection (base scenario)
    double? retraiteEstimee;
    double? tauxRemplacement;
    try {
      final projection = ForecasterService.project(profile: profile);
      retraiteEstimee = projection.base.revenuAnnuelRetraite / 12;
      final revenuActuel = profile.salaireBrutMensuel > 0
          ? NetIncomeBreakdown.compute(
              grossSalary: profile.salaireBrutMensuel * 12,
              canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
              age: DateTime.now().year - profile.birthYear,
            ).monthlyNetPayslip
          : 0.0;
      if (revenuActuel > 0) {
        tauxRemplacement = (retraiteEstimee / revenuActuel * 100);
      }
    } catch (_) {}

    // Budget libre
    final depMensuelles = profile.totalDepensesMensuelles;
    final revenuNet = profile.salaireBrutMensuel > 0
        ? NetIncomeBreakdown.compute(
            grossSalary: profile.salaireBrutMensuel * 12,
            canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
            age: DateTime.now().year - profile.birthYear,
          ).monthlyNetPayslip
        : 0.0;
    final budgetLibre = revenuNet - depMensuelles;

    // Patrimoine total
    final patrimoine = profile.patrimoine.totalPatrimoine +
        (profile.prevoyance.avoirLppTotal ?? 0) +
        (profile.prevoyance.totalEpargne3a ?? 0);

    return Row(
      children: [
        Expanded(
          child: _KeyFigureCard(
            label: 'Retraite estimee',
            value: retraiteEstimee != null
                ? 'CHF ${retraiteEstimee.round()}/mois'
                : '\u2014',
            subtitle: tauxRemplacement != null
                ? '${tauxRemplacement.round()}% du revenu'
                : null,
            icon: Icons.beach_access_outlined,
            color: MintColors.primary,
            onTap: () => context.push('/retirement'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KeyFigureCard(
            label: 'Budget libre',
            value: budgetLibre > 0
                ? '+CHF ${budgetLibre.round()}/m'
                : 'CHF ${budgetLibre.round()}/m',
            icon: Icons.account_balance_wallet_outlined,
            color: budgetLibre >= 0 ? MintColors.success : MintColors.warning,
            onTap: () => context.push('/budget'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KeyFigureCard(
            label: 'Patrimoine',
            value: patrimoine >= 1000
                ? 'CHF ${(patrimoine / 1000).round()}k'
                : 'CHF ${patrimoine.round()}',
            icon: Icons.trending_up_outlined,
            color: MintColors.info,
            onTap: () => context.push('/profile/bilan'),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  //  COUPLE CARD — first class
  // ────────────────────────────────────────────────────────

  Widget _buildCoupleCard(CoachProfile profile) {
    final conjName = profile.conjoint?.firstName ?? 'ton conjoint';
    final firstName = profile.firstName ?? 'Toi';

    // Try couple projection
    String? coupleRevenu;
    try {
      final projection = ForecasterService.project(profile: profile);
      final monthlyCouple = projection.base.revenuAnnuelRetraite / 12;
      coupleRevenu = 'CHF ${monthlyCouple.round()}/mois';
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/profile/bilan'),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.people_outline,
                  size: 24, color: MintColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$firstName + $conjName',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  if (coupleRevenu != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Retraite couple : $coupleRevenu',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
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

  // ────────────────────────────────────────────────────────
  //  RESPONSE CARDS — dynamic, contextual
  // ────────────────────────────────────────────────────────

  List<ResponseCard> _responseCards(
    CoachProfile profile,
    VisibilityScore score,
  ) {
    return ResponseCardService.generateForPulse(
      profile,
      limit: 3,
      visibilityScore: score,
    );
  }

  // ────────────────────────────────────────────────────────
  //  VISIBILITY SCORE — couple-aware
  // ────────────────────────────────────────────────────────

  VisibilityScore _computeVisibilityScore(CoachProfile profile) {
    if (profile.isCouple &&
        profile.conjoint != null &&
        _hasMinimalConjointData(profile.conjoint!)) {
      return VisibilityScoreService.computeCouple(
        profile,
        _conjointToCoachProfile(profile),
      );
    }
    return VisibilityScoreService.compute(profile);
  }

  bool _hasMinimalConjointData(ConjointProfile conjoint) {
    return conjoint.birthYear != null &&
        conjoint.salaireBrutMensuel != null &&
        conjoint.salaireBrutMensuel! > 0;
  }

  /// Construit un CoachProfile synthetique depuis ConjointProfile.
  CoachProfile _conjointToCoachProfile(CoachProfile mainProfile) {
    final conj = mainProfile.conjoint!;
    final retirementAge = conj.targetRetirementAge ?? 65;
    final birthYr = conj.birthYear ?? mainProfile.birthYear;
    return CoachProfile(
      firstName: conj.firstName,
      birthYear: birthYr,
      canton: mainProfile.canton,
      commune: mainProfile.commune,
      nationality: conj.nationality,
      salaireBrutMensuel: conj.salaireBrutMensuel ?? 0,
      nombreDeMois: conj.nombreDeMois,
      bonusPourcentage: conj.bonusPourcentage ?? 0,
      employmentStatus: conj.employmentStatus ?? 'salarie',
      etatCivil: mainProfile.etatCivil,
      arrivalAge: conj.arrivalAge,
      targetRetirementAge: conj.targetRetirementAge,
      prevoyance: conj.prevoyance ?? const PrevoyanceProfile(),
      patrimoine: conj.patrimoine ?? const PatrimoineProfile(),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(birthYr + retirementAge),
        label: 'Retraite',
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  //  APPBAR + EMPTY STATE
  // ────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(BuildContext context, CoachProfile profile) {
    final firstName = profile.firstName ?? 'toi';
    final greeting = profile.isCouple && profile.conjoint?.firstName != null
        ? 'Bonjour $firstName et ${profile.conjoint!.firstName}'
        : 'Bonjour $firstName';

    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: MintColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Text(
          greeting,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MintColors.primary,
                MintColors.primaryLight,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
              'Bienvenue sur MINT',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    MintColors.primary,
                    MintColors.primaryLight,
                  ],
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
                    'Commence par remplir ton profil',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Quelques questions suffisent pour obtenir '
                    'ta premiere estimation de visibilite financiere.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () {
                      context.push('/onboarding/smart');
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Demarrer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

/// Compact card for a single key figure (retraite, budget, patrimoine).
class _KeyFigureCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _KeyFigureCard({
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
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
              style: GoogleFonts.outfit(
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
