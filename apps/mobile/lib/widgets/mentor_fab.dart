import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:go_router/go_router.dart';

/// FAB Mentor - Compagnon toujours accessible
///
/// Floating Action Button qui ouvre le modal Mentor
class MentorFAB extends StatelessWidget {
  const MentorFAB({super.key, this.currentTabIndex = 0});

  final int currentTabIndex;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showMentorModal(context),
      backgroundColor: MintColors.primary,
      child: const Icon(Icons.auto_awesome, color: Colors.white),
    );
  }

  void _showMentorModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MentorModal(currentTabIndex: currentTabIndex),
    );
  }
}

/// Modal Mentor avec actions rapides, contextualisees par tab
class MentorModal extends StatelessWidget {
  const MentorModal({super.key, this.currentTabIndex = 0});

  final int currentTabIndex;

  List<_MentorAction> _actionsForTab() {
    const session = _MentorAction(
      icon: Icons.play_circle_outline,
      title: 'Lancer une session complète',
      subtitle: 'Diagnostic personnalisé en 5 min',
      color: MintColors.primary,
      route: '/advisor',
    );
    const rapport = _MentorAction(
      icon: Icons.assessment_outlined,
      title: 'Voir mon rapport actuel',
      subtitle: 'État de ta situation financière',
      color: MintColors.success,
      route: '/report',
    );
    const simuler = _MentorAction(
      icon: Icons.calculate_outlined,
      title: 'Simuler un scénario',
      subtitle: '3a, LPP, leasing, crédit...',
      color: Colors.orange,
      route: '/tools',
    );
    const apprendre = _MentorAction(
      icon: Icons.school_outlined,
      title: 'Apprendre un concept',
      subtitle: 'Pilier 3a, LPP, fiscalité...',
      color: Colors.purple,
      route: '/education/hub',
    );
    const askMint = _MentorAction(
      icon: Icons.auto_awesome,
      title: 'Ask MINT',
      subtitle: 'Pose tes questions finance suisse',
      color: MintColors.accent,
      route: '/ask-mint',
    );
    const enrichir = _MentorAction(
      icon: Icons.person_add_outlined,
      title: 'Enrichir mon profil',
      subtitle: 'Plus de precision = meilleurs conseils',
      color: MintColors.primary,
      route: '/advisor/wizard',
    );
    const documents = _MentorAction(
      icon: Icons.folder_outlined,
      title: 'Mes documents',
      subtitle: 'Coffre-fort numérique',
      color: MintColors.success,
      route: '/documents',
    );

    switch (currentTabIndex) {
      case 0: // Dashboard
        return [session, rapport, simuler, apprendre, askMint];
      case 1: // Agir
        return [session, simuler, rapport, apprendre, askMint];
      case 2: // Apprendre
        return [simuler, apprendre, askMint, session, rapport];
      case 3: // Profil
        return [enrichir, documents, askMint, session, simuler];
      default:
        return [session, rapport, simuler, apprendre, askMint];
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actionsForTab();
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MintColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: MintColors.accentPastel,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: MintColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mentor Advisor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Que puis-je faire pour toi ?',
                        style: TextStyle(
                          fontSize: 14,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Actions (ordered by tab context)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: actions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final a = actions[index];
                return _buildActionTile(
                  context,
                  icon: a.icon,
                  title: a.title,
                  subtitle: a.subtitle,
                  color: a.color,
                  onTap: () {
                    Navigator.pop(context);
                    context.push(a.route);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: MintColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _MentorAction {
  const _MentorAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;
}
