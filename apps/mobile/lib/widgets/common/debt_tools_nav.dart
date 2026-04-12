import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Navigation croisée entre les 5 outils dette.
///
/// Affiche les outils connexes (exclut l'écran courant via [currentRoute]).
class DebtToolsNav extends StatelessWidget {
  final String currentRoute;

  const DebtToolsNav({super.key, required this.currentRoute});

  static const _tools = [
    _DebtTool(
      route: '/debt/ratio',
      icon: Icons.speed,
      title: 'Diagnostic dette',
      subtitle: 'Ton ratio d\'endettement et minimum vital',
    ),
    _DebtTool(
      route: '/debt/repayment',
      icon: Icons.trending_down,
      title: 'Plan de remboursement',
      subtitle: 'Avalanche vs boule de neige',
    ),
    _DebtTool(
      route: '/check/debt',
      icon: Icons.fact_check_outlined,
      title: 'Check risque',
      subtitle: 'Auto-évaluation en 6 questions',
    ),
    _DebtTool(
      route: '/simulator/credit',
      icon: Icons.credit_card,
      title: 'Simulateur crédit',
      subtitle: 'Mensualité et coût total d\'un crédit',
    ),
    _DebtTool(
      route: '/debt/help',
      icon: Icons.support_agent,
      title: 'Aide professionnelle',
      subtitle: 'Dettes Conseils Suisse, Caritas, cantonal',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final others = _tools.where((t) => t.route != currentRoute).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OUTILS DETTE CONNEXES',
            style: MintTextStyles.labelMedium(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          const Text(
            'Explore tous les outils pour maîtriser ta dette.',
            style: TextStyle(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < others.length; i++) ...[
            _buildToolLink(context, others[i]),
            if (i < others.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildToolLink(BuildContext context, _DebtTool tool) {
    return Semantics(
      label: tool.title,
      button: true,
      child: InkWell(
        onTap: () => context.push(tool.route),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(tool.icon, color: MintColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: MintColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebtTool {
  final String route;
  final IconData icon;
  final String title;
  final String subtitle;

  const _DebtTool({
    required this.route,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
