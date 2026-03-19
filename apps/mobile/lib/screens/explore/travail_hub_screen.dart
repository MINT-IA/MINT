import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

class TravailHubScreen extends StatelessWidget {
  const TravailHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.white,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        title: Text('Travail', style: MintTextStyles.headlineMedium()),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(MintSpacing.lg),
        children: [
          Text(
            'Parcours vedettes',
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _FeaturedCard(
            title: 'Premier emploi',
            subtitle: 'Tout ce qu\'il faut savoir pour bien demarrer',
            icon: Icons.rocket_launch_outlined,
            iconColor: MintColors.info,
            onTap: () => context.push('/first-job'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _FeaturedCard(
            title: 'Chomage',
            subtitle: 'Tes droits, indemnites et demarches',
            icon: Icons.shield_outlined,
            iconColor: MintColors.warning,
            onTap: () => context.push('/unemployment'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _FeaturedCard(
            title: 'Independant',
            subtitle: 'Prevoyance et fiscalite sur mesure',
            icon: Icons.storefront_outlined,
            iconColor: MintColors.success,
            onTap: () => context.push('/segments/independant'),
          ),
          const SizedBox(height: MintSpacing.xl),
          Text(
            'Voir tout',
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _ToolRow(
            title: 'Comparateur d\'emploi',
            onTap: () => context.push('/simulator/job-comparison'),
          ),
          _ToolRow(
            title: 'Frontalier',
            onTap: () => context.push('/segments/frontalier'),
          ),
          _ToolRow(
            title: 'Expatriation',
            onTap: () => context.push('/expatriation'),
          ),
          _ToolRow(
            title: 'Gender gap',
            onTap: () => context.push('/segments/gender-gap'),
          ),
          _ToolRow(
            title: 'AVS independant',
            onTap: () => context.push('/independants/avs'),
          ),
          _ToolRow(
            title: 'IJM',
            onTap: () => context.push('/independants/ijm'),
          ),
          _ToolRow(
            title: '3a independant',
            onTap: () => context.push('/independants/3a'),
          ),
          _ToolRow(
            title: 'Dividende vs Salaire',
            onTap: () => context.push('/independants/dividende-salaire'),
          ),
          _ToolRow(
            title: 'LPP volontaire',
            onTap: () => context.push('/independants/lpp-volontaire'),
          ),
          const SizedBox(height: MintSpacing.xl),
          TextButton.icon(
            onPressed: () => context.push('/education/hub'),
            icon: const Icon(
              Icons.school_outlined,
              size: 16,
              color: MintColors.info,
            ),
            label: Text(
              'Comprendre ce sujet',
              style: MintTextStyles.bodySmall(color: MintColors.info),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.iconColor = MintColors.info,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MintColors.border.withAlpha(128),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: MintSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: MintTextStyles.titleMedium()),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    subtitle,
                    style: MintTextStyles.bodySmall(
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
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text(title, style: MintTextStyles.bodyMedium()),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              color: MintColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
