import 'dart:math';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/widgets/coach/baby_cost_widget.dart';
import 'package:mint_mobile/widgets/coach/budget_bebe_widget.dart';
import 'package:mint_mobile/widgets/coach/clause_3a_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:mint_mobile/widgets/visualizations/fiscal_impact_waterfall.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:provider/provider.dart';

// ────────────────────────────────────────────────────────────
//  NAISSANCE SCREEN — Category C (Life Event)
// ────────────────────────────────────────────────────────────
//
// Four-tab interactive screen:
//   Tab 1: "Conge"       — Parental leave APG calculator
//   Tab 2: "Allocations" — Family allowances by canton
//   Tab 3: "Impact"      — Financial impact of having children
//   Tab 4: "Checklist"   — Essential steps for new parents
//
// Design System: MintTextStyles + MintSpacing tokens.
// AppBar: white standard (Life Event screen).
// Ne constitue pas un conseil en prévoyance (LSFin).
//
// P2 « gate dur » : chaque sortie calculée (congé APG / allocations / impact)
// est gatée derrière les faits de situation qu'ELLE consomme. Un fait n'est
// CONFIRMÉ que s'il vient des données réelles de l'utilisateur (provenance =
// `userProvidedFields` / `gender` non-null, ou champ touché). Une valeur égale
// à un défaut fabriqué reste ASSUMED (jamais confirmée). Aucun chiffre ne se
// calcule sur un défaut inventé.
// Réf : .planning/decisions/2026-07-25-p2-simulator-result-gating.md
// ────────────────────────────────────────────────────────────

class NaissanceScreen extends StatefulWidget {
  const NaissanceScreen({super.key});

  @override
  State<NaissanceScreen> createState() => _NaissanceScreenState();
}

class _NaissanceScreenState extends State<NaissanceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: Conge inputs ───────────────────────────────
  bool _isMother = true;
  double _salaireMensuel = 6000;
  Map<String, dynamic>? _congeResult;

  // ── Tab 2: Allocations inputs ─────────────────────────
  String _cantonAlloc = 'VD';
  int _nbEnfantsAlloc = 1;
  Map<String, dynamic>? _allocResult;
  List<Map<String, dynamic>> _allocRanking = [];

  // ── Tab 3: Impact inputs ──────────────────────────────
  double _revenuImpact = 80000;
  int _nbEnfantsImpact = 1;
  double _fraisGarde = 1500;
  Map<String, dynamic>? _impactResult;

  // ── Tab 4: Checklist state ──────────────────────────────
  final Set<int> _checkedItems = {};
  final Map<int, bool> _expandedItems = {};

  // ── P2 « gate dur » : provenance PAR FAIT, ré-évaluée à chaque notify ──
  // Pas de latch global `_prefilled` : `loadFromWizard` notifie plusieurs fois
  // (cache→frais→fusionné) ; un latch au 1er notify échouerait un champ dont la
  // donnée arrive au notify suivant. Chaque fait garde `_xSeeded`/`_xTouched`.
  CoachProfileProvider? _profileProvider;

  // Congé : salaire (clé 'salary') + rôle parental (gender non-null, sans clé).
  bool _salaireTouched = false;
  bool _salaireSeeded = false; // provenance = userProvidedFields('salary').
  bool _parentRoleTouched = false;
  bool _parentRoleSeeded = false; // provenance = profile.gender non-null.

  // Allocations : canton (clé 'canton') + nb enfants (sans clé → touch seul).
  bool _cantonTouched = false;
  bool _cantonSeeded = false; // provenance = userProvidedFields('canton').
  bool _nbEnfantsAllocTouched = false; // pas de clé → confirmable au touch seul.

  // Impact : revenu (dérive de la clé 'salary') + frais de garde (aucune source
  // profil → touch seul) + nb enfants (sans clé → touch seul).
  bool _revenuTouched = false;
  bool _revenuSeeded = false; // provenance = userProvidedFields('salary').
  double _totalEpargne3a = 0.0; // solde 3a réel (profil), 0 si inconnu/effacé.
  bool _fraisGardeTouched = false; // aucune source profil → confirmable au touch.
  bool _nbEnfantsImpactTouched = false; // pas de clé → confirmable au touch seul.

  // Baselines pour l'annonce VoiceOver incomplet→complet (par sortie).
  bool _congeGateComplete = false;
  bool _allocGateComplete = false;
  bool _impactGateComplete = false;

  // Ancres pour scroll-to-first-missing quand une situation est incomplète.
  final _congeSalaireKey = GlobalKey();
  final _congeParentKey = GlobalKey();
  final _allocCantonKey = GlobalKey();
  final _allocNbEnfantsKey = GlobalKey();
  final _impactRevenuKey = GlobalKey();
  final _impactFraisGardeKey = GlobalKey();
  final _impactNbEnfantsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Gate dur : au 1er frame rien n'est confirmé → aucun résultat fabriqué.
    _recalculateAll();
  }

  /// P2 (zéro donnée inventée) : on s'abonne au provider car `loadFromWizard()`
  /// hydrate le profil de façon asynchrone (l'écran peut être monté avant
  /// l'arrivée des données). Un champ édité (touched) n'est jamais réécrasé par
  /// une hydratation tardive ; un champ absent garde son défaut éditable mais
  /// reste non confirmé → gaté.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    CoachProfileProvider? provider;
    try {
      provider = context.read<CoachProfileProvider>();
    } on ProviderNotFoundException {
      provider = null; // tests unitaires isolés : on garde les défauts.
    }
    if (!identical(provider, _profileProvider)) {
      _profileProvider?.removeListener(_seedFromProfile);
      _profileProvider = provider;
      _profileProvider?.addListener(_seedFromProfile);
    }
    _seedFromProfile();
    // Baseline APRÈS le seed : pas d'annonce parasite si le profil confirme
    // déjà tout au premier build.
    _refreshGateBaselines();
  }

  @override
  void dispose() {
    _profileProvider?.removeListener(_seedFromProfile);
    _tabController.dispose();
    super.dispose();
  }

  /// Seed provenance-gaté, rejoué à CHAQUE notify (aucun latch global).
  /// Un champ n'est amorcé — et donc confirmé — que si sa provenance est réelle :
  /// une clé `userProvidedFields`, un `gender` non-null, jamais valeur≠défaut.
  void _seedFromProfile() {
    final profile = _profileProvider?.profile;
    var changed = false;

    if (profile == null) {
      // Profil absent : pas encore hydraté (le listener rejouera) ou effacé
      // (logout / reset) pendant que l'écran est monté. La provenance issue du
      // profil disparaît : les faits seededFromProfile retombent à non
      // confirmés (un fait TOUCHÉ reste une donnée user et survit). Tout
      // résultat qui reposait sur un fait seedé est invalidé — aucun chiffre ne
      // survit à sa source.
      if (_salaireSeeded) {
        _salaireSeeded = false;
        changed = true;
      }
      if (_parentRoleSeeded) {
        _parentRoleSeeded = false;
        changed = true;
      }
      if (_cantonSeeded) {
        _cantonSeeded = false;
        changed = true;
      }
      if (_revenuSeeded) {
        _revenuSeeded = false;
        changed = true;
      }
      // Le solde 3a affiché (clause OPP3) est une donnée profil live : sur un
      // clear il doit disparaître, sinon un ancien solde CHF resterait rendu.
      if (_totalEpargne3a != 0.0) {
        _totalEpargne3a = 0.0;
        changed = true;
      }
      if (changed) {
        _recalculateAll();
        _refreshGateBaselines();
        if (mounted) setState(() {});
      }
      return;
    }

    // Solde 3a réel (clause bénéficiaire OPP3) — ré-évalué à chaque notify,
    // jamais inventé. Champ d'état (pas de lecture live en build) pour qu'un
    // clear le remette à 0 et retire la carte.
    {
      final e3a = profile.prevoyance.totalEpargne3a;
      if (e3a != _totalEpargne3a) {
        _totalEpargne3a = e3a;
        changed = true;
      }
    }

    // Congé — salaire mensuel : clé 'salary' ET valeur DANS la plage
    // représentable du contrôle [2000, 15000]. Un clamp fabriquerait une valeur
    // ≠ la vraie (ex. 1000 affiché 2000) ; hors plage → NON confirmé (gaté).
    if (!_salaireTouched) {
      final v = profile.salaireBrutMensuel;
      final valid = profile.userProvidedFields.contains('salary') &&
          v >= 2000.0 &&
          v <= 15000.0;
      if (_salaireSeeded != valid) {
        _salaireSeeded = valid;
        changed = true;
      }
      if (valid) {
        if (v != _salaireMensuel) {
          _salaireMensuel = v;
          changed = true;
        }
      }
    }

    // Congé — rôle parental : provenance = `gender` non-null ('F'→mère,
    // 'M'→père). AUCUNE clé userProvidedFields (gender non-null == donnée
    // réelle). Un gender null laisse le défaut `true` ASSUMED → congé gaté
    // (afficher 14 semaines de maternité à un inconnu/père serait une
    // fabrication).
    if (!_parentRoleTouched) {
      final g = profile.gender;
      final valid = g == 'F' || g == 'M';
      if (_parentRoleSeeded != valid) {
        _parentRoleSeeded = valid;
        changed = true;
      }
      if (valid) {
        final v = g == 'F';
        if (v != _isMother) {
          _isMother = v;
          changed = true;
        }
      }
    }

    // Allocations — canton : clé 'canton'.
    if (!_cantonTouched) {
      final c = profile.canton;
      final valid = profile.userProvidedFields.contains('canton') &&
          c.isNotEmpty &&
          c != 'unknown' &&
          FamilyService.cantonNames.containsKey(c);
      if (_cantonSeeded != valid) {
        _cantonSeeded = valid;
        changed = true;
      }
      if (valid && c != _cantonAlloc) {
        _cantonAlloc = c;
        changed = true;
      }
    }

    // Allocations — nombre d'enfants : AUCUNE clé → confirmable au touch seul.
    // On amorce la VALEUR (confort) quand > 0 ; ne confirme jamais le fait.
    if (!_nbEnfantsAllocTouched && profile.nombreEnfants > 0) {
      final v = profile.nombreEnfants.clamp(1, 5);
      if (v != _nbEnfantsAlloc) {
        _nbEnfantsAlloc = v;
        changed = true;
      }
    }

    // Impact — revenu annuel = salaire × 12 : clé 'salary' ET revenu DANS la
    // plage représentable [30000, 200000]. Hors plage → NON confirmé (un clamp
    // fabriquerait un revenu ≠ le vrai). Pas de clamp : on ne seede que la
    // vraie valeur en plage.
    if (!_revenuTouched) {
      final annual = profile.salaireBrutMensuel * 12;
      final valid = profile.userProvidedFields.contains('salary') &&
          annual >= 30000.0 &&
          annual <= 200000.0;
      if (_revenuSeeded != valid) {
        _revenuSeeded = valid;
        changed = true;
      }
      if (valid && annual != _revenuImpact) {
        _revenuImpact = annual;
        changed = true;
      }
    }

    // Impact — nombre d'enfants : AUCUNE clé → confirmable au touch seul.
    // Valeur de confort amorcée quand > 0 ; ne confirme jamais le fait.
    if (!_nbEnfantsImpactTouched && profile.nombreEnfants > 0) {
      final v = profile.nombreEnfants.clamp(1, 5);
      if (v != _nbEnfantsImpact) {
        _nbEnfantsImpact = v;
        changed = true;
      }
    }

    // Frais de garde : AUCUNE source profil → jamais amorcé (le défaut 1500
    // reste ASSUMED jusqu'à ce que l'utilisateur fournisse son coût réel).

    if (changed) {
      _recalculateAll();
      _refreshGateBaselines();
      if (mounted) setState(() {});
    }
  }

  // ── P2 provenance getters (live, non-latching) ──
  FactProvenance get _salaireProvenance => _salaireTouched
      ? FactProvenance.touched
      : (_salaireSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  FactProvenance get _parentRoleProvenance => _parentRoleTouched
      ? FactProvenance.touched
      : (_parentRoleSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  FactProvenance get _cantonProvenance => _cantonTouched
      ? FactProvenance.touched
      : (_cantonSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  FactProvenance get _nbEnfantsAllocProvenance =>
      _nbEnfantsAllocTouched ? FactProvenance.touched : FactProvenance.assumed;

  FactProvenance get _revenuProvenance => _revenuTouched
      ? FactProvenance.touched
      : (_revenuSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  FactProvenance get _fraisGardeProvenance =>
      _fraisGardeTouched ? FactProvenance.touched : FactProvenance.assumed;

  FactProvenance get _nbEnfantsImpactProvenance =>
      _nbEnfantsImpactTouched ? FactProvenance.touched : FactProvenance.assumed;

  // ── Per-output gates (determinative facts only) ──
  // Congé APG : salaire (le chiffre) + rôle parental (durée maternité≠paternité).
  SituationGate _congeGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'salaire',
          label: (c) => S.of(c)!.naissanceGateFactSalaire,
          why: (c) => S.of(c)!.naissanceGateWhySalaire,
          provenance: _salaireProvenance,
          onComplete: () => _scrollToKey(_congeSalaireKey),
        ),
        SituationFact(
          key: 'parentRole',
          label: (c) => S.of(c)!.naissanceGateFactParent,
          why: (c) => S.of(c)!.naissanceGateWhyParent,
          provenance: _parentRoleProvenance,
          onComplete: () => _scrollToKey(_congeParentKey),
        ),
      ]);

  // Allocations : canton (barème cantonal) + nombre d'enfants.
  SituationGate _allocGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'canton',
          label: (c) => S.of(c)!.naissanceGateFactCanton,
          why: (c) => S.of(c)!.naissanceGateWhyCanton,
          provenance: _cantonProvenance,
          onComplete: () => _scrollToKey(_allocCantonKey),
        ),
        SituationFact(
          key: 'nbEnfants',
          label: (c) => S.of(c)!.naissanceGateFactEnfants,
          why: (c) => S.of(c)!.naissanceGateWhyEnfants,
          provenance: _nbEnfantsAllocProvenance,
          onComplete: () => _scrollToKey(_allocNbEnfantsKey),
        ),
      ]);

  // Impact : revenu imposable + frais de garde réels + nombre d'enfants.
  SituationGate _impactGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'revenu',
          label: (c) => S.of(c)!.naissanceGateFactRevenu,
          why: (c) => S.of(c)!.naissanceGateWhyRevenu,
          provenance: _revenuProvenance,
          onComplete: () => _scrollToKey(_impactRevenuKey),
        ),
        SituationFact(
          key: 'fraisGarde',
          label: (c) => S.of(c)!.naissanceGateFactFraisGarde,
          why: (c) => S.of(c)!.naissanceGateWhyFraisGarde,
          provenance: _fraisGardeProvenance,
          onComplete: () => _scrollToKey(_impactFraisGardeKey),
        ),
        SituationFact(
          key: 'nbEnfants',
          label: (c) => S.of(c)!.naissanceGateFactEnfants,
          why: (c) => S.of(c)!.naissanceGateWhyEnfantsImpact,
          provenance: _nbEnfantsImpactProvenance,
          onComplete: () => _scrollToKey(_impactNbEnfantsKey),
        ),
        // L'impact consomme AUSSI le canton (impôt/allocations cantonaux) et le
        // rôle parental (interruption LPP maternité 12 mois vs paternité 2). Ces
        // figures secondaires seraient fabriquées sur les défauts VD/maternité
        // si on ne gatait pas dessus. Canton/rôle seedent du profil → pas de
        // friction pour un profil complet.
        SituationFact(
          key: 'canton',
          label: (c) => S.of(c)!.naissanceGateFactCanton,
          why: (c) => S.of(c)!.naissanceGateWhyCanton,
          provenance: _cantonProvenance,
          onComplete: () => _scrollToKey(_allocCantonKey),
        ),
        SituationFact(
          key: 'parentRole',
          label: (c) => S.of(c)!.naissanceGateFactParent,
          why: (c) => S.of(c)!.naissanceGateWhyParent,
          provenance: _parentRoleProvenance,
          onComplete: () => _scrollToKey(_congeParentKey),
        ),
      ]);

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  COMPUTE (compute-time gate : aucun résultat sans faits confirmés)
  // ════════════════════════════════════════════════════════════

  void _recalculateAll() {
    _recalculateConge();
    _recalculateAlloc();
    _recalculateImpact();
  }

  /// Le congé n'est calculé que si son gate est complet (salaire + rôle).
  /// Sinon `null` : le slot résultat affiche la carte de situation.
  void _recalculateConge() {
    _congeResult = _congeGate(context).complete
        ? FamilyService.simulateCongeParental(
            salaireMensuel: _salaireMensuel,
            isMother: _isMother,
          )
        : null;
  }

  /// Les allocations ne sont calculées que si canton + nombre d'enfants sont
  /// confirmés. Sinon `null` (et ranking vide) : la carte de situation prend la
  /// place du résultat.
  void _recalculateAlloc() {
    if (_allocGate(context).complete) {
      _allocResult = FamilyService.estimateAllocations(
        canton: _cantonAlloc,
        nbEnfants: _nbEnfantsAlloc,
      );
      _allocRanking = FamilyService.getAllocationsRanking(
        nbEnfants: _nbEnfantsAlloc,
      );
    } else {
      _allocResult = null;
      _allocRanking = [];
    }
  }

  /// L'impact n'est calculé que si revenu + frais de garde + nombre d'enfants
  /// sont confirmés. Sinon `null` : la carte de situation prend la place.
  void _recalculateImpact() {
    _impactResult = _impactGate(context).complete ? _computeImpact() : null;
  }

  Map<String, dynamic> _computeImpact() {
    final tauxMarginal = 0.15 + (_revenuImpact / 1000000);
    final fiscalResult = FamilyService.calculateImpactFiscalEnfant(
      revenuImposable: _revenuImpact,
      tauxMarginal: tauxMarginal,
      nbEnfants: _nbEnfantsImpact,
      fraisGarde: _fraisGarde,
    );

    final allocResult = FamilyService.estimateAllocations(
      canton: _cantonAlloc,
      nbEnfants: _nbEnfantsImpact,
    );
    final allocAnnuel = allocResult['annuelTotal'] as double;

    final economieFiscale = fiscalResult['economieFiscale'] as double;
    final fraisGardeAnnuel = _fraisGarde * 12 * _nbEnfantsImpact;
    // Net = uniquement des inputs gatés (économie fiscale + allocations − frais
    // de garde RÉELS). Aucun « autres coûts » forfaitaire inventé
    // (1500/enfant/mois) : un coût fabriqué n'a pas sa place dans un net
    // personnalisé (Codex P2 : zéro CHF personnel fabriqué dans la sortie).
    final netImpact = economieFiscale + allocAnnuel - fraisGardeAnnuel;

    // Career gap LPP projection
    final interruptionMois = _isMother ? 12 : 2;
    final lppPerteEstimee = _revenuImpact * 0.07 * interruptionMois / 12;

    return {
      'fiscalResult': fiscalResult,
      'allocAnnuel': allocAnnuel,
      'economieFiscale': economieFiscale,
      'fraisGardeAnnuel': fraisGardeAnnuel,
      'netImpact': netImpact,
      'interruptionMois': interruptionMois,
      'lppPerteEstimee': lppPerteEstimee,
    };
  }

  void _refreshGateBaselines() {
    _congeGateComplete = _congeGate(context).complete;
    _allocGateComplete = _allocGate(context).complete;
    _impactGateComplete = _impactGate(context).complete;
  }

  void _announceComplete() {
    SemanticsService.sendAnnouncement(
      View.of(context),
      S.of(context)!.situationGateAnnounceComplete,
      Directionality.of(context),
    );
  }

  /// L'utilisateur a édité un fait de SITUATION du congé (salaire, rôle) :
  /// recalcule tout (stale-result invalidation) et annonce le passage
  /// incomplet→complet pour VoiceOver (le scroll ≠ déplacement de focus).
  void _afterCongeFactChanged() {
    final was = _congeGateComplete;
    setState(_recalculateAll);
    _refreshGateBaselines();
    if (_congeGateComplete && !was) _announceComplete();
  }

  void _afterAllocFactChanged() {
    final was = _allocGateComplete;
    setState(_recalculateAll);
    _refreshGateBaselines();
    if (_allocGateComplete && !was) _announceComplete();
  }

  void _afterImpactFactChanged() {
    final was = _impactGateComplete;
    setState(_recalculateAll);
    _refreshGateBaselines();
    if (_impactGateComplete && !was) _announceComplete();
  }

  /// @visibleForTesting : entrées consommées par les services (preuve P2).
  @visibleForTesting
  double get debugSalaire => _salaireMensuel;
  @visibleForTesting
  bool get debugIsMother => _isMother;
  @visibleForTesting
  String get debugCanton => _cantonAlloc;
  @visibleForTesting
  int get debugNbEnfantsAlloc => _nbEnfantsAlloc;
  @visibleForTesting
  double get debugRevenu => _revenuImpact;
  @visibleForTesting
  int get debugNbEnfantsImpact => _nbEnfantsImpact;
  @visibleForTesting
  double get debugFraisGarde => _fraisGarde;

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // ILLOG-02 : conteneur Semantics racine (motif rente_vs_capital) sinon le
    // pont AX iOS effondre toute la route en un seul nœud (« 1 element »).
    return Semantics(
      identifier: 'naissance_screen',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: MintColors.porcelaine,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildAppBar(context, innerBoxIsScrolled),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTab1Conge(),
              _buildTab2Allocations(),
              _buildTab3Impact(),
              _buildTab4Checklist(),
            ],
          ),
        ),
      ),
    );
  }

  // ── App Bar with Tabs (white standard — Life Event) ──

  Widget _buildAppBar(BuildContext context, bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: 120,
      backgroundColor: MintColors.porcelaine,
      elevation: 0,
      surfaceTintColor: MintColors.porcelaine,
      // Ancre C4 « pas de cul-de-sac » : bouton retour identifié (safePop →
      // pop, sinon go('/home')). Locator sémantique pour le smoke Tier B.
      leading: Semantics(
        identifier: 'naissance-back',
        button: true,
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () => safePop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 56, right: MintSpacing.md),
        // Ancre régionale Tier B smoke (C1 « atteignable ») posée sur le titre
        // AppBar — motif profond, JAMAIS le wrapper racine (leçon ADR AX iOS 26.2).
        title: Semantics(
          identifier: 'naissance-anchor',
          child: Text(
            S.of(context)!.naissanceTitle,
            style: MintTextStyles.headlineMedium(color: MintColors.textPrimary),
          ),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: MintColors.primary,
        indicatorWeight: 2,
        labelColor: MintColors.textPrimary,
        unselectedLabelColor: MintColors.textMuted,
        dividerColor: MintColors.border.withValues(alpha: 0.3),
        labelStyle: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        unselectedLabelStyle: MintTextStyles.bodySmall(color: MintColors.textMuted),
        tabs: [
          Tab(text: S.of(context)!.naissanceTabConge),
          Tab(text: S.of(context)!.naissanceTabAllocations),
          Tab(text: S.of(context)!.naissanceTabImpact),
          Tab(text: S.of(context)!.naissanceTabChecklist),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: CONGE — Parental leave calculator
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Conge() {
    // Render-time gate : la sortie congé ne s'affiche que si son résultat existe
    // ET que ses faits déterminants sont confirmés (données réelles).
    final congeReady = _congeResult != null && _congeGate(context).complete;

    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Narrative intro
        MintNarrativeCard(
          headline: S.of(context)!.narrativeBirthHeadline,
          body: S.of(context)!.narrativeBirthBody,
          tone: MintSurfaceTone.peche,
          badge: S.of(context)!.narrativeBirthBadge,
        ),
        const SizedBox(height: MintSpacing.xl),

        // Result slot : hero « premier éclairage » OU carte de situation gatée.
        if (congeReady) ...[
          _buildCongePremierEclairage(),
          const SizedBox(height: MintSpacing.xl),
        ] else ...[
          SituationGateCard(
            title: S.of(context)!.donationGateTitle,
            gate: _congeGate(context),
          ),
          const SizedBox(height: MintSpacing.xl),
        ],

        // Toggle + salary
        _buildCongeInputsCard(),
        const SizedBox(height: MintSpacing.xl),

        if (congeReady) ...[
          _buildCongeTimeline(),
          const SizedBox(height: MintSpacing.xl),
          _buildCongeBreakdown(),
          const SizedBox(height: MintSpacing.xl),
        ],

        _buildEducationalInsert(
          S.of(context)!.naissanceCongeEducational,
        ),
        const SizedBox(height: MintSpacing.xl),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildCongeInputsCard() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mother/Father toggle
          Row(
            key: _congeParentKey,
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.naissanceLeaveType,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ),
              SegmentedButton<bool>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: MintColors.primary,
                  selectedForegroundColor: MintColors.white,
                  textStyle: MintTextStyles.labelMedium(color: MintColors.textPrimary),
                ),
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(S.of(context)!.naissanceMother),
                    icon: const Icon(Icons.woman, size: 16),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(S.of(context)!.naissanceFather),
                    icon: const Icon(Icons.man, size: 16),
                  ),
                ],
                selected: {_isMother},
                onSelectionChanged: (v) {
                  HapticFeedback.lightImpact();
                  // Sélectionner un rôle = fournir la donnée (touch). Touched
                  // supersede le seed → donnée user, immunisée à un clear profil.
                  _parentRoleTouched = true;
                  _parentRoleSeeded = false;
                  _isMother = v.first;
                  _afterCongeFactChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),

          // Salary input
          MintAmountField(
            key: _congeSalaireKey,
            label: S.of(context)!.naissanceMonthlySalary,
            value: _salaireMensuel,
            formatValue: (v) => FamilyService.formatChf(v),
            onChanged: (v) {
              _salaireTouched = true;
              _salaireSeeded = false; // touched supersede le seed (donnée user).
              _salaireMensuel = v;
              _afterCongeFactChanged();
            },
            min: 2000,
            max: 15000,
          ),
        ],
      ),
    );
  }

  Widget _buildCongeTimeline() {
    final result = _congeResult!;
    final weeks = result['dureeSemaines'] as int;
    final apgDaily = result['apgJournalier'] as double;
    final totalApg = result['totalApg'] as double;
    final isCapped = result['isCapped'] as bool;
    final type = result['type'] as String;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.naissanceCongeLabel(type),
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),

          // Timeline bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _isMother
                    ? MintColors.info.withValues(alpha: 0.15)
                    : MintColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isMother ? MintColors.info : MintColors.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        S.of(context)!.naissanceWeeks(weeks),
                        style: MintTextStyles.bodyMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.md),

          // Details
          _buildResultRow(
            S.of(context)!.naissanceApgPerDay,
            FamilyService.formatChf(apgDaily),
          ),
          const SizedBox(height: MintSpacing.sm),
          _buildResultRow(
            S.of(context)!.naissanceTotalApg,
            FamilyService.formatChf(totalApg),
            valueKey: const Key('naissanceCongeFigure'),
          ),
          if (isCapped) ...[
            const SizedBox(height: MintSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm, vertical: MintSpacing.xs),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                S.of(context)!.naissanceCappedAt(FamilyService.apgDailyMax.toStringAsFixed(0)),
                style: MintTextStyles.labelSmall(color: MintColors.warning).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCongeBreakdown() {
    final result = _congeResult!;
    final salaireJour = result['salaireJournalier'] as double;
    final apgJour = result['apgJournalier'] as double;
    final perte = result['perteSalaire'] as double;
    final diffJour = salaireJour - apgJour;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.naissanceDailyDetail,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildBarComparison(
            label: S.of(context)!.naissanceSalaryPerDay,
            value: salaireJour,
            maxValue: max(salaireJour, apgJour),
            color: MintColors.primary,
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          _buildBarComparison(
            label: S.of(context)!.naissanceApgDay,
            value: apgJour,
            maxValue: max(salaireJour, apgJour),
            color: MintColors.success,
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: MintSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                diffJour > 0 ? S.of(context)!.naissanceDiffPerDay : S.of(context)!.naissanceNoLoss,
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
              ),
              if (diffJour > 0)
                Text(
                  '-${FamilyService.formatChf(diffJour)}',
                  style: MintTextStyles.titleMedium(color: MintColors.error).copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          if (perte > 0) ...[
            const SizedBox(height: MintSpacing.sm),
            Text(
              S.of(context)!.naissanceTotalLossEstimated(FamilyService.formatChf(perte)),
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCongePremierEclairage() {
    final result = _congeResult!;
    final totalApg = result['totalApg'] as double;
    final weeks = result['dureeSemaines'] as int;
    final typeLabel = _isMother
        ? S.of(context)!.naissanceMaternite
        : S.of(context)!.naissancePaternite;

    return MintResultHeroCard(
      key: const Key('naissanceCongeHero'),
      eyebrow: typeLabel,
      primaryValue: FamilyService.formatChf(totalApg),
      primaryLabel: S.of(context)!.naissanceTotalApg,
      secondaryValue: S.of(context)!.naissanceWeeks(weeks),
      secondaryLabel: S.of(context)!.naissanceCongeLabel(typeLabel),
      narrative: S.of(context)!.naissancePremierEclairageText(typeLabel, FamilyService.formatChf(totalApg), weeks),
      tone: MintSurfaceTone.peche,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: ALLOCATIONS — Family allowances by canton
  // ════════════════════════════════════════════════════════════

  Widget _buildTab2Allocations() {
    final allocReady = _allocResult != null && _allocGate(context).complete;

    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Inputs
        _buildAllocInputsCard(),
        const SizedBox(height: MintSpacing.lg),

        if (allocReady) ...[
          // Hero card
          _buildAllocHeroCard(),
          const SizedBox(height: MintSpacing.lg),

          // Canton ranking
          _buildAllocRanking(),
          const SizedBox(height: MintSpacing.lg),

          // Chiffre choc
          _buildAllocPremierEclairage(),
          const SizedBox(height: MintSpacing.lg),
        ] else ...[
          SituationGateCard(
            title: S.of(context)!.donationGateTitle,
            gate: _allocGate(context),
          ),
          const SizedBox(height: MintSpacing.lg),
        ],

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildAllocInputsCard() {
    final sortedCodes = FamilyService.sortedCantonCodes;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        children: [
          // Canton dropdown
          Row(
            key: _allocCantonKey,
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.naissanceCanton,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: MintColors.porcelaine,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _cantonAlloc,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                    items: sortedCodes.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(
                            '$code — ${FamilyService.cantonNames[code]}'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        // Touch = donnée user ; touched supersede le seed.
                        _cantonTouched = true;
                        _cantonSeeded = false;
                        _cantonAlloc = v;
                        _afterAllocFactChanged();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          // Children stepper
          Row(
            key: _allocNbEnfantsKey,
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.naissanceNbEnfants,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ),
              _buildStepper(
                value: _nbEnfantsAlloc,
                minVal: 1,
                maxVal: 5,
                onChanged: (v) {
                  _nbEnfantsAllocTouched = true;
                  _nbEnfantsAlloc = v;
                  _afterAllocFactChanged();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllocHeroCard() {
    final result = _allocResult!;
    final mensuel = result['mensuelTotal'] as double;
    final annuel = result['annuelTotal'] as double;
    final cantonNom = FamilyService.cantonNames[_cantonAlloc] ?? _cantonAlloc;
    final plural = _nbEnfantsAlloc > 1 ? 's' : '';

    return MintResultHeroCard(
      key: const Key('naissanceAllocHero'),
      eyebrow: S.of(context)!.naissanceTabAllocations,
      primaryValue: '${FamilyService.formatChf(mensuel)}/mois',
      primaryLabel: '${FamilyService.formatChf(annuel)}/an',
      narrative: S.of(context)!.naissanceAllocForCanton(cantonNom, _nbEnfantsAlloc, plural),
      accentColor: MintColors.success,
      tone: MintSurfaceTone.sauge,
    );
  }

  Widget _buildAllocRanking() {
    if (_allocRanking.isEmpty) return const SizedBox.shrink();

    final maxMensuel = _allocRanking.first['mensuelTotal'] as double;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.sm, MintSpacing.lg, MintSpacing.sm + 4),
            child: Text(
              S.of(context)!.naissanceRanking26,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
          ),
          ..._allocRanking.map((c) {
            final canton = c['canton'] as String;
            final mensuel = c['mensuelTotal'] as double;
            final isHighlighted = canton == _cantonAlloc;
            final ratio = maxMensuel > 0 ? mensuel / maxMensuel : 0.0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: MintSpacing.xs + 2),
              color: isHighlighted
                  ? MintColors.primary.withValues(alpha: 0.06)
                  : null,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${c['rank']}',
                      style: MintTextStyles.labelSmall(
                        color: isHighlighted
                            ? MintColors.primary
                            : MintColors.textMuted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      canton,
                      style: MintTextStyles.bodySmall(
                        color: isHighlighted
                            ? MintColors.primary
                            : MintColors.textPrimary,
                      ).copyWith(
                        fontWeight:
                            isHighlighted ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: MintColors.appleSurface,
                        color: isHighlighted
                            ? MintColors.primary
                            : MintColors.border,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: MintSpacing.sm + 2),
                  SizedBox(
                    width: 70,
                    child: Text(
                      FamilyService.formatChf(mensuel),
                      style: MintTextStyles.labelSmall(
                        color: isHighlighted
                            ? MintColors.primary
                            : MintColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAllocPremierEclairage() {
    final result = _allocResult!;
    final diff = result['differenceVsBest'] as double;
    final bestCanton = result['bestCantonNom'] as String;
    final cantonNom = result['cantonNom'] as String;

    if (diff <= 0) {
      return Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: MintColors.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined,
                size: 20, color: MintColors.success),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Text(
                S.of(context)!.naissanceBestCanton(cantonNom),
                style: MintTextStyles.bodySmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return _buildEducationalInsert(
      S.of(context)!.naissanceAllocDiff(bestCanton, cantonNom, FamilyService.formatChf(diff)),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: IMPACT — Financial impact of having children
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Impact() {
    final impactReady = _impactResult != null && _impactGate(context).complete;

    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Inputs (toujours visibles)
        _buildImpactInputsCard(),
        const SizedBox(height: MintSpacing.xl),

        if (impactReady) ...[
          ..._buildImpactResults(_impactResult!),
        ] else ...[
          SituationGateCard(
            title: S.of(context)!.donationGateTitle,
            gate: _impactGate(context),
          ),
          const SizedBox(height: MintSpacing.lg),
        ],

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildImpactInputsCard() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        children: [
          MintAmountField(
            key: _impactRevenuKey,
            label: S.of(context)!.naissanceRevenuAnnuel,
            value: _revenuImpact,
            formatValue: (v) => FamilyService.formatChf(v),
            onChanged: (v) {
              _revenuTouched = true;
              _revenuSeeded = false; // touched supersede le seed (donnée user).
              _revenuImpact = v;
              _afterImpactFactChanged();
            },
            min: 30000,
            max: 200000,
          ),
          const SizedBox(height: MintSpacing.lg),
          Row(
            key: _impactNbEnfantsKey,
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.naissanceNbEnfants,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ),
              _buildStepper(
                value: _nbEnfantsImpact,
                minVal: 1,
                maxVal: 5,
                onChanged: (v) {
                  _nbEnfantsImpactTouched = true;
                  _nbEnfantsImpact = v;
                  _afterImpactFactChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),
          MintAmountField(
            key: _impactFraisGardeKey,
            label: S.of(context)!.naissanceFraisGarde,
            value: _fraisGarde,
            formatValue: (v) => FamilyService.formatChf(v),
            onChanged: (v) {
              _fraisGardeTouched = true;
              _fraisGarde = v;
              _afterImpactFactChanged();
            },
            min: 0,
            max: 3000,
          ),
        ],
      ),
    );
  }

  /// Sortie « impact » — ne s'affiche que via le render-gate (gate complet +
  /// résultat non-null). Tous les chiffres dérivent de faits confirmés.
  List<Widget> _buildImpactResults(Map<String, dynamic> r) {
    final fiscalResult = r['fiscalResult'] as Map<String, dynamic>;
    final allocAnnuel = r['allocAnnuel'] as double;
    final economieFiscale = r['economieFiscale'] as double;
    final fraisGardeAnnuel = r['fraisGardeAnnuel'] as double;
    final netImpact = r['netImpact'] as double;
    final interruptionMois = r['interruptionMois'] as int;
    final lppPerteEstimee = r['lppPerteEstimee'] as double;

    final cantonNom = FamilyService.cantonNames[_cantonAlloc] ?? _cantonAlloc;
    final plural = _nbEnfantsImpact > 1 ? 's' : '';

    // Solde 3a RÉEL du profil (jamais estimé) : la clause 3a n'est rendue que
    // s'il existe un solde renseigné. Champ d'état ré-évalué à chaque notify
    // (pas de lecture live) → un clear le remet à 0 et retire la carte.
    final totalEpargne3a = _totalEpargne3a;

    return [
      // 1. Tax savings
      _buildImpactSection(
        icon: Icons.savings_outlined,
        title: S.of(context)!.naissanceTaxSavings,
        color: MintColors.success,
        children: [
          _buildResultRow(
            S.of(context)!.naissanceDeductionPerChild,
            '$_nbEnfantsImpact x ${FamilyService.formatChf(FamilyService.deductionParEnfant)}',
          ),
          const SizedBox(height: MintSpacing.xs + 2),
          _buildResultRow(
            S.of(context)!.naissanceDeductionChildcare,
            FamilyService.formatChf(
                fiscalResult['deductionGarde'] as double),
          ),
          const SizedBox(height: MintSpacing.xs + 2),
          _buildResultRow(
            S.of(context)!.naissanceEstimatedTaxSaving,
            FamilyService.formatChf(economieFiscale),
            valueKey: const Key('naissanceImpactFigure'),
          ),
        ],
      ),
      const SizedBox(height: MintSpacing.sm + 4),

      // 2. Allocations income
      _buildImpactSection(
        icon: Icons.child_care,
        title: S.of(context)!.naissanceAllowanceIncome,
        color: MintColors.success,
        children: [
          _buildResultRow(
            S.of(context)!.naissanceAnnualAllowances,
            FamilyService.formatChf(allocAnnuel),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.naissanceAllocContextNote(cantonNom, _nbEnfantsImpact, plural),
            style: MintTextStyles.labelMedium(color: MintColors.textMuted),
          ),
        ],
      ),
      const SizedBox(height: MintSpacing.sm + 4),

      // 3. Career gap warning
      _buildImpactSection(
        icon: Icons.warning_amber_outlined,
        title: S.of(context)!.naissanceCareerImpact,
        color: MintColors.warning,
        children: [
          _buildResultRow(
            S.of(context)!.naissanceEstimatedInterruption,
            S.of(context)!.naissanceMonths(interruptionMois),
          ),
          const SizedBox(height: MintSpacing.xs + 2),
          _buildResultRow(
            S.of(context)!.naissanceLppLossEstimated,
            '-${FamilyService.formatChf(lppPerteEstimee)}',
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.naissanceLppLessContributions,
            style: MintTextStyles.labelMedium(color: MintColors.textMuted).copyWith(height: 1.4),
          ),
        ],
      ),
      const SizedBox(height: MintSpacing.lg),

      // Net impact
      AnimatedContainer(
        key: const Key('naissanceImpactNet'),
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: netImpact >= 0
              ? MintColors.success.withValues(alpha: 0.08)
              : MintColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: netImpact >= 0
                ? MintColors.success.withValues(alpha: 0.3)
                : MintColors.error.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Text(
              S.of(context)!.naissanceNetAnnualImpact,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: MintSpacing.sm),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                '${netImpact >= 0 ? "+" : ""}${FamilyService.formatChf(netImpact)}',
                key: ValueKey(netImpact),
                style: MintTextStyles.displaySmall(
                  color: netImpact >= 0
                      ? MintColors.success
                      : MintColors.error,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              S.of(context)!.naissanceNetFormula,
              style: MintTextStyles.labelMedium(color: MintColors.textMuted),
            ),
          ],
        ),
      ),
      const SizedBox(height: MintSpacing.lg),

      // Waterfall — fiscal impact breakdown (child tax deductions)
      FiscalImpactWaterfall(
        steps: [
          WaterfallStep(
            label: S.of(context)!.naissanceWaterfallRevenu,
            amount: _revenuImpact,
            isTotal: true,
          ),
          WaterfallStep(
            label: S.of(context)!.naissanceTaxSavings,
            amount: economieFiscale,
          ),
          WaterfallStep(
            label: S.of(context)!.naissanceWaterfallAlloc,
            amount: allocAnnuel,
          ),
          WaterfallStep(
            label: S.of(context)!.naissanceWaterfallChildcare,
            amount: -fraisGardeAnnuel,
          ),
          WaterfallStep(
            label: S.of(context)!.naissanceWaterfallAfter,
            amount: _revenuImpact + netImpact,
            isTotal: true,
          ),
        ],
        totalSavings: economieFiscale + allocAnnuel,
      ),
      const SizedBox(height: MintSpacing.lg),

      _buildEducationalInsert(
        S.of(context)!.naissanceChildCostEducational,
      ),
      const SizedBox(height: MintSpacing.lg),

      // Caption : les deux widgets ci-dessous exposent des MOYENNES suisses
      // génériques (crèche, alimentation, budget 50/30/20) — pas la situation
      // de l'utilisateur. Étiquetés comme tels ; non gatés sur des faits perso.
      Padding(
        padding: const EdgeInsets.only(bottom: MintSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 14, color: MintColors.textMuted),
            const SizedBox(width: MintSpacing.xs + 2),
            Expanded(
              child: Text(
                S.of(context)!.naissanceCostGenericExampleLabel,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              ),
            ),
          ],
        ),
      ),

      BudgetBebeWidget(
        monthlyIncome: _revenuImpact / 12,
        costPerChild: 1200,
      ),
      const SizedBox(height: MintSpacing.lg),

      // ── P9-A : Cout du bonheur — decomposition mensuelle ──
      BabyCostWidget(
        yearsOfDependency: 25,
        items: [
          BabyCostItem(
            label: S.of(context)!.naissanceBabyCostCreche,
            emoji: '\u{1F3EB}',
            monthlyCost: 1800,
            note: S.of(context)!.naissanceBabyCostCrecheNote,
          ),
          BabyCostItem(
            label: S.of(context)!.naissanceBabyCostAlimentation,
            emoji: '\u{1F37C}',
            monthlyCost: 250,
          ),
          BabyCostItem(
            label: S.of(context)!.naissanceBabyCostVetements,
            emoji: '\u{1F455}',
            monthlyCost: 150,
          ),
          BabyCostItem(
            label: S.of(context)!.naissanceBabyCostLamal,
            emoji: '\u{1F3E5}',
            monthlyCost: 120,
            note: S.of(context)!.naissanceBabyCostLamalNote,
          ),
          BabyCostItem(
            label: S.of(context)!.naissanceBabyCostActivites,
            emoji: '\u26BD',
            monthlyCost: 100,
          ),
          BabyCostItem(
            label: S.of(context)!.naissanceBabyCostDivers,
            emoji: '\u{1F381}',
            monthlyCost: 80,
          ),
        ],
      ),
      const SizedBox(height: MintSpacing.lg),

      // ── P8-C : Clause 3a bénéficiaire (OPP3 art. 2) ──
      // Rendue UNIQUEMENT avec le solde 3a RÉEL du profil ; jamais un montant
      // inventé (aucune approximation « % du revenu »). Solde inconnu / nul →
      // widget omis (pas de 3a fabriqué dans la sortie impact).
      if (totalEpargne3a > 0) ...[
        Clause3aWidget(
          balance3a: totalEpargne3a,
          hasClause: false,
        ),
        const SizedBox(height: MintSpacing.lg),
      ],
    ];
  }

  Widget _buildImpactSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: MintSpacing.sm + 2),
              Text(
                title,
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          ...children,
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 4: CHECKLIST — Essential steps for new parents
  // ════════════════════════════════════════════════════════════

  Widget _buildTab4Checklist() {
    final items = _buildNaissanceChecklistItems();
    final nbChecked = _checkedItems.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Intro
        MintSurface(
          tone: MintSurfaceTone.bleu,
          padding: const EdgeInsets.all(MintSpacing.md + 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.child_care,
                  color: MintColors.info, size: 20),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: Text(
                  S.of(context)!.naissanceChecklistIntro,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MintSpacing.xl),

        // Progress bar
        MintSurface(
          tone: MintSurfaceTone.blanc,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.of(context)!.naissanceStepsCompleted(nbChecked, items.length),
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(nbChecked / items.length * 100).toStringAsFixed(0)}%',
                    style: MintTextStyles.titleMedium(
                      color: nbChecked == items.length
                          ? MintColors.success
                          : MintColors.primary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: MintSpacing.sm + 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: LinearProgressIndicator(
                    value: items.isNotEmpty ? nbChecked / items.length : 0,
                    backgroundColor: MintColors.porcelaine,
                    color: nbChecked == items.length
                        ? MintColors.success
                        : MintColors.primary,
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MintSpacing.xl),

        // Checklist items
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildChecklistItem(
            index: index,
            title: item['title'] as String,
            description: item['description'] as String,
          );
        }),
        const SizedBox(height: MintSpacing.lg),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildChecklistItem({
    required int index,
    required String title,
    required String description,
  }) {
    final isChecked = _checkedItems.contains(index);
    final isExpanded = _expandedItems[index] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isChecked
              ? MintColors.saugeClaire.withValues(alpha: 0.3)
              : MintColors.craie,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Semantics(
              label: title,
              button: true,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _expandedItems[index] = !isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(MintSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label: title,
                        button: true,
                        toggled: isChecked,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isChecked) {
                                _checkedItems.remove(index);
                              } else {
                                _checkedItems.add(index);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isChecked
                                  ? MintColors.success
                                  : MintColors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isChecked
                                    ? MintColors.success
                                    : MintColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: isChecked
                                ? const Icon(Icons.check,
                                    size: 15, color: MintColors.white)
                                : null,
                          ),
                        ),
                      ),
                    const SizedBox(width: MintSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        title,
                        style: MintTextStyles.bodyMedium(
                          color: isChecked
                              ? MintColors.textMuted
                              : MintColors.textPrimary,
                        ).copyWith(
                          fontWeight: FontWeight.w600,
                          decoration:
                              isChecked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: MintColors.textMuted,
                    ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                padding: const EdgeInsets.fromLTRB(52, 0, MintSpacing.md, MintSpacing.md),
                child: Text(
                  description,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  // ── Checklist Data ──────────────────────────────────────

  List<Map<String, String>> _buildNaissanceChecklistItems() {
    return [
      {'title': S.of(context)!.naissanceChecklistItem1Title, 'description': S.of(context)!.naissanceChecklistItem1Desc},
      {'title': S.of(context)!.naissanceChecklistItem2Title, 'description': S.of(context)!.naissanceChecklistItem2Desc},
      {'title': S.of(context)!.naissanceChecklistItem3Title, 'description': S.of(context)!.naissanceChecklistItem3Desc},
      {'title': S.of(context)!.naissanceChecklistItem4Title, 'description': S.of(context)!.naissanceChecklistItem4Desc},
      {'title': S.of(context)!.naissanceChecklistItem5Title, 'description': S.of(context)!.naissanceChecklistItem5Desc},
      {'title': S.of(context)!.naissanceChecklistItem6Title, 'description': S.of(context)!.naissanceChecklistItem6Desc},
      {'title': S.of(context)!.naissanceChecklistItem7Title, 'description': S.of(context)!.naissanceChecklistItem7Desc},
      {'title': S.of(context)!.naissanceChecklistItem8Title, 'description': S.of(context)!.naissanceChecklistItem8Desc},
      {'title': S.of(context)!.naissanceChecklistItem9Title, 'description': S.of(context)!.naissanceChecklistItem9Desc},
    ];
  }

  // ════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _buildStepper({
    required int value,
    required int minVal,
    required int maxVal,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Semantics(
          label: S.of(context)!.naissanceNbEnfants,
          button: true,
          child: IconButton(
            onPressed: value > minVal ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, size: 24),
            color: MintColors.primary,
          ),
        ),
        SizedBox(
          width: MintSpacing.xl,
          child: Text(
            '$value',
            style: MintTextStyles.titleLarge(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          label: S.of(context)!.naissanceNbEnfants,
          button: true,
          child: IconButton(
            onPressed: value < maxVal ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline, size: 24),
            color: MintColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, String value, {Key? valueKey}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        Text(
          value,
          key: valueKey,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildBarComparison({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
  }) {
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            Text(
              FamilyService.formatChf(value),
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.xs + 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: MintColors.appleSurface,
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildEducationalInsert(String text) {
    return MintSurface(
      tone: MintSurfaceTone.bleu,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, size: 18, color: MintColors.info),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.naissanceDidYouKnow,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  text,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return MintSurface(
      tone: MintSurfaceTone.peche,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.corailDiscret, size: 18),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.naissanceDisclaimer,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
