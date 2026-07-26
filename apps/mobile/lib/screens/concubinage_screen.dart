import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_hero_number.dart';
import 'package:mint_mobile/widgets/visualizations/concubinage_decision_matrix.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

// ────────────────────────────────────────────────────────────
//  CONCUBINAGE SCREEN — Category C (Life Event)
// ────────────────────────────────────────────────────────────
//
// Three-tab decision-support screen:
//   Tab 1: "Comparateur" — Mariage vs Concubinage matrix + hero chiffre-choc
//   Tab 2: "Protection"  — Survivor benefits gap + comparison table
//   Tab 3: "Checklist"   — Essential protections for concubins
//
// Design System: MintTextStyles + MintSpacing tokens.
// AppBar: white standard (Life Event screen).
// Ne constitue pas un conseil juridique ou fiscal (LSFin).
// ────────────────────────────────────────────────────────────

/// Les 26 codes cantonaux suisses — la « plage valide » du fait `canton`.
/// Le barème d'impôt et le taux de succession ne sont confirmés que pour un de
/// ces codes ; une chaîne vide, 'unknown', un blanc ou une valeur parasite ne
/// confirment jamais (ferme le défaut `fromJson canton ?? 'ZH'`).
const Set<String> _kSwissCantons = {
  'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR', 'JU', 'LU', 'NE',
  'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG', 'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
};

bool _isValidCanton(String c) => _kSwissCantons.contains(c.trim().toUpperCase());

/// Comparateur mariage / concubinage (dual-party : partenaire 1 = l'utilisateur,
/// partenaire 2 = son concubin).
///
/// P2 « gate dur » (.planning/decisions/2026-07-25-p2-simulator-result-gating.md):
/// aucun chiffre « ta situation » n'est affiché sur un défaut fabriqué. Chaque
/// carte-résultat est gatée derrière les faits qu'ELLE consomme ; un fait n'est
/// CONFIRMÉ que s'il vient de données réelles — amorcé depuis le profil (clé
/// userProvidedFields + valeur dans la plage) OU saisi (valeur non nulle).
///
/// Provenance :
///   • revenu 1 = l'UTILISATEUR → amorcé depuis `salary` réel dans la plage ;
///   • revenu 2 = le PARTENAIRE → amorcé UNIQUEMENT depuis `conjoint` réel,
///     JAMAIS depuis le salaire de l'utilisateur (cross-contamination) ;
///   • canton → amorcé depuis `canton` réel (clé + code valide), sinon touch
///     via le sélecteur à l'écran ;
///   • patrimoine / rente LPP du partenaire → touch-only (aucune clé de
///     provenance ne couvre le patrimoine total ni la rente du partenaire) ;
///   • épargne 3a → seulement un solde réel du profil, jamais une estimation.
class ConcubinageScreen extends StatefulWidget {
  const ConcubinageScreen({super.key});

  @override
  State<ConcubinageScreen> createState() => _ConcubinageScreenState();
}

class _ConcubinageScreenState extends State<ConcubinageScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: Comparateur inputs ─────────────────────────
  // Un fait consommé par un résultat est NULLABLE, défaut null : la valeur non
  // nulle EST le signal « donnée réelle » (saisie OU seed profil). Un défaut =
  // null « Non renseigné », jamais un nombre inventé (80000 / 60000 / 300000).
  double? _revenu1; // = l'UTILISATEUR (seedable depuis `salary`)
  double? _revenu2; // = le PARTENAIRE (seedable depuis `conjoint`, jamais soi)
  double? _patrimoine; // touch-only
  // Le sélecteur de canton a besoin d'une valeur affichable → `_canton` reste
  // non nul, mais le GATE ne le considère confirmé que via `_cantonConfirmed`
  // (touché à l'écran OU seedé depuis un canton réel). 'VD' non touché = non
  // confirmé → gaté.
  String _canton = 'VD';
  bool _cantonConfirmed = false;
  Map<String, dynamic>? _comparisonResult;

  // ── Tab 2: Protection ─────────────────────────────────
  double? _renteLpp; // rente LPP mensuelle du PARTENAIRE (touch-only)

  // ── Tab 3: Checklist state ────────────────────────────
  final Set<int> _checkedItems = {};
  final Map<int, bool> _expandedItems = {};

  bool _seeded = false;

  // Baseline pour l'annonce VoiceOver au passage incomplet→complet.
  bool _lastAllComplete = false;

  // ── Ancres de scroll (« Compléter » depuis une carte de situation) ──
  final _revenu1Key = GlobalKey();
  final _revenu2Key = GlobalKey();
  final _patrimoineKey = GlobalKey();
  final _cantonKey = GlobalKey();
  final _renteLppKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Pas de calcul ici : `_recompute()` n'a lieu qu'après le seed (données
    // réelles) — aucun chiffre fabriqué n'est produit à l'ouverture.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      _seeded = true;
      final profile = context.coachProfileOrNull;
      if (profile != null) {
        final provided = profile.userProvidedFields;
        // ── revenu 1 = l'UTILISATEUR ──
        // Confirmé seulement depuis une donnée RÉELLE : clé `salary` ET valeur
        // dans la plage du champ. Hors plage → NON amorcé (jamais un clamp qui
        // fabriquerait une valeur ≠ la vraie).
        final gross = profile.salaireBrutMensuel * 12;
        if (provided.contains('salary') && gross >= 20000 && gross <= 300000) {
          _revenu1 = gross;
        }
        // ── revenu 2 = le PARTENAIRE ──
        // Amorcé UNIQUEMENT depuis un revenu de conjoint réellement déclaré
        // (jamais depuis le salaire de l'utilisateur = cross-contamination,
        // leçon deces_proche / divorce). null → touch-only.
        final partnerMonthly = profile.conjoint?.salaireBrutMensuel;
        if (partnerMonthly != null) {
          final partnerAnnual = partnerMonthly * 12;
          if (partnerAnnual >= 20000 && partnerAnnual <= 300000) {
            _revenu2 = partnerAnnual;
          }
        }
        // ── canton ──
        // Provenance canonique = clé 'canton' RÉELLEMENT fournie ET code valide.
        // La clé seule ne suffit pas ('' / 'XX' keyed passeraient) ; la validité
        // seule non plus (`fromJson` met `canton ?? 'ZH'` → 'ZH' legacy sans
        // saisie). Les deux ensemble ferment le trou.
        if (provided.contains('canton') && _isValidCanton(profile.canton)) {
          _canton = profile.canton.trim().toUpperCase();
          _cantonConfirmed = true;
        }
        // patrimoine / rente LPP : touch-only, jamais amorcés.
      }
      _recompute();
      _lastAllComplete = _allInputGatesComplete(context);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Recalcule avec des sentinelles (0 / '') pour tout fait non renseigné : le
  // service peut calculer, mais le GATE au rendu garantit qu'aucun chiffre dérivé
  // d'un 0/''-fabriqué n'est affiché (défense en profondeur, motif divorce).
  void _recompute() {
    _comparisonResult = FamilyService.compareMariageVsConcubinage(
      revenu1: _revenu1 ?? 0,
      revenu2: _revenu2 ?? 0,
      canton: _cantonConfirmed ? _canton : '',
      patrimoine: _patrimoine ?? 0,
    );
  }

  // ── Debug getters (@visibleForTesting) : les tests anti-façade assertent sur
  //    l'état confirmé (null == non renseigné) et sur le CHF rendu. ──
  @visibleForTesting
  double? get debugRevenu1 => _revenu1;
  @visibleForTesting
  double? get debugRevenu2 => _revenu2;
  @visibleForTesting
  double? get debugPatrimoine => _patrimoine;
  @visibleForTesting
  double? get debugRenteLpp => _renteLpp;
  @visibleForTesting
  bool get debugCantonConfirmed => _cantonConfirmed;
  @visibleForTesting
  String get debugCanton => _canton;
  @visibleForTesting
  TabController get debugTabController => _tabController;

  // ── Provenance : confirmé (saisi OU seedé depuis une donnée réelle) vs
  //    assumed (défaut null → gate fermé). ──
  FactProvenance _prov(bool confirmed) =>
      confirmed ? FactProvenance.touched : FactProvenance.assumed;

  // Comparaison fiscale (impôt du couple + score + matrice) : écart d'impôt
  // → revenu des deux partenaires + canton réel (le barème dépend du canton).
  SituationGate _fiscalGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'revenu1',
          label: (c) => S.of(c)!.concubinageGateFactRevenu1,
          why: (c) => S.of(c)!.concubinageGateWhyRevenu1,
          provenance: _prov(_revenu1 != null),
          onComplete: () => _scrollToKey(_revenu1Key),
        ),
        SituationFact(
          key: 'revenu2',
          label: (c) => S.of(c)!.concubinageGateFactRevenu2,
          why: (c) => S.of(c)!.concubinageGateWhyRevenu2,
          provenance: _prov(_revenu2 != null),
          onComplete: () => _scrollToKey(_revenu2Key),
        ),
        SituationFact(
          key: 'canton',
          label: (c) => S.of(c)!.concubinageGateFactCanton,
          why: (c) => S.of(c)!.concubinageGateWhyCanton,
          provenance: _prov(_cantonConfirmed),
          onComplete: () => _scrollToKey(_cantonKey),
        ),
      ]);

  // Impôt de succession : patrimoine transmis + canton (le taux « tiers » est
  // cantonal — un impôt sur un canton fabriqué serait faux).
  SituationGate _inheritanceGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'patrimoine',
          label: (c) => S.of(c)!.concubinageGateFactPatrimoine,
          why: (c) => S.of(c)!.concubinageGateWhyPatrimoine,
          provenance: _prov(_patrimoine != null),
          onComplete: () => _scrollToKey(_patrimoineKey),
        ),
        SituationFact(
          key: 'canton',
          label: (c) => S.of(c)!.concubinageGateFactCanton,
          why: (c) => S.of(c)!.concubinageGateWhyCanton,
          provenance: _prov(_cantonConfirmed),
          onComplete: () => _scrollToKey(_cantonKey),
        ),
      ]);

  // Rente de survivant (comparaison marié vs concubin) : dépend de la rente LPP
  // mensuelle du partenaire.
  SituationGate _survivorGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'renteLpp',
          label: (c) => S.of(c)!.concubinageGateFactRenteLpp,
          why: (c) => S.of(c)!.concubinageGateWhyRenteLpp,
          provenance: _prov(_renteLpp != null),
          onComplete: () => _scrollToKey(_renteLppKey),
        ),
      ]);

  // NB : pas de gate 3a. Le solde 3a (`prevoyance.totalEpargne3a`) n'a AUCUNE
  // provenance fiable côté profil (pas de clé `userProvidedFields`, pas d'entrée
  // `dataSources`) et peut être ESTIMÉ (`coach_profile.dart` ~2955) — un chiffre
  // « ton 3a = CHF X » serait donc potentiellement fabriqué. Sans contrôle à
  // l'écran, un gate keyed serait une impasse permanente. On remplace la carte
  // chiffrée par un encart ÉDUCATIF conditionnel (aucun montant, cf. Tab2).

  // Gates pilotés par des saisies à l'écran (pour l'annonce VoiceOver au passage
  // incomplet→complet). Le gate 3a est piloté par le profil (hors écran) → exclu.
  bool _allInputGatesComplete(BuildContext context) =>
      _fiscalGate(context).complete &&
      _inheritanceGate(context).complete &&
      _survivorGate(context).complete;

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  /// Un fait déterminant a bougé : recalcule (un chiffre affiché ne survit jamais
  /// à un changement d'entrée) et annonce le passage incomplet→complet pour
  /// VoiceOver (le scroll ≠ déplacement de focus).
  void _onFactChanged(VoidCallback apply) {
    setState(() {
      apply();
      _recompute();
    });
    final nowComplete = _allInputGatesComplete(context);
    if (nowComplete && !_lastAllComplete) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        S.of(context)!.situationGateAnnounceComplete,
        Directionality.of(context),
      );
    }
    _lastAllComplete = nowComplete;
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // ILLOG-02 : conteneur Semantics racine (motif rente_vs_capital) sinon le
    // pont AX iOS effondre toute la route en un seul nœud.
    return Semantics(
      identifier: 'concubinage_screen',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: MintColors.background,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildAppBar(context, innerBoxIsScrolled),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTab1Comparateur(),
              _buildTab2Protection(),
              _buildTab3Checklist(),
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
      backgroundColor: MintColors.white,
      elevation: 0,
      surfaceTintColor: MintColors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => safePop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 56, right: MintSpacing.md),
        title: Text(
          S.of(context)!.concubinageAppBarTitle,
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
        unselectedLabelStyle: MintTextStyles.bodySmall(color: MintColors.textMuted),
        tabs: [
          Tab(text: S.of(context)!.concubinageTabComparateur),
          Tab(text: S.of(context)!.concubinageTabProtection),
          Tab(text: S.of(context)!.concubinageTabChecklist),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: COMPARATEUR — Mariage vs Concubinage
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Comparateur() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Hero chiffre-choc — patrimoine exposé. Gaté par affichage : masqué tant
        // que le patrimoine n'est pas confirmé (jamais un 300000 fabriqué).
        if (_patrimoine != null) ...[
          MintEntrance(child: _buildHeroPremierEclairage()),
          const SizedBox(height: MintSpacing.lg),
        ],

        // Inputs
        MintEntrance(
          delay: const Duration(milliseconds: 100),
          child: _buildComparateurInputs(),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Cluster fiscal (matrice + score + détail) — gaté sur revenu1 + revenu2
        // + canton (l'écart d'impôt et le verdict de score en dépendent).
        MintEntrance(
          delay: const Duration(milliseconds: 200),
          child: _buildFiscalCluster(),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Impôt de succession — gaté sur patrimoine + canton.
        MintEntrance(
          delay: const Duration(milliseconds: 300),
          child: _buildInheritanceSection(),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Educational insert — AVS cap 150% (LAVS art. 35)
        MintEntrance(
          delay: const Duration(milliseconds: 350),
          child: _buildEducationalInsert(
            S.of(context)!.concubinageEducationalAvs,
          ),
        ),
        const SizedBox(height: MintSpacing.md),

        // Educational insert — Succession
        MintEntrance(
          delay: const Duration(milliseconds: 400),
          child: _buildEducationalInsert(
            S.of(context)!.concubinageEducationalSuccession,
          ),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Neutral conclusion
        MintEntrance(
          delay: const Duration(milliseconds: 450),
          child: _buildNeutralConclusion(),
        ),
        const SizedBox(height: MintSpacing.lg),

        _buildDisclaimer(),
      ],
    );
  }

  // Rendu uniquement quand `_patrimoine` est confirmé (voir `_buildTab1`).
  Widget _buildHeroPremierEclairage() {
    return Semantics(
      label: S.of(context)!.concubinageHeroPremierEclairage(
        FamilyService.formatChf(_patrimoine!),
      ),
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            MintHeroNumber(
              value: FamilyService.formatChf(_patrimoine!),
              caption: S.of(context)!.concubinageHeroPremierEclairageDesc,
              color: MintColors.white,
            ),
          ],
        ),
      ),
    );
  }

  // Cluster fiscal : matrice + score + détail fiscal partagent les mêmes faits
  // (revenu1, revenu2, canton) → un seul gate en tête. Tant qu'il est incomplet,
  // aucun verdict fiscal (score, « avantage », delta CHF) n'est calculé.
  Widget _buildFiscalCluster() {
    final gate = _fiscalGate(context);
    if (!gate.complete) {
      return SituationGateCard(
        title: S.of(context)!.concubinageGateFiscalTitle,
        gate: gate,
      );
    }
    return Column(
      children: [
        ConcubinageDecisionMatrix(criteria: _matrixCriteria),
        const SizedBox(height: MintSpacing.lg),
        _buildScoreSummary(),
        const SizedBox(height: MintSpacing.lg),
        _buildFiscalDetailCard(),
      ],
    );
  }

  // Impôt de succession — gate patrimoine + canton avant tout chiffre.
  Widget _buildInheritanceSection() {
    final gate = _inheritanceGate(context);
    if (!gate.complete) {
      return SituationGateCard(
        title: S.of(context)!.concubinageGateInheritanceTitle,
        gate: gate,
      );
    }
    return _buildInheritanceCard();
  }

  Widget _buildComparateurInputs() {
    final sortedCodes = FamilyService.sortedCantonCodes;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintAmountField(
            key: _revenu1Key,
            label: S.of(context)!.concubinageRevenu1,
            value: _revenu1 ?? 0,
            formatValue: (v) => _revenu1 == null
                ? S.of(context)!.concubinageNonRenseigne
                : FamilyService.formatChf(v),
            onChanged: (v) => _onFactChanged(() => _revenu1 = v),
            min: 0,
            max: 300000,
          ),
          const SizedBox(height: MintSpacing.md),
          MintAmountField(
            key: _revenu2Key,
            label: S.of(context)!.concubinageRevenu2,
            value: _revenu2 ?? 0,
            formatValue: (v) => _revenu2 == null
                ? S.of(context)!.concubinageNonRenseigne
                : FamilyService.formatChf(v),
            onChanged: (v) => _onFactChanged(() => _revenu2 = v),
            min: 0,
            max: 300000,
          ),
          const SizedBox(height: MintSpacing.md),
          MintAmountField(
            key: _patrimoineKey,
            label: S.of(context)!.concubinagePatrimoineTotal,
            value: _patrimoine ?? 0,
            formatValue: (v) => _patrimoine == null
                ? S.of(context)!.concubinageNonRenseigne
                : FamilyService.formatChf(v),
            onChanged: (v) => _onFactChanged(() => _patrimoine = v),
            min: 0,
            max: 2000000,
          ),
          const SizedBox(height: MintSpacing.lg),

          // Canton dropdown
          Row(
            key: _cantonKey,
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.concubinageCanton,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: MintColors.appleSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _canton,
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
                        _onFactChanged(() {
                          _canton = v;
                          _cantonConfirmed = true;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<ComparisonCriteria> get _matrixCriteria {
    final isPenalite = _comparisonResult != null
        ? (_comparisonResult!['fiscal'] as Map<String, dynamic>)['isPenalite']
            as bool
        : false;
    return [
      ComparisonCriteria(
        label: S.of(context)!.concubinageCriteriaImpots,
        marriageLabel: isPenalite ? S.of(context)!.concubinageCriteriaPenaliteFiscale : S.of(context)!.concubinageCriteriaBonusFiscal,
        concubinageLabel: isPenalite ? S.of(context)!.concubinageCriteriaAvantageux : S.of(context)!.concubinageCriteriaDesavantageux,
        advantage:
            isPenalite ? Advantage.concubinage : Advantage.marriage,
        icon: Icons.account_balance_outlined,
      ),
      ComparisonCriteria(
        label: S.of(context)!.concubinageCriteriaHeritage,
        marriageLabel: S.of(context)!.concubinageCriteriaHeritageMarriage,
        concubinageLabel: S.of(context)!.concubinageCriteriaHeritageConcubinage,
        advantage: Advantage.marriage,
        icon: Icons.family_restroom,
      ),
      ComparisonCriteria(
        label: S.of(context)!.concubinageCriteriaProtection,
        marriageLabel: S.of(context)!.concubinageCriteriaProtectionMarriage,
        concubinageLabel: S.of(context)!.concubinageCriteriaProtectionConcubinage,
        advantage: Advantage.marriage,
        icon: Icons.shield_outlined,
      ),
      ComparisonCriteria(
        label: S.of(context)!.concubinageCriteriaFlexibilite,
        marriageLabel: S.of(context)!.concubinageCriteriaFlexibiliteMarriage,
        concubinageLabel: S.of(context)!.concubinageCriteriaFlexibiliteConcubinage,
        advantage: Advantage.concubinage,
        icon: Icons.swap_horiz,
      ),
      ComparisonCriteria(
        label: S.of(context)!.concubinageCriteriaPension,
        marriageLabel: S.of(context)!.concubinageCriteriaPensionMarriage,
        concubinageLabel: S.of(context)!.concubinageCriteriaPensionConcubinage,
        advantage: Advantage.marriage,
        icon: Icons.balance,
      ),
    ];
  }

  Widget _buildScoreSummary() {
    final result = _comparisonResult!;
    final scoreMariage = result['scoreMariage'] as int;
    final scoreConcubinage = result['scoreConcubinage'] as int;

    return Semantics(
      label: '${S.of(context)!.concubinageMariage}: $scoreMariage ${S.of(context)!.concubinageAvantages}, ${S.of(context)!.concubinageConcubinage}: $scoreConcubinage ${S.of(context)!.concubinageAvantages}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$scoreMariage',
                    style: MintTextStyles.displayMedium(color: MintColors.white).copyWith(fontSize: 36, fontWeight: FontWeight.w800), // lint-ignore: prefer_mint_text_style
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    S.of(context)!.concubinageAvantages,
                    style: MintTextStyles.labelSmall(color: MintColors.white60),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    S.of(context)!.concubinageMariage,
                    style: MintTextStyles.bodyMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 60,
              color: MintColors.white24,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$scoreConcubinage',
                    style: MintTextStyles.displayMedium(color: MintColors.white).copyWith(fontSize: 36, fontWeight: FontWeight.w800), // lint-ignore: prefer_mint_text_style
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    S.of(context)!.concubinageAvantages,
                    style: MintTextStyles.labelSmall(color: MintColors.white60),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    S.of(context)!.concubinageConcubinage,
                    style: MintTextStyles.bodyMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiscalDetailCard() {
    final result = _comparisonResult!;
    final fiscal = result['fiscal'] as Map<String, dynamic>;
    final totalCelib = fiscal['totalCelibataires'] as double;
    final totalMarie = fiscal['totalMarie'] as double;
    final difference = fiscal['difference'] as double;
    final isPenalite = fiscal['isPenalite'] as bool;

    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.concubinageDetailFiscal,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            S.of(context)!.concubinageImpots2Celibataires,
            FamilyService.formatChf(totalCelib),
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            S.of(context)!.concubinageImpotsMaries,
            FamilyService.formatChf(totalMarie),
          ),
          const SizedBox(height: 8),
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPenalite ? S.of(context)!.concubinagePenaliteMariage : S.of(context)!.concubinageBonusMariage,
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${isPenalite ? "+" : "-"}${FamilyService.formatChf(difference.abs())}',
                style: MintTextStyles.titleLarge(color: isPenalite ? MintColors.error : MintColors.success).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInheritanceCard() {
    final result = _comparisonResult!;
    final inheritance = result['inheritance'] as Map<String, dynamic>;
    final impot = inheritance['impot'] as double;
    final taux = inheritance['taux'] as double;

    if (impot <= 0) return const SizedBox.shrink();

    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.concubinageImpotSuccession,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Cadre CONDITIONNEL : sans testament, le·la concubin·e n'est pas
          // héritier·ère (il·elle n'hérite de rien) ; le chiffre ci-dessous n'est
          // dû QUE SI on le·la désigne par testament (taux tiers, pas d'exonération
          // contrairement au·à la conjoint·e marié·e). Aucune présomption d'héritage.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.info.withValues(alpha: 0.18)),
            ),
            child: Text(
              S.of(context)!.concubinageInheritanceConditional,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            S.of(context)!.concubinagePatrimoineTransmis,
            FamilyService.formatChf(_patrimoine!),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResultRow(S.of(context)!.concubinageMarieExonereLabel, S.of(context)!.concubinageMarieExonere),
                    const SizedBox(height: 8),
                    _buildResultRow(
                      S.of(context)!.concubinageConcubinTaux((taux * 100).toStringAsFixed(0)),
                      FamilyService.formatChf(impot),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber,
                    size: 18, color: MintColors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.of(context)!.concubinageWarningSuccession(FamilyService.formatChf(impot), FamilyService.formatChf(_patrimoine!)),
                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeutralConclusion() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(MintSpacing.xs + 2),
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.balance, size: 18, color: MintColors.primary),
          ),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.concubinageNeutralTitle,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  S.of(context)!.concubinageNeutralDesc,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: PROTECTION — Survivor benefits gap
  // ════════════════════════════════════════════════════════════

  Widget _buildTab2Protection() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Intro
        MintEntrance(child: Container(
          padding: const EdgeInsets.all(MintSpacing.md),
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined,
                  color: MintColors.info, size: 20),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: Text(
                  S.of(context)!.concubinageProtectionIntro,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
        ),
        const SizedBox(height: MintSpacing.lg),

        // LPP slider \u2014 rente LPP mensuelle du PARTENAIRE (touch-only).
        MintEntrance(
          delay: const Duration(milliseconds: 100),
          child: MintSurface(
          tone: MintSurfaceTone.blanc,
          elevated: true,
          child: MintAmountField(
            key: _renteLppKey,
            label: S.of(context)!.concubinageProtectionLppSlider,
            value: _renteLpp ?? 0,
            formatValue: (v) => _renteLpp == null
                ? S.of(context)!.concubinageNonRenseigne
                : FamilyService.formatChf(v),
            onChanged: (v) => _onFactChanged(() => _renteLpp = v),
            min: 0,
            max: 8000,
          ),
        ),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Rente de survivant (mari\u00e9 vs concubin) \u2014 gat\u00e9e sur la rente LPP.
        MintEntrance(
          delay: const Duration(milliseconds: 150),
          child: _buildSurvivorSection(),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Comparison table: married vs concubin
        MintEntrance(
          delay: const Duration(milliseconds: 200),
          child: _buildProtectionComparison(),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Educational insert — LPP survivor
        MintEntrance(
          delay: const Duration(milliseconds: 250),
          child: _buildEducationalInsert(
            S.of(context)!.concubinageEducationalLpp,
          ),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Clause bénéficiaire 3a — encart ÉDUCATIF conditionnel (aucun montant :
        // le solde 3a n'a pas de provenance fiable et la destination dépend de la
        // clause, inconnue ici). Remplace l'ancien Clause3aWidget (qui affichait
        // un solde potentiellement estimé + « va à tes parents » présumé).
        MintEntrance(
          delay: const Duration(milliseconds: 300),
          child: _buildEducationalInsert(
            S.of(context)!.concubinage3aClauseEducational,
          ),
        ),
        const SizedBox(height: MintSpacing.lg),

        _buildDisclaimer(),
      ],
    );
  }

  // Rente de survivant (conjoint·e marié·e vs concubin·e). Gaté sur la rente LPP
  // du partenaire. La figure MARIÉE est fondée sur la seule donnée CONFIRMÉE — la
  // rente LPP de survivant (60 % de la rente du partenaire, LPP art. 19). La rente
  // AVS de survivant N'EST PAS chiffrée ici : son montant dépend de la carrière de
  // cotisation (non confirmée) ; l'afficher au maximum légal serait fabriqué. Elle
  // est mentionnée qualitativement sous la comparaison (aucun CHF). Le côté
  // concubin est CHF 0 — vérité légale (aucune rente automatique).
  Widget _buildSurvivorSection() {
    final gate = _survivorGate(context);
    if (!gate.complete) {
      return SituationGateCard(
        title: S.of(context)!.concubinageGateSurvivorTitle,
        gate: gate,
      );
    }
    final lppSurvivorMarried = _renteLpp! * FamilyService.lppSurvivorFactor;

    return Column(
      children: [
        Row(
          children: [
            // Conjoint·e survivant·e — rente LPP de survivant (donnée confirmée).
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(MintSpacing.md),
                decoration: BoxDecoration(
                  color: MintColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MintColors.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      FamilyService.formatChf(lppSurvivorMarried),
                      style: MintTextStyles.headlineSmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      S.of(context)!.concubinageProtectionMaried,
                      style: MintTextStyles.labelSmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.of(context)!.concubinageSurvivorLppDetail,
                      style: MintTextStyles.micro(color: MintColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            // Concubin survivor
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(MintSpacing.md),
                decoration: BoxDecoration(
                  color: MintColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      'CHF 0',
                      style: MintTextStyles.headlineSmall(color: MintColors.error).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      S.of(context)!.concubinageProtectionConcubinLabel,
                      style: MintTextStyles.labelSmall(color: MintColors.error).copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm),
        Text(
          S.of(context)!.concubinageProtectionSurvivorZero,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: MintSpacing.xs),
        // Avantage AVS énoncé QUALITATIVEMENT (aucun CHF : la rente AVS de
        // survivant dépend de la carrière de cotisation, non confirmée).
        Text(
          S.of(context)!.concubinageSurvivorAvsNote,
          style: MintTextStyles.micro(color: MintColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProtectionComparison() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                child: Center(
                  child: Text(
                    S.of(context)!.concubinageProtectionMaried,
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, fontSize: 11), // lint-ignore: prefer_mint_text_style
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    S.of(context)!.concubinageProtectionConcubinLabel,
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, fontSize: 11), // lint-ignore: prefer_mint_text_style
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          _buildComparisonRow(S.of(context)!.concubinageProtectionAvsSurvivor, true, false),
          _buildComparisonRow(S.of(context)!.concubinageProtectionLppSurvivor, true, false),
          _buildComparisonRow(S.of(context)!.concubinageProtectionHeritage, true, false),
          _buildComparisonRow(S.of(context)!.concubinageProtectionPension, true, false),
          _buildComparisonRow(S.of(context)!.concubinageProtectionAvsPlafond, false, true),
          const SizedBox(height: MintSpacing.sm),
          // Les ✓ du mariage sont un ACCÈS LÉGAL soumis à conditions (art. 19 LPP,
          // conditions LAVS) — pas une réception garantie. Le concubin n'a aucun
          // accès quelles que soient les conditions. On l'énonce sous le tableau.
          Text(
            S.of(context)!.concubinageProtectionConditionsNote,
            style: MintTextStyles.micro(color: MintColors.textMuted),
            textAlign: TextAlign.center,
          ),
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
                    S.of(context)!.concubinageProtectionWarning,
                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.4),
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

  // ════════════════════════════════════════════════════════════
  //  TAB 3: CHECKLIST — Essential steps for concubins
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Checklist() {
    final items = _checklistItems(context);
    final nbChecked = _checkedItems.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Intro
        MintEntrance(child: Container(
          padding: const EdgeInsets.all(MintSpacing.md),
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.checklist_rtl,
                  color: MintColors.info, size: 20),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: Text(
                  S.of(context)!.concubinageChecklistIntro,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Progress bar
        MintEntrance(
          delay: const Duration(milliseconds: 100),
          child: Container(
          padding: const EdgeInsets.all(MintSpacing.lg),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.of(context)!.concubinageProtectionsCount(nbChecked, items.length),
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(nbChecked / items.length * 100).toStringAsFixed(0)}%',
                    style: MintTextStyles.titleMedium(color: nbChecked == items.length ? MintColors.success : MintColors.primary).copyWith(fontWeight: FontWeight.w700),
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
                    backgroundColor: MintColors.appleSurface,
                    color: nbChecked == items.length
                        ? MintColors.success
                        : MintColors.primary,
                    minHeight: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
        const SizedBox(height: MintSpacing.lg),

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
              ? MintColors.success.withValues(alpha: 0.04)
              : MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isChecked
                ? MintColors.success.withValues(alpha: 0.3)
                : MintColors.lightBorder,
          ),
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
                            HapticFeedback.lightImpact();
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
                              borderRadius: BorderRadius.circular(7),
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

  // ════════════════════════════════════════════════════════════
  //  CHECKLIST DATA
  // ════════════════════════════════════════════════════════════

  List<Map<String, String>> _checklistItems(BuildContext context) => [
    {
      'title': S.of(context)!.concubinageChecklist1Title,
      'description': S.of(context)!.concubinageChecklist1Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist2Title,
      'description': S.of(context)!.concubinageChecklist2Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist3Title,
      'description': S.of(context)!.concubinageChecklist3Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist4Title,
      'description': S.of(context)!.concubinageChecklist4Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist5Title,
      'description': S.of(context)!.concubinageChecklist5Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist6Title,
      'description': S.of(context)!.concubinageChecklist6Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist7Title,
      'description': S.of(context)!.concubinageChecklist7Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist8Title,
      'description': S.of(context)!.concubinageChecklist8Desc,
    },
  ];

  // ════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildEducationalInsert(String text) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(MintSpacing.xs + 2),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.lightbulb_outline, size: 18, color: MintColors.info),
          ),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.lifeEventDidYouKnow,
                  style: MintTextStyles.bodySmall(color: MintColors.info).copyWith(fontWeight: FontWeight.w700),
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
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.concubinageDisclaimer,
              style: MintTextStyles.labelMedium(color: MintColors.deepOrange).copyWith(height: 1.5, fontStyle: FontStyle.normal),
            ),
          ),
        ],
      ),
    );
  }
}
