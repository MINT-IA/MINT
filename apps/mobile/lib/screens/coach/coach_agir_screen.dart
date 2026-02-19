import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
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

  const _TimelineEvent({
    required this.date,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.cta,
  });
}

class CoachAgirScreen extends StatefulWidget {
  const CoachAgirScreen({super.key});

  @override
  State<CoachAgirScreen> createState() => _CoachAgirScreenState();
}

enum _AgirResetAction { resetHistory, resetDiagnostic }

class _CoachAgirScreenState extends State<CoachAgirScreen> {
  Set<String> _exploredSimulators = {};

  @override
  void initState() {
    super.initState();
    _loadExploredSimulators();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rafraichir les checkmarks au retour de navigation
    _loadExploredSimulators();
  }

  Future<void> _loadExploredSimulators() async {
    final explored = await ReportPersistenceService.loadExploredSimulators();
    if (mounted) {
      setState(() => _exploredSimulators = explored);
    }
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
      await context.read<CoachProfileProvider>().loadFromWizard();
      await _loadExploredSimulators();
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

    // Check if current month's check-in is done
    final hasCurrentCheckIn = profile.checkIns.any(
      (ci) => ci.month.year == now.year && ci.month.month == now.month,
    );

    // Build timeline events from profile + milestones
    final timelineEvents = _buildTimelineEvents(profile, s);

    // Coaching tips tries par impact
    final tips = CoachingService.generateTips(
      profile: profile.toCoachingProfile(),
    );

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

                // ── Section: Actions recommandees (priority roadmap) ──
                if (tips.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'Actions recommandees',
                    subtitle: 'Triees par priorite',
                    icon: Icons.bolt,
                    color: MintColors.coachAccent,
                  ),
                  const SizedBox(height: 16),
                  ..._buildPriorityRoadmap(
                    priorityGroups,
                    hasDebtInImmediate,
                  ),
                  const SizedBox(height: 24),
                ],

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

      // Tip cards within this group
      for (final tip in tips) {
        // Check dependency indicator: prevoyance tip + debt in immediate
        final showDependency =
            tip.category == 'prevoyance' && hasDebtInImmediate;

        // Check if this tip's simulator has been explored
        final simId = _simulatorIdForTip(tip);
        final isExplored = simId != null && _exploredSimulators.contains(simId);

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CoachingTipCard(
              tip: tip,
              dependencyHint:
                  showDependency ? 'Apres : remboursement dette' : null,
              isExplored: isExplored,
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

  // ── No contributions state ──────────────────────────────
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

    // 1. 3a deadline — Dec of current year
    events.add(_TimelineEvent(
      date: DateTime(now.year, 12, 31),
      title: s?.agirTimeline3a ?? 'Dernier jour versement 3a',
      subtitle: s?.agirTimeline3aSub ??
          'Vérifie que ton plafond est atteint avant fin décembre.',
      icon: Icons.savings,
      color: const Color(0xFF4F46E5),
      cta: s?.agirTimeline3aCta ?? 'Vérifier mon 3a',
    ));

    // 2. Tax filing — March of next year
    final taxYear = now.month <= 3 ? now.year : now.year + 1;
    events.add(_TimelineEvent(
      date: DateTime(taxYear, 3, 31),
      title: s?.agirTimelineTax(profile.canton) ??
          'Déclaration impôts ${profile.canton}',
      subtitle: s?.agirTimelineTaxSub ??
          'Pense à rassembler tes attestations 3a et LPP.',
      icon: Icons.description,
      color: MintColors.warning,
      cta: s?.agirTimelineTaxCta ?? 'Préparer mes documents',
    ));

    // 3. LAMal franchise — November of current year
    final lamalYear = now.month <= 11 ? now.year : now.year + 1;
    events.add(_TimelineEvent(
      date: DateTime(lamalYear, 11, 30),
      title: s?.agirTimelineLamal ?? 'Franchise LAMal (changer ?)',
      subtitle: s?.agirTimelineLamalSub ??
          'Évalue si ta franchise actuelle est toujours adaptée.',
      icon: Icons.health_and_safety,
      color: MintColors.error,
      cta: s?.agirTimelineLamalCta ?? 'Simuler les franchises',
    ));

    // 4. Milestones from ForecasterService
    try {
      final projection = ForecasterService.project(profile: profile);
      for (final milestone in projection.milestones.take(3)) {
        events.add(_TimelineEvent(
          date: milestone.date,
          title: milestone.label,
          icon: Icons.flag,
          color: MintColors.trajectoryBase,
        ));
      }
    } catch (_) {
      // Graceful degradation — skip milestones if projection fails
    }

    // 5. Retirement
    events.add(_TimelineEvent(
      date: profile.goalA.targetDate,
      title: 'Retraite ${profile.firstName ?? ''} (65 ans)',
      subtitle: s?.agirTimelineRetireSub ?? 'Ton objectif principal.',
      icon: Icons.beach_access,
      color: MintColors.trajectoryOptimiste,
    ));

    // Sort by date
    events.sort((a, b) => a.date.compareTo(b.date));

    // Filter to only future events
    return events
        .where((e) => e.date.isAfter(now.subtract(const Duration(days: 1))))
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

                // Dot
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: event.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: event.color.withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),

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
                        color: MintColors.textPrimary,
                      ),
                    ),

                    // Subtitle
                    if (event.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textSecondary,
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

  const _CoachingTipCard({
    required this.tip,
    this.dependencyHint,
    this.isExplored = false,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = _colorForTipCategory(tip.category);

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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tip.message,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: MintColors.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: 2,
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
