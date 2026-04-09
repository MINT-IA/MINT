import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  LIFE EVENT DEFINITION
// ────────────────────────────────────────────────────────────

class _LifeEvent {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color accentColor;

  const _LifeEvent({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.accentColor,
  });
}

// ────────────────────────────────────────────────────────────
//  CATEGORY DEFINITION
// ────────────────────────────────────────────────────────────

class _EventCategory {
  final String label;
  final IconData icon;
  final Color color;
  final List<_LifeEvent> events;

  const _EventCategory({
    required this.label,
    required this.icon,
    required this.color,
    required this.events,
  });
}

// ────────────────────────────────────────────────────────────
//  ALL 18 LIFE EVENTS — organized by 6 categories
// ────────────────────────────────────────────────────────────

List<_EventCategory> _buildCategories(BuildContext context) {
  final s = S.of(context)!;
  return [
    _EventCategory(
      label: s.timelineCatFamille,
      icon: Icons.family_restroom,
      color: MintColors.error,
      events: [
        _LifeEvent(
          title: s.timelineEventMariageTitle,
          subtitle: s.timelineEventMariageSub,
          icon: Icons.favorite_outline,
          route: '/mariage',
          accentColor: MintColors.error,
        ),
        _LifeEvent(
          title: s.timelineEventConcubinageTitle,
          subtitle: s.timelineEventConcubitageSub,
          icon: Icons.people_outline,
          route: '/concubinage',
          accentColor: MintColors.warning,
        ),
        _LifeEvent(
          title: s.timelineEventNaissanceTitle,
          subtitle: s.timelineEventNaissanceSub,
          icon: Icons.child_care,
          route: '/naissance',
          accentColor: MintColors.info,
        ),
        _LifeEvent(
          title: s.timelineEventDivorceTitle,
          subtitle: s.timelineEventDivorceSub,
          icon: Icons.heart_broken_outlined,
          route: '/divorce',
          accentColor: MintColors.warning,
        ),
        _LifeEvent(
          title: s.timelineEventSuccessionTitle,
          subtitle: s.timelineEventSuccessionSub,
          icon: Icons.account_balance_outlined,
          route: '/succession',
          accentColor: MintColors.primary,
        ),
      ],
    ),
    _EventCategory(
      label: s.timelineCatProfessionnel,
      icon: Icons.work_outline,
      color: MintColors.info,
      events: [
        _LifeEvent(
          title: s.timelineEventPremierEmploiTitle,
          subtitle: s.timelineEventPremierEmploiSub,
          icon: Icons.school_outlined,
          route: '/first-job',
          accentColor: MintColors.info,
        ),
        _LifeEvent(
          title: s.timelineEventChangementEmploiTitle,
          subtitle: s.timelineEventChangementEmploiSub,
          icon: Icons.swap_horiz,
          route: '/simulator/job-comparison',
          accentColor: MintColors.primary,
        ),
        _LifeEvent(
          title: s.timelineEventIndependantTitle,
          subtitle: s.timelineEventIndependantSub,
          icon: Icons.storefront_outlined,
          route: '/segments/independant',
          accentColor: MintColors.success,
        ),
        _LifeEvent(
          title: s.timelineEventPerteEmploiTitle,
          subtitle: s.timelineEventPerteEmploiSub,
          icon: Icons.trending_down,
          route: '/unemployment',
          accentColor: MintColors.warning,
        ),
        _LifeEvent(
          title: s.timelineEventRetraiteTitle,
          subtitle: s.timelineEventRetraiteSub,
          icon: Icons.elderly,
          route: '/retraite',
          accentColor: MintColors.primary,
        ),
      ],
    ),
    _EventCategory(
      label: s.timelineCatPatrimoine,
      icon: Icons.account_balance_wallet_outlined,
      color: MintColors.success,
      events: [
        _LifeEvent(
          title: s.timelineEventAchatImmoTitle,
          subtitle: s.timelineEventAchatImmoSub,
          icon: Icons.home_outlined,
          route: '/hypotheque',
          accentColor: MintColors.success,
        ),
        _LifeEvent(
          title: s.timelineEventVenteImmoTitle,
          subtitle: s.timelineEventVenteImmoSub,
          icon: Icons.real_estate_agent,
          route: '/life-event/housing-sale',
          accentColor: MintColors.warning,
        ),
        _LifeEvent(
          title: s.timelineEventHeritageTitle,
          subtitle: s.timelineEventHeritageSub,
          icon: Icons.volunteer_activism,
          route: '/succession',
          accentColor: MintColors.info,
        ),
        _LifeEvent(
          title: s.timelineEventDonationTitle,
          subtitle: s.timelineEventDonationSub,
          icon: Icons.card_giftcard,
          route: '/life-event/donation',
          accentColor: MintColors.primary,
        ),
      ],
    ),
    _EventCategory(
      label: s.timelineCatSante,
      icon: Icons.health_and_safety_outlined,
      color: MintColors.error,
      events: [
        _LifeEvent(
          title: s.timelineEventInvaliditeTitle,
          subtitle: s.timelineEventInvaliditeSub,
          icon: Icons.accessible,
          route: '/invalidite',
          accentColor: MintColors.error,
        ),
      ],
    ),
    _EventCategory(
      label: s.timelineCatMobilite,
      icon: Icons.flight_takeoff,
      color: MintColors.warning,
      events: [
        _LifeEvent(
          title: s.timelineEventDemenagementTitle,
          subtitle: s.timelineEventDemenagementSub,
          icon: Icons.map_outlined,
          route: '/fiscal',
          accentColor: MintColors.warning,
        ),
        _LifeEvent(
          title: s.timelineEventExpatriationTitle,
          subtitle: s.timelineEventExpatriationSub,
          icon: Icons.public,
          route: '/expatriation',
          accentColor: MintColors.info,
        ),
      ],
    ),
    _EventCategory(
      label: s.timelineCatCrise,
      icon: Icons.warning_amber_rounded,
      color: MintColors.error,
      events: [
        _LifeEvent(
          title: s.timelineEventSurendettementTitle,
          subtitle: s.timelineEventSurendettementSub,
          icon: Icons.crisis_alert,
          route: '/check/debt',
          accentColor: MintColors.error,
        ),
      ],
    ),
  ];
}

// ────────────────────────────────────────────────────────────
//  QUICK ACTIONS (outils essentiels)
// ────────────────────────────────────────────────────────────

class _QuickAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color color;

  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.color,
  });
}

List<_QuickAction> _buildQuickActionItems(BuildContext context) {
  final s = S.of(context)!;
  return [
    _QuickAction(
      title: s.timelineQuickCheckupTitle,
      subtitle: s.timelineQuickCheckupSub,
      icon: Icons.shield_outlined,
      route: '/coach/chat',
      color: MintColors.primary,
    ),
    _QuickAction(
      title: s.timelineQuickBudgetTitle,
      subtitle: s.timelineQuickBudgetSub,
      icon: Icons.pie_chart_outline,
      route: '/budget',
      color: MintColors.success,
    ),
    _QuickAction(
      title: s.timelineQuickPilier3aTitle,
      subtitle: s.timelineQuickPilier3aSub,
      icon: Icons.savings_outlined,
      route: '/pilier-3a',
      color: MintColors.info,
    ),
    _QuickAction(
      title: s.timelineQuickFiscaliteTitle,
      subtitle: s.timelineQuickFiscaliteSub,
      icon: Icons.receipt_long,
      route: '/fiscal',
      color: MintColors.warning,
    ),
  ];
}

// ────────────────────────────────────────────────────────────
//  TIMELINE SCREEN
// ────────────────────────────────────────────────────────────

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final categories = _buildCategories(context);
    return Scaffold(
      backgroundColor: MintColors.background,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildTimelineHeader(context)),
          // Quick actions row
          SliverToBoxAdapter(child: _buildQuickActions(context)),
          // Life events by category
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),
                _buildSectionTitle(s.timelineSectionTitleUpper, Icons.timeline),
                const SizedBox(height: 4),
                Text(
                  s.timelineSectionSubtitle,
                  style: MintTextStyles.bodySmall(),
                ),
                const SizedBox(height: 16),
                for (final category in categories) ...[
                  _buildCategoryHeader(category),
                  const SizedBox(height: 8),
                  for (var i = 0; i < category.events.length; i++) ...[
                    _buildEventCard(context, category.events[i]),
                    if (i < category.events.length - 1)
                      const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 20),
                ],
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ))),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final s = S.of(context)!;
    return SliverAppBar(
      floating: true,
      backgroundColor: MintColors.white,
      elevation: 0,
      title: Text(
        s.timelineTitle,
        style: MintTextStyles.titleLarge(),
      ),
    );
  }

  Widget _buildTimelineHeader(BuildContext context) {
    final s = S.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.timelineHeader,
            style: MintTextStyles.headlineLarge().copyWith(fontSize: 24),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            s.timelineSubheader,
            style: MintTextStyles.bodyMedium(),
          ),
        ],
      ),
    );
  }

  // ── Quick actions (horizontal scroll) ──────────────────────

  Widget _buildQuickActions(BuildContext context) {
    final actions = _buildQuickActionItems(context);
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final action = actions[index];
          return _buildQuickActionCard(context, action);
        },
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, _QuickAction action) {
    return Semantics(
      label: action.title,
      button: true,
      child: GestureDetector(
        onTap: () => context.push(action.route),
        child: MintSurface(
        padding: const EdgeInsets.all(14),
        radius: 16,
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MintEntrance(child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(action.icon, color: action.color, size: 18),
            )),
            const Spacer(),
            MintEntrance(delay: const Duration(milliseconds: 100), child: Text(
              action.title,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(
                fontWeight: FontWeight.w700,
              ),
            )),
            const SizedBox(height: MintSpacing.xs),
            MintEntrance(delay: const Duration(milliseconds: 200), child: Text(
              action.subtitle,
              style: MintTextStyles.micro(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )),
          ],
        ),
      ),
    ),
    );
  }

  // ── Section title ──────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: MintColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: MintTextStyles.labelSmall(color: MintColors.primary).copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider()),
      ],
    );
  }

  // ── Category header ────────────────────────────────────────

  Widget _buildCategoryHeader(_EventCategory category) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(category.icon, color: category.color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          category.label,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(color: category.color.withValues(alpha: 0.2)),
        ),
      ],
    );
  }

  // ── Event card ─────────────────────────────────────────────

  Widget _buildEventCard(BuildContext context, _LifeEvent event) {
    return Semantics(
      label: event.title,
      button: true,
      child: Material(
        color: MintColors.transparent,
        child: InkWell(
          onTap: () => context.push(event.route),
          borderRadius: BorderRadius.circular(14),
        child: MintSurface(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          radius: 14,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: event.accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(event.icon, color: event.accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      event.subtitle,
                      style: MintTextStyles.labelSmall(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: event.accentColor.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
