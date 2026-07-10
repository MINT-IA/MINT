import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/disability_calculator.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
  bool _hasIjm = true;
  bool _hasPrivateInsurance = false;

  _DisabilityInsuranceLedgerFacts _ledgerFacts(
    CoachProfileProvider provider,
  ) {
    final profile = provider.profile;
    if (profile == null) return const _DisabilityInsuranceLedgerFacts();
    final provided = profile.userProvidedFields;
    // Zero salary means this disability insurance scenario cannot calculate;
    // zero savings is a valid declared fact and must not block the screen.
    final salary = provided.contains('salary') && profile.salaireBrutMensuel > 0
        ? profile.salaireBrutMensuel.clamp(2000.0, 25000.0)
        : null;
    final savings = provided.contains('liquidSavings')
        ? profile.patrimoine.epargneLiquide.clamp(0.0, 500000.0)
        : null;
    return _DisabilityInsuranceLedgerFacts(
      grossMonthly: salary,
      savings: savings,
    );
  }

  // ── Scorecard items ───────────────────────────────────────

  List<CoverageItem> _scorecardItems(
    S s,
    _DisabilityInsuranceLedgerFacts facts,
  ) {
    final hasLpp = DisabilityCalculator.hasLppCoverage(facts.grossMonthly!);

    // IJM
    final ijmGrade = _hasIjm ? 'B+' : (_hasPrivateInsurance ? 'B' : 'F');
    final ijmDetail = _hasIjm
        ? s.disabilityGapIjmCoverage
        : _hasPrivateInsurance
            ? s.disabilityInsPrivateInsuranceDetail
            : s.disabilityGapNoIjmCoverage;

    // AI
    const aiGrade = 'C';

    // LPP
    final lppGrade = hasLpp ? 'A-' : 'D';
    final lppDetail =
        hasLpp ? s.disabilityGapLppCovered : s.disabilityGapLppNotCovered;

    // Épargne
    final monthsReserve = DisabilityCalculator.monthsReserve(
      savings: facts.savings!,
      grossMonthly: facts.grossMonthly!,
    );
    final savingsGrade = DisabilityCalculator.savingsReserveGrade(
      monthsReserve,
    );
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

  String _overallGrade(_DisabilityInsuranceLedgerFacts facts) {
    return DisabilityCalculator.overallGrade(
      hasIjm: _hasIjm,
      hasPrivateInsurance: _hasPrivateInsurance,
      grossMonthly: facts.grossMonthly!,
      savings: facts.savings!,
    );
  }

  double _lifeDropPercent(_DisabilityInsuranceLedgerFacts facts) {
    return DisabilityCalculator.lifeDropPercent(facts.grossMonthly!);
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
    final s = S.of(context)!;
    final facts = _ledgerFacts(context.watch<CoachProfileProvider>());

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
                        _buildLedgerFactsCard(context, s, facts),
                        if (facts.isComplete) ...[
                          const SizedBox(height: 20),
                          DisabilityScorecardWidget(
                            items: _scorecardItems(s, facts),
                            overallGrade: _overallGrade(facts),
                            lifeDropPercent: _lifeDropPercent(facts),
                          ),
                          const SizedBox(height: 20),
                          const FranchiseCostWidget(
                            options: _franchiseOptions,
                            initialConsultationsPerYear: 3,
                          ),
                          const SizedBox(height: 20),
                        ],
                        EduDisclaimer(
                          text: s.disabilityInsDisclaimer,
                        ),
                        const SizedBox(height: 8),
                        EduLegalSources(
                          sources: s.disabilityInsSources,
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
    S s,
    _DisabilityInsuranceLedgerFacts facts,
  ) {
    final route = facts.missingRoute;
    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            key: const Key('disability_insurance_ledger_facts'),
            identifier: 'disability_insurance_ledger_facts',
            container: true,
            explicitChildNodes: true,
            child: Row(
              children: [
                Icon(
                  facts.isComplete
                      ? Icons.check_circle_outline
                      : Icons.manage_search_outlined,
                  color: facts.isComplete
                      ? MintColors.success
                      : MintColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    facts.isComplete
                        ? s.dataQualityKnownSection
                        : s.dataQualityMissingSection,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (route != null)
                  TextButton.icon(
                    key: const Key('disability_insurance_enrich_profile_cta'),
                    onPressed: () => context.push(route),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: Text(s.dataQualityEnrich),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildFactRow(
            identifier: 'disability_insurance_income_fact',
            label: s.disabilityInsGrossSalary,
            value: facts.grossMonthly == null
                ? s.dataBlockStatusMissing
                : 'CHF ${_fmtChf(facts.grossMonthly!)}',
            isMissing: facts.grossMonthly == null,
          ),
          const SizedBox(height: 8),
          _buildFactRow(
            identifier: 'disability_insurance_savings_fact',
            label: s.disabilityInsSavings,
            value: facts.savings == null
                ? s.dataBlockStatusMissing
                : 'CHF ${_fmtChf(facts.savings!)}',
            isMissing: facts.savings == null,
          ),
          if (facts.isComplete) ...[
            const SizedBox(height: 16),
            MintEntrance(
                delay: const Duration(milliseconds: 300),
                child: _buildToggleRow(
                  label: s.disabilityInsIjmEmployer,
                  value: _hasIjm,
                  onChanged: (v) => setState(() => _hasIjm = v),
                )),
            const SizedBox(height: 8),
            MintEntrance(
                delay: const Duration(milliseconds: 400),
                child: _buildToggleRow(
                  label: s.disabilityInsPrivateLossInsurance,
                  value: _hasPrivateInsurance,
                  onChanged: (v) => setState(() => _hasPrivateInsurance = v),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildFactRow({
    required String identifier,
    required String label,
    required String value,
    required bool isMissing,
  }) {
    return Semantics(
      key: Key(identifier),
      identifier: identifier,
      label: '$label, $value',
      container: true,
      child: Row(
        children: [
          Icon(
            isMissing ? Icons.help_outline : Icons.check_circle_outline,
            color: isMissing ? MintColors.warning : MintColors.success,
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
              color: isMissing ? MintColors.warning : MintColors.textPrimary,
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

class _DisabilityInsuranceLedgerFacts {
  const _DisabilityInsuranceLedgerFacts({
    this.grossMonthly,
    this.savings,
  });

  final double? grossMonthly;
  final double? savings;

  bool get isComplete => grossMonthly != null && savings != null;

  String? get missingRoute {
    if (grossMonthly == null) {
      return '/data-block/revenu?inputKey=q_gross_salary_annual';
    }
    if (savings == null) {
      return '/data-block/patrimoine?inputKey=q_cash_total';
    }
    return null;
  }
}
