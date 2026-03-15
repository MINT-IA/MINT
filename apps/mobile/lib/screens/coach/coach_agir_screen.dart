import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/coach/coach_helpers.dart';

// ────────────────────────────────────────────────────────────
//  COACH AGIR SCREEN — V2 "Le Prochain Pas"
// ────────────────────────────────────────────────────────────
//
//  1 action urgente (expanded) + Ce mois + Mini timeline (3)
//
//  Propriété exclusive d'Agir :
//  - L'action #1 (priorité maximale, expanded)
//  - Le check-in mensuel (contributions + bouton)
//  - La mini timeline (3 prochaines échéances)
//  - Les actions secondaires (collapsed)
//
//  Tout le reste vit ailleurs :
//  - Hero / Score → Pulse tab
//  - Streak → supprimé (gamification superflue)
//  - Scenarios → Apprendre tab
//  - Historique → Profil tab
//  - Micro-actions → supprimé (dilue le focus)
// ────────────────────────────────────────────────────────────

/// Élément de la timeline
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
  bool _showAllActions = false;

  Widget _buildResetMenuButton() {
    return PopupMenuButton<_AgirResetAction>(
      tooltip: S.of(context)!.agirResetTooltip,
      icon: const Icon(Icons.tune, color: MintColors.textPrimary),
      onSelected: (value) => _handleResetAction(value),
      itemBuilder: (_) => [
        PopupMenuItem<_AgirResetAction>(
          value: _AgirResetAction.resetHistory,
          child: Text(S.of(context)!.agirResetHistoryLabel),
        ),
        PopupMenuItem<_AgirResetAction>(
          value: _AgirResetAction.resetDiagnostic,
          child: Text(S.of(context)!.agirResetDiagnosticLabel),
        ),
      ],
    );
  }

  Future<void> _handleResetAction(_AgirResetAction action) async {
    final coachProvider = context.read<CoachProfileProvider>();
    final activityProvider = context.read<UserActivityProvider>();
    if (action == _AgirResetAction.resetHistory) {
      final confirmed = await _confirmResetDialog(
        title: S.of(context)!.agirResetHistoryTitle,
        message: S.of(context)!.agirResetHistoryMessage,
        cta: S.of(context)!.agirResetHistoryCta,
      );
      if (confirmed != true || !mounted) return;

      await ReportPersistenceService.clearCoachHistory();
      if (!mounted) return;
      await coachProvider.loadFromWizard();
      await activityProvider.clearAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context)!.agirHistoryResetSnackbar)),
      );
      return;
    }

    final confirmed = await _confirmResetDialog(
      title: S.of(context)!.agirResetDiagnosticTitle,
      message: S.of(context)!.agirResetDiagnosticMessage,
      cta: S.of(context)!.agirResetDiagnosticCta,
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
            child: Text(S.of(context)!.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: MintColors.error),
            child: Text(cta),
          ),
        ],
      ),
    );
  }

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
    final s = S.of(context)!;
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

    // Build timeline events — limit to 3 nearest
    final allTimelineEvents = _buildTimelineEvents(profile, s);
    final miniTimeline = allTimelineEvents.take(3).toList();

    // User activity provider
    final activity = context.watch<UserActivityProvider>();

    // Coaching tips sorted by impact — filter snoozed/dismissed
    final allTips = CoachingService.generateTips(
      profile: profile.toCoachingProfile(),
      s: S.of(context)!,
    );
    final tips = allTips.where((t) => activity.isTipActive(t.id)).toList();

    // Action #1 = first tip (highest priority)
    final topTip = tips.isNotEmpty ? tips.first : null;
    final otherTips = tips.length > 1 ? tips.sublist(1) : <CoachingTip>[];

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

                // ── Action #1 (expanded, hero) ──────────────
                if (topTip != null) ...[
                  _buildTopAction(topTip, activity),
                  const SizedBox(height: 24),
                ],

                // ── Ce mois: contributions + check-in ───────
                _buildSectionLabel(
                  s.agirThisMonth,
                  currentMonthLabel,
                ),
                const SizedBox(height: 12),

                // Budget flow: Net → Fixes → Dispo → Versé → Reste
                if (profile.salaireBrutMensuel > 0)
                  _buildBudgetContextBar(profile),

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

                if (profile.plannedContributions.isNotEmpty)
                  _buildCheckinAction(
                    context: context,
                    isDone: hasCurrentCheckIn,
                    monthLabel: currentMonthLabel,
                  ),

                const SizedBox(height: 24),

                // ── Mini timeline (3 prochaines échéances) ───
                if (miniTimeline.isNotEmpty) ...[
                  _buildSectionLabel(
                    s.agirTimeline,
                    s.agirTimelineSub,
                  ),
                  const SizedBox(height: 12),
                  ...miniTimeline.asMap().entries.map(
                        (entry) => _TimelineItem(
                          event: entry.value,
                          isFirst: entry.key == 0,
                          isLast: entry.key == miniTimeline.length - 1,
                        ),
                      ),
                  const SizedBox(height: 24),
                ],

                // ── Other actions (collapsed) ───────────────
                if (otherTips.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showAllActions = !_showAllActions),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: MintColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: MintColors.lightBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showAllActions
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: MintColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            s.agirOtherActions(otherTips.length.toString()),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MintColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showAllActions) ...[
                    const SizedBox(height: 12),
                    ...otherTips.map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Dismissible(
                          key: ValueKey('tip_${tip.id}'),
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 24),
                            decoration: BoxDecoration(
                              color: MintColors.success,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle,
                                    color: MintColors.white, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  S.of(context)!.agirSwipeDone,
                                  style: const TextStyle(
                                    color: MintColors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: MintColors.warning,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  S.of(context)!.agirSwipeSnooze,
                                  style: const TextStyle(
                                    color: MintColors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.schedule,
                                    color: MintColors.white, size: 24),
                              ],
                            ),
                          ),
                          onDismissed: (direction) {
                            if (direction == DismissDirection.startToEnd) {
                              activity.dismissTip(tip.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(S.of(context)!
                                        .agirSwipeDoneSnackbar(tip.title)),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } else {
                              activity.snoozeTip(
                                  tip.id, const Duration(days: 30));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(S.of(context)!
                                        .agirSwipeSnoozeSnackbar(tip.title)),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                          child: _CoachingTipCard(tip: tip),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],

                // Disclaimer
                _buildDisclaimer(s),
                const SizedBox(height: 80), // FAB clearance
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action #1 (hero) ──────────────────────────────────────
  Widget _buildTopAction(CoachingTip tip, UserActivityProvider activity) {
    final simId = _simulatorIdForTip(tip);
    final isExplored = simId != null && activity.isSimulatorExplored(simId);
    final categoryColor = _colorForCategory(tip.category);

    return GestureDetector(
      onTap: () => context.push(tipRoute(tip)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              categoryColor.withValues(alpha: 0.06),
              categoryColor.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: categoryColor.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: icon + "Priorité #1" badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(tip.icon, color: categoryColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          S.of(context)!.agirPriorityImmediate,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: categoryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tip.title,
                        style: GoogleFonts.montserrat(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isExplored)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: MintColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check,
                        color: MintColors.white, size: 14),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Message
            Text(
              tip.narrativeMessage ?? tip.message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),

            // Impact CHF badge
            if (tip.estimatedImpactChf != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: MintColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up,
                        color: MintColors.success, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${ForecasterService.formatChf(tip.estimatedImpactChf!)} ${S.of(context)!.agirPerYear}',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MintColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // CTA row
            Row(
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        S.of(context)!.agirTopActionCta,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: MintColors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward,
                          color: MintColors.white, size: 16),
                    ],
                  ),
                ),
              ],
            ),

            // Source (legal reference)
            const SizedBox(height: 10),
            Text(
              tip.source,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case 'fiscalite':
        return MintColors.indigo;
      case 'prevoyance':
        return MintColors.cyan;
      case 'budget':
        return MintColors.warning;
      case 'retraite':
        return MintColors.success;
      default:
        return MintColors.info;
    }
  }

  // ── Section label (compact) ─────────────────────────────────
  // ── Budget context bar (simplified: 3 chiffres) ──────────
  Widget _buildBudgetContextBar(CoachProfile profile) {
    final l = S.of(context)!;

    // Compute net income → disponible
    final revenuNet = NetIncomeBreakdown.compute(
      grossSalary: profile.salaireBrutMensuel * 12,
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      age: DateTime.now().year - profile.birthYear,
    ).monthlyNetPayslip;

    final fraisFixes = profile.totalDepensesMensuelles;
    final disponible = revenuNet - fraisFixes;
    final verse = profile.totalContributionsMensuelles;
    final reste = disponible - verse;
    final isOverBudget = reste < 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: isOverBudget
              ? Border.all(color: MintColors.error.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          children: [
            // 3 chiffres: Dispo − Versé = Reste
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BudgetFlowLabel(
                  label: l.agirBudgetAvailable,
                  value: formatChf(disponible),
                  color: MintColors.textPrimary,
                  bold: true,
                ),
                Text('\u2212', style: GoogleFonts.inter(
                  fontSize: 14, color: MintColors.textMuted,
                )),
                _BudgetFlowLabel(
                  label: l.agirBudgetSaved,
                  value: formatChf(verse),
                  color: MintColors.primary,
                ),
                Text('=', style: GoogleFonts.inter(
                  fontSize: 14, color: MintColors.textMuted,
                )),
                _BudgetFlowLabel(
                  label: l.agirBudgetRemaining,
                  value: formatChf(reste),
                  color: isOverBudget ? MintColors.error : MintColors.success,
                  bold: true,
                ),
              ],
            ),
            // Warning if over budget
            if (isOverBudget) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: MintColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.agirBudgetWarning,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: MintColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 18,
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
    );
  }

  // ── Check-in action ────────────────────────────────────────
  Widget _buildCheckinAction({
    required BuildContext context,
    required bool isDone,
    required String monthLabel,
  }) {
    final s = S.of(context)!;
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
                s.agirCheckinDone(monthLabel),
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
                s.agirDone,
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
        onPressed: () => context.push('/coach/checkin'),
        icon: const Icon(Icons.edit_calendar, size: 20),
        label: Text(
          s.agirCheckinCta(monthLabel),
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: MintColors.primary,
          foregroundColor: MintColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    final s = S.of(context)!;
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
        s.agirTitle,
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ── Empty profile state ───────────────────────────────────
  Widget _buildEmptyProfile(BuildContext context, S s) {
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
              child: const Icon(
                Icons.flash_on,
                color: MintColors.coachAccent,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              S.of(context)!.agirEmptyTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              S.of(context)!.agirEmptyBody,
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
                  S.of(context)!.agirEmptyLaunchCta,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  foregroundColor: MintColors.white,
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
  Widget _buildNoContributions(BuildContext context, S s) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.add_circle_outline,
            color: MintColors.coachAccent,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.agirNoContribTitle,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            S.of(context)!.agirNoContribBody,
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
                foregroundColor: MintColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                S.of(context)!.agirNoContribCta,
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

  // ── Build timeline events ──────────────────────────────────
  List<_TimelineEvent> _buildTimelineEvents(CoachProfile profile, S s) {
    final now = DateTime.now();
    final events = <_TimelineEvent>[];

    bool isPastDate(DateTime d) => d.isBefore(now);
    bool isImminent(DateTime d) =>
        !isPastDate(d) && d.difference(now).inDays <= 30;

    // 1. 3a deadline — Dec of current year
    final dec31 = DateTime(now.year, 12, 31);
    events.add(_TimelineEvent(
      date: dec31,
      title: s.agirTimeline3a,
      subtitle: s.agirTimeline3aSub,
      icon: Icons.savings,
      color: isImminent(dec31) ? MintColors.amber : MintColors.indigo,
      cta: s.agirTimeline3aCta,
      isPast: isPastDate(dec31),
      isCompleted: false,
    ));

    // 2. Tax filing — March of next year
    final taxYear = now.month <= 3 ? now.year : now.year + 1;
    final taxDeadline = DateTime(taxYear, 3, 31);
    events.add(_TimelineEvent(
      date: taxDeadline,
      title: s.agirTimelineTax(profile.canton),
      subtitle: s.agirTimelineTaxSub,
      icon: Icons.description,
      color: isImminent(taxDeadline) ? MintColors.amber : MintColors.warning,
      cta: s.agirTimelineTaxCta,
      isPast: isPastDate(taxDeadline),
    ));

    // 3. LAMal franchise — November of current year
    final lamalYear = now.month <= 11 ? now.year : now.year + 1;
    final lamalDeadline = DateTime(lamalYear, 11, 30);
    events.add(_TimelineEvent(
      date: lamalDeadline,
      title: s.agirTimelineLamal,
      subtitle: s.agirTimelineLamalSub,
      icon: Icons.health_and_safety,
      color: isImminent(lamalDeadline) ? MintColors.amber : MintColors.error,
      cta: s.agirTimelineLamalCta,
      isPast: isPastDate(lamalDeadline),
    ));

    // 4. Monthly check-in
    final hasCurrentCheckIn = profile.checkIns.any(
      (ci) => ci.month.year == now.year && ci.month.month == now.month,
    );
    final checkInDate = DateTime(now.year, now.month, 1);
    events.add(_TimelineEvent(
      date: checkInDate,
      title: S.of(context)!.agirTimelineCheckinTitle,
      subtitle: hasCurrentCheckIn
          ? S.of(context)!.agirTimelineCheckinDone
          : S.of(context)!.agirTimelineCheckinPending,
      icon: hasCurrentCheckIn
          ? Icons.check_circle
          : Icons.calendar_today_outlined,
      color: hasCurrentCheckIn ? MintColors.positive : MintColors.amber,
      cta: hasCurrentCheckIn ? null : S.of(context)!.agirTimelineCheckinCta,
      isCompleted: hasCurrentCheckIn,
    ));

    // 5. Milestones from ForecasterService (max 2)
    try {
      final projection = ForecasterService.project(profile: profile);
      for (final milestone in projection.milestones.take(2)) {
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
      // Graceful degradation
    }

    // 6. Retirement
    events.add(_TimelineEvent(
      date: profile.goalA.targetDate,
      title: S.of(context)!
          .agirTimelineRetirementTitle(profile.firstName ?? ''),
      subtitle: s.agirTimelineRetireSub,
      icon: Icons.beach_access,
      color: MintColors.trajectoryOptimiste,
      isPast: isPastDate(profile.goalA.targetDate),
    ));

    // Sort by date, keep future + recently completed
    events.sort((a, b) => a.date.compareTo(b.date));
    return events
        .where((e) =>
            e.isCompleted ||
            e.date.isAfter(now.subtract(const Duration(days: 31))))
        .toList();
  }

  // ── Disclaimer ─────────────────────────────────────────────
  Widget _buildDisclaimer(S s) {
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
          const Icon(
            Icons.info_outline,
            color: MintColors.textMuted,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.agirDisclaimer,
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
    final s = S.of(context)!;
    final icon = iconForCategory(contribution.category);
    final color = colorForCategory(contribution.category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.03),
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
                  ? s.agirAuto
                  : s.agirManuel,
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
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 12,
                    color: MintColors.border,
                  )
                else
                  const SizedBox(height: 12),

                _buildTimelineDot(),

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
                  color: MintColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MintColors.lightBorder),
                  boxShadow: [
                    BoxShadow(
                      color: MintColors.primary.withValues(alpha: 0.03),
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
                        Text(
                          _yearsUntil(context, event.date),
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
                            ? MintColors.positive
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
                          backgroundColor:
                              event.color.withValues(alpha: 0.08),
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
      dotColor = MintColors.positive;
      dotChild = const Icon(Icons.check, size: 10, color: MintColors.white);
    } else if (event.isPast) {
      dotColor = MintColors.greyNeutral;
    } else if (daysUntil <= 30 && daysUntil >= 0) {
      dotColor = MintColors.amber;
    } else {
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

  String _yearsUntil(BuildContext context, DateTime target) {
    final now = DateTime.now();
    final months = (target.year - now.year) * 12 + (target.month - now.month);
    if (months < 1) return S.of(context)!.agirTimelineThisMonth;
    if (months < 12) {
      return S.of(context)!.agirTimelineInMonths(months.toString());
    }
    final years = months ~/ 12;
    if (years == 1) return S.of(context)!.agirTimelineInOneYear;
    return S.of(context)!.agirTimelineInYears(years.toString());
  }
}

// ════════════════════════════════════════════════════════════════
//  COACHING TIP CARD (compact, for "other actions" list)
// ════════════════════════════════════════════════════════════════

class _CoachingTipCard extends StatelessWidget {
  final CoachingTip tip;

  const _CoachingTipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    final categoryColor = _colorForTipCategory(tip.category);

    return GestureDetector(
      onTap: () => context.push(tipRoute(tip)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MintColors.lightBorder),
          boxShadow: [
            BoxShadow(
              color: MintColors.primary.withValues(alpha: 0.03),
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
                color: categoryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tip.icon, color: categoryColor, size: 18),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 2),
                  Text(
                    tip.source,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: MintColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (tip.estimatedImpactChf != null) ...[
              const SizedBox(width: 8),
              Text(
                ForecasterService.formatChf(tip.estimatedImpactChf!),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.success,
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: MintColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForTipCategory(String category) {
    switch (category) {
      case 'fiscalite':
        return MintColors.indigo;
      case 'prevoyance':
        return MintColors.cyan;
      case 'budget':
        return MintColors.warning;
      case 'retraite':
        return MintColors.success;
      default:
        return MintColors.info;
    }
  }
}

/// Compact label for budget flow bar (value + label stacked).
class _BudgetFlowLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _BudgetFlowLabel({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: MintColors.textMuted,
          ),
        ),
      ],
    );
  }
}
