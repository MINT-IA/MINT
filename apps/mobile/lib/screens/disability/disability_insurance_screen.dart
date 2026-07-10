import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/disability_insurance_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/disability_scorecard_widget.dart';
import 'package:mint_mobile/widgets/coach/franchise_cost_widget.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  P4 — COUVERTURE INVALIDITÉ
//  Bulletin scolaire (E) + Franchise LAMal (D)
//  Source : LAMal art. 64-64a, LAVS, LPP art. 23-26
// ────────────────────────────────────────────────────────────

class DisabilityInsuranceScreen extends StatefulWidget {
  const DisabilityInsuranceScreen({super.key});

  @override
  State<DisabilityInsuranceScreen> createState() =>
      _DisabilityInsuranceScreenState();
}

class _DisabilityInsuranceScreenState extends State<DisabilityInsuranceScreen> {
  bool _hasIjm = false;
  bool _hasPrivateInsurance = false;

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

  double? _liquidSavings(CoachProfile? profile) {
    if (profile == null ||
        !profile.userProvidedFields.contains('liquidSavings')) {
      return null;
    }
    final savings = profile.patrimoine.epargneLiquide;
    // A user-provided zero balance is still a real fact: unlock the result.
    if (savings < 0) return null;
    return savings.toDouble();
  }

  double? _monthlyExpenses(CoachProfile? profile) {
    if (profile == null ||
        !profile.userProvidedFields.contains('monthlyExpenses')) {
      return null;
    }
    final expenses = profile.depenses.totalMensuel;
    if (expenses <= 0) return null;
    return expenses.toDouble();
  }

  // ── Scorecard items ───────────────────────────────────────

  List<CoverageItem> _scorecardItems({
    required double grossMonthly,
    required double savings,
    required double monthlyExpenses,
  }) {
    final s = S.of(context)!;
    final hasLpp = DisabilityInsuranceCalculator.hasLppInvalidityCoverage(
      grossMonthlySalary: grossMonthly,
    );

    // IJM
    final ijmGrade = _hasIjm ? 'B+' : (_hasPrivateInsurance ? 'B' : 'F');
    final ijmDetail = _hasIjm
        ? s.disabilityGapIjmCoverage
        : _hasPrivateInsurance
            ? s.disabilityInsPrivateLossInsurance
            : s.disabilityGapNoIjmCoverage;

    // AI
    const aiGrade = 'C';

    // LPP
    final lppGrade = hasLpp ? 'A-' : 'D';
    final lppDetail =
        hasLpp ? s.disabilityGapLppCovered : s.disabilityGapLppNotCovered;

    // Épargne
    final monthsReserve =
        DisabilityInsuranceCalculator.emergencyReserveMonthsFromExpenses(
      monthlyExpenses: monthlyExpenses,
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
    final savingsDetail =
        s.disabilityGapSavingsDetail(monthsReserve.toStringAsFixed(1));

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
        detail: savingsDetail,
        emoji: '💰',
      ),
    ];
  }

  String _overallGrade({
    required double grossMonthly,
    required double savings,
    required double monthlyExpenses,
  }) {
    int score = 0;
    if (_hasIjm || _hasPrivateInsurance) score += 3;
    if (DisabilityInsuranceCalculator.hasLppInvalidityCoverage(
      grossMonthlySalary: grossMonthly,
    )) {
      score += 2;
    }
    final monthsReserve =
        DisabilityInsuranceCalculator.emergencyReserveMonthsFromExpenses(
      monthlyExpenses: monthlyExpenses,
      liquidSavings: savings,
    );
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

  // ── Franchise options ─────────────────────────────────────

  static const List<FranchiseOption> _franchiseOptions = [
    FranchiseOption(franchiseAmount: 300, monthlyPremiumSavings: 0),
    FranchiseOption(franchiseAmount: 500, monthlyPremiumSavings: 10),
    FranchiseOption(franchiseAmount: 1000, monthlyPremiumSavings: 25),
    FranchiseOption(franchiseAmount: 1500, monthlyPremiumSavings: 40),
    FranchiseOption(franchiseAmount: 2000, monthlyPremiumSavings: 60),
    FranchiseOption(franchiseAmount: 2500, monthlyPremiumSavings: 80),
  ];

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
    final savings = _liquidSavings(profile);
    final monthlyExpenses = _monthlyExpenses(profile);
    final hasRequiredFacts =
        grossMonthly != null && savings != null && monthlyExpenses != null;

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
                        _buildLedgerFactsCard(
                          context,
                          S.of(context)!,
                          grossMonthly: grossMonthly,
                          savings: savings,
                          monthlyExpenses: monthlyExpenses,
                        ),
                        const SizedBox(height: 20),
                        if (hasRequiredFacts) ...[
                          Semantics(
                            key: const Key(
                                'disability_insurance_result_section'),
                            identifier: 'disability_insurance_result_section',
                            child: DisabilityScorecardWidget(
                              items: _scorecardItems(
                                grossMonthly: grossMonthly,
                                savings: savings,
                                monthlyExpenses: monthlyExpenses,
                              ),
                              overallGrade: _overallGrade(
                                grossMonthly: grossMonthly,
                                savings: savings,
                                monthlyExpenses: monthlyExpenses,
                              ),
                              lifeDropPercent: _lifeDropPercent(grossMonthly),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        const FranchiseCostWidget(
                          options: _franchiseOptions,
                          initialConsultationsPerYear: 3,
                        ),
                        const SizedBox(height: 20),
                        EduDisclaimer(
                          text: S.of(context)!.disabilityInsDisclaimer,
                        ),
                        const SizedBox(height: 8),
                        EduLegalSources(
                          sources: S.of(context)!.disabilityInsSources,
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
              colors: [MintColors.blueDark, MintColors.blueMaterial900],
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
                    S.of(context)!.disabilityInsTitle,
                    style:
                        MintTextStyles.headlineMedium(color: MintColors.white)
                            .copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    S.of(context)!.disabilityInsSubtitle,
                    style: MintTextStyles.labelSmall(color: MintColors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      title: Semantics(
        header: true,
        child: Text(
          S.of(context)!.disabilityInsAppBarTitle,
          style: MintTextStyles.titleMedium(color: MintColors.white)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildLedgerFactsCard(
    BuildContext context,
    S s, {
    required double? grossMonthly,
    required double? savings,
    required double? monthlyExpenses,
  }) {
    final missingSalary = grossMonthly == null;
    final missingSavings = savings == null;
    final missingExpenses = monthlyExpenses == null;
    final hasMissing = missingSalary || missingSavings || missingExpenses;
    final route = missingSalary
        ? '/data-block/revenu?inputKey=q_gross_salary_annual'
        : missingSavings
            ? '/data-block/patrimoine?inputKey=q_cash_total'
            : missingExpenses
                ? '/budget/setup'
                : '/data-block/revenu?inputKey=q_gross_salary_annual';

    return Semantics(
      key: const Key('disability_insurance_ledger_facts'),
      identifier: 'disability_insurance_ledger_facts',
      container: true,
      child: MintSurface(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MintEntrance(
                child: Row(
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
                  key: const Key('disability_insurance_enrich_cta'),
                  onPressed: () => context.push(route),
                  icon: Icon(
                    hasMissing ? Icons.add_circle_outline : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: Text(hasMissing ? s.dataQualityEnrich : s.commonEdit),
                ),
              ],
            )),
            const SizedBox(height: 16),
            MintEntrance(
                delay: const Duration(milliseconds: 100),
                child: _buildFactRow(
                  key: const Key('disability_insurance_salary_fact'),
                  identifier: 'disability_insurance_salary_fact',
                  label: s.disabilityInsGrossSalary,
                  value: grossMonthly == null
                      ? s.dataBlockStatusMissing
                      : 'CHF ${_fmtChf(grossMonthly)}',
                  missing: missingSalary,
                )),
            const SizedBox(height: 12),
            MintEntrance(
                delay: const Duration(milliseconds: 200),
                child: _buildFactRow(
                  key: const Key('disability_insurance_savings_fact'),
                  identifier: 'disability_insurance_savings_fact',
                  label: s.disabilityInsSavings,
                  value: savings == null
                      ? s.dataBlockStatusMissing
                      : 'CHF ${_fmtChf(savings)}',
                  missing: missingSavings,
                )),
            const SizedBox(height: 16),
            MintEntrance(
                delay: const Duration(milliseconds: 300),
                child: _buildFactRow(
                  key: const Key('disability_insurance_expenses_fact'),
                  identifier: 'disability_insurance_expenses_fact',
                  label: s.emergencyFundChargesLabel,
                  value: monthlyExpenses == null
                      ? s.dataBlockStatusMissing
                      : 'CHF ${_fmtChf(monthlyExpenses)}',
                  missing: missingExpenses,
                )),
            const SizedBox(height: 16),
            MintEntrance(
                delay: const Duration(milliseconds: 400),
                child: _buildToggleRow(
                  label: S.of(context)!.disabilityInsIjmEmployer,
                  value: _hasIjm,
                  onChanged: (v) => setState(() => _hasIjm = v),
                )),
            const SizedBox(height: 8),
            MintEntrance(
                delay: const Duration(milliseconds: 500),
                child: _buildToggleRow(
                  label: S.of(context)!.disabilityInsPrivateLossInsurance,
                  value: _hasPrivateInsurance,
                  onChanged: (v) => setState(() => _hasPrivateInsurance = v),
                )),
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
          child: Text(label,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: MintColors.primary,
        ),
      ],
    );
  }
}
