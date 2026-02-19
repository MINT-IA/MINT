import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/analytics_service.dart';
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

  @override
  void initState() {
    super.initState();
    _analytics.trackScreenView('/advisor/plan-30-days');
    _analytics.trackEvent(
      'onboarding_plan30_viewed',
      category: 'engagement',
      data: {
        'stress_choice': widget.stressChoice,
        'main_goal': widget.mainGoal,
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final actions = _buildPlanActions();
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
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final action in actions) ...[
            _PlanActionCard(
              action: action,
              onTap: () {
                _analytics.trackCTAClick(
                  'onboarding_plan30_step_open',
                  screenName: '/advisor/plan-30-days',
                  data: {'route': action.route, 'title': action.title},
                );
                context.push(action.route);
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              _analytics.trackCTAClick(
                'onboarding_plan30_open_dashboard',
                screenName: '/advisor/plan-30-days',
              );
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
    required this.onTap,
  });

  final _PlanAction action;
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
