import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';

/// Screen for navigating the financial impact of a relative's death in Switzerland.
///
/// Covers succession timeline, urgent actions, fiscal obligations,
/// 2nd/3rd pillar beneficiaries, and marital regime impact.
/// Life Event: deathOfRelative.
///
/// P2 « gate dur » : les deux sorties chiffrées/personnalisées de l'écran sont
/// gatées derrière les faits de situation qu'ELLES consomment.
///   • Bénéficiaires (capital LPP + 3a du défunt) — chiffres échos de données que
///     SEUL l'utilisateur peut fournir (avoirs du DÉFUNT, jamais dans son propre
///     profil) → faits TOUCH-ONLY. Aucun amorçage depuis le patrimoine/LPP/3a de
///     l'utilisateur : ce serait attribuer SES avoirs au défunt (fabrication).
///   • Impact fiscal (exonération / imposition cantonale) — affirmation
///     personnalisée gatée sur le lien de parenté (touch) + le canton de la
///     succession (clé 'canton' ou touch ; défaut = domicile du DÉFUNT, que
///     l'utilisateur confirme/corrige — l'impôt successoral est cantonal).
/// Un fait n'est CONFIRMÉ que s'il vient de données réelles (provenance
/// `userProvidedFields` / champ touché) ; une valeur égale à un défaut fabriqué
/// reste ASSUMED. Aucun chiffre/affirmation ne s'affiche sur un défaut inventé.
/// Réf : .planning/decisions/2026-07-25-p2-simulator-result-gating.md
///
/// `_fortuneDefunt` et `_testamentExiste` restent des entrées de situation
/// éditables mais ne nourrissent AUCUNE sortie chiffrée (pas de service de
/// réserve/quotité sur cet écran) → ils ne gatent rien. Leur amorçage fabriqué
/// (patrimoine de l'utilisateur → fortune du défunt) est retiré.
class DecesProcheScreen extends StatefulWidget {
  const DecesProcheScreen({super.key});

  @override
  State<DecesProcheScreen> createState() => _DecesProcheScreenState();
}

class _DecesProcheScreenState extends State<DecesProcheScreen> {
  // ── Input state ──
  String _lienParente = 'conjoint';
  String _canton = 'ZH';
  double _fortuneDefunt = 500000; // entrée éditable ; ne nourrit aucune sortie.
  double _lppDefunt = 200000;
  double _pilier3aDefunt = 50000;
  bool _testamentExiste = false; // entrée ; n'affecte aucune sortie chiffrée.

  // ── P2 « gate dur » : provenance PAR FAIT (touch-only) ──
  // Toutes les données de cet écran concernent le DÉFUNT (lien avec le défunt,
  // canton du dernier domicile du défunt, avoirs LPP/3a du défunt) : AUCUNE
  // n'est dans le profil de l'utilisateur → toutes TOUCH-ONLY. On ne lit donc
  // jamais le profil ici (seeder le canton de l'utilisateur comme celui du
  // défunt serait la même fabrication que d'attribuer les avoirs de
  // l'utilisateur au défunt).
  bool _lienTouched = false;
  bool _cantonTouched = false;
  bool _lppTouched = false;
  bool _pilier3aTouched = false;

  // Baselines pour l'annonce VoiceOver incomplet→complet (par sortie).
  bool _beneficiairesGateComplete = false;
  bool _impactGateComplete = false;

  // Ancres pour scroll-to-first-missing quand une situation est incomplète.
  final _lienKey = GlobalKey();
  final _cantonKey = GlobalKey();
  final _lppKey = GlobalKey();
  final _pilier3aKey = GlobalKey();

  /// P2 (zéro donnée inventée) : cet écran ne lit PAS le profil de l'utilisateur.
  /// Toutes les données concernent le défunt (lien, canton du défunt, avoirs du
  /// défunt) et sont donc fournies par l'utilisateur (touch). On calcule juste
  /// la baseline pour l'annonce VoiceOver incomplet→complet.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshGateBaselines();
  }

  // ── P2 provenance getters (touch-only, non-latching) ──
  FactProvenance get _lienProvenance =>
      _lienTouched ? FactProvenance.touched : FactProvenance.assumed;

  FactProvenance get _cantonProvenance =>
      _cantonTouched ? FactProvenance.touched : FactProvenance.assumed;

  FactProvenance get _lppProvenance =>
      _lppTouched ? FactProvenance.touched : FactProvenance.assumed;

  FactProvenance get _pilier3aProvenance =>
      _pilier3aTouched ? FactProvenance.touched : FactProvenance.assumed;

  // ── Per-output gates (determinative facts only) ──
  // Bénéficiaires : capital LPP + capital 3a du défunt (les deux chiffres échos
  // du bloc « prévoyance du défunt »). Aucune source profil → touch seul.
  SituationGate _beneficiairesGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'lppDefunt',
          label: (c) => S.of(c)!.decesGateFactLpp,
          why: (c) => S.of(c)!.decesGateWhyLpp,
          provenance: _lppProvenance,
          onComplete: () => _scrollToKey(_lppKey),
        ),
        SituationFact(
          key: 'pilier3aDefunt',
          label: (c) => S.of(c)!.decesGateFact3a,
          why: (c) => S.of(c)!.decesGateWhy3a,
          provenance: _pilier3aProvenance,
          onComplete: () => _scrollToKey(_pilier3aKey),
        ),
      ]);

  // Impact fiscal : l'exonération / imposition dépend du lien de parenté et du
  // canton de la succession (barème cantonal). La fortune du défunt ne change
  // pas l'affirmation qualitative (exonéré / soumis) → non gatée ici.
  SituationGate _impactFiscalGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'lienParente',
          label: (c) => S.of(c)!.decesGateFactLien,
          why: (c) => S.of(c)!.decesGateWhyLien,
          provenance: _lienProvenance,
          onComplete: () => _scrollToKey(_lienKey),
        ),
        SituationFact(
          key: 'canton',
          label: (c) => S.of(c)!.decesGateFactCanton,
          why: (c) => S.of(c)!.decesGateWhyCanton,
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

  void _refreshGateBaselines() {
    _beneficiairesGateComplete = _beneficiairesGate(context).complete;
    _impactGateComplete = _impactFiscalGate(context).complete;
  }

  void _announceComplete() {
    SemanticsService.sendAnnouncement(
      View.of(context),
      S.of(context)!.situationGateAnnounceComplete,
      Directionality.of(context),
    );
  }

  /// L'utilisateur a édité un fait de situation : rebuild (les sorties se
  /// recalculent inline dans leur branche `complete`, aucun résultat stocké à
  /// invalider) et annonce le passage incomplet→complet d'une sortie pour
  /// VoiceOver (le scroll ≠ déplacement de focus).
  void _afterFactChanged() {
    final wasBeneficiaires = _beneficiairesGateComplete;
    final wasImpact = _impactGateComplete;
    setState(() {});
    _refreshGateBaselines();
    final newlyComplete = (_beneficiairesGateComplete && !wasBeneficiaires) ||
        (_impactGateComplete && !wasImpact);
    if (newlyComplete) _announceComplete();
  }

  /// @visibleForTesting : entrées consommées par les sorties (preuve P2).
  @visibleForTesting
  String get debugLienParente => _lienParente;
  @visibleForTesting
  String get debugCanton => _canton;
  @visibleForTesting
  double get debugLppDefunt => _lppDefunt;
  @visibleForTesting
  double get debugPilier3aDefunt => _pilier3aDefunt;
  @visibleForTesting
  double get debugFortuneDefunt => _fortuneDefunt;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Semantics(
      identifier: 'deces_proche_screen',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        // Ancre C4 « pas de cul-de-sac » : bouton retour identifié (safePop →
        // pop, sinon go('/home')) remplaçant le back par défaut, non-poppable
        // sur entrée deeplink. `label` = tooltip « retour » localisé (leçon
        // Codex B3 #1141 : un leading icon-only sans label est annoncé « bouton »
        // seul par VoiceOver). Smoke Tier B (lot B4).
        leading: Semantics(
          identifier: 'deces-back',
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
          identifier: 'deces-anchor',
          child: Text(s.decesProcheTitre, style: MintTextStyles.headlineMedium()),
        ),
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero: premier éclairage ──
              MintEntrance(child: _buildPremierEclairage(s)),
              const SizedBox(height: 24),

              // ── Urgences 48h ──
              MintEntrance(delay: const Duration(milliseconds: 100), child: _buildUrgences48h(s)),
              const SizedBox(height: 24),

              // ── Inputs ──
              MintEntrance(delay: const Duration(milliseconds: 200), child: _buildInputs(s)),
              const SizedBox(height: 24),

              // ── Timeline succession ──
              MintEntrance(delay: const Duration(milliseconds: 300), child: _buildTimeline(s)),
              const SizedBox(height: 24),

              // ── Beneficiaires LPP / 3a (gaté) ──
              MintEntrance(delay: const Duration(milliseconds: 400), child: _buildBeneficiaires(s)),
              const SizedBox(height: 24),

              // ── Impact fiscal (gaté) ──
              _buildImpactFiscal(s),
              const SizedBox(height: 24),

              // ── Actions concrètes ──
              _buildActions(s),
              const SizedBox(height: 24),

              // ── Disclaimer ──
              _buildDisclaimer(s),
            ],
          ),
        ),
      ))),
    ));
  }

  Widget _buildPremierEclairage(S s) {
    const delaiRepudiation = 3; // mois — CC art. 567 (constante légale)
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MintColors.primary, MintColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Semantics(
            label: '$delaiRepudiation ${s.decesProcheMoisRepudiation}',
            child: Text(
              '$delaiRepudiation',
              style: MintTextStyles.displayLarge(color: MintColors.white),
            ),
          ),
          Text(
            s.decesProcheMoisRepudiation,
            style: MintTextStyles.bodyLarge(color: MintColors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUrgences48h(S s) {
    final urgences = [
      s.decesProche48hActe,
      s.decesProche48hBanque,
      s.decesProche48hAssurance,
      s.decesProche48hEmployeur,
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.urgentBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.decesProche48hTitre,
            style: MintTextStyles.titleMedium(color: MintColors.error).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...urgences.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: MintColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${e.key + 1}',
                          style: MintTextStyles.labelSmall(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.value,
                          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
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

  Widget _buildInputs(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.decesProcheSituation,
          style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
        ),
        const SizedBox(height: MintSpacing.md),

        // Lien de parenté (fait de situation TOUCH-ONLY)
        Row(
          key: _lienKey,
          children: [
            Expanded(
              child: Text(s.decesProcheLienParente,
                  style: MintTextStyles.bodyMedium(color: MintColors.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'conjoint', label: Text(s.decesProcheLienConjoint)),
            ButtonSegment(value: 'parent', label: Text(s.decesProcheLienParent)),
            ButtonSegment(value: 'enfant', label: Text(s.decesProcheLienEnfant)),
          ],
          selected: {_lienParente},
          onSelectionChanged: (v) {
            // Sélectionner = fournir la donnée (touch seul ; aucune clé profil).
            _lienTouched = true;
            _lienParente = v.first;
            _afterFactChanged();
          },
        ),
        const SizedBox(height: 16),

        // Fortune du défunt — entrée éditable ; ne nourrit AUCUNE sortie chiffrée
        // (pas de service de réserve/quotité). Jamais amorcée depuis le
        // patrimoine de l'utilisateur (ce serait attribuer sa fortune au défunt).
        MintPremiumSlider(
          key: const Key('deces_fortune_field'),
          label: s.decesProcheFortune,
          value: _fortuneDefunt,
          min: 0,
          max: 5000000,
          divisions: 100,
          formatValue: (v) => formatChfWithPrefix(v),
          onChanged: (v) => setState(() => _fortuneDefunt = v),
        ),
        const SizedBox(height: 16),

        // Capital LPP du défunt (TOUCH-ONLY ; alimente la carte bénéficiaires)
        KeyedSubtree(
          key: _lppKey,
          child: MintPremiumSlider(
            key: const Key('deces_lpp_field'),
            label: s.decesProchebeneficiairesLpp,
            value: _lppDefunt,
            min: 0,
            max: 2000000,
            divisions: 100,
            formatValue: (v) => formatChfWithPrefix(v),
            onChanged: (v) {
              _lppTouched = true;
              _lppDefunt = v;
              _afterFactChanged();
            },
          ),
        ),
        const SizedBox(height: 16),

        // Capital 3a du défunt (TOUCH-ONLY ; alimente la carte bénéficiaires)
        KeyedSubtree(
          key: _pilier3aKey,
          child: MintPremiumSlider(
            key: const Key('deces_3a_field'),
            label: s.decesProchebeneficiaires3a,
            value: _pilier3aDefunt,
            min: 0,
            max: 500000,
            divisions: 100,
            formatValue: (v) => formatChfWithPrefix(v),
            onChanged: (v) {
              _pilier3aTouched = true;
              _pilier3aDefunt = v;
              _afterFactChanged();
            },
          ),
        ),
        const SizedBox(height: 16),

        // Canton de la succession (clé 'canton' ou touch)
        Row(
          key: _cantonKey,
          children: [
            Text(s.decesProcheCanton,
                style: MintTextStyles.bodyMedium(color: MintColors.textSecondary)),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _canton,
              items: FamilyService.sortedCantonCodes
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  // Touch = l'utilisateur renseigne le canton du défunt.
                  _cantonTouched = true;
                  _canton = v;
                  _afterFactChanged();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Testament — entrée de situation ; n'affecte aucune sortie chiffrée de
        // cet écran (les bénéficiaires LPP/3a suivent l'ordre OPP2/OPP3, l'impôt
        // successoral dépend du lien + canton) → non gaté.
        SwitchListTile(
          title: Text(s.decesProchTestament,
              style: MintTextStyles.bodyMedium()),
          value: _testamentExiste,
          onChanged: (v) => setState(() => _testamentExiste = v),
        ),
      ],
    );
  }

  Widget _buildTimeline(S s) {
    final etapes = [
      (s.decesProchTimeline1Titre, s.decesProchTimeline1Desc, '0-3 j'),
      (s.decesProchTimeline2Titre, s.decesProchTimeline2Desc, '1-4 sem'),
      (s.decesProchTimeline3Titre, s.decesProchTimeline3Desc, '1-3 mois'),
      (s.decesProchTimeline4Titre, s.decesProchTimeline4Desc, '3-12 mois'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.decesProchTimelineTitre,
          style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
        ),
        const SizedBox(height: MintSpacing.md),
        ...etapes.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MintSurface(
                  tone: MintSurfaceTone.porcelaine,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  radius: 8,
                  child: Text(e.$3,
                      style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.$1,
                          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(e.$2,
                          style: MintTextStyles.bodySmall(color: MintColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Carte bénéficiaires : les deux chiffres (capital LPP + 3a du défunt) sont
  /// des échos de faits que SEUL l'utilisateur peut fournir. Sur les défauts
  /// 200000/50000 ce serait une prévoyance du défunt fabriquée → gate sur
  /// {lppDefunt, pilier3aDefunt}. Tant que les deux faits ne sont pas confirmés,
  /// on affiche la carte de situation (jamais un chiffre inventé).
  Widget _buildBeneficiaires(S s) {
    final gate = _beneficiairesGate(context);
    if (!gate.complete) {
      return SituationGateCard(
        title: s.donationGateTitle,
        gate: gate,
      );
    }
    // Ancre régionale Tier B smoke (C2 « chiffré ») posée sur la carte
    // bénéficiaires — présente UNIQUEMENT quand le gate {lppDefunt, pilier3aDefunt}
    // est complet (avoirs du défunt renseignés), jamais sur la carte-gate vide.
    // Motif profond, jamais le wrapper racine (leçon ADR AX iOS 26.2).
    return Semantics(
      identifier: 'deces-result',
      child: Container(
      key: const Key('deces_beneficiaires_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.decesProchebeneficiairesTitre,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _infoRow(s.decesProchebeneficiairesLpp,
              formatChfWithPrefix(_lppDefunt)),
          const SizedBox(height: 8),
          _infoRow(s.decesProchebeneficiaires3a,
              formatChfWithPrefix(_pilier3aDefunt)),
          const SizedBox(height: 12),
          Text(
            s.decesProchebeneficiairesNote,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary)),
        Text(value,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  /// Impact fiscal : affirmation personnalisée (exonéré / soumis au canton).
  /// Gatée sur {lienParente, canton} — sur les défauts conjoint/ZH ce serait une
  /// affirmation fiscale personnalisée fabriquée (mauvais lien / mauvais canton).
  Widget _buildImpactFiscal(S s) {
    final gate = _impactFiscalGate(context);
    if (!gate.complete) {
      return SituationGateCard(
        title: s.donationGateTitle,
        gate: gate,
      );
    }
    final estExempt = _lienParente == 'conjoint';
    return Container(
      key: const Key('deces_impact_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: estExempt ? MintColors.successBg : MintColors.warningBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.decesProchImpactFiscalTitre,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            estExempt
                ? s.decesProchImpactFiscalExempt(_canton)
                : s.decesProchImpactFiscalTaxe(_canton),
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(S s) {
    final actions = [
      s.decesProchAction1,
      s.decesProchAction2,
      s.decesProchAction3,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.decesProchActionsTitre,
          style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
        ),
        const SizedBox(height: 12),
        ...actions.map(
          (a) => MintSurface(
            tone: MintSurfaceTone.porcelaine,
            padding: const EdgeInsets.all(12),
            radius: 10,
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: MintColors.success, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(a,
                      style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer(S s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.disclaimerBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        s.decesProchDisclaimer,
        style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}
