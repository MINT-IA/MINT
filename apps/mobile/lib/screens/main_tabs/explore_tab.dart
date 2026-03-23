import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Tab 2 — Explorer
///
/// 7 hubs thematiques with 2-tier layout:
///   - Top 3 promoted hubs (large cards) — selected by user age context
///   - Bottom 4 compact rows — grouped in a single MintSurface card
///
/// Age-based promotion:
///   - age > 50  → Retraite, Fiscalité, Patrimoine & Succession
///   - age 35-50 → Retraite, Logement, Fiscalité
///   - age < 35  → Travail & Statut, Logement, Famille
///   - fallback  → Retraite, Fiscalité, Logement
///
/// Hubs: Retraite, Famille, Travail & Statut, Logement,
///        Fiscalite, Patrimoine & Succession, Sante & Protection
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final int? userAge = _resolveUserAge(context);
    final promotedIds = _promotedHubIds(userAge);

    // Build full hub list in canonical order.
    final allHubs = _buildAllHubs(l, context);

    // Split into promoted (top 3) and compact (bottom 4).
    final promoted = <_HubData>[];
    final compact = <_HubData>[];
    for (final hub in allHubs) {
      if (promotedIds.contains(hub.id)) {
        promoted.add(hub);
      } else {
        compact.add(hub);
      }
    }

    // Sort promoted to match promotedIds order.
    promoted.sort((a, b) =>
        promotedIds.indexOf(a.id).compareTo(promotedIds.indexOf(b.id)));

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: MintSpacing.md),
                // ── Top 3: promoted hub cards ──
                for (int i = 0; i < promoted.length; i++) ...[
                  _ExploreHubCard(
                    title: promoted[i].title,
                    narrative: promoted[i].narrative,
                    tone: promoted[i].tone,
                    icon: promoted[i].icon,
                    onTap: promoted[i].onTap,
                  ),
                  if (i < promoted.length - 1)
                    const SizedBox(height: MintSpacing.xl),
                ],
                const SizedBox(height: MintSpacing.xl),
                // ── Section label ──
                Text(
                  l.exploreHubOtherTopics,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: MintSpacing.md),
                // ── Bottom 4: compact rows in a single card ──
                MintSurface(
                  tone: MintSurfaceTone.blanc,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < compact.length; i++) ...[
                        _CompactHubRow(
                          title: compact[i].title,
                          icon: compact[i].icon,
                          onTap: compact[i].onTap,
                          isFirst: i == 0,
                          isLast: i == compact.length - 1,
                        ),
                        if (i < compact.length - 1)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            indent: MintSpacing.md,
                            endIndent: MintSpacing.md,
                            color: MintColors.lightBorder,
                          ),
                      ],
                    ],
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

  /// Resolve user age from CoachProfileProvider (nullable when no profile).
  int? _resolveUserAge(BuildContext context) {
    try {
      final provider = context.watch<CoachProfileProvider>();
      return provider.profile?.age;
    } catch (_) {
      return null;
    }
  }

  /// Return the 3 hub IDs to promote based on user age.
  List<String> _promotedHubIds(int? age) {
    if (age == null) return ['retraite', 'fiscalite', 'logement'];
    if (age > 50) return ['retraite', 'fiscalite', 'patrimoine'];
    if (age >= 35) return ['retraite', 'logement', 'fiscalite'];
    return ['travail', 'logement', 'famille'];
  }

  /// Build canonical list of all 7 hubs with metadata.
  List<_HubData> _buildAllHubs(S l, BuildContext context) {
    return [
      _HubData(
        id: 'retraite',
        title: l.exploreHubRetraiteTitle,
        narrative: l.exploreHubRetraiteSubtitle,
        tone: MintSurfaceTone.sauge,
        icon: Icons.beach_access_outlined,
        onTap: () => context.push('/explore/retraite'),
      ),
      _HubData(
        id: 'famille',
        title: l.exploreHubFamilleTitle,
        narrative: l.exploreHubFamilleSubtitle,
        tone: MintSurfaceTone.peche,
        icon: Icons.family_restroom_outlined,
        onTap: () => context.push('/explore/famille'),
      ),
      _HubData(
        id: 'travail',
        title: l.exploreHubTravailTitle,
        narrative: l.exploreHubTravailSubtitle,
        tone: MintSurfaceTone.bleu,
        icon: Icons.work_outline,
        onTap: () => context.push('/explore/travail'),
      ),
      _HubData(
        id: 'logement',
        title: l.exploreHubLogementTitle,
        narrative: l.exploreHubLogementSubtitle,
        tone: MintSurfaceTone.porcelaine,
        icon: Icons.home_outlined,
        onTap: () => context.push('/explore/logement'),
      ),
      _HubData(
        id: 'fiscalite',
        title: l.exploreHubFiscaliteTitle,
        narrative: l.exploreHubFiscaliteSubtitle,
        tone: MintSurfaceTone.blanc,
        icon: Icons.receipt_long_outlined,
        onTap: () => context.push('/explore/fiscalite'),
      ),
      _HubData(
        id: 'patrimoine',
        title: l.exploreHubPatrimoineTitle,
        narrative: l.exploreHubPatrimoineSubtitle,
        tone: MintSurfaceTone.sauge,
        icon: Icons.account_balance_outlined,
        onTap: () => context.push('/explore/patrimoine'),
      ),
      _HubData(
        id: 'sante',
        title: l.exploreHubSanteTitle,
        narrative: l.exploreHubSanteSubtitle,
        tone: MintSurfaceTone.bleu,
        icon: Icons.health_and_safety_outlined,
        onTap: () => context.push('/explore/sante'),
      ),
    ];
  }
}

/// Internal data holder for a hub entry.
class _HubData {
  final String id;
  final String title;
  final String narrative;
  final MintSurfaceTone tone;
  final IconData icon;
  final VoidCallback onTap;

  const _HubData({
    required this.id,
    required this.title,
    required this.narrative,
    required this.tone,
    required this.icon,
    required this.onTap,
  });
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

/// Compact hub row — icon + title + chevron inside a grouped card.
class _CompactHubRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _CompactHubRow({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(20) : Radius.zero,
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md,
            vertical: MintSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: MintColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: MintSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: MintTextStyles.titleMedium(),
                ),
              ),
              Icon(
                Icons.chevron_right,
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
