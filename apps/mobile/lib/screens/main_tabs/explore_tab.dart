import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
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

  Widget _buildLifeEventsSection(BuildContext context) {
    final l10n = S.of(context);
    return _buildPillarCard(
      context,
      icon: Icons.event_note,
      title: l10n?.explorePillarLifeTitle ?? 'Il m\'arrive quelque chose',
      subtitle: l10n?.explorePillarLifeSub ??
          'Mariage, naissance, divorce, déménagement... on t\'accompagne.',
      pillarColor: MintColors.warning,
      previewContent: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            _buildEventTile(
              context,
              icon: Icons.favorite_outline,
              title: l10n?.exploreEventMarriage ?? 'Mariage',
              subtitle: l10n?.exploreEventMarriageSub ?? 'Impact fiscal et LPP',
              color: MintColors.pink,
              route: '/mariage',
            ),
            _buildEventTile(
              context,
              icon: Icons.child_care,
              title: l10n?.exploreEventBirth ?? 'Naissance',
              subtitle:
                  l10n?.exploreEventBirthSub ?? 'Allocations et déductions',
              color: MintColors.info,
              route: '/naissance',
            ),
            _buildEventTile(
              context,
              icon: Icons.people_outline,
              title: l10n?.exploreEventConcubinage ?? 'Concubinage',
              subtitle: l10n?.exploreEventConcubinageSub ??
                  'Protéger ton couple',
              color: MintColors.purple,
              route: '/concubinage',
            ),
            _buildEventTile(
              context,
              icon: Icons.family_restroom,
              title: l10n?.exploreEventDivorce ?? 'Divorce',
              subtitle:
                  l10n?.exploreEventDivorceSub ?? 'Partage LPP et AVS',
              color: MintColors.warning,
              route: '/life-event/divorce',
            ),
            _buildEventTile(
              context,
              icon: Icons.volunteer_activism,
              title: l10n?.exploreEventSuccession ?? 'Succession',
              subtitle: l10n?.exploreEventSuccessionSub ??
                  'Droits et planning',
              color: MintColors.success,
              route: '/life-event/succession',
            ),
            _buildEventTile(
              context,
              icon: Icons.home_work_outlined,
              title: l10n?.exploreEventHouseSale ?? 'Vente immobilière',
              subtitle:
                  l10n?.exploreEventHouseSaleSub ?? 'Impôt plus-value',
              color: MintColors.cyan,
              route: '/life-event/housing-sale',
            ),
            _buildEventTile(
              context,
              icon: Icons.card_giftcard,
              title: l10n?.exploreEventDonation ?? 'Donation',
              subtitle: l10n?.exploreEventDonationSub ??
                  'Fiscalité et limites',
              color: MintColors.deepOrange,
              route: '/life-event/donation',
            ),
            _buildEventTile(
              context,
              icon: Icons.flight_takeoff,
              title: l10n?.exploreEventExpat ?? 'Expatriation',
              subtitle:
                  l10n?.exploreEventExpatSub ?? 'Départ ou arrivée',
              color: MintColors.indigo,
              route: '/expatriation',
            ),
            // ── Événements professionnels ──
            _buildEventTile(
              context,
              icon: Icons.work_outline,
              title: 'Premier emploi',
              subtitle: 'AVS, LPP, impôts : tout comprendre',
              color: MintColors.info,
              route: '/first-job',
            ),
            _buildEventTile(
              context,
              icon: Icons.swap_horiz,
              title: 'Changement de poste',
              subtitle: 'Comparer LPP et salaire',
              color: MintColors.teal,
              route: '/simulator/job-comparison',
            ),
            _buildEventTile(
              context,
              icon: Icons.rocket_launch_outlined,
              title: 'Devenir indépendant',
              subtitle: 'AVS, 3a, LPP volontaire',
              color: MintColors.purple,
              route: '/segments/independant',
            ),
            _buildEventTile(
              context,
              icon: Icons.work_off_outlined,
              title: 'Perte d\'emploi',
              subtitle: 'Chômage, LPP, budget',
              color: MintColors.warning,
              route: '/unemployment',
            ),
            _buildEventTile(
              context,
              icon: Icons.beach_access_outlined,
              title: 'Retraite',
              subtitle: 'AVS, LPP, retrait 3a',
              color: MintColors.success,
              route: '/retirement',
            ),
            // ── Patrimoine ──
            _buildEventTile(
              context,
              icon: Icons.house_outlined,
              title: 'Achat immobilier',
              subtitle: 'Fonds propres et hypothèque',
              color: MintColors.cyan,
              route: '/mortgage/affordability',
            ),
            // ── Santé ──
            _buildEventTile(
              context,
              icon: Icons.health_and_safety_outlined,
              title: 'Invalidité',
              subtitle: 'Lacune de prévoyance',
              color: MintColors.error,
              route: '/simulator/disability-gap',
            ),
            // ── Mobilité ──
            _buildEventTile(
              context,
              icon: Icons.map_outlined,
              title: 'Déménagement cantonal',
              subtitle: 'Comparer la fiscalité',
              color: MintColors.amber,
              route: '/fiscal',
            ),
            // ── Famille ──
            _buildEventTile(
              context,
              icon: Icons.sentiment_very_dissatisfied_outlined,
              title: 'Décès d\'un proche',
              subtitle: 'Succession et démarches',
              color: MintColors.textMuted,
              route: '/life-event/succession',
            ),
            // ── Crise ──
            _buildEventTile(
              context,
              icon: Icons.warning_amber_outlined,
              title: 'Crise de dette',
              subtitle: 'Diagnostic et solutions',
              color: MintColors.error,
              route: '/check/debt',
            ),
          ],
        ),
      ],
      ctaText: '',
      onCtaTap: () {},
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
                      color: Colors.white, size: 24),
                  const SizedBox(height: 10),
                  Text(
                    l10n?.exploreAskMintTitle ?? 'Ask MINT',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
                      color: Colors.white.withValues(alpha: 0.8),
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
          color: Colors.white,
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
          color: Colors.white,
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
  }) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
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
    );
  }
}
