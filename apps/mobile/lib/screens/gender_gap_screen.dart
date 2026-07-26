import 'package:flutter/material.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/segments_service.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';

// ────────────────────────────────────────────────────────────
//  GENDER GAP PREVOYANCE SCREEN — Sprint S12 / Chantier 6
// ────────────────────────────────────────────────────────────

/// Les 26 codes cantonaux suisses — la « plage valide » du fait `canton`.
/// Une chaîne vide, 'unknown', un blanc ou une valeur parasite ne confirment
/// jamais (ferme le défaut legacy `CoachProfile.fromJson canton ?? 'ZH'`).
const Set<String> _kSwissCantons = {
  'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR', 'JU', 'LU', 'NE',
  'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG', 'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
};

bool _isValidCanton(String c) => _kSwissCantons.contains(c.trim().toUpperCase());

/// Explorateur de la lacune de prévoyance (temps partiel).
///
/// P2 « gate dur » (.planning/decisions/2026-07-25-p2-simulator-result-gating.md):
/// aucun chiffre « ta situation » n'est calculé sur un défaut fabriqué. Le calcul
/// n'a lieu qu'APRÈS le seed profil, et chaque carte-résultat est gatée derrière
/// les faits qu'ELLE consomme :
///   • comparaison de rente (rente projetée + lacune) → revenu + avoir LPP + âge ;
///   • détail de coordination (salaire coordonné) → revenu.
///
/// Un fait n'est CONFIRMÉ que s'il vient de données réelles — amorcé depuis le
/// profil (clé `userProvidedFields` + valeur dans la plage) OU saisi. Les faits
/// non consommés par un calcul (canton, années de cotisation) ne gatent PAS le
/// chiffre — le service `GenderGapService` ne les lit pas (la LPP est fédérale ;
/// `anneesCotisation` est inutilisé) — mais ils ne sont jamais AFFICHÉS fabriqués :
/// une valeur non confirmée est rendue « Non renseigné » (jamais 'ZH' / 15).
/// Motif : ADR §2 « age drives neither output → not gated (pure friction) ».
///
/// Le `_tauxActivite` est le bouton EXPLORATOIRE (« ma lacune à X % ») : sa
/// position est explicite à l'écran, ce n'est donc pas une fabrication cachée. Il
/// reste interactif ; le RÉSULTAT reste gaté tant que les faits de situation
/// consommés ne sont pas confirmés.
class GenderGapScreen extends StatefulWidget {
  const GenderGapScreen({super.key});

  @override
  State<GenderGapScreen> createState() => _GenderGapScreenState();
}

class _GenderGapScreenState extends State<GenderGapScreen> {
  // ── State ──────────────────────────────────────────────────
  // Bouton exploratoire : position explicite à l'écran → jamais gaté.
  double _tauxActivite = 60;

  // Faits de situation : NULLABLE, défaut null. La valeur non nulle EST le
  // signal « donnée réelle » (seed profil dans la plage) ; un défaut = null
  // « Non renseigné », jamais un nombre inventé (85000 / 120000 / 40 / 15).
  double? _revenuAnnuel; // consommé (comparaison + coordination)
  double? _avoirLpp; // consommé (comparaison)
  int? _age; // consommé (comparaison)
  int? _anneesCotisation; // affichage seul (service ne le lit pas)
  // Le canton n'a pas de contrôle à l'écran : `_canton` porte la valeur réelle
  // seedée, `_cantonConfirmed` dit si elle vient d'une donnée utilisateur. Non
  // confirmé → affiché « Non renseigné » (affichage seul ; LPP fédérale).
  String _canton = '';
  bool _cantonConfirmed = false;

  GenderGapResult? _result;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    // Pas de calcul ici : `_recompute()` n'a lieu qu'après le seed (données
    // réelles) — aucun chiffre fabriqué n'est produit à l'ouverture.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final profile = context.coachProfileOrNull;
    if (profile != null) {
      final provided = profile.userProvidedFields;
      // ── revenu = l'UTILISATEUR ──
      // Confirmé seulement depuis une donnée RÉELLE : clé `salary` ET valeur
      // dans la plage annuelle plausible. Hors plage → NON amorcé (jamais un
      // clamp qui fabriquerait une valeur ≠ la vraie).
      final revenu = profile.revenuBrutAnnuel;
      if (provided.contains('salary') && revenu >= 20000 && revenu <= 2000000) {
        _revenuAnnuel = revenu;
      }
      // ── avoir LPP ──
      // Uniquement une valeur RÉELLE (certificat scanné : `isLppFromCertificate`),
      // jamais l'estimation âge×salaire, et dans la plage [>0, 5000000].
      final lpp = profile.prevoyance.avoirLppTotal;
      if (lpp != null &&
          lpp > 0 &&
          lpp <= 5000000 &&
          profile.prevoyance.isLppFromCertificate) {
        _avoirLpp = lpp;
      }
      // ── âge ──
      // Clé `age` RÉELLEMENT fournie ET âge plausible via `ageOrNull` (le getter
      // `age` renvoie le sentinel 0 quand la naissance manque → jamais amorcé).
      final ageVal = profile.ageOrNull;
      if (provided.contains('age') &&
          ageVal != null &&
          ageVal >= 16 &&
          ageVal <= 99) {
        _age = ageVal;
      }
      // ── années de cotisation ── (affichage seul) donnée réelle du certificat.
      final annees = profile.prevoyance.anneesContribuees;
      if (annees != null && annees > 0 && annees <= 50) {
        _anneesCotisation = annees;
      }
      // ── canton ── (affichage seul) provenance canonique = clé 'canton'
      // RÉELLEMENT fournie ET code valide. La clé seule ne suffit pas ('' / 'XX'
      // keyed passeraient) ; la validité seule non plus (`fromJson` met
      // `canton ?? 'ZH'` → 'ZH' legacy sans saisie). Les deux ensemble ferment
      // le trou.
      if (provided.contains('canton') && _isValidCanton(profile.canton)) {
        _canton = profile.canton.trim().toUpperCase();
        _cantonConfirmed = true;
      }
      // NB : aucun champ de taux d'activité réel n'existe sur le profil → le
      // slider garde sa position par défaut (explicite, exploratoire).
    }
    _recompute();
  }

  // Recalcule avec des sentinelles (0 / '') pour tout fait non confirmé : le
  // service peut calculer, mais le GATE au rendu garantit qu'aucun chiffre dérivé
  // d'un 0/''-fabriqué n'est affiché (défense en profondeur, motif divorce). Le
  // canton est passé mais inutilisé par `GenderGapService` (LPP fédérale).
  void _recompute() {
    final input = GenderGapInput(
      tauxActivite: _tauxActivite,
      age: _age ?? 0,
      revenuAnnuel: (_revenuAnnuel ?? 0) * (_tauxActivite / 100),
      avoirLpp: _avoirLpp ?? 0,
      anneesCotisation: _anneesCotisation ?? 0,
      canton: _cantonConfirmed ? _canton : '',
    );
    _result = GenderGapService.analyse(input: input);
  }

  // ── Debug getters (@visibleForTesting) : provenance confirmée (null == non
  //    renseigné). Les tests anti-façade assertent aussi sur le CHF rendu. ──
  @visibleForTesting
  double? get debugRevenuAnnuel => _revenuAnnuel;
  @visibleForTesting
  double? get debugAvoirLpp => _avoirLpp;
  @visibleForTesting
  int? get debugAge => _age;
  @visibleForTesting
  int? get debugAnneesCotisation => _anneesCotisation;
  @visibleForTesting
  bool get debugCantonConfirmed => _cantonConfirmed;
  @visibleForTesting
  String get debugCanton => _canton;
  @visibleForTesting
  double get debugTauxActivite => _tauxActivite;

  // ── Provenance : confirmé (saisi OU seedé depuis une donnée réelle) vs
  //    assumed (défaut null → gate fermé). ──
  FactProvenance _prov(bool confirmed) =>
      confirmed ? FactProvenance.touched : FactProvenance.assumed;

  // Comparaison de rente (rente projetée à 100 % vs au taux + lacune) : le
  // service consomme revenu + avoir LPP + âge (pas le canton, pas les années).
  // `onComplete: null` — aucun contrôle à l'écran ne saisit ces faits ; la carte
  // renvoie vers le profil (via `why`).
  SituationGate _pensionGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'revenu',
          label: (c) => S.of(c)!.genderGapRevenuAnnuel,
          why: (c) => S.of(c)!.genderGapGateWhyRevenu,
          provenance: _prov(_revenuAnnuel != null),
        ),
        SituationFact(
          key: 'avoirLpp',
          label: (c) => S.of(c)!.genderGapAvoirLpp,
          why: (c) => S.of(c)!.genderGapGateWhyAvoirLpp,
          provenance: _prov(_avoirLpp != null),
        ),
        SituationFact(
          key: 'age',
          label: (c) => S.of(c)!.genderGapAge,
          why: (c) => S.of(c)!.genderGapGateWhyAge,
          provenance: _prov(_age != null),
        ),
      ]);

  // Détail de coordination (salaire coordonné à 100 % / au taux, déduction fixe) :
  // le service dérive tout du revenu (la déduction est une constante ; le taux est
  // explicite).
  SituationGate _coordinationGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'revenu',
          label: (c) => S.of(c)!.genderGapRevenuAnnuel,
          why: (c) => S.of(c)!.genderGapGateWhyRevenu,
          provenance: _prov(_revenuAnnuel != null),
        ),
      ]);

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    // ILLOG-02 : conteneur Semantics racine (motif rente_vs_capital) sinon le
    // pont AX iOS effondre toute la route en un seul nœud.
    return Semantics(
      identifier: 'gender_gap_screen',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: MintColors.background,
        appBar: AppBar(
          backgroundColor: MintColors.white,
          foregroundColor: MintColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
            onPressed: () => safePop(context),
          ),
          title: Text(
            s.genderGapAppBarTitle,
            style: MintTextStyles.headlineMedium(),
          ),
        ),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.sm, MintSpacing.lg, MintSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MintEntrance(child: _buildHeader(s)),
              const SizedBox(height: MintSpacing.lg),
              MintEntrance(delay: const Duration(milliseconds: 100), child: _buildIntro(s)),
              const SizedBox(height: MintSpacing.lg),

              // Taux activite slider
              MintEntrance(delay: const Duration(milliseconds: 200), child: _buildTauxSlider(s)),
              const SizedBox(height: MintSpacing.lg),

              // Input section
              MintEntrance(delay: const Duration(milliseconds: 300), child: _buildInputSection(s)),
              const SizedBox(height: MintSpacing.lg),

              // Results (chaque carte calculée se gate elle-même ; OFS +
              // recommandations + disclaimer + sources restent ÉDUCATIFS).
              if (_result != null) ...[
                _buildPensionComparison(s),
                const SizedBox(height: MintSpacing.lg),
                _buildCoordinationExplanation(s),
                const SizedBox(height: MintSpacing.lg),
                _buildOfsStatistic(s),
                const SizedBox(height: MintSpacing.lg),
                _buildRecommendations(s),
                const SizedBox(height: MintSpacing.lg),
              ],

              // Disclaimer
              MintEntrance(delay: const Duration(milliseconds: 400), child: _buildDisclaimer(s)),
              const SizedBox(height: MintSpacing.md),

              // Sources
              _buildSourcesFooter(s),
              const SizedBox(height: MintSpacing.xxl),
            ],
          ),
        ))),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader(S s) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MintColors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.balance,
              color: MintColors.purple,
              size: 28,
            ),
          ),
          const SizedBox(width: MintSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.genderGapHeaderTitle,
                  style: MintTextStyles.headlineLarge().copyWith(fontSize: 24), // lint-ignore: prefer_mint_text_style
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  s.genderGapHeaderSubtitle,
                  style: MintTextStyles.bodyMedium(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Intro ──────────────────────────────────────────────────

  Widget _buildIntro(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              s.genderGapIntro,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Taux slider ────────────────────────────────────────────

  Widget _buildTauxSlider(S s) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintPremiumSlider(
            label: s.genderGapTauxActivite,
            value: _tauxActivite,
            min: 10,
            max: 100,
            divisions: 18,
            formatValue: (v) => '${v.round()}%',
            activeColor: _tauxActivite < 60
                ? MintColors.error
                : _tauxActivite < 80
                    ? MintColors.warning
                    : MintColors.success,
            onChanged: (value) {
              // Le taux est exploratoire : on recalcule (un chiffre affiché ne
              // survit jamais à un changement d'entrée — stale-invalidation).
              setState(() {
                _tauxActivite = value;
                _recompute();
              });
            },
          ),
        ],
      ),
    );
  }

  // ── Input section ──────────────────────────────────────────

  Widget _buildInputSection(S s) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.genderGapParametres,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.md),
          // Un fait non confirmé est rendu « Non renseigné », jamais le nombre
          // fabriqué (85000 / 40 / 120000 / 15 / 'ZH').
          _buildInputRow(
            s.genderGapRevenuAnnuel,
            _revenuAnnuel != null
                ? GenderGapService.formatChf(_revenuAnnuel!)
                : s.genderGapNonRenseigne,
          ),
          const SizedBox(height: MintSpacing.sm),
          _buildInputRow(
            s.genderGapAge,
            _age != null ? s.genderGapAgeValue('$_age') : s.genderGapNonRenseigne,
          ),
          const SizedBox(height: MintSpacing.sm),
          _buildInputRow(
            s.genderGapAvoirLpp,
            _avoirLpp != null
                ? GenderGapService.formatChf(_avoirLpp!)
                : s.genderGapNonRenseigne,
          ),
          const SizedBox(height: MintSpacing.sm),
          _buildInputRow(
            s.genderGapAnneesCotisation,
            _anneesCotisation != null
                ? '$_anneesCotisation'
                : s.genderGapNonRenseigne,
          ),
          const SizedBox(height: MintSpacing.sm),
          _buildInputRow(
            s.genderGapCanton,
            _cantonConfirmed ? _canton : s.genderGapNonRenseigne,
          ),
          const SizedBox(height: MintSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: MintSpacing.sm),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_outlined, color: MintColors.info, size: 16),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    s.genderGapDemoMode,
                    style: MintTextStyles.labelSmall(color: MintColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
        ),
        Text(
          value,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        ),
      ],
    );
  }

  // ── Pension comparison ─────────────────────────────────────

  Widget _buildPensionComparison(S s) {
    // GATE DUR : rente projetée + lacune consomment revenu + avoir LPP + âge.
    // Un seul manquant → carte de situation (aucun chiffre fabriqué).
    final gate = _pensionGate(context);
    if (!gate.complete) {
      return SituationGateCard(title: s.genderGapGatePensionTitle, gate: gate);
    }
    final result = _result!;
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.genderGapRenteLppEstimee,
            style: MintTextStyles.titleLarge(),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            s.genderGapProjection('${result.anneesRestantes}'),
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.lg),

          // Visual bars
          _buildPensionBar(
            label: s.genderGapAt100,
            amount: result.renteAt100Pct,
            maxAmount: result.renteAt100Pct,
            color: MintColors.success,
          ),
          const SizedBox(height: MintSpacing.sm),
          _buildPensionBar(
            label: s.genderGapAtTaux('${_tauxActivite.round()}'),
            amount: result.renteAtCurrentTaux,
            maxAmount: result.renteAt100Pct,
            color: _tauxActivite < 60 ? MintColors.error : MintColors.warning,
          ),
          const SizedBox(height: MintSpacing.lg),

          // Gap highlight
          Semantics(
            label: '${s.genderGapLacuneAnnuelle} ${GenderGapService.formatChf(result.lacuneAnnuelle)}',
            child: Container(
              padding: const EdgeInsets.all(MintSpacing.md),
              decoration: BoxDecoration(
                color: MintColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MintColors.error.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.genderGapLacuneAnnuelle,
                        style: MintTextStyles.bodyMedium(color: MintColors.error),
                      ),
                      Text(
                        GenderGapService.formatChf(result.lacuneAnnuelle),
                        style: MintTextStyles.titleLarge(color: MintColors.error),
                      ),
                    ],
                  ),
                  const SizedBox(height: MintSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.genderGapLacuneTotale,
                        style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                      ),
                      Text(
                        GenderGapService.formatChf(result.lacuneTotale),
                        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          // Transparence : la projection repose sur des hypothèses simplifiées
          // (rendement LPP + durée de retraite) — on les énonce plutôt que de les
          // laisser implicites derrière un chiffre « ta situation ».
          Text(
            s.genderGapProjectionAssumptions,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted)
                .copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPensionBar({
    required String label,
    required double amount,
    required double maxAmount,
    required Color color,
  }) {
    final ratio = maxAmount > 0 ? (amount / maxAmount).clamp(0.0, 1.0) : 0.0;
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
              '${GenderGapService.formatChf(amount)}${S.of(context)!.genderGapPerYear}',
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 12,
            backgroundColor: MintColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── Coordination explanation ───────────────────────────────

  Widget _buildCoordinationExplanation(S s) {
    // GATE DUR : le salaire coordonné dérive du revenu. Revenu non confirmé →
    // carte de situation.
    final gate = _coordinationGate(context);
    if (!gate.complete) {
      return SituationGateCard(title: s.genderGapGateCoordTitle, gate: gate);
    }
    final result = _result!;
    // Atteint uniquement quand le revenu est confirmé → `_revenuAnnuel!` sûr.
    final revenu = _revenuAnnuel!;
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, color: MintColors.purple, size: 20),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  s.genderGapCoordinationTitle,
                  style: MintTextStyles.labelLarge(),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            s.genderGapCoordinationBody,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.md),

          // Comparison table
          MintSurface(
            tone: MintSurfaceTone.porcelaine,
            padding: const EdgeInsets.all(12),
            radius: 12,
            child: Column(
              children: [
                _buildComparisonRow(
                  s.genderGapSalaireBrut100,
                  GenderGapService.formatChf(revenu),
                ),
                const Divider(height: MintSpacing.md),
                _buildComparisonRow(
                  s.genderGapSalaireCoordonne100,
                  GenderGapService.formatChf(result.salaireCoordonne100),
                ),
                const Divider(height: MintSpacing.md),
                _buildComparisonRow(
                  s.genderGapSalaireBrutTaux('${_tauxActivite.round()}'),
                  GenderGapService.formatChf(revenu * (_tauxActivite / 100)),
                ),
                const Divider(height: MintSpacing.md),
                _buildComparisonRow(
                  s.genderGapSalaireCoordonneTaux('${_tauxActivite.round()}'),
                  GenderGapService.formatChf(result.salaireCoordonneActuel),
                  highlight: true,
                ),
                const Divider(height: MintSpacing.md),
                _buildComparisonRow(
                  s.genderGapDeductionFixe,
                  GenderGapService.formatChf(result.deductionCoordination),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            s.genderGapSourceCoordination,
            style: MintTextStyles.labelSmall(),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: MintTextStyles.labelSmall(
              color: highlight ? MintColors.error : MintColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: MintTextStyles.bodySmall(
            color: highlight ? MintColors.error : MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── OFS Statistic ──────────────────────────────────────────
  // ÉDUCATIF (fait général OFS) — non gaté.

  Widget _buildOfsStatistic(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bar_chart, color: MintColors.purple, size: 24),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.genderGapStatOfsTitle,
                  style: MintTextStyles.bodyMedium(color: MintColors.purple).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  GenderGapService.statistiqueOfs,
                  style: MintTextStyles.bodySmall(color: MintColors.purple),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Recommendations ────────────────────────────────────────
  // ÉDUCATIF (options générales avec sources légales) — non gaté.

  Widget _buildRecommendations(S s) {
    final result = _result!;
    if (result.recommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 16, color: MintColors.textMuted),
            const SizedBox(width: MintSpacing.sm),
            Text(
              s.genderGapRecommandations,
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm),
        ...result.recommendations.map((rec) => Padding(
          padding: const EdgeInsets.only(bottom: MintSpacing.sm),
          child: _buildRecommendationCard(rec),
        )),
      ],
    );
  }

  Widget _buildRecommendationCard(GenderGapRecommendation rec) {
    return Semantics(
      label: rec.title,
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rec.title,
              style: MintTextStyles.labelLarge(),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              rec.description,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              rec.source,
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer(S s) {
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
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              s.genderGapDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sources footer ─────────────────────────────────────────

  Widget _buildSourcesFooter(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.genderGapSources,
          style: MintTextStyles.labelSmall(),
        ),
        const SizedBox(height: 6),
        Text(
          s.genderGapSourcesBody,
          style: MintTextStyles.labelSmall(),
        ),
      ],
    );
  }
}
