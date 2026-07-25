import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/expat_service.dart';
import 'package:mint_mobile/services/fiscal_service.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/couple/conjoint_missing_hint.dart';
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/coach/top_cantons_widget.dart';
import 'package:mint_mobile/widgets/coach/avs_gap_widget.dart';
import 'package:mint_mobile/widgets/coach/expat_countdown_widget.dart';
import 'package:mint_mobile/widgets/coach/expat_rights_loss_widget.dart';
import 'package:mint_mobile/services/financial_core/income_tax_model_v2.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';

// ────────────────────────────────────────────────────────────
//  EXPAT SCREEN — Sprint S23 / Expatriation + Frontaliers
// ────────────────────────────────────────────────────────────
//
// Design System: Category C — Life Event.
// Three-tab interactive screen for expatriation planning:
//   Tab 1: "Forfait"  — Lump-sum taxation simulator
//   Tab 2: "Départ"   — Departure planning checklist
//   Tab 3: "AVS"      — Pension gap estimator
//
// Ne constitue pas un conseil fiscal ou juridique (LSFin).
// ────────────────────────────────────────────────────────────

class ExpatScreen extends StatefulWidget {
  const ExpatScreen({super.key});

  @override
  State<ExpatScreen> createState() => _ExpatScreenState();
}

class _ExpatScreenState extends State<ExpatScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  CoachProfileProvider? _profileProvider;

  // ── Tab 1: Forfait inputs (TOUCH-ONLY — faits mondiaux, aucune source profil.
  //    Les défauts 1M / 5M sont des fabrications : gate dur tant que non touchés) ──
  String _forfaitCanton = 'VD';
  double _livingExpenses = 1000000;
  double _actualIncome = 5000000;
  Map<String, dynamic>? _forfaitResult;
  bool _forfaitCantonTouched = false;
  bool _livingExpensesTouched = false;
  bool _actualIncomeTouched = false;

  // ── Tab 1: Top cantons — classement personnalisé sur le revenu RÉEL du profil
  //    (jamais le défaut forfait 5M). Faits profil, aucun contrôle in-screen →
  //    onComplete null. Snapshots re-évalués à chaque notify (pas de lecture
  //    live en build). ──
  bool _topCantonsHasChildren = false;
  List<CantonRanking> _topCantonsResult = const [];
  double _topIncome = 0;
  bool _topIncomeSeeded = false;
  String _topAnchor = 'VD';
  bool _topAnchorSeeded = false;
  bool _topMarried = false;
  int _topProfileEnfants = 0;
  bool _topMissingConjointIncome = false;

  // ── Tab 2: Depart inputs ──────────────────────────────
  DateTime _departureDate = DateTime.now().add(const Duration(days: 180));
  String _departCanton = 'VD';
  bool _departCantonTouched = false; // amorçage de confort (non gaté).
  double _pillar3aBalance = 80000;
  double _lppBalance = 250000;
  bool _pillar3aTouched = false;
  bool _pillar3aSeeded = false; // provenance = prevoyance.totalEpargne3a > 0.
  bool _lppTouched = false;
  bool _lppSeeded = false; // provenance = userProvidedFields('avoirLpp').
  Map<String, dynamic>? _departResult;
  final Set<String> _completedChecklist = {};

  // ── Tab 3: AVS inputs (TOUCH-ONLY — pas de source profil pour les années.
  //    Les défauts 20 / 10 sont des fabrications) ──
  int _yearsInCh = 20;
  int _yearsAbroad = 10;
  bool _yearsInChTouched = false;
  bool _yearsAbroadTouched = false;
  Map<String, dynamic>? _avsResult;
  // Projection AvsGapWidget : âge RÉEL du profil (clé 'age'), pas le défaut 40.
  int? _profileAge;
  bool _ageSeeded = false;

  // ── Gate baselines (annonce VoiceOver au passage incomplet→complet) ──
  bool _forfaitGateComplete = false;
  bool _topCantonsGateComplete = false;
  bool _departGateComplete = false;
  bool _avsGateComplete = false;
  bool _avsProjectionGateComplete = false;

  // ── Scroll anchors (scroll-to-first-missing) ──
  final _forfaitCantonKey = GlobalKey();
  final _livingExpensesKey = GlobalKey();
  final _actualIncomeKey = GlobalKey();
  final _pillar3aKey = GlobalKey();
  final _lppKey = GlobalKey();
  final _yearsInChKey = GlobalKey();
  final _yearsAbroadKey = GlobalKey();

  // ── Debug getters (tests anti-façade : lire l'état confirmé, jamais un bool
  //    interne comme vérité — les tests assertent sur le CHF rendu) ──
  double get debugLivingExpenses => _livingExpenses;
  double get debugActualIncome => _actualIncome;
  double get debugPillar3a => _pillar3aBalance;
  double get debugLpp => _lppBalance;
  int get debugYearsInCh => _yearsInCh;
  int get debugYearsAbroad => _yearsAbroad;
  String get debugTopAnchor => _topAnchor;
  double get debugTopIncome => _topIncome;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Gate dur : au 1er frame rien n'est confirmé → aucun chiffre fabriqué.
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

  /// Classement REEL des cantons (audit T05-F41, MINT_nosync-9f8) : ecart =
  /// charge fiscale du canton d'ancrage - charge du candidat, via
  /// FiscalService (modele simplifie MINT, 26 cantons). Exclut l'ancrage, ne
  /// garde que les ecarts positifs, max 5 — jamais de rangs rembourres.
  /// Calcule au build (<1 ms pour 26 cantons) : reste coherent avec
  /// l'hydratation asynchrone du profil (review Codex — un state fige en
  /// initState restait rassis quand le profil arrivait apres).
  List<CantonRanking> _computeTopCantons({
    required String anchorCanton,
    required double income,
    required String etatCivil,
    required int enfants,
  }) {
    final chargeActuelle = (FiscalService.estimateTax(
          revenuBrut: income,
          canton: anchorCanton,
          etatCivil: etatCivil,
          nombreEnfants: enfants,
        )['chargeTotale'] as double?) ??
        0;

    final all = FiscalService.compareAllCantons(
      revenuBrut: income,
      etatCivil: etatCivil,
      nombreEnfants: enfants,
    );
    final candidates = <CantonRanking>[];
    for (final m in all) {
      final code = m['canton'] as String;
      if (code == anchorCanton) continue;
      final saving = chargeActuelle - ((m['chargeTotale'] as double?) ?? 0);
      if (saving <= 0) continue;
      candidates.add(CantonRanking(
        rank: candidates.length + 1,
        canton: (m['cantonNom'] as String?) ?? code,
        shortCode: code,
        annualTaxSaving: saving.roundToDouble(),
      ));
      if (candidates.length == 5) break;
    }
    return candidates;
  }

  // ════════════════════════════════════════════════════════════
  //  SEED — provenance re-évaluée à CHAQUE notify (aucun latch global)
  // ════════════════════════════════════════════════════════════

  /// Un champ n'est amorcé — et donc confirmé — que si sa provenance est réelle :
  /// une clé `userProvidedFields`, un solde profil > 0, jamais valeur≠défaut.
  void _seedFromProfile() {
    final profile = _profileProvider?.profile;
    var changed = false;

    if (profile == null) {
      // Profil absent : pas encore hydraté (le listener rejouera) ou effacé
      // (logout / reset). Toute provenance issue du profil disparaît : les faits
      // seededFromProfile retombent non confirmés (un fait TOUCHÉ reste une
      // donnée user et survit). Tout résultat qui reposait sur un fait seedé est
      // invalidé — aucun chiffre ne survit à sa source.
      changed = _resetSeededFlags();
      if (changed) {
        _recalculateAll();
        _refreshGateBaselines();
        if (mounted) setState(() {});
      }
      return;
    }

    final provided = profile.userProvidedFields;

    // ── Départ — LPP : clé 'avoirLpp' + valeur DANS la plage du contrôle
    //    [0, 1000000]. Hors plage → NON confirmé (un clamp fabriquerait une
    //    valeur ≠ la vraie, ex. 2M affiché 1M). Le défaut 250000 reste ASSUMED.
    if (!_lppTouched) {
      final v = profile.prevoyance.avoirLppTotal ?? 0;
      final valid = provided.contains('avoirLpp') && v > 0 && v <= 1000000;
      if (_lppSeeded != valid) {
        _lppSeeded = valid;
        changed = true;
      }
      if (valid && v != _lppBalance) {
        _lppBalance = v;
        changed = true;
      }
    }

    // ── Départ — 3a : solde RÉEL > 0 DANS la plage [0, 500000]. Aucune clé
    //    `userProvidedFields` → un solde profil > 0 est une donnée user (motif
    //    conjoint/gender). Le défaut 80000 reste ASSUMED jusqu'à seed/touch.
    if (!_pillar3aTouched) {
      final v = profile.prevoyance.totalEpargne3a;
      final valid = v > 0 && v <= 500000;
      if (_pillar3aSeeded != valid) {
        _pillar3aSeeded = valid;
        changed = true;
      }
      if (valid && v != _pillar3aBalance) {
        _pillar3aBalance = v;
        changed = true;
      }
    }

    // ── Départ — canton courant : amorçage de CONFORT (aucun CHF n'en dépend →
    //    non gaté ; sert au libellé de la checklist). ──
    if (!_departCantonTouched) {
      final c = profile.canton;
      if (provided.contains('canton') &&
          ExpatService.cantonNames.containsKey(c) &&
          c != _departCanton) {
        _departCanton = c;
        changed = true;
      }
    }

    // ── Top cantons — revenu RÉEL (clé 'salary' + valeur > 0) et canton
    //    d'ancrage RÉEL (clé 'canton' + code connu du modèle). Le classement CHF
    //    est personnalisé (barème sur le revenu) → sans ces faits il serait
    //    fabriqué (défaut forfait 5M / ancrage VD). Marié (clé 'civilStatus')
    //    → revenu du couple. ──
    final married =
        provided.contains('civilStatus') && profile.etatCivil.name == 'marie';
    final income =
        married ? profile.revenuBrutAnnuelCouple : profile.revenuBrutAnnuel;
    final incomeSeeded = provided.contains('salary') && income > 0;
    final anchorValid = provided.contains('canton') &&
        cantonalCommunalTaxChf.containsKey(profile.canton);
    final anchor = anchorValid ? profile.canton : _forfaitCanton;
    final missingConj = married && profile.isMissingConjointIncome;
    if (_topIncomeSeeded != incomeSeeded) {
      _topIncomeSeeded = incomeSeeded;
      changed = true;
    }
    if (incomeSeeded && income != _topIncome) {
      _topIncome = income;
      changed = true;
    }
    if (_topAnchorSeeded != anchorValid) {
      _topAnchorSeeded = anchorValid;
      changed = true;
    }
    if (anchor != _topAnchor) {
      _topAnchor = anchor;
      changed = true;
    }
    if (_topMarried != married) {
      _topMarried = married;
      changed = true;
    }
    if (_topProfileEnfants != (profile.nombreEnfants)) {
      _topProfileEnfants = profile.nombreEnfants;
      changed = true;
    }
    if (_topMissingConjointIncome != missingConj) {
      _topMissingConjointIncome = missingConj;
      changed = true;
    }

    // ── AVS projection — âge RÉEL (clé 'age' + ageOrNull non-null), pas le
    //    défaut 40. Champ d'état ré-évalué à chaque notify (un clear le remet à
    //    null → la projection AvsGapWidget se re-gate). ──
    final ageSeeded = provided.contains('age') && profile.ageOrNull != null;
    final age = profile.ageOrNull;
    if (_ageSeeded != ageSeeded) {
      _ageSeeded = ageSeeded;
      changed = true;
    }
    if (_profileAge != age) {
      _profileAge = age;
      changed = true;
    }

    if (changed) {
      _recalculateAll();
      _refreshGateBaselines();
      if (mounted) setState(() {});
    }
  }

  /// Remet à zéro toute provenance issue du profil (clear/logout). Les faits
  /// TOUCHÉS ne sont pas des flags seeded → ils survivent. Retourne true si un
  /// flag/snapshot a changé.
  bool _resetSeededFlags() {
    var changed = false;
    if (_lppSeeded) {
      _lppSeeded = false;
      changed = true;
    }
    if (_pillar3aSeeded) {
      _pillar3aSeeded = false;
      changed = true;
    }
    if (_topIncomeSeeded) {
      _topIncomeSeeded = false;
      changed = true;
    }
    if (_topAnchorSeeded) {
      _topAnchorSeeded = false;
      changed = true;
    }
    if (_topMarried) {
      _topMarried = false;
      changed = true;
    }
    if (_topProfileEnfants != 0) {
      _topProfileEnfants = 0;
      changed = true;
    }
    if (_topMissingConjointIncome) {
      _topMissingConjointIncome = false;
      changed = true;
    }
    if (_ageSeeded) {
      _ageSeeded = false;
      changed = true;
    }
    if (_profileAge != null) {
      _profileAge = null;
      changed = true;
    }
    return changed;
  }

  // ════════════════════════════════════════════════════════════
  //  PROVENANCE — touched supersede seed ; assumed ne gate jamais ouvert
  // ════════════════════════════════════════════════════════════

  FactProvenance get _forfaitCantonProvenance =>
      _forfaitCantonTouched ? FactProvenance.touched : FactProvenance.assumed;
  FactProvenance get _livingExpensesProvenance =>
      _livingExpensesTouched ? FactProvenance.touched : FactProvenance.assumed;
  FactProvenance get _actualIncomeProvenance =>
      _actualIncomeTouched ? FactProvenance.touched : FactProvenance.assumed;

  FactProvenance get _topIncomeProvenance => _topIncomeSeeded
      ? FactProvenance.seededFromProfile
      : FactProvenance.assumed;
  FactProvenance get _topAnchorProvenance => _topAnchorSeeded
      ? FactProvenance.seededFromProfile
      : FactProvenance.assumed;

  FactProvenance get _pillar3aProvenance => _pillar3aTouched
      ? FactProvenance.touched
      : (_pillar3aSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);
  FactProvenance get _lppProvenance => _lppTouched
      ? FactProvenance.touched
      : (_lppSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  FactProvenance get _yearsInChProvenance =>
      _yearsInChTouched ? FactProvenance.touched : FactProvenance.assumed;
  FactProvenance get _yearsAbroadProvenance =>
      _yearsAbroadTouched ? FactProvenance.touched : FactProvenance.assumed;
  FactProvenance get _ageProvenance =>
      _ageSeeded ? FactProvenance.seededFromProfile : FactProvenance.assumed;

  // ════════════════════════════════════════════════════════════
  //  GATES — chaque sortie gate sur les faits QU'ELLE consomme
  // ════════════════════════════════════════════════════════════

  // Forfait fiscal : canton + dépenses de vie mondiales + revenu mondial réel.
  SituationGate _forfaitGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'forfaitCanton',
          label: (c) => S.of(c)!.expatGateFactForfaitCanton,
          why: (c) => S.of(c)!.expatGateWhyForfaitCanton,
          provenance: _forfaitCantonProvenance,
          onComplete: () => _scrollToKey(_forfaitCantonKey),
        ),
        SituationFact(
          key: 'livingExpenses',
          label: (c) => S.of(c)!.expatGateFactLivingExpenses,
          why: (c) => S.of(c)!.expatGateWhyLivingExpenses,
          provenance: _livingExpensesProvenance,
          onComplete: () => _scrollToKey(_livingExpensesKey),
        ),
        SituationFact(
          key: 'actualIncome',
          label: (c) => S.of(c)!.expatGateFactActualIncome,
          why: (c) => S.of(c)!.expatGateWhyActualIncome,
          provenance: _actualIncomeProvenance,
          onComplete: () => _scrollToKey(_actualIncomeKey),
        ),
      ]);

  // Top cantons : revenu imposable réel + canton d'ancrage réel (facts profil,
  // aucun contrôle in-screen → onComplete null).
  SituationGate _topCantonsGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'income',
          label: (c) => S.of(c)!.expatGateFactIncome,
          why: (c) => S.of(c)!.expatGateWhyIncome,
          provenance: _topIncomeProvenance,
        ),
        SituationFact(
          key: 'canton',
          label: (c) => S.of(c)!.expatGateFactCanton,
          why: (c) => S.of(c)!.expatGateWhyCanton,
          provenance: _topAnchorProvenance,
        ),
      ]);

  // Départ (héros « capital en jeu ») : solde 3a + avoir LPP.
  SituationGate _departGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'pillar3a',
          label: (c) => S.of(c)!.expatGateFactPillar3a,
          why: (c) => S.of(c)!.expatGateWhyPillar3a,
          provenance: _pillar3aProvenance,
          onComplete: () => _scrollToKey(_pillar3aKey),
        ),
        SituationFact(
          key: 'lpp',
          label: (c) => S.of(c)!.expatGateFactLpp,
          why: (c) => S.of(c)!.expatGateWhyLpp,
          provenance: _lppProvenance,
          onComplete: () => _scrollToKey(_lppKey),
        ),
      ]);

  // Lacune AVS (_avsResult) : années en Suisse + années à l'étranger.
  SituationGate _avsGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'yearsInCh',
          label: (c) => S.of(c)!.expatGateFactYearsInCh,
          why: (c) => S.of(c)!.expatGateWhyYearsInCh,
          provenance: _yearsInChProvenance,
          onComplete: () => _scrollToKey(_yearsInChKey),
        ),
        SituationFact(
          key: 'yearsAbroad',
          label: (c) => S.of(c)!.expatGateFactYearsAbroad,
          why: (c) => S.of(c)!.expatGateWhyYearsAbroad,
          provenance: _yearsAbroadProvenance,
          onComplete: () => _scrollToKey(_yearsAbroadKey),
        ),
      ]);

  // Projection AvsGapWidget : années en Suisse (touch) + âge réel (clé 'age').
  // La projection de rente future dépend des années restantes = f(âge).
  SituationGate _avsProjectionGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'yearsInCh',
          label: (c) => S.of(c)!.expatGateFactYearsInCh,
          why: (c) => S.of(c)!.expatGateWhyYearsInCh,
          provenance: _yearsInChProvenance,
          onComplete: () => _scrollToKey(_yearsInChKey),
        ),
        SituationFact(
          key: 'age',
          label: (c) => S.of(c)!.expatGateFactAge,
          why: (c) => S.of(c)!.expatGateWhyAge,
          provenance: _ageProvenance,
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
  //  COMPUTE (gate au compute-time : aucun résultat sans faits confirmés)
  // ════════════════════════════════════════════════════════════

  void _recalculateAll() {
    _recalculateForfait();
    _recalculateTopCantons();
    _recalculateDepart();
    _recalculateAvs();
  }

  void _recalculateForfait() {
    _forfaitResult = _forfaitGate(context).complete
        ? ExpatService.simulateForfaitFiscal(
            canton: _forfaitCanton,
            livingExpenses: _livingExpenses,
            actualIncome: _actualIncome,
          )
        : null;
  }

  void _recalculateTopCantons() {
    _topCantonsResult = _topCantonsGate(context).complete
        ? _computeTopCantons(
            anchorCanton: _topAnchor,
            income: _topIncome,
            etatCivil: _topMarried ? 'marie' : 'celibataire',
            enfants: _topMarried
                ? ((_topCantonsHasChildren || _topProfileEnfants > 0) ? 1 : 0)
                : 0,
          )
        : const [];
  }

  // Checklist / timeline départ : AUCUN CHF rendu → non gaté (calculé toujours).
  void _recalculateDepart() {
    _departResult = ExpatService.planDeparture(
      departureDate: _departureDate,
      canton: _departCanton,
      pillar3aBalance: _pillar3aBalance,
      lppBalance: _lppBalance,
    );
  }

  void _recalculateAvs() {
    _avsResult = _avsGate(context).complete
        ? ExpatService.estimateAvsGap(
            yearsAbroad: _yearsAbroad,
            yearsInCh: _yearsInCh,
          )
        : null;
  }

  void _refreshGateBaselines() {
    _forfaitGateComplete = _forfaitGate(context).complete;
    _topCantonsGateComplete = _topCantonsGate(context).complete;
    _departGateComplete = _departGate(context).complete;
    _avsGateComplete = _avsGate(context).complete;
    _avsProjectionGateComplete = _avsProjectionGate(context).complete;
  }

  void _announceComplete() {
    SemanticsService.sendAnnouncement(
      View.of(context),
      S.of(context)!.situationGateAnnounceComplete,
      Directionality.of(context),
    );
  }

  /// L'utilisateur a édité un fait de SITUATION : recalcule tout (stale-result
  /// invalidation) et annonce le passage incomplet→complet pour VoiceOver
  /// (le scroll ≠ déplacement de focus). Une seule annonce si l'une des sorties
  /// vient de se déverrouiller.
  void _afterFactsChanged() {
    final wasForfait = _forfaitGateComplete;
    final wasTop = _topCantonsGateComplete;
    final wasDepart = _departGateComplete;
    final wasAvs = _avsGateComplete;
    final wasProj = _avsProjectionGateComplete;
    setState(_recalculateAll);
    _refreshGateBaselines();
    final lifted = (_forfaitGateComplete && !wasForfait) ||
        (_topCantonsGateComplete && !wasTop) ||
        (_departGateComplete && !wasDepart) ||
        (_avsGateComplete && !wasAvs) ||
        (_avsProjectionGateComplete && !wasProj);
    if (lifted) _announceComplete();
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // ILLOG-02 : conteneur Semantics racine (motif rente_vs_capital) sinon le
    // pont AX iOS effondre toute la route en un seul nœud (« 1 element »).
    return Semantics(
      identifier: 'expat_screen',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: MintColors.white,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildAppBar(context, innerBoxIsScrolled),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTab1Forfait(),
              _buildTab2Depart(),
              _buildTab3Avs(),
            ],
          ),
        ),
      ),
    );
  }

  // ── App Bar with Tabs — white standard ──────────────────

  Widget _buildAppBar(BuildContext context, bool innerBoxIsScrolled) {
    final l = S.of(context)!;
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => safePop(context),
      ),
      title: Semantics(
        header: true,
        child: Text(
          l.expatTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: MintColors.primary,
        indicatorWeight: 3,
        labelColor: MintColors.textPrimary,
        unselectedLabelColor: MintColors.textMuted,
        labelStyle: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        unselectedLabelStyle: MintTextStyles.bodySmall(),
        tabs: [
          Tab(text: l.expatTabForfait),
          Tab(text: l.expatTabDeparture),
          Tab(text: l.expatTabAvs),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: FORFAIT — Lump-sum Taxation
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Forfait() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, MintSpacing.xxl),
      children: [
        MintEntrance(child: _buildForfaitInputCard()),
        const SizedBox(height: MintSpacing.lg),
        // Result slot : carte de comparaison OU carte de situation gatée. Le
        // forfait ne se calcule pas sur les défauts fabriqués 1M / 5M.
        if (_forfaitResult != null) ...[
          MintEntrance(
            delay: const Duration(milliseconds: 100),
            child: _buildForfaitResultCard(),
          ),
          const SizedBox(height: MintSpacing.lg),
        ] else ...[
          MintEntrance(
            delay: const Duration(milliseconds: 100),
            child: SituationGateCard(
              title: S.of(context)!.expatForfaitGateTitle,
              gate: _forfaitGate(context),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
        ],
        MintEntrance(
          delay: const Duration(milliseconds: 200),
          child: _buildAbolishedWarning(),
        ),
        const SizedBox(height: MintSpacing.lg),
        MintEntrance(
          delay: const Duration(milliseconds: 300),
          child: _buildEducationalInsert(
            S.of(context)!.expatForfaitEducation,
          ),
        ),
        const SizedBox(height: MintSpacing.lg),
        MintEntrance(
          delay: const Duration(milliseconds: 400),
          child: _buildTopCantonSection(),
        ),
        const SizedBox(height: MintSpacing.lg),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildTopCantonSection() {
    // Gate dur : le classement CHF est personnalisé (barème sur le revenu réel).
    // Sans revenu + canton réels du profil, chaque écart serait fabriqué (défaut
    // forfait 5M / ancrage VD). Faits profil → onComplete null (le profil se
    // complète ailleurs). Snapshots re-évalués en _seedFromProfile (pas de
    // lecture live en build).
    if (!_topCantonsGate(context).complete) {
      return SituationGateCard(
        title: S.of(context)!.expatTopCantonsGateTitle,
        gate: _topCantonsGate(context),
      );
    }
    // Le modèle famille de FiscalService n'a de variante enfants que pour les
    // mariés — le toggle serait numériquement inerte sinon (façade) : masqué
    // hors mariage, pré-réglé sur le profil.
    final enfants = _topMarried
        ? ((_topCantonsHasChildren || _topProfileEnfants > 0) ? 1 : 0)
        : 0;

    return Column(children: [
      // Honnêteté mono-revenu (beads MINT_nosync-mla volet C) : marié sans
      // conjoint financier -> le classement couple est en fait mono-revenu.
      // Gate sur MARIÉ uniquement — en concubinage l'imposition est séparée, le
      // calcul solo est correct par conception (pas de fausse alerte « donnée
      // manquante »).
      if (_topMissingConjointIncome)
        const ConjointMissingHint(forceShow: true),
      TopCantonWidget(
        currentCanton: _topAnchor,
        rankings: _topCantonsResult,
        hasChildren: enfants > 0,
        onChildrenChanged: _topMarried
            ? (v) {
                _topCantonsHasChildren = v;
                _afterFactsChanged();
              }
            : null,
      ),
    ]);
  }

  Widget _buildForfaitInputCard() {
    final l = S.of(context)!;
    final eligibleCantons = ExpatService.eligibleForfaitCantons;

    if (!eligibleCantons.contains(_forfaitCanton)) {
      _forfaitCanton = eligibleCantons.first;
    }

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(
            key: _forfaitCantonKey,
            child: Row(
            children: [
              Expanded(
                child: Text(
                  l.expatCanton,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: MintSpacing.sm),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _forfaitCanton,
                    style: MintTextStyles.bodyMedium(
                        color: MintColors.textPrimary),
                    items: eligibleCantons.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(
                            '$code \u2014 ${ExpatService.cantonNames[code]}'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _forfaitCanton = v;
                        _forfaitCantonTouched = true;
                        _afterFactsChanged();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          ),
          const SizedBox(height: MintSpacing.lg),
          KeyedSubtree(
            key: _livingExpensesKey,
            child: MintAmountField(
              label: l.expatLivingExpenses,
              value: _livingExpenses,
              formatValue: (v) => ExpatService.formatChf(v),
              onChanged: (v) {
                _livingExpenses = v;
                _livingExpensesTouched = true;
                _afterFactsChanged();
              },
              min: 250000,
              max: 5000000,
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          KeyedSubtree(
            key: _actualIncomeKey,
            child: MintAmountField(
              label: l.expatActualIncome,
              value: _actualIncome,
              formatValue: (v) => ExpatService.formatChf(v),
              onChanged: (v) {
                _actualIncome = v;
                _actualIncomeTouched = true;
                _afterFactsChanged();
              },
              min: 500000,
              max: 20000000,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForfaitResultCard() {
    final l = S.of(context)!;
    final result = _forfaitResult!;

    if (result['abolished'] == true) {
      return Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.block, size: 20, color: MintColors.error),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Text(
                result['note'] as String,
                style: MintTextStyles.bodyMedium(
                    color: MintColors.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    final forfaitTax = result['forfaitTax'] as double;
    final ordinaryTax = result['ordinaryTax'] as double;
    final savings = result['savings'] as double;
    final savingsPercent = result['savingsPercent'] as double;
    final forfaitBase = result['forfaitBase'] as double;
    final isFavorable = result['isFavorable'] as bool;

    return MintSurface(
      key: const Key('expatForfaitResult'),
      tone: MintSurfaceTone.porcelaine,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatTaxComparison,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),

          // Side by side
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(MintSpacing.md),
                  decoration: BoxDecoration(
                    color: MintColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 24, color: MintColors.textSecondary),
                      const SizedBox(height: MintSpacing.sm),
                      Text(
                        l.expatForfaitFiscal,
                        style: MintTextStyles.labelSmall(
                            color: MintColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MintSpacing.sm),
                      Text(
                        ExpatService.formatChf(forfaitTax),
                        style: MintTextStyles.titleMedium(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        l.expatForfaitBase(
                            ExpatService.formatChf(forfaitBase)),
                        style: MintTextStyles.labelSmall(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(MintSpacing.md),
                  decoration: BoxDecoration(
                    color: MintColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_outlined,
                          size: 24, color: MintColors.textSecondary),
                      const SizedBox(height: MintSpacing.sm),
                      Text(
                        l.expatOrdinaryTaxation,
                        style: MintTextStyles.labelSmall(
                            color: MintColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MintSpacing.sm),
                      Text(
                        ExpatService.formatChf(ordinaryTax),
                        style: MintTextStyles.titleMedium(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        l.expatOnActualIncome,
                        style: MintTextStyles.labelSmall(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          // Savings badge
          Semantics(
            label: isFavorable
                ? l.expatSavingsBadge(ExpatService.formatChf(savings.abs()),
                    savingsPercent.toStringAsFixed(0))
                : l.expatForfaitMoreCostly(
                    ExpatService.formatChf(savings.abs())),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.lg, vertical: MintSpacing.sm),
              decoration: BoxDecoration(
                color: isFavorable
                    ? MintColors.success.withValues(alpha: 0.1)
                    : MintColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFavorable
                      ? MintColors.success.withValues(alpha: 0.3)
                      : MintColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isFavorable ? Icons.trending_down : Icons.trending_up,
                    size: 20,
                    color: isFavorable
                        ? MintColors.success
                        : MintColors.warning,
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Flexible(
                    child: Text(
                      isFavorable
                          ? l.expatSavingsBadge(
                              ExpatService.formatChf(savings.abs()),
                              savingsPercent.toStringAsFixed(0))
                          : l.expatForfaitMoreCostly(
                              ExpatService.formatChf(savings.abs())),
                      style: MintTextStyles.titleMedium(
                        color: isFavorable
                            ? MintColors.success
                            : MintColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbolishedWarning() {
    final l = S.of(context)!;
    final abolished = ExpatService.forfaitAbolishedCantons.toList()..sort();
    final names =
        abolished.map((c) => ExpatService.cantonNames[c] ?? c).join(', ');

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: MintColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber,
              size: 18, color: MintColors.warning),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.expatAbolishedCantons,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.warning),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  l.expatAbolishedNote(names),
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: DEPART — Departure Planning
  // ════════════════════════════════════════════════════════════

  Widget _buildTab2Depart() {
    final l = S.of(context)!;
    // Chiffre-choc for tab 2: total capital at stake
    final totalCapital = _pillar3aBalance + _lppBalance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, MintSpacing.xxl),
      children: [
        // ── Chiffre-choc hero for Tab 2 — capital de prévoyance en jeu ──
        // Gate dur : le héros = 3a + LPP. Sur les défauts fabriqués 80000 +
        // 250000 (= 330000) il faudrait afficher un capital inventé → gaté tant
        // que les deux soldes ne viennent pas des données réelles.
        if (_departGate(context).complete) ...[
          if (totalCapital > 0)
            MintEntrance(
              child: KeyedSubtree(
                key: const Key('expatDepartHero'),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: MintSpacing.lg),
                  child: MintResultHeroCard(
                    eyebrow: l.expatTabDeparture.toUpperCase(),
                    primaryValue: ExpatService.formatChf(totalCapital),
                    primaryLabel: l.expatDepartPremierEclairage(
                        ExpatService.formatChf(totalCapital)),
                    narrative: l.expatDepartPremierEclairage(
                        ExpatService.formatChf(totalCapital)),
                    accentColor: MintColors.info,
                    tone: MintSurfaceTone.bleu,
                  ),
                ),
              ),
            ),
        ] else ...[
          MintEntrance(
            child: Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.lg),
              child: SituationGateCard(
                title: S.of(context)!.expatDepartGateTitle,
                gate: _departGate(context),
              ),
            ),
          ),
        ],

        MintEntrance(
          delay: const Duration(milliseconds: 100),
          child: _buildDepartInputCard(),
        ),
        const SizedBox(height: MintSpacing.lg),
        MintEntrance(
          delay: const Duration(milliseconds: 150),
          child: _buildNoExitTaxBadge(),
        ),
        const SizedBox(height: MintSpacing.lg),
        MintEntrance(
          delay: const Duration(milliseconds: 200),
          child: ExpatCountdownWidget(
          departureDate: _departureDate,
          deadlines: const [
            ExpatDeadline(
              label: '3\u00e8me pilier 3a \u2014 cl\u00f4ture ou gel',
              emoji: '\u{1F3E6}',
              daysFromDeparture: -90,
              action:
                  'Contacte ta banque pour planifier la cl\u00f4ture ou le transfert du 3a.',
              legalRef: 'OPP3 art. 1',
              consequence:
                  'Un 3a non g\u00e9r\u00e9 avant le d\u00e9part peut bloquer des fonds pendant des ann\u00e9es.',
            ),
            ExpatDeadline(
              label: 'LPP \u2014 libre passage',
              emoji: '\u{1F4BC}',
              daysFromDeparture: -60,
              action:
                  'Demande le transfert de ton avoir LPP sur un compte de libre passage ou une police.',
              legalRef: 'LPP art. 5 + LFLP art. 4',
            ),
            ExpatDeadline(
              label: 'AVS \u2014 cotisation volontaire',
              emoji: '\u{1F6E1}\uFE0F',
              daysFromDeparture: 0,
              action:
                  'Si tu t\'installes hors EU/AELE, tu peux t\'affilier volontairement \u00e0 l\'AVS pour \u00e9viter des lacunes.',
              legalRef: 'LAVS art. 2',
              isEuOnly: false,
            ),
          ],
        ),
        ),
        const SizedBox(height: MintSpacing.lg),
        if (_departResult != null) ...[
          MintEntrance(
            delay: const Duration(milliseconds: 250),
            child: _buildDepartTimeline(),
          ),
          const SizedBox(height: MintSpacing.lg),
          MintEntrance(
            delay: const Duration(milliseconds: 300),
            child: _buildDepartChecklist(),
          ),
          const SizedBox(height: MintSpacing.lg),
        ],
        MintEntrance(
          delay: const Duration(milliseconds: 350),
          child: _buildEducationalInsert(l.expatTab2EduInsert),
        ),
        const SizedBox(height: MintSpacing.lg),
        // ── P13-A : 5 choses que tu perds en partant ───────────
        MintEntrance(
          delay: const Duration(milliseconds: 400),
          child: ExpatRightsLossWidget(
          destination: 'l\'\u00e9tranger',
          isEuDestination: false,
          rights: [
            const ExpatRight(
              label: 'AVS \u2014 cotisation obligatoire',
              emoji: '\u{1F6E1}\uFE0F',
              before: 'Cotisation automatique via employeur',
              after: 'Lacunes AVS \u2192 rente r\u00e9duite',
              legalRef: 'LAVS art. 1a',
              impact:
                  'Chaque ann\u00e9e manquante r\u00e9duit ta rente AVS de ~2.3%. '
                  '10 ans = \u221223% \u00e0 vie.',
              isIrreversible: true,
            ),
            const ExpatRight(
              label: 'LPP \u2014 2e pilier',
              emoji: '\u{1F3E6}',
              before: '\u00c9pargne retraite obligatoire',
              after: 'Capital bloqu\u00e9 ou retir\u00e9 sans rendement',
              legalRef: 'LPP art. 5',
              impact:
                  'Tu peux retirer ton avoir LPP, mais tu paies l\'imp\u00f4t '
                  'sur le capital retir\u00e9. La reconstitution est impossible \u00e0 l\'\u00e9tranger.',
            ),
            const ExpatRight(
              label: 'Pilier 3a',
              emoji: '\u{1F3DB}\uFE0F',
              before: 'D\u00e9ductions fiscales annuelles',
              after: 'Compte bloqu\u00e9 \u2014 aucun nouveau versement possible',
              legalRef: 'OPP3 art. 1',
              impact:
                  'Tu perds le droit de verser dans le 3a d\u00e8s que tu n\'as '
                  'plus de revenu soumis \u00e0 l\'AVS suisse.',
            ),
            const ExpatRight(
              label: 'LAMal \u2014 assurance maladie',
              emoji: '\u{1F3E5}',
              before: 'Couverture universelle en Suisse',
              after: 'L\u2019assurance maladie est \u00e0 souscrire dans le pays de r\u00e9sidence',
              legalRef: 'LAMal art. 3',
              impact:
                  'La couverture internationale est souvent partielle et '
                  'co\u00fbteuse. V\u00e9rifie les conventions bilat\u00e9rales.',
            ),
            ExpatRight(
              label: 'Ch\u00f4mage AC',
              emoji: '\u{1F4BC}',
              before: S.of(context)!.expatAcIndemnities,
              after: S.of(context)!.expatNoAcRightsAbroad,
              legalRef: 'LACI art. 8',
              impact: S.of(context)!.expatJobLossAbroad,
            ),
          ],
        ),
        ),
        const SizedBox(height: MintSpacing.lg),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildDepartInputCard() {
    final l = S.of(context)!;
    final sortedCodes = ExpatService.sortedCantonCodes;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.expatDepartureDate,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary),
                ),
              ),
              Semantics(
                label: l.expatDepartureDate,
                button: true,
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _departureDate,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 730)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme:
                                Theme.of(context).colorScheme.copyWith(
                                      primary: MintColors.primary,
                                    ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      _departureDate = picked;
                      _afterFactsChanged();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: MintSpacing.md, vertical: MintSpacing.sm),
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MintColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: MintColors.textSecondary),
                        const SizedBox(width: MintSpacing.sm),
                        Text(
                          '${_departureDate.day.toString().padLeft(2, '0')}.'
                          '${_departureDate.month.toString().padLeft(2, '0')}.'
                          '${_departureDate.year}',
                          style: MintTextStyles.bodyMedium(
                              color: MintColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.expatCurrentCanton,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: MintSpacing.sm),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _departCanton,
                    style: MintTextStyles.bodyMedium(
                        color: MintColors.textPrimary),
                    items: sortedCodes.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(
                            '$code \u2014 ${ExpatService.cantonNames[code]}'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _departCanton = v;
                        _departCantonTouched = true;
                        _afterFactsChanged();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),
          KeyedSubtree(
            key: _pillar3aKey,
            child: MintAmountField(
              label: l.expatPillar3aBalance,
              value: _pillar3aBalance,
              formatValue: (v) => ExpatService.formatChf(v),
              onChanged: (v) {
                _pillar3aBalance = v;
                _pillar3aTouched = true;
                _afterFactsChanged();
              },
              min: 0,
              max: 500000,
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          KeyedSubtree(
            key: _lppKey,
            child: MintAmountField(
              label: l.expatLppBalance,
              value: _lppBalance,
              formatValue: (v) => ExpatService.formatChf(v),
              onChanged: (v) {
                _lppBalance = v;
                _lppTouched = true;
                _afterFactsChanged();
              },
              min: 0,
              max: 1000000,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoExitTaxBadge() {
    final l = S.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.lg, vertical: 14),
      decoration: BoxDecoration(
        color: MintColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: MintColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle,
              size: 20, color: MintColors.success),
          const SizedBox(width: MintSpacing.sm),
          Flexible(
            child: Text(
              l.expatNoExitTax,
              style: MintTextStyles.titleMedium(color: MintColors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartTimeline() {
    final l = S.of(context)!;
    final result = _departResult!;
    final daysUntil = result['daysUntilDeparture'] as int;

    final items = <Map<String, String>>[
      {
        'label': l.expatTimelineToday,
        'desc': l.expatTimelineTodayDesc,
        'timing': l.expatTimelineTodayTiming,
      },
      {
        'label': l.expatTimeline2to3Months,
        'desc': l.expatTimeline2to3MonthsDesc,
        'timing': daysUntil > 90
            ? l.expatTimeline2to3MonthsTiming(
                ((daysUntil - 90) / 30).round())
            : l.expatTimelineUrgent,
      },
      {
        'label': l.expatTimeline1Month,
        'desc': l.expatTimeline1MonthDesc,
        'timing': daysUntil > 30
            ? l.expatTimeline1MonthTiming(
                ((daysUntil - 30) / 30).round())
            : l.expatTimelineUrgent,
      },
      {
        'label': l.expatTimelineDDay,
        'desc': l.expatTimelineDDayDesc,
        'timing': daysUntil > 0
            ? l.expatTimelineDDayTiming(daysUntil)
            : l.expatTimelinePassed,
      },
      {
        'label': l.expatTimeline30After,
        'desc': l.expatTimeline30AfterDesc,
        'timing': l.expatTimeline30AfterTiming,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatRecommendedTimeline,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isLast = idx == items.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: idx == 0
                              ? MintColors.primary
                              : MintColors.border,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: idx == 0
                                ? MintColors.primary
                                : MintColors.textMuted,
                            width: 2,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 50,
                          color: MintColors.border,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: isLast ? 0 : MintSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['label']!,
                              style: MintTextStyles.bodySmall(
                                  color: MintColors.textPrimary),
                            ),
                            Text(
                              item['timing']!,
                              style: MintTextStyles.labelSmall(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['desc']!,
                          style: MintTextStyles.labelSmall(
                              color: MintColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDepartChecklist() {
    final l = S.of(context)!;
    final result = _departResult!;
    final checklist = result['checklist'] as List<Map<String, dynamic>>;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatDepartureChecklist,
                style: MintTextStyles.labelSmall(),
              ),
              const Spacer(),
              Text(
                '${_completedChecklist.length}/${checklist.length}',
                style: MintTextStyles.titleMedium(
                    color: MintColors.primary),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          ...checklist.map((item) {
            final id = item['id'] as String;
            final title = item['title'] as String;
            final subtitle = item['subtitle'] as String;
            final timing = item['timing'] as String;
            final isCompleted = _completedChecklist.contains(id);

            return Semantics(
              label: 'Checklist\u00a0: $title',
              button: true,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isCompleted) {
                      _completedChecklist.remove(id);
                    } else {
                      _completedChecklist.add(id);
                    }
                  });
                },
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: isCompleted
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: _buildChecklistItem(
                    title: title,
                    subtitle: subtitle,
                    timing: timing,
                    isCompleted: false,
                  ),
                  secondChild: _buildChecklistItem(
                    title: title,
                    subtitle: subtitle,
                    timing: timing,
                    isCompleted: true,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required String title,
    required String subtitle,
    required String timing,
    required bool isCompleted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color:
                  isCompleted ? MintColors.success : MintColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCompleted
                    ? MintColors.success
                    : MintColors.border,
                width: 2,
              ),
            ),
            child: isCompleted
                ? const Icon(Icons.check,
                    size: 16, color: MintColors.white)
                : null,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCompleted ? 0.5 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: MintTextStyles.labelSmall(
                        color: MintColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timing,
                    style: MintTextStyles.micro(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: AVS — Pension Gap Estimator
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Avs() {
    final l = S.of(context)!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, MintSpacing.xxl),
      children: [
        MintEntrance(child: _buildAvsInputCard()),
        const SizedBox(height: MintSpacing.lg),
        if (_avsResult != null) ...[
          // ── Chiffre-choc hero for Tab 3 ──
          if ((_avsResult!['annualLoss'] as double) > 0)
            MintEntrance(
              delay: const Duration(milliseconds: 100),
              child: Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.lg),
                child: MintResultHeroCard(
                  eyebrow: l.expatTabAvs.toUpperCase(),
                  primaryValue: '-${ExpatService.formatChf(_avsResult!['annualLoss'] as double)}',
                  primaryLabel: l.expatAvsPremierEclairage(ExpatService.formatChf(
                      _avsResult!['annualLoss'] as double)),
                  narrative: l.expatAvsPremierEclairage(ExpatService.formatChf(
                      _avsResult!['annualLoss'] as double)),
                  accentColor: MintColors.error,
                  tone: MintSurfaceTone.porcelaine,
                ),
              ),
            ),

          MintEntrance(
            delay: const Duration(milliseconds: 200),
            child: _buildAvsRingChart(),
          ),
          const SizedBox(height: MintSpacing.lg),
          MintEntrance(
            delay: const Duration(milliseconds: 250),
            child: _buildAvsReductionCard(),
          ),
          const SizedBox(height: MintSpacing.lg),
          MintEntrance(
            delay: const Duration(milliseconds: 300),
            child: _buildAvsVoluntarySection(),
          ),
          const SizedBox(height: MintSpacing.lg),
          MintEntrance(
            delay: const Duration(milliseconds: 350),
            child: _buildAvsRecommendation(),
          ),
          const SizedBox(height: MintSpacing.lg),
        ] else ...[
          // Gate dur : la lacune AVS se calcule sur les années de cotisation.
          // Sur les défauts fabriqués 20 / 10 il faudrait une lacune inventée.
          MintEntrance(
            delay: const Duration(milliseconds: 100),
            child: SituationGateCard(
              title: l.expatAvsGateTitle,
              gate: _avsGate(context),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
        ],
        // Projection AvsGapWidget : rente future = f(années de cotisation, âge
        // réel). Gate dur sur {yearsInCh (touché), âge (clé 'age')} — sinon la
        // rente serait projetée sur le défaut 20 ans / âge 40 fabriqués.
        if (_avsProjectionGate(context).complete && _profileAge != null) ...[
          AvsGapWidget(
            currentContributionYears: _yearsInCh,
            currentAge: _profileAge!,
          ),
        ] else ...[
          SituationGateCard(
            title: l.expatAvsProjectionGateTitle,
            gate: _avsProjectionGate(context),
          ),
        ],
        const SizedBox(height: MintSpacing.lg),
        _buildEducationalInsert(l.expatAvsEducation),
        const SizedBox(height: MintSpacing.lg),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildAvsInputCard() {
    final l = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(
            key: _yearsInChKey,
            child: MintPickerTile(
              label: l.expatYearsInSwitzerland,
              value: _yearsInCh,
              minValue: 0,
              maxValue: 44,
              formatValue: (v) => '$v ans',
              onChanged: (v) {
                _yearsInCh = v;
                _yearsInChTouched = true;
                _afterFactsChanged();
              },
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          KeyedSubtree(
            key: _yearsAbroadKey,
            child: MintPickerTile(
              label: l.expatYearsAbroad,
              value: _yearsAbroad,
              minValue: 0,
              maxValue: 44,
              formatValue: (v) => '$v ans',
              onChanged: (v) {
                _yearsAbroad = v;
                _yearsAbroadTouched = true;
                _afterFactsChanged();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvsRingChart() {
    final l = S.of(context)!;
    final result = _avsResult!;
    final completeness = result['completeness'] as double;
    final completenessPercent = result['completenessPercent'] as double;
    final estimatedRente = result['estimatedRente'] as double;

    Color ringColor;
    if (completeness >= 0.90) {
      ringColor = MintColors.success;
    } else if (completeness >= 0.70) {
      ringColor = MintColors.warning;
    } else {
      ringColor = MintColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withAlpha(128)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.donut_large,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatAvsCompleteness,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),

          Semantics(
            label:
                '${completenessPercent.toStringAsFixed(0)}% ${l.expatOfPension}',
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: completeness,
                      strokeWidth: 12,
                      backgroundColor:
                          MintColors.border.withValues(alpha: 0.3),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(ringColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${completenessPercent.toStringAsFixed(0)}%',
                        style: MintTextStyles.displayMedium(
                            color: ringColor),
                      ),
                      Text(
                        l.expatOfPension,
                        style: MintTextStyles.bodySmall(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),

          Container(
            padding: const EdgeInsets.all(MintSpacing.md),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.expatEstimatedPension,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondary),
                ),
                Text(
                  '${ExpatService.formatChf(estimatedRente)}/mois',
                  style: MintTextStyles.headlineMedium(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvsReductionCard() {
    final l = S.of(context)!;
    final result = _avsResult!;
    final missingYears = result['missingYears'] as int;
    final reductionPercent = result['reductionPercent'] as double;
    final monthlyLoss = result['monthlyLoss'] as double;
    final annualLoss = result['annualLoss'] as double;

    if (missingYears == 0) {
      return Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: MintColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle,
                size: 20, color: MintColors.success),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Text(
                l.expatAvsComplete,
                style: MintTextStyles.bodyMedium(
                    color: MintColors.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const Key('expatAvsResult'),
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_down,
                  size: 16, color: MintColors.error),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatPensionImpact,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          _buildResultRow(l.expatMissingYears, '$missingYears ans'),
          const SizedBox(height: MintSpacing.sm),
          _buildResultRow(
            l.expatEstimatedReduction,
            '-${reductionPercent.toStringAsFixed(1)}%',
            color: MintColors.error,
          ),
          const SizedBox(height: MintSpacing.sm),
          _buildResultRow(
            l.expatMonthlyLoss,
            '-${ExpatService.formatChf(monthlyLoss)}',
            color: MintColors.error,
          ),
          const SizedBox(height: MintSpacing.sm),
          _buildResultRow(
            l.expatAnnualLoss,
            '-${ExpatService.formatChf(annualLoss)}',
            color: MintColors.error,
            bold: true,
          ),
          const SizedBox(height: MintSpacing.sm),
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l.expatAvsReductionExplain(
                  (ExpatService.reductionPerMissingYear * 100)
                      .toStringAsFixed(1)),
              style: MintTextStyles.labelSmall(
                  color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvsVoluntarySection() {
    final l = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatVoluntaryContribution,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          Container(
            padding: const EdgeInsets.all(MintSpacing.md),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.expatVoluntaryAvsTitle,
                  style:
                      MintTextStyles.titleMedium(color: MintColors.info),
                ),
                const SizedBox(height: MintSpacing.sm),
                _buildResultRow(
                  l.expatMinContribution,
                  '${ExpatService.formatChf(ExpatService.avsVoluntaryMin)}/an',
                ),
                const SizedBox(height: MintSpacing.xs),
                _buildResultRow(
                  l.expatMaxContribution,
                  '${ExpatService.formatChf(ExpatService.avsVoluntaryMax)}/an',
                ),
                const SizedBox(height: MintSpacing.sm),
                Text(
                  l.expatVoluntaryAvsBody,
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvsRecommendation() {
    final l = S.of(context)!;
    final result = _avsResult!;
    final recommendation = result['recommendation'] as String;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatRecommendation,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            recommendation,
            style: MintTextStyles.bodyMedium(
                color: MintColors.textPrimary),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _buildResultRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: MintTextStyles.bodyMedium(),
          ),
        ),
        Text(
          value,
          style: MintTextStyles.bodyMedium(
            color: color ?? MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildEducationalInsert(String text) {
    final l = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(MintSpacing.xs),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lightbulb_outline,
                size: 18, color: MintColors.info),
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.expatDidYouKnow,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.info),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  text,
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Semantics(
      label: ExpatService.disclaimer,
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline,
                color: MintColors.textMuted, size: 18),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Text(
                ExpatService.disclaimer,
                style: MintTextStyles.micro(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
