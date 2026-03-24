import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
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
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/models/screen_return.dart';

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
        final age = DateTime.now().year - profile.birthYear;
        _age = age.clamp(18, 64);
        final savings = profile.patrimoine.epargneLiquide;
        if (savings > 0) _savings = savings.clamp(0.0, 500000.0);
      });
    }
    ScreenCompletionTracker.markCompletedWithReturn(
      'disability_gap',
      ScreenReturn.completed(
        route: '/disability-gap',
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
    // Acte 1 : Employeur — 80% salaire (CO art. 324a, durée variable)
    final act1Income = _grossMonthly * 0.80;

    // Acte 2 : IJM — 80% si souscrite, 0 sinon (24 mois max)
    final act2Income = _hasIjm ? _grossMonthly * 0.80 : 0.0;

    // Acte 3 : AI + LPP (définitif)
    // AI max CHF 2'520/mois (LAI art. 28 + LAVS art. 34)
    // LPP invalidité ≈ 40% salaire coordonné (LPP art. 23-24, estimation)
    final annualGross = _grossMonthly * 12;
    double lppInvalidity = 0.0;
    if (annualGross >= lppSeuilEntree) {
      final coordinated = (annualGross - lppDeductionCoordination)
          .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
      lppInvalidity = coordinated * 0.40 / 12;
    }
    final act3Income = aiRenteEntiere + lppInvalidity;

    final s = S.of(context)!;
    return [
      DisabilityAct(
        label: s.disabilityGapAct1Label,
        subtitle: s.disabilityGapEmployerSub,
        durationLabel: s.disabilityGapAct1Duration,
        monthlyIncome: act1Income,
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
        monthlyIncome: act2Income,
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
        monthlyIncome: act3Income,
        emoji: '🔴',
        color: MintColors.error,
        detail: s.disabilityGapAct3Detail(_fmtChf(aiRenteEntiere), _fmtChf(lppInvalidity), _fmtChf(act3Income)),
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

  List<CoverageItem> get _scorecardItems {
    final s = S.of(context)!;
    // APG/IJM grade
    final ijmGrade = _hasIjm ? 'B+' : 'F';
    final ijmDetail = _hasIjm
        ? s.disabilityGapIjmCoverage
        : s.disabilityGapNoIjmCoverage;

    // AI grade (systemic — everyone gets it)
    const aiGrade = 'C';

    // LPP grade
    final annualGross = _grossMonthly * 12;
    final hasLpp = annualGross >= lppSeuilEntree;
    final lppGrade = hasLpp ? 'A-' : 'D';
    final lppDetail = hasLpp
        ? s.disabilityGapLppCovered
        : s.disabilityGapLppNotCovered;

    // Épargne urgence grade
    final monthsReserve = _savings / (_grossMonthly * 0.7);
    final String savingsGrade;
    if (monthsReserve >= 6) {
      savingsGrade = 'A';
    } else if (monthsReserve >= 3) {
      savingsGrade = 'C+';
    } else if (monthsReserve >= 1) {
      savingsGrade = 'D';
    } else {
      savingsGrade = 'F';
    }

    return [
      CoverageItem(
        label: s.disabilityGapApgLabel,
        grade: ijmGrade,
        detail: ijmDetail,
        legalRef: 'LAMal art. 67-77',
        emoji: '🛡️',
      ),
      CoverageItem(
        label: s.disabilityGapAiLabel,
        grade: aiGrade,
        detail: s.disabilityGapAiDetail(_fmtChf(aiRenteEntiere)),
        legalRef: 'LAI art. 28',
        emoji: '🏛️',
      ),
      CoverageItem(
        label: s.disabilityGapLppLabel,
        grade: lppGrade,
        detail: lppDetail,
        legalRef: 'LPP art. 23-26',
        emoji: '🏦',
      ),
      CoverageItem(
        label: s.disabilityGapSavingsLabel,
        grade: savingsGrade,
        detail: s.disabilityGapSavingsDetail(monthsReserve.toStringAsFixed(1)),
        emoji: '💰',
      ),
    ];
  }

  String get _overallGrade {
    final hasIjmOk = _hasIjm;
    final annualGross = _grossMonthly * 12;
    final hasLpp = annualGross >= lppSeuilEntree;
    final monthsReserve = _savings / (_grossMonthly * 0.7);
    int score = 0;
    if (hasIjmOk) score += 3;
    if (hasLpp) score += 2;
    if (monthsReserve >= 3) score += 2;
    if (monthsReserve >= 6) score += 1;
    if (score >= 7) return 'B+';
    if (score >= 5) return 'C+';
    if (score >= 3) return 'C-';
    return 'D';
  }

  double get _lifeDropPercent {
    final act3Income = _acts.last.monthlyIncome;
    return ((1 - act3Income / _grossMonthly) * 100).clamp(0, 100);
  }

  static String _fmtChf(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _buildInputsCard(),
                const SizedBox(height: 20),
                DisabilityCliffWidget(
                  grossMonthly: _grossMonthly,
                  acts: _acts,
                ),
                const SizedBox(height: 20),
                DisabilityCountdownWidget(
                  monthlyExpenses: _grossMonthly * 0.70,
                  initialSavings: _savings,
                ),
                const SizedBox(height: 20),
                if (_age >= 35 && _lppCapitalBefore > 0) ...[
                  DisabilityResetWidget(
                    currentAge: _age,
                    currentSalary: _grossMonthly * 12,
                    reducedSalary: _grossMonthly * 12 * 0.5,
                    capitalBefore: _lppCapitalBefore,
                    capitalAfter: _lppCapitalAfter,
                  ),
                  const SizedBox(height: 20),
                ],
                DisabilityScorecardWidget(
                  items: _scorecardItems,
                  overallGrade: _overallGrade,
                  lifeDropPercent: _lifeDropPercent,
                ),
                const SizedBox(height: 20),
                // ── Related sections (hub) ──
                _buildRelatedSections(),
                const SizedBox(height: 20),
                EduDisclaimer(
                  text: S.of(context)!.disabilityGapDisclaimer,
                ),
                const SizedBox(height: 8),
                EduLegalSources(
                  sources: S.of(context)!.disabilityGapSources,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: MintColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MintColors.redWine, MintColors.darkRed],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    S.of(context)!.disabilityStatLine1,
                    style: MintTextStyles.bodySmall(color: MintColors.white70).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                  Text(
                    S.of(context)!.disabilityStatLine2,
                    style: MintTextStyles.titleMedium(color: MintColors.white).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      title: Text(
        S.of(context)!.disabilityAppBarTitle,
        style: MintTextStyles.titleMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildInputsCard() {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
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
            format: (v) => "CHF ${_fmtChf(v)}",
            onChanged: (v) => setState(() => _grossMonthly = v),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: S.of(context)!.disabilityYourAge,
            value: _age.toDouble(),
            min: 18,
            max: 64,
            divisions: 46,
            format: (v) => S.of(context)!.disabilityGapAgeLabel(v.toInt()),
            onChanged: (v) => setState(() => _age = v.toInt()),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: S.of(context)!.disabilityAvailableSavings,
            value: _savings,
            min: 0,
            max: 200000,
            divisions: 40,
            format: (v) => "CHF ${_fmtChf(v)}",
            onChanged: (v) => setState(() => _savings = v),
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
                onChanged: (v) => setState(() => _hasIjm = v),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
            Text(
              format(value),
              style: MintTextStyles.bodySmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.border,
            thumbColor: MintColors.primary,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
