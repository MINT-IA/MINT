import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

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
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHorizonHeader('IMMÉDIAT (THIS YEAR)'),
                const SizedBox(height: 12),
                _buildTimelineEvent(
                  context,
                  title: 'Maîtrise du Cashflow',
                  date: 'Tous les mois',
                  status: 'Essentiel',
                  description:
                      'Gérez votre budget dépenses variables vs futur.',
                  icon: Icons.pie_chart_outline,
                  route: '/budget',
                  isNext: true,
                ),
                _buildConnector(),
                _buildTimelineEvent(
                  context,
                  title: 'Protection de Base',
                  date: 'Session immédiate',
                  status: 'Prioritaire',
                  description: 'Fonds d\'urgence, LPP et dettes.',
                  icon: Icons.shield_outlined,
                  route: '/advisor', // Lance le Wizard global pour l'instant
                  isNext: true,
                  buttonLabel: 'Lancer le Check-up',
                ),
                _buildConnector(),
                const SizedBox(height: 24),
                _buildHorizonHeader('COURT TERME (1-3 ANS)'),
                const SizedBox(height: 12),
                _buildTimelineEvent(
                  context,
                  title: 'Optimisation 3e Pilier',
                  date: 'Décembre 2026',
                  status: 'Opportunité',
                  description: 'Maximiser la déduction fiscale.',
                  icon: Icons.savings_outlined,
                  route: '/simulator/3a',
                ),
                _buildConnector(),
                _buildTimelineEvent(
                  context,
                  title: 'Projet Achat Immo',
                  date: 'Horizon 2028',
                  status: 'Planification',
                  description: 'Simuler votre capacité d\'emprunt.',
                  icon: Icons.home_outlined,
                  route: '/simulator/compound', // Placeholder
                ),
                const SizedBox(height: 24),
                _buildHorizonHeader('VIE & ÉVÉNEMENTS'),
                const SizedBox(height: 12),
                _buildEventTrigger(context, 'Mariage / Divorce',
                    Icons.favorite_border, 'Impact sur LPP & AVS'),
                const SizedBox(height: 12),
                _buildEventTrigger(context, 'Retraite / Pré-retraite',
                    Icons.elderly, 'Planification rente vs capital'),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHorizonHeader(String title) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              color: MintColors.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: MintColors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votre vie financière,\nétape par étape.',
            style: GoogleFonts.montserrat(
                fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sélectionnez un événement ou un outil pour adapter votre stratégie.',
            style: TextStyle(color: MintColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEvent(
    BuildContext context, {
    required String title,
    required String date,
    required String status,
    required String description,
    required IconData icon,
    required String route,
    bool isNext = false,
    String? buttonLabel,
  }) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isNext ? Colors.white : MintColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isNext ? MintColors.primary : MintColors.border,
              width: isNext ? 2 : 1),
          boxShadow: isNext
              ? [
                  BoxShadow(
                      color: MintColors.primary.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isNext
                    ? MintColors.primary.withOpacity(0.1)
                    : MintColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: isNext ? MintColors.primary : MintColors.textMuted,
                  size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(date,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: MintColors.textMuted)),
                      if (isNext)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: MintColors.primary,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(status.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(title,
                      style: GoogleFonts.montserrat(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 13, color: MintColors.textSecondary)),
                  if (isNext) const SizedBox(height: 16),
                  if (isNext)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.push(route),
                        child: Text(buttonLabel ?? 'Ouvrir'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnector() {
    return Container(
      margin: const EdgeInsets.only(left: 42),
      width: 2,
      height: 30,
      color: MintColors.border,
    );
  }

  Widget _buildEventTrigger(
      BuildContext context, String title, IconData icon, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: MintColors.textSecondary, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: MintColors.textMuted)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Delta Session : Coming Soon')));
            },
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Simuler'),
          ),
        ],
      ),
    );
  }
}
