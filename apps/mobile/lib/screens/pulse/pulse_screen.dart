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
import 'package:mint_mobile/services/financial_core/fri_calculator.dart';
import 'package:mint_mobile/services/fri_computation_service.dart';
import 'package:mint_mobile/services/temporal_priority_service.dart';
import 'package:mint_mobile/services/response_card_service.dart';
import 'package:mint_mobile/services/micro_action_engine.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/visibility_score_service.dart';
import 'package:mint_mobile/services/monthly_briefing_service.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
  List<ResponseCard> _responseCards = const [];

  // ── Cached projections (avoid 3x ForecasterService calls) ──
  ProjectionResult? _cachedProjection;
  MonthlyBriefingDelta? _cachedBriefing;
  FriBreakdown? _cachedFri;

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

    // ── Cache projection (used by key figures + couple + FRI) ──
    try {
      _cachedProjection = ForecasterService.project(profile: profile);
    } catch (_) {
      _cachedProjection = null;
    }

    // ── Compute FRI (Financial Readiness Index) ──────────
    _cachedFri = _computeFri(profile);

    // ── Compute temporal items (uses FRI) ───────────────
    _computeTemporalItems(profile);

    // ── Generate response cards (synchronous) ─────────────
    _responseCards = ResponseCardService.generate(
      profile: profile,
      limit: 4,
    );

    // ── Monthly briefing (post-check-in banner) ──────────
    _cachedBriefing = MonthlyBriefingService.fromProfile(profile);

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

    final fri = _cachedFri;
    _temporalItems = TemporalPriorityService.prioritize(
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      taxSaving3a: taxSaving3a,
      friTotal: fri?.total ?? 0,
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

    // ── Response cards (computed once in didChangeDependencies) ────
    final cards = _responseCards;

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

              // 2b. Score history sparkline
              if (coachProvider.scoreHistory.length >= 2)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ScoreSparkline(
                    history: coachProvider.scoreHistory,
                  ),
                ),
              const SizedBox(height: 16),

              // 2c. Post-check-in briefing banner
              if (_cachedBriefing != null)
                Padding(
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, bottom: 16),
                  child: _buildBriefingBanner(_cachedBriefing!),
                ),

              // 2c-bis. No check-in nudge (coaching loop bridge)
              if (_cachedBriefing == null &&
                  !_hasCheckInThisMonth(profile))
                Padding(
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, bottom: 16),
                  child: _buildNoCheckInBanner(context),
                ),

              // 2d. FRI — Financial Readiness Index
              if (_cachedFri != null && visibilityScore.total >= 50)
                Padding(
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, bottom: 16),
                  child: _buildFriCard(_cachedFri!),
                ),

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
                  child: Builder(builder: (context) {
                    final l = S.of(context)!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.pulsePrioritiesTitle,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: MintColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.pulsePrioritiesSubtitle,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: MintColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 12),
                ResponseCardStrip(cards: cards),
                const SizedBox(height: 24),
              ],

              // 5. Section Comprendre
              ComprendreSection(),
              const SizedBox(height: 24),

              // 6. Disclaimer (toujours visible)
              PulseDisclaimer(),
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
    final l = S.of(context)!;
    // Retirement projection (from cache)
    double? retraiteEstimee;
    double? tauxRemplacement;
    if (_cachedProjection != null) {
      retraiteEstimee =
          _cachedProjection!.base.revenuAnnuelRetraite / 12;
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
        (profile.prevoyance.totalEpargne3a ?? 0);

    return Row(
      children: [
        Expanded(
          child: _KeyFigureCard(
            label: l.pulseKeyFigRetraite,
            value: retraiteEstimee != null
                ? 'CHF ${retraiteEstimee.round()}/mois'
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
          child: _KeyFigureCard(
            label: l.pulseKeyFigBudgetLibre,
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
            label: l.pulseKeyFigPatrimoine,
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
    final l = S.of(context)!;
    final conjName = profile.conjoint?.firstName ?? 'ton conjoint';
    final firstName = profile.firstName ?? 'Toi';

    // Couple projection (from cache)
    String? coupleRevenu;
    if (_cachedProjection != null) {
      final monthlyCouple =
          _cachedProjection!.base.revenuAnnuelRetraite / 12;
      coupleRevenu = 'CHF ${monthlyCouple.round()}/mois';
    }

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
                      l.pulseCoupleRetraite(coupleRevenu!),
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
  //  POST-CHECK-IN BRIEFING BANNER (#2)
  // ────────────────────────────────────────────────────────

  bool _hasCheckInThisMonth(CoachProfile profile) {
    final now = DateTime.now();
    return profile.checkIns.any(
      (ci) => ci.month.year == now.year && ci.month.month == now.month,
    );
  }

  Widget _buildNoCheckInBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded,
              size: 16, color: MintColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aucun check-in ce mois. Enregistre tes versements '
              'pour suivre ta progression.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.go('/coach/checkin'),
            style: TextButton.styleFrom(
              foregroundColor: MintColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Check-in',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBriefingBanner(MonthlyBriefingDelta briefing) {
    final trendIcon = switch (briefing.trend) {
      BriefingTrend.enHausse => Icons.trending_up,
      BriefingTrend.enBaisse => Icons.trending_down,
      BriefingTrend.stable => Icons.trending_flat,
    };
    final trendColor = switch (briefing.trend) {
      BriefingTrend.enHausse => MintColors.success,
      BriefingTrend.enBaisse => MintColors.warning,
      BriefingTrend.stable => MintColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: trendColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(trendIcon, size: 16, color: trendColor),
              const SizedBox(width: 8),
              Text(
                'Bilan du mois \u2014 ${briefing.trendLabel}',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          if (briefing.insights.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              briefing.insights.first,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  //  FRI — Financial Readiness Index (#3)
  // ────────────────────────────────────────────────────────

  /// Delegate FRI computation to FriComputationService (financial_core bridge).
  /// Never duplicate calculation logic — anti-pattern #12.
  FriBreakdown _computeFri(CoachProfile profile) {
    if (_cachedProjection == null) {
      // Without projection, compute with minimal FriInput
      return FriCalculator.compute(const FriInput());
    }
    return FriComputationService.compute(
      profile: profile,
      projection: _cachedProjection!,
    );
  }

  Widget _buildFriCard(FriBreakdown fri) {
    final color = fri.total >= 65
        ? MintColors.success
        : fri.total >= 40
            ? MintColors.warning
            : MintColors.error;

    // Identify weakest component for guidance
    final components = {
      'Liquidite': fri.liquidite,
      'Optimisation fiscale': fri.fiscalite,
      'Retraite': fri.retraite,
      'Risques structurels': fri.risque,
    };
    final weakest = components.entries
        .reduce((a, b) => a.value <= b.value ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                'Solidite financiere',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${fri.total.round()} / 100',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4-bar gauge
          Row(
            children: [
              _FriBar(label: 'L', value: fri.liquidite, max: 25),
              const SizedBox(width: 6),
              _FriBar(label: 'F', value: fri.fiscalite, max: 25),
              const SizedBox(width: 6),
              _FriBar(label: 'R', value: fri.retraite, max: 25),
              const SizedBox(width: 6),
              _FriBar(label: 'S', value: fri.risque, max: 25),
            ],
          ),
          const SizedBox(height: 10),

          // Weakest point + action
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: MintColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Point le plus fragile : ${weakest.key}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
                    l.pulseEmptyTitle,
                    style: GoogleFonts.outfit(
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
                    onPressed: () {
                      context.push('/onboarding/smart');
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(l.pulseEmptyCtaStart),
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
                  PulseDisclaimer(),
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

// ────────────────────────────────────────────────────────
//  FRI BAR (single component gauge)
// ────────────────────────────────────────────────────────

class _FriBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;

  const _FriBar({
    required this.label,
    required this.value,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (value / max).clamp(0.0, 1.0);
    final color = ratio >= 0.7
        ? MintColors.success
        : ratio >= 0.4
            ? MintColors.warning
            : MintColors.error;

    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: MintColors.surface,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${value.round()}',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
//  SCORE SPARKLINE (#1)
// ────────────────────────────────────────────────────────

class _ScoreSparkline extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const _ScoreSparkline({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) return const SizedBox.shrink();

    // Extract scores, keep last 12 months
    final recent = history.length > 12
        ? history.sublist(history.length - 12)
        : history;
    final scores =
        recent.map((e) => (e['score'] as num?)?.toDouble() ?? 0).toList();
    final first = scores.first;
    final last = scores.last;
    final delta = last - first;
    final deltaColor =
        delta >= 0 ? MintColors.success : MintColors.warning;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // Sparkline chart
          Expanded(
            child: SizedBox(
              height: 28,
              child: CustomPaint(
                painter: _SparklinePainter(scores: scores),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Delta badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${delta >= 0 ? '+' : ''}${delta.round()} pts',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: deltaColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> scores;

  _SparklinePainter({required this.scores});

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2) return;

    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final range = (maxScore - minScore).clamp(1.0, 100.0);

    final paint = Paint()
      ..color = MintColors.primary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < scores.length; i++) {
      final x = i / (scores.length - 1) * size.width;
      final y =
          size.height - ((scores[i] - minScore) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Fill gradient under curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          MintColors.primary.withValues(alpha: 0.15),
          MintColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Last point dot
    final dotPaint = Paint()
      ..color = MintColors.primary
      ..style = PaintingStyle.fill;
    final lastX = size.width;
    final lastY = size.height -
        ((scores.last - minScore) / range * size.height);
    canvas.drawCircle(Offset(lastX, lastY), 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.scores != scores;
}
