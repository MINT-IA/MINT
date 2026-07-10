import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/disability_insurance_calculator.dart';
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
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

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
  bool _hasIjm = false;
  bool _hasUserInteracted = false;

  CoachProfileProvider? _profileProvider(BuildContext context) {
    try {
      return context.watch<CoachProfileProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  double? _grossMonthlySalary(CoachProfile? profile) {
    if (profile == null || !profile.userProvidedFields.contains('salary')) {
      return null;
    }
    final salary = profile.salaireBrutMensuel;
    if (salary <= 0) return null;
    return salary.toDouble();
  }

  int? _ageFromLedger(CoachProfile? profile) {
    if (profile == null || !profile.userProvidedFields.contains('age')) {
      return null;
    }
    final age = profile.ageOrNull;
    if (age == null || age < 18 || age > 64) return null;
    return age;
  }

  double? _liquidSavings(CoachProfile? profile) {
    if (profile == null ||
        !profile.userProvidedFields.contains('liquidSavings')) {
      return null;
    }
    final savings = profile.patrimoine.epargneLiquide;
    if (savings < 0) return null;
    return savings.toDouble();
  }

  void _emitScreenReturn(double grossMonthly) {
    if (!_hasUserInteracted) return;
    final act3Income = DisabilityInsuranceCalculator.act3MonthlyIncome(
      grossMonthlySalary: grossMonthly,
    );
    ScreenCompletionTracker.markCompletedWithReturn(
      'disability_gap',
      ScreenReturn.completed(
        route: '/invalidite',
        updatedFields: {
          'disabilityGapMensuel': grossMonthly - act3Income,
        },
        confidenceDelta: 0.02,
        nextCapSuggestion: 'assurance_invalidite',
      ),
    );
  }

  // ── Calcul des actes (La Falaise) ─────────────────────────

  List<DisabilityAct> _acts(double grossMonthly) {
    final act1Income =
        DisabilityInsuranceCalculator.employerContinuationMonthlyIncome(
      grossMonthlySalary: grossMonthly,
    );
    final act2Income = DisabilityInsuranceCalculator.ijmMonthlyIncome(
      grossMonthlySalary: grossMonthly,
      hasIjm: _hasIjm,
    );
    final lppInvalidity =
        DisabilityInsuranceCalculator.lppInvalidityMonthlyIncome(
      grossMonthlySalary: grossMonthly,
    );
    final act3Income = DisabilityInsuranceCalculator.act3MonthlyIncome(
      grossMonthlySalary: grossMonthly,
    );
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
        label: _hasIjm
            ? s.disabilityGapAct2LabelIjm
            : s.disabilityGapAct2LabelNoIjm,
        subtitle:
            _hasIjm ? s.disabilityGapAct2SubIjm : s.disabilityGapAct2SubNoIjm,
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
        detail: s.disabilityGapAct3Detail(_fmtChf(aiRenteEntiere),
            _fmtChf(lppInvalidity), _fmtChf(act3Income)),
      ),
    ];
  }

  // ── Calcul Reset silencieux (LPP) ────────────────────────

  double _lppCapitalBefore({
    required int age,
    required double grossMonthly,
  }) {
    return DisabilityInsuranceCalculator.projectedLppCapitalBeforeDisability(
      currentAge: age,
      grossMonthlySalary: grossMonthly,
    );
  }

  double _lppCapitalAfter({
    required int age,
    required double grossMonthly,
  }) {
    return DisabilityInsuranceCalculator.projectedLppCapitalAfterDisability(
      currentAge: age,
      grossMonthlySalary: grossMonthly,
    );
  }

  // ── Calcul Bulletin scolaire ─────────────────────────────

  List<CoverageItem> _scorecardItems({
    required double grossMonthly,
    required double savings,
  }) {
    final s = S.of(context)!;
    // APG/IJM grade
    final ijmGrade = _hasIjm ? 'B+' : 'F';
    final ijmDetail =
        _hasIjm ? s.disabilityGapIjmCoverage : s.disabilityGapNoIjmCoverage;

    // AI grade (systemic — everyone gets it)
    const aiGrade = 'C';

    // LPP grade
    final hasLpp = DisabilityInsuranceCalculator.hasLppInvalidityCoverage(
      grossMonthlySalary: grossMonthly,
    );
    final lppGrade = hasLpp ? 'A-' : 'D';
    final lppDetail =
        hasLpp ? s.disabilityGapLppCovered : s.disabilityGapLppNotCovered;

    // Épargne urgence grade
    final monthsReserve = DisabilityInsuranceCalculator.emergencyReserveMonths(
      grossMonthlySalary: grossMonthly,
      liquidSavings: savings,
    );
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

  String _overallGrade({
    required double grossMonthly,
    required double savings,
  }) {
    final hasIjmOk = _hasIjm;
    final hasLpp = DisabilityInsuranceCalculator.hasLppInvalidityCoverage(
      grossMonthlySalary: grossMonthly,
    );
    final monthsReserve = DisabilityInsuranceCalculator.emergencyReserveMonths(
      grossMonthlySalary: grossMonthly,
      liquidSavings: savings,
    );
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

  double _lifeDropPercent(double grossMonthly) {
    return DisabilityInsuranceCalculator.lifeDropPercent(
      grossMonthlySalary: grossMonthly,
    );
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
    final provider = _profileProvider(context);
    final profile = provider?.profile;
    final grossMonthly = _grossMonthlySalary(profile);
    final age = _ageFromLedger(profile);
    final savings = _liquidSavings(profile);
    final hasRequiredFacts =
        grossMonthly != null && age != null && savings != null;
    final lppCapitalBefore = hasRequiredFacts
        ? _lppCapitalBefore(age: age, grossMonthly: grossMonthly)
        : 0.0;
    final lppCapitalAfter = hasRequiredFacts
        ? _lppCapitalAfter(age: age, grossMonthly: grossMonthly)
        : 0.0;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 20),
                        MintEntrance(
                            child: MintNarrativeCard(
                          headline: S.of(context)!.narrativeDisabilityHeadline,
                          body: S.of(context)!.narrativeDisabilityBody,
                          tone: MintSurfaceTone.peche,
                          badge: S.of(context)!.narrativeDisabilityBadge,
                        )),
                        const SizedBox(height: 20),
                        MintEntrance(
                            delay: const Duration(milliseconds: 100),
                            child: _buildLedgerFactsCard(
                              context,
                              S.of(context)!,
                              grossMonthly: grossMonthly,
                              age: age,
                              savings: savings,
                            )),
                        const SizedBox(height: 20),
                        if (hasRequiredFacts) ...[
                          Semantics(
                            key: const Key('disability_gap_result_section'),
                            identifier: 'disability_gap_result_section',
                            child: Column(
                              children: [
                                MintEntrance(
                                    delay: const Duration(milliseconds: 200),
                                    child: DisabilityCliffWidget(
                                      grossMonthly: grossMonthly,
                                      acts: _acts(grossMonthly),
                                    )),
                                const SizedBox(height: 20),
                                MintEntrance(
                                    delay: const Duration(milliseconds: 300),
                                    child: DisabilityCountdownWidget(
                                      monthlyExpenses: grossMonthly *
                                          DisabilityInsuranceCalculator
                                              .emergencyReserveChargeRatio,
                                      initialSavings: savings,
                                      allowSavingsAdjustment: false,
                                    )),
                                const SizedBox(height: 20),
                                if (age >= 35 && lppCapitalBefore > 0) ...[
                                  DisabilityResetWidget(
                                    currentAge: age,
                                    currentSalary: grossMonthly *
                                        DisabilityInsuranceCalculator
                                            .monthsPerYear,
                                    reducedSalary: grossMonthly *
                                        DisabilityInsuranceCalculator
                                            .monthsPerYear *
                                        DisabilityInsuranceCalculator
                                            .reducedEarningCapacityRate,
                                    capitalBefore: lppCapitalBefore,
                                    capitalAfter: lppCapitalAfter,
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                MintEntrance(
                                    delay: const Duration(milliseconds: 400),
                                    child: DisabilityScorecardWidget(
                                      items: _scorecardItems(
                                        grossMonthly: grossMonthly,
                                        savings: savings,
                                      ),
                                      overallGrade: _overallGrade(
                                        grossMonthly: grossMonthly,
                                        savings: savings,
                                      ),
                                      lifeDropPercent:
                                          _lifeDropPercent(grossMonthly),
                                    )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // ── Related sections (hub) ──
                        MintEntrance(
                            delay: const Duration(milliseconds: 500),
                            child: _buildRelatedSections()),
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
              ))),
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
                    style: MintTextStyles.bodySmall(color: MintColors.white70)
                        .copyWith(
                            fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                  Text(
                    S.of(context)!.disabilityStatLine2,
                    style: MintTextStyles.titleLarge(color: MintColors.white)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      title: Text(
        S.of(context)!.disabilityAppBarTitle,
        style: MintTextStyles.titleMedium(color: MintColors.white)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildLedgerFactsCard(
    BuildContext context,
    S s, {
    required double? grossMonthly,
    required int? age,
    required double? savings,
  }) {
    final missingSalary = grossMonthly == null;
    final missingAge = age == null;
    final missingSavings = savings == null;
    final hasMissing = missingSalary || missingAge || missingSavings;
    final missingFactRoute = missingSalary
        ? '/data-block/revenu?inputKey=q_gross_salary_annual'
        : missingAge
            ? '/data-block/revenu?inputKey=q_birth_year'
            : '/data-block/patrimoine?inputKey=q_cash_total';
    final route = hasMissing
        ? missingFactRoute
        : '/data-block/revenu?inputKey=q_gross_salary_annual';

    return Semantics(
      key: const Key('disability_gap_ledger_facts'),
      identifier: 'disability_gap_ledger_facts',
      container: true,
      child: MintSurface(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasMissing
                      ? Icons.manage_search_outlined
                      : Icons.check_circle_outline,
                  color: hasMissing ? MintColors.warning : MintColors.success,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasMissing
                        ? s.dataQualityMissingSection
                        : s.dataQualityKnownSection,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  key: const Key('disability_gap_enrich_cta'),
                  onPressed: () => context.push(route),
                  icon: Icon(
                    hasMissing ? Icons.add_circle_outline : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: Text(hasMissing ? s.dataQualityEnrich : s.commonEdit),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFactRow(
              key: const Key('disability_gap_salary_fact'),
              identifier: 'disability_gap_salary_fact',
              label: s.disabilityGrossMonthly,
              value: grossMonthly == null
                  ? s.dataBlockStatusMissing
                  : 'CHF ${_fmtChf(grossMonthly)}',
              missing: missingSalary,
            ),
            const SizedBox(height: 12),
            _buildFactRow(
              key: const Key('disability_gap_age_fact'),
              identifier: 'disability_gap_age_fact',
              label: s.disabilityYourAge,
              value: age == null
                  ? s.dataBlockStatusMissing
                  : s.disabilityGapAgeLabel(age),
              missing: missingAge,
            ),
            const SizedBox(height: 12),
            _buildFactRow(
              key: const Key('disability_gap_savings_fact'),
              identifier: 'disability_gap_savings_fact',
              label: s.disabilityAvailableSavings,
              value: savings == null
                  ? s.dataBlockStatusMissing
                  : 'CHF ${_fmtChf(savings)}',
              missing: missingSavings,
            ),
            const SizedBox(height: 16),
            _buildToggleRow(
              label: s.disabilityHasIjm,
              value: _hasIjm,
              onChanged: (v) {
                _hasUserInteracted = true;
                setState(() => _hasIjm = v);
                if (grossMonthly != null) _emitScreenReturn(grossMonthly);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactRow({
    required Key key,
    required String identifier,
    required String label,
    required String value,
    required bool missing,
  }) {
    return Semantics(
      key: key,
      identifier: identifier,
      label: '$label, $value',
      container: true,
      child: Row(
        children: [
          Icon(
            missing ? Icons.help_outline : Icons.check_circle_outline,
            color: missing ? MintColors.warning : MintColors.success,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: MintTextStyles.bodySmall(
              color: missing ? MintColors.warning : MintColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: MintColors.primary,
        ),
      ],
    );
  }

  Widget _buildRelatedSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.of(context)!.disabilityExploreAlso,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        CollapsibleSection(
          title: S.of(context)!.disabilityCoverageInsurance,
          subtitle: S.of(context)!.disabilityCoverageSubtitle,
          icon: Icons.shield_outlined,
          child: _buildSectionCta(
              S.of(context)!.disabilityCtaEvaluate, '/disability/insurance'),
        ),
        CollapsibleSection(
          title: S.of(context)!.disabilitySelfEmployed,
          subtitle: S.of(context)!.disabilitySelfEmployedSubtitle,
          icon: Icons.rocket_launch,
          child: _buildSectionCta(
              S.of(context)!.disabilityCtaAnalyze, '/disability/self-employed'),
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
}
