import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/domain/disability_gap_calculator.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/disability_cliff_widget.dart';
import 'package:mint_mobile/widgets/coach/disability_countdown_widget.dart';
import 'package:mint_mobile/widgets/coach/disability_reset_widget.dart';
import 'package:mint_mobile/widgets/coach/disability_scorecard_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';
import 'package:mint_mobile/widgets/collapsible_section.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';

// ────────────────────────────────────────────────────────────
//  P4 — ÉCRAN PRINCIPAL INVALIDITÉ
//  La Falaise (A) + Reset silencieux (B) + Countdown (F) + Bulletin (E)
//  Source : LAI art. 28, LPP art. 23-26, CO art. 324a, LPGA art. 19
// ────────────────────────────────────────────────────────────

class DisabilityGapScreen extends StatefulWidget {
  const DisabilityGapScreen({super.key});

  @override
  State<DisabilityGapScreen> createState() => _DisabilityGapScreenState();
}

class _DisabilityGapScreenState extends State<DisabilityGapScreen> {
  double _grossMonthly = 8333; // ~100k/an
  int _age = 45;
  double _savings = 30000;
  bool _hasIjm = true;
  bool _seededFromProfile = false;
  bool _hasUserInteracted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededFromProfile) return;
    _seededFromProfile = true;
    final profile = context.read<CoachProfileProvider>().profile;
    if (profile != null) {
      setState(() {
        final salary = profile.salaireBrutMensuel;
        if (salary > 0) _grossMonthly = salary.clamp(2000.0, 25000.0);
        // SALVAGE-01-02 / def-03/mlf-03: route age through ageOrNull instead
        // of the raw `now.year - birthYear`, which on the birthYear==0
        // sentinel yielded 2026 -> clamp(18,64) = 64 (a fabricated near-
        // retirement age). When age is unknown, leave the editable _age
        // slider at its default so the user supplies it (prompt, not 64).
        final age = profile.ageOrNull;
        if (age != null) _age = age.clamp(18, 64);
        final savings = profile.patrimoine.epargneLiquide;
        if (savings > 0) _savings = savings.clamp(0.0, 500000.0);
      });
    }
  }

  void _emitScreenReturn() {
    if (!_hasUserInteracted) return;
    ScreenCompletionTracker.markCompletedWithReturn(
      'disability_gap',
      ScreenReturn.completed(
        route: '/invalidite',
        updatedFields: {
          'disabilityGapMensuel': _grossMonthly - _acts.last.monthlyIncome,
        },
        confidenceDelta: 0.02,
        nextCapSuggestion: 'assurance_invalidite',
      ),
    );
  }

  // ── Calcul des actes (La Falaise) ─────────────────────────

  List<DisabilityAct> get _acts {
    // Étalon unique : DisabilityService (fin du doublon 3-têtes, cf.
    // V2-2-INVENTORY.md). Acte 1 = employeur 100 % (CO art. 324a — verdict
    // actuaire Codex 2026-07-31 : afficher 80 % pour cet acte était FAUX, le
    // 80 % correspond à l'IJM) ; acte 2 = IJM 80 %/0 ; acte 3 = AI (max légal)
    // + LPP (proxy éducatif sourcé).
    final proj = DisabilityService.acts(
      grossMonthly: _grossMonthly,
      hasIjm: _hasIjm,
    );

    final s = S.of(context)!;
    return [
      DisabilityAct(
        label: s.disabilityGapAct1Label,
        subtitle: s.disabilityGapEmployerSub,
        durationLabel: s.disabilityGapAct1Duration,
        monthlyIncome: proj.employerIncome,
        emoji: '🟢',
        color: MintColors.success,
        detail: s.disabilityGapAct1Detail,
      ),
      DisabilityAct(
        label: _hasIjm ? s.disabilityGapAct2LabelIjm : s.disabilityGapAct2LabelNoIjm,
        subtitle: _hasIjm
            ? s.disabilityGapAct2SubIjm
            : s.disabilityGapAct2SubNoIjm,
        durationLabel: s.disabilityGapAct2Duration,
        monthlyIncome: proj.ijmIncome,
        emoji: _hasIjm ? '🟡' : '🔴',
        color: _hasIjm ? MintColors.amber : MintColors.error,
        detail: _hasIjm
            ? s.disabilityGapAct2DetailIjm
            : s.disabilityGapAct2DetailNoIjm,
      ),
      DisabilityAct(
        label: s.disabilityGapAct3Label,
        subtitle: s.disabilityGapAiDelaySub,
        durationLabel: s.disabilityGapAct3Duration,
        monthlyIncome: proj.longTermIncome,
        emoji: '🔴',
        color: MintColors.error,
        detail: s.disabilityGapAct3Detail(
            formatChf(proj.aiRente),
            formatChf(proj.lppInvalidity),
            formatChf(proj.longTermIncome)),
      ),
    ];
  }

  // ── Calcul Reset silencieux (LPP) ────────────────────────

  double get _lppCapitalBefore {
    final yearsToRetirement = (65 - _age).clamp(0, 40);
    final annualGross = _grossMonthly * 12;
    if (annualGross < lppSeuilEntree) return 0;
    final coordinated = (annualGross - lppDeductionCoordination)
        .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
    final rate = getLppBonificationRate(_age);
    final annualContrib = coordinated * rate;
    // Simplified: flat contributions, 1% employer return
    return annualContrib * yearsToRetirement * 1.5; // growth factor approximation
  }

  double get _lppCapitalAfter {
    // 50% disability → 50% salary reduction
    final reducedGross = _grossMonthly * 12 * 0.5;
    final yearsToRetirement = (65 - _age).clamp(0, 40);
    if (reducedGross < lppSeuilEntree) return 0;
    final coordinated = (reducedGross - lppDeductionCoordination)
        .clamp(0.0, lppSalaireCoordMax);
    if (coordinated <= 0) return 0;
    final rate = getLppBonificationRate(_age);
    final annualContrib = coordinated * rate;
    return annualContrib * yearsToRetirement * 1.5;
  }

  // ── Calcul Bulletin scolaire ─────────────────────────────

  // Bulletin de couverture via l'étalon unique DisabilityService (notes lettres
  // + réserve + chute de revenu). Les libellés/détails restent composés ici
  // (i18n ARB) : le service ne retourne jamais de texte FR.
  DisabilityCoverage get _coverage => DisabilityService.coverage(
        grossMonthly: _grossMonthly,
        savings: _savings,
        hasIjm: _hasIjm,
      );

  List<CoverageItem> get _scorecardItems {
    final s = S.of(context)!;
    final cov = _coverage;
    return [
      CoverageItem(
        label: s.disabilityGapApgLabel,
        grade: cov.ijmGrade,
        detail: _hasIjm
            ? s.disabilityGapIjmCoverage
            : s.disabilityGapNoIjmCoverage,
        legalRef: 'LAMal art. 67-77',
        emoji: '🛡️',
      ),
      CoverageItem(
        label: s.disabilityGapAiLabel,
        grade: cov.aiGrade,
        detail: s.disabilityGapAiDetail(
            formatChf(DisabilityService.aiRenteFullMonthly)),
        legalRef: 'LAI art. 28',
        emoji: '🏛️',
      ),
      CoverageItem(
        label: s.disabilityGapLppLabel,
        grade: cov.lppGrade,
        detail: cov.hasLpp
            ? s.disabilityGapLppCovered
            : s.disabilityGapLppNotCovered,
        legalRef: 'LPP art. 23-26',
        emoji: '🏦',
      ),
      CoverageItem(
        label: s.disabilityGapSavingsLabel,
        grade: cov.savingsGrade,
        detail: s.disabilityGapSavingsDetail(
            cov.reserveMonths.toStringAsFixed(1)),
        emoji: '💰',
      ),
    ];
  }

  String get _overallGrade => _coverage.overallGrade;

  double get _lifeDropPercent => _coverage.lifeDropPercent;

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // AX iOS 26.2 (investigation AX invalidite, ADR 2026-07-31) : plus de
    // wrapper racine `Semantics(container:true, explicitChildNodes:true)` NI de
    // `SliverAppBar`. Les DEUX motifs effondraient l'arbre AX des routes
    // poussées sur iOS 26.2 — le wrapper racine AU REPOS, le SliverAppBar AU
    // SCROLL (cf. project_ios26_ax_tree_collapse, patron first_job #1127 /
    // independant #1140). AppBar classique en `Scaffold.appBar` + hero-stat
    // relogé en tête de corps (`_buildStatHero`, ex-`flexibleSpace`) → arbre
    // riche et STABLE au scroll, `disability-result` (Falaise) atteignable.
    // AX iOS 26.2 (investigation AX invalidite) : LISTE LAZY. La cause de
    // l'effondrement d'arbre AX AU FLING était la DENSITÉ SÉMANTIQUE CUMULATIVE
    // des ~4-5 cartes chiffrées rendues au repos (bisection Probe D→H : aucune
    // carte seule n'effondre — sauf le countdown avec son slider interactif,
    // désormais retiré ; c'est le CUMUL qui dépasse le seuil du pont a11y iOS
    // 26.2). `SliverChildBuilderDelegate` + `addAutomaticKeepAlives:false`
    // détruit les cartes hors-vue au scroll → le nombre de nœuds sémantiques
    // VIVANTS reste borné au viewport, sous le seuil. (Cf.
    // project_ios26_ax_tree_collapse ; independant reste sain car son bas de
    // page est gaté/quasi-vide au repos.)
    final items = <Widget>[
      const SizedBox(height: 20),
      // Hero-stat éducatif (« 1 personne sur 5 … ») migré depuis l'ancien
      // `FlexibleSpaceBar` du SliverAppBar (aucune perte de contenu). Pas
      // d'ancre AX ici → pas de piège re-collapse.
      MintEntrance(child: _buildStatHero()),
      const SizedBox(height: 20),
      MintEntrance(child: MintNarrativeCard(
        headline: S.of(context)!.narrativeDisabilityHeadline,
        body: S.of(context)!.narrativeDisabilityBody,
        tone: MintSurfaceTone.peche,
        badge: S.of(context)!.narrativeDisabilityBadge,
      )),
      const SizedBox(height: 20),
      MintEntrance(delay: const Duration(milliseconds: 100), child: _buildInputsCard()),
      const SizedBox(height: 20),
      // Ancre régionale Tier B smoke (C2 « chiffré ») posée sur la « Falaise »
      // — les trois actes (employeur / IJM / AI+LPP) sont chiffrés au repos
      // depuis le profil seedé (salaire/âge), aucun gate. Motif profond, jamais
      // le wrapper racine.
      MintEntrance(delay: const Duration(milliseconds: 200), child: Semantics(
        identifier: 'disability-result',
        child: DisabilityCliffWidget(
          grossMonthly: _grossMonthly,
          acts: _acts,
        ),
      )),
      const SizedBox(height: 20),
      MintEntrance(delay: const Duration(milliseconds: 300), child: DisabilityCountdownWidget(
        monthlyExpenses: DisabilityService.monthlyExpenses(_grossMonthly),
        initialSavings: _savings,
        interactive: false,
      )),
      const SizedBox(height: 20),
      if (_age >= 35 && _lppCapitalBefore > 0) DisabilityResetWidget(
        currentAge: _age,
        currentSalary: _grossMonthly * 12,
        reducedSalary: _grossMonthly * 12 * 0.5,
        capitalBefore: _lppCapitalBefore,
        capitalAfter: _lppCapitalAfter,
      ),
      if (_age >= 35 && _lppCapitalBefore > 0) const SizedBox(height: 20),
      MintEntrance(delay: const Duration(milliseconds: 400), child: DisabilityScorecardWidget(
        items: _scorecardItems,
        overallGrade: _overallGrade,
        lifeDropPercent: _lifeDropPercent,
      )),
      const SizedBox(height: 20),
      // ── Related sections (hub) ──
      MintEntrance(delay: const Duration(milliseconds: 500), child: _buildRelatedSections()),
      const SizedBox(height: 20),
      EduDisclaimer(
        text: S.of(context)!.disabilityGapDisclaimer,
      ),
      const SizedBox(height: 8),
      EduLegalSources(
        sources: S.of(context)!.disabilityGapSources,
      ),
    ];
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: _buildAppBar(context),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => items[index],
                childCount: items.length,
                addAutomaticKeepAlives: false,
              ),
            ),
          ),
        ],
      ))),
    );
  }

  // AX iOS 26.2 (investigation AX invalidite, ADR 2026-07-31) : AppBar
  // classique en `Scaffold.appBar` remplace le `SliverAppBar`
  // (expandedHeight/flexibleSpace) qui ré-effondrait l'arbre AX AU SCROLL sur
  // les routes poussées (2ᵉ déclencheur ADR, cf. project_ios26_ax_tree_collapse,
  // patron first_job #1127 / independant #1140). Le hero-stat éducatif migre en
  // tête de corps (`_buildStatHero`) → aucune perte de contenu. Titre →
  // `AppBar.title` (disability-anchor, C1) ; retour → `leading`
  // (disability-back, C4, safePop + `label` accessible localisé — leçon Codex B3
  // #1141) ; centerTitle:false via AppBarTheme (app.dart).
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: MintColors.primary,
      foregroundColor: MintColors.white,
      leading: Semantics(
        identifier: 'disability-back',
        button: true,
        label: MaterialLocalizations.of(context).backButtonTooltip,
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.white),
          onPressed: () => safePop(context),
        ),
      ),
      title: Semantics(
        identifier: 'disability-anchor',
        child: Text(
          S.of(context)!.disabilityAppBarTitle,
          style: MintTextStyles.titleMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // Hero-stat éducatif relogé depuis l'ancien `FlexibleSpaceBar` du SliverAppBar
  // (« 1 personne sur 5 / sera touchée avant 65 ans »). Bannière dégradée en
  // tête de corps — même contenu, mêmes couleurs/styles, aucune ancre AX (pas de
  // piège re-collapse sur un MintEntrance animé).
  Widget _buildStatHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MintColors.redWine, MintColors.darkRed],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.disabilityStatLine1,
            style: MintTextStyles.bodySmall(color: MintColors.white70).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
          Text(
            S.of(context)!.disabilityStatLine2,
            style: MintTextStyles.titleLarge(color: MintColors.white).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildInputsCard() {
    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.disabilityYourSituation,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _buildSliderRow(
            label: S.of(context)!.disabilityGrossMonthly,
            value: _grossMonthly,
            min: 2000,
            max: 25000,
            divisions: 46,
            format: (v) => "CHF ${formatChf(v)}",
            onChanged: (v) { _hasUserInteracted = true; setState(() => _grossMonthly = v); _emitScreenReturn(); },
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: S.of(context)!.disabilityYourAge,
            value: _age.toDouble(),
            min: 18,
            max: 64,
            divisions: 46,
            format: (v) => S.of(context)!.disabilityGapAgeLabel(v.toInt()),
            onChanged: (v) { _hasUserInteracted = true; setState(() => _age = v.toInt()); _emitScreenReturn(); },
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: S.of(context)!.disabilityAvailableSavings,
            value: _savings,
            min: 0,
            max: 200000,
            divisions: 40,
            format: (v) => "CHF ${formatChf(v)}",
            onChanged: (v) { _hasUserInteracted = true; setState(() => _savings = v); _emitScreenReturn(); },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  S.of(context)!.disabilityHasIjm,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
              ),
              Switch(
                value: _hasIjm,
                onChanged: (v) { _hasUserInteracted = true; setState(() => _hasIjm = v); _emitScreenReturn(); },
                activeTrackColor: MintColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.of(context)!.disabilityExploreAlso,
          style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        CollapsibleSection(
          title: S.of(context)!.disabilityCoverageInsurance,
          subtitle: S.of(context)!.disabilityCoverageSubtitle,
          icon: Icons.shield_outlined,
          child: _buildSectionCta(S.of(context)!.disabilityCtaEvaluate, '/disability/insurance'),
        ),
        CollapsibleSection(
          title: S.of(context)!.disabilitySelfEmployed,
          subtitle: S.of(context)!.disabilitySelfEmployedSubtitle,
          icon: Icons.rocket_launch,
          child: _buildSectionCta(S.of(context)!.disabilityCtaAnalyze, '/disability/self-employed'),
        ),
      ],
    );
  }

  Widget _buildSectionCta(String label, String route) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => context.push(route),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required void Function(double) onChanged,
  }) {
    return MintPremiumSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      formatValue: format,
      onChanged: onChanged,
    );
  }
}
