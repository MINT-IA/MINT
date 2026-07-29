import 'dart:math' show pow;
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/widgets/educational/salary_breakdown_widget.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/coach/first_salary_film_widget.dart';
import 'package:mint_mobile/widgets/coach/budget_503020_widget.dart';
import 'package:mint_mobile/widgets/coach/career_timelapse_widget.dart';
import 'package:mint_mobile/widgets/coach/payslip_xray_widget.dart';
import 'package:mint_mobile/widgets/coach/job_change_checklist_widget.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';

// ────────────────────────────────────────────────────────────
//  FIRST JOB SCREEN — Sprint S19 / Premier emploi
// ────────────────────────────────────────────────────────────
//
// Interactive first job salary analyzer.
// Category C — Life Event (DESIGN_SYSTEM §2C).
// ────────────────────────────────────────────────────────────

class FirstJobScreen extends StatefulWidget {
  const FirstJobScreen({super.key});

  @override
  State<FirstJobScreen> createState() => _FirstJobScreenState();
}

class _FirstJobScreenState extends State<FirstJobScreen> {
  bool _hasUserInteracted = false;
  String? _seqRunId;
  String? _seqStepId;
  bool _finalReturnEmitted = false;

  double _salaire = 5000;
  int _age = 25;
  String _canton = 'ZH';
  double _tauxActivite = 100;
  FirstJobResult? _result;

  // ── P2 « gate dur » : provenance par fait, ré-évaluée à chaque notify ──
  // Un fait de SITUATION n'est CONFIRMÉ que s'il vient des données réelles :
  // soit amorcé depuis un champ profil réellement fourni
  // (`userProvidedFields`), soit touché par l'utilisateur. Une valeur égale à
  // un défaut fabriqué reste ASSUMED (jamais confirmée). Pas de latch global
  // `_seededFromProfile` : `loadFromWizard` notifie plusieurs fois
  // (cache→frais→fusionné) ; un latch au 1er notify échouerait un champ dont la
  // donnée arrive au notify suivant.
  CoachProfileProvider? _profileProvider;
  bool _salaireTouched = false;
  bool _salaireSeeded = false; // provenance = userProvidedFields('salary').
  bool _ageTouched = false;
  bool _ageSeeded = false; // provenance = userProvidedFields('age'), 18-30 only.
  bool _cantonTouched = false;
  bool _cantonSeeded = false; // provenance = userProvidedFields('canton').

  // Baseline pour l'annonce VoiceOver incomplet→complet.
  bool _lastGateComplete = false;

  // Anchors pour scroll-to-first-missing quand la situation est incomplète.
  final _salaireKey = GlobalKey();
  final _ageKey = GlobalKey();
  final _cantonKey = GlobalKey();

  // Checklist tracking
  final Set<int> _checkedItems = {};

  // Swiss cantons
  static const List<String> _cantons = [
    'AG',
    'AI',
    'AR',
    'BE',
    'BL',
    'BS',
    'FR',
    'GE',
    'GL',
    'GR',
    'JU',
    'LU',
    'NE',
    'NW',
    'OW',
    'SG',
    'SH',
    'SO',
    'SZ',
    'TG',
    'TI',
    'UR',
    'VD',
    'VS',
    'ZG',
    'ZH',
  ];

  @override
  void initState() {
    super.initState();
    // Gate dur : au 1er frame rien n'est confirmé → aucun résultat fabriqué.
    _computeResult();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readSequenceContext();
    });
  }

  void _readSequenceContext() {
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map<String, dynamic>) {
        _seqRunId = extra['runId'] as String?;
        _seqStepId = extra['stepId'] as String?;
      }
    } catch (_) {
      // Not navigated via GoRouter or no extra — stay Tier B.
    }
  }

  void _emitFinalReturn() {
    if (_finalReturnEmitted) return;
    if (_seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;

    if (!_hasUserInteracted) {
      final screenReturn = ScreenReturn.abandoned(
        route: '/first-job',
        runId: _seqRunId,
        stepId: _seqStepId,
        eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      ScreenCompletionTracker.markCompletedWithReturn(
          'first_job', screenReturn);
      return;
    }

    final screenReturn = ScreenReturn.completed(
      route: '/first-job',
      stepOutputs: {},
      runId: _seqRunId,
      stepId: _seqStepId,
      eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
    );
    ScreenCompletionTracker.markCompletedWithReturn('first_job', screenReturn);
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
    _lastGateComplete = _situationGate(context).complete;
  }

  /// Seed provenance-gaté, rejoué à CHAQUE notify (aucun latch global).
  /// Un champ n'est amorcé — et donc confirmé — que si sa provenance est réelle :
  /// une clé `userProvidedFields`, jamais valeur≠défaut. L'âge n'est amorcé que
  /// dans la plage du slider (18-30, intention premier emploi) ; hors plage il
  /// reste non confirmé → gaté, et sa valeur ne sort jamais des bornes du slider
  /// (pas d'assert).
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
      if (_ageSeeded) {
        _ageSeeded = false;
        changed = true;
      }
      if (_cantonSeeded) {
        _cantonSeeded = false;
        changed = true;
      }
      if (changed) _calculate();
      return;
    }

    // Salaire : clé 'salary'.
    if (!_salaireTouched) {
      // La clé seule ne suffit PAS : il faut aussi que la valeur tienne dans la
      // plage du contrôle. Sans ce second test, un salaire à 0 portant la clé
      // passait par `clamp(2000, 15000)` et ressortait à CHF 2'000 — un montant
      // que l'utilisateur n'a jamais saisi, déclaré « confirmé », et sur lequel
      // la décomposition du salaire se calculait.
      //
      // Le clamp EST la fabrication : borner une valeur hors plage produit un
      // chiffre inventé, en bas comme en haut. Un salaire réel de 20'000
      // afficherait 15'000, ce qui n'est pas davantage défendable. Hors plage
      // ⇒ non amorcé ⇒ le gate demande la saisie.
      final raw = profile.salaireBrutMensuel;
      final inRange = raw >= 2000.0 && raw <= 15000.0;
      final seeded = profile.userProvidedFields.contains('salary') && inRange;
      if (_salaireSeeded != seeded) {
        _salaireSeeded = seeded;
        changed = true;
      }
      if (seeded && raw != _salaire) {
        _salaire = raw;
        changed = true;
      }
    }

    // Âge : clé 'age', amorcé seulement dans la plage du slider (18-30).
    if (!_ageTouched) {
      final age = profile.ageOrNull;
      final inRange = age != null && age >= 18 && age <= 30;
      final valid = profile.userProvidedFields.contains('age') && inRange;
      if (_ageSeeded != valid) {
        _ageSeeded = valid;
        changed = true;
      }
      if (valid && age != _age) {
        _age = age;
        changed = true;
      }
    }

    // Canton : clé 'canton'.
    if (!_cantonTouched) {
      final c = profile.canton;
      final valid = profile.userProvidedFields.contains('canton') &&
          c.isNotEmpty &&
          c != 'unknown' &&
          _cantons.contains(c);
      if (_cantonSeeded != valid) {
        _cantonSeeded = valid;
        changed = true;
      }
      if (valid && c != _canton) {
        _canton = c;
        changed = true;
      }
    }

    if (changed) _calculate();
  }

  @override
  void dispose() {
    _profileProvider?.removeListener(_seedFromProfile);
    super.dispose();
  }

  // ── P2 provenance getters (live, non-latching) ──
  FactProvenance get _salaireProvenance => _salaireTouched
      ? FactProvenance.touched
      : (_salaireSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  FactProvenance get _ageProvenance => _ageTouched
      ? FactProvenance.touched
      : (_ageSeeded ? FactProvenance.seededFromProfile : FactProvenance.assumed);

  FactProvenance get _cantonProvenance => _cantonTouched
      ? FactProvenance.touched
      : (_cantonSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  /// Le badge « profil » s'affiche dès qu'un fait vient réellement du profil.
  bool get _seededFromProfile =>
      _salaireSeeded || _ageSeeded || _cantonSeeded;

  // ── Gate (sortie unique = la décomposition du salaire) ──
  // Faits déterminants : salaire (le chiffre), âge (seuil LPP obligatoire à
  // 25 ans), canton (fiscalité / déductions cantonales). Le taux d'activité est
  // un paramètre de SCÉNARIO → non gaté, mais l'éditer invalide le résultat.
  SituationGate _situationGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'salary',
          label: (c) => S.of(c)!.firstJobGateFactSalaire,
          why: (c) => S.of(c)!.firstJobGateWhySalaire,
          provenance: _salaireProvenance,
          onComplete: () => _scrollToKey(_salaireKey),
        ),
        SituationFact(
          key: 'age',
          label: (c) => S.of(c)!.firstJobGateFactAge,
          why: (c) => S.of(c)!.firstJobGateWhyAge,
          provenance: _ageProvenance,
          onComplete: () => _scrollToKey(_ageKey),
        ),
        SituationFact(
          key: 'canton',
          label: (c) => S.of(c)!.firstJobGateFactCanton,
          why: (c) => S.of(c)!.firstJobGateWhyCanton,
          provenance: _cantonProvenance,
          onComplete: () => _scrollToKey(_cantonKey),
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

  /// Calcule le résultat SEULEMENT si le gate est complet (compute-time gate).
  /// Sinon aucun chiffre : le slot résultat affiche la carte de situation à la
  /// place. Un résultat n'existe donc jamais sur un défaut fabriqué.
  void _computeResult() {
    _result = _situationGate(context).complete
        ? FirstJobService.analyzeSalary(
            salaireBrutMensuel: _salaire,
            age: _age,
            canton: _canton,
            tauxActivite: _tauxActivite,
          )
        : null;
  }

  /// Recalcule + rebuild, SANS annonce (seed profil, ou édition d'un paramètre
  /// de scénario comme le taux d'activité). Toute entrée qui bouge invalide
  /// d'abord le résultat : aucun chiffre périmé ne survit à une entrée modifiée.
  void _calculate() {
    _computeResult();
    _lastGateComplete = _situationGate(context).complete;
    if (mounted) setState(() {});
  }

  /// L'utilisateur a édité un fait de SITUATION déterminant (salaire, âge,
  /// canton) : recalcule et annonce le passage incomplet→complet pour VoiceOver
  /// (le scroll ≠ déplacement de focus).
  void _afterSituationFactChanged() {
    final wasComplete = _lastGateComplete;
    _computeResult();
    final nowComplete = _situationGate(context).complete;
    if (nowComplete && !wasComplete) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        S.of(context)!.firstJobGateAnnounceComplete,
        Directionality.of(context),
      );
    }
    _lastGateComplete = nowComplete;
    if (mounted) setState(() {});
  }

  /// @visibleForTesting : entrées consommées par analyzeSalary (preuve P2).
  @visibleForTesting
  double get debugSalaire => _salaire;
  @visibleForTesting
  int get debugAge => _age;
  @visibleForTesting
  String get debugCanton => _canton;
  @visibleForTesting
  double get debugTaux => _tauxActivite;

  /// @visibleForTesting : contrat de retour — une vraie interaction utilisateur
  /// doit émettre `completed`, jamais `abandoned`. Une régression du seul
  /// « le scénario de salaire ne pose pas ce drapeau » suffit à casser le
  /// contrat même quand le résultat s'affiche.
  @visibleForTesting
  bool get debugHasUserInteracted => _hasUserInteracted;

  /// @visibleForTesting : émet le retour final avec un contexte de séquence
  /// injecté (sans passer par GoRouter), pour prouver `completed` vs
  /// `abandoned` selon l'interaction réelle.
  @visibleForTesting
  void debugEmitFinalReturn({required String runId, required String stepId}) {
    _seqRunId = runId;
    _seqStepId = stepId;
    _emitFinalReturn();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _emitFinalReturn();
      },
      // ILLOG-02 : conteneur Semantics racine (motif rente_vs_capital) sinon le
      // pont AX iOS effondre toute la route en un seul nœud (« 1 element »).
      child: Semantics(
        identifier: 'first_job_screen',
        container: true,
        explicitChildNodes: true,
        child: Scaffold(
          backgroundColor: MintColors.background,
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: CustomScrollView(
                    slivers: [
                      _buildAppBar(context),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                            MintSpacing.lg, 0, MintSpacing.lg, MintSpacing.lg),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            MintEntrance(
                                child: MintNarrativeCard(
                              headline:
                                  S.of(context)!.narrativeFirstJobHeadline,
                              body: S.of(context)!.narrativeFirstJobBody,
                              tone: MintSurfaceTone.sauge,
                              badge: S.of(context)!.narrativeFirstJobBadge,
                            )),
                            const SizedBox(height: MintSpacing.md + 4),
                            MintEntrance(
                                delay: const Duration(milliseconds: 100),
                                child: _buildHeader()),
                            const SizedBox(height: MintSpacing.md + 4),
                            MintEntrance(
                                delay: const Duration(milliseconds: 200),
                                child: _buildSalaireSlider()),
                            const SizedBox(height: MintSpacing.md + 4),
                            MintEntrance(
                                delay: const Duration(milliseconds: 300),
                                child: _buildAgeSlider()),
                            const SizedBox(height: MintSpacing.md + 4),
                            MintEntrance(
                                delay: const Duration(milliseconds: 400),
                                child: _buildCantonAndActivity()),
                            const SizedBox(height: MintSpacing.lg),
                            // Gate dur : la décomposition (et tous les chiffres
                            // qui en dérivent) ne s'affiche que si les faits
                            // déterminants sont confirmés. Sinon la carte de
                            // situation prend sa place dans le slot résultat.
                            if (_result != null &&
                                _situationGate(context).complete) ...[
                              _buildPremierEclairage(),
                              const SizedBox(height: MintSpacing.lg),
                              SalaryBreakdownWidget(
                                brut: _result!.brut,
                                netEstime: _result!.netEstime,
                                cotisationsEmployeur:
                                    _result!.cotisationsEmployeur,
                                deductions: _result!.deductionItems,
                              ),
                              const SizedBox(height: MintSpacing.lg),
                              PayslipXRayWidget(
                                // Toutes les valeurs proviennent de `_result!`
                                // (étalon `FirstJobService.analyzeSalary`) : un
                                // seul net sur l'écran, aucun ratio fabriqué.
                                grossSalary: _result!.brut,
                                netSalary: _result!.netEstime,
                                // `cotisationsEmployeur` = charges employeur EN
                                // PLUS du brut ; le widget affiche « ton vrai
                                // salaire » = coût total employeur = brut +
                                // charges.
                                employerHiddenCost: _result!.brut +
                                    _result!.cotisationsEmployeur,
                                deductions: [
                                  PayslipLine(
                                    label:
                                        S.of(context)!.firstJobPayslipAvsLabel,
                                    emoji: '\u{1F6E1}\u{FE0F}',
                                    amount: _result!.avsAiApg,
                                    percentage: _result!.brut > 0
                                        ? _result!.avsAiApg /
                                            _result!.brut *
                                            100
                                        : 0,
                                    explanation: S
                                        .of(context)!
                                        .firstJobPayslipAvsExplanation,
                                    legalRef:
                                        'LAVS art. 5 · LAI art. 3 · LAPG art. 27',
                                  ),
                                  PayslipLine(
                                    label:
                                        S.of(context)!.firstJobPayslipLppLabel,
                                    emoji: '\u{1F3E6}',
                                    amount: _result!.lppEmploye,
                                    percentage: _result!.brut > 0
                                        ? _result!.lppEmploye /
                                            _result!.brut *
                                            100
                                        : 0,
                                    explanation: S
                                        .of(context)!
                                        .firstJobPayslipLppExplanation,
                                    legalRef: 'LPP art. 16',
                                  ),
                                ],
                              ),
                              const SizedBox(height: MintSpacing.lg),
                              _build3aRecommendation(),
                              const SizedBox(height: MintSpacing.lg),
                              _build3aWarning(),
                              const SizedBox(height: MintSpacing.lg),
                              _buildLamalComparison(),
                              const SizedBox(height: MintSpacing.lg),
                              _buildChecklist(),
                              const SizedBox(height: MintSpacing.lg),
                              Builder(
                                builder: (ctx) {
                                  final l = S.of(ctx)!;
                                  return JobChangeChecklistWidget(
                                    items: [
                                      ChecklistItem(
                                        deadline: l.firstJobChecklistDeadline1,
                                        emoji: '\u{1F4C4}',
                                        action: l.firstJobChecklistAction1,
                                        legalRef: 'LFLP art. 2',
                                        consequence:
                                            l.firstJobChecklistConsequence1,
                                      ),
                                      ChecklistItem(
                                        deadline: l.firstJobChecklistDeadline2,
                                        emoji: '\u{1F3E6}',
                                        action: l.firstJobChecklistAction2,
                                        legalRef: 'LFLP art. 4 al. 2',
                                        consequence:
                                            l.firstJobChecklistConsequence2,
                                      ),
                                      ChecklistItem(
                                        deadline: l.firstJobChecklistDeadline3,
                                        emoji: '\u{1F6E1}\u{FE0F}',
                                        action: l.firstJobChecklistAction3,
                                        legalRef: 'LAMal art. 71',
                                      ),
                                      ChecklistItem(
                                        deadline: l.firstJobChecklistDeadline4,
                                        emoji: '\u{1F3E6}',
                                        action: l.firstJobChecklistAction4,
                                        legalRef: 'OPP3 art. 7',
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: MintSpacing.lg),
                              _buildEducation(),
                              const SizedBox(height: MintSpacing.lg),
                              _buildMintAnalysisSection(),
                              const SizedBox(height: MintSpacing.lg),
                            ] else ...[
                              // Slot résultat gaté : la carte de situation
                              // remplace la décomposition tant que salaire, âge
                              // et canton ne sont pas confirmés (données réelles).
                              MintEntrance(
                                child: SituationGateCard(
                                  title: S.of(context)!.donationGateTitle,
                                  gate: _situationGate(context),
                                ),
                              ),
                              const SizedBox(height: MintSpacing.lg),
                            ],
                            MintEntrance(
                                delay: const Duration(milliseconds: 400),
                                child: _buildDisclaimer()),
                            const SizedBox(height: 100),
                          ]),
                        ),
                      ),
                    ],
                  ))))),
    );
  }

  // ── App Bar (white standard per DESIGN_SYSTEM §4.5) ──────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: Semantics(
        label: S.of(context)!.semanticsBackButton,
        button: true,
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () => safePop(context),
        ),
      ),
      title: Text(
        S.of(context)!.firstJobTitle,
        style: MintTextStyles.headlineMedium(),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.celebration_outlined,
              color: MintColors.info, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.firstJobHeaderDesc,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliders ────────────────────────────────────────────────

  Widget _buildSalaireSlider() {
    return _buildSliderCard(
      cardKey: _salaireKey,
      title: S.of(context)!.firstJobSalaryTitle,
      valueLabel: FirstJobService.formatChf(_salaire),
      minLabel: S.of(context)!.firstJobSalaryMin,
      maxLabel: S.of(context)!.firstJobSalaryMax,
      value: _salaire,
      min: 2000,
      max: 15000,
      divisions: 260,
      onChanged: (v) {
        _hasUserInteracted = true;
        _salaireTouched = true;
        _salaireSeeded = false; // touched supersede le seed (donnée user).
        _salaire = v;
        _afterSituationFactChanged();
      },
    );
  }

  Widget _buildAgeSlider() {
    return _buildSliderCard(
      cardKey: _ageKey,
      title: S.of(context)!.unemploymentAgeSliderTitle,
      valueLabel: S.of(context)!.unemploymentAgeValue(_age),
      minLabel: S.of(context)!.unemploymentAgeMin,
      maxLabel: S.of(context)!.unemploymentAgeValue(30),
      value: _age.toDouble(),
      min: 18,
      max: 30,
      divisions: 12,
      onChanged: (v) {
        _hasUserInteracted = true;
        _ageTouched = true;
        _ageSeeded = false; // touched supersede le seed (donnée user).
        _age = v.toInt();
        _afterSituationFactChanged();
      },
    );
  }

  Widget _buildSliderCard({
    Key? cardKey,
    required String title,
    required String valueLabel,
    required String minLabel,
    required String maxLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return MintSurface(
      key: cardKey,
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: MintPremiumSlider(
        label: title,
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        formatValue: (_) => valueLabel,
        onChanged: onChanged,
      ),
    );
  }

  // ── Canton + Activity Rate ─────────────────────────────────

  Widget _buildCantonAndActivity() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Canton dropdown
          Row(
            key: _cantonKey,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.firstJobCantonLabel,
                style:
                    MintTextStyles.titleMedium(color: MintColors.textPrimary),
              ),
              Semantics(
                label: S.of(context)!.firstJobCantonLabel,
                button: true,
                child: MintSurface(
                  tone: MintSurfaceTone.porcelaine,
                  padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.sm + 4),
                  radius: 10,
                  child: DropdownButton<String>(
                    value: _canton,
                    underline: const SizedBox.shrink(),
                    style:
                        MintTextStyles.titleMedium(color: MintColors.primary),
                    items: _cantons.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _hasUserInteracted = true;
                        _cantonTouched = true;
                        _cantonSeeded = false; // touched supersede le seed.
                        _canton = v;
                        _afterSituationFactChanged();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md + 4),

          // Activity rate slider
          MintPremiumSlider(
            label: S.of(context)!.firstJobActivityRate,
            value: _tauxActivite,
            min: 10,
            max: 100,
            divisions: 18,
            formatValue: (v) => '${v.toStringAsFixed(0)}\u00a0%',
            onChanged: (v) {
              _tauxActivite = v;
              _calculate();
            },
          ),
        ],
      ),
    );
  }

  // ── Premier Éclairage ───────────────────────────────────────────

  Widget _buildPremierEclairage() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            FirstJobService.formatChf(r.cotisationsEmployeur),
            style: MintTextStyles.displayMedium(color: MintColors.white)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            r.premierEclairage,
            style: MintTextStyles.bodyMedium(
                color: MintColors.white.withValues(alpha: 0.9)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── 3a Recommendation ──────────────────────────────────────

  Widget _build3aRecommendation() {
    final r = _result!;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.firstJob3aHeader,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  S.of(context)!.firstJob3aAnnualCap,
                  FirstJobService.formatChf(r.plafondAnnuel3a),
                ),
              ),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: _buildMiniMetric(
                  S.of(context)!.firstJob3aMonthlySuggestion,
                  FirstJobService.formatChf(r.montantMensuelSuggere3a),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up,
                    size: 16, color: MintColors.success),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    S.of(context)!.firstJobFiscalSavings(
                        FirstJobService.formatChf(r.economieFiscaleEstimee3a)),
                    style: MintTextStyles.bodySmall(color: MintColors.success)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.sm + 6),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: MintTextStyles.titleMedium(color: MintColors.primary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── 3a WARNING ─────────────────────────────────────────────

  Widget _build3aWarning() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: MintColors.error.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: MintColors.error, size: 24),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.firstJob3aWarningTitle,
                  style: MintTextStyles.bodyMedium(color: MintColors.error)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.xs + 2),
                Text(
                  _result!.alerte3a,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── LAMal Franchise Comparison ─────────────────────────────

  Widget _buildLamalComparison() {
    final r = _result!;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.firstJobLamalHeader,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          // Franchise cards
          ...r.franchiseOptions.map((option) {
            final isRecommended = option.franchise == r.franchiseRecommandee;
            return Container(
              margin: const EdgeInsets.only(bottom: MintSpacing.sm),
              padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.sm + 6, vertical: MintSpacing.sm + 4),
              decoration: BoxDecoration(
                color: isRecommended
                    ? MintColors.success.withValues(alpha: 0.06)
                    : MintColors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isRecommended
                    ? Border.all(
                        color: MintColors.success.withValues(alpha: 0.15))
                    : Border.all(
                        color: MintColors.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  if (isRecommended)
                    Container(
                      margin: const EdgeInsets.only(right: MintSpacing.sm),
                      padding: const EdgeInsets.symmetric(
                          horizontal: MintSpacing.xs + 2, vertical: 2),
                      decoration: BoxDecoration(
                        color: MintColors.success,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        S.of(context)!.firstJobTopBadge,
                        style:
                            MintTextStyles.labelSmall(color: MintColors.white)
                                .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'CHF\u00a0${option.franchise}',
                      style: MintTextStyles.bodyMedium(
                        color: isRecommended
                            ? MintColors.success
                            : MintColors.textPrimary,
                      ).copyWith(
                          fontWeight: isRecommended
                              ? FontWeight.w700
                              : FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      S.of(context)!.firstJobPrimePerMonth(
                          FirstJobService.formatChf(option.primeMensuelle)),
                      style: MintTextStyles.labelSmall(
                          color: MintColors.textSecondary),
                    ),
                  ),
                  Text(
                    S.of(context)!.firstJobCoutMaxPerYear(
                        FirstJobService.formatChf(option.coutAnnuelMax)),
                    style: MintTextStyles.labelSmall(),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: MintSpacing.sm + 4),

          // Savings highlight
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined,
                    size: 16, color: MintColors.success),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    S.of(context)!.firstJobFranchiseSavings(
                        FirstJobService.formatChf(r.economieAnnuelleVs300)),
                    style: MintTextStyles.bodySmall(color: MintColors.success)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Note
          Text(
            r.noteLamal,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Checklist ──────────────────────────────────────────────

  Widget _buildChecklist() {
    final items = _result?.checklist ?? [];
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.firstJobChecklistHeader,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          ...List.generate(items.length, (index) {
            final checked = _checkedItems.contains(index);
            return Semantics(
              label: '${S.of(context)!.firstJobChecklistHeader} ${index + 1}',
              button: true,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (checked) {
                      _checkedItems.remove(index);
                    } else {
                      _checkedItems.add(index);
                    }
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: MintSpacing.sm + 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color:
                              checked ? MintColors.success : MintColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: checked
                                ? MintColors.success
                                : MintColors.border,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: checked
                            ? const Icon(Icons.check,
                                size: 16, color: MintColors.white)
                            : Text(
                                '${index + 1}',
                                style: MintTextStyles.labelSmall(
                                    color: MintColors.textSecondary),
                              ),
                      ),
                      const SizedBox(width: MintSpacing.sm + 4),
                      Expanded(
                        child: Text(
                          items[index],
                          style: MintTextStyles.bodyMedium(
                            color: checked
                                ? MintColors.textMuted
                                : MintColors.textPrimary,
                          ).copyWith(
                            decoration:
                                checked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Education ──────────────────────────────────────────────

  Widget _buildEducation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: MintSpacing.sm),
            Text(
              S.of(context)!.unemploymentGoodToKnow,
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildEduCard(
          Icons.account_balance_outlined,
          S.of(context)!.firstJobEduLppTitle,
          S.of(context)!.firstJobEduLppBody,
        ),
        _buildEduCard(
          Icons.receipt_long_outlined,
          S.of(context)!.firstJobEdu13Title,
          S.of(context)!.firstJobEdu13Body,
        ),
        _buildEduCard(
          Icons.savings_outlined,
          S.of(context)!.firstJobEduBudgetTitle,
          S.of(context)!.firstJobEduBudgetBody,
        ),
        _buildEduCard(
          Icons.description_outlined,
          S.of(context)!.firstJobEduTaxTitle,
          S.of(context)!.firstJobEduTaxBody,
        ),
      ],
    );
  }

  Widget _buildEduCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MintSurface(
              padding: const EdgeInsets.all(MintSpacing.sm),
              radius: 10,
              child: Icon(icon, size: 18, color: MintColors.primary),
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    body,
                    style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Analyse MINT ───────────────────────────────────────────

  Widget _buildMintAnalysisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildScenarioChips(),
        const SizedBox(height: MintSpacing.md),
        FirstSalaryFilmWidget(grossMonthly: _salaire),
        const SizedBox(height: MintSpacing.md + 4),
        _buildBudget503020(),
        const SizedBox(height: MintSpacing.md + 4),
        _buildCareerTimeLapse(),
      ],
    );
  }

  /// Future Value of annuity: annual * ((1+r)^n - 1) / r
  static double _fvAnnuity(double annual, int years, {double r = 0.04}) {
    if (years <= 0) return 0;
    return annual * ((pow(1 + r, years) - 1) / r);
  }

  Widget _buildBudget503020() {
    final l10n = S.of(context)!;
    // Ce bloc n'est monté que dans la branche gatée (_result != null) : un seul
    // net sur l'écran, celui de l'étalon — aucun ratio de repli fabriqué.
    final net = _result!.netEstime;
    final annualSavings = net * 0.20 * 12;
    final years = (avsAgeReferenceHomme - _age).clamp(0, 45);
    final fv = _fvAnnuity(annualSavings, years);
    return Budget503020Widget(
      netIncome: net,
      categories: [
        BudgetCategory(
          label: l10n.firstJobBudgetBesoins,
          emoji: '\u{1F3E0}',
          percent: 50,
          amount: net * 0.50,
          examples: [
            l10n.firstJobBudgetLoyer,
            'LAMal',
            l10n.firstJobBudgetTransport,
            l10n.firstJobBudgetAlimentation,
          ],
        ),
        BudgetCategory(
          label: l10n.firstJobBudgetEnvies,
          emoji: '\u2728',
          percent: 30,
          amount: net * 0.30,
          examples: [
            l10n.firstJobBudgetLoisirs,
            l10n.firstJobBudgetRestaurants,
            l10n.firstJobBudgetVoyages,
            l10n.firstJobBudgetShopping,
          ],
        ),
        BudgetCategory(
          label: l10n.firstJobBudgetEpargne,
          emoji: '\u{1F3E6}',
          percent: 20,
          amount: net * 0.20,
          examples: [
            l10n.firstJobBudgetPilier3a,
            l10n.firstJobBudgetEpargneCourt,
            l10n.firstJobBudgetFondsUrgence,
          ],
        ),
      ],
      premierEclairage: l10n.firstJobBudgetPremierEclairage(
        '${(annualSavings.round() ~/ 1000)}\'000',
        '~${(fv.round() ~/ 1000)}\'000',
      ),
    );
  }

  Widget _buildCareerTimeLapse() {
    const monthly3a = pilier3aPlafondAvecLpp / 12;
    const annual3a = monthly3a * 12;

    final candidateAges = [22, 25, 30, 35].where((a) => a <= _age + 5).toList();
    final scenarioAges = candidateAges.isEmpty ? [_age] : candidateAges;
    final scenarios = scenarioAges
        .map((a) => TimeLapseScenario(
              startAge: a,
              capitalAt65:
                  _fvAnnuity(annual3a, (avsAgeReferenceHomme - a).clamp(0, 45)),
            ))
        .toList();

    return CareerTimeLapseWidget(
      scenarios: scenarios,
      monthly3aContribution: monthly3a,
      initialAge: _age,
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            S.of(context)!.firstJobAnalysisHeader,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.sm + 2, vertical: MintSpacing.xs),
          decoration: BoxDecoration(
            color: _seededFromProfile
                ? MintColors.success.withValues(alpha: 0.1)
                : MintColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _seededFromProfile
                  ? MintColors.success.withValues(alpha: 0.15)
                  : MintColors.warning.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            _seededFromProfile
                ? '\u{1F4CD} ${S.of(context)!.firstJobProfileBadge}'
                : '\u{1F4A1} ${S.of(context)!.firstJobIllustrativeBadge}',
            style: MintTextStyles.labelSmall(
              color:
                  _seededFromProfile ? MintColors.success : MintColors.warning,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildScenarioChips() {
    final l10n = S.of(context)!;
    // Repère OFS daté (millésime visible via le label), pas un littéral en dur.
    const median = ofsSalaireMedianMensuelBrut;
    final profileVal = _seededFromProfile
        ? context.read<CoachProfileProvider>().profile?.salaireBrutMensuel ??
            5000.0
        : 5000.0;
    final boosted = (profileVal * 1.20).clamp(2000.0, 15000.0);

    final scenarios = [
      (
        label: _seededFromProfile
            ? '\u{1F4CD} ${l10n.firstJobScenarioMySalary}'
            : '\u{1F4CD} ${l10n.firstJobScenarioDefault}',
        value: profileVal.clamp(2000.0, 15000.0),
        active: (_salaire - profileVal.clamp(2000.0, 15000.0)).abs() < 50,
      ),
      (
        label: '\u{1F1E8}\u{1F1ED} ${l10n.firstJobScenarioMedianCH}',
        value: median,
        active: (_salaire - median).abs() < 50,
      ),
      (
        label: '\u2728 ${l10n.firstJobScenarioBoosted}',
        value: boosted,
        active: (_salaire - boosted).abs() < 50,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: scenarios.map((s) {
          return Padding(
            padding: const EdgeInsets.only(right: MintSpacing.sm),
            child: Semantics(
              label: l10n.firstJobScenarioSemantics(s.label),
              button: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  // Choisir un scénario de salaire = fournir un salaire (touch).
                  // Compte comme interaction pour le contrat de retour (sinon
                  // PopScope émet ScreenReturn.abandoned alors que l'utilisateur
                  // a bien agi).
                  _hasUserInteracted = true;
                  _salaireTouched = true;
                  _salaireSeeded = false;
                  _salaire = s.value;
                  _afterSituationFactChanged();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.sm + 6, vertical: MintSpacing.sm),
                  decoration: BoxDecoration(
                    color: s.active ? MintColors.primary : MintColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: s.active ? MintColors.primary : MintColors.border,
                      width: s.active ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    '${s.label}  CHF ${FirstJobService.formatChf(s.value)}',
                    style: MintTextStyles.labelSmall(
                      color:
                          s.active ? MintColors.white : MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.firstJobDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
