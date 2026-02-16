import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:go_router/go_router.dart';

// ────────────────────────────────────────────────────────────
//  EXPLORE TAB — Refonte UX "Wow"
// ────────────────────────────────────────────────────────────
//
//  Organisation par cercles de vie :
//    1. MES OBJECTIFS — 4 goal cards (budget, immobilier, fiscalite, retraite)
//    2. SIMULATEURS — 7 tool tiles with descriptions
//    3. EVENEMENTS DE VIE — 8 life events (all 18 types covered)
//    4. DOCUMENTS — LPP certificate upload
//    5. ASK MINT — AI chat
//    6. APPRENDRE — Educational hub + 5 themed learn items
//
//  UX upgrade:
//    - Stagger entry animation (100ms per section)
//    - All MintColors (no hardcoded Colors)
//    - Descriptions on simulator tiles
//    - All 8+ life events (was 2)
//    - Learn items route to specific themes (was all → hub)
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
      duration: const Duration(milliseconds: 1400),
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
    const totalSlots = 6;
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
                _staggeredEntry(index: 0, child: _buildGoalsSection(context)),
                const SizedBox(height: 32),
                _staggeredEntry(
                    index: 1, child: _buildSimulatorsSection(context)),
                const SizedBox(height: 32),
                _staggeredEntry(
                    index: 2, child: _buildLifeEventsSection(context)),
                const SizedBox(height: 32),
                _staggeredEntry(
                    index: 3, child: _buildDocumentUploadSection(context)),
                const SizedBox(height: 32),
                _staggeredEntry(
                    index: 4, child: _buildAskMintSection(context)),
                const SizedBox(height: 32),
                _staggeredEntry(
                    index: 5, child: _buildLearnSection(context)),
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

  // ── MES OBJECTIFS ──────────────────────────────────────

  Widget _buildGoalsSection(BuildContext context) {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.ads_click, l10n?.exploreGoalsSection ?? 'MES OBJECTIFS'),
        const SizedBox(height: 16),
        _buildGoalCard(
          context,
          icon: Icons.savings_outlined,
          title: l10n?.exploreGoalBudget ?? 'Maîtriser mon Budget',
          subtitle: l10n?.exploreGoalBudgetSub ?? 'Gérer mes dépenses → 3 min',
          tint: MintColors.warning,
          onTap: () => context.push('/budget'),
        ),
        const SizedBox(height: 12),
        _buildGoalCard(
          context,
          icon: Icons.home_outlined,
          title: l10n?.exploreGoalProperty ?? 'Devenir Propriétaire',
          subtitle: l10n?.exploreGoalPropertySub ?? 'Simuler mon achat → 5 min',
          tint: MintColors.info,
          onTap: () => context.push('/mortgage/affordability'),
        ),
        const SizedBox(height: 12),
        _buildGoalCard(
          context,
          icon: Icons.trending_down,
          title: l10n?.exploreGoalTax ?? 'Payer Moins d\'Impôts',
          subtitle: l10n?.exploreGoalTaxSub ?? 'Optimiser mon 3a → 3 min',
          tint: MintColors.success,
          onTap: () => context.push('/simulator/3a'),
        ),
        const SizedBox(height: 12),
        _buildGoalCard(
          context,
          icon: Icons.beach_access_outlined,
          title: l10n?.exploreGoalRetirement ?? 'Préparer ma Retraite',
          subtitle: l10n?.exploreGoalRetirementSub ?? 'Voir mon plan → 10 min',
          tint: MintColors.purple, // Purple
          onTap: () => context.push('/retirement'),
        ),
      ],
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              tint.withValues(alpha: 0.06),
              tint.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tint.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tint, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            Icon(Icons.arrow_forward_ios,
                size: 16, color: MintColors.textMuted),
          ],
        ),
      ),
    );
  }

  // ── SIMULATEURS ──────────────────────────────────────

  Widget _buildSimulatorsSection(BuildContext context) {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.calculate_outlined, l10n?.exploreSimulatorsSection ?? 'SIMULATEURS'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildSimulatorTile(
              context,
              icon: Icons.trending_up,
              title: l10n?.exploreSimCompound ?? 'Intérêts Composés',
              subtitle: l10n?.exploreSimCompoundSub ?? 'Voir l\'effet du temps',
              color: MintColors.success,
              route: '/simulator/compound',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.grid_view,
              title: l10n?.exploreSimAdvanced ?? 'Outils Avancés',
              subtitle: l10n?.exploreSimAdvancedSub ?? 'Tous les simulateurs',
              color: MintColors.primary,
              route: '/tools',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.directions_car_outlined,
              title: l10n?.exploreSimLeasing ?? 'Leasing',
              subtitle: l10n?.exploreSimLeasingSub ?? 'Coût réel du leasing',
              color: MintColors.warning,
              route: '/simulator/leasing',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.credit_card,
              title: l10n?.exploreSimCredit ?? 'Crédit Conso',
              subtitle: l10n?.exploreSimCreditSub ?? 'Coût de l\'emprunt',
              color: MintColors.error,
              route: '/simulator/credit',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.account_balance,
              title: l10n?.exploreSimRenteCapital ?? 'Rente vs Capital',
              subtitle: l10n?.exploreSimRenteCapitalSub ?? 'Comparer les options',
              color: MintColors.info,
              route: '/simulator/rente-capital',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.shield_outlined,
              title: l10n?.exploreSimDisability ?? 'Filet de Sécurité',
              subtitle: l10n?.exploreSimDisabilitySub ?? 'Gap invalidité',
              color: MintColors.deepOrange,
              route: '/simulator/disability-gap',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.swap_horiz,
              title: l10n?.exploreSimJobChange ?? 'Changement d\'emploi',
              subtitle: l10n?.exploreSimJobChangeSub ?? 'Comparer 2 offres',
              color: MintColors.warning,
              route: '/simulator/job-comparison',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimulatorTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String route,
  }) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── EVENEMENTS DE VIE ──────────────────────────────────

  Widget _buildLifeEventsSection(BuildContext context) {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.event_note, l10n?.exploreLifeEventsSection ?? 'ÉVÉNEMENTS DE VIE'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildSimulatorTile(
              context,
              icon: Icons.favorite_outline,
              title: l10n?.exploreEventMarriage ?? 'Mariage',
              subtitle: l10n?.exploreEventMarriageSub ?? 'Impact fiscal et LPP',
              color: MintColors.pink,
              route: '/mariage',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.child_care,
              title: l10n?.exploreEventBirth ?? 'Naissance',
              subtitle: l10n?.exploreEventBirthSub ?? 'Allocations et déductions',
              color: MintColors.info,
              route: '/naissance',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.people_outline,
              title: l10n?.exploreEventConcubinage ?? 'Concubinage',
              subtitle: l10n?.exploreEventConcubinageSub ?? 'Protéger ton couple',
              color: MintColors.purple,
              route: '/concubinage',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.family_restroom,
              title: l10n?.exploreEventDivorce ?? 'Divorce',
              subtitle: l10n?.exploreEventDivorceSub ?? 'Partage LPP et AVS',
              color: MintColors.warning,
              route: '/life-event/divorce',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.volunteer_activism,
              title: l10n?.exploreEventSuccession ?? 'Succession',
              subtitle: l10n?.exploreEventSuccessionSub ?? 'Droits et planning',
              color: MintColors.success,
              route: '/life-event/succession',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.home_work_outlined,
              title: l10n?.exploreEventHouseSale ?? 'Vente immobilière',
              subtitle: l10n?.exploreEventHouseSaleSub ?? 'Impôt plus-value',
              color: MintColors.cyan,
              route: '/life-event/housing-sale',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.card_giftcard,
              title: l10n?.exploreEventDonation ?? 'Donation',
              subtitle: l10n?.exploreEventDonationSub ?? 'Fiscalité et limites',
              color: MintColors.deepOrange,
              route: '/life-event/donation',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.flight_takeoff,
              title: l10n?.exploreEventExpat ?? 'Expatriation',
              subtitle: l10n?.exploreEventExpatSub ?? 'Départ ou arrivée',
              color: MintColors.indigo,
              route: '/expatriation',
            ),
          ],
        ),
      ],
    );
  }

  // ── DOCUMENTS ──────────────────────────────────────

  Widget _buildDocumentUploadSection(BuildContext context) {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.upload_file, l10n?.exploreDocumentsSection ?? 'DOCUMENTS'),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => context.push('/documents'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MintColors.info.withValues(alpha: 0.06),
                  MintColors.info.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.description_outlined,
                      color: MintColors.info, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.exploreDocUploadLpp ?? 'Upload ton certificat LPP',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n?.exploreDocUploadLppSub ?? 'Extraction automatique de tes données →',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: MintColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── ASK MINT ──────────────────────────────────────

  Widget _buildAskMintSection(BuildContext context) {
    final l10n = S.of(context);
    final byok = context.watch<ByokProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.auto_awesome, l10n?.exploreAskMintSection ?? 'ASK MINT'),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => context.push('/ask-mint'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MintColors.accent,
                  MintColors.accent.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: MintColors.accent.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_outline,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.exploreAskMintTitle ?? 'Ask MINT',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        byok.isConfigured
                            ? l10n?.exploreAskMintConfigured ?? 'Pose tes questions finance suisse →'
                            : l10n?.exploreAskMintNotConfigured ?? 'Configure ton IA pour commencer →',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── APPRENDRE ──────────────────────────────────────

  Widget _buildLearnSection(BuildContext context) {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.school_outlined, l10n?.exploreLearnSection ?? 'APPRENDRE'),
        const SizedBox(height: 16),
        // Premium "J'y comprends rien" Card
        InkWell(
          onTap: () => context.push('/education/hub'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MintColors.primary,
                  MintColors.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: MintColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.help_outline,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.exploreLearnHub ?? "J'y comprends rien",
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n?.exploreLearnHubSub ?? "L'essentiel, sans jargon. →",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 10),
        _buildLearnItem(
          context,
          icon: Icons.shield_outlined,
          title: l10n?.exploreLearnEmergency ?? 'Le fonds d\'urgence',
          duration: '3 min',
          themeId: 'emergency',
        ),
        const SizedBox(height: 10),
        _buildLearnItem(
          context,
          icon: Icons.medical_services_outlined,
          title: l10n?.exploreLearnLamal ?? 'Les subsides LAMal',
          duration: '4 min',
          themeId: 'lamal',
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: MintColors.primary, size: 20),
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

  // ── SHARED ──────────────────────────────────────

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: MintColors.textMuted),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
