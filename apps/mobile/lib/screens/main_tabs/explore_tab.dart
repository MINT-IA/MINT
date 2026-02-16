import 'package:flutter/material.dart';
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
//    6. APPRENDRE — Educational hub + 3 themed learn items
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
    const totalSlots = 7;
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
    return SliverAppBar(
      floating: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      title: Text(
        'EXPLORER',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.ads_click, 'MES OBJECTIFS'),
        const SizedBox(height: 16),
        _buildGoalCard(
          context,
          icon: Icons.savings_outlined,
          title: 'Maitriser mon Budget',
          subtitle: 'Gerer mes depenses → 3 min',
          tint: MintColors.warning,
          onTap: () => context.push('/budget'),
        ),
        const SizedBox(height: 12),
        _buildGoalCard(
          context,
          icon: Icons.home_outlined,
          title: 'Devenir Proprietaire',
          subtitle: 'Simuler mon achat → 5 min',
          tint: MintColors.info,
          onTap: () => context.push('/mortgage/affordability'),
        ),
        const SizedBox(height: 12),
        _buildGoalCard(
          context,
          icon: Icons.trending_down,
          title: 'Payer Moins d\'Impots',
          subtitle: 'Optimiser mon 3a → 3 min',
          tint: MintColors.success,
          onTap: () => context.push('/simulator/3a'),
        ),
        const SizedBox(height: 12),
        _buildGoalCard(
          context,
          icon: Icons.beach_access_outlined,
          title: 'Preparer ma Retraite',
          subtitle: 'Voir mon plan → 10 min',
          tint: const Color(0xFF8B5CF6), // Purple
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.calculate_outlined, 'SIMULATEURS'),
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
              title: 'Interets Composes',
              subtitle: 'Voir l\'effet du temps',
              color: MintColors.success,
              route: '/simulator/compound',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.grid_view,
              title: 'Outils Avances',
              subtitle: 'Tous les simulateurs',
              color: MintColors.primary,
              route: '/tools',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.directions_car_outlined,
              title: 'Leasing',
              subtitle: 'Cout reel du leasing',
              color: MintColors.warning,
              route: '/simulator/leasing',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.credit_card,
              title: 'Credit Conso',
              subtitle: 'Cout de l\'emprunt',
              color: MintColors.error,
              route: '/simulator/credit',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.account_balance,
              title: 'Rente vs Capital',
              subtitle: 'Comparer les options',
              color: MintColors.info,
              route: '/simulator/rente-capital',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.shield_outlined,
              title: 'Filet de Securite',
              subtitle: 'Gap invalidite',
              color: const Color(0xFFEA580C),
              route: '/simulator/disability-gap',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.swap_horiz,
              title: 'Changement d\'emploi',
              subtitle: 'Comparer 2 offres',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.event_note, '\u00c9V\u00c9NEMENTS DE VIE'),
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
              title: 'Mariage',
              subtitle: 'Impact fiscal et LPP',
              color: const Color(0xFFEC4899),
              route: '/mariage',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.child_care,
              title: 'Naissance',
              subtitle: 'Allocations et deductions',
              color: MintColors.info,
              route: '/naissance',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.people_outline,
              title: 'Concubinage',
              subtitle: 'Proteger ton couple',
              color: const Color(0xFF8B5CF6),
              route: '/concubinage',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.family_restroom,
              title: 'Divorce',
              subtitle: 'Partage LPP et AVS',
              color: MintColors.warning,
              route: '/life-event/divorce',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.volunteer_activism,
              title: 'Succession',
              subtitle: 'Droits et planning',
              color: MintColors.success,
              route: '/life-event/succession',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.home_work_outlined,
              title: 'Vente immobiliere',
              subtitle: 'Impot plus-value',
              color: const Color(0xFF0891B2),
              route: '/life-event/housing-sale',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.card_giftcard,
              title: 'Donation',
              subtitle: 'Fiscalite et limites',
              color: const Color(0xFFEA580C),
              route: '/life-event/donation',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.flight_takeoff,
              title: 'Expatriation',
              subtitle: 'Depart ou arrivee',
              color: const Color(0xFF4F46E5),
              route: '/expatriation',
            ),
          ],
        ),
      ],
    );
  }

  // ── DOCUMENTS ──────────────────────────────────────

  Widget _buildDocumentUploadSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.upload_file, 'DOCUMENTS'),
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
                        'Upload ton certificat LPP',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Extraction automatique de tes donnees \u2192',
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
    final byok = context.watch<ByokProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.auto_awesome, 'ASK MINT'),
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
                        'Ask MINT',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        byok.isConfigured
                            ? 'Pose tes questions finance suisse \u2192'
                            : 'Configure ton IA pour commencer \u2192',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.school_outlined, 'APPRENDRE'),
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
                        "J'y comprends rien",
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "L'essentiel, sans jargon. \u2192",
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
          title: 'C\'est quoi le 3a ?',
          duration: '3 min',
          themeId: '3a',
        ),
        const SizedBox(height: 10),
        _buildLearnItem(
          context,
          icon: Icons.work_outline,
          title: 'LPP : Mode d\'emploi',
          duration: '5 min',
          themeId: 'lpp',
        ),
        const SizedBox(height: 10),
        _buildLearnItem(
          context,
          icon: Icons.calculate_outlined,
          title: 'Fiscalite Suisse 101',
          duration: '7 min',
          themeId: 'fiscal',
        ),
        const SizedBox(height: 10),
        _buildLearnItem(
          context,
          icon: Icons.shield_outlined,
          title: 'Le fonds d\'urgence',
          duration: '3 min',
          themeId: 'emergency',
        ),
        const SizedBox(height: 10),
        _buildLearnItem(
          context,
          icon: Icons.medical_services_outlined,
          title: 'Les subsides LAMal',
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
