import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:go_router/go_router.dart';

/// Tab EXPLORER - Objectifs de vie et simulateurs
///
/// Organisation par cercles de vie, pas par hiérarchie technique
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

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
                _buildGoalsSection(context),
                const SizedBox(height: 32),
                _buildSimulatorsSection(context),
                const SizedBox(height: 32),
                _buildDocumentUploadSection(context),
                const SizedBox(height: 32),
                _buildAskMintSection(context),
                const SizedBox(height: 32),
                _buildLearnSection(context),
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

  Widget _buildGoalsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.ads_click, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'MES OBJECTIFS',
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
        _buildGoalCard(
          context,
          icon: Icons.savings_outlined,
          title: 'Maîtriser mon Budget',
          subtitle: 'Gérer mes dépenses → 3 min',
          gradient: [Colors.amber.shade50, Colors.amber.shade100],
          color: Colors.amber.shade700,
          onTap: () => context.push('/budget'),
        ),
        const SizedBox(height: 12),
        _buildGoalCard(
          context,
          icon: Icons.home_outlined,
          title: 'Devenir Propriétaire',
          subtitle: 'Simuler mon achat → 5 min',
          gradient: [Colors.blue.shade50, Colors.blue.shade100],
          color: Colors.blue.shade700,
          onTap: () {},
        ),
        const SizedBox(height: 12),
        _buildGoalCard(
          context,
          icon: Icons.trending_down,
          title: 'Payer Moins d\'Impôts',
          subtitle: 'Optimiser mon 3a → 3 min',
          gradient: [Colors.green.shade50, Colors.green.shade100],
          color: Colors.green.shade700,
          onTap: () => context.push('/simulator/3a'),
        ),
        const SizedBox(height: 12),
        _buildGoalCard(
          context,
          icon: Icons.beach_access_outlined,
          title: 'Préparer ma Retraite',
          subtitle: 'Voir mon plan → 10 min',
          gradient: [Colors.purple.shade50, Colors.purple.shade100],
          color: Colors.purple.shade700,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildGoalCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
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
                color: Colors.white.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withOpacity(0.6),
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

  Widget _buildSimulatorsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calculate_outlined,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'SIMULATEURS',
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
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _buildSimulatorTile(
              context,
              icon: Icons.trending_up,
              title: 'Intérêts\nComposés',
              color: MintColors.primary,
              route: '/simulator/compound',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.grid_view,
              title: 'Outils\nAvancés',
              color: MintColors.primary,
              route: '/tools',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.directions_car_outlined,
              title: 'Leasing',
              color: Colors.orange,
              route: '/simulator/leasing',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.credit_card,
              title: 'Credit\nConso',
              color: MintColors.warning,
              route: '/simulator/credit',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.account_balance,
              title: 'Rente vs\nCapital',
              color: const Color(0xFF4F46E5),
              route: '/simulator/rente-capital',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.shield_outlined,
              title: 'Filet de\nSécurité',
              color: const Color(0xFFEA580C),
              route: '/simulator/disability-gap',
            ),
            _buildSimulatorTile(
              context,
              icon: Icons.swap_horiz,
              title: 'Changement\nd\'emploi',
              color: Colors.amber.shade700,
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
          border: Border.all(color: MintColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentUploadSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.upload_file, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'DOCUMENTS',
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
          onTap: () => context.push('/documents'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.indigo.shade50,
                  Colors.indigo.shade100,
                ],
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
                    color: Colors.white.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.description_outlined,
                      color: Colors.indigo.shade700, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upload ton certificat LPP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Extraction automatique de tes donn\u00e9es \u2192',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.6),
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
        ),
      ],
    );
  }

  Widget _buildAskMintSection(BuildContext context) {
    final byok = context.watch<ByokProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'ASK MINT',
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
          onTap: () => context.push('/ask-mint'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MintColors.accent,
                  MintColors.accent.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: MintColors.accent.withOpacity(0.3),
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
                    color: Colors.white.withOpacity(0.2),
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
                        style: GoogleFonts.outfit(
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
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
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

  Widget _buildLearnSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.school_outlined, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'APPRENDRE',
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
        // Premium "J'y comprends rien" Card
        InkWell(
          onTap: () => context.push('/education/hub'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [MintColors.primary, MintColors.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: MintColors.primary.withOpacity(0.3),
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
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.help_outline, color: Colors.white, size: 28),
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
                        "L'essentiel, sans jargon. →",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildLearnItem(
          context,
          icon: Icons.school_outlined,
          title: 'C\'est quoi le 3a ?',
          duration: '3 min',
        ),
        const SizedBox(height: 12),
        _buildLearnItem(
          context,
          icon: Icons.menu_book_outlined,
          title: 'LPP : Mode d\'emploi',
          duration: '5 min',
        ),
        const SizedBox(height: 12),
        _buildLearnItem(
          context,
          icon: Icons.calculate_outlined,
          title: 'Fiscalité Suisse 101',
          duration: '7 min',
        ),
      ],
    );
  }

  Widget _buildLearnItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String duration,
  }) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MintColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: MintColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              duration,
              style: const TextStyle(
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
}
