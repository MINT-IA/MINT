import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

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

const _categories = <_EventCategory>[
  _EventCategory(
    label: 'FAMILLE',
    icon: Icons.family_restroom,
    color: MintColors.error,
    events: [
      _LifeEvent(
        title: 'Mariage',
        subtitle: 'Impact LPP, AVS, impôts et régime matrimonial',
        icon: Icons.favorite_outline,
        route: '/mariage',
        accentColor: MintColors.error,
      ),
      _LifeEvent(
        title: 'Concubinage',
        subtitle: 'Prévoyance, succession et fiscalité du couple non marié',
        icon: Icons.people_outline,
        route: '/concubinage',
        accentColor: MintColors.warning,
      ),
      _LifeEvent(
        title: 'Naissance',
        subtitle: 'Allocations, déductions fiscales et assurances',
        icon: Icons.child_care,
        route: '/naissance',
        accentColor: MintColors.info,
      ),
      _LifeEvent(
        title: 'Divorce',
        subtitle: 'Partage LPP, pension et réorganisation financière',
        icon: Icons.heart_broken_outlined,
        route: '/divorce',
        accentColor: MintColors.warning,
      ),
      _LifeEvent(
        title: 'Succession',
        subtitle: 'Réserves héréditaires, partage et impôts (CC art. 457ss)',
        icon: Icons.account_balance_outlined,
        route: '/succession',
        accentColor: MintColors.primary,
      ),
    ],
  ),
  _EventCategory(
    label: 'PROFESSIONNEL',
    icon: Icons.work_outline,
    color: MintColors.info,
    events: [
      _LifeEvent(
        title: 'Premier emploi',
        subtitle: 'Premiers pas\u00a0: AVS, LPP, 3a et budget',
        icon: Icons.school_outlined,
        route: '/first-job',
        accentColor: MintColors.info,
      ),
      _LifeEvent(
        title: 'Changement d\'emploi',
        subtitle: 'Comparaison LPP, libre passage et négociation',
        icon: Icons.swap_horiz,
        route: '/simulator/job-comparison',
        accentColor: MintColors.primary,
      ),
      _LifeEvent(
        title: 'Indépendant',
        subtitle: 'AVS, LPP volontaire, 3a élargi et dividende vs salaire',
        icon: Icons.storefront_outlined,
        route: '/segments/independant',
        accentColor: MintColors.success,
      ),
      _LifeEvent(
        title: 'Perte d\'emploi',
        subtitle: 'Chômage, délai de carence et protection prévoyance',
        icon: Icons.trending_down,
        route: '/unemployment',
        accentColor: MintColors.warning,
      ),
      _LifeEvent(
        title: 'Retraite',
        subtitle: 'Rente vs capital, échelonnement 3a, lacune AVS',
        icon: Icons.elderly,
        route: '/retraite',
        accentColor: MintColors.primary,
      ),
    ],
  ),
  _EventCategory(
    label: 'PATRIMOINE',
    icon: Icons.account_balance_wallet_outlined,
    color: MintColors.success,
    events: [
      _LifeEvent(
        title: 'Achat immobilier',
        subtitle: 'Capacité d\'emprunt, EPL et impôt sur la valeur locative',
        icon: Icons.home_outlined,
        route: '/hypotheque',
        accentColor: MintColors.success,
      ),
      _LifeEvent(
        title: 'Vente immobilière',
        subtitle: 'Plus-value, impôt cantonal et remploi',
        icon: Icons.real_estate_agent,
        route: '/life-event/housing-sale',
        accentColor: MintColors.warning,
      ),
      _LifeEvent(
        title: 'Héritage',
        subtitle: 'Estimation, impôt cantonal et partage successoral',
        icon: Icons.volunteer_activism,
        route: '/succession',
        accentColor: MintColors.info,
      ),
      _LifeEvent(
        title: 'Donation',
        subtitle: 'Impôt cantonal, réserves et quotité disponible',
        icon: Icons.card_giftcard,
        route: '/life-event/donation',
        accentColor: MintColors.primary,
      ),
    ],
  ),
  _EventCategory(
    label: 'SANTÉ',
    icon: Icons.health_and_safety_outlined,
    color: MintColors.error,
    events: [
      _LifeEvent(
        title: 'Invalidité',
        subtitle: 'Lacune de couverture AI + LPP et prévention',
        icon: Icons.accessible,
        route: '/invalidite',
        accentColor: MintColors.error,
      ),
    ],
  ),
  _EventCategory(
    label: 'MOBILITÉ',
    icon: Icons.flight_takeoff,
    color: MintColors.warning,
    events: [
      _LifeEvent(
        title: 'Déménagement cantonal',
        subtitle: 'Impact fiscal du changement de canton (26 barèmes)',
        icon: Icons.map_outlined,
        route: '/fiscal',
        accentColor: MintColors.warning,
      ),
      _LifeEvent(
        title: 'Expatriation / Frontalier',
        subtitle: 'Double imposition, 3a et couverture sociale',
        icon: Icons.public,
        route: '/expatriation',
        accentColor: MintColors.info,
      ),
    ],
  ),
  _EventCategory(
    label: 'CRISE',
    icon: Icons.warning_amber_rounded,
    color: MintColors.error,
    events: [
      _LifeEvent(
        title: 'Surendettement',
        subtitle: 'Ratio d\'endettement, plan de remboursement et aide',
        icon: Icons.crisis_alert,
        route: '/check/debt',
        accentColor: MintColors.error,
      ),
    ],
  ),
];

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

const _quickActions = <_QuickAction>[
  _QuickAction(
    title: 'Check-up financier',
    subtitle: 'Lancer le diagnostic complet',
    icon: Icons.shield_outlined,
    route: '/onboarding/quick',
    color: MintColors.primary,
  ),
  _QuickAction(
    title: 'Budget',
    subtitle: 'Gérer le cashflow mensuel',
    icon: Icons.pie_chart_outline,
    route: '/budget',
    color: MintColors.success,
  ),
  _QuickAction(
    title: 'Pilier 3a',
    subtitle: 'Optimiser la déduction fiscale',
    icon: Icons.savings_outlined,
    route: '/pilier-3a',
    color: MintColors.info,
  ),
  _QuickAction(
    title: 'Fiscalité',
    subtitle: 'Comparer 26 cantons',
    icon: Icons.receipt_long,
    route: '/fiscal',
    color: MintColors.warning,
  ),
];

// ────────────────────────────────────────────────────────────
//  TIMELINE SCREEN
// ────────────────────────────────────────────────────────────

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildTimelineHeader()),
          // Quick actions row
          SliverToBoxAdapter(child: _buildQuickActions(context)),
          // Life events by category
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),
                _buildSectionTitle('ÉVÉNEMENTS DE VIE', Icons.timeline),
                const SizedBox(height: 4),
                Text(
                  'Sélectionne un événement pour simuler son impact financier.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                for (final category in _categories) ...[
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
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: MintColors.background,
      title: Text(
        'MON PARCOURS',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
          fontSize: 14,
          color: MintColors.primary,
        ),
      ),
    );
  }

  Widget _buildTimelineHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ta vie financière,\nétape par étape.',
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Outils essentiels et événements de vie — tout est là.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick actions (horizontal scroll) ──────────────────────

  Widget _buildQuickActions(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: _quickActions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final action = _quickActions[index];
          return _buildQuickActionCard(context, action);
        },
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, _QuickAction action) {
    return GestureDetector(
      onTap: () => context.push(action.route),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: action.color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: action.color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(action.icon, color: action.color, size: 18),
            ),
            const Spacer(),
            Text(
              action.title,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              action.subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: MintColors.primary,
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
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: MintColors.textMuted,
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
    return Material(
      color: MintColors.transparent,
      child: InkWell(
        onTap: () => context.push(event.route),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MintColors.lightBorder),
          ),
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
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: MintColors.textSecondary,
                      ),
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
    );
  }
}
