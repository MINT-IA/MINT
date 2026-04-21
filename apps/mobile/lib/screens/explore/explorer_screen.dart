import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/mint_shell.dart';

/// Explorer tab root — 7 domain hubs in a 2-column grid.
class ExplorerScreen extends StatelessWidget {
  const ExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Explorer',
          style: MintTextStyles.headlineSmall(color: MintColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: MintColors.textPrimary),
            onPressed: () => MintShell.openDrawer(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(MintSpacing.md),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: MintSpacing.md,
          crossAxisSpacing: MintSpacing.md,
          childAspectRatio: 1.1,
          children: [
            _HubCard(
              icon: Icons.savings_outlined,
              label: S.of(context)!.hubRetraite,
              route: '/explore/retraite',
              color: MintColors.accent,
            ),
            _HubCard(
              icon: Icons.family_restroom_outlined,
              label: S.of(context)!.hubFamille,
              route: '/explore/famille',
              color: MintColors.corailDiscret,
            ),
            _HubCard(
              icon: Icons.work_outline,
              label: S.of(context)!.hubTravail,
              route: '/explore/travail',
              color: MintColors.ardoise,
            ),
            _HubCard(
              icon: Icons.home_outlined,
              label: S.of(context)!.hubLogement,
              route: '/explore/logement',
              color: MintColors.accent,
            ),
            _HubCard(
              icon: Icons.receipt_long_outlined,
              label: S.of(context)!.hubFiscalite,
              route: '/explore/fiscalite',
              color: MintColors.corailDiscret,
            ),
            _HubCard(
              icon: Icons.account_balance_outlined,
              label: S.of(context)!.hubPatrimoine,
              route: '/explore/patrimoine',
              color: MintColors.ardoise,
            ),
            _HubCard(
              icon: Icons.health_and_safety_outlined,
              label: S.of(context)!.hubSante,
              route: '/explore/sante',
              color: MintColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final Color color;

  const _HubCard({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: MintColors.ardoise.withValues(alpha: 0.12)),
      ),
      color: MintColors.craie,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.all(MintSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: MintSpacing.sm),
              Text(
                label,
                style: MintTextStyles.labelLarge(color: MintColors.textPrimary),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
