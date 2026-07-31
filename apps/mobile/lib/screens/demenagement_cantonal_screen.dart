import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/premium/mint_hero_number.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_signal_row.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_confidence_notice.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';

/// Sortie calculée de l'écran : l'économie (ou surcoût) annuelle d'un
/// déménagement inter-cantonal, décomposée en part fiscale et part LAMal.
/// Elle n'est produite que lorsque le [SituationGate] est complet — jamais sur
/// un défaut fabriqué.
class _DemenagementResult {
  const _DemenagementResult({
    required this.econFiscale,
    required this.econLamal,
  });

  final double econFiscale;
  final double econLamal;

  double get total => econFiscale + econLamal;
}

/// Screen for simulating the financial impact of a cantonal move (Cat C — Life Event).
///
/// Layout S55: enjeu d'abord, consequence avant controle, matiere chaude.
/// Hero = delta fiscal annuel. Consequence de demenager, pas un tableau fiscal.
/// Life Event: cantonMove.
///
/// P2 « gate dur » : l'unique sortie personnalisée (l'économie annuelle
/// déménagement = part fiscale + part LAMal, et tout ce qui en dérive : héros,
/// comparaison des deux cantons, détail par poste, insight « mois de loyer »)
/// est gatée derrière les faits qu'ELLE consomme :
///   • revenu brut annuel (clé 'salary', valeur DANS la plage du slider) —
///     amorcé depuis le salaire réel de l'utilisateur ;
///   • canton de départ (clé 'canton') — le canton ACTUEL de l'utilisateur ;
///   • canton d'arrivée — destination HYPOTHÉTIQUE, aucune source profil →
///     TOUCH-ONLY (le défaut 'VS' reste une hypothèse jusqu'au choix) ;
///   • situation familiale (clé 'civilStatus') — pilote le nombre de primes
///     LAMal du ménage.
/// Un fait n'est CONFIRMÉ que s'il vient de données réelles (provenance
/// `userProvidedFields` / champ touché) ; une valeur égale à un défaut fabriqué
/// reste ASSUMED. Les primes LAMal moyennes et les indices fiscaux affichés dans
/// la carte de comparaison sont des repères cantonaux GÉNÉRIQUES (étiquetés
/// comme tels), jamais la prime réelle de l'utilisateur.
/// Réf : .planning/decisions/2026-07-25-p2-simulator-result-gating.md
class DemenagementCantonalScreen extends StatefulWidget {
  const DemenagementCantonalScreen({super.key});

  @override
  State<DemenagementCantonalScreen> createState() =>
      _DemenagementCantonalScreenState();
}

class _DemenagementCantonalScreenState
    extends State<DemenagementCantonalScreen> {
  // ── Input state ──
  String _cantonDepart = 'GE';
  String _cantonArrivee = 'VS';
  double _revenuBrut = 120000;
  String _situationFamiliale = 'marie';

  // Sortie calculée : null tant que le gate n'est pas complet (compute-time
  // gate). Un chiffre n'existe donc jamais sur un défaut fabriqué.
  _DemenagementResult? _result;

  // ── P2 « gate dur » : provenance PAR FAIT, ré-évaluée à chaque notify ──
  // Aucun latch global `_prefilled` : `loadFromWizard` notifie plusieurs fois
  // (cache→frais→fusionné) ; un latch au 1er notify échouerait un champ dont la
  // donnée arrive au notify suivant. Chaque fait garde `_xSeeded`/`_xTouched`.
  CoachProfileProvider? _profileProvider;

  bool _revenuTouched = false;
  bool _revenuSeeded = false; // provenance = userProvidedFields('salary').
  bool _cantonDepartTouched = false;
  bool _cantonDepartSeeded = false; // provenance = userProvidedFields('canton').
  bool _cantonArriveeTouched = false; // aucune source profil → touch seul.
  bool _situationTouched = false;
  bool _situationSeeded = false; // provenance = userProvidedFields('civilStatus').

  // Baseline pour l'annonce VoiceOver incomplet→complet.
  bool _lastGateComplete = false;

  // Ancres pour scroll-to-first-missing quand la situation est incomplète.
  final _revenuKey = GlobalKey();
  final _cantonDepartKey = GlobalKey();
  final _cantonArriveeKey = GlobalKey();
  final _situationKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Gate dur : au 1er frame rien n'est confirmé → aucun résultat fabriqué.
    _computeResult();
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

  @override
  void dispose() {
    _profileProvider?.removeListener(_seedFromProfile);
    super.dispose();
  }

  /// Seed provenance-gaté, rejoué à CHAQUE notify (aucun latch global). Un champ
  /// n'est amorcé — et donc confirmé — que si sa provenance est réelle : une clé
  /// `userProvidedFields`, jamais valeur≠défaut. Le revenu n'est amorcé que DANS
  /// la plage du slider [30000, 500000] (hors plage → NON confirmé, jamais un
  /// clamp qui fabriquerait un revenu ≠ vrai).
  void _seedFromProfile() {
    final profile = _profileProvider?.profile;
    var changed = false;

    if (profile == null) {
      // Profil absent : pas encore hydraté (le listener rejouera) ou effacé
      // (logout / reset) pendant que l'écran est monté. La provenance issue du
      // profil disparaît : les faits seededFromProfile retombent à non
      // confirmés (un fait TOUCHÉ reste une donnée user et survit). Tout
      // résultat qui reposait sur un fait seedé est invalidé.
      if (_revenuSeeded) {
        _revenuSeeded = false;
        changed = true;
      }
      if (_cantonDepartSeeded) {
        _cantonDepartSeeded = false;
        changed = true;
      }
      if (_situationSeeded) {
        _situationSeeded = false;
        changed = true;
      }
      if (changed) _calculate();
      return;
    }

    // Revenu brut annuel — clé 'salary' ET annuel (salaire mensuel × 12) DANS
    // la plage [30000, 500000] du slider. Hors plage → NON confirmé.
    if (!_revenuTouched) {
      final annual = profile.salaireBrutMensuel * 12;
      final valid = profile.userProvidedFields.contains('salary') &&
          annual >= 30000.0 &&
          annual <= 500000.0;
      if (_revenuSeeded != valid) {
        _revenuSeeded = valid;
        changed = true;
      }
      if (valid && annual != _revenuBrut) {
        _revenuBrut = annual;
        changed = true;
      }
    }

    // Canton de départ — le canton ACTUEL de l'utilisateur (clé 'canton').
    if (!_cantonDepartTouched) {
      final c = profile.canton;
      final valid = profile.userProvidedFields.contains('canton') &&
          cantonFullNames.containsKey(c);
      if (_cantonDepartSeeded != valid) {
        _cantonDepartSeeded = valid;
        changed = true;
      }
      if (valid && c != _cantonDepart) {
        _cantonDepart = c;
        changed = true;
      }
    }

    // Situation familiale — clé 'civilStatus' (etatCivil est non-nullable avec un
    // défaut celibataire → seule la clé prouve que l'utilisateur l'a fournie ;
    // jamais une comparaison de valeur). marié → 'marie', sinon 'celibataire'.
    if (!_situationTouched) {
      final valid = profile.userProvidedFields.contains('civilStatus');
      if (_situationSeeded != valid) {
        _situationSeeded = valid;
        changed = true;
      }
      if (valid) {
        final v = profile.etatCivil == CoachCivilStatus.marie
            ? 'marie'
            : 'celibataire';
        if (v != _situationFamiliale) {
          _situationFamiliale = v;
          changed = true;
        }
      }
    }

    // Canton d'arrivée : destination hypothétique, aucune source profil →
    // jamais amorcé (le défaut 'VS' reste ASSUMED jusqu'au choix utilisateur).

    if (changed) _calculate();
  }

  // ── P2 provenance getters (live, non-latching) ──
  FactProvenance get _revenuProvenance => _revenuTouched
      ? FactProvenance.touched
      : (_revenuSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  FactProvenance get _cantonDepartProvenance => _cantonDepartTouched
      ? FactProvenance.touched
      : (_cantonDepartSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  // Aucune source profil : seul le touch confirme la destination.
  FactProvenance get _cantonArriveeProvenance =>
      _cantonArriveeTouched ? FactProvenance.touched : FactProvenance.assumed;

  FactProvenance get _situationProvenance => _situationTouched
      ? FactProvenance.touched
      : (_situationSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  // ── Gate (sortie unique = l'économie déménagement) ──
  // Faits déterminants : revenu (part fiscale), canton départ + canton arrivée
  // (les deux barèmes + primes comparés), situation familiale (nombre de primes
  // LAMal du ménage). Le héros affiche le total → il consomme les quatre.
  SituationGate _situationGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'revenu',
          label: (c) => S.of(c)!.demenagementGateFactRevenu,
          why: (c) => S.of(c)!.demenagementGateWhyRevenu,
          provenance: _revenuProvenance,
          onComplete: () => _scrollToKey(_revenuKey),
        ),
        SituationFact(
          key: 'cantonDepart',
          label: (c) => S.of(c)!.demenagementGateFactCantonDepart,
          why: (c) => S.of(c)!.demenagementGateWhyCantonDepart,
          provenance: _cantonDepartProvenance,
          onComplete: () => _scrollToKey(_cantonDepartKey),
        ),
        SituationFact(
          key: 'cantonArrivee',
          label: (c) => S.of(c)!.demenagementGateFactCantonArrivee,
          why: (c) => S.of(c)!.demenagementGateWhyCantonArrivee,
          provenance: _cantonArriveeProvenance,
          onComplete: () => _scrollToKey(_cantonArriveeKey),
        ),
        SituationFact(
          key: 'situationFamiliale',
          label: (c) => S.of(c)!.demenagementGateFactSituation,
          why: (c) => S.of(c)!.demenagementGateWhySituation,
          provenance: _situationProvenance,
          onComplete: () => _scrollToKey(_situationKey),
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

  /// Gate dur au compute : l'économie n'est calculée que si revenu, canton
  /// départ, canton arrivée et situation familiale sont confirmés. Sinon `null`
  /// → le slot résultat affiche la carte de situation (jamais un chiffre
  /// fabriqué).
  void _computeResult() {
    _result = _situationGate(context).complete
        ? _DemenagementResult(
            econFiscale: _computeEconFiscale(),
            econLamal: _computeEconLamal(),
          )
        : null;
  }

  /// Recalcule + rebuild, SANS annonce (seed profil). Toute entrée qui bouge
  /// invalide d'abord le résultat : aucun chiffre périmé ne survit à une entrée
  /// modifiée.
  void _calculate() {
    _computeResult();
    _lastGateComplete = _situationGate(context).complete;
    if (mounted) setState(() {});
  }

  /// L'utilisateur a édité un fait déterminant : recalcule (stale-result
  /// invalidation) et annonce le passage incomplet→complet pour VoiceOver (le
  /// scroll ≠ déplacement de focus).
  void _afterFactChanged() {
    final wasComplete = _lastGateComplete;
    _computeResult();
    final nowComplete = _situationGate(context).complete;
    if (nowComplete && !wasComplete) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        S.of(context)!.situationGateAnnounceComplete,
        Directionality.of(context),
      );
    }
    _lastGateComplete = nowComplete;
    if (mounted) setState(() {});
  }

  // Modèle proportionnel simplifié via ratios d'indices fiscaux (voir DECISION
  // ci-dessous). Appelé uniquement par `_computeResult` (donc jamais sur un
  // défaut non confirmé).
  // DECISION: Simplified proportional model using fiscal index ratios.
  // Full per-canton accuracy via TaxCalculator.estimateMonthlyIncomeTax()
  // deferred to Phase 2 (MINT-201). Current model gives directionally
  // correct comparisons for educational purposes.
  // Ref: financial_core/tax_calculator.dart — progressiveTax(), capitalWithdrawalTax()
  double _computeEconFiscale() {
    final idxDepart = _indiceFiscal[_cantonDepart] ?? 75;
    final idxArrivee = _indiceFiscal[_cantonArrivee] ?? 75;
    // 22% ≈ taux moyen effectif d'imposition du revenu à GE au revenu médian
    // (LIFD art. 36 + cantonal).
    final tauxMoyenDepart = idxDepart / 100 * 0.22;
    final tauxMoyenArrivee = idxArrivee / 100 * 0.22;
    return _revenuBrut * (tauxMoyenDepart - tauxMoyenArrivee);
  }

  double _computeEconLamal() {
    final lamalDepart = _lamalMensuelle[_cantonDepart] ?? 370;
    final lamalArrivee = _lamalMensuelle[_cantonArrivee] ?? 370;
    final nbPersonnes = 1 + (_situationFamiliale == 'marie' ? 1 : 0);
    return (lamalDepart - lamalArrivee) * 12 * nbPersonnes.toDouble();
  }

  /// @visibleForTesting : entrées + sortie consommées par le rendu (preuve P2).
  @visibleForTesting
  double get debugRevenu => _revenuBrut;
  @visibleForTesting
  String get debugCantonDepart => _cantonDepart;
  @visibleForTesting
  String get debugCantonArrivee => _cantonArrivee;
  @visibleForTesting
  String get debugSituation => _situationFamiliale;
  @visibleForTesting
  double? get debugEconFiscale => _result?.econFiscale;
  @visibleForTesting
  double? get debugEconLamal => _result?.econLamal;
  @visibleForTesting
  double? get debugTotal => _result?.total;

  // Simplified cantonal tax burden index (relative, GE=100)
  static const _indiceFiscal = {
    'AG': 72, 'AI': 58, 'AR': 65, 'BE': 82, 'BL': 78, 'BS': 85,
    'FR': 70, 'GE': 100, 'GL': 62, 'GR': 68, 'JU': 88, 'LU': 60,
    'NE': 92, 'NW': 48, 'OW': 50, 'SG': 72, 'SH': 70, 'SO': 78,
    'SZ': 45, 'TG': 68, 'TI': 80, 'UR': 55, 'VD': 95, 'VS': 75,
    'ZG': 40, 'ZH': 72,
  };

  // Simplified LAMal monthly premium by canton (adult, franchise 300)
  static const _lamalMensuelle = {
    'AG': 370, 'AI': 290, 'AR': 320, 'BE': 400, 'BL': 410, 'BS': 440,
    'FR': 360, 'GE': 480, 'GL': 310, 'GR': 320, 'JU': 380, 'LU': 350,
    'NE': 420, 'NW': 300, 'OW': 290, 'SG': 340, 'SH': 350, 'SO': 370,
    'SZ': 310, 'TG': 330, 'TI': 400, 'UR': 290, 'VD': 450, 'VS': 370,
    'ZG': 310, 'ZH': 390,
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final gate = _situationGate(context);
    final resultReady = _result != null && gate.complete;

    return Semantics(
      identifier: 'demenagement_cantonal_screen',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
      backgroundColor: MintColors.porcelaine,
      // ── White standard AppBar (Design System §4.5) ──
      appBar: AppBar(
        // Ancre C4 « pas de cul-de-sac » : bouton retour identifié (safePop →
        // pop, sinon go('/home')) remplaçant le back par défaut, non-poppable
        // sur entrée deeplink. `label` = tooltip « retour » localisé (leçon
        // Codex B3 #1141). Smoke Tier B (lot B4).
        leading: Semantics(
          identifier: 'demenagement-back',
          button: true,
          label: MaterialLocalizations.of(context).backButtonTooltip,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => safePop(context),
          ),
        ),
        // Ancre régionale Tier B smoke (C1 « atteignable ») posée sur le titre
        // AppBar — motif profond, jamais le wrapper racine (leçon ADR AX iOS 26.2).
        title: Semantics(
          identifier: 'demenagement-anchor',
          child: Text(
            s.demenagementTitreV2,
            style: MintTextStyles.headlineMedium(),
          ),
        ),
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              // RÉSULTAT (gaté) : héros + comparaison + détail + insight, OU
              // carte de situation tant que les quatre faits ne viennent pas des
              // données réelles de l'utilisateur.
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              if (resultReady) ...[
                // SECTION 1 — L'ENJEU : delta fiscal hero
                // Ancre régionale Tier B smoke (C2 « chiffré ») posée sur le
                // héros delta fiscal — présente UNIQUEMENT dans la branche
                // `resultReady` (les quatre faits confirmés), jamais sur la
                // carte-gate. Motif profond, jamais le wrapper racine (ADR AX).
                MintEntrance(child: Semantics(
                  identifier: 'demenagement-result',
                  child: MintHeroNumber(
                  value: '${_result!.total >= 0 ? '+ ' : ''}'
                      '${formatChfWithPrefix(_result!.total)}',
                  caption: s.demenagementPremierEclairageSousTitre,
                  color: _result!.total >= 0
                      ? MintColors.success
                      : MintColors.error,
                  semanticsLabel: s.demenagementBilanTotal,
                  ),
                )),
                const SizedBox(height: MintSpacing.sm),
                MintEntrance(delay: const Duration(milliseconds: 100), child: Text(
                  s.demenagementPremierEclairageDetail(
                      _cantonDepart, _cantonArrivee),
                  style: MintTextStyles.bodySmall(color: MintColors.textMuted),
                )),
                const SizedBox(height: MintSpacing.xxl),

                // SECTION 2 — COMPARAISON : deux cantons cote a cote
                MintEntrance(delay: const Duration(milliseconds: 200), child: _buildCantonComparison(s)),
                const SizedBox(height: MintSpacing.xl),

                // SECTION 3 — DETAIL par poste (MintSignalRow)
                MintEntrance(delay: const Duration(milliseconds: 300), child: _buildDetailParPoste(s)),
                const SizedBox(height: MintSpacing.lg),

                // SECTION 4 — INSIGHT emotionnel
                MintEntrance(delay: const Duration(milliseconds: 400), child: _buildInsight(s)),
                const SizedBox(height: MintSpacing.lg),

                // SECTION 5 — CONFIDENCE NOTICE
                MintConfidenceNotice(
                  percent: 40,
                  message: s.demenagementDisclaimer,
                ),
                const SizedBox(height: MintSpacing.xl),
              ] else ...[
                MintEntrance(
                  child: SituationGateCard(
                    title: s.donationGateTitle,
                    gate: gate,
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),
              ],

              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              // SECTION 6 — CONTROLES : sous le resultat (toujours visibles)
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              _buildInputs(s),
              const SizedBox(height: MintSpacing.xl),

              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              // SECTION 7 — CHECKLIST demenagement
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              _buildChecklist(s),
              const SizedBox(height: MintSpacing.lg),

              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              // SECTION 8 — DISCLAIMER (micro)
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              Text(
                s.demenagementDisclaimer,
                style: MintTextStyles.micro(),
              ),
            ],
          ),
        ),
      ))),
    ));
  }

  /// Two MintSurface cards side by side: sauge for the winning canton, peche for the losing one.
  /// Rendue uniquement dans la branche résultat (les deux cantons sont alors
  /// confirmés). Les indices fiscaux et primes LAMal affichés sont des repères
  /// cantonaux GÉNÉRIQUES (moyennes) — étiquetés par la légende, pas la prime
  /// réelle de l'utilisateur.
  Widget _buildCantonComparison(S s) {
    final economieTotal = _result!.total;

    // Determine which canton "wins"
    final departGagne = economieTotal < 0;
    final idxDepart = _indiceFiscal[_cantonDepart] ?? 75;
    final idxArrivee = _indiceFiscal[_cantonArrivee] ?? 75;
    final lamalDepart = _lamalMensuelle[_cantonDepart] ?? 370;
    final lamalArrivee = _lamalMensuelle[_cantonArrivee] ?? 370;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Canton depart
            Expanded(
              child: MintSurface(
                tone: departGagne
                    ? MintSurfaceTone.sauge
                    : MintSurfaceTone.peche,
                padding: const EdgeInsets.all(MintSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cantonDepart,
                      style: MintTextStyles.headlineMedium(
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      s.demenagementCantonDepart,
                      style: MintTextStyles.labelSmall(
                        color: MintColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.md),
                    Text(
                      s.demenagementFiscalTitre,
                      style: MintTextStyles.labelSmall(
                        color: MintColors.textMuted,
                      ),
                    ),
                    Text(
                      '$idxDepart',
                      style: MintTextStyles.titleMedium(
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.sm),
                    Text(
                      s.demenagementLamalTitre,
                      style: MintTextStyles.labelSmall(
                        color: MintColors.textMuted,
                      ),
                    ),
                    Text(
                      'CHF $lamalDepart/mois',
                      style: MintTextStyles.titleMedium(
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: MintSpacing.sm),
            // Canton arrivee
            Expanded(
              child: MintSurface(
                tone: departGagne
                    ? MintSurfaceTone.peche
                    : MintSurfaceTone.sauge,
                padding: const EdgeInsets.all(MintSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cantonArrivee,
                      style: MintTextStyles.headlineMedium(
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      s.demenagementCantonArrivee,
                      style: MintTextStyles.labelSmall(
                        color: MintColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.md),
                    Text(
                      s.demenagementFiscalTitre,
                      style: MintTextStyles.labelSmall(
                        color: MintColors.textMuted,
                      ),
                    ),
                    Text(
                      '$idxArrivee',
                      style: MintTextStyles.titleMedium(
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.sm),
                    Text(
                      s.demenagementLamalTitre,
                      style: MintTextStyles.labelSmall(
                        color: MintColors.textMuted,
                      ),
                    ),
                    Text(
                      'CHF $lamalArrivee/mois',
                      style: MintTextStyles.titleMedium(
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm),
        // Légende : les indices + primes ci-dessus sont des repères cantonaux
        // GÉNÉRIQUES (moyennes), pas la prime réelle de l'utilisateur.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline,
                size: 14, color: MintColors.textMuted),
            const SizedBox(width: MintSpacing.xs),
            Expanded(
              child: Text(
                s.demenagementReferenceCaption,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Detail breakdown with MintSignalRow for each financial post.
  Widget _buildDetailParPoste(S s) {
    final econFiscale = _result!.econFiscale;
    final econLamal = _result!.econLamal;
    final economieTotal = _result!.total;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.demenagementSituation,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          MintSignalRow(
            label: s.demenagementEconomieFiscale,
            value: '${econFiscale >= 0 ? '+' : ''}${formatChfWithPrefix(econFiscale)}/an',
            valueColor:
                econFiscale >= 0 ? MintColors.success : MintColors.error,
          ),
          MintSignalRow(
            label: s.demenagementLamalTitre,
            value: '${econLamal >= 0 ? '+' : ''}${formatChfWithPrefix(econLamal)}/an',
            valueColor:
                econLamal >= 0 ? MintColors.success : MintColors.error,
          ),
          Divider(
            color: MintColors.border.withValues(alpha: 0.3),
            height: 1,
          ),
          MintSignalRow(
            label: s.demenagementBilanTotal,
            value: '${economieTotal >= 0 ? '+' : ''}${formatChfWithPrefix(economieTotal)}/an',
            valueColor:
                economieTotal >= 0 ? MintColors.success : MintColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildInsight(S s) {
    final economieTotal = _result!.total;
    final estPositif = economieTotal >= 0;
    const loyerMoyen = 1500.0;
    final moisCouverts = economieTotal.abs() / loyerMoyen;

    return MintSurface(
      tone: estPositif ? MintSurfaceTone.sauge : MintSurfaceTone.peche,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            estPositif ? Icons.check_circle_outline : Icons.info_outline,
            color: estPositif ? MintColors.success : MintColors.corailDiscret,
            size: 20,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              estPositif
                  ? s.demenagementInsightPositif(
                      moisCouverts.toStringAsFixed(0))
                  : s.demenagementInsightNegatif,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputs(S s) {
    return MintSurface(
      tone: MintSurfaceTone.craie,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.demenagementSituation,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),

          // Canton depart / arrivee
          Row(
            children: [
              Expanded(
                child: Column(
                  key: _cantonDepartKey,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.demenagementCantonDepart,
                        style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary)),
                    const SizedBox(height: MintSpacing.xs),
                    Semantics(
                      label: s.demenagementCantonDepart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MintSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: MintColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: const Key('demenagement_canton_depart'),
                            isExpanded: true,
                            value: _cantonDepart,
                            items: sortedCantonCodes
                                .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c,
                                        style: MintTextStyles.bodySmall(
                                            color: MintColors.textPrimary))))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              // Touch = donnée user ; touched supersede le seed
                              // (immunisé au clear).
                              _cantonDepartTouched = true;
                              _cantonDepartSeeded = false;
                              _cantonDepart = v;
                              _afterFactChanged();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: MintSpacing.sm),
                child:
                    Icon(Icons.arrow_forward, color: MintColors.textMuted),
              ),
              Expanded(
                child: Column(
                  key: _cantonArriveeKey,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.demenagementCantonArrivee,
                        style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary)),
                    const SizedBox(height: MintSpacing.xs),
                    Semantics(
                      label: s.demenagementCantonArrivee,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MintSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: MintColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: const Key('demenagement_canton_arrivee'),
                            isExpanded: true,
                            value: _cantonArrivee,
                            items: sortedCantonCodes
                                .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c,
                                        style: MintTextStyles.bodySmall(
                                            color: MintColors.textPrimary))))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              // Choisir la destination = fournir la donnée (touch
                              // seul ; aucune source profil pour l'arrivée).
                              _cantonArriveeTouched = true;
                              _cantonArrivee = v;
                              _afterFactChanged();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),

          // Revenu brut
          KeyedSubtree(
            key: _revenuKey,
            child: MintPremiumSlider(
              key: const Key('demenagement_revenu_field'),
              label: s.demenagementRevenu,
              value: _revenuBrut,
              min: 30000,
              max: 500000,
              divisions: 94,
              formatValue: (_) => formatChfWithPrefix(_revenuBrut),
              onChanged: (v) {
                // Touch = donnée user ; touched supersede le seed.
                _revenuTouched = true;
                _revenuSeeded = false;
                _revenuBrut = v;
                _afterFactChanged();
              },
            ),
          ),
          const SizedBox(height: MintSpacing.lg),

          // Situation familiale
          Semantics(
            label: s.demenagementCelibataire,
            child: SegmentedButton<String>(
              key: const Key('demenagement_situation'),
              segments: [
                ButtonSegment(
                    value: 'celibataire',
                    label: Text(s.demenagementCelibataire)),
                ButtonSegment(
                    value: 'marie', label: Text(s.demenagementMarie)),
              ],
              selected: {_situationFamiliale},
              onSelectionChanged: (v) {
                // Sélectionner (même le défaut) = fournir la donnée (touch seul,
                // même si la clé 'civilStatus' peut aussi l'amorcer).
                _situationTouched = true;
                _situationSeeded = false;
                _situationFamiliale = v.first;
                _afterFactChanged();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklist(S s) {
    final items = [
      s.demenagementChecklist1,
      s.demenagementChecklist2,
      s.demenagementChecklist3,
      s.demenagementChecklist4,
      s.demenagementChecklist5,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.demenagementChecklistTitre,
          style: MintTextStyles.headlineMedium(),
        ),
        const SizedBox(height: MintSpacing.sm),
        ...items.map(
          (item) => Semantics(
            label: item,
            child: MintSurface(
              tone: MintSurfaceTone.blanc,
              padding: const EdgeInsets.all(MintSpacing.md),
              radius: 12,
              child: Row(
                children: [
                  const Icon(Icons.check_box_outline_blank,
                      color: MintColors.textMuted, size: 20),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Text(item,
                        style: MintTextStyles.bodyMedium(
                            color: MintColors.textPrimary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
