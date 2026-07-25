import 'dart:math';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/widgets/coach/clause_3a_widget.dart';
import 'package:mint_mobile/widgets/coach/survivor_pension_widget.dart';
import 'package:mint_mobile/widgets/visualizations/marriage_penalty_gauge.dart';
import 'package:mint_mobile/widgets/visualizations/regime_matrimonial_pie.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_signal_row.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/coach/couple_narrative_timeline.dart';

// ────────────────────────────────────────────────────────────
//  MARIAGE SCREEN — Category C (Life Event)
// ────────────────────────────────────────────────────────────
//
// Four-tab interactive screen:
//   Tab 1: "Impots"     — Marriage penalty/bonus calculator
//   Tab 2: "Regime"     — Matrimonial regime comparison
//   Tab 3: "Protection" — Survivor benefits (married vs not)
//   Tab 4: "Checklist"  — Essential steps before/after marriage
//
// Design System: MintTextStyles + MintSpacing tokens.
// AppBar: white standard (Life Event screen).
// Ne constitue pas un conseil fiscal ou juridique (LSFin).
//
// P2 « gate dur » : chaque sortie calculée (impôt du couple / partage du régime
// / histoire à deux / rente de survivant) est gatée derrière les faits de
// situation qu'ELLE consomme. Un fait n'est CONFIRMÉ que s'il vient des données
// réelles de l'utilisateur (provenance = `userProvidedFields` / conjoint réel,
// ou champ touché). Une valeur égale à un défaut fabriqué reste ASSUMED (jamais
// confirmée). Aucun chiffre ne se calcule sur un défaut inventé.
// Réf : .planning/decisions/2026-07-25-p2-simulator-result-gating.md
// ────────────────────────────────────────────────────────────

class MariageScreen extends StatefulWidget {
  const MariageScreen({super.key});

  @override
  State<MariageScreen> createState() => _MariageScreenState();
}

class _MariageScreenState extends State<MariageScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: Impôts inputs ──────────────────────────────
  double _revenu1 = 80000;
  double _revenu2 = 60000;
  String _canton = 'VD';
  int _nbEnfants = 0;
  Map<String, dynamic>? _fiscalResult;

  // ── Tab 2: Régime inputs ──────────────────────────────
  int _selectedRegime = 0; // 0=participation (défaut légal CC art. 181)
  double _patrimoine1 = 200000;
  double _patrimoine2 = 100000;

  // ── Tab 3: Protection ─────────────────────────────────
  double _renteLpp = 2500;
  // Solde 3a RÉEL du profil — champ d'état (jamais une lecture live en build,
  // jamais estimé depuis le revenu). Un clear le remet à 0 et retire la clause.
  double _totalEpargne3a = 0.0;

  // ── Tab 4: Checklist ──────────────────────────────────
  final Set<int> _checkedItems = {};
  final Map<int, bool> _expandedItems = {};

  // ── P2 « gate dur » : provenance PAR FAIT, ré-évaluée à chaque notify ──
  // Aucun latch `_prefilled` : `loadFromWizard` notifie plusieurs fois
  // (cache→frais→fusionné) ; un latch au 1er notify échouerait un champ dont la
  // donnée arrive au notify suivant. Chaque fait garde `_xSeeded`/`_xTouched`.
  CoachProfileProvider? _profileProvider;

  // Impôts : revenu1 (clé 'salary'), revenu2 (conjoint réel), canton (clé
  // 'canton'), nombre d'enfants (aucune clé → touch seul).
  bool _revenu1Touched = false;
  bool _revenu1Seeded = false; // provenance = userProvidedFields('salary').
  bool _revenu2Touched = false;
  bool _revenu2Seeded = false; // provenance = conjoint réel (salaire > 0).
  bool _cantonTouched = false;
  bool _cantonSeeded = false; // provenance = userProvidedFields('canton').
  bool _nbEnfantsTouched = false; // pas de clé → confirmable au touch seul.

  // Régime : patrimoines des deux conjoints (aucune clé → touch seul).
  bool _patrimoine1Touched = false;
  bool _patrimoine2Touched = false;

  // Protection : rente LPP mensuelle (clé 'avoirLpp' → rente via LppCalculator).
  bool _renteLppTouched = false;
  bool _renteLppSeeded = false;

  // Baselines pour l'annonce VoiceOver incomplet→complet (par sortie).
  bool _fiscalGateComplete = false;
  bool _regimeGateComplete = false;
  bool _timelineGateComplete = false;
  bool _protectionGateComplete = false;

  // Ancres pour scroll-to-first-missing quand une situation est incomplète.
  final _revenu1Key = GlobalKey();
  final _revenu2Key = GlobalKey();
  final _cantonKey = GlobalKey();
  final _nbEnfantsKey = GlobalKey();
  final _patrimoine1Key = GlobalKey();
  final _patrimoine2Key = GlobalKey();
  final _renteLppKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Gate dur : au 1er frame rien n'est confirmé → aucun résultat fabriqué.
    _recalculate();
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

  /// Seed provenance-gaté, rejoué à CHAQUE notify (aucun latch global). Un champ
  /// n'est amorcé — et donc confirmé — que si sa provenance est réelle : une clé
  /// `userProvidedFields`, un conjoint réel, jamais valeur≠défaut.
  void _seedFromProfile() {
    final profile = _profileProvider?.profile;
    var changed = false;

    if (profile == null) {
      // Profil absent : pas encore hydraté (le listener rejouera) ou effacé
      // (logout / reset) pendant que l'écran est monté. La provenance issue du
      // profil disparaît : les faits seededFromProfile retombent à non
      // confirmés (un fait TOUCHÉ reste une donnée user et survit). Tout
      // résultat qui reposait sur un fait seedé est invalidé.
      if (_revenu1Seeded) {
        _revenu1Seeded = false;
        changed = true;
      }
      if (_revenu2Seeded) {
        _revenu2Seeded = false;
        changed = true;
      }
      if (_cantonSeeded) {
        _cantonSeeded = false;
        changed = true;
      }
      if (_renteLppSeeded) {
        _renteLppSeeded = false;
        changed = true;
      }
      // Le solde 3a affiché (clause OPP3) est une donnée profil live : sur un
      // clear il doit disparaître, sinon un ancien solde CHF resterait rendu.
      if (_totalEpargne3a != 0.0) {
        _totalEpargne3a = 0.0;
        changed = true;
      }
      if (changed) {
        _recalculate();
        _refreshGateBaselines();
        if (mounted) setState(() {});
      }
      return;
    }

    // Solde 3a réel (clause bénéficiaire OPP3) — ré-évalué à chaque notify,
    // jamais estimé. Champ d'état (pas de lecture live en build) pour qu'un
    // clear le remette à 0 et retire la carte.
    {
      final e3a = profile.prevoyance.totalEpargne3a;
      if (e3a != _totalEpargne3a) {
        _totalEpargne3a = e3a;
        changed = true;
      }
    }

    // Revenu 1 — clé 'salary' ET revenu annuel DANS la plage [>0, 300000] du
    // champ. Hors plage → NON confirmé (un clamp fabriquerait un revenu ≠ vrai).
    if (!_revenu1Touched) {
      final annual = profile.salaireBrutMensuel * 12;
      final valid = profile.userProvidedFields.contains('salary') &&
          annual > 0 &&
          annual <= 300000.0;
      if (_revenu1Seeded != valid) {
        _revenu1Seeded = valid;
        changed = true;
      }
      if (valid && annual != _revenu1) {
        _revenu1 = annual;
        changed = true;
      }
    }

    // Revenu 2 — conjoint RÉEL (salaire > 0). Aucune clé : un conjoint réel ==
    // donnée user (comme `gender` pour naissance). Sans conjoint, le défaut
    // 60000 reste ASSUMED — une hypothèse what-if étiquetée, jamais un fait.
    if (!_revenu2Touched) {
      final conjoint = profile.conjoint;
      final cGross = conjoint?.salaireBrutMensuel;
      final hasConjoint = cGross != null && cGross > 0;
      final annual = hasConjoint ? cGross * conjoint!.nombreDeMois : 0.0;
      final valid = hasConjoint && annual > 0 && annual <= 300000.0;
      if (_revenu2Seeded != valid) {
        _revenu2Seeded = valid;
        changed = true;
      }
      if (valid && annual != _revenu2) {
        _revenu2 = annual;
        changed = true;
      }
    }

    // Canton — clé 'canton'.
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
      if (valid && c != _canton) {
        _canton = c;
        changed = true;
      }
    }

    // Nombre d'enfants — AUCUNE clé → confirmable au touch seul. On amorce la
    // VALEUR (confort) quand > 0 ; ne confirme jamais le fait.
    if (!_nbEnfantsTouched && profile.nombreEnfants > 0) {
      final v = profile.nombreEnfants.clamp(0, 5);
      if (v != _nbEnfants) {
        _nbEnfants = v;
        changed = true;
      }
    }

    // Rente LPP — clé 'avoirLpp' + avoir > 0 → rente mensuelle via la source
    // canonique (financial_core L1, LppCalculator ; réduction retraite anticipée
    // LPP art. 13 al. 2), DANS la plage [>0, 8000] du champ. Sans clé / hors
    // plage → NON confirmé (le défaut 2500 reste ASSUMED, jamais un clamp).
    if (!_renteLppTouched) {
      final avoir = profile.prevoyance.avoirLppTotal;
      final hasKey = profile.userProvidedFields.contains('avoirLpp');
      var rente = 0.0;
      if (hasKey && avoir != null && avoir > 0) {
        rente = LppCalculator.monthlyRenteFromAvoir(
          avoir: avoir,
          baseRate: profile.prevoyance.tauxConversion,
          retirementAge: profile.effectiveRetirementAge,
        ).roundToDouble();
      }
      final valid = rente > 0 && rente <= 8000.0;
      if (_renteLppSeeded != valid) {
        _renteLppSeeded = valid;
        changed = true;
      }
      if (valid && rente != _renteLpp) {
        _renteLpp = rente;
        changed = true;
      }
    }

    // Patrimoines : aucune source profil fiable par conjoint → jamais amorcés
    // (les défauts 200000/100000 restent ASSUMED jusqu'au touch de l'utilisateur).

    if (changed) {
      _recalculate();
      _refreshGateBaselines();
      if (mounted) setState(() {});
    }
  }

  // ── P2 provenance getters (live, non-latching) ──
  FactProvenance get _revenu1Provenance => _revenu1Touched
      ? FactProvenance.touched
      : (_revenu1Seeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  FactProvenance get _revenu2Provenance => _revenu2Touched
      ? FactProvenance.touched
      : (_revenu2Seeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  FactProvenance get _cantonProvenance => _cantonTouched
      ? FactProvenance.touched
      : (_cantonSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  FactProvenance get _nbEnfantsProvenance =>
      _nbEnfantsTouched ? FactProvenance.touched : FactProvenance.assumed;

  FactProvenance get _patrimoine1Provenance =>
      _patrimoine1Touched ? FactProvenance.touched : FactProvenance.assumed;

  FactProvenance get _patrimoine2Provenance =>
      _patrimoine2Touched ? FactProvenance.touched : FactProvenance.assumed;

  FactProvenance get _renteLppProvenance => _renteLppTouched
      ? FactProvenance.touched
      : (_renteLppSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  // ── Per-output gates (determinative facts only) ──
  // Impôt du couple : revenu1 + revenu2 + canton (barème) + nombre d'enfants.
  SituationGate _fiscalGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'revenu1',
          label: (c) => S.of(c)!.mariageGateFactRevenu1,
          why: (c) => S.of(c)!.mariageGateWhyRevenu1,
          provenance: _revenu1Provenance,
          onComplete: () => _scrollToKey(_revenu1Key),
        ),
        SituationFact(
          key: 'revenu2',
          label: (c) => S.of(c)!.mariageGateFactRevenu2,
          why: (c) => S.of(c)!.mariageGateWhyRevenu2,
          provenance: _revenu2Provenance,
          onComplete: () => _scrollToKey(_revenu2Key),
        ),
        SituationFact(
          key: 'canton',
          label: (c) => S.of(c)!.mariageGateFactCanton,
          why: (c) => S.of(c)!.mariageGateWhyCanton,
          provenance: _cantonProvenance,
          onComplete: () => _scrollToKey(_cantonKey),
        ),
        SituationFact(
          key: 'nbEnfants',
          label: (c) => S.of(c)!.mariageGateFactEnfants,
          why: (c) => S.of(c)!.mariageGateWhyEnfants,
          provenance: _nbEnfantsProvenance,
          onComplete: () => _scrollToKey(_nbEnfantsKey),
        ),
      ]);

  // Partage du régime : patrimoine de chaque conjoint (le partage se calcule
  // dessus). Le RÉGIME choisi a un défaut légal (participation) — surface
  // éditable documentée, PAS un fait gaté.
  SituationGate _regimeGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'patrimoine1',
          label: (c) => S.of(c)!.mariageGateFactPatrimoine1,
          why: (c) => S.of(c)!.mariageGateWhyPatrimoine1,
          provenance: _patrimoine1Provenance,
          onComplete: () => _scrollToKey(_patrimoine1Key),
        ),
        SituationFact(
          key: 'patrimoine2',
          label: (c) => S.of(c)!.mariageGateFactPatrimoine2,
          why: (c) => S.of(c)!.mariageGateWhyPatrimoine2,
          provenance: _patrimoine2Provenance,
          onComplete: () => _scrollToKey(_patrimoine2Key),
        ),
      ]);

  // Histoire à deux : la timeline affiche le revenu mensuel du couple — elle
  // consomme revenu1 + revenu2 (mêmes faits que l'impôt). Sur les défauts
  // 80000/60000 ce serait un revenu fabriqué → gatée sur ses deux revenus.
  SituationGate _timelineGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'revenu1',
          label: (c) => S.of(c)!.mariageGateFactRevenu1,
          why: (c) => S.of(c)!.mariageGateWhyRevenu1,
          provenance: _revenu1Provenance,
          onComplete: () => _scrollToKey(_revenu1Key),
        ),
        SituationFact(
          key: 'revenu2',
          label: (c) => S.of(c)!.mariageGateFactRevenu2,
          why: (c) => S.of(c)!.mariageGateWhyRevenu2,
          provenance: _revenu2Provenance,
          onComplete: () => _scrollToKey(_revenu2Key),
        ),
      ]);

  // Rente de survivant : rente LPP mensuelle du défunt (part LPP personnelle).
  SituationGate _protectionGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'renteLpp',
          label: (c) => S.of(c)!.mariageGateFactRenteLpp,
          why: (c) => S.of(c)!.mariageGateWhyRenteLpp,
          provenance: _renteLppProvenance,
          onComplete: () => _scrollToKey(_renteLppKey),
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

  /// Gate dur au compute : l'impôt du couple n'est calculé que si revenu1,
  /// revenu2, canton et nombre d'enfants sont confirmés. Sinon `null` → le slot
  /// résultat affiche la carte de situation (jamais un chiffre fabriqué).
  void _recalculate() {
    _fiscalResult = _fiscalGate(context).complete
        ? FamilyService.compareFiscalMariage(
            revenu1: _revenu1,
            revenu2: _revenu2,
            canton: _canton,
            nbEnfants: _nbEnfants,
          )
        : null;
  }

  void _refreshGateBaselines() {
    _fiscalGateComplete = _fiscalGate(context).complete;
    _regimeGateComplete = _regimeGate(context).complete;
    _timelineGateComplete = _timelineGate(context).complete;
    _protectionGateComplete = _protectionGate(context).complete;
  }

  void _announceComplete() {
    SemanticsService.sendAnnouncement(
      View.of(context),
      S.of(context)!.situationGateAnnounceComplete,
      Directionality.of(context),
    );
  }

  /// L'utilisateur a édité un fait de situation : recalcule l'impôt (stale-result
  /// invalidation), rebuild (régime / timeline / protection recalculés inline
  /// dans leur branche `complete`) et annonce le passage incomplet→complet d'une
  /// sortie pour VoiceOver (le scroll ≠ déplacement de focus).
  void _afterFactChanged() {
    final wasFiscal = _fiscalGateComplete;
    final wasRegime = _regimeGateComplete;
    final wasTimeline = _timelineGateComplete;
    final wasProtection = _protectionGateComplete;
    setState(_recalculate);
    _refreshGateBaselines();
    final newlyComplete = (_fiscalGateComplete && !wasFiscal) ||
        (_regimeGateComplete && !wasRegime) ||
        (_timelineGateComplete && !wasTimeline) ||
        (_protectionGateComplete && !wasProtection);
    if (newlyComplete) _announceComplete();
  }

  /// @visibleForTesting : entrées consommées par les services (preuve P2).
  @visibleForTesting
  double get debugRevenu1 => _revenu1;
  @visibleForTesting
  double get debugRevenu2 => _revenu2;
  @visibleForTesting
  String get debugCanton => _canton;
  @visibleForTesting
  int get debugNbEnfants => _nbEnfants;
  @visibleForTesting
  double get debugRenteLpp => _renteLpp;
  @visibleForTesting
  double get debugPatrimoine1 => _patrimoine1;
  @visibleForTesting
  double get debugPatrimoine2 => _patrimoine2;

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // ILLOG-02 : conteneur Semantics racine (motif rente_vs_capital) sinon le
    // pont AX iOS effondre toute la route en un seul nœud (« 1 element »).
    return Semantics(
      identifier: 'mariage_screen',
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
              _buildTab1Impots(),
              _buildTab2Regime(),
              _buildTab3Protection(),
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => safePop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding:
            const EdgeInsets.only(left: 56, bottom: 56, right: MintSpacing.md),
        title: Text(
          S.of(context)!.mariageTitle,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary),
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
        unselectedLabelStyle:
            MintTextStyles.bodySmall(color: MintColors.textMuted),
        tabs: [
          Tab(text: S.of(context)!.mariageTabImpots),
          Tab(text: S.of(context)!.mariageTabRegime),
          Tab(text: S.of(context)!.mariageTabProtection),
          Tab(text: S.of(context)!.naissanceTabChecklist),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: IMPOTS — Marriage fiscal impact
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Impots() {
    // Render-time gate : la comparaison fiscale ne s'affiche que si son résultat
    // existe ET que ses faits déterminants sont confirmés (données réelles).
    final fiscalReady = _fiscalResult != null && _fiscalGate(context).complete;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Narrative intro
        MintNarrativeCard(
          headline: S.of(context)!.narrativeMarriageHeadline,
          body: S.of(context)!.narrativeMarriageBody,
          tone: MintSurfaceTone.peche,
          badge: S.of(context)!.narrativeMarriageBadge,
        ),
        const SizedBox(height: MintSpacing.xl),

        // Result slot : hero comparaison OU carte de situation gatée.
        if (fiscalReady) ...[
          _buildFiscalHeroCard(),
          const SizedBox(height: MintSpacing.xl),
        ] else ...[
          SituationGateCard(
            title: S.of(context)!.donationGateTitle,
            gate: _fiscalGate(context),
          ),
          const SizedBox(height: MintSpacing.xl),
        ],

        _buildImpotsInputsCard(),
        const SizedBox(height: MintSpacing.xl),

        if (fiscalReady) ...[
          MarriagePenaltyGauge(
            taxSingles: (_fiscalResult!['totalCelibataires'] as double),
            taxMarried: (_fiscalResult!['totalMarie'] as double),
          ),
          const SizedBox(height: MintSpacing.xl),
          _buildDeductionsBreakdown(),
          const SizedBox(height: MintSpacing.xl),
        ],
        _buildEducationalInsert(
          S.of(context)!.mariageEducationalPenalty,
        ),
        const SizedBox(height: MintSpacing.xl),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildFiscalHeroCard() {
    final result = _fiscalResult!;
    final difference = result['difference'] as double;
    final isPenalite = result['isPenalite'] as bool;
    final totalMarie = result['totalMarie'] as double;

    return MintResultHeroCard(
      key: const Key('mariageFiscalHero'),
      eyebrow: S.of(context)!.mariageFiscalComparison,
      primaryValue:
          '${isPenalite ? "+" : "-"}${FamilyService.formatChf(difference.abs())}',
      primaryLabel: isPenalite
          ? S
              .of(context)!
              .mariagePenaltyAmount(FamilyService.formatChf(difference.abs()))
          : S
              .of(context)!
              .mariageBonusAmount(FamilyService.formatChf(difference.abs())),
      secondaryValue: FamilyService.formatChf(totalMarie),
      secondaryLabel: S.of(context)!.mariageMaries,
      narrative: isPenalite
          ? S.of(context)!.mariageEducationalPenalty
          : S.of(context)!.mariageEducationalPenalty,
      accentColor: isPenalite ? MintColors.error : MintColors.success,
      tone: MintSurfaceTone.porcelaine,
    );
  }

  Widget _buildImpotsInputsCard() {
    final sortedCodes = FamilyService.sortedCantonCodes;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintAmountField(
            key: _revenu1Key,
            label: S.of(context)!.mariageRevenu1,
            value: _revenu1,
            formatValue: (v) => FamilyService.formatChf(v),
            onChanged: (v) {
              // Touch = donnée user ; touched supersede le seed (immunisé au clear).
              _revenu1Touched = true;
              _revenu1Seeded = false;
              _revenu1 = v;
              _afterFactChanged();
            },
            min: 0,
            max: 300000,
          ),
          const SizedBox(height: MintSpacing.lg),
          KeyedSubtree(
            key: _revenu2Key,
            child: MintAmountField(
              key: const Key('mariage_revenu2_field'),
              label: S.of(context)!.mariageRevenu2,
              value: _revenu2,
              formatValue: (v) => FamilyService.formatChf(v),
              onChanged: (v) {
                _revenu2Touched = true;
                _revenu2Seeded = false;
                _revenu2 = v;
                _afterFactChanged();
              },
              min: 0,
              max: 300000,
            ),
          ),
          // D9 — étiquette hypothèse : sans conjoint réel connu (revenu2 non
          // confirmé), le Revenu 2 est une valeur de scénario modifiable, pas un
          // fait du profil. Provenance == assumed → hypothèse ; seedé (conjoint)
          // ou touché → fait de l'utilisateur, plus d'étiquette.
          if (_revenu2Provenance == FactProvenance.assumed) ...[
            const SizedBox(height: MintSpacing.xs),
            Row(
              key: const Key('mariage_revenu2_hypothesis_note'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.tune,
                  size: 14,
                  color: MintColors.textMuted,
                ),
                const SizedBox(width: MintSpacing.xs),
                Expanded(
                  child: Text(
                    S.of(context)!.mariageRevenu2Hypothesis,
                    style:
                        MintTextStyles.bodySmall(color: MintColors.textMuted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: MintSpacing.lg),

          // Canton dropdown
          Row(
            key: _cantonKey,
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.mariageCanton,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
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
                    value: _canton,
                    style: MintTextStyles.bodyMedium(
                        color: MintColors.textPrimary),
                    items: sortedCodes.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child:
                            Text('$code — ${FamilyService.cantonNames[code]}'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        // Touch = donnée user ; touched supersede le seed.
                        _cantonTouched = true;
                        _cantonSeeded = false;
                        _canton = v;
                        _afterFactChanged();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          // Children counter
          Row(
            key: _nbEnfantsKey,
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.mariageEnfants,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ),
              _buildStepper(
                value: _nbEnfants,
                minVal: 0,
                maxVal: 5,
                onChanged: (v) {
                  // Sélectionner (même 0) = fournir la donnée (touch seul, pas
                  // de clé userProvidedFields pour le nombre d'enfants).
                  _nbEnfantsTouched = true;
                  _nbEnfants = v;
                  _afterFactChanged();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // _buildHeroComparisonCard removed — replaced by MintResultHeroCard in _buildFiscalHeroCard

  Widget _buildDeductionsBreakdown() {
    final result = _fiscalResult!;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.mariageDeductions,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          MintSignalRow(
            label: S.of(context)!.mariageDeductionCouple,
            value: FamilyService.formatChf(result['deductionMarie'] as double),
          ),
          MintSignalRow(
            label: S.of(context)!.mariageDeductionInsurance,
            value:
                FamilyService.formatChf(result['deductionAssurance'] as double),
          ),
          if ((result['deductionDoubleRevenu'] as double) > 0)
            MintSignalRow(
              label: S.of(context)!.mariageDeductionDualIncome,
              value: FamilyService.formatChf(
                  result['deductionDoubleRevenu'] as double),
            ),
          if ((result['deductionEnfants'] as double) > 0)
            MintSignalRow(
              label: S.of(context)!.mariageDeductionChildren,
              value:
                  FamilyService.formatChf(result['deductionEnfants'] as double),
            ),
          Divider(color: MintColors.border.withValues(alpha: 0.3)),
          MintSignalRow(
            label: S.of(context)!.mariageTotalDeductions,
            value: FamilyService.formatChf(result['totalDeductions'] as double),
            valueColor: MintColors.primary,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: REGIME — Matrimonial regime comparison
  // ════════════════════════════════════════════════════════════

  RegimeMatrimonial _regimeFromIndex(int index) {
    switch (index) {
      case 1:
        return RegimeMatrimonial.separationBiens;
      case 2:
        return RegimeMatrimonial.communauteBiens;
      default:
        return RegimeMatrimonial.participationAcquets;
    }
  }

  Widget _buildTab2Regime() {
    // Le partage (pie + chiffre-choc) se calcule sur les patrimoines ; la
    // timeline sur les revenus. Chaque sortie gate sur SES faits déterminants.
    final regimeReady = _regimeGate(context).complete;
    final timelineReady = _timelineGate(context).complete;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Regime cards
        Row(
          children: [
            const Icon(Icons.gavel, size: 16, color: MintColors.textMuted),
            const SizedBox(width: MintSpacing.sm),
            Text(
              S.of(context)!.mariageRegimeMatrimonial,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildRegimeCard(
          index: 0,
          icon: Icons.handshake_outlined,
          title: S.of(context)!.mariageParticipation,
          subtitle: S.of(context)!.mariageParticipationSub,
          description: S.of(context)!.mariageParticipationDesc,
        ),
        const SizedBox(height: MintSpacing.sm + 2),
        _buildRegimeCard(
          index: 1,
          icon: Icons.lock_outline,
          title: S.of(context)!.mariageSeparation,
          subtitle: S.of(context)!.mariageSeparationSub,
          description: S.of(context)!.mariageSeparationDesc,
        ),
        const SizedBox(height: MintSpacing.sm + 2),
        _buildRegimeCard(
          index: 2,
          icon: Icons.group_outlined,
          title: S.of(context)!.mariageCommunaute,
          subtitle: S.of(context)!.mariageCommunauteSub,
          description: S.of(context)!.mariageCommunauteDesc,
        ),
        const SizedBox(height: MintSpacing.lg),

        // Patrimoine sliders (inputs) — toujours visibles, ancres scroll.
        MintSurface(
          tone: MintSurfaceTone.blanc,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MintAmountField(
                key: _patrimoine1Key,
                label: S.of(context)!.mariagePatrimoine1,
                value: _patrimoine1,
                formatValue: (v) => FamilyService.formatChf(v),
                onChanged: (v) {
                  _patrimoine1Touched = true;
                  _patrimoine1 = v;
                  _afterFactChanged();
                },
                min: 0,
                max: 1000000,
              ),
              const SizedBox(height: MintSpacing.lg),
              MintAmountField(
                key: _patrimoine2Key,
                label: S.of(context)!.mariagePatrimoine2,
                value: _patrimoine2,
                formatValue: (v) => FamilyService.formatChf(v),
                onChanged: (v) {
                  _patrimoine2Touched = true;
                  _patrimoine2 = v;
                  _afterFactChanged();
                },
                min: 0,
                max: 1000000,
              ),
            ],
          ),
        ),
        const SizedBox(height: MintSpacing.xl),

        // Partage du régime (pie + chiffre-choc) OU carte de situation gatée :
        // sur les défauts 200000/100000 le partage serait fabriqué.
        if (regimeReady) ...[
          RegimeMatrimonialPie(
            assetsPersonne1: _patrimoine1,
            assetsPersonne2: _patrimoine2,
            regime: _regimeFromIndex(_selectedRegime),
            onRegimeChanged: (r) => setState(() => _selectedRegime = r.index),
          ),
          const SizedBox(height: MintSpacing.lg),
          _buildPremierEclairageRegime(),
          const SizedBox(height: MintSpacing.lg),
        ] else ...[
          SituationGateCard(
            title: S.of(context)!.donationGateTitle,
            gate: _regimeGate(context),
          ),
          const SizedBox(height: MintSpacing.lg),
        ],

        // Histoire à deux (revenu mensuel du couple) OU carte gatée : sur les
        // défauts 80000/60000 le revenu affiché serait fabriqué.
        if (timelineReady) ...[
          CoupleNarrativeTimeline(
            partner1Name: S.of(context)!.mariageTimelinePartner1,
            partner2Name: S.of(context)!.mariageTimelinePartner2,
            coachTip: S.of(context)!.mariageTimelineCoachTip,
            acts: [
              CoupleAct(
                number: 1,
                title: S.of(context)!.mariageTimelineAct1Title,
                period: S.of(context)!.mariageTimelineAct1Period,
                monthlyIncome: (_revenu1 + _revenu2) / 12,
                insight: S.of(context)!.mariageTimelineAct1Insight,
              ),
              CoupleAct(
                number: 2,
                title: S.of(context)!.mariageTimelineAct2Title,
                period: S.of(context)!.mariageTimelineAct2Period,
                monthlyIncome: (_revenu1 + _revenu2) / 12 * 1.15,
                deltaPercent: 15,
                insight: S.of(context)!.mariageTimelineAct2Insight,
              ),
              CoupleAct(
                number: 3,
                title: S.of(context)!.mariageTimelineAct3Title,
                period: S.of(context)!.mariageTimelineAct3Period,
                monthlyIncome: (_revenu1 + _revenu2) / 12 * 0.65,
                deltaPercent: -35,
                isDip: true,
                insight: S.of(context)!.mariageTimelineAct3Insight,
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),
        ] else ...[
          SituationGateCard(
            title: S.of(context)!.donationGateTitle,
            gate: _timelineGate(context),
          ),
          const SizedBox(height: MintSpacing.lg),
        ],

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildRegimeCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
  }) {
    final isSelected = _selectedRegime == index;

    return Semantics(
      label: title,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedRegime = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(MintSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? MintColors.primary.withValues(alpha: 0.04)
                : MintColors.craie,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? MintColors.primary.withValues(alpha: 0.1)
                      : MintColors.porcelaine,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? MintColors.primary
                      : MintColors.textSecondary,
                ),
              ),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MintTextStyles.bodyMedium(
                              color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      style: MintTextStyles.labelMedium(
                          color: MintColors.textMuted),
                    ),
                    const SizedBox(height: MintSpacing.xs + 2),
                    Text(
                      description,
                      style: MintTextStyles.bodySmall(
                              color: MintColors.textSecondary)
                          .copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: MintColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check,
                      size: 14, color: MintColors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremierEclairageRegime() {
    final total = _patrimoine1 + _patrimoine2;
    if (total <= 0) return const SizedBox.shrink();

    double acquetsPartage;
    if (_selectedRegime == 0) {
      // Participation: 50/50 of total
      acquetsPartage = (total / 2 - min(_patrimoine1, _patrimoine2)).abs();
    } else if (_selectedRegime == 2) {
      acquetsPartage = (total / 2 - min(_patrimoine1, _patrimoine2)).abs();
    } else {
      return const SizedBox.shrink();
    }

    if (acquetsPartage <= 0) return const SizedBox.shrink();

    return MintResultHeroCard(
      eyebrow: S.of(context)!.mariageRegimeMatrimonial,
      primaryValue: FamilyService.formatChf(acquetsPartage),
      primaryLabel: _selectedRegime == 0
          ? S.of(context)!.mariagePremierEclairageDefault
          : S.of(context)!.mariagePremierEclairageCommunaute,
      narrative: _selectedRegime == 0
          ? S.of(context)!.mariagePremierEclairageDefault
          : S.of(context)!.mariagePremierEclairageCommunaute,
      tone: MintSurfaceTone.peche,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: PROTECTION — Survivor benefits
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Protection() {
    // La rente de survivant (hero + cartes + widget) dérive de la rente LPP
    // mensuelle du défunt. Sur le défaut 2500 ce serait une rente fabriquée →
    // gate sur `renteLpp` (clé 'avoirLpp' ou champ touché).
    final protectionReady = _protectionGate(context).complete;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // LPP slider (input) — toujours visible, ancre scroll.
        MintSurface(
          key: _renteLppKey,
          tone: MintSurfaceTone.blanc,
          child: MintAmountField(
            label: S.of(context)!.mariageLppRenteLabel,
            value: _renteLpp,
            formatValue: (v) => FamilyService.formatChf(v),
            onChanged: (v) {
              _renteLppTouched = true;
              _renteLppSeeded = false;
              _renteLpp = v;
              _afterFactChanged();
            },
            min: 0,
            max: 8000,
          ),
        ),
        const SizedBox(height: MintSpacing.xl),

        // Sortie survivant OU carte de situation gatée.
        if (protectionReady) ...[
          ..._buildProtectionResults(),
        ] else ...[
          SituationGateCard(
            title: S.of(context)!.donationGateTitle,
            gate: _protectionGate(context),
          ),
          const SizedBox(height: MintSpacing.xl),
        ],

        // Comparaison mariés vs concubins (éducatif, aucun CHF) — toujours.
        _buildProtectionComparison(),
        const SizedBox(height: MintSpacing.lg),

        // Checklist protections (éducatif) — toujours.
        _buildProtectionChecklist(),
        const SizedBox(height: MintSpacing.lg),

        // Clause 3a — solde RÉEL du profil UNIQUEMENT (jamais estimé « % du
        // revenu »). Solde inconnu / nul → widget omis (pas de 3a fabriqué).
        if (_totalEpargne3a > 0) ...[
          Clause3aWidget(balance3a: _totalEpargne3a),
          const SizedBox(height: MintSpacing.lg),
        ],

        _buildDisclaimer(),
      ],
    );
  }

  /// Sortie « rente de survivant » — rendue seulement via le render-gate
  /// (`protectionReady`). La part AVS est la rente maximale légale (constante
  /// documentée, cf. libellé « 80 % de la rente maximale ») ; la part LPP dérive
  /// de la rente LPP confirmée du défunt.
  List<Widget> _buildProtectionResults() {
    const avsSurvivor = avsRenteMaxMensuelle * FamilyService.avsSurvivorFactor;
    final lppSurvivor = _renteLpp * FamilyService.lppSurvivorFactor;
    final totalSurvivor = avsSurvivor + lppSurvivor;

    return [
      MintResultHeroCard(
        key: const Key('mariageSurvivorHero'),
        eyebrow: S.of(context)!.mariageTabProtection,
        primaryValue: '${FamilyService.formatChf(totalSurvivor)}/mois',
        primaryLabel: S.of(context)!.mariageSurvivorMonthly,
        narrative: S.of(context)!.mariageProtectionIntro,
        accentColor: MintColors.success,
        tone: MintSurfaceTone.sauge,
      ),
      const SizedBox(height: MintSpacing.xl),
      _buildSurvivorCard(
        icon: Icons.account_balance_outlined,
        label: S.of(context)!.mariageAvsSurvivor,
        subtitle: S.of(context)!.mariageAvsSurvivorSub,
        value: avsSurvivor,
        footnote: S.of(context)!.mariageAvsSurvivorFootnote,
      ),
      const SizedBox(height: MintSpacing.sm + 4),
      _buildSurvivorCard(
        icon: Icons.savings_outlined,
        label: S.of(context)!.mariageLppSurvivor,
        subtitle: S.of(context)!.mariageLppSurvivorSub,
        value: lppSurvivor,
        footnote: S.of(context)!.mariageLppSurvivorFootnote,
      ),
      const SizedBox(height: MintSpacing.xl),
      SurvivorPensionWidget(
        partnerAvsRente: avsRenteMaxMensuelle,
        partnerLppMonthly: _renteLpp,
        isConcubin: false,
      ),
      const SizedBox(height: MintSpacing.lg),
    ];
  }

  Widget _buildSurvivorCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required double value,
    required String footnote,
  }) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MintColors.saugeClaire.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: MintColors.success),
          ),
          const SizedBox(width: MintSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style:
                      MintTextStyles.labelMedium(color: MintColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  footnote,
                  style: MintTextStyles.labelSmall(color: MintColors.textMuted)
                      .copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          Text(
            '${FamilyService.formatChf(value)}/mois',
            style: MintTextStyles.bodyMedium(color: MintColors.success)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionComparison() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare, size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.mariageVsConcubin,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          _buildComparisonRow(
              S.of(context)!.mariageRenteAvsSurvivor, true, false),
          _buildComparisonRow(
              S.of(context)!.mariageRenteLppSurvivor, true, false),
          _buildComparisonRow(
              S.of(context)!.mariageHeritageExonere, true, false),
          _buildComparisonRow(
              S.of(context)!.mariagePensionAlimentaire, true, false),
          const SizedBox(height: MintSpacing.sm),
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber,
                    size: 18, color: MintColors.error),
                const SizedBox(width: MintSpacing.sm + 2),
                Expanded(
                  child: Text(
                    S.of(context)!.mariageConcubinWarning,
                    style:
                        MintTextStyles.bodySmall(color: MintColors.textPrimary)
                            .copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, bool married, bool concubin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                married ? Icons.check_circle : Icons.cancel,
                size: 20,
                color: married ? MintColors.success : MintColors.error,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                concubin ? Icons.check_circle : Icons.cancel,
                size: 20,
                color: concubin ? MintColors.success : MintColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionChecklist() {
    final items = [
      S.of(context)!.mariageProtectionItem1,
      S.of(context)!.mariageProtectionItem2,
      S.of(context)!.mariageProtectionItem3,
      S.of(context)!.mariageProtectionItem4,
      S.of(context)!.mariageProtectionItem5,
    ];

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.mariageProtectionsEssentielles,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: const BoxDecoration(
                        color: MintColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: MintSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        item,
                        style: MintTextStyles.bodyMedium(
                                color: MintColors.textPrimary)
                            .copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 4: CHECKLIST — Essential steps before/after marriage
  // ════════════════════════════════════════════════════════════

  Widget _buildTab4Checklist() {
    final items = _buildMariageChecklistItems();
    final nbChecked = _checkedItems.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Intro
        MintSurface(
          tone: MintSurfaceTone.bleu,
          padding: const EdgeInsets.all(MintSpacing.md + 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.checklist_rtl, color: MintColors.info, size: 20),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: Text(
                  S.of(context)!.mariageChecklistIntro,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary)
                          .copyWith(height: 1.5),
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
                    S
                        .of(context)!
                        .mariageChecklistProgress(nbChecked, items.length),
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w600),
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
                padding: const EdgeInsets.fromLTRB(
                    52, 0, MintSpacing.md, MintSpacing.md),
                child: Text(
                  description,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary)
                          .copyWith(height: 1.5),
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

  // Checklist data is built dynamically using i18n keys — see _buildMariageChecklistItems()
  List<Map<String, String>> _buildMariageChecklistItems() {
    return [
      {
        'title': S.of(context)!.mariageChecklistItem1Title,
        'description': S.of(context)!.mariageChecklistItem1Desc
      },
      {
        'title': S.of(context)!.mariageChecklistItem2Title,
        'description': S.of(context)!.mariageChecklistItem2Desc
      },
      {
        'title': S.of(context)!.mariageChecklistItem3Title,
        'description': S.of(context)!.mariageChecklistItem3Desc
      },
      {
        'title': S.of(context)!.mariageChecklistItem4Title,
        'description': S.of(context)!.mariageChecklistItem4Desc
      },
      {
        'title': S.of(context)!.mariageChecklistItem5Title,
        'description': S.of(context)!.mariageChecklistItem5Desc
      },
      {
        'title': S.of(context)!.mariageChecklistItem6Title,
        'description': S.of(context)!.mariageChecklistItem6Desc
      },
      {
        'title': S.of(context)!.mariageChecklistItem7Title,
        'description': S.of(context)!.mariageChecklistItem7Desc
      },
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
          label: S.of(context)!.mariageEnfants,
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
            style: MintTextStyles.titleLarge(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          label: S.of(context)!.mariageEnfants,
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
                  S.of(context)!.lifeEventDidYouKnow,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  text,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary)
                          .copyWith(height: 1.5),
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
          const Icon(Icons.info_outline,
              color: MintColors.corailDiscret, size: 18),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.mariageDisclaimer,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted)
                  .copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
