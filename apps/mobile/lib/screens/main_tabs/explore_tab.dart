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
///
/// Search bar (W17-P3.3): keyword-based client-side search across
/// all tools, screens, and hubs.
class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

/// A searchable entry in the explore index.
class _SearchEntry {
  final String label;
  final String route;
  final List<String> keywords;

  const _SearchEntry(this.label, this.route, this.keywords);

  /// Case- and accent-insensitive match against query.
  bool matches(String normalizedQuery) {
    if (_normalize(label).contains(normalizedQuery)) return true;
    for (final kw in keywords) {
      if (_normalize(kw).contains(normalizedQuery)) return true;
    }
    return false;
  }

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[àâä]'), 'a')
        .replaceAll(RegExp('[ùûü]'), 'u')
        .replaceAll(RegExp('[ôö]'), 'o')
        .replaceAll(RegExp('[îï]'), 'i')
        .replaceAll('ç', 'c');
  }
}

class _ExploreTabState extends State<ExploreTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Static search index — all major tools, screens, and hubs.
  static const List<_SearchEntry> _searchIndex = [
    // Retraite
    _SearchEntry('Retraite', '/retraite', ['retirement', 'pension', 'AVS', 'LPP']),
    _SearchEntry('Rente vs Capital', '/rente-vs-capital', ['rente', 'capital', 'choix']),
    _SearchEntry('Rachat LPP', '/rachat-lpp', ['rachat', 'buyback', '2e pilier']),
    _SearchEntry('EPL', '/epl', ['retrait', 'anticipé', 'pilier']),
    _SearchEntry('Décaissement', '/decaissement', ['withdrawal', 'retrait']),
    _SearchEntry('Succession', '/succession', ['héritage', 'estate']),
    _SearchEntry('Libre passage', '/libre-passage', ['transfer', 'caisse']),
    // Fiscalité
    _SearchEntry('Pilier 3a', '/pilier-3a', ['3a', 'épargne', 'fiscal']),
    _SearchEntry('Comparateur 3a', '/3a-deep/comparator', ['provider', 'banque']),
    _SearchEntry('Rendement réel 3a', '/3a-deep/real-return', ['rendement', 'return']),
    _SearchEntry('3a échelonné', '/3a-deep/staggered-withdrawal', ['retrait', 'échelonné']),
    _SearchEntry('3a rétroactif', '/3a-retroactif', ['rétroactif', 'retroactive']),
    _SearchEntry('Fiscal', '/fiscal', ['impôt', 'tax', 'cantonal']),
    // Logement
    _SearchEntry('Hypothèque', '/hypotheque', ['mortgage', 'maison', 'achat']),
    _SearchEntry('Amortissement', '/mortgage/amortization', ['amortir', 'rembourser']),
    _SearchEntry('Valeur locative', '/mortgage/imputed-rental', ['locative', 'imputed']),
    _SearchEntry('SARON vs Fixe', '/mortgage/saron-vs-fixed', ['taux', 'rate', 'SARON']),
    // Famille
    _SearchEntry('Divorce', '/divorce', ['séparation', 'splitting']),
    _SearchEntry('Mariage', '/mariage', ['wedding', 'couple']),
    _SearchEntry('Naissance', '/naissance', ['bébé', 'enfant', 'baby']),
    _SearchEntry('Concubinage', '/concubinage', ['union libre']),
    // Emploi
    _SearchEntry('Chômage', '/unemployment', ['perte', 'emploi', 'job']),
    _SearchEntry('Premier emploi', '/first-job', ['stage', 'apprenti']),
    _SearchEntry('Expatriation', '/expatriation', ['expat', 'étranger']),
    // Indépendants
    _SearchEntry('Indépendant', '/segments/independant', ['self-employed', 'freelance']),
    // Santé
    _SearchEntry('Invalidité', '/invalidite', ['disability', 'AI']),
    _SearchEntry('LAMal', '/assurances/lamal', ['franchise', 'assurance']),
    // Budget
    _SearchEntry('Budget', '/budget', ['dépenses', 'revenu', 'expenses']),
    _SearchEntry('Dettes', '/check/debt', ['dette', 'crédit', 'debt']),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

    final normalizedQuery = _searchQuery.isNotEmpty
        ? _SearchEntry._normalize(_searchQuery)
        : '';
    final searchResults = normalizedQuery.isNotEmpty
        ? _searchIndex.where((e) => e.matches(normalizedQuery)).toList()
        : <_SearchEntry>[];

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
        // Search bar
        SliverToBoxAdapter(
          child: Container(
            color: MintColors.porcelaine,
            padding: const EdgeInsets.fromLTRB(
              MintSpacing.lg,
              MintSpacing.md,
              MintSpacing.lg,
              0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l.explorerSearchHint,
                prefixIcon: const Icon(
                  Icons.search,
                  color: MintColors.textSecondary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: MintColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: MintColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (query) =>
                  setState(() => _searchQuery = query),
            ),
          ),
        ),
        // Search results OR hub grid
        if (_searchQuery.isNotEmpty)
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
                  if (searchResults.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: MintSpacing.xl,
                      ),
                      child: Center(
                        child: Text(
                          l.explorerSearchNoResults,
                          style: MintTextStyles.bodyMedium(
                            color: MintColors.textMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final entry in searchResults)
                      _buildSearchResultTile(context, entry),
                  const SizedBox(height: MintSpacing.xxl),
                ],
              ),
            ),
          )
        else
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

  /// Build a single search result tile.
  Widget _buildSearchResultTile(BuildContext context, _SearchEntry entry) {
    return Semantics(
      button: true,
      label: entry.label,
      child: ListTile(
        leading: const Icon(
          Icons.arrow_forward_rounded,
          color: MintColors.textSecondary,
          size: 20,
        ),
        title: Text(
          entry.label,
          style: MintTextStyles.bodyLarge(),
        ),
        contentPadding: EdgeInsets.zero,
        shape: Border(
          bottom: BorderSide(
            color: MintColors.textMuted.withValues(alpha: 0.15),
          ),
        ),
        onTap: () => context.push(entry.route),
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
