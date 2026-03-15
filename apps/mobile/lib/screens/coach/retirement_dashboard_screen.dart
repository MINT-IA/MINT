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
import 'package:mint_mobile/services/dashboard_curator_service.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/reengagement_engine.dart';
import 'package:mint_mobile/services/temporal_priority_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/services/slm/slm_auto_prompt_service.dart';
import 'package:mint_mobile/widgets/coach/retirement_hero_zone.dart';
import 'package:mint_mobile/widgets/coach/smart_shortcuts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  RETIREMENT DASHBOARD SCREEN — Hermeneutic Redesign
// ────────────────────────────────────────────────────────────
//
//  5 positions (from 18 → 5, -72% scroll depth):
//
//  0. UrgentBanner — temporal deadline < 60 days (conditional)
//  1. HeroZone — CHF/mois, replacement rate, pillar bar,
//     sparkline, confidence chip, coach one-liner
//  2. ActionCards — max 2 curated actions with CHF impact
//  3. SmartShortcuts — filtered chips to arbitrage/tools +
//     "Voir ton bilan détaillé" CTA
//  4. Footer — disclaimer + sources
//
//  STATE A (confiance >= 70%): Full hero, financial actions
//  STATE B (confiance < 70%): ~prefix, wide band, data enrichment card
//  STATE C (no profile): Onboarding CTA + educational card
//
//  Fallback chain: SLM → Templates → BYOK (privacy-first).
//  Aucun terme banni (garanti, certain, optimal, meilleur…).
// ────────────────────────────────────────────────────────────

class RetirementDashboardScreen extends StatefulWidget {
  const RetirementDashboardScreen({super.key});

  @override
  State<RetirementDashboardScreen> createState() =>
      _RetirementDashboardScreenState();
}

class _RetirementDashboardScreenState extends State<RetirementDashboardScreen> {
  // ── Core state ──────────────────────────────────────────
  CoachProfile? _profile;
  FinancialFitnessScore? _score;
  ProjectionResult? _projection;
  double _confidenceScore = 0;
  ProjectionConfidence? _confidence;

  // ── Coach narrative state ──────────────────────────────
  CoachNarrative? _narrative;
  int _narrativeGeneration = 0;
  String? _scoreHistorySignature;
  List<CuratedCard> _curatedCards = const [];
  List<TemporalItem> _temporalItems = const [];

  // ── Snapshot persistence ────────────────────────────────
  bool _snapshotPersisted = false;
  bool _slmPromptChecked = false;

  // ────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ────────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_slmPromptChecked) {
      _slmPromptChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) SlmAutoPromptService.checkAndPrompt(context);
      });
    }

    final provider = context.watch<CoachProfileProvider>();
    final newScoreHistorySignature =
        _computeScoreHistorySignature(provider.scoreHistory);

    if (!provider.hasProfile) {
      _profile = null;
      _projection = null;
      _confidence = null;
      _confidenceScore = 0;
      _scoreHistorySignature = null;
      _narrativeGeneration++;
      _narrative = null;
      _curatedCards = const [];
      _temporalItems = const [];
      return;
    }

    final newProfile = provider.profile!;
    if (_profile != null && _profile == newProfile) {
      if (_scoreHistorySignature == newScoreHistorySignature) return;
      _scoreHistorySignature = newScoreHistorySignature;
      final tips = _buildCoachingTips(newProfile);
      unawaited(_generateNarrative(tips, provider.scoreHistory));
      return;
    }

    _profile = newProfile;
    _scoreHistorySignature = newScoreHistorySignature;
    try {
      _score = FinancialFitnessService.calculate(
        profile: _profile!,
        previousScore: provider.previousScore,
      );
      _projection = ForecasterService.project(profile: _profile!);
      _confidence = ConfidenceScorer.score(_profile!);
      _confidenceScore = _confidence!.score;

      final tips = _buildCoachingTips(_profile!);
      _curateDashboardContent(tips);
      _persistInitialSnapshot(_profile!);
      unawaited(_generateNarrative(tips, provider.scoreHistory));
    } catch (e) {
      debugPrint('RetirementDashboard: projection error: $e');
      _projection = null;
      _confidence = null;
      _confidenceScore = 0;
      _narrativeGeneration++;
      _narrative = null;
      _curatedCards = const [];
      _temporalItems = const [];
    }
  }

  // ────────────────────────────────────────────────────────────
  //  NARRATIVE GENERATION
  // ────────────────────────────────────────────────────────────

  Future<void> _generateNarrative(
    List<CoachingTip> tips,
    List<Map<String, dynamic>> scoreHistory,
  ) async {
    final gen = ++_narrativeGeneration;
    final profile = _profile;
    if (profile == null) {
      if (mounted) setState(() => _narrative = null);
      return;
    }

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
        s: S.of(context)!,
        byokConfig: byokConfig,
      );

      if (mounted && gen == _narrativeGeneration) {
        setState(() => _narrative = narrative);
      }
    } catch (e) {
      debugPrint('RetirementDashboard: narrative error: $e');
      if (mounted && gen == _narrativeGeneration) {
        setState(() => _narrative = null);
      }
    }
  }

  List<CoachingTip> _buildCoachingTips(CoachProfile profile) {
    try {
      return CoachingService.generateTips(
        profile: profile.toCoachingProfile(),
        s: S.of(context)!,
      );
    } catch (e) {
      debugPrint('RetirementDashboard: tips error: $e');
      return [];
    }
  }

  String _computeScoreHistorySignature(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return 'empty';
    final buffer = StringBuffer('${history.length}|');
    for (final entry in history) {
      buffer
        ..write(entry['month'] ?? '')
        ..write(':')
        ..write(entry['score'] ?? '')
        ..write(';');
    }
    return buffer.toString();
  }

  // ────────────────────────────────────────────────────────────
  //  DASHBOARD CONTENT CURATION
  // ────────────────────────────────────────────────────────────

  void _curateDashboardContent(List<CoachingTip> tips) {
    final profile = _profile;
    if (profile == null) return;

    final taxSaving3a = profile.salaireBrutMensuel > 0
        ? pilier3aPlafondAvecLpp *
            RetirementTaxCalculator.estimateMarginalRate(
                profile.salaireBrutMensuel * 12, profile.canton)
        : 0.0;
    final friScore = _score?.global.toDouble() ?? 0.0;
    final friDelta = (_score?.deltaVsPreviousMonth ?? 0).toDouble();

    final reengagementMessages = ReengagementEngine.generateMessages(
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      taxSaving3a: taxSaving3a,
      friTotal: friScore,
      friDelta: friDelta,
    );

    _curatedCards = DashboardCuratorService.curate(
      tips: tips,
      reengagementMessages: reengagementMessages,
    );

    final rawTemporalItems = TemporalPriorityService.prioritize(
      s: S.of(context)!,
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      taxSaving3a: taxSaving3a,
      friTotal: friScore,
      friDelta: friDelta,
    );
    final hasTaxCard = _curatedCards.any((c) {
      final src = c.source;
      return src is CoachingTip && src.id == 'tax_deadline';
    });
    _temporalItems = hasTaxCard
        ? rawTemporalItems
            .where((t) =>
                !t.title.toLowerCase().contains('fiscal') &&
                !t.title.toLowerCase().contains('déclaration'))
            .toList()
        : rawTemporalItems;
  }

  // ────────────────────────────────────────────────────────────
  //  SNAPSHOT PERSISTENCE
  // ────────────────────────────────────────────────────────────

  void _persistInitialSnapshot(CoachProfile profile) {
    if (_snapshotPersisted) return;
    if (profile.initialProjectionSnapshot == null && _projection != null) {
      _snapshotPersisted = true;
      final snapshotJson = _projection!.toJson();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final provider = context.read<CoachProfileProvider>();
        provider.updateProfile(
          profile.copyWith(initialProjectionSnapshot: snapshotJson),
        );
      });
    }
  }

  // ────────────────────────────────────────────────────────────
  //  BUILD — 3 STATES
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CoachProfileProvider>();

    if (!provider.hasProfile || _projection == null) {
      return _buildStateC();
    }
    return _buildDashboard();
  }

  // ────────────────────────────────────────────────────────────
  //  UNIFIED DASHBOARD (State A + B — same layout, different emphasis)
  // ────────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    final proj = _projection!;
    final profile = _profile!;
    final isApproximate = _confidenceScore < 70;

    final monthlyBase = proj.base.revenuAnnuelRetraite / 12;
    final monthlyPrudent = proj.prudent.revenuAnnuelRetraite / 12;
    final monthlyOptimiste = proj.optimiste.revenuAnnuelRetraite / 12;

    // Couple combined income
    final isCouple = profile.isCouple && profile.conjoint?.birthYear != null;
    final decoBase = proj.base.decomposition;
    double? partnerMonthly;
    if (isCouple) {
      final avsConj = (decoBase['avs_conjoint'] ?? 0) / 12;
      final lppConj = (decoBase['lpp_conjoint'] ?? 0) / 12;
      partnerMonthly = avsConj + lppConj;
    }

    // Coach one-liner from narrative or template
    final coachOneLiner = _narrative?.greeting ??
        _buildDefaultOneLiner(profile, proj);

    // Urgent temporal item (deadline < 60 days)
    final urgentItem = _temporalItems
        .where((t) => t.daysUntil < 60)
        .toList();

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(profile.firstName),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Position 0: Urgent Banner (conditional) ──
                if (urgentItem.isNotEmpty) ...[
                  _UrgentBanner(item: urgentItem.first),
                  const SizedBox(height: 12),
                ],

                // ── Position 1: Hero Zone ──
                RetirementHeroZone(
                  monthlyIncome: isCouple && partnerMonthly != null
                      ? monthlyBase + partnerMonthly
                      : monthlyBase,
                  replacementRate: proj.tauxRemplacementBase,
                  decomposition: decoBase,
                  monthlyPrudent: monthlyPrudent,
                  monthlyOptimiste: monthlyOptimiste,
                  confidenceScore: _confidenceScore,
                  coachOneLiner: coachOneLiner,
                  deltaSinceLastVisit: _computeDelta(),
                  currentAge: profile.age,
                  retirementAge: profile.effectiveRetirementAge,
                  isApproximate: isApproximate,
                  isCouple: isCouple,
                  partnerName: profile.conjoint?.firstName,
                  partnerMonthlyIncome: partnerMonthly,
                  onConfidenceTap: () => _showEnrichmentSheet(context),
                ),
                const SizedBox(height: 16),

                // ── Position 2: Action Cards (max 2) ──
                ..._buildActionCards(isApproximate),

                // ── Position 3: Smart Shortcuts ──
                SmartShortcuts(
                  profile: profile,
                  confidenceScore: _confidenceScore,
                ),
                const SizedBox(height: 24),

                // ── Position 4: Footer ──
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
  //  STATE C — No profile / onboarding
  // ────────────────────────────────────────────────────────────

  Widget _buildStateC() {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(null),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildOnboardingHero(),
                const SizedBox(height: 16),
                _buildEducationalCard(),
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
    final title = firstName != null && firstName.isNotEmpty
        ? S.of(context)!.dashboardAppBarWithName(firstName)
        : S.of(context)!.dashboardAppBarDefault;

    return SliverAppBar(
      expandedHeight: 80,
      floating: true,
      snap: true,
      backgroundColor: MintColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          title,
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
          icon: const Icon(Icons.edit_note_outlined,
              color: MintColors.textSecondary),
          onPressed: () => context.push('/profile/bilan'),
          tooltip: S.of(context)!.dashboardMyData,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  ACTION CARDS — max 2, with CHF impact
  // ────────────────────────────────────────────────────────────

  List<Widget> _buildActionCards(bool isApproximate) {
    if (_curatedCards.isEmpty) return [];

    // Pick max 2 cards:
    // - Card 1: highest impact financial action
    // - Card 2: if low confidence → data enrichment, else second action
    final cards = _curatedCards.take(2).toList();

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          S.of(context)!.retirementDashboardNextActions,
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
      ),
      ...cards.map((card) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ActionCard(card: card),
          )),
      // Show data enrichment cards if low confidence (up to 3)
      if (isApproximate && _confidence?.prompts.isNotEmpty == true) ...[
        ..._confidence!.prompts.take(3).map((prompt) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DataEnrichmentCard(
                prompt: prompt,
                confidenceScore: _confidenceScore,
              ),
            )),
      ],
      const SizedBox(height: 6),
    ];
  }

  // ────────────────────────────────────────────────────────────
  //  HELPERS
  // ────────────────────────────────────────────────────────────

  String _buildDefaultOneLiner(CoachProfile profile, ProjectionResult proj) {
    final rate = proj.tauxRemplacementBase;
    final s = S.of(context)!;
    if (rate >= 70) {
      return s.retirementDashboardOneLinerGood;
    }
    if (rate >= 50) {
      return s.retirementDashboardOneLinerModerate;
    }
    return s.retirementDashboardOneLinerLow;
  }

  double? _computeDelta() {
    // Compare current projection with initial snapshot
    final profile = _profile;
    if (profile == null || _projection == null) return null;
    final snapshot = profile.initialProjectionSnapshot;
    if (snapshot == null) return null;
    try {
      final initial = ProjectionResult.fromJson(snapshot);
      final currentMonthly = _projection!.base.revenuAnnuelRetraite / 12;
      final initialMonthly = initial.base.revenuAnnuelRetraite / 12;
      final delta = currentMonthly - initialMonthly;
      return delta.abs() > 50 ? delta : null;
    } catch (_) {
      return null;
    }
  }

  void _showEnrichmentSheet(BuildContext context) {
    final prompts = _confidence?.prompts ?? [];
    if (prompts.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: const BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.retirementDashboardEnrichTitle,
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              S.of(context)!.retirementDashboardConfidenceCurrent(_confidenceScore.round().toString()),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ...prompts.take(5).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/data-block/${p.category}');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: MintColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MintColors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: MintColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _categoryIcon(p.category),
                              size: 16,
                              color: MintColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: MintColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  S.of(context)!.retirementDashboardPrecisionPts(p.impact.toString()),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: MintColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 14, color: MintColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'lpp' => Icons.business_outlined,
      'avs' => Icons.account_balance_outlined,
      '3a' => Icons.savings_outlined,
      'patrimoine' => Icons.account_balance_wallet_outlined,
      'logement' => Icons.home_outlined,
      'depenses' => Icons.receipt_long_outlined,
      'income' => Icons.payments_outlined,
      _ => Icons.add_circle_outline,
    };
  }

  // ────────────────────────────────────────────────────────────
  //  STATE C WIDGETS
  // ────────────────────────────────────────────────────────────

  Widget _buildOnboardingHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.primary.withValues(alpha: 0.06),
            MintColors.coachAccent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          const Icon(Icons.beach_access_outlined,
              size: 48, color: MintColors.primary),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.retirementDashboardHeroTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context)!.dashboardQuickStartBody,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/onboarding/quick'),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                S.of(context)!.retirementDashboardStartCta,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            S.of(context)!.retirementDashboardPrivacyNote,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationalCard() {
    return GestureDetector(
      onTap: () => context.push('/education/hub'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MintColors.info.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_outlined,
                  size: 20, color: MintColors.info),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context)!.retirementDashboardEduTitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  Text(
                    S.of(context)!.retirementDashboardEduSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: MintColors.textMuted),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  DISCLAIMER
  // ────────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Text(
      S.of(context)!.dashboardDisclaimer,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textMuted,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  URGENT BANNER — Temporal deadline < 60 days
// ────────────────────────────────────────────────────────────

class _UrgentBanner extends StatelessWidget {
  final TemporalItem item;

  const _UrgentBanner({required this.item});

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntil;
    return GestureDetector(
      onTap: () => context.push(item.deeplink),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: MintColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MintColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 18, color: MintColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${item.title} — J-$days',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 12, color: MintColors.warning),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ACTION CARD — Curated action with CHF impact
// ────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final CuratedCard card;

  const _ActionCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final urgencyColor = switch (card.urgency) {
      AlertUrgency.urgent => MintColors.error,
      AlertUrgency.active => MintColors.warning,
      AlertUrgency.info => MintColors.primary,
    };

    return GestureDetector(
      onTap: card.deeplink != null ? () => context.push(card.deeplink!) : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: urgencyColor.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: MintColors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                switch (card.urgency) {
                  AlertUrgency.urgent => Icons.warning_amber_rounded,
                  AlertUrgency.active => Icons.trending_up,
                  AlertUrgency.info => Icons.lightbulb_outline,
                },
                size: 16,
                color: urgencyColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.message,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (card.impactChf != null && card.impactChf! > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: MintColors.success.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+CHF ${formatChf(card.impactChf!)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MintColors.success,
                        ),
                      ),
                    ),
                  ],
                  if (card.deadlineDays != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      S.of(context)!.retirementDashboardDeadlineDays(card.deadlineDays.toString()),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: urgencyColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (card.deeplink != null)
              const Icon(Icons.chevron_right, size: 18, color: MintColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  DATA ENRICHMENT CARD — Confidence improvement prompt
// ────────────────────────────────────────────────────────────

class _DataEnrichmentCard extends StatelessWidget {
  final EnrichmentPrompt prompt;
  final double confidenceScore;

  const _DataEnrichmentCard({
    required this.prompt,
    required this.confidenceScore,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/data-block/${prompt.category}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MintColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: MintColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.document_scanner_outlined,
                  size: 16, color: MintColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prompt.label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  Text(
                    S.of(context)!.retirementDashboardPrecisionPercent(prompt.impact.toString()),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MintColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: MintColors.primary),
          ],
        ),
      ),
    );
  }
}
