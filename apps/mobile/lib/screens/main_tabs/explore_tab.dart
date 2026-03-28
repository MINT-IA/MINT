import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Tab 2 — Explorer
///
/// 7 hubs thematiques. Chaque hub = une grande carte narrative
/// avec fond colore subtil (Cleo-inspired).
///
/// Hubs: Retraite, Famille, Travail & Statut, Logement,
///        Fiscalite, Patrimoine & Succession, Sante & Protection
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: MintColors.porcelaine,
          surfaceTintColor: MintColors.porcelaine,
          title: Text(
            l.tabExplore,
            style: MintTextStyles.headlineMedium(),
          ),
          centerTitle: false,
        ),
        SliverToBoxAdapter(
          child: Container(
            color: MintColors.porcelaine,
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.lg,
            ),
            child: Column(
              children: [
                const SizedBox(height: MintSpacing.md),
                MintEntrance(
                  child: _ExploreHubCard(
                    title: l.exploreHubRetraiteTitle,
                    narrative: l.exploreHubRetraiteSubtitle,
                    tone: MintSurfaceTone.sauge,
                    icon: Icons.beach_access_outlined,
                    onTap: () => context.push('/explore/retraite'),
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),
                MintEntrance(
                  delay: const Duration(milliseconds: 100),
                  child: _ExploreHubCard(
                    title: l.exploreHubFamilleTitle,
                    narrative: l.exploreHubFamilleSubtitle,
                    tone: MintSurfaceTone.peche,
                    icon: Icons.family_restroom_outlined,
                    onTap: () => context.push('/explore/famille'),
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),
                MintEntrance(
                  delay: const Duration(milliseconds: 200),
                  child: _ExploreHubCard(
                    title: l.exploreHubTravailTitle,
                    narrative: l.exploreHubTravailSubtitle,
                    tone: MintSurfaceTone.bleu,
                    icon: Icons.work_outline,
                    onTap: () => context.push('/explore/travail'),
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),
                MintEntrance(
                  delay: const Duration(milliseconds: 300),
                  child: _ExploreHubCard(
                    title: l.exploreHubLogementTitle,
                    narrative: l.exploreHubLogementSubtitle,
                    tone: MintSurfaceTone.porcelaine,
                    icon: Icons.home_outlined,
                    onTap: () => context.push('/explore/logement'),
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),
                MintEntrance(
                  delay: const Duration(milliseconds: 400),
                  child: _ExploreHubCard(
                    title: l.exploreHubFiscaliteTitle,
                    narrative: l.exploreHubFiscaliteSubtitle,
                    tone: MintSurfaceTone.blanc,
                    icon: Icons.receipt_long_outlined,
                    onTap: () => context.push('/explore/fiscalite'),
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),
                MintEntrance(
                  delay: const Duration(milliseconds: 500),
                  child: _ExploreHubCard(
                    title: l.exploreHubPatrimoineTitle,
                    narrative: l.exploreHubPatrimoineSubtitle,
                    tone: MintSurfaceTone.sauge,
                    icon: Icons.account_balance_outlined,
                    onTap: () => context.push('/explore/patrimoine'),
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),
                MintEntrance(
                  delay: const Duration(milliseconds: 600),
                  child: _ExploreHubCard(
                    title: l.exploreHubSanteTitle,
                    narrative: l.exploreHubSanteSubtitle,
                    tone: MintSurfaceTone.bleu,
                    icon: Icons.health_and_safety_outlined,
                    onTap: () => context.push('/explore/sante'),
                  ),
                ),
                const SizedBox(height: MintSpacing.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Premium hub card — warm coloured surface, narrative text,
/// generous breathing room. Cleo "goal card" aesthetic.
class _ExploreHubCard extends StatelessWidget {
  final String title;
  final String narrative;
  final MintSurfaceTone tone;
  final IconData icon;
  final VoidCallback onTap;

  const _ExploreHubCard({
    required this.title,
    required this.narrative,
    required this.tone,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: MintSurface(
          tone: tone,
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: MintColors.textSecondary,
                    size: 22,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: MintColors.textMuted.withValues(alpha: 0.5),
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: MintSpacing.lg),
              Text(
                title,
                style: MintTextStyles.headlineMedium(),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                narrative,
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textSecondary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
