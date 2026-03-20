import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/colors.dart';

/// "Explorer" hub — navigation rows to tools and simulators.
///
/// Pure presentational widget. No business logic.
class ExploreHub extends StatelessWidget {
  const ExploreHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explorer',
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Outils et simulateurs pour ta pr\u00e9voyance',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
          ),
          const SizedBox(height: 12),
          const _ExploreRow(
            icon: Icons.person_outline,
            title: 'Mon profil',
            subtitle: 'Compl\u00e9ter ou ajuster mes donn\u00e9es',
            route: '/profile/bilan',
          ),
          if (FeatureFlags.enableDecisionScaffold)
            const _ExploreRow(
              icon: Icons.balance,
              title: 'Rente vs capital',
              subtitle: 'Comparer les options de retrait LPP',
              route: '/rente-vs-capital',
            ),
          const _ExploreRow(
            icon: Icons.chat_outlined,
            title: 'Coach & check-in',
            subtitle: 'Discussion et suivi mensuel',
            route: '/coach/checkin',
          ),
          const _ExploreRow(
            icon: Icons.document_scanner_outlined,
            title: 'Scanner un document',
            subtitle: 'Certificat LPP, d\u00e9claration fiscale',
            route: '/scan',
          ),
          const _ExploreRow(
            icon: Icons.assignment_outlined,
            title: 'Extrait AVS',
            subtitle: 'Commander et v\u00e9rifier ton extrait CI',
            route: '/document-scan/avs-guide',
          ),
        ],
      ),
    );
  }
}

class _ExploreRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const _ExploreRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'interactive element',
      button: true,
      child: InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: MintColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: MintColors.textMuted),
          ],
        ),
      ),
    ),);
  }
}
