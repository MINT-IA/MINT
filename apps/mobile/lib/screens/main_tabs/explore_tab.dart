import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:go_router/go_router.dart';

// ────────────────────────────────────────────────────────────
//  EXPLORE TAB — 3 Piliers par Modèle Mental
// ────────────────────────────────────────────────────────────
//
//  Organisation par intent utilisateur :
//    1. JE VEUX COMPRENDRE — Educational hub (9 themes, quiz)
//    2. JE VEUX CALCULER   — 4 quick goals + CTA vers 49 outils
//    3. IL M'ARRIVE QQCH   — 8 life events (grid 2x4)
//    4. UTILITY STRIP       — Ask MINT + Documents (compact)
//
//  0 doublon de route. Chaque écran accessible depuis 1 seul endroit.
// ────────────────────────────────────────────────────────────

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  late Animation<double> _staggerAnimation;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _staggerAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: Curves.easeOutCubic,
    );
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _staggeredEntry({required int index, required Widget child}) {
    const totalSlots = 4;
    return AnimatedBuilder(
      animation: _staggerAnimation,
      builder: (context, _) {
        final progress =
            ((_staggerAnimation.value * totalSlots) - index).clamp(0.0, 1.0);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Contextual suggestion based on profile
                _buildContextualSuggestion(context),
                _staggeredEntry(
                    index: 0, child: _buildComprendreSection(context)),
                const SizedBox(height: 28),
                _staggeredEntry(
                    index: 1, child: _buildCalculerSection(context)),
                const SizedBox(height: 28),
                _staggeredEntry(
                    index: 2, child: _buildLifeEventsSection(context)),
                const SizedBox(height: 28),
                _staggeredEntry(
                    index: 3, child: _buildUtilityStrip(context)),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final l10n = S.of(context);
    return SliverAppBar(
      floating: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      title: Text(
        l10n?.exploreTitle ?? 'EXPLORER',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ── PILIER 1 — JE VEUX COMPRENDRE ──────────────────────

  Widget _buildComprendreSection(BuildContext context) {
    final l10n = S.of(context);
    return _buildPillarCard(
      context,
      icon: Icons.school_outlined,
      title: l10n?.explorePillarComprendreTitle ?? 'Je veux comprendre',
      subtitle: l10n?.explorePillarComprendreSub ??
          'L\'essentiel de la finance suisse, sans jargon. Quiz inclus.',
      pillarColor: MintColors.purple,
      previewContent: [
        _buildLearnItem(
          context,
          icon: Icons.savings_outlined,
          title: l10n?.exploreLearn3a ?? 'C\'est quoi le 3a ?',
          duration: '3 min',
          themeId: '3a',
        ),
        const SizedBox(height: 10),
        _buildLearnItem(
          context,
          icon: Icons.work_outline,
          title: l10n?.exploreLearnLpp ?? 'LPP : Mode d\'emploi',
          duration: '5 min',
          themeId: 'lpp',
        ),
        const SizedBox(height: 10),
        _buildLearnItem(
          context,
          icon: Icons.calculate_outlined,
          title: l10n?.exploreLearnFiscal ?? 'Fiscalité Suisse 101',
          duration: '7 min',
          themeId: 'fiscal',
        ),
      ],
      ctaText: l10n?.explorePillarComprendreCta ?? 'Explorer les 9 thèmes',
      onCtaTap: () => context.push('/education/hub'),
    );
  }

  // ── PILIER 2 — JE VEUX CALCULER ────────────────────────

  Widget _buildCalculerSection(BuildContext context) {
    final l10n = S.of(context);
    return _buildPillarCard(
      context,
      icon: Icons.calculate_outlined,
      title: l10n?.explorePillarCalculerTitle ?? 'Je veux calculer',
      subtitle: l10n?.explorePillarCalculerSub ??
          'Simule, compare, optimise. 49 outils à ta disposition.',
      pillarColor: MintColors.success,
      previewContent: [
        _buildGoalCard(
          context,
          icon: Icons.savings_outlined,
          title: l10n?.exploreGoalBudget ?? 'Maîtriser mon Budget',
          subtitle:
              l10n?.exploreGoalBudgetSub ?? 'Gérer mes dépenses → 3 min',
          tint: MintColors.warning,
          onTap: () => context.push('/budget'),
        ),
        const SizedBox(height: 10),
        _buildGoalCard(
          context,
          icon: Icons.home_outlined,
          title: l10n?.exploreGoalProperty ?? 'Devenir Propriétaire',
          subtitle: l10n?.exploreGoalPropertySub ??
              'Simuler mon achat → 5 min',
          tint: MintColors.info,
          onTap: () => context.push('/mortgage/affordability'),
        ),
        const SizedBox(height: 10),
        _buildGoalCard(
          context,
          icon: Icons.trending_down,
          title: l10n?.exploreGoalTax ?? 'Payer Moins d\'Impôts',
          subtitle:
              l10n?.exploreGoalTaxSub ?? 'Optimiser mon 3a → 3 min',
          tint: MintColors.success,
          onTap: () => context.push('/simulator/3a'),
        ),
        const SizedBox(height: 10),
        _buildGoalCard(
          context,
          icon: Icons.beach_access_outlined,
          title: l10n?.exploreGoalRetirement ?? 'Préparer ma Retraite',
          subtitle:
              l10n?.exploreGoalRetirementSub ?? 'Voir mon plan → 10 min',
          tint: MintColors.purple,
          onTap: () => context.push('/retirement'),
        ),
      ],
      ctaText: l10n?.explorePillarCalculerCta ?? 'Voir tous les outils',
      onCtaTap: () => context.push('/tools'),
    );
  }

  // ── PILIER 3 — IL M'ARRIVE QUELQUE CHOSE ───────────────

  /// Calcule un score de pertinence (0-100) pour un evenement de vie
  /// selon le profil utilisateur.
  int _relevanceScore(String eventId, CoachProfileProvider coachProvider) {
    final profile = coachProvider.profile;
    if (profile == null) return 50; // Score neutre si pas de profil

    final age = DateTime.now().year - profile.birthYear;
    final goalType = profile.goalA.type;
    final isIndep = profile.employmentStatus == 'independant';
    final hasDebt = profile.dettes.totalDettes > 0;

    switch (eventId) {
      case 'first_job':
        return age < 28 ? 95 : (age < 35 ? 60 : 20);
      case 'job_change':
        return (age >= 25 && age <= 50) ? 70 : 40;
      case 'self_employment':
        return isIndep ? 90 : (age < 40 ? 55 : 35);
      case 'job_loss':
        return 50;
      case 'retirement':
        return age > 50 ? 95 : (age > 40 ? 65 : 25);
      case 'marriage':
        return age < 40 ? 75 : 45;
      case 'birth':
        return age < 42 ? 70 : 30;
      case 'concubinage':
        return age < 40 ? 65 : 40;
      case 'divorce':
        return age > 30 ? 55 : 30;
      case 'succession':
        return age > 45 ? 75 : 35;
      case 'housing_purchase':
        return (goalType == GoalAType.achatImmo || (age >= 28 && age <= 50)) ? 85 : 40;
      case 'housing_sale':
        return age > 40 ? 55 : 25;
      case 'donation':
        return age > 50 ? 60 : 25;
      case 'expatriation':
        return 45;
      case 'disability':
        return 50;
      case 'canton_move':
        return 45;
      case 'death_of_relative':
        return age > 40 ? 50 : 30;
      case 'debt_crisis':
        return hasDebt ? 90 : (goalType == GoalAType.debtFree ? 80 : 30);
      default:
        return 50;
    }
  }

  Widget _buildLifeEventsSection(BuildContext context) {
    final l10n = S.of(context);
    final coachProvider = context.watch<CoachProfileProvider>();
    final activity = context.watch<UserActivityProvider>();

    // Liste des evenements de vie avec ID pour scoring + tracking
    final events = <_LifeEventData>[
      _LifeEventData(id: 'marriage', icon: Icons.favorite_outline,
        title: l10n?.exploreEventMarriage ?? 'Mariage',
        subtitle: l10n?.exploreEventMarriageSub ?? 'Impact fiscal et LPP',
        color: MintColors.pink, route: '/mariage'),
      _LifeEventData(id: 'birth', icon: Icons.child_care,
        title: l10n?.exploreEventBirth ?? 'Naissance',
        subtitle: l10n?.exploreEventBirthSub ?? 'Allocations et déductions',
        color: MintColors.info, route: '/naissance'),
      _LifeEventData(id: 'concubinage', icon: Icons.people_outline,
        title: l10n?.exploreEventConcubinage ?? 'Concubinage',
        subtitle: l10n?.exploreEventConcubinageSub ?? 'Protéger ton couple',
        color: MintColors.purple, route: '/concubinage'),
      _LifeEventData(id: 'divorce', icon: Icons.family_restroom,
        title: l10n?.exploreEventDivorce ?? 'Divorce',
        subtitle: l10n?.exploreEventDivorceSub ?? 'Partage LPP et AVS',
        color: MintColors.warning, route: '/life-event/divorce'),
      _LifeEventData(id: 'succession', icon: Icons.volunteer_activism,
        title: l10n?.exploreEventSuccession ?? 'Succession',
        subtitle: l10n?.exploreEventSuccessionSub ?? 'Droits et planning',
        color: MintColors.success, route: '/life-event/succession'),
      _LifeEventData(id: 'housing_sale', icon: Icons.home_work_outlined,
        title: l10n?.exploreEventHouseSale ?? 'Vente immobilière',
        subtitle: l10n?.exploreEventHouseSaleSub ?? 'Impôt plus-value',
        color: MintColors.cyan, route: '/life-event/housing-sale'),
      _LifeEventData(id: 'donation', icon: Icons.card_giftcard,
        title: l10n?.exploreEventDonation ?? 'Donation',
        subtitle: l10n?.exploreEventDonationSub ?? 'Fiscalité et limites',
        color: MintColors.deepOrange, route: '/life-event/donation'),
      _LifeEventData(id: 'expatriation', icon: Icons.flight_takeoff,
        title: l10n?.exploreEventExpat ?? 'Expatriation',
        subtitle: l10n?.exploreEventExpatSub ?? 'Départ ou arrivée',
        color: MintColors.indigo, route: '/expatriation'),
      _LifeEventData(id: 'first_job', icon: Icons.work_outline,
        title: l10n?.exploreEventFirstJob ?? 'Premier emploi',
        subtitle: l10n?.exploreEventFirstJobSub ?? 'AVS, LPP, impôts\u00a0: tout comprendre',
        color: MintColors.info, route: '/first-job'),
      _LifeEventData(id: 'job_change', icon: Icons.swap_horiz,
        title: l10n?.exploreEventJobChange ?? 'Changement de poste',
        subtitle: l10n?.exploreEventJobChangeSub ?? 'Comparer LPP et salaire',
        color: MintColors.teal, route: '/simulator/job-comparison'),
      _LifeEventData(id: 'self_employment', icon: Icons.rocket_launch_outlined,
        title: l10n?.exploreEventSelfEmployment ?? 'Devenir indépendant',
        subtitle: l10n?.exploreEventSelfEmploymentSub ?? 'AVS, 3a, LPP volontaire',
        color: MintColors.purple, route: '/segments/independant'),
      _LifeEventData(id: 'job_loss', icon: Icons.work_off_outlined,
        title: l10n?.exploreEventJobLoss ?? 'Perte d\'emploi',
        subtitle: l10n?.exploreEventJobLossSub ?? 'Chômage, LPP, budget',
        color: MintColors.warning, route: '/unemployment'),
      _LifeEventData(id: 'retirement', icon: Icons.beach_access_outlined,
        title: l10n?.exploreEventRetirement ?? 'Retraite',
        subtitle: l10n?.exploreEventRetirementSub ?? 'AVS, LPP, retrait 3a',
        color: MintColors.success, route: '/retirement'),
      _LifeEventData(id: 'housing_purchase', icon: Icons.house_outlined,
        title: l10n?.exploreEventHousingPurchase ?? 'Achat immobilier',
        subtitle: l10n?.exploreEventHousingPurchaseSub ?? 'Fonds propres et hypothèque',
        color: MintColors.cyan, route: '/mortgage/affordability'),
      _LifeEventData(id: 'disability', icon: Icons.health_and_safety_outlined,
        title: l10n?.exploreEventDisability ?? 'Invalidité',
        subtitle: l10n?.exploreEventDisabilitySub ?? 'Lacune de prévoyance',
        color: MintColors.error, route: '/disability/gap'),
      _LifeEventData(id: 'canton_move', icon: Icons.map_outlined,
        title: l10n?.exploreEventCantonMove ?? 'Déménagement cantonal',
        subtitle: l10n?.exploreEventCantonMoveSub ?? 'Comparer la fiscalité',
        color: MintColors.amber, route: '/fiscal'),
      _LifeEventData(id: 'death_of_relative',
        icon: Icons.sentiment_very_dissatisfied_outlined,
        title: l10n?.exploreEventDeathRelative ?? 'Décès d\'un proche',
        subtitle: l10n?.exploreEventDeathRelativeSub ?? 'Succession et démarches',
        color: MintColors.textMuted, route: '/life-event/succession'),
      _LifeEventData(id: 'debt_crisis', icon: Icons.warning_amber_outlined,
        title: l10n?.exploreEventDebtCrisis ?? 'Crise de dette',
        subtitle: l10n?.exploreEventDebtCrisisSub ?? 'Diagnostic et solutions',
        color: MintColors.error, route: '/check/debt'),
    ];

    // Trier par score de pertinence decroissant
    events.sort((a, b) {
      final scoreA = _relevanceScore(a.id, coachProvider);
      final scoreB = _relevanceScore(b.id, coachProvider);
      return scoreB.compareTo(scoreA);
    });

    // Trouver la suggestion du coach (premier non-explore)
    final suggestion = events.cast<_LifeEventData?>().firstWhere(
      (e) => !activity.isLifeEventExplored(e!.id),
      orElse: () => null,
    );

    return _buildPillarCard(
      context,
      icon: Icons.event_note,
      title: l10n?.explorePillarLifeTitle ?? 'Il m\'arrive quelque chose',
      subtitle: l10n?.explorePillarLifeSub ??
          'Mariage, naissance, divorce, déménagement... on t\'accompagne.',
      pillarColor: MintColors.warning,
      previewContent: [
        // Suggestion du coach (si profil disponible et evenement non explore)
        if (coachProvider.hasProfile && suggestion != null)
          _buildCoachSuggestion(context, suggestion, activity),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: events.map((e) {
            final isExplored = activity.isLifeEventExplored(e.id);
            return _buildEventTile(
              context,
              icon: e.icon,
              title: e.title,
              subtitle: e.subtitle,
              color: e.color,
              route: e.route,
              eventId: e.id,
              isExplored: isExplored,
            );
          }).toList(),
        ),
      ],
      ctaText: '',
      onCtaTap: () {},
    );
  }

  /// Carte "Suggestion du coach" en haut de la section evenements
  Widget _buildCoachSuggestion(
    BuildContext context,
    _LifeEventData event,
    UserActivityProvider activity,
  ) {
    final l10n = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () {
          activity.markLifeEventExplored(event.id);
          context.push(event.route);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                event.color.withValues(alpha: 0.08),
                MintColors.accentPastel.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: event.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: event.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(event.icon, color: event.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.exploreCoachSuggestionLabel ?? 'Suggestion du coach',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: MintColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.title,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    Text(
                      event.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: event.color),
            ],
          ),
        ),
      ),
    );
  }

  // ── UTILITY STRIP ──────────────────────────────────────

  Widget _buildUtilityStrip(BuildContext context) {
    final l10n = S.of(context);
    final byok = context.watch<ByokProvider>();
    return Row(
      children: [
        // Ask MINT
        Expanded(
          child: InkWell(
            onTap: () => context.push('/ask-mint'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MintColors.accent,
                    MintColors.accent.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: MintColors.accent.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      color: MintColors.white, size: 24),
                  const SizedBox(height: 10),
                  Text(
                    l10n?.exploreAskMintTitle ?? 'Ask MINT',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MintColors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    byok.isConfigured
                        ? l10n?.exploreAskMintConfigured ??
                            'Pose tes questions →'
                        : l10n?.exploreAskMintNotConfigured ??
                            'Configure ton IA →',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.white.withValues(alpha: 0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Documents
        Expanded(
          child: InkWell(
            onTap: () => context.push('/documents'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MintColors.info.withValues(alpha: 0.08),
                    MintColors.info.withValues(alpha: 0.16),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: MintColors.info.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.description_outlined,
                      color: MintColors.info, size: 24),
                  const SizedBox(height: 10),
                  Text(
                    l10n?.exploreDocUploadLpp ?? 'Certificats & documents',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n?.exploreDocUploadLppSub ??
                        'Certificat LPP, extraits AVS →',
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
          ),
        ),
      ],
    );
  }

  // ── SHARED WIDGETS ─────────────────────────────────────

  Widget _buildPillarCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color pillarColor,
    required List<Widget> previewContent,
    required String ctaText,
    required VoidCallback onCtaTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            pillarColor.withValues(alpha: 0.06),
            pillarColor.withValues(alpha: 0.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: pillarColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: pillarColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: pillarColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
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
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Preview content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: previewContent,
            ),
          ),
          // CTA
          if (ctaText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: InkWell(
                onTap: onCtaTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: pillarColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ctaText,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: pillarColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward,
                          size: 16, color: pillarColor),
                    ],
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tint, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 16, color: MintColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String duration,
    required String themeId,
  }) {
    return InkWell(
      onTap: () => context.push('/education/theme/$themeId'),
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
            Icon(icon, color: MintColors.purple, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Text(
              duration,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                size: 16, color: MintColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String route,
    String? eventId,
    bool isExplored = false,
  }) {
    return InkWell(
      onTap: () {
        if (eventId != null) {
          context.read<UserActivityProvider>().markLifeEventExplored(eventId);
        }
        context.push(route);
      },
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: MintColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Badge "Explore" si deja visite
          if (isExplored)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: MintColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: MintColors.white, size: 10),
              ),
            ),
        ],
      ),
    );
  }

  // ── CONTEXTUAL SUGGESTION ────────────────────────────────
  // One personalized suggestion at the top, based on profile state.

  Widget _buildContextualSuggestion(BuildContext context) {
    final coachProvider = context.watch<CoachProfileProvider>();
    final profile = coachProvider.profile;
    if (profile == null) return const SizedBox.shrink();

    final l10n = S.of(context);

    // Pick the most relevant suggestion
    String title;
    String subtitle;
    IconData icon;
    Color color;
    String route;

    final age = DateTime.now().year - profile.birthYear;
    final has3a = profile.prevoyance.totalEpargne3a > 0;
    final hasLpp = (profile.prevoyance.avoirLppTotal ?? 0) > 0;

    if (!has3a && age < 55) {
      // No 3a → suggest 3a simulator
      title = l10n?.exploreSuggestion3aTitle ?? 'Le 3a : ton premier levier fiscal';
      subtitle = l10n?.exploreSuggestion3aSub ?? 'Découvre combien tu peux économiser d\'impôts';
      icon = Icons.savings_outlined;
      color = MintColors.success;
      route = '/simulator/3a';
    } else if (hasLpp && (profile.prevoyance.rachatMaximum ?? 0) > 20000) {
      // Has LPP with buyback potential → suggest LPP deep
      title = l10n?.exploreSuggestionLppTitle ?? 'Rachat LPP : une opportunité\u00a0?';
      subtitle = l10n?.exploreSuggestionLppSub ?? 'Simule l\'impact sur ta retraite et tes impôts';
      icon = Icons.account_balance_outlined;
      color = MintColors.cyan;
      route = '/lpp-deep/rachat';
    } else if (age >= 50) {
      // Over 50 → retirement planning
      title = l10n?.exploreSuggestionRetirementTitle ?? 'Ta retraite approche';
      subtitle = l10n?.exploreSuggestionRetirementSub ?? 'Rente, capital ou mix\u00a0? Compare les options';
      icon = Icons.beach_access_outlined;
      color = MintColors.purple;
      route = '/retirement';
    } else {
      // Default: budget
      title = l10n?.exploreSuggestionBudgetTitle ?? 'Commence par ton budget';
      subtitle = l10n?.exploreSuggestionBudgetSub ?? '3 minutes pour voir où va ton argent';
      icon = Icons.account_balance_wallet_outlined;
      color = MintColors.warning;
      route = '/budget';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.08),
                color.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
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
                      l10n?.exploreSuggestionLabel ?? 'Suggestion pour toi',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Donnees d'un evenement de vie pour le scoring et l'affichage.
class _LifeEventData {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;

  const _LifeEventData({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
  });
}
