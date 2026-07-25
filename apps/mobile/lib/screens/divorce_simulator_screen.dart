import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/life_events_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/coach/divorce_film_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';
import 'package:mint_mobile/widgets/premium/mint_signal_row.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

/// Swiss CHF formatter with apostrophe grouping.
String _formatChfSwiss(double value) {
  final intVal = value.round();
  final isNeg = intVal < 0;
  final str = intVal.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write("'");
    }
    buffer.write(str[i]);
  }
  return '${isNeg ? '-' : ''}${buffer.toString()}';
}

/// Swiss CHF formatter with prefix.
String _chfFmt(double value) {
  return 'CHF\u00A0${_formatChfSwiss(value)}';
}

/// Les 26 codes cantonaux suisses \u2014 la \u00AB plage valide \u00BB du fait `canton`.
/// Le bar\u00E8me d'imp\u00F4t du divorce n'est confirm\u00E9 que pour un de ces codes ; une
/// cha\u00EEne vide, 'unknown', un blanc ou une valeur parasite ne confirment jamais.
const Set<String> _kSwissCantons = {
  'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR', 'JU', 'LU', 'NE',
  'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG', 'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
};

bool _isValidCanton(String c) => _kSwissCantons.contains(c.trim().toUpperCase());

/// Dual-party divorce simulator.
///
/// P2 « gate dur » (.planning/decisions/2026-07-25-p2-simulator-result-gating.md):
/// aucun chiffre « votre situation » n'est calculé sur un défaut fabriqué. Chaque
/// carte-résultat est gatée derrière les faits qu'ELLE consomme ; un fait n'est
/// CONFIRMÉ que s'il vient de données réelles — amorcé depuis le profil de
/// l'utilisateur (conjoint 1 = l'utilisateur) OU saisi par lui (valeur non nulle).
/// Un défaut = valeur nulle « Non renseigné », jamais un nombre inventé.
///
/// Provenance :
///   • conjoint 1 = l'UTILISATEUR → revenu/LPP/3a/enfants amorcés depuis les
///     données réelles (clé userProvidedFields + valeur dans la plage du contrôle) ;
///   • conjoint 2 = l'EX-CONJOINT → JAMAIS amorcé (aucune donnée du profil ne le
///     décrit) ; touch-only ;
///   • fortune / dettes / durée du mariage / avoir LPP au mariage → touch-only ;
///   • régime matrimonial → participation aux acquêts est le régime LÉGAL par
///     défaut (CC art. 181) : éducatif, pas fabriqué → non gaté.
class DivorceSimulatorScreen extends StatefulWidget {
  const DivorceSimulatorScreen({super.key});

  @override
  State<DivorceSimulatorScreen> createState() =>
      _DivorceSimulatorScreenState();
}

class _DivorceSimulatorScreenState extends State<DivorceSimulatorScreen> {
  final _scrollController = ScrollController();
  final _resultsKey = GlobalKey();

  // ---- Input State ----
  // Un fait consommé par un résultat est NULLABLE, défaut null : la valeur non
  // nulle EST le signal « donnée réelle » (saisie utilisateur OU seed profil).
  // Les picker-tiles (durée/enfants) restent des int (le wheel a besoin d'une
  // valeur affichable) et sont confirmés par un booléen `_touched` — 0 enfant
  // est une réponse valide, il doit être confirmé explicitement.

  // Section 1 — Situation familiale
  int _marriageDuration = 10;
  bool _marriageDurationTouched = false;
  int _numberOfChildren = 0;
  bool _childrenTouched = false;
  // Participation aux acquêts = régime légal par défaut (CC art. 181) →
  // éducatif, non gaté.
  MatrimonialRegime _regime = MatrimonialRegime.participationAuxAcquets;

  // Section 2 — Revenus
  double? _incomeConjoint1; // = l'UTILISATEUR (seedable)
  double? _incomeConjoint2; // = l'EX-CONJOINT (touch-only, jamais seedé)

  // Section 3 — Prévoyance
  double? _lppConjoint1; // = l'UTILISATEUR (seedable)
  double? _lppConjoint2; // = l'EX-CONJOINT (touch-only)
  // Avoir LPP de chaque conjoint AU MARIAGE (CC art. 122 / LFLP art. 22a).
  // Touch-only : sans cette donnée le partage ne peut pas être établi.
  double? _avoirAuMariage1;
  double? _avoirAuMariage2;
  double? _pillar3aConjoint1; // = l'UTILISATEUR (seedable) — non consommé par le
  // service (input inerte), mais amorcé par cohérence.
  double? _pillar3aConjoint2; // = l'EX-CONJOINT (touch-only)

  // Section 4 — Patrimoine (touch-only)
  double? _fortuneCommune;
  double? _dettesCommunes;

  // Canton de résidence RÉEL de l'utilisateur (= conjoint 1), amorcé depuis le
  // profil. Détermine le barème d'impôt du divorce. Aucun contrôle in-screen →
  // pour un utilisateur anonyme il reste null (impact fiscal gaté), la « why »
  // du gate renvoie vers le profil. null = non confirmé.
  String? _userCanton;

  // Result
  DivorceResult? _result;

  // Checklist state
  List<bool> _checklistState = [];

  bool _prefilled = false;

  // Baseline pour l'annonce VoiceOver au passage incomplet→complet.
  bool _lastAllComplete = false;

  // ── Ancres de scroll (« Compléter » depuis la carte de situation) ──
  final _income1Key = GlobalKey();
  final _income2Key = GlobalKey();
  final _lpp1Key = GlobalKey();
  final _lpp2Key = GlobalKey();
  final _avoir1Key = GlobalKey();
  final _avoir2Key = GlobalKey();
  final _fortuneKey = GlobalKey();
  final _dettesKey = GlobalKey();
  final _childrenKey = GlobalKey();
  final _durationKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefilled) {
      _prefilled = true;
      final profile = context.coachProfileOrNull;
      if (profile != null) {
        final provided = profile.userProvidedFields;
        // ── Conjoint 1 = l'UTILISATEUR ──
        // Un fait n'est amorcé — et donc confirmé — que depuis une donnée RÉELLE :
        // clé userProvidedFields (jamais valeur≠défaut) ET valeur DANS la plage du
        // contrôle. Hors plage → NON amorcé (jamais un clamp qui fabriquerait une
        // valeur ≠ la vraie).
        final gross = profile.salaireBrutMensuel * 12;
        if (provided.contains('salary') && gross >= 20000 && gross <= 300000) {
          _incomeConjoint1 = gross;
        }
        // LPP conjoint 1 : uniquement une valeur RÉELLE (certificat scanné), jamais
        // l'estimation âge×salaire (plans 07/11) — et dans la plage [>0, 500000].
        final lpp = profile.prevoyance.avoirLppTotal;
        if (lpp != null &&
            lpp > 0 &&
            lpp <= 500000 &&
            profile.prevoyance.isLppFromCertificate) {
          _lppConjoint1 = lpp;
        }
        // 3a conjoint 1 : solde réel > 0 dans la plage [>0, 200000].
        final p3a = profile.prevoyance.totalEpargne3a;
        if (p3a > 0 && p3a <= 200000) {
          _pillar3aConjoint1 = p3a;
        }
        // Nombre d'enfants : > 0 est une donnée réelle → confirme (touched).
        if (profile.nombreEnfants > 0) {
          _numberOfChildren = profile.nombreEnfants;
          _childrenTouched = true;
        }
        // Canton de résidence : provenance canonique du codebase (expat /
        // donation / demenagement) = clé 'canton' RÉELLEMENT fournie ET code
        // valide. La clé seule ne suffit pas (une valeur parasite 'XX' / '' avec
        // clé serait acceptée) ; la validité seule ne suffit pas non plus, car
        // `CoachProfile.fromJson` met `canton ?? 'ZH'` — un profil legacy/incomplet
        // porte 'ZH' SANS saisie utilisateur et passerait la validité. Les deux
        // ensemble : la clé n'est ajoutée (`coach_profile.dart` ~3436) que sur une
        // réponse réelle à `q_canton`. Un impôt fiscal sur un 'ZH' fabriqué est
        // exactement le trou que le gate dur ferme.
        if (profile.userProvidedFields.contains('canton') &&
            _isValidCanton(profile.canton)) {
          _userCanton = profile.canton;
        }
        // ── Conjoint 2 = l'EX-CONJOINT : JAMAIS amorcé (aucune donnée du profil
        //    ne le décrit ; le seeder depuis les avoirs de l'utilisateur serait la
        //    fabrication par cross-contamination). Touch-only. ──
        // fortune / dettes / durée / avoir au mariage : touch-only, jamais amorcés.
      }
    }
    // Baseline APRÈS le seed : pas d'annonce parasite si le profil confirmait déjà
    // tout (impossible ici — le seed ne touche que conjoint 1 —, mais on aligne le
    // motif des autres simulateurs).
    _lastAllComplete = _allGatesComplete(context);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Debug getters (@visibleForTesting) : les tests anti-façade assertent sur
  //    l'état confirmé (null == non renseigné) et sur le CHF rendu. ──
  @visibleForTesting
  double? get debugIncome1 => _incomeConjoint1;
  @visibleForTesting
  double? get debugIncome2 => _incomeConjoint2;
  @visibleForTesting
  double? get debugLpp1 => _lppConjoint1;
  @visibleForTesting
  double? get debugLpp2 => _lppConjoint2;
  @visibleForTesting
  double? get debugAvoir1 => _avoirAuMariage1;
  @visibleForTesting
  double? get debugAvoir2 => _avoirAuMariage2;
  @visibleForTesting
  double? get debug3a1 => _pillar3aConjoint1;
  @visibleForTesting
  double? get debug3a2 => _pillar3aConjoint2;
  @visibleForTesting
  double? get debugFortune => _fortuneCommune;
  @visibleForTesting
  double? get debugDettes => _dettesCommunes;
  @visibleForTesting
  int get debugChildren => _numberOfChildren;
  @visibleForTesting
  bool get debugChildrenTouched => _childrenTouched;
  @visibleForTesting
  bool get debugMarriageDurationTouched => _marriageDurationTouched;
  @visibleForTesting
  String? get debugCanton => _userCanton;

  // ── Provenance : non nul (saisi OU seedé depuis une donnée réelle) = confirmé ;
  //    nul = non renseigné (assumed, gate fermé). ──
  FactProvenance _prov(bool confirmed) =>
      confirmed ? FactProvenance.touched : FactProvenance.assumed;

  // ── Gates : chaque sortie gate sur les faits QU'ELLE consomme (ADR §2). ──

  // Partage LPP : avoir actuel + avoir au mariage des DEUX conjoints (CC art. 122).
  SituationGate _lppGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'lpp1',
          label: (c) => S.of(c)!.divorceGateFactLpp1,
          why: (c) => S.of(c)!.divorceGateWhyLpp1,
          provenance: _prov(_lppConjoint1 != null),
          onComplete: () => _scrollToKey(_lpp1Key),
        ),
        SituationFact(
          key: 'lpp2',
          label: (c) => S.of(c)!.divorceGateFactLpp2,
          why: (c) => S.of(c)!.divorceGateWhyLpp2,
          provenance: _prov(_lppConjoint2 != null),
          onComplete: () => _scrollToKey(_lpp2Key),
        ),
        SituationFact(
          key: 'avoir1',
          label: (c) => S.of(c)!.divorceGateFactAvoir1,
          why: (c) => S.of(c)!.divorceGateWhyAvoir1,
          provenance: _prov(_avoirAuMariage1 != null),
          onComplete: () => _scrollToKey(_avoir1Key),
        ),
        SituationFact(
          key: 'avoir2',
          label: (c) => S.of(c)!.divorceGateFactAvoir2,
          why: (c) => S.of(c)!.divorceGateWhyAvoir2,
          provenance: _prov(_avoirAuMariage2 != null),
          onComplete: () => _scrollToKey(_avoir2Key),
        ),
      ]);

  // Impact fiscal : revenu des deux conjoints + canton RÉEL (le barème d'impôt
  // dépend du canton — un chiffre fiscal sur un canton fabriqué serait faux).
  // Le canton n'a pas de contrôle in-screen → onComplete null (la « why » oriente
  // vers le profil).
  SituationGate _taxGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'income1',
          label: (c) => S.of(c)!.divorceGateFactRevenu1,
          why: (c) => S.of(c)!.divorceGateWhyRevenu1,
          provenance: _prov(_incomeConjoint1 != null),
          onComplete: () => _scrollToKey(_income1Key),
        ),
        SituationFact(
          key: 'income2',
          label: (c) => S.of(c)!.divorceGateFactRevenu2,
          why: (c) => S.of(c)!.divorceGateWhyRevenu2,
          provenance: _prov(_incomeConjoint2 != null),
          onComplete: () => _scrollToKey(_income2Key),
        ),
        SituationFact(
          key: 'canton',
          label: (c) => S.of(c)!.divorceGateFactCanton,
          why: (c) => S.of(c)!.divorceGateWhyCanton,
          provenance: _prov(_userCanton != null),
        ),
      ]);

  // Partage du patrimoine : fortune + dettes communes ; en séparation de biens le
  // partage suit les revenus → ils deviennent déterminants pour cette sortie.
  SituationGate _patrimoineGate(BuildContext context) {
    final facts = <SituationFact>[
      SituationFact(
        key: 'fortune',
        label: (c) => S.of(c)!.divorceGateFactFortune,
        why: (c) => S.of(c)!.divorceGateWhyFortune,
        provenance: _prov(_fortuneCommune != null),
        onComplete: () => _scrollToKey(_fortuneKey),
      ),
      SituationFact(
        key: 'dettes',
        label: (c) => S.of(c)!.divorceGateFactDettes,
        why: (c) => S.of(c)!.divorceGateWhyDettes,
        provenance: _prov(_dettesCommunes != null),
        onComplete: () => _scrollToKey(_dettesKey),
      ),
    ];
    if (_regime == MatrimonialRegime.separationDeBiens) {
      facts.addAll([
        SituationFact(
          key: 'income1',
          label: (c) => S.of(c)!.divorceGateFactRevenu1,
          why: (c) => S.of(c)!.divorceGateWhyRevenu1,
          provenance: _prov(_incomeConjoint1 != null),
          onComplete: () => _scrollToKey(_income1Key),
        ),
        SituationFact(
          key: 'income2',
          label: (c) => S.of(c)!.divorceGateFactRevenu2,
          why: (c) => S.of(c)!.divorceGateWhyRevenu2,
          provenance: _prov(_incomeConjoint2 != null),
          onComplete: () => _scrollToKey(_income2Key),
        ),
      ]);
    }
    return SituationGate(facts);
  }

  // Pension alimentaire : revenus des deux conjoints + nombre d'enfants + durée.
  SituationGate _pensionGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'income1',
          label: (c) => S.of(c)!.divorceGateFactRevenu1,
          why: (c) => S.of(c)!.divorceGateWhyRevenu1,
          provenance: _prov(_incomeConjoint1 != null),
          onComplete: () => _scrollToKey(_income1Key),
        ),
        SituationFact(
          key: 'income2',
          label: (c) => S.of(c)!.divorceGateFactRevenu2,
          why: (c) => S.of(c)!.divorceGateWhyRevenu2,
          provenance: _prov(_incomeConjoint2 != null),
          onComplete: () => _scrollToKey(_income2Key),
        ),
        SituationFact(
          key: 'enfants',
          label: (c) => S.of(c)!.divorceGateFactEnfants,
          why: (c) => S.of(c)!.divorceGateWhyEnfants,
          provenance: _prov(_childrenTouched),
          onComplete: () => _scrollToKey(_childrenKey),
        ),
        SituationFact(
          key: 'duree',
          label: (c) => S.of(c)!.divorceGateFactDuree,
          why: (c) => S.of(c)!.divorceGateWhyDuree,
          provenance: _prov(_marriageDurationTouched),
          onComplete: () => _scrollToKey(_durationKey),
        ),
      ]);

  bool _allGatesComplete(BuildContext context) =>
      _lppGate(context).complete &&
      _taxGate(context).complete &&
      _patrimoineGate(context).complete &&
      _pensionGate(context).complete;

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

  /// Un fait déterminant a bougé : invalide tout résultat périmé (un chiffre
  /// affiché ne survit jamais à un changement d'entrée) et annonce le passage
  /// incomplet→complet pour VoiceOver (le scroll ≠ déplacement de focus).
  void _onFactChanged(VoidCallback apply) {
    setState(() {
      apply();
      _result = null;
    });
    final nowComplete = _allGatesComplete(context);
    if (nowComplete && !_lastAllComplete) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        S.of(context)!.situationGateAnnounceComplete,
        Directionality.of(context),
      );
    }
    _lastAllComplete = nowComplete;
  }

  void _simulate() {
    // Défense en profondeur : le service peut calculer avec 0 pour un fait non
    // renseigné, mais le gate au rendu garantit qu'aucun chiffre dérivé d'un 0
    // fabriqué n'est jamais affiché.
    final input = DivorceInput(
      marriageDurationYears: _marriageDurationTouched ? _marriageDuration : 0,
      numberOfChildren: _childrenTouched ? _numberOfChildren : 0,
      regime: _regime,
      // Canton réel ou '' si non confirmé : le service calcule, mais le gate au
      // rendu bloque l'affichage tant que canton n'est pas confirmé.
      canton: _userCanton ?? '',
      incomeConjoint1: _incomeConjoint1 ?? 0,
      incomeConjoint2: _incomeConjoint2 ?? 0,
      lppConjoint1: _lppConjoint1 ?? 0,
      lppConjoint2: _lppConjoint2 ?? 0,
      avoirAuMariage1: _avoirAuMariage1,
      avoirAuMariage2: _avoirAuMariage2,
      pillar3aConjoint1: _pillar3aConjoint1 ?? 0,
      pillar3aConjoint2: _pillar3aConjoint2 ?? 0,
      fortuneCommune: _fortuneCommune ?? 0,
      dettesCommunes: _dettesCommunes ?? 0,
    );

    setState(() {
      _result = DivorceService.simulate(input: input);
      _checklistState = List.filled(_result!.checklist.length, false);
    });

    // Smooth scroll to results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resultsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _resultsKey.currentContext!,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ILLOG-02 : conteneur Semantics racine (motif rente_vs_capital) sinon le pont
    // AX iOS effondre toute la route en un seul nœud (« 1 element »).
    return Semantics(
      identifier: 'divorce_simulator_screen',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: MintColors.porcelaine,
        appBar: AppBar(
          backgroundColor: MintColors.porcelaine,
          surfaceTintColor: MintColors.porcelaine,
          foregroundColor: MintColors.textPrimary,
          title: Text(
            S.of(context)!.divorceAppBarTitle,
            style: MintTextStyles.headlineMedium(color: MintColors.textPrimary),
          ),
        ),
        body: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.lg,
            vertical: MintSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero: partage LPP impact (shown when results exist)
              if (_result != null) ...[
                Container(key: _resultsKey),
                _buildDivorceHeroCard(),
                const SizedBox(height: MintSpacing.xl),
              ] else ...[
                _buildIntroCard(),
                const SizedBox(height: MintSpacing.xl),
              ],
              _buildSituationFamilialeSection(),
              const SizedBox(height: MintSpacing.md),
              _buildRevenusSection(),
              const SizedBox(height: MintSpacing.md),
              _buildPrevoyanceSection(),
              const SizedBox(height: MintSpacing.md),
              _buildPatrimoineSection(),
              const SizedBox(height: MintSpacing.xl),
              _buildSimulateButton(),
              const SizedBox(height: MintSpacing.xl),
              if (_result != null) ...[
                _buildLppSplitCard(),
                const SizedBox(height: MintSpacing.xl),
                _buildTaxImpactCard(),
                const SizedBox(height: MintSpacing.xl),
                _buildPatrimoineSplitCard(),
                const SizedBox(height: MintSpacing.xl),
                _buildPensionAlimentaireCard(),
                const SizedBox(height: MintSpacing.xl),
                // Alertes : gatées derrière l'ensemble des faits pour qu'aucun CHF
                // (transfert LPP, delta fiscal) issu d'un 0 fabriqué n'y apparaisse.
                if (_allGatesComplete(context) &&
                    _result!.alerts.isNotEmpty) ...[
                  _buildAlertsSection(),
                  const SizedBox(height: MintSpacing.xl),
                ],
                _buildChecklistSection(),
                const SizedBox(height: MintSpacing.xl),
              ],
              _buildEducationalFooter(),
              const SizedBox(height: MintSpacing.xl),
              // Le film du divorce rend des CHF personnels (LPP, impôts, pension
              // alimentaire réelle) → gaté derrière les QUATRE sorties confirmées
              // (sa scène pension affiche la pension réelle du service, jamais un
              // forfait fabriqué).
              if (_result != null && _allGatesComplete(context)) ...[
                _buildMintDivorceSection(),
                const SizedBox(height: MintSpacing.xl),
              ],
              _buildDisclaimer(),
              const SizedBox(height: MintSpacing.xl + MintSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  // --- Hero Card (shown after simulation) ---
  Widget _buildDivorceHeroCard() {
    final r = _result!;
    final lppComplete = _lppGate(context).complete;
    final taxComplete = _taxGate(context).complete;
    // Tant que le partage LPP n'est pas entièrement renseigné (avoirs actuels +
    // avoirs au mariage des deux conjoints), le transfert ne peut pas être établi :
    // le hero rend « donnée requise », jamais un « CHF 0 » de transfert fabriqué
    // (CC art. 122 / LFLP art. 22a).
    if (!lppComplete) {
      return MintResultHeroCard(
        eyebrow: S.of(context)!.divorcePartageLpp,
        primaryValue: S.of(context)!.divorceHeroDonneeRequiseValue,
        primaryLabel: S.of(context)!.divorceHeroDonneeRequiseLabel,
        narrative: S.of(context)!.divorceSplitDonneeRequise,
        accentColor: MintColors.info,
        tone: MintSurfaceTone.peche,
      );
    }
    return MintResultHeroCard(
      eyebrow: S.of(context)!.divorcePartageLpp,
      primaryValue: _chfFmt(r.lppSplit.transferAmount),
      primaryLabel: S.of(context)!.divorceTransfertAmount(
        _chfFmt(r.lppSplit.transferAmount),
        r.lppSplit.transferDirection,
      ),
      // Le delta fiscal secondaire n'est affiché que si les revenus sont
      // renseignés — sinon on le retire (pas de delta fabriqué).
      secondaryValue:
          taxComplete ? _chfFmt(r.taxImpact.delta.abs()) : null,
      secondaryLabel: taxComplete ? S.of(context)!.divorceImpactFiscal : null,
      narrative: S.of(context)!.divorceHeaderSubtitle,
      accentColor: MintColors.error,
      tone: MintSurfaceTone.peche,
    );
  }

  // --- Intro Card (shown before simulation) ---
  Widget _buildIntroCard() {
    return MintSurface(
      tone: MintSurfaceTone.bleu,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline,
              size: 20, color: MintColors.info),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.divorceIntroText,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // --- Section 1: Situation Familiale ---
  Widget _buildSituationFamilialeSection() {
    return SimulatorCard(
      title: S.of(context)!.divorceSituationFamiliale,
      subtitle: S.of(context)!.divorceSituationSubtitle,
      icon: Icons.people_outline,
      accentColor: MintColors.purple,
      child: Column(
        children: [
          MintPickerTile(
            key: _durationKey,
            label: S.of(context)!.divorceDureeMariage,
            value: _marriageDuration,
            minValue: 1,
            maxValue: 40,
            formatValue: (v) => S.of(context)!.divorceYears(v),
            onChanged: (v) => _onFactChanged(() {
              _marriageDuration = v;
              _marriageDurationTouched = true;
            }),
          ),
          const SizedBox(height: MintSpacing.md),
          MintPickerTile(
            key: _childrenKey,
            label: S.of(context)!.divorceNbEnfants,
            value: _numberOfChildren,
            minValue: 0,
            maxValue: 5,
            formatValue: (v) => '$v',
            onChanged: (v) => _onFactChanged(() {
              _numberOfChildren = v;
              _childrenTouched = true;
            }),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildRegimeChips(),
        ],
      ),
    );
  }

  // --- Regime Chips ---
  Widget _buildRegimeChips() {
    final options = <MapEntry<MatrimonialRegime, String>>[
      MapEntry(
          MatrimonialRegime.participationAuxAcquets, S.of(context)!.divorceParticipationDefault),
      MapEntry(
          MatrimonialRegime.communauteDeBiens, S.of(context)!.divorceCommunaute),
      MapEntry(
          MatrimonialRegime.separationDeBiens, S.of(context)!.divorceSeparation),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.divorceRegimeMatrimonial,
          style: MintTextStyles.bodySmall(
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: MintSpacing.sm),
        Wrap(
          spacing: MintSpacing.sm,
          runSpacing: MintSpacing.sm,
          children: options.map((opt) {
            final selected = _regime == opt.key;
            return Semantics(
              label: '${S.of(context)!.divorceRegimeMatrimonial}\u00a0: ${opt.value}',
              button: true,
              selected: selected,
              child: GestureDetector(
              onTap: () => _onFactChanged(() => _regime = opt.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? MintColors.purple.withValues(alpha: 0.1)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? MintColors.purple
                        : MintColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  opt.value,
                  style: MintTextStyles.labelMedium(
                    color: selected
                        ? MintColors.purple
                        : MintColors.textSecondary,
                  ).copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Section 2: Revenus ---
  Widget _buildRevenusSection() {
    return SimulatorCard(
      title: S.of(context)!.divorceRevenus,
      subtitle: S.of(context)!.divorceRevenusSubtitle,
      icon: Icons.payments_outlined,
      accentColor: MintColors.purple,
      child: Column(
        children: [
          MintAmountField(
            key: _income1Key,
            label: S.of(context)!.divorceConjoint1Revenu,
            value: _incomeConjoint1 ?? 0,
            formatValue: (v) => _incomeConjoint1 == null
                ? S.of(context)!.divorceNonRenseigne
                : _chfFmt(v),
            onChanged: (v) => _onFactChanged(() => _incomeConjoint1 = v),
            min: 0,
            max: 300000,
          ),
          const SizedBox(height: MintSpacing.md),
          MintAmountField(
            key: _income2Key,
            label: S.of(context)!.divorceConjoint2Revenu,
            value: _incomeConjoint2 ?? 0,
            formatValue: (v) => _incomeConjoint2 == null
                ? S.of(context)!.divorceNonRenseigne
                : _chfFmt(v),
            onChanged: (v) => _onFactChanged(() => _incomeConjoint2 = v),
            min: 0,
            max: 300000,
          ),
        ],
      ),
    );
  }

  // --- Section 3: Prévoyance ---
  Widget _buildPrevoyanceSection() {
    return SimulatorCard(
      title: S.of(context)!.divorcePrevoyance,
      subtitle: S.of(context)!.divorcePrevoyanceSubtitle,
      icon: Icons.account_balance_outlined,
      accentColor: MintColors.purple,
      child: Column(
        children: [
          MintAmountField(
            key: _lpp1Key,
            label: S.of(context)!.divorceLppConjoint1,
            value: _lppConjoint1 ?? 0,
            formatValue: (v) => _lppConjoint1 == null
                ? S.of(context)!.divorceNonRenseigne
                : _chfFmt(v),
            onChanged: (v) => _onFactChanged(() => _lppConjoint1 = v),
            min: 0,
            max: 500000,
          ),
          const SizedBox(height: MintSpacing.md),
          MintAmountField(
            key: _avoir1Key,
            label: S.of(context)!.divorceAvoirAuMariage1,
            value: _avoirAuMariage1 ?? 0,
            formatValue: (v) => _avoirAuMariage1 == null
                ? S.of(context)!.divorceNonRenseigne
                : _chfFmt(v),
            onChanged: (v) => _onFactChanged(() => _avoirAuMariage1 = v),
            min: 0,
            max: 500000,
          ),
          const SizedBox(height: MintSpacing.md),
          MintAmountField(
            key: _lpp2Key,
            label: S.of(context)!.divorceLppConjoint2,
            value: _lppConjoint2 ?? 0,
            formatValue: (v) => _lppConjoint2 == null
                ? S.of(context)!.divorceNonRenseigne
                : _chfFmt(v),
            onChanged: (v) => _onFactChanged(() => _lppConjoint2 = v),
            min: 0,
            max: 500000,
          ),
          const SizedBox(height: MintSpacing.md),
          MintAmountField(
            key: _avoir2Key,
            label: S.of(context)!.divorceAvoirAuMariage2,
            value: _avoirAuMariage2 ?? 0,
            formatValue: (v) => _avoirAuMariage2 == null
                ? S.of(context)!.divorceNonRenseigne
                : _chfFmt(v),
            onChanged: (v) => _onFactChanged(() => _avoirAuMariage2 = v),
            min: 0,
            max: 500000,
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            S.of(context)!.divorceAvoirAuMariageHint,
            style: MintTextStyles.bodySmall(
              color: MintColors.textMuted,
            ).copyWith(height: 1.4),
          ),
          const SizedBox(height: MintSpacing.md),
          MintAmountField(
            label: S.of(context)!.divorce3aConjoint1,
            value: _pillar3aConjoint1 ?? 0,
            formatValue: (v) => _pillar3aConjoint1 == null
                ? S.of(context)!.divorceNonRenseigne
                : _chfFmt(v),
            onChanged: (v) => _onFactChanged(() => _pillar3aConjoint1 = v),
            min: 0,
            max: 200000,
          ),
          const SizedBox(height: MintSpacing.md),
          MintAmountField(
            label: S.of(context)!.divorce3aConjoint2,
            value: _pillar3aConjoint2 ?? 0,
            formatValue: (v) => _pillar3aConjoint2 == null
                ? S.of(context)!.divorceNonRenseigne
                : _chfFmt(v),
            onChanged: (v) => _onFactChanged(() => _pillar3aConjoint2 = v),
            min: 0,
            max: 200000,
          ),
        ],
      ),
    );
  }

  // --- Section 4: Patrimoine ---
  Widget _buildPatrimoineSection() {
    return SimulatorCard(
      title: S.of(context)!.divorcePatrimoine,
      subtitle: S.of(context)!.divorcePatrimoineSubtitle,
      icon: Icons.home_outlined,
      accentColor: MintColors.purple,
      child: Column(
        children: [
          MintAmountField(
            key: _fortuneKey,
            label: S.of(context)!.divorceFortune,
            value: _fortuneCommune ?? 0,
            formatValue: (v) => _fortuneCommune == null
                ? S.of(context)!.divorceNonRenseigne
                : _chfFmt(v),
            onChanged: (v) => _onFactChanged(() => _fortuneCommune = v),
            min: 0,
            max: 2000000,
          ),
          const SizedBox(height: MintSpacing.md),
          MintAmountField(
            key: _dettesKey,
            label: S.of(context)!.divorceDettes,
            value: _dettesCommunes ?? 0,
            formatValue: (v) => _dettesCommunes == null
                ? S.of(context)!.divorceNonRenseigne
                : _chfFmt(v),
            onChanged: (v) => _onFactChanged(() => _dettesCommunes = v),
            min: 0,
            max: 1000000,
          ),
        ],
      ),
    );
  }

  // --- Simulate Button ---
  Widget _buildSimulateButton() {
    return SizedBox(
      width: double.infinity,
      child: Semantics(
        button: true,
        label: S.of(context)!.divorceSimuler,
        child: FilledButton.icon(
          onPressed: _simulate,
          icon: const Icon(Icons.calculate_outlined, size: 20),
          label: Text(
            S.of(context)!.divorceSimuler,
            style: MintTextStyles.titleMedium(color: MintColors.white),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: MintColors.primary,
            foregroundColor: MintColors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  // --- LPP Split Card ---
  Widget _buildLppSplitCard() {
    final gate = _lppGate(context);
    if (!gate.complete) {
      return SituationGateCard(
        title: S.of(context)!.divorcePartageLpp,
        gate: gate,
      );
    }
    // Gate complet ⇒ avoirs au mariage renseignés ⇒ le service isole la part
    // acquise pendant le mariage (jamais incomplet ici).
    final r = _result!;
    return MintSurface(
      tone: MintSurfaceTone.bleu,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.divorcePartageLpp,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: MintSpacing.md),
          MintSignalRow(
            label: S.of(context)!.divorceTotalLpp,
            value: _chfFmt(r.lppSplit.totalLpp),
          ),
          MintSignalRow(
            label: S.of(context)!.divorcePartConjoint1,
            value: _chfFmt(r.lppSplit.shareConjoint1),
          ),
          MintSignalRow(
            label: S.of(context)!.divorcePartConjoint2,
            value: _chfFmt(r.lppSplit.shareConjoint2),
          ),
          if (r.lppSplit.transferAmount > 0) ...[
            const SizedBox(height: MintSpacing.sm),
            MintSurface(
              tone: MintSurfaceTone.blanc,
              padding: const EdgeInsets.all(MintSpacing.sm + 4),
              radius: 12,
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward,
                      size: 16, color: MintColors.info),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Semantics(
                      label: S.of(context)!.divorceTransfertAmount(
                        _chfFmt(r.lppSplit.transferAmount),
                        r.lppSplit.transferDirection,
                      ),
                      child: Text(
                        S.of(context)!.divorceTransfertAmount(
                          _chfFmt(r.lppSplit.transferAmount),
                          r.lppSplit.transferDirection,
                        ),
                        style: MintTextStyles.bodyMedium(
                          color: MintColors.info,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Tax Impact Card ---
  Widget _buildTaxImpactCard() {
    final gate = _taxGate(context);
    if (!gate.complete) {
      return SituationGateCard(
        title: S.of(context)!.divorceImpactFiscal,
        gate: gate,
      );
    }
    final r = _result!;
    final isIncrease = r.taxImpact.delta > 0;
    final accentColor = isIncrease ? MintColors.warning : MintColors.success;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.divorceImpactFiscal,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: MintSpacing.md),
          MintSignalRow(
            label: S.of(context)!.divorceImpotMarie,
            value: _chfFmt(r.taxImpact.estimatedTaxMarried),
          ),
          MintSignalRow(
            label: S.of(context)!.divorceImpotConjoint1,
            value: _chfFmt(r.taxImpact.estimatedTaxConjoint1),
          ),
          MintSignalRow(
            label: S.of(context)!.divorceImpotConjoint2,
            value: _chfFmt(r.taxImpact.estimatedTaxConjoint2),
          ),
          Divider(color: MintColors.border.withValues(alpha: 0.3)),
          MintSignalRow(
            label: S.of(context)!.divorceTotalApresDivorce,
            value: _chfFmt(r.taxImpact.totalTaxAfter),
            valueColor: accentColor,
          ),
          const SizedBox(height: MintSpacing.sm),
          MintSurface(
            tone: isIncrease ? MintSurfaceTone.peche : MintSurfaceTone.sauge,
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            radius: 12,
            child: Row(
              children: [
                Icon(
                  isIncrease ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: accentColor,
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Semantics(
                    label: S.of(context)!.divorceFiscalDelta(
                      isIncrease ? '+' : '',
                      _chfFmt(r.taxImpact.delta),
                    ),
                    child: Text(
                      S.of(context)!.divorceFiscalDelta(
                        isIncrease ? '+' : '',
                        _chfFmt(r.taxImpact.delta),
                      ),
                      style: MintTextStyles.bodyMedium(
                        color: accentColor,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          // Transparence : le service applique le canton (confirmé) du ménage aux
          // DEUX conjoints. Au moment du divorce le domicile est commun → c'est la
          // base correcte ; le canton futur de l'ex n'est pas connu et n'est pas
          // inventé. On l'énonce plutôt que de le laisser implicite.
          Text(
            S.of(context)!.divorceImpactFiscalCantonNote,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  // --- Patrimoine Split Card ---
  Widget _buildPatrimoineSplitCard() {
    final gate = _patrimoineGate(context);
    if (!gate.complete) {
      return SituationGateCard(
        title: S.of(context)!.divorcePartagePatrimoine,
        gate: gate,
      );
    }
    final r = _result!;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.divorcePartagePatrimoine,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: MintSpacing.md),
          MintSignalRow(
            label: S.of(context)!.divorceFortuneNette,
            value: _chfFmt(r.patrimoineSplit.fortuneNette),
          ),
          const SizedBox(height: MintSpacing.sm),
          // Visual bar for split
          Semantics(
            label: S.of(context)!.divorcePartagePatrimoine,
            child: _buildSplitBar(
              r.patrimoineSplit.shareConjoint1,
              r.patrimoineSplit.shareConjoint2,
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          MintSignalRow(
            label: S.of(context)!.divorceConjoint1Label,
            value: _chfFmt(r.patrimoineSplit.shareConjoint1),
          ),
          MintSignalRow(
            label: S.of(context)!.divorceConjoint2Label,
            value: _chfFmt(r.patrimoineSplit.shareConjoint2),
          ),
        ],
      ),
    );
  }

  // --- Split Bar Visual ---
  Widget _buildSplitBar(double share1, double share2) {
    final total = share1.abs() + share2.abs();
    final pct1 = total > 0 ? share1.abs() / total : 0.5;
    return Container(
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Flexible(
              flex: (pct1 * 100).toInt().clamp(1, 99),
              child: Container(
                color: MintColors.purple,
                alignment: Alignment.center,
                child: Text(
                  S.of(context)!.divorceSplitC1,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.white,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Flexible(
              flex: ((1 - pct1) * 100).toInt().clamp(1, 99),
              child: Container(
                color: MintColors.purple.withValues(alpha: 0.15),
                alignment: Alignment.center,
                child: Text(
                  S.of(context)!.divorceSplitC2,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.purple,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Pension Alimentaire Card ---
  Widget _buildPensionAlimentaireCard() {
    final gate = _pensionGate(context);
    if (!gate.complete) {
      return SituationGateCard(
        title: S.of(context)!.divorcePensionAlimentaire,
        gate: gate,
      );
    }
    final r = _result!;
    if (r.pensionAlimentaireMonthly <= 0) {
      return const SizedBox.shrink();
    }
    return MintSurface(
      tone: MintSurfaceTone.peche,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.divorcePensionAlimentaire,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: MintSpacing.md),
          Semantics(
            label: S.of(context)!.divorcePensionMois(
              _chfFmt(r.pensionAlimentaireMonthly),
            ),
            child: Text(
              S.of(context)!.divorcePensionMois(
                _chfFmt(r.pensionAlimentaireMonthly),
              ),
              style: MintTextStyles.displaySmall(
                color: MintColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.divorcePensionAnnuel(
              _chfFmt(r.pensionAlimentaireMonthly * 12),
            ),
            style: MintTextStyles.bodyMedium(
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            S.of(context)!.divorcePensionDescription,
            style: MintTextStyles.labelMedium(
              color: MintColors.textMuted,
            ).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  // --- Alerts Section ---
  Widget _buildAlertsSection() {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.divorcePointsAttention,
          style: MintTextStyles.labelMedium(
            color: MintColors.textMuted,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        ...r.alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm),
              child: MintSurface(
                tone: MintSurfaceTone.peche,
                padding: const EdgeInsets.all(14),
                radius: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: MintColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        alert,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary,
                        ).copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // --- Checklist Section ---
  Widget _buildChecklistSection() {
    final r = _result!;
    return SimulatorCard(
      title: S.of(context)!.divorceActionsTitle,
      subtitle: S.of(context)!.divorceActionsSubtitle,
      icon: Icons.checklist,
      accentColor: MintColors.purple,
      child: Column(
        children: List.generate(r.checklist.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: MintSpacing.sm),
            child: Semantics(
              label: r.checklist[index],
              toggled: _checklistState[index],
              child: InkWell(
              onTap: () {
                setState(() {
                  _checklistState[index] = !_checklistState[index];
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.sm + 4,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _checklistState[index]
                      ? MintColors.success.withValues(alpha: 0.06)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _checklistState[index]
                        ? MintColors.success.withValues(alpha: 0.3)
                        : MintColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _checklistState[index]
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                      color: _checklistState[index]
                          ? MintColors.success
                          : MintColors.textMuted,
                    ),
                    const SizedBox(width: MintSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        r.checklist[index],
                        style: MintTextStyles.bodySmall(
                          color: _checklistState[index]
                              ? MintColors.textSecondary
                              : MintColors.textPrimary,
                        ).copyWith(
                          decoration: _checklistState[index]
                              ? TextDecoration.lineThrough
                              : null,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          );
        }),
      ),
    );
  }

  // --- Educational Footer ---
  Widget _buildEducationalFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.divorceComprendre,
          style: MintTextStyles.labelMedium(
            color: MintColors.textMuted,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildExpandableTile(
          S.of(context)!.divorceEduParticipationTitle,
          S.of(context)!.divorceEduParticipationContent,
        ),
        const SizedBox(height: MintSpacing.sm),
        _buildExpandableTile(
          S.of(context)!.divorceEduLppTitle,
          S.of(context)!.divorceEduLppContent,
        ),
      ],
    );
  }

  // --- Expandable Tile ---
  Widget _buildExpandableTile(String title, String content) {
    return MintSurface(
      tone: MintSurfaceTone.craie,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: MintColors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: MintSpacing.md, vertical: MintSpacing.xs),
          childrenPadding: const EdgeInsets.fromLTRB(MintSpacing.md, 0, MintSpacing.md, MintSpacing.md),
          title: Text(
            title,
            style: MintTextStyles.bodyMedium(
              color: MintColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
          children: [
            Text(
              content,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ).copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // --- Disclaimer ---
  Widget _buildDisclaimer() {
    return Semantics(
      label: S.of(context)!.divorceDisclaimer,
      child: MintSurface(
        tone: MintSurfaceTone.peche,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: MintColors.corailDiscret),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Text(
                S.of(context)!.divorceDisclaimer,
                style: MintTextStyles.labelSmall(
                  color: MintColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MINT Coach Widget: Divorce Film ---
  // Rendu uniquement quand les QUATRE sorties sont confirmées (voir build) →
  // chaque CHF du film trace une valeur réelle du service (myLpp/partnerLpp,
  // impôts, pension alimentaire), jamais un forfait fabriqué.
  Widget _buildMintDivorceSection() {
    final r = _result!;
    return DivorceFilmWidget(
      myLpp: _lppConjoint1!,
      partnerLpp: _lppConjoint2!,
      // Transfert LPP RÉEL du service (part acquise PENDANT le mariage, CC art.
      // 122 / LFLP art. 22a) — jamais un partage du solde total recalculé dans
      // le widget. Même valeur que la carte Partage LPP / le hero.
      lppTransfer: r.lppSplit.transferAmount,
      lppTransferDirection: r.lppSplit.transferDirection,
      annualTaxMarried: r.taxImpact.estimatedTaxMarried,
      annualTaxSingle: r.taxImpact.estimatedTaxConjoint1 +
          r.taxImpact.estimatedTaxConjoint2,
      childrenCount: _childrenTouched ? _numberOfChildren : 0,
      // Pension alimentaire RÉELLE (écart de revenus + enfants + durée, service
      // income-gap) — la même valeur que la carte Pension, jamais un forfait
      // CHF 1'500/enfant + CHF 500 codé en dur.
      monthlyPension: r.pensionAlimentaireMonthly,
    );
  }

}
