import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'canton_r1.dart';
import 'eclairage_impot_3a.dart';
import 'fact_etat_civil.dart';
import 'fact_lieu.dart';
import 'fact_revenu.dart';
import 'l10n/generated/mint_next_localizations.dart';
import 'multi_provider_amount_draft.dart';
import 'multi_provider_amount_editor.dart';
import 'ordinary_chf_amount.dart';
import 'provider_label.dart';
import 'r3_eclairage_catalog.g.dart';
import 'r4_fermeture_catalog.g.dart';
import 'scenarios_versement.dart';

enum _DesignNode {
  today3aIntent,
  orientation,
  // Phase B (année = hypothèse par défaut, plus une question): factTaxYear is
  // kept as a documented-historical, UNREACHABLE node — no inbound edge routes
  // here anymore (orientation.continue, the batch16 purge, the year-rollover
  // reset and the LPP back-edge all now target orientation). The linear journey
  // dropped from 7 to 6 screens before the éclairage. Retained only for switch
  // exhaustiveness + the frozen batch6/batch7 contract (navigation.yaml still
  // describes the 7-screen graph — declared divergence, superseded by runtime).
  factTaxYear,
  factLppAffiliation,
  lppUnknownHelp,
  withoutLppBoundary,
  factContribution,
  contributionUnknownHelp,
  factContributedAmount,
  contributedAmountUnknownHelp,
  unresolvedAmountHelp,
  contributionStatusCorrection,
  factCanton,
  factLieu,
  factRevenu,
  eclairageImpot3a,
  educationExplanation,
  dismissed,
  scenariosVersement,
  factEtatCivil,
}

enum _LppAffiliation { yes, no, unknown }

enum _ContributionStatus { yes, no, unknown }

/// Which R3 (batch21) éclairage node the test harness lands on directly.
///
/// The R3 forward controls never route in R3 (never_routes_in_r3), so — like
/// batch20's fact_lieu, reached via the shared entry path — the two éclairage
/// nodes are reached by a harness that starts on the requested node with its
/// facts preset. fact_revenu commits a band without routing; eclairage renders
/// one of the five sealed states from the preset facts.
enum Batch21Start { factRevenu, eclairage }

/// Preset facts for the batch21 harness (test-only reachability).
class Batch21Config {
  const Batch21Config({
    this.startNode = Batch21Start.factRevenu,
    this.band,
    this.situation = EclairageSituation.celibataire,
    this.exactIncome,
    this.canContribute = true,
  });

  final Batch21Start startNode;
  final String? band; // committed taxable_income_band_enum, null -> pending
  final EclairageSituation situation;
  final int? exactIncome; // grounded exact point -> precision_refined
  final bool canContribute; // false -> non_applicable_source
}

/// Which R4 (batch22, "fermeture de la boucle") node the test harness lands
/// on directly.
///
/// batch22 is PARALLEL PREP in an isolated worktree (codex/journey-os-batch22-
/// runtime) — it is NOT wired into the linear journey (never_routes_in_r4 on
/// both nodes' forward controls; fact_etat_civil's `back` too). Like the R3
/// harness before its own integration wave, the two R4 nodes are reached by a
/// harness that starts on the requested node with its facts preset, not by
/// walking the (still R3-only) linear journey.
enum Batch22Start { scenariosVersement, factEtatCivil }

/// Preset facts for the batch22 harness (test-only reachability).
///
/// scenarios_versement's four critical inputs (tax_year, commune,
/// taxable_income_band, lpp_affiliation — additional_planned_amount is NEVER
/// a pending trigger) are each modelled as a `*Known` flag so a dev test can
/// null out exactly one and assert `pending_missing_fact` names it. The
/// grounded engine fixtures (r4_fermeture_catalog.g.dart) cover ONLY canton
/// FR / band b70_100 / célibataire — an OFFLINE-LAB LIMITATION documented in
/// scenarios_versement.dart, mirroring R3's single grounded refine point.
class Batch22Config {
  const Batch22Config({
    this.startNode = Batch22Start.scenariosVersement,
    this.taxYearKnown = true,
    this.commune = r3ExampleCommune,
    this.canton = r3ExampleCanton,
    this.communeKnown = true,
    this.band = 'b70_100',
    this.bandKnown = true,
    this.affiliated = true,
    this.affiliationKnown = true,
    this.contributedChf = 0,
    this.nonAffiliatedIncomeChf = r4Plafond20DemoIncomeChf,
    this.civilStatus,
  });

  final Batch22Start startNode;

  final bool taxYearKnown;
  final String commune;
  final String canton;
  final bool communeKnown;
  final String band;
  final bool bandKnown;
  final bool affiliated;
  final bool affiliationKnown;
  final int contributedChf;
  final int nonAffiliatedIncomeChf;

  /// fact_etat_civil preset selection. null = no card selected
  /// (default_hypothesis, no_preselection).
  final String? civilStatus;
}

class MintNextDesignLabApp extends StatelessWidget {
  const MintNextDesignLabApp({
    super.key,
    this.locale,
    this.textScaler,
    this.currentYear,
  }) : _enableBatch14MultiProvider = false,
       _enableBatch16Unresolved = false,
       batch21 = null,
       batch22 = null,
       now = null;

  @visibleForTesting
  const MintNextDesignLabApp.batch14Harness({
    super.key,
    this.locale,
    this.textScaler,
    this.currentYear,
  }) : _enableBatch14MultiProvider = true,
       _enableBatch16Unresolved = false,
       batch21 = null,
       batch22 = null,
       now = null;

  @visibleForTesting
  const MintNextDesignLabApp.batch16Harness({
    super.key,
    this.locale,
    this.textScaler,
    this.currentYear,
    this.now,
  }) : _enableBatch14MultiProvider = true,
       _enableBatch16Unresolved = true,
       batch21 = null,
       batch22 = null;

  /// R3 (batch21) éclairage-arc harness: lands directly on [Batch21Config.startNode]
  /// with the preset facts, so the two nodes are reachable despite the R3 forward
  /// controls never routing (never_routes_in_r3).
  @visibleForTesting
  const MintNextDesignLabApp.batch21Harness({
    super.key,
    this.locale,
    this.textScaler,
    this.currentYear,
    this.batch21 = const Batch21Config(),
  }) : _enableBatch14MultiProvider = false,
       _enableBatch16Unresolved = false,
       batch22 = null,
       now = null;

  /// R4 (batch22, "fermeture de la boucle") harness: lands directly on
  /// [Batch22Config.startNode] with the preset facts, so scenarios_versement
  /// and fact_etat_civil are reachable despite their forward controls never
  /// routing in R4 (parallel prep, not the integration wave).
  @visibleForTesting
  const MintNextDesignLabApp.batch22Harness({
    super.key,
    this.locale,
    this.textScaler,
    this.currentYear,
    this.batch22 = const Batch22Config(),
  }) : _enableBatch14MultiProvider = false,
       _enableBatch16Unresolved = false,
       batch21 = null,
       now = null;

  final Locale? locale;
  final TextScaler? textScaler;
  final int? currentYear;
  final bool _enableBatch14MultiProvider;
  final bool _enableBatch16Unresolved;
  final Batch21Config? batch21;
  final Batch22Config? batch22;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: MintNextLocalizations.localizationsDelegates,
      supportedLocales: MintNextLocalizations.supportedLocales,
      theme: _theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: _DesignLabJourney(
        currentYear: currentYear ?? DateTime.now().year,
        enableBatch14MultiProvider: _enableBatch14MultiProvider,
        enableBatch16Unresolved: _enableBatch16Unresolved,
        batch21: batch21,
        batch22: batch22,
        now: now ?? DateTime.now,
      ),
    );
  }
}

const _paper = Color(0xFFFAF8F5);
const _porcelain = Color(0xFFF4F1EC);
const _ink = Color(0xFF1A1A1A);
const _secondaryInk = Color(0xFF4A4A4A);
// 5.98:1 against _paper. The former coral failed normal-text AA at 3.51:1.
const _coral = Color(0xFF944B34);
const _sage = Color(0xFFD4DFCE);
const _border = Color(0xFFE2DED7);

final _theme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: _paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _sage,
    surface: _paper,
    brightness: Brightness.light,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      fontFamily: 'Supreme',
      fontSize: 18,
      height: 1.45,
      color: _ink,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Supreme',
      fontSize: 16,
      height: 1.45,
      color: _secondaryInk,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Supreme',
      fontWeight: FontWeight.w700,
      fontSize: 16,
    ),
  ),
);

class _DesignLabJourney extends StatefulWidget {
  const _DesignLabJourney({
    required this.currentYear,
    required this.enableBatch14MultiProvider,
    required this.enableBatch16Unresolved,
    required this.batch21,
    required this.batch22,
    required this.now,
  });

  final int currentYear;
  final bool enableBatch14MultiProvider;
  final bool enableBatch16Unresolved;
  final Batch21Config? batch21;
  final Batch22Config? batch22;
  final DateTime Function() now;

  @override
  State<_DesignLabJourney> createState() => _DesignLabJourneyState();
}

class _DesignLabJourneyState extends State<_DesignLabJourney>
    with WidgetsBindingObserver {
  _DesignNode _node = _DesignNode.today3aIntent;
  int? _taxYear;
  // R3 (batch21): the committed taxable-income band (fact_revenu), read by the
  // eclairage payoff node. Ephemeral until committed, then joins the profile.
  String? _taxableIncomeBand;
  // R4 (batch22): scenarios_versement's facts (each nullable field IS the
  // "missing" state for pending_missing_fact) + fact_etat_civil's committed
  // status. Preset by the isolated batch22 harness only (parallel prep, not
  // wired into the linear journey).
  int? _scenariosTaxYear;
  String? _scenariosCommune;
  String? _scenariosCanton;
  String? _scenariosBand;
  bool? _scenariosAffiliated;
  // V4-2 (Codex P1-2): the already-contributed amount is carried in RAPPEN (minor
  // units) end-to-end so the scenarios margin never truncates centimes. The
  // harness API stays francs (converted ×100 at the seed boundary); the live
  // contribution flows lift the parser's minor units directly (no ~/100).
  int _scenariosContributedRappen = 0;
  int _scenariosNonAffiliatedIncomeChf = r4Plafond20DemoIncomeChf;
  // R4 (batch22) integration: the committed commune + derived canton LABEL,
  // lifted from fact_lieu (onCommuneSelected) so the éclairage payoff hypothesis
  // row shows the commune the user actually picked — never the hardcoded fixture
  // commune presented as their choice (the displayable-lie fix). Default = the
  // offline-lab fixture example (canton FR / Fribourg): the batch21/batch22
  // harness paths land on éclairage/scenarios WITHOUT walking fact_lieu, so they
  // keep the graved example, and the canton-FR-grounded engine fixtures are
  // never re-derived (NEVER#3 — this lifts the LABEL only, disclaimed as an
  // estimate; eclairage-scope.yaml:60,69 freezes the number at the chef-lieu).
  String _eclairageCommune = r3ExampleCommune;
  String _eclairageCanton = r3ExampleCanton;
  // V3-1 (Codex P1-1): the canton CODE the user actually picked in fact_lieu.
  // Default = the fixture canton (FR / Fribourg) — the offline-lab hero range is
  // always the FR fixture, so any picked canton ≠ FR triggers the co-located
  // "example figure for Fribourg" disclosure on the éclairage lieu row. Locale-
  // robust (a CODE, never a locale-dependent label).
  String _eclairageCantonCode = 'FR';
  // V4-1 (Codex P1-1): the BFS id of the commune the user actually picked in
  // fact_lieu. Default = the chef-lieu Fribourg fixture BFS (harness paths that
  // skip fact_lieu keep the graved example, so they disclose NOTHING). The
  // éclairage resolves the lieu disclosure by EXACT locality (chef-lieu -> none ;
  // other FR commune -> intra-cantonal ; other canton -> inter-cantonal) from
  // this BFS + the canton CODE, never a label.
  int _eclairageBfs = eclairageFixtureChefLieuBfs;
  // R4 (batch22) integration: the scenarios own-amount ("versement"), LIFTED to
  // the parent so it survives one fermeture loop turn (scenarios -> etat_civil
  // -> éclairage -> scenarios) instead of dying with the ScenariosVersementScreen
  // widget on destruction. Null on first arrival (no preselected amount — sealed
  // R4_07); preserved thereafter so a loop never silently drops it.
  int? _scenariosOwnAmountChf;
  String? _batch22CivilStatus;
  // R4 (batch22) integration: fact_etat_civil is now reachable from BOTH the
  // éclairage situation-row refine AND scenarios_versement.continue — its back
  // button returns to whichever origin opened it (origin-aware, like the
  // fact_lieu/fact_canton back helpers). Defaults to the éclairage payoff.
  _DesignNode _etatCivilOrigin = _DesignNode.eclairageImpot3a;
  // R4 (batch22) integration: scenarios_versement.keep_local_reference is a
  // stay-put persist (never leaves the node) — this flag drives the announced
  // "reference kept" live-region chip.
  bool _scenariosReferenceKept = false;
  _LppAffiliation? _lppAffiliation;
  _ContributionStatus? _contributionStatus;
  bool _contributionEdgeHelpExpanded = false;
  final TextEditingController _providerNameController = TextEditingController();
  final TextEditingController _ordinaryAmountController =
      TextEditingController();
  final MultiProviderAmountDraft _multiProviderDraft =
      MultiProviderAmountDraft();
  bool _allProvidersReviewed = false;
  bool _amountWhereToFindExpanded = false;
  bool _amountHelpPartial = false;
  bool _restoreAmountFocus = false;
  bool _restoreUnknownActionFocus = false;
  bool _multipleProvidersDeclared = false;
  _DesignNode _educationBackNode = _DesignNode.contributionUnknownHelp;
  MultiProviderUnresolvedOrigin? _unresolvedOrigin;
  String? _restoreBatch16RowId;
  String? _restoreBatch16Target;
  String _helpRestoreTarget = 'heading';
  Timer? _batch16Ttl;
  late DateTime _batch16LastActivity;
  final FocusNode _defaultSafeExitFocus = FocusNode(
    debugLabel: 'safe exit trigger',
  );
  final FocusNode _mixedSafeExitFocus = FocusNode(
    debugLabel: 'mixed editor safe exit',
  );
  final FocusNode _confirmedSafeExitFocus = FocusNode(
    debugLabel: 'all confirmed editor safe exit',
  );
  final FocusNode _unresolvedSafeExitFocus = FocusNode(
    debugLabel: 'unresolved safe exit trigger',
  );
  final FocusNode _correctionSafeExitFocus = FocusNode(
    debugLabel: 'correction safe exit trigger',
  );
  final FocusNode _educationSafeExitFocus = FocusNode(
    debugLabel: 'education safe exit trigger',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _batch16LastActivity = widget.now();
    _armBatch16Ttl();
    // R3 harness: land directly on the requested éclairage node with its facts
    // preset (the R3 forward controls never route, so the journey cannot walk
    // into these nodes — the harness places the runtime under test).
    final batch21 = widget.batch21;
    if (batch21 != null) {
      _taxYear = widget.currentYear;
      _taxableIncomeBand = batch21.band;
      _node = switch (batch21.startNode) {
        Batch21Start.factRevenu => _DesignNode.factRevenu,
        Batch21Start.eclairage => _DesignNode.eclairageImpot3a,
      };
    }
    // R4 (batch22) harness: land directly on the requested fermeture-de-la-
    // boucle node with its facts preset. The fermeture edges are now WIRED
    // (fact_etat_civil.continue -> éclairage ; scenarios.back -> éclairage), so
    // the harness seeds the default year hypothesis (Phase B: année is always
    // seeded once in-journey) — otherwise routing to the éclairage payoff would
    // hit a null `_taxYear!`.
    final batch22 = widget.batch22;
    if (batch22 != null) {
      _taxYear = widget.currentYear;
      _scenariosTaxYear = batch22.taxYearKnown ? widget.currentYear : null;
      _scenariosCommune = batch22.communeKnown ? batch22.commune : null;
      _scenariosCanton = batch22.communeKnown ? batch22.canton : null;
      _scenariosBand = batch22.bandKnown ? batch22.band : null;
      _scenariosAffiliated =
          batch22.affiliationKnown ? batch22.affiliated : null;
      // V4-2: the harness API is francs; convert to rappen at the seed boundary
      // so the runtime is rappen-native while Batch22Config stays francs.
      _scenariosContributedRappen = batch22.contributedChf * 100;
      _scenariosNonAffiliatedIncomeChf = batch22.nonAffiliatedIncomeChf;
      _batch22CivilStatus = batch22.civilStatus;
      _node = switch (batch22.startNode) {
        Batch22Start.scenariosVersement => _DesignNode.scenariosVersement,
        Batch22Start.factEtatCivil => _DesignNode.factEtatCivil,
      };
    }
  }

  void _armBatch16Ttl() {
    _batch16Ttl?.cancel();
    if (!widget.enableBatch16Unresolved) return;
    _batch16Ttl = Timer(const Duration(minutes: 30), _expireBatch16IfStale);
  }

  void _expireBatch16IfStale() {
    const ttl = Duration(minutes: 30);
    final elapsed = widget.now().difference(_batch16LastActivity);
    if (elapsed >= ttl) {
      _purgeToOrientation();
      return;
    }
    _batch16Ttl = Timer(ttl - elapsed, _expireBatch16IfStale);
  }

  void _touchBatch16() {
    _batch16LastActivity = widget.now();
    _armBatch16Ttl();
  }

  void _purgeToOrientation() {
    if (!mounted || !widget.enableBatch16Unresolved) return;
    setState(() {
      _clearContributionFacts();
      _unresolvedOrigin = null;
      // Phase B: the tax-year screen is gone; the batch16 safe purge now lands on
      // orientation (the screen that precedes the LPP question) and re-seeds the
      // default year hypothesis so downstream `_taxYear!` stays non-null.
      _taxYear = widget.currentYear;
      _node = _DesignNode.orientation;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) _purgeToOrientation();
  }

  @override
  void didUpdateWidget(covariant _DesignLabJourney oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentYear != widget.currentYear) {
      _clearEphemeralFacts();
      _unresolvedOrigin = null;
      // Phase B: on a calendar-year rollover the default year hypothesis re-seeds
      // silently to the new current year and the journey returns to orientation.
      // DEFERRED: the batch6 navigation contract wanted to surface
      // `tax_year_rolled_over`; with the tax-year screen removed that surfacing
      // waits for the future year-refinement affordance (no rollover screen in
      // this wave — explicit deferral, not a silent gap).
      _taxYear = widget.currentYear;
      _node = _DesignNode.orientation;
    }
  }

  @override
  void dispose() {
    _providerNameController.dispose();
    _ordinaryAmountController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _batch16Ttl?.cancel();
    _defaultSafeExitFocus.dispose();
    _mixedSafeExitFocus.dispose();
    _confirmedSafeExitFocus.dispose();
    _unresolvedSafeExitFocus.dispose();
    _correctionSafeExitFocus.dispose();
    _educationSafeExitFocus.dispose();
    super.dispose();
  }

  void _go(_DesignNode node) => setState(() => _node = node);

  /// R4 (batch22) integration: from the éclairage payoff, `continue` opens the
  /// scenarios_versement fermeture-de-boucle node, seeding its facts from the
  /// journey — affiliated from lpp_affiliation (choose_yes -> true), contributed
  /// 0 for the contribution-status = no walk, and the FR fixture commune/canton
  /// the payoff already displays (the documented offline-lab grounding, mirrored
  /// from eclairage_impot_3a's communeLabel/cantonLabel). This supersedes the R3
  /// kept boundary on this edge (batch21 eclairage-scope.yaml
  /// future_target_r4: scenarios_versement); the batch21 sealed test never taps
  /// eclairage.continue, so R3 stays green.
  void _enterScenariosFromEclairage() {
    setState(() {
      _scenariosTaxYear = _taxYear;
      // Lifted commune/canton (the commune the user actually picked in
      // fact_lieu), never the hardcoded fixture — matches the éclairage payoff.
      _scenariosCommune = _eclairageCommune;
      _scenariosCanton = _eclairageCanton;
      _scenariosBand = _taxableIncomeBand;
      _scenariosAffiliated = _lppAffiliation == _LppAffiliation.yes;
      // PRESERVE financial state across ONE fermeture loop turn: do NOT force
      // the contributed amount to 0, do NOT erase the own-amount ("versement"),
      // do NOT reset referenceKept. Re-entering scenarios from the éclairage
      // payoff is a loop turn, not a fresh journey — the earlier fix reset all
      // three and silently destroyed the user's state (roast P1-1).
      // _scenariosContributedRappen, _scenariosOwnAmountChf and
      // _scenariosReferenceKept keep their values.
      _node = _DesignNode.scenariosVersement;
    });
  }

  /// R4 (batch22) integration: map a committed civil status to the éclairage
  /// situation hypothesis. marie_pacse -> marié ; concubinage -> concubinage
  /// (is_married = false, so the NUMBER stays célibataire-equivalent — no ×0.80
  /// splitting, per the sealed R4_13 ruling) ; célibataire / unset -> célibataire.
  EclairageSituation _situationFromCivilStatus(String? status) =>
      switch (status) {
        'marie_pacse' => EclairageSituation.marie,
        'concubinage' => EclairageSituation.concubinage,
        _ => EclairageSituation.celibataire,
      };

  /// R4 (batch22) integration: the éclairage situation-row refine affordance
  /// opens the civil-status collection node; origin-aware back returns here.
  void _refineSituationToEtatCivil() {
    setState(() {
      _etatCivilOrigin = _DesignNode.eclairageImpot3a;
      _node = _DesignNode.factEtatCivil;
    });
  }

  /// R4 (batch22) integration: scenarios_versement.continue advances to the
  /// civil-status node (registry order scenarios -> etat_civil); origin-aware
  /// back returns to scenarios.
  void _enterEtatCivilFromScenarios() {
    setState(() {
      _etatCivilOrigin = _DesignNode.scenariosVersement;
      _node = _DesignNode.factEtatCivil;
    });
  }

  /// R4 (batch22) integration: fact_etat_civil.continue returns to the éclairage
  /// payoff, which re-derives its situation hypothesis from the committed
  /// status (still display-only — no fabricated married range, NEVER#3). The
  /// screen guards this edge (a_status_is_selected): with no status it surfaces
  /// the no-selection error and never calls this.
  void _continueFromEtatCivil() => _go(_DesignNode.eclairageImpot3a);

  /// R4 (batch22) integration: origin-aware back from fact_etat_civil.
  void _backFromEtatCivil() => _go(_etatCivilOrigin);

  /// R4 (batch22) integration: scenarios_versement.keep_local_reference persists
  /// a local reference and STAYS on the node, announcing the kept state via an
  /// a11y live-region chip — it never leaves the fermeture node.
  void _keepScenariosReference() {
    if (_scenariosReferenceKept) return;
    setState(() => _scenariosReferenceKept = true);
  }

  void _returnToAmountField() {
    setState(() {
      _restoreAmountFocus = true;
      _restoreUnknownActionFocus = false;
      _node = _DesignNode.factContributedAmount;
    });
  }

  void _returnToUnknownAmountTrigger() {
    setState(() {
      _restoreAmountFocus = false;
      _restoreUnknownActionFocus = true;
      _node = _DesignNode.factContributedAmount;
    });
  }

  void _clearContributionFacts() {
    _contributionStatus = null;
    _contributionEdgeHelpExpanded = false;
    _clearContributionAmount();
  }

  void _clearContributionAmount() {
    _providerNameController.clear();
    _ordinaryAmountController.clear();
    _allProvidersReviewed = false;
    _amountWhereToFindExpanded = false;
    _amountHelpPartial = false;
    _multipleProvidersDeclared = false;
    _multiProviderDraft.purge();
    _unresolvedOrigin = null;
    // V3-2 (Codex P1-2): re-choosing the contribution status (e.g. yes -> no)
    // clears the entered amount, so the scenarios margin returns to a full
    // plafond (contributed 0) rather than keeping a stale value.
    _scenariosContributedRappen = 0;
  }

  void _clearEphemeralFacts() {
    _taxYear = null;
    _lppAffiliation = null;
    _clearContributionFacts();
  }

  void _leaveWithoutSaving() {
    setState(() {
      _clearEphemeralFacts();
      _node = _DesignNode.dismissed;
    });
  }

  String get _nodeId => switch (_node) {
    _DesignNode.today3aIntent => 'today_3a_intent',
    _DesignNode.orientation => 'orientation',
    _DesignNode.factTaxYear => 'fact_tax_year',
    _DesignNode.factLppAffiliation => 'fact_lpp_affiliation',
    _DesignNode.lppUnknownHelp => 'lpp_unknown_help',
    _DesignNode.withoutLppBoundary => 'without_lpp_boundary',
    _DesignNode.factContribution => 'fact_contribution',
    _DesignNode.contributionUnknownHelp => 'contribution_unknown_help',
    _DesignNode.factContributedAmount => 'fact_contributed_amount',
    _DesignNode.contributedAmountUnknownHelp =>
      'contributed_amount_unknown_help',
    _DesignNode.unresolvedAmountHelp => 'unresolved_amount_help',
    _DesignNode.contributionStatusCorrection =>
      'contribution_status_correction',
    _DesignNode.factCanton => 'fact_canton',
    _DesignNode.factLieu => 'fact_lieu',
    _DesignNode.factRevenu => 'fact_revenu',
    _DesignNode.eclairageImpot3a => 'eclairage_impot_3a',
    _DesignNode.educationExplanation => 'education_explanation',
    _DesignNode.dismissed => 'dismissed',
    _DesignNode.scenariosVersement => 'scenarios_versement',
    _DesignNode.factEtatCivil => 'fact_etat_civil',
  };

  FocusNode get _activeSafeExitFocus => switch (_node) {
    _DesignNode.factContributedAmount when widget.enableBatch16Unresolved =>
      _multiProviderDraft.allProvidersReviewed
          ? _confirmedSafeExitFocus
          : _mixedSafeExitFocus,
    _DesignNode.unresolvedAmountHelp => _unresolvedSafeExitFocus,
    _DesignNode.contributionStatusCorrection => _correctionSafeExitFocus,
    _DesignNode.educationExplanation when _unresolvedOrigin != null =>
      _educationSafeExitFocus,
    _ => _defaultSafeExitFocus,
  };

  void _openBatch16Help(MultiProviderUnresolvedOrigin origin) {
    _touchBatch16();
    setState(() {
      _unresolvedOrigin = origin;
      _helpRestoreTarget = 'heading';
      _node = _DesignNode.unresolvedAmountHelp;
    });
  }

  void _returnFromBatch16Help() {
    final rowId = _unresolvedOrigin?.rowId;
    if (rowId == null) return;
    setState(() {
      _restoreBatch16RowId = rowId;
      _restoreBatch16Target = 'doubt';
      _node = _DesignNode.factContributedAmount;
    });
  }

  void _returnToBatch16Help(String target) {
    if (_unresolvedOrigin == null) return;
    setState(() {
      _helpRestoreTarget = target;
      _node = _DesignNode.unresolvedAmountHelp;
    });
  }

  void _resolveBatch16ProviderTotal(MultiProviderUnresolvedResolveToken token) {
    if (!identical(_unresolvedOrigin?.resolveToken, token)) return;
    if (_multiProviderDraft.resolveProviderReportedTotal(token) !=
        MultiProviderUnresolvedActionResult.resolvedToUnreviewed) {
      return;
    }
    final rowId = _unresolvedOrigin?.rowId;
    if (rowId == null) return;
    setState(() {
      _unresolvedOrigin = null;
      _restoreBatch16RowId = rowId;
      _restoreBatch16Target = 'amount';
      _node = _DesignNode.factContributedAmount;
    });
  }

  void _refundBatch16Provider(MultiProviderUnresolvedRefundToken token) {
    if (!identical(_unresolvedOrigin?.refundToken, token)) return;
    if (_multiProviderDraft.refundFullyProvider(token) !=
        MultiProviderUnresolvedRefundResult.tombstoned) {
      return;
    }
    final rowId = _unresolvedOrigin?.rowId;
    if (rowId == null) return;
    setState(() {
      _unresolvedOrigin = null;
      _restoreBatch16RowId = rowId;
      _restoreBatch16Target = 'undo';
      _node = _DesignNode.factContributedAmount;
    });
  }

  void _beginBatch16AllZero(MultiProviderUnresolvedAllZeroToken token) {
    if (!identical(_unresolvedOrigin?.allZeroToken, token)) return;
    if (_multiProviderDraft.beginAllProvidersZeroCorrection(token) !=
        MultiProviderAllZeroCorrectionResult.ready) {
      return;
    }
    setState(() => _node = _DesignNode.contributionStatusCorrection);
  }

  void _chooseBatch16Correction(_ContributionStatus status) {
    switch (status) {
      case _ContributionStatus.yes:
        final rowId = _unresolvedOrigin?.rowId;
        if (rowId == null) return;
        setState(() {
          _contributionStatus = status;
          _restoreBatch16RowId = rowId;
          _restoreBatch16Target = 'doubt';
          _node = _DesignNode.factContributedAmount;
        });
      case _ContributionStatus.no:
        setState(() {
          _clearContributionAmount();
          _contributionStatus = status;
          _unresolvedOrigin = null;
          // Commune-directe (product decision 2026-08-05): the "no contribution"
          // branch reaches the fused fact_lieu node (canton derived), never the
          // condemned standalone fact_canton screen.
          _node = _DesignNode.factLieu;
        });
      case _ContributionStatus.unknown:
        setState(() {
          _clearContributionAmount();
          _contributionStatus = status;
          _unresolvedOrigin = null;
          _node = _DesignNode.contributionUnknownHelp;
        });
    }
  }

  Future<void> _showSafeExit() async {
    final l10n = MintNextLocalizations.of(context);
    final leftJourney = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (sheetContext) => _SafeExitSheet(
        l10n: l10n,
        onResume: () => Navigator.pop(sheetContext, false),
        onLeave: () {
          Navigator.pop(sheetContext, true);
          _leaveWithoutSaving();
        },
      ),
    );
    if (mounted && leftJourney != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _activeSafeExitFocus.requestFocus();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  void _backFromContributionAmount() {
    if (widget.enableBatch14MultiProvider) {
      _multiProviderDraft.setAllProvidersReviewed(false);
    }
    _go(_DesignNode.factContribution);
  }

  void _backFromCanton() {
    if (widget.enableBatch16Unresolved &&
        _multiProviderDraft.allProvidersReviewed) {
      setState(() {
        _restoreBatch16Target = 'continue';
        _node = _DesignNode.factContributedAmount;
      });
      return;
    }
    _go(
      _contributionStatus == _ContributionStatus.yes
          ? _DesignNode.factContributedAmount
          : _DesignNode.factContribution,
    );
  }

  void _backFromEducation() {
    if (_educationBackNode == _DesignNode.unresolvedAmountHelp) {
      _returnToBatch16Help('education');
      return;
    }
    _go(_educationBackNode);
  }

  void _handleSystemBack() {
    switch (_node) {
      case _DesignNode.today3aIntent:
        _showSafeExit();
      case _DesignNode.orientation:
        _go(_DesignNode.today3aIntent);
      case _DesignNode.factTaxYear:
        // Historical-unreachable (Phase B); kept for switch exhaustiveness.
        _go(_DesignNode.orientation);
      case _DesignNode.factLppAffiliation:
        _go(_DesignNode.orientation);
      case _DesignNode.lppUnknownHelp:
      case _DesignNode.withoutLppBoundary:
        _go(_DesignNode.factLppAffiliation);
      case _DesignNode.factContribution:
        _go(_DesignNode.factLppAffiliation);
      case _DesignNode.contributionUnknownHelp:
        _go(_DesignNode.factContribution);
      case _DesignNode.factContributedAmount:
        _backFromContributionAmount();
      case _DesignNode.contributedAmountUnknownHelp:
        _returnToUnknownAmountTrigger();
      case _DesignNode.unresolvedAmountHelp:
        _returnFromBatch16Help();
      case _DesignNode.contributionStatusCorrection:
        _returnToBatch16Help('all_zero');
      case _DesignNode.factCanton:
        _backFromCanton();
      case _DesignNode.factLieu:
        // Commune-directe: fact_lieu is reached from BOTH contribution branches
        // (no → directly; positive → after the amount step). System-back is
        // origin-aware (same helper the condemned fact_canton used): it returns
        // to the amount step for a positive contribution, otherwise to the
        // contribution boundary.
        _backFromCanton();
      case _DesignNode.factRevenu:
        _go(_DesignNode.factLieu);
      case _DesignNode.eclairageImpot3a:
        _go(_DesignNode.factRevenu);
      case _DesignNode.educationExplanation:
        _backFromEducation();
      case _DesignNode.dismissed:
        _go(_DesignNode.today3aIntent);
      case _DesignNode.scenariosVersement:
        // R4 (batch22) integration: scenarios is now linearly reached from the
        // éclairage payoff — system back mirrors the screen back edge.
        _go(_DesignNode.eclairageImpot3a);
      case _DesignNode.factEtatCivil:
        // R4 (batch22) integration: fact_etat_civil is now linearly reached from
        // the éclairage refine OR scenarios.continue — system back mirrors the
        // origin-aware screen back edge.
        _backFromEtatCivil();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleSystemBack();
      },
      child: Focus(
        canRequestFocus: false,
        includeSemantics: false,
        onKeyEvent: (node, event) {
          _touchBatch16();
          return KeyEventResult.ignored;
        },
        child: Listener(
          onPointerDown: (_) => _touchBatch16(),
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _Header(
                    nodeId: _nodeId,
                    onExit: _showSafeExit,
                    exitFocusNode: _activeSafeExitFocus,
                    exitLabel: _node == _DesignNode.unresolvedAmountHelp
                        ? '${l10n.quit} · ${l10n.batch16RowContext(_multiProviderDraft.rows.indexWhere((row) => row.id == _unresolvedOrigin!.rowId) + 1, _taxYear!)}'
                        : null,
                    exitSortKey: _node == _DesignNode.unresolvedAmountHelp
                        ? const OrdinalSortKey(6)
                        : const OrdinalSortKey(1),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      key: ValueKey('journey-switcher:${widget.currentYear}'),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      child: KeyedSubtree(
                        key: ValueKey('node:$_nodeId'),
                        child: switch (_node) {
                          _DesignNode.today3aIntent => _Today(
                            onStart: () => _go(_DesignNode.orientation),
                          ),
                          _DesignNode.orientation => _Orientation(
                            // Phase B: orientation now leads straight to the LPP
                            // affiliation question (6-screen journey). The tax
                            // year is no longer a screen — it is seeded here as
                            // the default hypothesis (current calendar year),
                            // shown later in the éclairage eyebrow (Impôts ·
                            // {année}) and refinable in a future wave.
                            onContinue: () => setState(() {
                              _taxYear = widget.currentYear;
                              _node = _DesignNode.factLppAffiliation;
                            }),
                            onBack: () => _go(_DesignNode.today3aIntent),
                          ),
                          // Phase B: historical-unreachable renderer, retained
                          // for switch exhaustiveness (no inbound edge routes
                          // to factTaxYear anymore).
                          _DesignNode.factTaxYear => _TaxYear(
                            selectedYear: _taxYear,
                            currentYear: widget.currentYear,
                            onSelect: () => setState(() {
                              if (_taxYear != widget.currentYear) {
                                _clearContributionFacts();
                              }
                              _taxYear = widget.currentYear;
                            }),
                            onBack: () => _go(_DesignNode.orientation),
                            onContinue: () =>
                                _go(_DesignNode.factLppAffiliation),
                          ),
                          _DesignNode.factLppAffiliation => _LppQuestion(
                            selected: _lppAffiliation,
                            onChoose: (value) {
                              setState(() {
                                if (_lppAffiliation != value) {
                                  _clearContributionFacts();
                                }
                                _lppAffiliation = value;
                              });
                              _go(switch (value) {
                                _LppAffiliation.yes =>
                                  _DesignNode.factContribution,
                                _LppAffiliation.no =>
                                  _DesignNode.withoutLppBoundary,
                                _LppAffiliation.unknown =>
                                  _DesignNode.lppUnknownHelp,
                              });
                            },
                            onBack: () => _go(_DesignNode.orientation),
                          ),
                          _DesignNode.lppUnknownHelp => _LppUnknownHelp(
                            onBack: () => _go(_DesignNode.factLppAffiliation),
                          ),
                          _DesignNode.withoutLppBoundary => _WithoutLppBoundary(
                            onBack: () => _go(_DesignNode.factLppAffiliation),
                          ),
                          _DesignNode.factContribution => _ContributionQuestion(
                            taxYear: _taxYear!,
                            selected: _contributionStatus,
                            edgeHelpExpanded: _contributionEdgeHelpExpanded,
                            onToggleEdgeHelp: () => setState(
                              () => _contributionEdgeHelpExpanded =
                                  !_contributionEdgeHelpExpanded,
                            ),
                            onChoose: (value) {
                              setState(() {
                                if (_contributionStatus != value) {
                                  _clearContributionAmount();
                                }
                                _contributionStatus = value;
                                if (widget.enableBatch14MultiProvider &&
                                    value == _ContributionStatus.yes) {
                                  _multiProviderDraft.invalidateConfirmation();
                                }
                              });
                              _go(switch (value) {
                                _ContributionStatus.yes =>
                                  _DesignNode.factContributedAmount,
                                // Commune-directe pivot (Julien 2026-08-04): the
                                // "no contribution" branch reaches the fused
                                // fact_lieu node (national commune search, canton
                                // derived) in place of the standalone fact_canton.
                                _ContributionStatus.no => _DesignNode.factLieu,
                                _ContributionStatus.unknown =>
                                  _DesignNode.contributionUnknownHelp,
                              });
                            },
                            onBack: () => _go(_DesignNode.factLppAffiliation),
                          ),
                          _DesignNode.contributionUnknownHelp =>
                            _ContributionUnknownHelp(
                              taxYear: _taxYear!,
                              onContinueEducation: () {
                                _educationBackNode =
                                    _DesignNode.contributionUnknownHelp;
                                _go(_DesignNode.educationExplanation);
                              },
                              onBack: () => _go(_DesignNode.factContribution),
                            ),
                          _DesignNode.factContributedAmount =>
                            widget.enableBatch14MultiProvider
                                ? _Page(
                                    nodeId: 'fact_contributed_amount',
                                    eyebrow: l10n.batch11AmountEyebrow(
                                      _taxYear!,
                                    ),
                                    title: l10n.batch11AmountTitle(_taxYear!),
                                    body: l10n.batch14AmountBody,
                                    accent: MultiProviderAmountEditor(
                                      taxYear: _taxYear!,
                                      draft: _multiProviderDraft,
                                      onCommitted: (totalMinorUnits) {
                                        // V4-2 (Codex P1-2): the committed
                                        // multi-provider total is the real
                                        // already-contributed amount → feed it
                                        // into the scenarios margin in RAPPEN
                                        // (minor units). No ~/100 truncation: the
                                        // scenarios screen is now rappen-native and
                                        // floors only at display.
                                        setState(
                                          () => _scenariosContributedRappen =
                                              totalMinorUnits,
                                        );
                                        _go(_DesignNode.factLieu);
                                      },
                                      enableBatch16:
                                          widget.enableBatch16Unresolved,
                                      onAmountDoubt: _openBatch16Help,
                                      onDraftChanged: () {
                                        if (mounted) setState(() {});
                                      },
                                      restoreRowId: _restoreBatch16RowId,
                                      restoreFocusTarget:
                                          switch (_restoreBatch16Target) {
                                            'amount' =>
                                              MultiProviderAmountEditorFocusTarget
                                                  .amount,
                                            'doubt' =>
                                              MultiProviderAmountEditorFocusTarget
                                                  .doubt,
                                            'undo' =>
                                              MultiProviderAmountEditorFocusTarget
                                                  .undo,
                                            'continue' =>
                                              MultiProviderAmountEditorFocusTarget
                                                  .continueAction,
                                            _ => null,
                                          },
                                      restoreAmountFocus: _restoreAmountFocus,
                                      restoreUnknownActionFocus:
                                          _restoreUnknownActionFocus,
                                      onRestoreFocusConsumed: () {
                                        if (mounted &&
                                            (_restoreAmountFocus ||
                                                _restoreUnknownActionFocus ||
                                                _restoreBatch16RowId != null ||
                                                _restoreBatch16Target !=
                                                    null)) {
                                          setState(() {
                                            _restoreAmountFocus = false;
                                            _restoreUnknownActionFocus = false;
                                            _restoreBatch16RowId = null;
                                            _restoreBatch16Target = null;
                                          });
                                        }
                                      },
                                      onUnknown: () => setState(() {
                                        _amountHelpPartial = false;
                                        _node = _DesignNode
                                            .contributedAmountUnknownHelp;
                                      }),
                                      onCorrectPrevious: () {
                                        _backFromContributionAmount();
                                      },
                                    ),
                                    actions: const [],
                                  )
                                : _ContributionAmountForm(
                                    taxYear: _taxYear!,
                                    providerController: _providerNameController,
                                    amountController: _ordinaryAmountController,
                                    allProvidersReviewed: _allProvidersReviewed,
                                    whereToFindExpanded:
                                        _amountWhereToFindExpanded,
                                    restoreAmountFocus: _restoreAmountFocus,
                                    restoreUnknownActionFocus:
                                        _restoreUnknownActionFocus,
                                    onRestoreFocusConsumed: () {
                                      if (mounted &&
                                          (_restoreAmountFocus ||
                                              _restoreUnknownActionFocus)) {
                                        setState(() {
                                          _restoreAmountFocus = false;
                                          _restoreUnknownActionFocus = false;
                                        });
                                      }
                                    },
                                    onReviewedChanged: (value) {
                                      if (value && _multipleProvidersDeclared) {
                                        return;
                                      }
                                      setState(
                                        () => _allProvidersReviewed = value,
                                      );
                                    },
                                    onWhereToFindChanged: (value) => setState(
                                      () => _amountWhereToFindExpanded = value,
                                    ),
                                    onUnknown: () => setState(() {
                                      _amountHelpPartial = false;
                                      _node = _DesignNode
                                          .contributedAmountUnknownHelp;
                                    }),
                                    onMissing: () => setState(() {
                                      _allProvidersReviewed = false;
                                      _multipleProvidersDeclared = true;
                                      _amountHelpPartial = true;
                                      _node = _DesignNode
                                          .contributedAmountUnknownHelp;
                                    }),
                                    onContinue: (contributedMinorUnits) {
                                      if (!_multipleProvidersDeclared) {
                                        // V4-2 (Codex P1-2): feed the real
                                        // already-contributed amount into the
                                        // scenarios margin (plafond − versé) in
                                        // RAPPEN. parseOrdinaryChfAmount returns
                                        // MINOR UNITS; carry them verbatim — the
                                        // scenarios screen is rappen-native and
                                        // floors only at display (no centime
                                        // truncation at entry).
                                        setState(
                                          () => _scenariosContributedRappen =
                                              contributedMinorUnits,
                                        );
                                        _go(_DesignNode.factLieu);
                                      }
                                    },
                                    onCorrectPrevious:
                                        _backFromContributionAmount,
                                  ),
                          _DesignNode.contributedAmountUnknownHelp =>
                            _ContributedAmountUnknownHelp(
                              partial: _amountHelpPartial,
                              onFoundAmount: () {
                                if (_amountHelpPartial) {
                                  setState(() {
                                    _multipleProvidersDeclared = false;
                                    _restoreAmountFocus = true;
                                    _restoreUnknownActionFocus = false;
                                    _node = _DesignNode.factContributedAmount;
                                  });
                                } else {
                                  _returnToAmountField();
                                }
                              },
                              onContinueEducation: () {
                                _educationBackNode =
                                    _DesignNode.contributedAmountUnknownHelp;
                                _go(_DesignNode.educationExplanation);
                              },
                              onBack: _returnToUnknownAmountTrigger,
                            ),
                          _DesignNode.unresolvedAmountHelp =>
                            _Batch16UnresolvedHelp(
                              taxYear: _taxYear!,
                              rowNumber:
                                  _multiProviderDraft.rows.indexWhere(
                                    (row) => row.id == _unresolvedOrigin!.rowId,
                                  ) +
                                  1,
                              origin: _unresolvedOrigin!,
                              refundEligible:
                                  _multiProviderDraft.activeRowCount > 1 &&
                                  _multiProviderDraft.rows.any(
                                    (row) =>
                                        row.isActive &&
                                        row.id != _unresolvedOrigin!.rowId &&
                                        row.hasPositiveExactAmount,
                                  ),
                              restoreTarget: _helpRestoreTarget,
                              onProviderTotal: _resolveBatch16ProviderTotal,
                              onRefund: _refundBatch16Provider,
                              onAllZero: _beginBatch16AllZero,
                              onEducation: () {
                                _educationBackNode =
                                    _DesignNode.unresolvedAmountHelp;
                                _go(_DesignNode.educationExplanation);
                              },
                              onBack: _returnFromBatch16Help,
                            ),
                          _DesignNode.contributionStatusCorrection =>
                            _Batch16ContributionCorrection(
                              taxYear: _taxYear!,
                              onChoose: _chooseBatch16Correction,
                              onBack: () => _returnToBatch16Help('all_zero'),
                            ),
                          _DesignNode.factCanton => CantonR1Screen(
                            taxYear: _taxYear!,
                            hasPositiveContribution:
                                _contributionStatus == _ContributionStatus.yes,
                            onBack: _backFromCanton,
                          ),
                          _DesignNode.factLieu => FactLieuScreen(
                            taxYear: _taxYear!,
                            // ÉCLAIRAGE integration (batch21): the guarded
                            // fact_lieu continue now routes forward to the R3
                            // fact_revenu node once a commune is selected,
                            // superseding the batch20 R2 outbound-edge
                            // obligation (registry.deferred_integration).
                            onContinue: () => _go(_DesignNode.factRevenu),
                            // R4 (batch22): lift the picked commune LABEL up so
                            // the éclairage payoff shows the user's actual
                            // commune, never the hardcoded fixture (roast P1-1i).
                            onCommuneSelected:
                                (commune, canton, cantonCode, bfs) =>
                                    setState(() {
                                      _eclairageCommune = commune;
                                      _eclairageCanton = canton;
                                      // V3-1 (Codex P1-1): track the picked canton
                                      // CODE so the éclairage can disclose when the
                                      // hero range (FR fixture) is not the user's
                                      // canton.
                                      _eclairageCantonCode = cantonCode;
                                      // V4-1 (Codex P1-1): track the picked commune
                                      // BFS so the disclosure is by EXACT locality
                                      // (chef-lieu vs another FR commune vs another
                                      // canton), not merely by canton.
                                      _eclairageBfs = bfs;
                                    }),
                          ),
                          // R3 batch21 — the ÉCLAIRAGE arc. fact_revenu commits a
                          // band without routing (continue never routes in R3);
                          // eclairage renders the payoff state from the committed
                          // facts. Forward controls never route (next_action is
                          // out of R3 scope); edit/back reopen within the arc.
                          _DesignNode.factRevenu => FactRevenuScreen(
                            taxYear: _taxYear!,
                            selectedBand: _taxableIncomeBand,
                            onSelectBand: (band) =>
                                setState(() => _taxableIncomeBand = band),
                            onBack: () => _go(_DesignNode.factLieu),
                            // ÉCLAIRAGE integration (batch21): a committed band
                            // routes forward to the eclairage payoff node; with
                            // no band the guard surfaces error_no_selection and
                            // never routes (fact_revenu continue guard).
                            onContinue: () =>
                                _go(_DesignNode.eclairageImpot3a),
                          ),
                          _DesignNode.eclairageImpot3a => EclairageScreen(
                            taxYear: _taxYear!,
                            band: _taxableIncomeBand,
                            // R4 (batch22): the commune the user actually picked
                            // in fact_lieu (default = the graved fixture example
                            // for harness paths that skip fact_lieu). The engine
                            // number stays the canton-FR fixture (offline-lab
                            // limitation, disclaimed) — this is the LABEL only.
                            communeLabel: _eclairageCommune,
                            cantonLabel: _eclairageCanton,
                            // V4-1 (Codex P1-1): disclose the FR chef-lieu fixture
                            // basis by EXACT locality — none at the chef-lieu,
                            // intra-cantonal for another FR commune, inter-cantonal
                            // for another canton (locale-robust BFS + code, never a
                            // label). The label stays the real commune.
                            lieuDisclosure: eclairageLieuDisclosureFor(
                              bfs: _eclairageBfs,
                              cantonCode: _eclairageCantonCode,
                            ),
                            canContribute3a:
                                widget.batch21?.canContribute ?? true,
                            // R4 (batch22) integration: the situation hypothesis
                            // DERIVES from the committed civil status once the
                            // user has refined it (fact_etat_civil), else falls
                            // back to the R3 default (célibataire). The value
                            // stays display-only — the row's NUMBER never gets a
                            // fabricated married ×0.80 (NEVER#3 / sealed R4_13).
                            initialSituation: _batch22CivilStatus != null
                                ? _situationFromCivilStatus(_batch22CivilStatus)
                                : (widget.batch21?.situation ??
                                    EclairageSituation.celibataire),
                            initialExactIncome: widget.batch21?.exactIncome,
                            onBack: () => _go(_DesignNode.factRevenu),
                            // R4 (batch22) integration: continue now routes to
                            // the scenarios_versement fermeture node (superseding
                            // the R3 kept boundary on this edge).
                            onContinue: _enterScenariosFromEclairage,
                            onEditRevenu: () => _go(_DesignNode.factRevenu),
                            onEditLieu: () => _go(_DesignNode.factLieu),
                            onPendingComplete: () =>
                                _go(_DesignNode.factRevenu),
                            // R4 (batch22) integration: the situation row's
                            // refine affordance opens the civil-status node
                            // (origin-aware back returns to the payoff).
                            onRefineSituation: _refineSituationToEtatCivil,
                          ),
                          _DesignNode.educationExplanation =>
                            _EducationBoundary(onBack: _backFromEducation),
                          _DesignNode.dismissed => _Terminal(
                            title: l10n.dismissedTitle,
                            onRestart: () => _go(_DesignNode.today3aIntent),
                          ),
                          // R4 batch22 — the fermeture-de-boucle loop is now
                          // CLOSED by this integration batch. Inbound:
                          // eclairage.continue -> scenarios (via
                          // _enterScenariosFromEclairage) and eclairage situation
                          // refine -> fact_etat_civil. Outbound (this wave):
                          // scenarios.continue -> fact_etat_civil (registry
                          // order) ; scenarios.back -> eclairage ;
                          // scenarios.keep_local_reference persists + STAYS on
                          // the node (announced) ; fact_etat_civil.continue ->
                          // eclairage (situation re-derives, display-only —
                          // never a fabricated married ×0.80, NEVER#3) ;
                          // fact_etat_civil.back is origin-aware. Still inert:
                          // scenarios.pending complete_action and
                          // review_existing_overcontribution (boundary nodes out
                          // of scope). The married RECOMPUTE stays a later
                          // backend batch (L2 sensitivity, NEVER#3).
                          _DesignNode.scenariosVersement =>
                            ScenariosVersementScreen(
                              taxYear: _scenariosTaxYear,
                              commune: _scenariosCommune,
                              canton: _scenariosCanton,
                              band: _scenariosBand,
                              affiliated: _scenariosAffiliated,
                              contributedRappen: _scenariosContributedRappen,
                              nonAffiliatedIncomeChf:
                                  _scenariosNonAffiliatedIncomeChf,
                              referenceKept: _scenariosReferenceKept,
                              // R4 (batch22): the own-amount lives in the PARENT
                              // so it survives a fermeture loop turn (roast
                              // P1-1ii). Seed from the preserved value; report
                              // changes back up.
                              initialOwnAmountChf: _scenariosOwnAmountChf,
                              onOwnAmountChanged: (value) => setState(
                                () => _scenariosOwnAmountChf = value,
                              ),
                              onBack: () => _go(_DesignNode.eclairageImpot3a),
                              onContinue: _enterEtatCivilFromScenarios,
                              onPendingComplete: () {},
                              onKeepLocalReference: _keepScenariosReference,
                              onReviewExistingOvercontribution: () {},
                            ),
                          _DesignNode.factEtatCivil => FactEtatCivilScreen(
                            taxYear: widget.currentYear,
                            selectedStatus: _batch22CivilStatus,
                            onSelectStatus: (status) =>
                                setState(() => _batch22CivilStatus = status),
                            onBack: _backFromEtatCivil,
                            onContinue: _continueFromEtatCivil,
                          ),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.nodeId,
    required this.onExit,
    required this.exitFocusNode,
    this.exitLabel,
    required this.exitSortKey,
  });
  final String nodeId;
  final VoidCallback onExit;
  final FocusNode exitFocusNode;
  final String? exitLabel;
  final SemanticsSortKey exitSortKey;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compactWidth = viewportWidth > 0 && viewportWidth <= 320;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: l10n.brand,
              sortKey: const OrdinalSortKey(0),
              child: ExcludeSemantics(
                child: Text(
                  largeText ? 'm.' : l10n.brand,
                  style: const TextStyle(
                    fontFamily: 'Supreme',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 3.2,
                    color: _ink,
                  ),
                ),
              ),
            ),
          ),
          if (largeText || compactWidth)
            Semantics(
              label: exitLabel ?? l10n.quitJourney,
              button: true,
              onTap: onExit,
              excludeSemantics: true,
              sortKey: exitSortKey,
              child: IconButton(
                key: ValueKey('action:$nodeId.open_safe_exit'),
                focusNode: exitFocusNode,
                tooltip: exitLabel ?? l10n.quitJourney,
                onPressed: onExit,
                icon: const ExcludeSemantics(
                  child: Text(
                    '×',
                    style: TextStyle(fontFamily: 'Supreme', fontSize: 28),
                  ),
                ),
              ),
            )
          else
            MintDesignLabAction.text(
              key: ValueKey('action:$nodeId.open_safe_exit'),
              label: exitLabel ?? l10n.quit,
              semanticsLabel: exitLabel ?? l10n.quitJourney,
              semanticsSortKey: exitSortKey,
              focusNode: exitFocusNode,
              onPressed: onExit,
              compact: true,
            ),
        ],
      ),
    );
  }
}

class _Today extends StatelessWidget {
  const _Today({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    return _Page(
      nodeId: 'today_3a_intent',
      eyebrow: l10n.todayEyebrow,
      title: l10n.todayTitle,
      body: l10n.todayBody,
      accent: const _QuietOrb(),
      actions: [
        MintDesignLabAction(
          key: const ValueKey('action:today_3a_intent.start'),
          label: largeText ? l10n.startShort : l10n.start,
          onPressed: onStart,
        ),
      ],
    );
  }
}

class _Orientation extends StatelessWidget {
  const _Orientation({required this.onContinue, required this.onBack});
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'orientation',
      eyebrow: l10n.orientationEyebrow,
      title: l10n.orientationTitle,
      body: l10n.orientationBody,
      accent: _EditorialNote(text: l10n.orientationNote),
      actions: [
        MintDesignLabAction(
          key: const ValueKey('action:orientation.continue'),
          label: l10n.continueLabel,
          onPressed: onContinue,
        ),
        MintDesignLabAction.text(
          key: const ValueKey('action:orientation.back'),
          label: l10n.backLabel,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _TaxYear extends StatelessWidget {
  const _TaxYear({
    required this.selectedYear,
    required this.currentYear,
    required this.onSelect,
    required this.onBack,
    required this.onContinue,
  });
  final int? selectedYear;
  final int currentYear;
  final VoidCallback onSelect;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    final year = currentYear;
    return _Page(
      nodeId: 'fact_tax_year',
      eyebrow: l10n.taxYearEyebrow,
      title: l10n.taxYearTitle,
      body: l10n.taxYearBody,
      accent: Semantics(
        excludeSemantics: true,
        selected: selectedYear == year,
        button: true,
        label: l10n.currentYearLabel(year),
        onTap: onSelect,
        child: InkWell(
          key: const ValueKey('action:fact_tax_year.confirm_current_year'),
          onTap: onSelect,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: selectedYear == year ? _sage : _porcelain,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selectedYear == year ? _ink : _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.confirmYear(year),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Icon(
                  selectedYear == year
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (selectedYear == year)
          MintDesignLabAction(
            key: const ValueKey('action:fact_tax_year.continue'),
            label: l10n.continueLabel,
            onPressed: onContinue,
          ),
        MintDesignLabAction.text(
          key: const ValueKey('action:fact_tax_year.back'),
          label: l10n.backLabel,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _LppQuestion extends StatelessWidget {
  const _LppQuestion({
    required this.selected,
    required this.onChoose,
    required this.onBack,
  });

  final _LppAffiliation? selected;
  final ValueChanged<_LppAffiliation> onChoose;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'fact_lpp_affiliation',
      eyebrow: l10n.lppQuestionEyebrow,
      title: l10n.lppQuestionTitle,
      body: l10n.lppQuestionBody,
      accent: _EditorialNote(text: l10n.lppQuestionEvidence),
      actions: [
        Semantics(
          key: const ValueKey('group:fact_lpp_affiliation.choices'),
          container: true,
          explicitChildNodes: true,
          label: l10n.lppQuestionTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChoiceAction(
                actionId: 'action:fact_lpp_affiliation.choose_yes',
                label: l10n.lppChoiceYes,
                selected: selected == _LppAffiliation.yes,
                onPressed: () => onChoose(_LppAffiliation.yes),
              ),
              const SizedBox(height: 6),
              _ChoiceAction(
                actionId: 'action:fact_lpp_affiliation.choose_no',
                label: l10n.lppChoiceNo,
                selected: selected == _LppAffiliation.no,
                onPressed: () => onChoose(_LppAffiliation.no),
              ),
              const SizedBox(height: 6),
              _ChoiceAction(
                actionId: 'action:fact_lpp_affiliation.choose_unknown',
                label: l10n.lppChoiceUnknown,
                selected: selected == _LppAffiliation.unknown,
                onPressed: () => onChoose(_LppAffiliation.unknown),
              ),
            ],
          ),
        ),
        MintDesignLabAction.text(
          key: const ValueKey('action:fact_lpp_affiliation.back'),
          label: l10n.backLabel,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _ChoiceAction extends StatelessWidget {
  const _ChoiceAction({
    required this.actionId,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String actionId;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: label,
    onTap: onPressed,
    excludeSemantics: true,
    child: MintDesignLabAction.secondary(
      key: ValueKey(actionId),
      label: selected ? '✓  $label' : label,
      onPressed: onPressed,
    ),
  );
}

class _LppUnknownHelp extends StatelessWidget {
  const _LppUnknownHelp({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'lpp_unknown_help',
      eyebrow: l10n.lppUnknownEyebrow,
      title: l10n.lppUnknownTitle,
      body: l10n.lppUnknownBody,
      accent: Semantics(
        label: l10n.lppUnknownListLabel,
        child: Column(
          children:
              [
                    l10n.lppUnknownPayslip,
                    l10n.lppUnknownCertificate,
                    l10n.lppUnknownAsk,
                  ]
                  .asMap()
                  .entries
                  .map(
                    (entry) =>
                        _ChecklistRow(number: entry.key + 1, text: entry.value),
                  )
                  .toList(),
        ),
      ),
      actions: [
        MintDesignLabAction(
          key: const ValueKey('action:lpp_unknown_help.back'),
          label: l10n.lppBackToQuestion,
          onPressed: onBack,
        ),
        _UnavailableReference(
          key: const ValueKey('action:lpp_unknown_help.keep_checklist_local'),
          label: l10n.lppKeepChecklist,
          unavailable: l10n.localReferenceUnavailable,
        ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _sage),
          child: Text('$number', style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _WithoutLppBoundary extends StatelessWidget {
  const _WithoutLppBoundary({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'without_lpp_boundary',
      eyebrow: l10n.withoutLppEyebrow,
      title: l10n.withoutLppTitle,
      body: l10n.withoutLppBody,
      accent: const _QuietOrb(),
      actions: [
        MintDesignLabAction(
          key: const ValueKey('action:without_lpp_boundary.back'),
          label: l10n.lppCorrectAnswer,
          onPressed: onBack,
        ),
        _UnavailableReference(
          key: const ValueKey(
            'action:without_lpp_boundary.keep_explanation_local',
          ),
          label: l10n.withoutLppKeepExplanation,
          unavailable: l10n.localReferenceUnavailable,
        ),
      ],
    );
  }
}

class _UnavailableReference extends StatelessWidget {
  const _UnavailableReference({
    super.key,
    required this.label,
    required this.unavailable,
  });

  final String label;
  final String unavailable;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    enabled: false,
    readOnly: true,
    label: '$label. $unavailable',
    excludeSemantics: true,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _porcelain,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 20, color: _secondaryInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label · $unavailable',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ContributionQuestion extends StatelessWidget {
  const _ContributionQuestion({
    required this.taxYear,
    required this.selected,
    required this.edgeHelpExpanded,
    required this.onToggleEdgeHelp,
    required this.onChoose,
    required this.onBack,
  });

  final int taxYear;
  final _ContributionStatus? selected;
  final bool edgeHelpExpanded;
  final VoidCallback onToggleEdgeHelp;
  final ValueChanged<_ContributionStatus> onChoose;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'fact_contribution',
      eyebrow: l10n.contributionEyebrow(taxYear),
      title: l10n.contributionTitle(taxYear),
      body: l10n.contributionBody,
      accent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EditorialNote(text: l10n.contributionCreditedNote(taxYear)),
          const SizedBox(height: 12),
          Text(
            l10n.contributionAmountNote,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _DisclosureAction(
            label: l10n.contributionEdgeHelp,
            expanded: edgeHelpExpanded,
            onPressed: onToggleEdgeHelp,
          ),
          if (edgeHelpExpanded) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('content:fact_contribution.edge_help'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              decoration: BoxDecoration(
                color: _porcelain,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  l10n.contributionEdgePending,
                  l10n.contributionEdgeTransfer,
                  l10n.contributionEdgeBuyback,
                  l10n.contributionEdgeFullRefund,
                  l10n.contributionEdgePartialRefund,
                  l10n.contributionEdgeUnclearCorrection,
                  l10n.contributionEdgeMixedTransfer,
                  l10n.contributionEdgeReturn,
                  l10n.contributionEdgeAdjustment,
                ].map((text) => _MovementRule(text: text)).toList(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        Semantics(
          key: const ValueKey('group:fact_contribution.choices'),
          container: true,
          explicitChildNodes: true,
          label: l10n.contributionChoiceGroupLabel(taxYear),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChoiceAction(
                actionId: 'action:fact_contribution.choose_yes',
                label: l10n.contributionChoiceYes,
                selected: selected == _ContributionStatus.yes,
                onPressed: () => onChoose(_ContributionStatus.yes),
              ),
              const SizedBox(height: 6),
              _ChoiceAction(
                actionId: 'action:fact_contribution.choose_no',
                label: l10n.contributionChoiceNo,
                selected: selected == _ContributionStatus.no,
                onPressed: () => onChoose(_ContributionStatus.no),
              ),
              const SizedBox(height: 6),
              _ChoiceAction(
                actionId: 'action:fact_contribution.choose_unknown',
                label: l10n.contributionChoiceUnknown,
                selected: selected == _ContributionStatus.unknown,
                onPressed: () => onChoose(_ContributionStatus.unknown),
              ),
            ],
          ),
        ),
        MintDesignLabAction.text(
          key: const ValueKey('action:fact_contribution.back'),
          label: l10n.backLabel,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _DisclosureAction extends StatelessWidget {
  const _DisclosureAction({
    required this.label,
    required this.expanded,
    required this.onPressed,
    this.actionKey = const ValueKey(
      'action:fact_contribution.toggle_edge_help',
    ),
    this.focusNode,
    this.semanticsSortKey,
    this.semanticsLabel,
  });

  final String label;
  final bool expanded;
  final VoidCallback onPressed;
  final Key actionKey;
  final FocusNode? focusNode;
  final SemanticsSortKey? semanticsSortKey;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    expanded: expanded,
    label: semanticsLabel ?? label,
    sortKey: semanticsSortKey,
    onTap: onPressed,
    excludeSemantics: true,
    child: InkWell(
      key: actionKey,
      focusNode: focusNode,
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    ),
  );
}

class _MovementRule extends StatelessWidget {
  const _MovementRule({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(Icons.arrow_right_rounded, size: 20, color: _coral),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _ContributionUnknownHelp extends StatelessWidget {
  const _ContributionUnknownHelp({
    required this.taxYear,
    required this.onContinueEducation,
    required this.onBack,
  });

  final int taxYear;
  final VoidCallback onContinueEducation;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'contribution_unknown_help',
      eyebrow: l10n.contributionUnknownEyebrow,
      title: l10n.contributionUnknownTitle,
      body: l10n.contributionUnknownBody(taxYear),
      accent: Semantics(
        label: l10n.contributionUnknownListLabel,
        child: Column(
          children:
              [
                    l10n.contributionUnknownProviderStatement(taxYear),
                    l10n.contributionUnknownInsuranceCertificate,
                    l10n.contributionUnknownProviderQuestion,
                    l10n.contributionUnknownTransferWarning,
                    l10n.contributionUnknownEducationLimit,
                  ]
                  .asMap()
                  .entries
                  .map(
                    (entry) =>
                        _ChecklistRow(number: entry.key + 1, text: entry.value),
                  )
                  .toList(),
        ),
      ),
      actions: [
        MintDesignLabAction(
          key: const ValueKey(
            'action:contribution_unknown_help.continue_education_only',
          ),
          label: l10n.contributionUnknownContinueEducation,
          onPressed: onContinueEducation,
        ),
        MintDesignLabAction.text(
          key: const ValueKey('action:contribution_unknown_help.back'),
          label: l10n.contributionBackToQuestion,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _ContributedAmountUnknownHelp extends StatelessWidget {
  const _ContributedAmountUnknownHelp({
    required this.partial,
    required this.onFoundAmount,
    required this.onContinueEducation,
    required this.onBack,
  });

  final bool partial;
  final VoidCallback onFoundAmount;
  final VoidCallback onContinueEducation;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'contributed_amount_unknown_help',
      eyebrow: l10n.contributionUnknownEyebrow,
      title: l10n.batch11HelpTitle,
      body: partial ? l10n.batch11HelpPartialBody : l10n.batch11HelpUnknownBody,
      accent: const _QuietOrb(),
      actions: [
        if (partial)
          MintDesignLabAction(
            key: const ValueKey(
              'action:contributed_amount_unknown_help.continue_education_only',
            ),
            label: l10n.batch11HelpEducationOnly,
            onPressed: onContinueEducation,
          )
        else
          MintDesignLabAction(
            key: const ValueKey(
              'action:contributed_amount_unknown_help.found_amount',
            ),
            label: l10n.batch11HelpFoundFirst,
            onPressed: onFoundAmount,
          ),
        if (partial)
          MintDesignLabAction.secondary(
            key: const ValueKey(
              'action:contributed_amount_unknown_help.found_amount',
            ),
            label: l10n.batch11HelpFoundPartial,
            onPressed: onFoundAmount,
          )
        else
          MintDesignLabAction.secondary(
            key: const ValueKey(
              'action:contributed_amount_unknown_help.continue_education_only',
            ),
            label: l10n.batch11HelpEducationOnly,
            onPressed: onContinueEducation,
          ),
        if (!partial)
          MintDesignLabAction.text(
            key: const ValueKey('action:contributed_amount_unknown_help.back'),
            label: l10n.batch11HelpBack,
            onPressed: onBack,
          ),
      ],
    );
  }
}

class _ContributionAmountForm extends StatefulWidget {
  const _ContributionAmountForm({
    required this.taxYear,
    required this.providerController,
    required this.amountController,
    required this.allProvidersReviewed,
    required this.whereToFindExpanded,
    required this.restoreAmountFocus,
    required this.restoreUnknownActionFocus,
    required this.onRestoreFocusConsumed,
    required this.onReviewedChanged,
    required this.onWhereToFindChanged,
    required this.onUnknown,
    required this.onMissing,
    required this.onContinue,
    required this.onCorrectPrevious,
  });
  final int taxYear;
  final TextEditingController providerController;
  final TextEditingController amountController;
  final bool allProvidersReviewed;
  final bool whereToFindExpanded;
  final bool restoreAmountFocus;
  final bool restoreUnknownActionFocus;
  final VoidCallback onRestoreFocusConsumed;
  final ValueChanged<bool> onReviewedChanged;
  final ValueChanged<bool> onWhereToFindChanged;
  final VoidCallback onUnknown;
  final VoidCallback onMissing;
  // V3-2 (Codex P1-2): carries the parsed already-contributed CHF up to the
  // journey so _scenariosContributedChf reflects the real value entered here —
  // the scenarios margin becomes plafond − versé (never a silent 0).
  final ValueChanged<int> onContinue;
  final VoidCallback onCorrectPrevious;

  @override
  State<_ContributionAmountForm> createState() =>
      _ContributionAmountFormState();
}

class _ContributionAmountFormState extends State<_ContributionAmountForm> {
  final FocusNode _providerFocus = FocusNode(debugLabel: 'provider name');
  final FocusNode _amountFocus = FocusNode(debugLabel: 'ordinary amount');
  final FocusNode _reviewedFocus = FocusNode(debugLabel: 'provider review');
  final FocusNode _unknownActionFocus = FocusNode(
    debugLabel: 'unknown amount trigger',
  );
  String? _providerError;
  String? _amountError;
  bool _reviewedError = false;

  @override
  void initState() {
    super.initState();
    if (widget.restoreAmountFocus || widget.restoreUnknownActionFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final target = widget.restoreAmountFocus
              ? _amountFocus
              : _unknownActionFocus;
          target.requestFocus();
          final focusContext = target.context;
          if (focusContext != null) {
            Scrollable.ensureVisible(focusContext, alignment: 0.35);
          }
          widget.onRestoreFocusConsumed();
        });
      });
    }
  }

  @override
  void dispose() {
    _providerFocus.dispose();
    _amountFocus.dispose();
    _reviewedFocus.dispose();
    _unknownActionFocus.dispose();
    super.dispose();
  }

  void _continue() {
    final providerMissing = widget.providerController.text.trim().isEmpty;
    final providerUnsafe =
        !providerMissing &&
        !providerLabelIsSafe(widget.providerController.text);
    final l10n = MintNextLocalizations.of(context);
    int? amount;
    try {
      amount = parseOrdinaryChfAmount(
        widget.amountController.text,
        locale: Localizations.localeOf(context).languageCode,
      );
    } on FormatException {
      amount = null;
    }
    setState(() {
      _providerError = providerMissing
          ? l10n.batch11ProviderNameEmpty
          : providerUnsafe
          ? l10n.batch11ProviderNameSensitive
          : null;
      _amountError = amount == null
          ? l10n.batch11AmountInvalid
          : amount == 0
          ? l10n.batch11AmountZero
          : null;
      _reviewedError = !widget.allProvidersReviewed;
    });
    if (providerMissing || providerUnsafe) {
      _providerFocus.requestFocus();
      return;
    }
    if (_amountError != null) {
      _amountFocus.requestFocus();
      return;
    }
    if (_reviewedError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _reviewedFocus.requestFocus();
        final focusContext = _reviewedFocus.context;
        if (focusContext != null) {
          Scrollable.ensureVisible(focusContext, alignment: 0.5);
        }
      });
      return;
    }
    // V3-2 (Codex P1-2): the guards above guarantee amount is non-null and > 0;
    // carry it up so the scenarios margin is plafond − versé (never a silent 0).
    widget.onContinue(amount!);
  }

  bool get _hasPositiveDraft {
    try {
      return parseOrdinaryChfAmount(
            widget.amountController.text,
            locale: Localizations.localeOf(context).languageCode,
          ) >
          0;
    } on FormatException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'fact_contributed_amount',
      eyebrow: l10n.batch11AmountEyebrow(widget.taxYear),
      title: l10n.batch11AmountTitle(widget.taxYear),
      body: l10n.batch11AmountBody,
      accent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('field:fact_contributed_amount.provider_name'),
            controller: widget.providerController,
            focusNode: _providerFocus,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.batch11ProviderNameLabel,
              errorText: _providerError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (widget.allProvidersReviewed) {
                widget.onReviewedChanged(false);
              }
              if (_providerError != null) {
                setState(() => _providerError = null);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            l10n.batch11ProviderNamePrivacy,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_providerError != null)
            Semantics(
              key: const ValueKey(
                'error:fact_contributed_amount.provider_name',
              ),
              liveRegion: true,
              label: _providerError,
              child: const SizedBox.shrink(),
            ),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('field:fact_contributed_amount.amount'),
            controller: widget.amountController,
            focusNode: _amountFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.batch11OrdinaryAmountLabel(widget.taxYear),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixText: 'CHF',
              errorText: _amountError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (widget.allProvidersReviewed) {
                widget.onReviewedChanged(false);
              }
              setState(() => _amountError = null);
            },
          ),
          if (_amountError != null)
            Semantics(
              key: const ValueKey('error:fact_contributed_amount.amount'),
              liveRegion: true,
              label: _amountError,
              child: const SizedBox.shrink(),
            ),
          const SizedBox(height: 8),
          Text(
            l10n.batch11NotTaxResult,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            key: const ValueKey(
              'action:fact_contributed_amount.toggle_all_reviewed',
            ),
            contentPadding: EdgeInsets.zero,
            focusNode: _reviewedFocus,
            value: widget.allProvidersReviewed,
            title: Text(l10n.batch11AllProvidersReviewed(widget.taxYear)),
            subtitle: _reviewedError
                ? Semantics(
                    key: const ValueKey(
                      'error:fact_contributed_amount.all_reviewed',
                    ),
                    liveRegion: true,
                    label: l10n.batch11ReviewAllRequired,
                    child: Text(l10n.batch11ReviewAllRequired),
                  )
                : null,
            onChanged: (value) {
              widget.onReviewedChanged(value ?? false);
              if (_reviewedError) setState(() => _reviewedError = false);
            },
          ),
          Semantics(
            key: const ValueKey(
              'action:fact_contributed_amount.toggle_where_to_find',
            ),
            button: true,
            expanded: widget.whereToFindExpanded,
            label: l10n.batch11WhereFindTitle,
            onTap: () =>
                widget.onWhereToFindChanged(!widget.whereToFindExpanded),
            child: ExcludeSemantics(
              child: TextButton(
                onPressed: () =>
                    widget.onWhereToFindChanged(!widget.whereToFindExpanded),
                child: Text(l10n.batch11WhereFindTitle),
              ),
            ),
          ),
          if (widget.whereToFindExpanded)
            Text(
              l10n.batch11WhereFindBody,
              key: const ValueKey(
                'content:fact_contributed_amount.where_to_find',
              ),
            ),
        ],
      ),
      actions: [
        MintDesignLabAction(
          key: const ValueKey('action:fact_contributed_amount.continue'),
          label: l10n.batch11Continue,
          onPressed: _continue,
        ),
        if (_hasPositiveDraft && !widget.allProvidersReviewed)
          MintDesignLabAction.secondary(
            key: const ValueKey(
              'action:fact_contributed_amount.missing_amount',
            ),
            label: l10n.batch11MissingAmount,
            onPressed: () {
              widget.onMissing();
            },
          )
        else
          MintDesignLabAction.secondary(
            key: const ValueKey(
              'action:fact_contributed_amount.unknown_amount',
            ),
            label: l10n.batch11UnknownAmount,
            focusNode: _unknownActionFocus,
            onPressed: () {
              widget.onUnknown();
            },
          ),
        MintDesignLabAction.text(
          key: const ValueKey(
            'action:fact_contributed_amount.correct_previous',
          ),
          label: l10n.batch11CorrectPrevious,
          onPressed: widget.onCorrectPrevious,
        ),
      ],
    );
  }
}

class _Batch16UnresolvedHelp extends StatefulWidget {
  const _Batch16UnresolvedHelp({
    required this.taxYear,
    required this.rowNumber,
    required this.origin,
    required this.refundEligible,
    required this.restoreTarget,
    required this.onProviderTotal,
    required this.onRefund,
    required this.onAllZero,
    required this.onEducation,
    required this.onBack,
  });

  final int taxYear;
  final int rowNumber;
  final MultiProviderUnresolvedOrigin origin;
  final bool refundEligible;
  final String restoreTarget;
  final ValueChanged<MultiProviderUnresolvedResolveToken> onProviderTotal;
  final ValueChanged<MultiProviderUnresolvedRefundToken> onRefund;
  final ValueChanged<MultiProviderUnresolvedAllZeroToken> onAllZero;
  final VoidCallback onEducation;
  final VoidCallback onBack;

  @override
  State<_Batch16UnresolvedHelp> createState() => _Batch16UnresolvedHelpState();
}

class _Batch16UnresolvedHelpState extends State<_Batch16UnresolvedHelp> {
  final ScrollController _scroll = ScrollController();
  bool _detailsExpanded = false;
  final FocusNode _heading = FocusNode(
    debugLabel: 'unresolved help heading',
    skipTraversal: true,
  );
  final FocusNode _providerTotal = FocusNode(
    debugLabel: 'unresolved provider total action',
  );
  final FocusNode _refunded = FocusNode(
    debugLabel: 'unresolved provider refunded action',
  );
  final FocusNode _allZero = FocusNode(
    debugLabel: 'unresolved all zero action',
  );
  final FocusNode _education = FocusNode(
    debugLabel: 'unresolved education action',
  );
  final FocusNode _details = FocusNode(debugLabel: 'unresolved details action');
  final FocusNode _back = FocusNode(debugLabel: 'unresolved back action');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (widget.restoreTarget) {
        case 'all_zero':
          _allZero.requestFocus();
        case 'education':
          _education.requestFocus();
        default:
          _heading.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _heading.dispose();
    _providerTotal.dispose();
    _refunded.dispose();
    _allZero.dispose();
    _education.dispose();
    _details.dispose();
    _back.dispose();
    super.dispose();
  }

  Widget _action({
    required Key key,
    required int order,
    required String label,
    required String semanticsLabel,
    double fontSize = 16,
    required FocusNode focus,
    required VoidCallback onPressed,
    MintActionTone tone = MintActionTone.secondary,
  }) {
    final sortKey = OrdinalSortKey(order.toDouble());
    return switch (tone) {
      MintActionTone.primary => MintDesignLabAction(
        key: key,
        label: label,
        semanticsLabel: semanticsLabel,
        semanticsSortKey: sortKey,
        focusNode: focus,
        fontSize: fontSize,
        onPressed: onPressed,
      ),
      MintActionTone.secondary => MintDesignLabAction.secondary(
        key: key,
        label: label,
        semanticsLabel: semanticsLabel,
        semanticsSortKey: sortKey,
        focusNode: focus,
        fontSize: fontSize,
        onPressed: onPressed,
      ),
      MintActionTone.text => MintDesignLabAction.text(
        key: key,
        label: label,
        semanticsLabel: semanticsLabel,
        semanticsSortKey: sortKey,
        focusNode: focus,
        fontSize: fontSize,
        onPressed: onPressed,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    final rowContext = l10n.batch16RowContext(widget.rowNumber, widget.taxYear);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compactLargeText =
        viewportWidth > 0 &&
        viewportWidth <= 320 &&
        MediaQuery.textScalerOf(context).scale(16) > 24;
    String contextual(String label) => '$label · $rowContext';
    final intents = [
      l10n.batch16AnnualOrdinaryTotalMeaning,
      l10n.batch16ActuallyCreditedMeaning(widget.taxYear),
      l10n.batch16ExcludedMovementsMeaning,
      l10n.batch16ProviderConfirmedNetMeaning,
      l10n.batch16InsuranceCertificateMeaning,
      l10n.batch16RefundVsAllZeroMeaning,
      l10n.batch16MintNotVerifiedMeaning,
      l10n.batch16NoTaxAdviceMeaning,
    ];
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          key: const ValueKey('scroll:unresolved_amount_help'),
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(24, compactLargeText ? 0 : 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                key: const ValueKey('heading:unresolved_amount_help'),
                focusNode: _heading,
                child: Semantics(
                  header: true,
                  child: Text(
                    compactLargeText
                        ? l10n.batch16HelpCompactTitle
                        : l10n.batch16HelpTitle,
                    style: _editorial(32),
                  ),
                ),
              ),
              SizedBox(height: compactLargeText ? 4 : 12),
              Text(
                compactLargeText
                    ? l10n.batch16HelpCompactBody
                    : l10n.batch16HelpBody,
              ),
              SizedBox(height: compactLargeText ? 4 : 16),
              _action(
                key: const ValueKey('action:unresolved_help.provider_total'),
                order: 0,
                label: compactLargeText
                    ? l10n.batch16HelpProviderTotalCompact
                    : l10n.batch16HelpProviderTotal,
                semanticsLabel: contextual(
                  '${l10n.batch16HelpProviderTotal}. ${l10n.batch16MintNotVerifiedMeaning}',
                ),
                fontSize: 16,
                focus: _providerTotal,
                tone: MintActionTone.primary,
                onPressed: () =>
                    widget.onProviderTotal(widget.origin.resolveToken),
              ),
              const SizedBox(height: 8),
              if (widget.refundEligible) ...[
                _action(
                  key: const ValueKey(
                    'action:unresolved_help.provider_refunded',
                  ),
                  order: 1,
                  label: l10n.batch16HelpProviderRefunded,
                  semanticsLabel: contextual(l10n.batch16HelpProviderRefunded),
                  fontSize: 16,
                  focus: _refunded,
                  onPressed: () => widget.onRefund(widget.origin.refundToken),
                ),
                const SizedBox(height: 8),
              ],
              _action(
                key: const ValueKey('action:unresolved_help.all_zero'),
                order: 2,
                label: l10n.batch16HelpAllZero,
                semanticsLabel: contextual(l10n.batch16HelpAllZero),
                fontSize: 16,
                focus: _allZero,
                onPressed: () => widget.onAllZero(widget.origin.allZeroToken),
              ),
              const SizedBox(height: 8),
              _action(
                key: const ValueKey('action:unresolved_help.education'),
                order: 3,
                label: l10n.batch16HelpEducation,
                semanticsLabel: contextual(l10n.batch16HelpEducation),
                fontSize: 16,
                focus: _education,
                onPressed: widget.onEducation,
              ),
              const SizedBox(height: 12),
              _DisclosureAction(
                actionKey: const ValueKey('action:unresolved_help.details'),
                label: l10n.batch16HelpDetails,
                semanticsLabel: contextual(l10n.batch16HelpDetails),
                expanded: _detailsExpanded,
                focusNode: _details,
                semanticsSortKey: const OrdinalSortKey(4),
                onPressed: () {
                  _details.requestFocus();
                  setState(() => _detailsExpanded = !_detailsExpanded);
                },
              ),
              if (_detailsExpanded) ...[
                const SizedBox(height: 12),
                Container(
                  key: const ValueKey('content:unresolved_help.details'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: _porcelain,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final intent in intents) ...[
                        Text(intent),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _action(
                key: const ValueKey('action:unresolved_help.back'),
                order: 5,
                label: l10n.batch16HelpBack,
                semanticsLabel: contextual(l10n.batch16HelpBack),
                fontSize: 16,
                focus: _back,
                tone: MintActionTone.text,
                onPressed: widget.onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Batch16ContributionCorrection extends StatelessWidget {
  const _Batch16ContributionCorrection({
    required this.taxYear,
    required this.onChoose,
    required this.onBack,
  });

  final int taxYear;
  final ValueChanged<_ContributionStatus> onChoose;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'contribution_status_correction',
      eyebrow: 'MINT',
      title: l10n.contributionTitle(taxYear),
      preserveHeadingBaseAtLargeText: true,
      body:
          '${l10n.batch16CorrectionTitle}\n\n${l10n.contributionBody}\n\n${l10n.batch16NoTaxAdviceMeaning}',
      accent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.batch16CurrentYes,
            key: const ValueKey('status:contribution_current_yes'),
          ),
          Text(
            l10n.batch16Unselected,
            key: const ValueKey('status:contribution_correction_unselected'),
          ),
        ],
      ),
      actions: [
        Text(
          l10n.batch16CorrectionDataLoss,
          key: const ValueKey('warning:contribution_correction.data_loss'),
        ),
        MintDesignLabAction(
          key: const ValueKey('action:contribution_correction.choose_yes'),
          label: l10n.batch16ChooseYes,
          onPressed: () => onChoose(_ContributionStatus.yes),
        ),
        MintDesignLabAction.secondary(
          key: const ValueKey('action:contribution_correction.choose_no'),
          label: l10n.batch16ChooseNo,
          onPressed: () => onChoose(_ContributionStatus.no),
        ),
        MintDesignLabAction.secondary(
          key: const ValueKey('action:contribution_correction.choose_unknown'),
          label: l10n.batch16ChooseUnknown,
          onPressed: () => onChoose(_ContributionStatus.unknown),
        ),
        MintDesignLabAction.text(
          key: const ValueKey('action:contribution_correction.back'),
          label: l10n.batch16Back,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _EducationBoundary extends StatelessWidget {
  const _EducationBoundary({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'education_explanation',
      eyebrow: l10n.contributionUnknownEyebrow,
      title: l10n.contributionEducationTitle,
      body: l10n.contributionEducationBody,
      accent: const _QuietOrb(),
      actions: [
        MintDesignLabAction.text(
          key: const ValueKey('action:education_explanation.back'),
          label: l10n.contributionEducationBack,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _Page extends StatefulWidget {
  const _Page({
    required this.nodeId,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accent,
    required this.actions,
    this.preserveHeadingBaseAtLargeText = false,
  });
  final String nodeId;
  final String eyebrow;
  final String title;
  final String body;
  final Widget accent;
  final List<Widget> actions;
  final bool preserveHeadingBaseAtLargeText;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _headingFocus = FocusNode(debugLabel: 'page heading');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _headingFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _headingFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compactWidth = viewportWidth > 0 && viewportWidth <= 320;
    final scrollActions = largeText || compactWidth;
    final actionPanel = _ActionPanel(actions: widget.actions);
    return Column(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            sortKey: const OrdinalSortKey(2),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                key: ValueKey('scroll:${widget.nodeId}'),
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.eyebrow,
                      style: const TextStyle(
                        fontFamily: 'Supreme',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                        color: _coral,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Focus(
                      key: ValueKey('heading:${widget.nodeId}'),
                      focusNode: _headingFocus,
                      child: Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(
                          widget.title,
                          style: _editorial(
                            widget.preserveHeadingBaseAtLargeText
                                ? 38
                                : (largeText ? 28 : 38),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.body,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    widget.accent,
                    if (scrollActions) ...[
                      const SizedBox(height: 24),
                      actionPanel,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!scrollActions)
          Semantics(
            container: true,
            sortKey: const OrdinalSortKey(3),
            child: actionPanel,
          ),
      ],
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.actions});
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: _paper,
      border: Border(top: BorderSide(color: _border)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: actions
            .expand((action) => [action, const SizedBox(height: 6)])
            .toList(),
      ),
    ),
  );
}

class _SafeExitSheet extends StatefulWidget {
  const _SafeExitSheet({
    required this.l10n,
    required this.onResume,
    required this.onLeave,
  });

  final MintNextLocalizations l10n;
  final VoidCallback onResume;
  final VoidCallback onLeave;

  @override
  State<_SafeExitSheet> createState() => _SafeExitSheetState();
}

class _SafeExitSheetState extends State<_SafeExitSheet> {
  final ScrollController _controller = ScrollController();
  final FocusNode _headingFocus = FocusNode(
    debugLabel: 'safe exit heading',
    skipTraversal: true,
  );
  final FocusNode _resumeFocus = FocusNode(debugLabel: 'safe exit resume');
  final FocusNode _leaveFocus = FocusNode(
    debugLabel: 'safe exit leave without saving',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _headingFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _headingFocus.dispose();
    _resumeFocus.dispose();
    _leaveFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
    policy: WidgetOrderTraversalPolicy(),
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.tab) {
          return KeyEventResult.ignored;
        }
        final scope = FocusScope.of(context);
        HardwareKeyboard.instance.isShiftPressed
            ? scope.previousFocus()
            : scope.nextFocus();
        return KeyEventResult.handled;
      },
      child: Semantics(
        key: const ValueKey('overlay:safe_exit'),
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        child: SafeArea(
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            child: SingleChildScrollView(
              key: const ValueKey('scroll:safe_exit'),
              controller: _controller,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Focus(
                    key: const ValueKey('heading:safe_exit'),
                    focusNode: _headingFocus,
                    child: Semantics(
                      header: true,
                      child: Text(
                        widget.l10n.safeExitTitle,
                        style: _editorial(30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.l10n.safeExitBody,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  MintDesignLabAction(
                    key: const ValueKey('overlay-action:safe_exit.resume'),
                    label: widget.l10n.resume,
                    focusNode: _resumeFocus,
                    onPressed: widget.onResume,
                  ),
                  const SizedBox(height: 10),
                  MintDesignLabAction.secondary(
                    key: const ValueKey(
                      'overlay-action:safe_exit.keep_local_reference',
                    ),
                    label: widget.l10n.keepReferenceUnavailable,
                    onPressed: null,
                  ),
                  const SizedBox(height: 10),
                  MintDesignLabAction.text(
                    key: const ValueKey(
                      'overlay-action:safe_exit.leave_without_saving',
                    ),
                    label: widget.l10n.leave,
                    focusNode: _leaveFocus,
                    onPressed: widget.onLeave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _EditorialNote extends StatelessWidget {
  const _EditorialNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _porcelain,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: Text(text, style: _editorial(21).copyWith(height: 1.35)),
  );
}

class _QuietOrb extends StatelessWidget {
  const _QuietOrb();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: 92,
      height: 92,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [Color(0xFFE8CFB8), _sage]),
      ),
    ),
  );
}

class _Terminal extends StatelessWidget {
  const _Terminal({required this.title, required this.onRestart});
  final String title;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) => _Page(
    nodeId: 'dismissed',
    eyebrow: 'MINT',
    title: title,
    body: MintNextLocalizations.of(context).safeExitBody,
    accent: const _QuietOrb(),
    actions: [
      MintDesignLabAction(
        key: const ValueKey('action:dismissed.restart'),
        label: MintNextLocalizations.of(context).start,
        onPressed: onRestart,
      ),
    ],
  );
}

TextStyle _editorial(double size) => TextStyle(
  fontFamily: 'Gambarino',
  fontSize: size,
  height: 1.12,
  color: _ink,
  fontWeight: FontWeight.w400,
);

enum MintActionTone { primary, secondary, text }

class MintDesignLabAction extends StatelessWidget {
  const MintDesignLabAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.semanticsLabel,
    this.semanticsSortKey,
    this.focusNode,
    this.fontSize = 16,
  }) : tone = MintActionTone.primary;
  const MintDesignLabAction.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.semanticsLabel,
    this.semanticsSortKey,
    this.focusNode,
    this.fontSize = 16,
  }) : tone = MintActionTone.secondary;
  const MintDesignLabAction.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.semanticsLabel,
    this.semanticsSortKey,
    this.focusNode,
    this.fontSize = 16,
  }) : tone = MintActionTone.text;

  final String label;
  final VoidCallback? onPressed;
  final bool compact;
  final String? semanticsLabel;
  final SemanticsSortKey? semanticsSortKey;
  final FocusNode? focusNode;
  final double fontSize;
  final MintActionTone tone;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(compact ? 72 : double.infinity, 48),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Supreme',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final button = switch (tone) {
      MintActionTone.primary => FilledButton(
        focusNode: focusNode,
        style: style.copyWith(
          backgroundColor: const WidgetStatePropertyAll(_ink),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
      MintActionTone.secondary => OutlinedButton(
        focusNode: focusNode,
        style: style.copyWith(
          foregroundColor: const WidgetStatePropertyAll(_ink),
          side: const WidgetStatePropertyAll(BorderSide(color: _ink)),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
      MintActionTone.text => TextButton(
        focusNode: focusNode,
        style: style.copyWith(
          foregroundColor: const WidgetStatePropertyAll(_secondaryInk),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    };
    if (semanticsLabel == null) return button;
    return Semantics(
      label: semanticsLabel,
      sortKey: semanticsSortKey,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      excludeSemantics: true,
      child: button,
    );
  }
}
