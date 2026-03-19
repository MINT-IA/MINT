import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/educational/educational_insert_widget.dart';

class StressCheckInsertWidget extends StatelessWidget {
  final VoidCallback? onLearnMore;
  final Function(String route)? onAction;

  const StressCheckInsertWidget({
    super.key,
    this.onLearnMore,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return EducationalInsertWidget(
      title: 'Ton stress financier, en clair',
      subtitle: 'Identifions ton levier n°1 en 30 secondes',
      disclaimer: 'Contenu à visée exclusivement pédagogique. MINT n\'est pas un service médical.',
      hypotheses: const [
        'Évaluation subjective de la priorité par l\'utilisateur',
        'Basé sur les barèmes suisses standards (AVS/LPP/Impôts)',
      ],
      onLearnMore: onLearnMore,
      content: Column(
        children: [
          _buildStressOption(
            icon: Icons.account_balance_wallet,
            label: 'Maîtriser mon flux mensuel (Budget)',
            route: '/budget',
          ),
          const SizedBox(height: 8),
          _buildStressOption(
            icon: Icons.trending_down,
            label: 'Alléger ma charge de dettes',
            route: '/simulator/leasing',
          ),
          const SizedBox(height: 8),
          _buildStressOption(
            icon: Icons.receipt_long,
            label: 'Optimiser mes impôts',
            route: '/pilier-3a',
          ),
          const SizedBox(height: 8),
          _buildStressOption(
            icon: Icons.security,
            label: 'Sécuriser ma retraite',
            route: '/retraite',
          ),
        ],
      ),
    );
  }

  Widget _buildStressOption({
    required IconData icon,
    required String label,
    required String route,
  }) {
    return Semantics(
      label: 'interactive element',
      button: true,
      child: InkWell(
      onTap: () => onAction?.call(route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: MintColors.primary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: MintColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: MintColors.primary, size: 20),
          ],
        ),
      ),
    ),);
  }
}
