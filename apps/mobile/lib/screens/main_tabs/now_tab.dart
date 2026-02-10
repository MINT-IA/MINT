import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/services/recommendations_service.dart';
import 'package:mint_mobile/services/timeline_service.dart';
import 'package:mint_mobile/models/recommendation.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/widgets/mint_ui_kit.dart';
import 'package:mint_mobile/widgets/action_card.dart';

/// Tab MAINTENANT - Actions contextuelles selon la situation
class NowTab extends StatelessWidget {
  const NowTab({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final isSafeMode = profile?.hasDebt ?? false;

    // Générer recommandations dynamiques
    final recommendations = RecommendationsService.generateRecommendations(
      profile: profile,
      maxRecommendations: 3,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              MintColors.appleSurface.withValues(alpha: 0.3),
            ],
            stops: const [0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // 1. Unified Ambient Blobs (Subtle)
            Positioned(
              top: -120,
              right: -50,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MintColors.primary.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            // 2. Contenu Scrollable
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Header
                      MintAnimateFadeUp(
                        child: MintHeader(
                          title: 'Bonjour, Julien',
                          subtitle: 'MAINTENANT',
                          isLarge: true,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Situation Card
                      MintAnimateFadeUp(
                        delayInMs: 100,
                        child: isSafeMode
                            ? _buildProtectionMode(context)
                            : _buildNormalMode(context, profile),
                      ),
                      const SizedBox(height: 32),

                      // Open Banking (Sprint S14)
                      MintAnimateFadeUp(
                        delayInMs: 150,
                        child: _buildOpenBankingSection(context),
                      ),
                      const SizedBox(height: 32),

                      // LPP Approfondi (Sprint S15)
                      MintAnimateFadeUp(
                        delayInMs: 175,
                        child: _buildLppDeepSection(context),
                      ),
                      const SizedBox(height: 32),

                      // Coaching Proactif
                      MintAnimateFadeUp(
                        delayInMs: 200,
                        child: _buildCoachingCard(context),
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      MintAnimateFadeUp(
                        delayInMs: 250,
                        child: _buildActionsSection(context, recommendations),
                      ),
                      const SizedBox(height: 32),

                      // Assurances
                      MintAnimateFadeUp(
                        delayInMs: 300,
                        child: _buildAssurancesSection(context),
                      ),
                      const SizedBox(height: 32),

                      // Segments sociologiques
                      MintAnimateFadeUp(
                        delayInMs: 350,
                        child: _buildSegmentsSection(context),
                      ),
                      const SizedBox(height: 32),

                      // Timeline
                      MintAnimateFadeUp(
                        delayInMs: 400,
                        child: _buildTimelineSection(context, profile),
                      ),
                      const SizedBox(height: 32),

                      // Evenements de vie
                      MintAnimateFadeUp(
                        delayInMs: 450,
                        child: _buildLifeEventsSection(context),
                      ),
                      const SizedBox(height: 32),

                      // Decouvrir les outils
                      MintAnimateFadeUp(
                        delayInMs: 500,
                        child: _buildDiscoverToolsSection(context),
                      ),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtectionMode(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.warning.withValues(alpha: 0.1),
            MintColors.warning.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.warning.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: MintColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MODE PROTECTION',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: MintColors.warning,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ton budget est sous contrôle',
                      style: TextStyle(
                        fontSize: 14,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MintColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      '2',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: MintColors.warning,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Actions urgentes à traiter',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: MintColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.warning,
              ),
              child: const Text('Voir mon plan de stabilisation'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalMode(BuildContext context, dynamic profile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.primary.withValues(alpha: 0.05),
            MintColors.appleSurface.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header moved to top
          Row(
            children: [
              _buildStatChip(
                  Icons.track_changes, 'Objectif', 'Moins d\'impôts'),
              const SizedBox(width: 12),
              _buildStatChip(Icons.insights, 'Précision', '67%'),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => context.push('/advisor'),
            child: const Text('Compléter mon profil +15%'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MintColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: MintColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachingCard(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/coaching'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade50, Colors.amber.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.tips_and_updates,
                  color: Colors.amber.shade700, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Coaching proactif',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Conseils personnalises selon votre profil \u2192',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.black45),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(
      BuildContext context, List<Recommendation> recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'ACTIONS RECOMMANDÉES',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var rec in recommendations) ...[
          ActionCard(
            icon: _getIconForKind(rec.kind),
            title: rec.title,
            subtitle: rec.summary,
            color: _getColorForKind(rec.kind),
            onTap: () {
              if (rec.nextActions.isNotEmpty) {
                final action = rec.nextActions.first;
                if (action.type == NextActionType.simulate) {
                  // Router vers le simulateur approprié
                  if (rec.kind == 'pillar3a') {
                    context.push('/simulator/3a');
                  } else if (rec.kind == 'compound_interest') {
                    context.push('/simulator/compound');
                  }
                } else if (action.type == NextActionType.checklist) {
                  context.push('/advisor');
                }
              }
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  IconData _getIconForKind(String kind) {
    switch (kind) {
      case 'pillar3a':
        return Icons.savings_outlined;
      case 'lpp':
        return Icons.account_balance;
      case 'compound_interest':
        return Icons.trending_up;
      case 'protection':
        return Icons.shield_outlined;
      case 'onboarding':
        return Icons.auto_awesome;
      default:
        return Icons.lightbulb_outline;
    }
  }

  Color _getColorForKind(String kind) {
    switch (kind) {
      case 'pillar3a':
        return MintColors.success;
      case 'lpp':
        return MintColors.primary;
      case 'compound_interest':
        return Colors.purple;
      case 'protection':
        return MintColors.warning;
      case 'onboarding':
        return MintColors.primary;
      default:
        return MintColors.textMuted;
    }
  }

  Widget _buildOpenBankingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_balance_outlined, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'OPEN BANKING',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => context.push('/open-banking'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.account_balance, color: Colors.teal.shade700, size: 22),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade600,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock, color: Colors.white, size: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Open Banking',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Connectez vos comptes bancaires',
                        style: TextStyle(
                          fontSize: 12,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: MintColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLppDeepSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_balance_outlined, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'LPP APPROFONDI',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSegmentTile(
          context: context,
          icon: Icons.trending_up,
          color: Colors.green,
          title: 'Rachat echelonne',
          subtitle: 'Optimisez vos rachats LPP sur plusieurs annees',
          route: '/lpp-deep/rachat',
        ),
        const SizedBox(height: 12),
        _buildSegmentTile(
          context: context,
          icon: Icons.swap_horiz,
          color: Colors.blue,
          title: 'Libre passage',
          subtitle: 'Checklist en cas de changement d\'emploi ou depart',
          route: '/lpp-deep/libre-passage',
        ),
        const SizedBox(height: 12),
        _buildSegmentTile(
          context: context,
          icon: Icons.home_outlined,
          color: Colors.teal,
          title: 'Retrait EPL',
          subtitle: 'Financer un logement avec votre 2e pilier',
          route: '/lpp-deep/epl',
        ),
      ],
    );
  }

  Widget _buildAssurancesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.health_and_safety_outlined, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'ASSURANCES',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSegmentTile(
          context: context,
          icon: Icons.health_and_safety,
          color: Colors.teal,
          title: 'Franchise LAMal',
          subtitle: 'Trouvez la franchise ideale',
          route: '/assurances/lamal',
        ),
        const SizedBox(height: 12),
        _buildSegmentTile(
          context: context,
          icon: Icons.verified_user,
          color: Colors.indigo,
          title: 'Check-up couverture',
          subtitle: 'Evaluez votre protection assurantielle',
          route: '/assurances/coverage',
        ),
      ],
    );
  }

  Widget _buildSegmentsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people_outline, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'SEGMENTS',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSegmentTile(
          context: context,
          icon: Icons.balance,
          color: Colors.purple,
          title: 'Gender gap prevoyance',
          subtitle: 'Impact du temps partiel sur la retraite',
          route: '/segments/gender-gap',
        ),
        const SizedBox(height: 12),
        _buildSegmentTile(
          context: context,
          icon: Icons.language,
          color: Colors.blue,
          title: 'Frontalier',
          subtitle: 'Droits et obligations par pays',
          route: '/segments/frontalier',
        ),
        const SizedBox(height: 12),
        _buildSegmentTile(
          context: context,
          icon: Icons.business_center,
          color: Colors.amber,
          title: 'Independant',
          subtitle: 'Couverture et protection sociale',
          route: '/segments/independant',
        ),
      ],
    );
  }

  Widget _buildSegmentTile({
    required BuildContext context,
    required IconData icon,
    required MaterialColor color,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color.shade700, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: MintColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSection(BuildContext context, dynamic profile) {
    // Générer timeline dynamique si profil disponible
    final timelineEvents = profile != null
        ? TimelineService.getUpcomingReminders(
            TimelineService.generateTimeline('current_session', {}))
        : <TimelineItem>[];

    // Fallback sur timeline statique si pas d'événements
    if (timelineEvents.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'TIMELINE (30 JOURS)',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTimelineItem(
            date: '15 déc',
            title: 'Versement 3a optimal',
            subtitle: 'Délai bancaire pour déduction fiscale',
          ),
          const SizedBox(height: 12),
          _buildTimelineItem(
            date: '20 déc',
            title: 'Revue bénéficiaires',
            subtitle: 'Mise à jour annuelle recommandée',
          ),
        ],
      );
    }

    // Timeline dynamique
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month_outlined,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'TIMELINE (30 JOURS)',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var event in timelineEvents.take(3)) ...[
          _buildTimelineItem(
            date: _formatDate(event.date),
            title: event.label,
            subtitle: event.description,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;

    if (diff == 0) return 'Aujourd\'hui';
    if (diff == 1) return 'Demain';
    if (diff < 7) return 'Dans $diff jours';

    const months = [
      'jan',
      'fév',
      'mar',
      'avr',
      'mai',
      'juin',
      'juil',
      'août',
      'sep',
      'oct',
      'nov',
      'déc'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  Widget _buildTimelineItem({
    required String date,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            date,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: MintColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLifeEventsSection(BuildContext context) {
    final events = <_LifeEvent>[
      _LifeEvent(
        icon: Icons.favorite,
        label: 'Mariage',
        route: '/mariage',
        color: const Color(0xFFDB2777),
      ),
      _LifeEvent(
        icon: Icons.child_friendly,
        label: 'Naissance',
        route: '/naissance',
        color: const Color(0xFF059669),
      ),
      _LifeEvent(
        icon: Icons.balance,
        label: 'Concubinage',
        route: '/concubinage',
        color: const Color(0xFF7C3AED),
      ),
      _LifeEvent(
        icon: Icons.family_restroom,
        label: 'Divorce',
        route: '/life-event/divorce',
        color: const Color(0xFF9333EA),
      ),
      _LifeEvent(
        icon: Icons.elderly,
        label: 'Retraite',
        route: '/retirement',
        color: const Color(0xFF4F46E5),
      ),
      _LifeEvent(
        icon: Icons.school,
        label: 'Premier emploi',
        route: '/first-job',
        color: const Color(0xFF2563EB),
      ),
      _LifeEvent(
        icon: Icons.work_off,
        label: 'Chomage',
        route: '/unemployment',
        color: const Color(0xFFDC2626),
      ),
      _LifeEvent(
        icon: Icons.house,
        label: 'Achat immo',
        route: '/mortgage/affordability',
        color: const Color(0xFF0D9488),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_note, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              '\u00c9V\u00c9NEMENTS DE VIE',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final event = events[index];
              return InkWell(
                onTap: () => context.push(event.route),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 88,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: event.color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: event.color.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: event.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(event.icon, color: event.color, size: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoverToolsSection(BuildContext context) {
    final tools = <_QuickTool>[
      _QuickTool(
        icon: Icons.balance,
        title: 'Comparateur fiscal',
        subtitle: 'Compare entre cantons',
        route: '/fiscal',
        color: const Color(0xFF059669),
      ),
      _QuickTool(
        icon: Icons.savings,
        title: 'Simulateur 3a',
        subtitle: 'Economie fiscale',
        route: '/simulator/3a',
        color: const Color(0xFF059669),
      ),
      _QuickTool(
        icon: Icons.house,
        title: 'Capacite d\'achat',
        subtitle: 'Peux-tu acheter ?',
        route: '/mortgage/affordability',
        color: const Color(0xFF0D9488),
      ),
      _QuickTool(
        icon: Icons.elderly,
        title: 'Retraite',
        subtitle: 'Plan complet',
        route: '/retirement',
        color: const Color(0xFF4F46E5),
      ),
      _QuickTool(
        icon: Icons.account_balance_wallet,
        title: 'Budget',
        subtitle: 'Tes depenses',
        route: '/budget',
        color: const Color(0xFFD97706),
      ),
      _QuickTool(
        icon: Icons.health_and_safety,
        title: 'Franchise LAMal',
        subtitle: 'Franchise ideale',
        route: '/assurances/lamal',
        color: const Color(0xFF0891B2),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.grid_view, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'D\u00c9COUVRIR LES OUTILS',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ),
            InkWell(
              onTap: () => context.push('/tools'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Voir tout',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MintColors.info,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tools.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final tool = tools[index];
              return InkWell(
                onTap: () => context.push(tool.route),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 140,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MintColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MintColors.lightBorder),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tool.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(tool.icon, color: tool.color, size: 18),
                      ),
                      const Spacer(),
                      Text(
                        tool.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tool.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: MintColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Internal helper for life event cards.
class _LifeEvent {
  final IconData icon;
  final String label;
  final String route;
  final Color color;

  const _LifeEvent({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });
}

/// Internal helper for quick tool cards.
class _QuickTool {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Color color;

  const _QuickTool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.color,
  });
}
