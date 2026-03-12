import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/coach_narrative_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/visibility_score_service.dart';
import 'package:mint_mobile/services/micro_action_engine.dart';
import 'package:mint_mobile/services/temporal_priority_service.dart';
import 'package:mint_mobile/services/pulse_hero_engine.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/pulse/focus_selector.dart';
import 'package:mint_mobile/widgets/pulse/visibility_score_card.dart';
import 'package:mint_mobile/widgets/pulse/pulse_disclaimer.dart';

// ────────────────────────────────────────────────────────
//  PULSE SCREEN — Redesign V2 (3-act layout)
// ────────────────────────────────────────────────────────
//
//  ACT 1 (above fold): Greeting + Hero/FocusSelector
//        + 3 key figures + unified visibility score
//
//  ACT 2 (first scroll): Profile enrichment OR actions
//        + couple card if applicable
//
//  ACT 3 (deep scroll): Coach insight (dark card)
//        + disclaimer
//
//  Removed from Pulse (relocated):
//  - FRI card → merged into visibility score
//  - Response Cards → Agir tab
//  - Comprendre section → Apprendre tab
//  - Sparkline → Profil page
//  - Duplicate temporal items → 1 urgent item max
// ────────────────────────────────────────────────────────

class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  // ── Async state ───────────────────────────────────────────
  CoachNarrative? _narrative;
  int _narrativeGeneration = 0;

  // ── Cached projections ─────────────────────────────────────
  ProjectionResult? _cachedProjection;

  // ── Profile tracking ───────────────────────────────────────
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
      }
      return;
    }

    final profile = provider.profile!;
    if (_lastProfile == profile) return;
    _lastProfile = profile;

    // ── Cache projection ──
    try {
      _cachedProjection = ForecasterService.project(profile: profile);
    } catch (_) {
      _cachedProjection = null;
    }

    // ── Generate narrative (async, non-blocking) ──
    final tips = _buildCoachingTips(profile);
    unawaited(_generateNarrative(profile, tips, provider.scoreHistory));
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
        if (byok.isConfigured &&
            byok.apiKey != null &&
            byok.provider != null) {
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
  //  BUILD — 3-act layout
  // ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final coachProvider = context.watch<CoachProfileProvider>();

    if (!coachProvider.hasProfile) {
      return _buildEmptyState(context);
    }

    final profile = coachProvider.profile!;
    final visibilityScore = _computeVisibilityScore(profile);
    final hero = PulseHeroEngine.compute(profile);

    return CustomScrollView(
      slivers: [
        _buildAppBar(context, profile),

        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ═══════════════════════════════════════════
              //  ACT 1 — ABOVE THE FOLD
              // ═══════════════════════════════════════════

              // Hero card OR FocusSelector
              if (hero != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _HeroCard(
                    hero: hero,
                    onChangeFocus: () => _showFocusPicker(context, profile),
                  ),
                )
              else
                FocusSelector(
                  profile: profile,
                  onFocusSelected: (focus) => _setFocus(context, focus),
                ),

              const SizedBox(height: 20),

              // 3 key figures
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildKeyFigures(profile),
              ),
              const SizedBox(height: 16),

              // Unified visibility score
              VisibilityScoreCard(score: visibilityScore),
              const SizedBox(height: 8),

              // ═══════════════════════════════════════════
              //  ACT 2 — FIRST SCROLL
              // ═══════════════════════════════════════════

              // Enrichment OR action cards
              if (visibilityScore.total < 60)
                _buildEnrichmentSection(profile, visibilityScore.total)
              else
                _buildActionSection(profile),

              // Couple card
              if (profile.isCouple && profile.conjoint != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildCoupleCard(profile),
                ),
                const SizedBox(height: 16),
              ],

              // Single most urgent temporal item
              Builder(builder: (context) {
                final items = _getUrgentItems(profile);
                if (items.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _UrgentDeadlineChip(item: items.first),
                );
              }),

              const SizedBox(height: 16),

              // ═══════════════════════════════════════════
              //  ACT 3 — DEEP SCROLL
              // ═══════════════════════════════════════════

              // Coach insight (dark card)
              if (_narrative != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _CoachInsightCard(
                    narrative: _narrative!,
                    onEnrich: () => context.push('/profile/bilan'),
                  ),
                ),
              if (_narrative != null) const SizedBox(height: 16),

              // No-checkin nudge
              if (!_hasCheckInThisMonth(profile))
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildNoCheckInChip(context),
                ),

              const SizedBox(height: 16),

              // Disclaimer
              const PulseDisclaimer(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  //  ACT 1 — KEY FIGURES
  // ────────────────────────────────────────────────────────

  Widget _buildKeyFigures(CoachProfile profile) {
    final l = S.of(context)!;

    // Retirement projection
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
            color:
                budgetLibre >= 0 ? MintColors.success : MintColors.warning,
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
  //  ACT 2 — ENRICHMENT SECTION (profile < 60%)
  // ────────────────────────────────────────────────────────

  Widget _buildEnrichmentSection(CoachProfile profile, double score) {
    final pct = score.round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MintColors.primary.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_fix_high_outlined,
                    size: 18, color: MintColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Jumeau numérique : $pct%',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (score / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: MintColors.surface,
                valueColor:
                    AlwaysStoppedAnimation(MintColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Plus ton profil est complet, plus tes projections sont fiables.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            // Max 2 enrichment actions
            ..._enrichmentActions(profile).take(2).map((action) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => context.push(action.route),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: MintColors.border.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(action.icon,
                            size: 16, color: MintColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            action.label,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: MintColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 12, color: MintColors.textMuted),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<_EnrichmentAction> _enrichmentActions(CoachProfile profile) {
    final actions = <_EnrichmentAction>[];

    if (profile.prevoyance.avoirLppTotal == null ||
        profile.prevoyance.avoirLppTotal == 0) {
      actions.add(const _EnrichmentAction(
        icon: Icons.upload_file_outlined,
        label: 'Ajoute ton certificat LPP (+15% de précision)',
        route: '/onboarding/smart',
      ));
    }
    if (profile.prevoyance.totalEpargne3a <= 0) {
      actions.add(const _EnrichmentAction(
        icon: Icons.savings_outlined,
        label: 'Renseigne ton 3e pilier',
        route: '/profile/bilan',
      ));
    }
    if (profile.patrimoine.totalPatrimoine <= 0) {
      actions.add(const _EnrichmentAction(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Ajoute ton épargne et investissements',
        route: '/profile/bilan',
      ));
    }
    if (!profile.isCouple &&
        (profile.etatCivil == CoachCivilStatus.marie || profile.etatCivil == CoachCivilStatus.concubinage)) {
      actions.add(const _EnrichmentAction(
        icon: Icons.people_outline,
        label: 'Invite ton conjoint·e (+20% de précision)',
        route: '/profile/bilan',
      ));
    }

    return actions;
  }

  // ────────────────────────────────────────────────────────
  //  ACT 2 — ACTION SECTION (profile >= 60%)
  // ────────────────────────────────────────────────────────

  Widget _buildActionSection(CoachProfile profile) {
    final actions = MicroActionEngine.suggest(profile: profile);
    if (actions.isEmpty) return const SizedBox.shrink();

    // Show max 2 actions
    final topActions = actions.take(2).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'À faire ce mois',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...topActions.map((action) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => context.push(action.deeplink),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MintColors.border.withValues(alpha: 0.5),
                    ),
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MintColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          action.icon,
                          size: 18,
                          color: MintColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action.title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: MintColors.textPrimary,
                              ),
                            ),
                            Text(
                              action.description,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: MintColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 12, color: MintColors.textMuted),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  //  COUPLE CARD
  // ────────────────────────────────────────────────────────

  Widget _buildCoupleCard(CoachProfile profile) {
    final l = S.of(context)!;
    final conjName = profile.conjoint?.firstName ?? 'ton conjoint';
    final firstName = profile.firstName ?? 'Toi';

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
        border:
            Border.all(color: MintColors.primary.withValues(alpha: 0.15)),
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
                      l.pulseCoupleRetraite(coupleRevenu),
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
  //  URGENT DEADLINE (single chip — replaces temporal strip)
  // ────────────────────────────────────────────────────────

  List<TemporalItem> _getUrgentItems(CoachProfile profile) {
    final taxSaving3a = profile.salaireBrutMensuel > 0
        ? pilier3aPlafondAvecLpp *
            RetirementTaxCalculator.estimateMarginalRate(
                profile.revenuBrutAnnuel, profile.canton)
        : 0.0;

    return TemporalPriorityService.prioritize(
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      taxSaving3a: taxSaving3a,
      friTotal: 0,
      friDelta: 0,
      limit: 1,
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

  bool _hasCheckInThisMonth(CoachProfile profile) {
    final now = DateTime.now();
    return profile.checkIns.any(
      (ci) => ci.month.year == now.year && ci.month.month == now.month,
    );
  }

  // ────────────────────────────────────────────────────────
  //  FOCUS PICKER (bottom sheet to change focus)
  // ────────────────────────────────────────────────────────

  void _showFocusPicker(BuildContext context, CoachProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
    final provider = context.read<CoachProfileProvider>();
    provider.updatePrimaryFocus(focus);
  }

  // ────────────────────────────────────────────────────────
  //  NO CHECK-IN CHIP
  // ────────────────────────────────────────────────────────

  Widget _buildNoCheckInChip(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/coach/checkin'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                S.of(context)!.pulseNoCheckinMsg,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.pulseCheckinBtn,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MintColors.primary,
              ),
            ),
          ],
        ),
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
          colors: [
            hero.color,
            hero.color.withValues(alpha: 0.85),
          ],
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
              Icon(hero.icon, size: 22, color: Colors.white.withValues(alpha: 0.9)),
              const Spacer(),
              // Change focus button
              GestureDetector(
                onTap: onChangeFocus,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded,
                          size: 14, color: Colors.white.withValues(alpha: 0.9)),
                      const SizedBox(width: 4),
                      Text(
                        'Changer',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.9),
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
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hero.subtitle,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.3,
            ),
          ),
          if (hero.detail != null) ...[
            const SizedBox(height: 8),
            Text(
              hero.detail!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
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
                color: Colors.white,
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
//  KEY FIGURE CARD
// ────────────────────────────────────────────────────────

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
//  URGENT DEADLINE CHIP (single item, replaces strip)
// ────────────────────────────────────────────────────────

class _UrgentDeadlineChip extends StatelessWidget {
  final TemporalItem item;

  const _UrgentDeadlineChip({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 16, color: MintColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            item.timeConstraint,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MintColors.warning,
            ),
          ),
        ],
      ),
    );
  }

}

// ────────────────────────────────────────────────────────
//  COACH INSIGHT CARD — Dark card (Act 3)
// ────────────────────────────────────────────────────────

class _CoachInsightCard extends StatelessWidget {
  final CoachNarrative narrative;
  final VoidCallback onEnrich;

  const _CoachInsightCard({
    required this.narrative,
    required this.onEnrich,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  narrative.isLlmGenerated
                      ? Icons.auto_awesome
                      : Icons.lightbulb_outline,
                  size: 16,
                  color: MintColors.primaryLight,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'L\'insight du coach',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (narrative.isLlmGenerated) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'IA',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            narrative.scoreSummary,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          if (narrative.topTipNarrative != null) ...[
            const SizedBox(height: 8),
            Text(
              narrative.topTipNarrative!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onEnrich,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: MintColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Affiner mon profil',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.primaryLight,
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
//  ENRICHMENT ACTION (data model)
// ────────────────────────────────────────────────────────

class _EnrichmentAction {
  final IconData icon;
  final String label;
  final String route;

  const _EnrichmentAction({
    required this.icon,
    required this.label,
    required this.route,
  });
}
