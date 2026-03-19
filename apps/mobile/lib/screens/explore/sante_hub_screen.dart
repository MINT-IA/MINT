import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

class SanteHubScreen extends StatelessWidget {
  const SanteHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.white,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        title: Text('Sante', style: MintTextStyles.headlineMedium()),
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
            title: 'Franchise LAMal',
            subtitle: 'Trouve la franchise qui te coute le moins',
            icon: Icons.health_and_safety_outlined,
            iconColor: MintColors.info,
            onTap: () => context.push('/assurances/lamal'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _FeaturedCard(
            title: 'Invalidite',
            subtitle: 'Estime ta couverture en cas d\'incapacite',
            icon: Icons.accessible_outlined,
            iconColor: MintColors.warning,
            onTap: () => context.push('/invalidite'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _FeaturedCard(
            title: 'Check-up couverture',
            subtitle: 'Verifie que tu es bien protege',
            icon: Icons.verified_user_outlined,
            iconColor: MintColors.success,
            onTap: () => context.push('/assurances/coverage'),
          ),
          const SizedBox(height: MintSpacing.xl),
          Text(
            'Voir tout',
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _ToolRow(
            title: 'Assurance invalidite',
            onTap: () => context.push('/disability/insurance'),
          ),
          _ToolRow(
            title: 'Invalidite independant',
            onTap: () => context.push('/disability/self-employed'),
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
