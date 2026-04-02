import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:provider/provider.dart';

/// Tab 2 — Explorer
///
/// 7 hubs thematiques. Chaque hub = une grande carte narrative
/// avec fond colore subtil (Cleo-inspired).
///
/// Hubs reordered dynamically by lifecycle phase (W17-P1).
/// Default order (no profile / acceleration phase):
///   Fiscalite, Logement, Retraite, Patrimoine, Famille, Travail, Sante
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  /// Hub display order by lifecycle phase.
  /// Keys match _hubConfigs entries below.
  static const Map<LifecyclePhase, List<String>> _hubOrder = {
    LifecyclePhase.demarrage: [
      'travail', 'fiscalite', 'logement', 'sante',
      'famille', 'patrimoine', 'retraite',
    ],
    LifecyclePhase.construction: [
      'logement', 'fiscalite', 'travail', 'famille',
      'retraite', 'patrimoine', 'sante',
    ],
    LifecyclePhase.acceleration: [
      'fiscalite', 'logement', 'retraite', 'patrimoine',
      'famille', 'travail', 'sante',
    ],
    LifecyclePhase.consolidation: [
      'retraite', 'fiscalite', 'patrimoine', 'logement',
      'famille', 'sante', 'travail',
    ],
    LifecyclePhase.transition: [
      'retraite', 'patrimoine', 'fiscalite', 'sante',
      'logement', 'famille', 'travail',
    ],
    LifecyclePhase.retraite: [
      'retraite', 'sante', 'patrimoine', 'fiscalite',
      'famille', 'logement', 'travail',
    ],
    LifecyclePhase.transmission: [
      'patrimoine', 'famille', 'sante', 'retraite',
      'fiscalite', 'logement', 'travail',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final profile = context.watch<CoachProfileProvider>().profile;
    final phase = profile != null
        ? LifecyclePhaseService.detect(profile)
        : null;
    final orderedHubKeys = phase != null
        ? _hubOrder[phase.phase]!
        : _hubOrder[LifecyclePhase.acceleration]!;

    // Hub configuration map — same icons, titles, colors, routes as before.
    final hubConfigs = <String, _HubConfig>{
      'retraite': _HubConfig(
        title: l.exploreHubRetraiteTitle,
        narrative: l.exploreHubRetraiteSubtitle,
        tone: MintSurfaceTone.sauge,
        icon: Icons.beach_access_outlined,
        route: '/explore/retraite',
      ),
      'famille': _HubConfig(
        title: l.exploreHubFamilleTitle,
        narrative: l.exploreHubFamilleSubtitle,
        tone: MintSurfaceTone.peche,
        icon: Icons.family_restroom_outlined,
        route: '/explore/famille',
      ),
      'travail': _HubConfig(
        title: l.exploreHubTravailTitle,
        narrative: l.exploreHubTravailSubtitle,
        tone: MintSurfaceTone.bleu,
        icon: Icons.work_outline,
        route: '/explore/travail',
      ),
      'logement': _HubConfig(
        title: l.exploreHubLogementTitle,
        narrative: l.exploreHubLogementSubtitle,
        tone: MintSurfaceTone.porcelaine,
        icon: Icons.home_outlined,
        route: '/explore/logement',
      ),
      'fiscalite': _HubConfig(
        title: l.exploreHubFiscaliteTitle,
        narrative: l.exploreHubFiscaliteSubtitle,
        tone: MintSurfaceTone.blanc,
        icon: Icons.receipt_long_outlined,
        route: '/explore/fiscalite',
      ),
      'patrimoine': _HubConfig(
        title: l.exploreHubPatrimoineTitle,
        narrative: l.exploreHubPatrimoineSubtitle,
        tone: MintSurfaceTone.sauge,
        icon: Icons.account_balance_outlined,
        route: '/explore/patrimoine',
      ),
      'sante': _HubConfig(
        title: l.exploreHubSanteTitle,
        narrative: l.exploreHubSanteSubtitle,
        tone: MintSurfaceTone.bleu,
        icon: Icons.health_and_safety_outlined,
        route: '/explore/sante',
      ),
    };

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: MintColors.porcelaine,
          surfaceTintColor: MintColors.porcelaine,
          title: Semantics(
            header: true,
            child: Text(
              l.tabExplore,
              style: MintTextStyles.headlineMedium(),
            ),
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
                for (int i = 0; i < orderedHubKeys.length; i++) ...[
                  if (i > 0) const SizedBox(height: MintSpacing.xl),
                  _buildHubCard(
                    context,
                    hubConfigs[orderedHubKeys[i]]!,
                    delay: Duration(milliseconds: i * 100),
                  ),
                ],
                const SizedBox(height: MintSpacing.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build a single hub card with entrance animation.
  Widget _buildHubCard(
    BuildContext context,
    _HubConfig config, {
    required Duration delay,
  }) {
    return MintEntrance(
      delay: delay,
      child: _ExploreHubCard(
        title: config.title,
        narrative: config.narrative,
        tone: config.tone,
        icon: config.icon,
        onTap: () => context.push(config.route),
      ),
    );
  }
}

/// Internal hub configuration — maps key to display properties.
class _HubConfig {
  final String title;
  final String narrative;
  final MintSurfaceTone tone;
  final IconData icon;
  final String route;

  const _HubConfig({
    required this.title,
    required this.narrative,
    required this.tone,
    required this.icon,
    required this.route,
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
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: MintTextStyles.headlineMedium(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
