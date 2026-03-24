import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

class TravailHubScreen extends StatelessWidget {
  const TravailHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.porcelaine,
        surfaceTintColor: MintColors.porcelaine,
        title: Text(l.exploreHubTravailTitle, style: MintTextStyles.headlineMedium()),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.lg,
          vertical: MintSpacing.md,
        ),
        children: [
          MintEntrance(child: Text(
            l.exploreHubFeatured,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          )),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.travailHubFeaturedPremierEmploi,
            subtitle: l.travailHubFeaturedPremierEmploiSub,
            icon: Icons.rocket_launch_outlined,
            tone: MintSurfaceTone.bleu,
            onTap: () => context.push('/first-job'),
          ),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.travailHubFeaturedChomage,
            subtitle: l.travailHubFeaturedChomageSub,
            icon: Icons.shield_outlined,
            tone: MintSurfaceTone.bleu,
            onTap: () => context.push('/unemployment'),
          ),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.travailHubFeaturedIndependant,
            subtitle: l.travailHubFeaturedIndependantSub,
            icon: Icons.storefront_outlined,
            tone: MintSurfaceTone.bleu,
            onTap: () => context.push('/segments/independant'),
          ),
          const SizedBox(height: MintSpacing.xl),
          MintEntrance(delay: Duration(milliseconds: 100), child: Text(
            l.exploreHubSeeAll,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          )),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.travailHubToolComparateurEmploi,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/simulator/job-comparison'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.travailHubToolFrontalier,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/segments/frontalier'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.travailHubToolExpatriation,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/expatriation'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.travailHubToolGenderGap,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/segments/gender-gap'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.travailHubToolAvsIndependant,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/independants/avs'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.travailHubToolIjm,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/independants/ijm'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.travailHubTool3aIndependant,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/independants/3a'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.travailHubToolDividendeSalaire,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/independants/dividende-salaire'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.travailHubToolLppVolontaire,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/independants/lpp-volontaire'),
          ),
          const SizedBox(height: MintSpacing.xl),
          TextButton.icon(
            onPressed: () => context.push('/education/hub'),
            icon: const Icon(
              Icons.school_outlined,
              size: 16,
              color: MintColors.textMuted,
            ),
            label: Text(
              l.exploreHubLearnMore,
              style: MintTextStyles.bodySmall(color: MintColors.textMuted),
            ),
          ),
          const SizedBox(height: MintSpacing.xxl),
        ],
      ),
    );
  }
}

class _HubItemCard extends StatelessWidget {
  const _HubItemCard({
    required this.title,
    required this.tone,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final MintSurfaceTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: MintSurface(
          tone: tone,
          padding: EdgeInsets.symmetric(
            horizontal: MintSpacing.lg,
            vertical: subtitle != null ? MintSpacing.lg : MintSpacing.md,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: MintColors.textSecondary, size: 22),
                const SizedBox(width: MintSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: subtitle != null
                          ? MintTextStyles.titleMedium()
                          : MintTextStyles.bodyMedium(),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        subtitle!,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: MintColors.textMuted.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
