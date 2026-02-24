import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/coach_narrative_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/coach/coach_helpers.dart';
import 'package:mint_mobile/services/streak_service.dart';
import 'package:mint_mobile/widgets/coach/streak_badge.dart';

// ────────────────────────────────────────────────────────────
//  COACH AGIR SCREEN — Sprint C7 / MINT Coach
// ────────────────────────────────────────────────────────────
//
// Tab Agir — la timeline d'actions, comme un calendrier
// d'entrainement. Affiche les versements du mois en cours,
// la timeline des evenements a venir, et l'historique
// des check-ins passes.
//
// Aucun terme banni. Ton pedagogique, tutoiement.
// ────────────────────────────────────────────────────────────

/// Element de la timeline
class _TimelineEvent {
  final DateTime date;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final String? cta;
  final bool isPast;
  final bool isCompleted;

  const _TimelineEvent({
    required this.date,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.cta,
    this.isPast = false,
    this.isCompleted = false,
  });
}

class CoachAgirScreen extends StatefulWidget {
  const CoachAgirScreen({super.key});

  @override
  State<CoachAgirScreen> createState() => _CoachAgirScreenState();
}

enum _AgirResetAction { resetHistory, resetDiagnostic }

class _CoachAgirScreenState extends State<CoachAgirScreen> {
  List<String>? _scenarioNarrations;
  bool _scenarioNarrationsFromLlm = false;
  String? _scenarioNarrativeProfileKey;
  int _scenarioNarrativeGeneration = 0;
  CoachNarrativeMode _narrativeMode = CoachNarrativeMode.detailed;
  bool _coachUxPrefsLoaded = false;
  String? _lastScoreDeltaReason;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_coachUxPrefsLoaded) {
      unawaited(_loadCoachUxPreferences());
    }
    final coachProvider = context.read<CoachProfileProvider>();
    final profile = coachProvider.profile;
    if (profile == null) return;
    final key =
        '${profile.birthYear}_${profile.canton}_${profile.updatedAt.toIso8601String()}_${coachProvider.scoreHistory.length}';
    if (_scenarioNarrativeProfileKey != key) {
      _scenarioNarrativeProfileKey = key;
      final tips = CoachingService.generateTips(
        profile: profile.toCoachingProfile(),
      );
      _loadScenarioNarratives(profile, coachProvider.scoreHistory, tips);
    }
  }

  Future<void> _loadCoachUxPreferences() async {
    final mode = await ReportPersistenceService.loadCoachNarrativeMode();
    final attribution =
        await ReportPersistenceService.loadLastScoreAttribution();
    if (!mounted) return;
    setState(() {
      _coachUxPrefsLoaded = true;
      _narrativeMode = mode == 'concise'
          ? CoachNarrativeMode.concise
          : CoachNarrativeMode.detailed;
      _lastScoreDeltaReason = attribution?['reason'] as String?;
    });
  }

  Future<void> _setNarrativeMode(CoachNarrativeMode mode) async {
    if (_narrativeMode == mode) return;
    setState(() => _narrativeMode = mode);
    await ReportPersistenceService.saveCoachNarrativeMode(
      mode == CoachNarrativeMode.concise ? 'concise' : 'detailed',
    );
  }

  Future<void> _loadScenarioNarratives(
    CoachProfile profile,
    List<Map<String, dynamic>>? scoreHistory,
    List<CoachingTip> tips,
  ) async {
    final gen = ++_scenarioNarrativeGeneration;
    LlmConfig? byokConfig;
    ByokProvider? byok;
    try {
      byok = context.read<ByokProvider>();
    } catch (_) {
      byok = null;
    }
    if (byok != null && byok.isConfigured && byok.apiKey != null) {
      final provider = switch (byok.provider) {
        'claude' || 'anthropic' => LlmProvider.anthropic,
        'mistral' => LlmProvider.mistral,
        _ => LlmProvider.openai,
      };
      byokConfig = LlmConfig(apiKey: byok.apiKey!, provider: provider);
    }
    final narrative = await CoachNarrativeService.generate(
      profile: profile,
      scoreHistory: scoreHistory,
      tips: tips,
      byokConfig: byokConfig,
    );
    if (!mounted || gen != _scenarioNarrativeGeneration) return;
    setState(() {
      _scenarioNarrations = narrative.scenarioNarrations;
      _scenarioNarrationsFromLlm = narrative.isLlmGenerated;
    });
  }

  Widget _buildResetMenuButton() {
    return PopupMenuButton<_AgirResetAction>(
      tooltip: 'Réinitialiser',
      icon: const Icon(Icons.tune, color: MintColors.textPrimary),
      onSelected: (value) => _handleResetAction(value),
      itemBuilder: (_) => const [
        PopupMenuItem<_AgirResetAction>(
          value: _AgirResetAction.resetHistory,
          child: Text('Réinitialiser mon historique coach'),
        ),
        PopupMenuItem<_AgirResetAction>(
          value: _AgirResetAction.resetDiagnostic,
          child: Text('Recommencer mon diagnostic'),
        ),
      ],
    );
  }

  Future<void> _handleResetAction(_AgirResetAction action) async {
    final coachProvider = context.read<CoachProfileProvider>();
    final activityProvider = context.read<UserActivityProvider>();
    if (action == _AgirResetAction.resetHistory) {
      final confirmed = await _confirmResetDialog(
        title: 'Réinitialiser ton historique coach ?',
        message:
            'Cela supprime tes check-ins, ton historique de score et la progression des simulateurs.',
        cta: 'Réinitialiser',
      );
      if (confirmed != true || !mounted) return;

      await ReportPersistenceService.clearCoachHistory();
      if (!mounted) return;
      await coachProvider.loadFromWizard();
      await activityProvider.clearAll();
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
    coachProvider.clear();
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

  // ── Priority roadmap grouping ───────────────────────────
  /// Groups coaching tips into 4 priority tiers for the roadmap display.
  Map<String, List<CoachingTip>> _prioritizeByQuarter(List<CoachingTip> tips) {
    final groups = <String, List<CoachingTip>>{
      'immediate': [], // Priorite immediate (red)
      'trimestre': [], // Ce trimestre (orange)
      'annee': [], // Cette annee (blue)
      'long_terme': [], // Long terme (green)
    };

    for (final tip in tips) {
      if ((tip.category == 'budget' &&
              tip.priority == CoachingPriority.haute) ||
          tip.id.contains('debt')) {
        groups['immediate']!.add(tip);
      } else if (tip.category == 'fiscalite' || tip.id.contains('3a')) {
        groups['trimestre']!.add(tip);
      } else if (tip.category == 'prevoyance' || tip.id.contains('lpp')) {
        groups['annee']!.add(tip);
      } else {
        groups['long_terme']!.add(tip);
      }
    }

    return groups;
  }

  // ── Simulator ID mapping for completion tracking ────────
  /// Maps a coaching tip to the simulator ID it targets.
  String? _simulatorIdForTip(CoachingTip tip) {
    switch (tip.category) {
      case 'fiscalite':
        return '3a';
      case 'prevoyance':
        if (tip.id.contains('lpp')) return 'lpp_deep';
        if (tip.id.contains('3a')) return '3a';
        return null;
      case 'retraite':
        if (tip.id.contains('rente') || tip.id.contains('capital')) {
          return 'rente_capital';
        }
        return 'retirement_projection';
      case 'budget':
        return 'budget';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final coachProvider = context.watch<CoachProfileProvider>();
    final profile = coachProvider.profile;
    final now = DateTime.now();
    final currentMonthLabel = '${kFrenchMonths[now.month - 1]} ${now.year}';

    // If no profile, show empty state prompting wizard
    if (profile == null) {
      return Scaffold(
        backgroundColor: MintColors.background,
        body: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyProfile(context, s),
            ),
          ],
        ),
      );
    }

    if (coachProvider.isPartialProfile) {
      return Scaffold(
        backgroundColor: MintColors.background,
        body: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildPartialProfile(context, s, coachProvider),
            ),
          ],
        ),
      );
    }

    // Check if current month's check-in is done
    final hasCurrentCheckIn = profile.checkIns.any(
      (ci) => ci.month.year == now.year && ci.month.month == now.month,
    );

    // Build timeline events from profile + milestones
    final timelineEvents = _buildTimelineEvents(profile, s);

    // User activity provider (inter-tab sync)
    final activity = context.watch<UserActivityProvider>();

    // Coaching tips tries par impact — filtrer les tips inactifs
    final allTips = CoachingService.generateTips(
      profile: profile.toCoachingProfile(),
    );
    final tips = allTips.where((t) => activity.isTipActive(t.id)).toList();

    // Group tips by priority quarter
    final priorityGroups = _prioritizeByQuarter(tips);

    // Check if there are debt-related tips in immediate group (for dependency indicator)
    final hasDebtInImmediate = priorityGroups['immediate']!.any(
      (t) => t.id.contains('debt'),
    );

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // ── Streak badge ──────────────────────────────
                _buildStreakSection(profile),
                const SizedBox(height: 12),
                _buildCoachPulseCard(profile, tips),
                const SizedBox(height: 8),
                _buildNarrativeModeControl(),
                const SizedBox(height: 12),
                _buildScenarioBriefCard(profile),
                const SizedBox(height: 20),

                // ── Section: Actions recommandees (priority roadmap) ──
                if (tips.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: s?.agirActionsRecommendedTitle ??
                        'Actions recommandees',
                    subtitle: s?.agirActionsRecommendedSubtitle ??
                        'Triees par priorite',
                    icon: Icons.bolt,
                    color: MintColors.coachAccent,
                  ),
                  const SizedBox(height: 16),
                  ..._buildPriorityRoadmap(
                    priorityGroups,
                    hasDebtInImmediate,
                    _narrativeMode,
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Section: Progression annuelle des versements ──
                if (profile.plannedContributions.isNotEmpty)
                  ..._buildContributionProgress(profile),

                // ── Section: Ce mois ─────────────────────────
                _buildSectionHeader(
                  title: s?.agirThisMonth ?? 'Ce mois',
                  subtitle: currentMonthLabel,
                  icon: Icons.calendar_today,
                  color: MintColors.coachAccent,
                ),
                const SizedBox(height: 16),

                // Planned contributions for this month
                if (profile.plannedContributions.isEmpty)
                  _buildNoContributions(context, s)
                else
                  ...profile.plannedContributions.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MonthlyContributionRow(
                        contribution: c,
                        isDone: hasCurrentCheckIn,
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Check-in action row
                if (profile.plannedContributions.isNotEmpty)
                  _buildCheckinAction(
                    context: context,
                    isDone: hasCurrentCheckIn,
                    monthLabel: currentMonthLabel,
                  ),

                const SizedBox(height: 36),

                // ── Section: Timeline ────────────────────────
                _buildSectionHeader(
                  title: s?.agirTimeline ?? 'Timeline',
                  subtitle: s?.agirTimelineSub ?? 'Tes prochaines échéances',
                  icon: Icons.timeline,
                  color: MintColors.info,
                ),
                const SizedBox(height: 16),

                // Timeline items
                ...timelineEvents.asMap().entries.map(
                      (entry) => _TimelineItem(
                        event: entry.value,
                        isFirst: entry.key == 0,
                        isLast: entry.key == timelineEvents.length - 1,
                      ),
                    ),

                const SizedBox(height: 36),

                // ── Section: Historique ──────────────────────
                _buildSectionHeader(
                  title: s?.agirHistory ?? 'Historique',
                  subtitle: s?.agirHistorySub ?? 'Tes check-ins passés',
                  icon: Icons.history,
                  color: MintColors.success,
                ),
                const SizedBox(height: 16),

                if (profile.checkIns.isEmpty)
                  _buildEmptyHistory(s)
                else
                  ...profile.checkIns.toList().reversed.map(
                        (ci) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _HistoryRow(checkIn: ci),
                        ),
                      ),

                const SizedBox(height: 32),

                // Disclaimer
                _buildDisclaimer(s),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Priority roadmap builder ──────────────────────────────
  List<Widget> _buildPriorityRoadmap(
    Map<String, List<CoachingTip>> groups,
    bool hasDebtInImmediate,
    CoachNarrativeMode narrativeMode,
  ) {
    const groupMeta = <String, ({String label, Color color})>{
      'immediate': (label: 'Priorite immediate', color: Color(0xFFFF453A)),
      'trimestre': (label: 'Ce trimestre', color: Color(0xFFFF9F0A)),
      'annee': (label: 'Cette annee', color: Color(0xFF007AFF)),
      'long_terme': (label: 'Long terme', color: Color(0xFF24B14D)),
    };

    final widgets = <Widget>[];

    for (final key in ['immediate', 'trimestre', 'annee', 'long_terme']) {
      final tips = groups[key]!;
      if (tips.isEmpty) continue;

      final meta = groupMeta[key]!;

      // Group header: colored dot + label
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 6),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: meta.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                meta.label,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: meta.color,
                ),
              ),
            ],
          ),
        ),
      );

      // Tip cards within this group (swipeable)
      final activity = context.watch<UserActivityProvider>();
      for (final tip in tips) {
        // Check dependency indicator: prevoyance tip + debt in immediate
        final showDependency =
            tip.category == 'prevoyance' && hasDebtInImmediate;

        // Check if this tip's simulator has been explored
        final simId = _simulatorIdForTip(tip);
        final isExplored = simId != null && activity.isSimulatorExplored(simId);

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: ValueKey('tip_${tip.id}'),
              // Swipe droite → Fait (dismiss)
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 24),
                decoration: BoxDecoration(
                  color: MintColors.success,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Fait',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Swipe gauche → Reporter 30j (snooze)
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: MintColors.warning,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reporter 30j',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.schedule, color: Colors.white, size: 24),
                  ],
                ),
              ),
              onDismissed: (direction) {
                if (direction == DismissDirection.startToEnd) {
                  // Swipe right → dismiss
                  activity.dismissTip(tip.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${tip.title} — marque comme fait'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  // Swipe left → snooze 30 days
                  activity.snoozeTip(tip.id, const Duration(days: 30));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${tip.title} — reporte de 30 jours'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: _CoachingTipCard(
                tip: tip,
                dependencyHint:
                    showDependency ? 'Apres : remboursement dette' : null,
                isExplored: isExplored,
                narrativeMode: narrativeMode,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  // ── Streak section ────────────────────────────────────────
  Widget _buildStreakSection(CoachProfile profile) {
    final streak = StreakService.compute(profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreakBadgeWidget(streak: streak),
        if (streak.earnedBadges.isNotEmpty) ...[
          const SizedBox(height: 12),
          EarnedBadgesRow(streak: streak),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // ── AppBar ─────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    final s = S.of(context);
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        _buildResetMenuButton(),
        const SizedBox(width: 8),
      ],
      title: Text(
        s?.agirTitle ?? 'AGIR',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Check-in action ────────────────────────────────────────
  Widget _buildCheckinAction({
    required BuildContext context,
    required bool isDone,
    required String monthLabel,
  }) {
    final s = S.of(context);
    if (isDone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: MintColors.success.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MintColors.success.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: MintColors.success,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s?.agirCheckinDone(monthLabel) ??
                    'Check-in $monthLabel effectué',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MintColors.success,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: MintColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s?.agirDone ?? 'Fait',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.success,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          // Navigate to check-in screen via GoRouter
          context.push('/coach/checkin');
        },
        icon: const Icon(Icons.edit_calendar, size: 20),
        label: Text(
          s?.agirCheckinCta(monthLabel) ?? 'Faire mon check-in $monthLabel',
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: MintColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ── Empty profile state ───────────────────────────────────
  Widget _buildEmptyProfile(BuildContext context, S? s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MintColors.coachAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flash_on,
                color: MintColors.coachAccent,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ton plan d\'action t\'attend',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Complète ton diagnostic pour obtenir un plan mensuel personnalisé '
              'basé sur ta situation réelle.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/advisor'),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: Text(
                  'Lancer mon diagnostic — 10 min',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartialProfile(
    BuildContext context,
    S? s,
    CoachProfileProvider provider,
  ) {
    final quality = (provider.onboardingQualityScore * 100).round();
    final section = provider.recommendedWizardSection;
    final sectionLabel = switch (section) {
      'identity' => s?.coachWizardSectionIdentity ?? 'Identite & foyer',
      'income' => s?.coachWizardSectionIncome ?? 'Revenu & foyer',
      'pension' => s?.coachWizardSectionPension ?? 'Prevoyance',
      'property' => s?.coachWizardSectionProperty ?? 'Immobilier & dettes',
      _ => s?.advisorMiniFullDiagnostic ?? 'Diagnostic',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.track_changes,
                color: MintColors.warning,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              s?.coachAgirPartialTitle('$quality') ??
                  'Plan en construction ($quality%)',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              s?.coachAgirPartialBody(sectionLabel) ??
                  'Pour activer tes actions prioritaires, complete maintenant la section $sectionLabel.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => context.push(
                  '/advisor/wizard',
                  extra: {'section': section},
                ),
                icon: const Icon(Icons.auto_awesome, size: 20),
                label: Text(
                  s?.coachAgirPartialAction(sectionLabel) ??
                      'Completer $sectionLabel',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/coach/chat'),
                child: Text(
                  s?.askMintTitle ?? 'Demander a MINT',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── No contributions state ──────────────────────────────
  // ── Contribution annual progress ─────────────────────────
  List<Widget> _buildContributionProgress(CoachProfile profile) {
    final now = DateTime.now();
    final currentYear = now.year;

    // Aggregate actual versements from check-ins this year
    final yearCheckIns = profile.checkIns.where(
      (ci) => ci.month.year == currentYear,
    );
    final actualByCategory = <String, double>{};
    for (final ci in yearCheckIns) {
      for (final entry in ci.versements.entries) {
        actualByCategory[entry.key] =
            (actualByCategory[entry.key] ?? 0) + entry.value;
      }
    }

    // Build progress cards for each planned contribution
    final widgets = <Widget>[
      _buildSectionHeader(
        title: 'Progression annuelle',
        subtitle: 'Planifie vs verse en $currentYear',
        icon: Icons.bar_chart,
        color: const Color(0xFF6366F1),
      ),
      const SizedBox(height: 16),
    ];

    for (final contribution in profile.plannedContributions) {
      final annualTarget = contribution.amount * 12;
      // Special case for 3a: cap at pillar 3a ceiling
      final target = contribution.category == '3a' && annualTarget > 7258
          ? 7258.0
          : annualTarget;

      // Sum actual from matching check-in keys
      double actual = 0;
      for (final entry in actualByCategory.entries) {
        if (entry.key.toLowerCase().contains(
              contribution.category.toLowerCase(),
            )) {
          actual += entry.value;
        }
      }

      final progress = target > 0 ? (actual / target).clamp(0.0, 1.0) : 0.0;
      final monthsElapsed = now.month;
      final expectedProgress = monthsElapsed / 12;
      final isOnTrack = progress >= expectedProgress * 0.8;

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ContributionProgressCard(
          label: contribution.label,
          category: contribution.category,
          actual: actual,
          target: target,
          progress: progress,
          isOnTrack: isOnTrack,
          hasCheckIns: yearCheckIns.isNotEmpty,
        ),
      ));
    }

    widgets.add(const SizedBox(height: 24));
    return widgets;
  }

  Widget _buildNoContributions(BuildContext context, S? s) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_circle_outline,
            color: MintColors.coachAccent,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            'Aucun versement planifié',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fais ton premier check-in pour configurer tes versements mensuels.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => context.push('/coach/checkin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MintColors.coachAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Configurer mes versements',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty history ──────────────────────────────────────────
  Widget _buildEmptyHistory(S? s) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off,
            color: MintColors.textMuted,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            s?.agirNoCheckin ?? 'Pas encore de check-in',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s?.agirNoCheckinSub ??
                'Fais ton premier check-in pour commencer à suivre ta progression.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Build timeline events ──────────────────────────────────
  List<_TimelineEvent> _buildTimelineEvents(CoachProfile profile, S? s) {
    final now = DateTime.now();
    final events = <_TimelineEvent>[];

    // Helper: is a date in the past?
    bool isPastDate(DateTime d) => d.isBefore(now);
    // Helper: is event within 30 days (imminent)?
    bool isImminent(DateTime d) =>
        !isPastDate(d) && d.difference(now).inDays <= 30;

    // 1. 3a deadline — Dec of current year
    final dec31 = DateTime(now.year, 12, 31);
    events.add(_TimelineEvent(
      date: dec31,
      title: s?.agirTimeline3a ?? 'Dernier jour versement 3a',
      subtitle: s?.agirTimeline3aSub ??
          'Vérifie que ton plafond est atteint avant fin décembre.',
      icon: Icons.savings,
      color:
          isImminent(dec31) ? const Color(0xFFF59E0B) : const Color(0xFF4F46E5),
      cta: s?.agirTimeline3aCta ?? 'Vérifier mon 3a',
      isPast: isPastDate(dec31),
      isCompleted: false, // would need 3a max check
    ));

    // 2. Tax filing — March of next year
    final taxYear = now.month <= 3 ? now.year : now.year + 1;
    final taxDeadline = DateTime(taxYear, 3, 31);
    events.add(_TimelineEvent(
      date: taxDeadline,
      title: s?.agirTimelineTax(profile.canton) ??
          'Déclaration impôts ${profile.canton}',
      subtitle: s?.agirTimelineTaxSub ??
          'Pense à rassembler tes attestations 3a et LPP.',
      icon: Icons.description,
      color: isImminent(taxDeadline)
          ? const Color(0xFFF59E0B)
          : MintColors.warning,
      cta: s?.agirTimelineTaxCta ?? 'Préparer mes documents',
      isPast: isPastDate(taxDeadline),
    ));

    // 3. LAMal franchise — November of current year
    final lamalYear = now.month <= 11 ? now.year : now.year + 1;
    final lamalDeadline = DateTime(lamalYear, 11, 30);
    events.add(_TimelineEvent(
      date: lamalDeadline,
      title: s?.agirTimelineLamal ?? 'Franchise LAMal (changer ?)',
      subtitle: s?.agirTimelineLamalSub ??
          'Évalue si ta franchise actuelle est toujours adaptée.',
      icon: Icons.health_and_safety,
      color: isImminent(lamalDeadline)
          ? const Color(0xFFF59E0B)
          : MintColors.error,
      cta: s?.agirTimelineLamalCta ?? 'Simuler les franchises',
      isPast: isPastDate(lamalDeadline),
    ));

    // 4. Monthly check-in event (1st of next month if not done)
    final hasCurrentCheckIn = profile.checkIns.any(
      (ci) => ci.month.year == now.year && ci.month.month == now.month,
    );
    final checkInDate = DateTime(now.year, now.month, 1);
    events.add(_TimelineEvent(
      date: checkInDate,
      title: 'Check-in mensuel',
      subtitle: hasCurrentCheckIn
          ? 'Fait — versements confirmes pour ce mois.'
          : 'Confirme tes versements du mois en 2 min.',
      icon: hasCurrentCheckIn
          ? Icons.check_circle
          : Icons.calendar_today_outlined,
      color:
          hasCurrentCheckIn ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
      cta: hasCurrentCheckIn ? null : 'Faire mon check-in',
      isCompleted: hasCurrentCheckIn,
    ));

    // 5. Milestones from ForecasterService
    try {
      final projection = ForecasterService.project(profile: profile);
      for (final milestone in projection.milestones.take(3)) {
        events.add(_TimelineEvent(
          date: milestone.date,
          title: milestone.label,
          icon: Icons.flag,
          color: isPastDate(milestone.date)
              ? MintColors.textMuted
              : MintColors.trajectoryBase,
          isPast: isPastDate(milestone.date),
        ));
      }
    } catch (_) {
      // Graceful degradation — skip milestones if projection fails
    }

    // 6. Retirement
    events.add(_TimelineEvent(
      date: profile.goalA.targetDate,
      title: 'Retraite ${profile.firstName ?? ''} (65 ans)',
      subtitle: s?.agirTimelineRetireSub ?? 'Ton objectif principal.',
      icon: Icons.beach_access,
      color: MintColors.trajectoryOptimiste,
      isPast: isPastDate(profile.goalA.targetDate),
    ));

    // Sort by date
    events.sort((a, b) => a.date.compareTo(b.date));

    // Keep past completed events (for visual progression) + all future events
    return events
        .where((e) =>
            e.isCompleted ||
            e.date.isAfter(now.subtract(const Duration(days: 31))))
        .toList();
  }

  // ── Disclaimer ─────────────────────────────────────────────
  Widget _buildDisclaimer(S? s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: MintColors.textMuted,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s?.agirDisclaimer ??
                  'Outil éducatif — ne constitue pas un conseil financier personnalisé. '
                      'Les échéances et projections sont indicatives. '
                      'Consulte un·e spécialiste pour un accompagnement adapté. LSFin.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachPulseCard(CoachProfile profile, List<CoachingTip> tips) {
    final s = S.of(context);
    final byok = context.watch<ByokProvider>();
    final hasCheckInThisMonth = profile.checkIns.any(
      (ci) =>
          ci.month.year == DateTime.now().year &&
          ci.month.month == DateTime.now().month,
    );
    final topTip = tips.isNotEmpty ? tips.first : null;
    final pulse = hasCheckInThisMonth
        ? (s?.agirCoachPulseDone ??
            'Tu es a jour ce mois-ci. Priorise maintenant l action la plus impactante.')
        : (s?.agirCoachPulsePending ??
            'Ton check-in mensuel est la prochaine action critique pour garder ta trajectoire fiable.');

    final whyNowRaw = topTip == null
        ? 'Commence par une action simple pour enclencher ta dynamique.'
        : (topTip.narrativeMessage ?? topTip.message);
    final whyNow =
        CoachNarrativeService.applyDetailMode(whyNowRaw, _narrativeMode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: MintColors.coachAccent,
              ),
              const SizedBox(width: 8),
              Text(
                s?.coachPulseTitle ?? 'Coach Pulse',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  byok.isConfigured
                      ? (s?.coachIaBadge ?? 'Coach IA')
                      : (s?.coachBadgeStatic ?? 'Coach'),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: MintColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pulse,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: MintColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s?.agirCoachPulseWhyNow(whyNow) ?? 'Pourquoi maintenant: $whyNow',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (_lastScoreDeltaReason != null &&
              _lastScoreDeltaReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MintColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MintColors.lightBorder),
              ),
              child: Text(
                CoachNarrativeService.applyDetailMode(
                  _lastScoreDeltaReason!,
                  _narrativeMode,
                ),
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: MintColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNarrativeModeControl() {
    final s = S.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: SegmentedButton<CoachNarrativeMode>(
        segments: [
          ButtonSegment<CoachNarrativeMode>(
            value: CoachNarrativeMode.concise,
            label: Text(s?.coachNarrativeModeConcise ?? 'Court'),
          ),
          ButtonSegment<CoachNarrativeMode>(
            value: CoachNarrativeMode.detailed,
            label: Text(s?.coachNarrativeModeDetailed ?? 'Détail'),
          ),
        ],
        selected: {_narrativeMode},
        onSelectionChanged: (selection) {
          if (selection.isEmpty) return;
          unawaited(_setNarrativeMode(selection.first));
        },
        showSelectedIcon: false,
        emptySelectionAllowed: false,
        multiSelectionEnabled: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: WidgetStatePropertyAll(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          ),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioBriefCard(CoachProfile profile) {
    final s = S.of(context);
    try {
      final projection = ForecasterService.project(profile: profile);
      final base = projection.base;
      final prudent = projection.prudent;
      final optimiste = projection.optimiste;

      final gap = optimiste.capitalFinal - prudent.capitalFinal;
      final replacement = projection.tauxRemplacementBase.round();
      final years = profile.anneesAvantRetraite;
      final narration =
          (_scenarioNarrations != null && _scenarioNarrations!.isNotEmpty)
              ? _scenarioNarrations!.first
              : null;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_stories_outlined,
                  size: 16,
                  color: MintColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  s?.agirScenarioBriefTitle ?? 'Scenarios de retraite en bref',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_scenarioNarrationsFromLlm)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MintColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s?.coachIaBadge ?? 'Coach IA',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: MintColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              CoachNarrativeService.applyDetailMode(
                narration ??
                    (s?.agirScenarioBriefSummary(
                          '$years',
                          ForecasterService.formatChf(base.capitalFinal),
                          '$replacement',
                          ForecasterService.formatChf(gap),
                        ) ??
                        'Dans ~$years ans, ton scenario Base vise ${ForecasterService.formatChf(base.capitalFinal)} '
                            '(~$replacement% de remplacement). L ecart Prudent vs Optimiste est '
                            '${ForecasterService.formatChf(gap)}.'),
                _narrativeMode,
              ),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => context.push('/retirement/projection'),
              child: Text(
                s?.agirScenarioBriefCta ?? 'Ouvrir la simulation complete',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  MONTHLY CONTRIBUTION ROW
// ════════════════════════════════════════════════════════════════

class _MonthlyContributionRow extends StatelessWidget {
  final PlannedMonthlyContribution contribution;
  final bool isDone;

  const _MonthlyContributionRow({
    required this.contribution,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final icon = iconForCategory(contribution.category);
    final color = colorForCategory(contribution.category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D1D1F).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Checkbox area
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDone
                  ? MintColors.success.withValues(alpha: 0.12)
                  : MintColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDone ? MintColors.success : MintColors.border,
                width: isDone ? 1.5 : 1,
              ),
            ),
            child: isDone
                ? const Icon(
                    Icons.check,
                    color: MintColors.success,
                    size: 18,
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Category icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),

          // Label
          Expanded(
            child: Text(
              contribution.label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color:
                    isDone ? MintColors.textSecondary : MintColors.textPrimary,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),

          // Amount
          Text(
            ForecasterService.formatChf(contribution.amount),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDone ? MintColors.textMuted : MintColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),

          // Auto/Manual badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: contribution.isAutomatic
                  ? MintColors.success.withValues(alpha: 0.1)
                  : MintColors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              contribution.isAutomatic
                  ? (s?.agirAuto ?? 'Auto')
                  : (s?.agirManuel ?? 'Manuel'),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: contribution.isAutomatic
                    ? MintColors.success
                    : MintColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  TIMELINE ITEM WIDGET
// ════════════════════════════════════════════════════════════════

class _TimelineItem extends StatelessWidget {
  final _TimelineEvent event;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({
    required this.event,
    this.isFirst = false,
    this.isLast = false,
  });

  String _formatDate(DateTime date) {
    final monthShort = kFrenchMonthsShort[date.month - 1];
    return '$monthShort ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column (dot + connecting line)
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Top connector line
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 12,
                    color: MintColors.border,
                  )
                else
                  const SizedBox(height: 12),

                // Dot — visual state: completed (green+check), past (grey),
                // imminent (<30d, orange pulse), upcoming (blue)
                _buildTimelineDot(),

                // Bottom connector line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: MintColors.border,
                    ),
                  )
                else
                  const Spacer(),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MintColors.lightBorder),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1D1D1F).withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date badge + icon row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: event.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatDate(event.date),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: event.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          event.icon,
                          color: event.color,
                          size: 18,
                        ),
                        const Spacer(),
                        // Years until
                        Text(
                          _yearsUntil(event.date),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: MintColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      event.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: event.isCompleted
                            ? const Color(0xFF10B981)
                            : event.isPast
                                ? MintColors.textMuted
                                : MintColors.textPrimary,
                        decoration: event.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),

                    // Subtitle
                    if (event.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: event.isPast
                              ? MintColors.textMuted
                              : MintColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],

                    // CTA
                    if (event.cta != null) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          final cta = event.cta;
                          if (cta == null) return;
                          if (cta.contains('3a')) {
                            context.push('/simulator/3a');
                          } else if (cta.contains('documents')) {
                            context.push('/documents');
                          } else if (cta.contains('franchises')) {
                            context.push('/assurances/lamal');
                          } else if (cta.contains('check-in')) {
                            context.push('/coach/checkin');
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          backgroundColor: event.color.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          event.cta!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: event.color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineDot() {
    final now = DateTime.now();
    final daysUntil = event.date.difference(now).inDays;

    Color dotColor;
    Widget? dotChild;

    if (event.isCompleted) {
      // Completed: green with checkmark
      dotColor = const Color(0xFF10B981);
      dotChild = const Icon(Icons.check, size: 10, color: Colors.white);
    } else if (event.isPast) {
      // Past but not completed: grey
      dotColor = const Color(0xFF9CA3AF);
    } else if (daysUntil <= 30 && daysUntil >= 0) {
      // Imminent: orange
      dotColor = const Color(0xFFF59E0B);
    } else {
      // Upcoming: use event color
      dotColor = event.color;
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: dotColor.withValues(alpha: 0.3),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: dotChild != null ? Center(child: dotChild) : null,
    );
  }

  String _yearsUntil(DateTime target) {
    final now = DateTime.now();
    final months = (target.year - now.year) * 12 + (target.month - now.month);
    if (months < 1) return 'Ce mois';
    if (months < 12) return 'dans $months mois';
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (remainingMonths == 0) return 'dans $years an${years > 1 ? 's' : ''}';
    return 'dans $years an${years > 1 ? 's' : ''}';
  }
}

// ════════════════════════════════════════════════════════════════
//  HISTORY ROW WIDGET
// ════════════════════════════════════════════════════════════════

class _HistoryRow extends StatelessWidget {
  final MonthlyCheckIn checkIn;

  const _HistoryRow({required this.checkIn});

  @override
  Widget build(BuildContext context) {
    final monthLabel =
        '${kFrenchMonths[checkIn.month.month - 1]} ${checkIn.month.year}';

    // Build summary of versements
    final summaryParts = <String>[];
    for (final entry in checkIn.versements.entries) {
      final shortId = _shortLabel(entry.key);
      summaryParts.add('$shortId ${ForecasterService.formatChf(entry.value)}');
    }
    final summary = summaryParts.join(' | ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Green check icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle,
              color: MintColors.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthLabel,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (checkIn.note != null && checkIn.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    checkIn.note!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: MintColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Total
          Text(
            ForecasterService.formatChf(checkIn.totalVersements),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.success,
            ),
          ),
        ],
      ),
    );
  }

  /// Short human-readable label from versement ID
  String _shortLabel(String id) {
    if (id.contains('3a')) return '3a';
    if (id.contains('lpp')) return 'LPP';
    if (id.contains('ib') || id.contains('invest')) return 'Invest.';
    if (id.contains('epargne')) return 'Épargne';
    return id;
  }
}

// ════════════════════════════════════════════════════════════════
//  COACHING TIP CARD — Actions recommandees triees par impact
// ════════════════════════════════════════════════════════════════

class _CoachingTipCard extends StatelessWidget {
  final CoachingTip tip;
  final String? dependencyHint;
  final bool isExplored;
  final CoachNarrativeMode narrativeMode;

  const _CoachingTipCard({
    required this.tip,
    this.dependencyHint,
    this.isExplored = false,
    this.narrativeMode = CoachNarrativeMode.detailed,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = _colorForTipCategory(tip.category);
    final rawMessage = tip.narrativeMessage ?? tip.message;
    final message =
        CoachNarrativeService.applyDetailMode(rawMessage, narrativeMode);

    return GestureDetector(
      onTap: () => context.push(tipRoute(tip)),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D1D1F).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Left: icon in colored circle
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(tip.icon, color: categoryColor, size: 22),
                    ),
                    const SizedBox(width: 14),

                    // Center: title + message + source
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip.title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MintColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            message,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: MintColors.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: MintColors.surface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tip.source,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: MintColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Right: CHF impact badge (if available)
                    if (tip.estimatedImpactChf != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: MintColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ForecasterService.formatChf(
                                  tip.estimatedImpactChf!),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: MintColors.success,
                              ),
                            ),
                            Text(
                              '/an',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: MintColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Arrow
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: MintColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),

                // Dependency hint (e.g. "Apres : remboursement dette")
                if (dependencyHint != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_right,
                        color: MintColors.textMuted,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dependencyHint!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: MintColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Green checkmark overlay (explored simulator)
          if (isExplored)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: MintColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: MintColors.success.withValues(alpha: 0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _colorForTipCategory(String category) {
    switch (category) {
      case 'fiscalite':
        return const Color(0xFF4F46E5); // Indigo
      case 'prevoyance':
        return const Color(0xFF0891B2); // Teal
      case 'budget':
        return MintColors.warning;
      case 'retraite':
        return MintColors.success;
      default:
        return MintColors.info;
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  CONTRIBUTION PROGRESS CARD
// ════════════════════════════════════════════════════════════════

class _ContributionProgressCard extends StatelessWidget {
  final String label;
  final String category;
  final double actual;
  final double target;
  final double progress;
  final bool isOnTrack;
  final bool hasCheckIns;

  const _ContributionProgressCard({
    required this.label,
    required this.category,
    required this.actual,
    required this.target,
    required this.progress,
    required this.isOnTrack,
    required this.hasCheckIns,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorForCategory(category);
    final icon = iconForCategory(category);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D1D1F).withValues(alpha: 0.03),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              if (!hasCheckIns)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'A confirmer',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                )
              else
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isOnTrack
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: MintColors.lightBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOnTrack ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${ForecasterService.formatChf(actual)} verses',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
              Text(
                'Objectif : ${ForecasterService.formatChf(target)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
