import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';

class Onboarding30DayPlanScreen extends StatefulWidget {
  const Onboarding30DayPlanScreen({
    super.key,
    this.stressChoice,
    this.mainGoal,
  });

  final String? stressChoice;
  final String? mainGoal;

  @override
  State<Onboarding30DayPlanScreen> createState() =>
      _Onboarding30DayPlanScreenState();
}

class _PlanAction {
  const _PlanAction({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
}

class _Onboarding30DayPlanScreenState extends State<Onboarding30DayPlanScreen> {
  final AnalyticsService _analytics = AnalyticsService();
  Set<String> _openedRoutes = <String>{};
  String? _lastRoute;
  bool _isCompleted = false;
  bool _isHydrating = true;

  @override
  void initState() {
    super.initState();
    _initPlanState();
  }

  Future<void> _initPlanState() async {
    _analytics.trackScreenView('/advisor/plan-30-days');
    final existing = await ReportPersistenceService.loadOnboarding30PlanState();
    final hadStarted = existing['started_at'] != null;
    await ReportPersistenceService.markOnboarding30PlanStarted(
      stressChoice: widget.stressChoice,
      mainGoal: widget.mainGoal,
    );
    final refreshed =
        await ReportPersistenceService.loadOnboarding30PlanState();
    if (!mounted) return;
    setState(() {
      _openedRoutes = Set<String>.from(
        (refreshed['opened_routes'] as List?) ?? const [],
      );
      _lastRoute = refreshed['last_route'] as String?;
      _isCompleted = refreshed['completed'] == true;
      _isHydrating = false;
    });

    _analytics.trackEvent(
      'onboarding_plan30_viewed',
      category: 'engagement',
      data: {
        'stress_choice': widget.stressChoice,
        'main_goal': widget.mainGoal,
        'opened_steps': _openedRoutes.length,
        'completed': _isCompleted,
      },
    );

    if (!hadStarted) {
      _analytics.trackEvent(
        'onboarding_plan30_started',
        category: 'conversion',
        data: {
          'stress_choice': widget.stressChoice,
          'main_goal': widget.mainGoal,
        },
      );
    }
  }

  List<_PlanAction> _buildPlanActions() {
    switch (widget.stressChoice) {
      case 'debt':
      case 'budget':
        return const [
          _PlanAction(
            title: 'Jour 1-7 · Stabiliser',
            subtitle: 'Mesure ton risque d endettement et stoppe les fuites.',
            route: '/check/debt',
            icon: Icons.warning_amber_rounded,
          ),
          _PlanAction(
            title: 'Jour 8-15 · Reprendre le controle',
            subtitle: 'Construis ton budget cible et ton reste a vivre.',
            route: '/budget',
            icon: Icons.pie_chart_outline_rounded,
          ),
          _PlanAction(
            title: 'Jour 16-30 · Passer a l action',
            subtitle: 'Active ton plan d actions et priorise les gains CHF.',
            route: '/coach/agir',
            icon: Icons.flash_on_rounded,
          ),
        ];
      case 'tax':
        return const [
          _PlanAction(
            title: 'Jour 1-7 · Cartographier',
            subtitle: 'Identifie ou tu perds le plus en impots.',
            route: '/fiscal',
            icon: Icons.receipt_long_rounded,
          ),
          _PlanAction(
            title: 'Jour 8-15 · Simuler',
            subtitle: 'Teste les scenarios 3a et rachat LPP.',
            route: '/simulator/3a',
            icon: Icons.calculate_rounded,
          ),
          _PlanAction(
            title: 'Jour 16-30 · Executer',
            subtitle: 'Transforme les scenarios en actions coachables.',
            route: '/coach/agir',
            icon: Icons.rocket_launch_rounded,
          ),
        ];
      case 'pension':
      default:
        return const [
          _PlanAction(
            title: 'Jour 1-7 · Voir ta trajectoire',
            subtitle: 'Lis ta projection retraite actuelle.',
            route: '/retirement/projection',
            icon: Icons.show_chart_rounded,
          ),
          _PlanAction(
            title: 'Jour 8-15 · Arbitrer rente/capital',
            subtitle: 'Compare les options et le risque de trou.',
            route: '/simulator/rente-capital',
            icon: Icons.balance_rounded,
          ),
          _PlanAction(
            title: 'Jour 16-30 · Industrialiser',
            subtitle: 'Passe en mode coach mensuel avec check-in.',
            route: '/coach/checkin',
            icon: Icons.event_repeat_rounded,
          ),
        ];
    }
  }

  Future<void> _openPlanAction(
      _PlanAction action, List<_PlanAction> actions) async {
    final wasOpened = _openedRoutes.contains(action.route);
    final before = _openedRoutes.length;
    await ReportPersistenceService.markOnboarding30PlanRouteOpened(
        action.route);
    if (!mounted) return;

    setState(() {
      _openedRoutes = {..._openedRoutes, action.route};
      _lastRoute = action.route;
    });

    _analytics.trackCTAClick(
      'onboarding_plan30_step_open',
      screenName: '/advisor/plan-30-days',
      data: {
        'route': action.route,
        'title': action.title,
        'already_opened': wasOpened,
        'progress_before': before,
        'progress_after': _openedRoutes.length,
      },
    );

    if (!_isCompleted && _openedRoutes.length >= actions.length) {
      _isCompleted = true;
      await ReportPersistenceService.setOnboarding30PlanCompleted(true);
      _analytics.trackEvent(
        'onboarding_plan30_completed',
        category: 'conversion',
        data: {
          'stress_choice': widget.stressChoice,
          'main_goal': widget.mainGoal,
          'steps_count': actions.length,
        },
      );
    }

    if (!mounted) return;
    await context.push(action.route);
  }

  @override
  Widget build(BuildContext context) {
    final actions = _buildPlanActions();
    final completionRatio = actions.isEmpty
        ? 0.0
        : (_openedRoutes.length / actions.length).clamp(0.0, 1.0);
    final nextAction = actions.firstWhere(
      (a) => !_openedRoutes.contains(a.route),
      orElse: () => actions.last,
    );

    if (_isHydrating) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: MintColors.surface,
      appBar: AppBar(
        backgroundColor: MintColors.surface,
        title: Text(
          'PLAN 30 JOURS',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: MintColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ton onboarding est complete.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Voici ton plan actionnable sur 30 jours pour passer de la theorie aux resultats.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: completionRatio,
                    minHeight: 8,
                    backgroundColor: Colors.white,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(MintColors.primary),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_openedRoutes.length}/${actions.length} etapes ouvertes',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!_isCompleted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MintColors.lightBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline_rounded,
                      color: MintColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _lastRoute != null
                          ? 'Reprendre ta derniere action'
                          : 'Prochaine action recommandee: ${nextAction.title}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final route = _lastRoute ?? nextAction.route;
                      final action = actions.firstWhere(
                        (a) => a.route == route,
                        orElse: () => nextAction,
                      );
                      await _openPlanAction(action, actions);
                    },
                    child: const Text('Reprendre'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          for (final action in actions) ...[
            _PlanActionCard(
              action: action,
              isDone: _openedRoutes.contains(action.route),
              onTap: () => _openPlanAction(action, actions),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              if (!_isCompleted && _openedRoutes.length >= actions.length) {
                _isCompleted = true;
                await ReportPersistenceService.setOnboarding30PlanCompleted(
                    true);
              }
              _analytics.trackCTAClick(
                'onboarding_plan30_open_dashboard',
                screenName: '/advisor/plan-30-days',
                data: {
                  'completion_ratio': completionRatio,
                  'completed': _isCompleted,
                },
              );
              if (!context.mounted) return;
              context.go('/home');
            },
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Aller au dashboard'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              _analytics.trackCTAClick(
                'onboarding_plan30_open_wizard',
                screenName: '/advisor/plan-30-days',
              );
              context.push('/advisor/wizard');
            },
            child: const Text('Completer mon diagnostic'),
          ),
        ],
      ),
    );
  }
}

class _PlanActionCard extends StatelessWidget {
  const _PlanActionCard({
    required this.action,
    required this.isDone,
    required this.onTap,
  });

  final _PlanAction action;
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(action.icon, color: MintColors.primary, size: 20),
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
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (isDone)
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: MintColors.success)
            else
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: MintColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
