import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/data/commune_registry.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Cycle canonique du fait domicile fiscal (Lego 1).
///
/// Collecte → relecture explicite → confirmation → résumé enregistré avec
/// modification et suppression. La sortie sûre n'écrit rien ; un échec de
/// persistance est visible et ne prétend jamais avoir réussi.
class MintNextDomicileScreen extends StatefulWidget {
  const MintNextDomicileScreen({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<MintNextDomicileScreen> createState() => _MintNextDomicileScreenState();
}

enum _Step { collect, review, noSwissDomicile, saved }

enum _RegistryState { loading, ready, failed }

class _MintNextDomicileScreenState extends State<MintNextDomicileScreen> {
  _Step _step = _Step.collect;

  /// La commune CHOISIE dans le registre fédéral — jamais un texte tapé.
  /// Tant qu'elle est nulle, rien ne peut être enregistré : c'est elle qui
  /// porte le numéro OFS et d'où le canton est dérivé.
  CommuneEntry? _selected;

  final _communeController = TextEditingController();
  List<CommuneEntry> _suggestions = const [];
  _RegistryState _registry =
      CommuneRegistry.isLoaded ? _RegistryState.ready : _RegistryState.loading;
  bool _validationError = false;
  bool _saveFailed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final existing = context.read<CoachProfileProvider>().domicileFact;
    if (existing != null) {
      _step = _Step.saved;
      // Un fait plus ancien peut ne porter aucun numéro OFS : il a été
      // enregistré à l'époque du champ libre. On ne LUI EN INVENTE PAS un,
      // on le laisse non résolu — la modification repassera par le registre.
      _selected = existing.communeBfs == null
          ? null
          : CommuneRegistry.byBfs(existing.communeBfs!);
      _communeController.text = existing.communeName ?? '';
    }
    _loadRegistry();
  }

  /// Le registre fédéral est un asset. Trois états, jamais un quatrième
  /// implicite : lecture en cours, prêt, échec. Un champ grisé sans
  /// explication laisserait quelqu'un devant un écran mort sans savoir si
  /// c'est lui ou l'app qui ne fonctionne pas.
  Future<void> _loadRegistry() async {
    if (CommuneRegistry.isLoaded) {
      if (mounted) setState(() => _registry = _RegistryState.ready);
      return;
    }
    if (mounted) setState(() => _registry = _RegistryState.loading);
    try {
      await CommuneRegistry.load();
    } on Object catch (error) {
      debugPrint('[MintNextDomicile] registre indisponible : $error');
      if (!mounted) return;
      setState(() => _registry = _RegistryState.failed);
      return;
    }
    if (!mounted) return;
    setState(() {
      _registry = _RegistryState.ready;
      final existing = context.read<CoachProfileProvider>().domicileFact;
      if (_selected == null && existing?.communeBfs != null) {
        _selected = CommuneRegistry.byBfs(existing!.communeBfs!);
      }
    });
  }

  @override
  void dispose() {
    _communeController.dispose();
    super.dispose();
  }

  DateTime _now() => (widget.now ?? DateTime.now)();

  MintNextDomicileFact _draftFact() => MintNextDomicileFact(
        // Le canton n'est pas saisi : il est DÉRIVÉ de la commune choisie.
        canton: _selected!.canton,
        communeName: _selected!.officialName,
        communeBfs: _selected!.bfs,
        assertedAt: _now(),
        source: MintNextDomicileFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  Future<void> _confirmSave() async {
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    try {
      await context.read<CoachProfileProvider>().saveDomicileFact(_draftFact());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.saved;
      });
    } on Object catch (error, stack) {
      debugPrint('[MintNextDomicile] save failed: '
          '${error.runtimeType}: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _saveFailed = true;
      });
    }
  }

  Future<void> _confirmNoSwissDomicile() async {
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    try {
      await context.read<CoachProfileProvider>().saveDomicileFact(
            MintNextDomicileFact.noSwissTaxDomicile(
              assertedAt: _now(),
              source: MintNextDomicileFact.userDeclarationSource,
              schemaVersion: 1,
            ),
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _selected = null;
        _communeController.clear();
        _step = _Step.saved;
      });
    } on Object catch (error, stack) {
      debugPrint('[MintNextDomicile] save failed: '  // lint-ignore
          '${error.runtimeType}: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _saveFailed = true;
      });
    }
  }

  Future<void> _delete() async {
    final l10n = S.of(context)!;
    final provider = context.read<CoachProfileProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mintNextDomicileDeleteTitle),
        content: Text(l10n.mintNextDomicileDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.mintNextDomicileDeleteCancel),
          ),
          Semantics(
            identifier: 'action:domicile.delete_confirm',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.mintNextDomicileDeleteConfirm),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    try {
      await provider.deleteDomicileFact();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _selected = null;
        _suggestions = const [];
        _communeController.clear();
        _step = _Step.collect;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _saveFailed = true;
      });
    }
  }

  void _onQueryChanged(String value) {
    setState(() {
      _validationError = false;
      // Toute frappe invalide la sélection : sinon on enregistrerait une
      // commune que la personne ne voit plus dans le champ.
      _selected = null;
      _suggestions = CommuneRegistry.search(value);
    });
  }

  void _select(CommuneEntry commune) {
    setState(() {
      _selected = commune;
      _communeController.text = commune.officialName;
      _suggestions = const [];
      _validationError = false;
    });
  }

  void _clearSelection() {
    setState(() {
      _selected = null;
      _communeController.clear();
      _suggestions = const [];
    });
  }

  /// « canton d'Argovie », jamais « canton de Argovie ».
  ///
  /// L'élision est une contrainte FRANÇAISE. Les autres langues construisent
  /// leur phrase autour du nom nu (« im Kanton Genf »), et leur coller une
  /// préposition française produirait la faute inverse.
  String _cantonPhrase(BuildContext context, String code) {
    final bare = cantonFullNames[code] ?? code;
    if (Localizations.localeOf(context).languageCode != 'fr') return bare;
    return cantonWithArticle[code] ?? bare;
  }

  /// La date de l'instantané, écrite dans la langue de la personne.
  String _snapshotLabel(BuildContext context) {
    final day = CommuneRegistry.snapshotDay;
    if (day == null) return CommuneRegistry.snapshotDate;
    return MaterialLocalizations.of(context).formatFullDate(day);
  }

  void _safeExit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    // Le geste de retour système doit faire ce que dit le bouton « Retour » :
    // revenir au champ de commune. Sans cela il quitte l'écran et perd la
    // sélection, alors que l'écran affiche une marche arrière.
    return PopScope(
      canPop: _step != _Step.review && _step != _Step.noSwissDomicile,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop &&
            (_step == _Step.review || _step == _Step.noSwissDomicile)) {
          setState(() => _step = _Step.collect);
        }
      },
      child: Scaffold(
        backgroundColor: MintColors.warmWhite,
        appBar: AppBar(
          title: Text(l10n.mintNextDomicileTitle),
          leading: Semantics(
            identifier: 'action:domicile.safe_exit',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.mintNextDomicileSafeExit,
              onPressed: _safeExit,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MintSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_saveFailed)
                  Semantics(
                    identifier: 'status:domicile.save_failed',
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(MintSpacing.md),
                      margin: const EdgeInsets.only(bottom: MintSpacing.md),
                      decoration: BoxDecoration(
                        color: MintColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(l10n.mintNextDomicileSaveFailed,
                          style: MintTextStyles.bodyMedium(
                              color: MintColors.textPrimary)),
                    ),
                  ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: MintSpacing.md),
                    child: LinearProgressIndicator(),
                  ),
                switch (_step) {
                  _Step.collect => _collect(l10n),
                  _Step.review => _review(l10n),
                  _Step.noSwissDomicile => _noSwissDomicile(l10n),
                  _Step.saved => _saved(l10n),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _collect(S l10n) => Semantics(
        identifier: 'node:domicile.collect',
        container: true,
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.mintNextDomicileQuestion,
                  style: MintTextStyles.headlineMedium(
                      color: MintColors.textPrimary)),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(l10n.mintNextDomicileWhy,
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary)),
            const SizedBox(height: MintSpacing.lg),
            Semantics(
              identifier: 'input:domicile.commune',
              child: TextField(
                controller: _communeController,
                enabled: _registry == _RegistryState.ready,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: l10n.mintNextDomicileCommuneLabel,
                  hintText: l10n.mintNextDomicileCommuneHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onQueryChanged,
              ),
            ),
            if (_registry == _RegistryState.loading) ...[
              const SizedBox(height: MintSpacing.sm),
              Semantics(
                identifier: 'status:domicile.registry_loading',
                liveRegion: true,
                child: Text(l10n.mintNextDomicileRegistryLoading,
                    style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary)),
              ),
            ] else if (_registry == _RegistryState.failed) ...[
              const SizedBox(height: MintSpacing.sm),
              Semantics(
                identifier: 'status:domicile.registry_failed',
                liveRegion: true,
                child: Text(l10n.mintNextDomicileRegistryFailed,
                    style: MintTextStyles.bodyMedium(color: MintColors.error)),
              ),
              const SizedBox(height: MintSpacing.xs),
              Semantics(
                identifier: 'action:domicile.registry_retry',
                child: TextButton(
                  onPressed: _busy ? null : _loadRegistry,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(l10n.mintNextDomicileRegistryRetry),
                ),
              ),
            ],
            if (_selected != null) ...[
              const SizedBox(height: MintSpacing.md),
              // Le canton n'est pas un second champ : c'est une conséquence
              // de la commune, montrée pour que la personne puisse la
              // vérifier avant d'aller plus loin.
              Semantics(
                identifier: 'status:domicile.canton_derived',
                liveRegion: true,
                child: Text(
                  l10n.mintNextDomicileCantonDerived(
                      _cantonPhrase(context, _selected!.canton)),
                  style:
                      MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                ),
              ),
              const SizedBox(height: MintSpacing.xs),
              Semantics(
                identifier: 'action:domicile.change_commune',
                child: TextButton(
                  onPressed: _busy ? null : _clearSelection,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(l10n.mintNextDomicileChangeCommune),
                ),
              ),
            ] else if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: MintSpacing.sm),
              Semantics(
                identifier: 'node:domicile.suggestions',
                container: true,
                explicitChildNodes: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final commune in _suggestions)
                      // L'identifiant porte le numéro OFS : une suggestion se
                      // sélectionne mécaniquement par son identité fédérale,
                      // jamais par son libellé affiché.
                      Semantics(
                        identifier: 'action:domicile.suggestion:${commune.bfs}',
                        label: l10n.mintNextDomicileSuggestionA11y(
                            commune.officialName,
                            cantonFullNames[commune.canton] ?? commune.canton),
                        child: TextButton(
                          onPressed: _busy ? null : () => _select(commune),
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            alignment: Alignment.centerLeft,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Le nom officiel porte déjà son suffixe
                              // cantonal quand il lève un homonyme
                              // (« Rickenbach (LU) ») : convention du
                              // registre, pas mise en forme de MINT.
                              Text(commune.officialName,
                                  style: MintTextStyles.bodyMedium(
                                      color: MintColors.textPrimary)),
                              // Le canton en toutes lettres : deux initiales
                              // ne parlent pas à tout le monde.
                              Text(
                                  cantonFullNames[commune.canton] ??
                                      commune.canton,
                                  style: MintTextStyles.bodySmall(
                                      color: MintColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else if (_communeController.text.trim().isNotEmpty) ...[
              const SizedBox(height: MintSpacing.sm),
              // Rien trouvé : on le dit, on ne laisse pas croire qu'une
              // saisie libre fera l'affaire.
              Semantics(
                identifier: 'status:domicile.no_match',
                liveRegion: true,
                child: Text(l10n.mintNextDomicileNoMatch,
                    style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary)),
              ),
            ],
            if (_validationError) ...[
              const SizedBox(height: MintSpacing.sm),
              Semantics(
                identifier: 'status:domicile.validation_error',
                liveRegion: true,
                child: Text(l10n.mintNextDomicileErrorMissing,
                    style: MintTextStyles.bodySmall(color: MintColors.error)),
              ),
            ],
            const SizedBox(height: MintSpacing.md),
            // Visible dès l'ouverture, pas seulement après une recherche
            // infructueuse : quelqu'un qui SAIT ne pas avoir de commune
            // suisse ne doit pas devoir échouer d'abord pour le dire.
            // Secondaire, pour que la question « es-tu imposé en Suisse ? »
            // ne soit pas posée d'emblée à tout le monde.
            Semantics(
              identifier: 'action:domicile.no_swiss_domicile',
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _step = _Step.noSwissDomicile),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
                child: Text(l10n.mintNextDomicileNoSwissAction),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            Semantics(
              identifier: 'action:domicile.continue',
              button: true,
              child: FilledButton(
                onPressed: _busy || _registry != _RegistryState.ready
                    ? null
                    : () {
                        if (_selected == null) {
                          setState(() => _validationError = true);
                          return;
                        }
                        setState(() => _step = _Step.review);
                      },
                child: Text(l10n.mintNextDomicileContinue),
              ),
            ),
          ],
        ),
      );

  /// Une limite structurante s'annonce AVANT toute collecte supplémentaire,
  /// pas après. Ce que MINT ne pourra pas faire est dit ici, une fois, sans
  /// détour et sans transformer l'aveu en rejet à la porte.
  Widget _noSwissDomicile(S l10n) => Semantics(
        identifier: 'node:domicile.no_swiss',
        container: true,
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.mintNextDomicileNoSwissTitle,
                  style: MintTextStyles.headlineMedium(
                      color: MintColors.textPrimary)),
            ),
            const SizedBox(height: MintSpacing.md),
            Semantics(
              identifier: 'status:domicile.no_swiss_limit',
              child: Text(l10n.mintNextDomicileNoSwissLimit,
                  style:
                      MintTextStyles.bodyMedium(color: MintColors.textPrimary)),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(l10n.mintNextDomicileNoSwissStillUseful,
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary)),
            const SizedBox(height: MintSpacing.xl),
            Semantics(
              identifier: 'action:domicile.no_swiss_confirm',
              child: FilledButton(
                onPressed: _busy ? null : _confirmNoSwissDomicile,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: Text(l10n.mintNextDomicileNoSwissConfirm),
              ),
            ),
            const SizedBox(height: MintSpacing.sm),
            Semantics(
              identifier: 'action:domicile.back_to_collect',
              child: TextButton(
                onPressed:
                    _busy ? null : () => setState(() => _step = _Step.collect),
                style:
                    TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(l10n.mintNextDomicileBack),
              ),
            ),
          ],
        ),
      );

  Widget _review(S l10n) {
    final commune = _selected!;
    return Semantics(
      identifier: 'node:domicile.review',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.mintNextDomicileReviewTitle,
                style: MintTextStyles.headlineMedium(
                    color: MintColors.textPrimary)),
          ),
          const SizedBox(height: MintSpacing.md),
          Container(
            padding: const EdgeInsets.all(MintSpacing.md),
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MintColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(commune.officialName,
                    style: MintTextStyles.headlineSmall(
                        color: MintColors.textPrimary)),
                Text(
                    l10n.mintNextDomicileCantonDerived(
                        _cantonPhrase(context, commune.canton)),
                    style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary)),
                const SizedBox(height: MintSpacing.xs),
                // La provenance a sa place ICI, au moment où l'on relit ce
                // que MINT va retenir — pas avant la première frappe, où elle
                // n'aide personne à choisir sa commune.
                Semantics(
                  identifier: 'node:domicile.registry_source',
                  child: Text(
                    l10n.mintNextDomicileRegistrySource(
                        _snapshotLabel(context)),
                    style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary),
                  ),
                ),
                const SizedBox(height: MintSpacing.sm),
                Text(
                  l10n.mintNextDomicileReviewSource(
                      MaterialLocalizations.of(context)
                          .formatShortDate(_now())),
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.xl),
          Semantics(
            identifier: 'action:domicile.confirm',
            button: true,
            child: FilledButton(
              onPressed: _busy ? null : _confirmSave,
              child: Text(l10n.mintNextDomicileConfirm),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            identifier: 'action:domicile.back_to_collect',
            button: true,
            child: TextButton(
              onPressed:
                  _busy ? null : () => setState(() => _step = _Step.collect),
              child: Text(l10n.mintNextDomicileBack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saved(S l10n) {
    final fact = context.watch<CoachProfileProvider>().domicileFact;
    if (fact == null) {
      return _collect(l10n);
    }
    return Semantics(
      identifier: 'node:domicile.saved',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.mintNextDomicileSavedTitle,
                style: MintTextStyles.headlineMedium(
                    color: MintColors.textPrimary)),
          ),
          const SizedBox(height: MintSpacing.md),
          Container(
            padding: const EdgeInsets.all(MintSpacing.md),
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MintColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  identifier: 'fact:domicile.summary',
                  child: Text(
                      fact.hasSwissTaxDomicile
                          ? (fact.communeName ?? '')
                          : l10n.mintNextDomicileNoSwissSavedTitle,
                      style: MintTextStyles.headlineSmall(
                          color: MintColors.textPrimary)),
                ),
                if (fact.hasSwissTaxDomicile && fact.canton != null)
                  Text(
                      l10n.mintNextDomicileCantonDerived(
                          _cantonPhrase(context, fact.canton!)),
                      style: MintTextStyles.bodyMedium(
                          color: MintColors.textSecondary))
                else if (!fact.hasSwissTaxDomicile)
                  Text(l10n.mintNextDomicileNoSwissLimit,
                      style: MintTextStyles.bodyMedium(
                          color: MintColors.textSecondary)),
                const SizedBox(height: MintSpacing.sm),
                Text(
                  l10n.mintNextDomicileReviewSource(
                      MaterialLocalizations.of(context)
                          .formatShortDate(fact.assertedAt.toLocal())),
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.xl),
          // Après la première mission de l'app, la suite doit être visible :
          // « Modifier » et « Supprimer » sont de la gestion, pas une suite.
          Semantics(
            identifier: 'action:domicile.back_to_today',
            child: FilledButton(
              onPressed: _busy ? null : () => context.go('/home'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              child: Text(l10n.mintNextDomicileBackToToday),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            identifier: 'action:domicile.edit',
            child: FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _selected = fact.communeBfs == null
                            ? null
                            : CommuneRegistry.byBfs(fact.communeBfs!);
                        _communeController.text = fact.communeName ?? '';
                        _suggestions = const [];
                        _step = _Step.collect;
                      }),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              child: Text(l10n.mintNextDomicileEdit),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            identifier: 'action:domicile.delete',
            button: true,
            child: TextButton(
              onPressed: _busy ? null : _delete,
              child: Text(l10n.mintNextDomicileDelete),
            ),
          ),
        ],
      ),
    );
  }
}
