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
import 'package:mint_mobile/services/financial_core/disability_calculator.dart';
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
  bool _hasIjm = true;
  String? _lastScreenReturnSignature;

  _DisabilityLedgerFacts _ledgerFacts(CoachProfileProvider provider) {
    final profile = provider.profile;
    if (profile == null) return const _DisabilityLedgerFacts();
    final provided = profile.userProvidedFields;
    // Zero salary means this employee disability scenario cannot calculate;
    // zero savings is a valid declared fact and must not block the screen.
    final salary = provided.contains('salary') && profile.salaireBrutMensuel > 0
        ? profile.salaireBrutMensuel.clamp(2000.0, 25000.0)
        : null;
    final age = provided.contains('age') && profile.ageOrNull != null
        ? profile.ageOrNull!.clamp(18, 64)
        : null;
    final savings = provided.contains('liquidSavings')
        ? profile.patrimoine.epargneLiquide.clamp(0.0, 500000.0)
        : null;
    return _DisabilityLedgerFacts(
      grossMonthly: salary,
      age: age,
      savings: savings,
    );
  }

  void _emitScreenReturn(_DisabilityLedgerFacts facts) {
    if (!mounted) return;
    if (!facts.isComplete) return;
    ScreenCompletionTracker.markCompletedWithReturn(
      'disability_gap',
      ScreenReturn.completed(
        route: '/invalidite',
        updatedFields: {
          'disabilityGapMensuel':
              DisabilityCalculator.monthlyGapAtAct3(facts.grossMonthly!),
        },
        confidenceDelta: 0.02,
        nextCapSuggestion: 'assurance_invalidite',
      ),
    );
  }

  void _scheduleScreenReturn(_DisabilityLedgerFacts facts) {
    if (!facts.isComplete) return;
    final signature =
        '${facts.grossMonthly}|${facts.age}|${facts.savings}|$_hasIjm';
    if (_lastScreenReturnSignature == signature) return;
    _lastScreenReturnSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emitScreenReturn(facts);
    });
  }

  // ── Calcul des actes (La Falaise) ─────────────────────────

  List<DisabilityAct> _acts(double grossMonthly) {
    // Acte 1 : Employeur — 80% salaire (CO art. 324a, durée variable)
    final act1Income = DisabilityCalculator.employerMonthlyIncome(grossMonthly);

    // Acte 2 : IJM — 80% si souscrite, 0 sinon (24 mois max)
    final act2Income =
        DisabilityCalculator.ijmMonthlyIncome(grossMonthly, hasIjm: _hasIjm);

    // Acte 3 : AI + LPP (définitif)
    // AI max CHF 2'520/mois (LAI art. 28 + LAVS art. 34)
    // LPP invalidité ≈ 40% salaire coordonné (LPP art. 23-24, estimation)
    final act3Income = DisabilityCalculator.act3MonthlyIncome(grossMonthly);
    final lppInvalidity =
        DisabilityCalculator.lppInvalidityMonthly(grossMonthly);

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

  // ── Calcul Bulletin scolaire ─────────────────────────────

  List<CoverageItem> _scorecardItems(double grossMonthly, double savings) {
    final s = S.of(context)!;
    // APG/IJM grade
    final ijmGrade = _hasIjm ? 'B+' : 'F';
    final ijmDetail =
        _hasIjm ? s.disabilityGapIjmCoverage : s.disabilityGapNoIjmCoverage;

    // AI grade (systemic — everyone gets it)
    const aiGrade = 'C';

    // LPP grade
    final hasLpp = DisabilityCalculator.hasLppCoverage(grossMonthly);
    final lppGrade = hasLpp ? 'A-' : 'D';
    final lppDetail =
        hasLpp ? s.disabilityGapLppCovered : s.disabilityGapLppNotCovered;

    // Épargne urgence grade
    final monthsReserve = DisabilityCalculator.monthsReserve(
      savings: savings,
      grossMonthly: grossMonthly,
    );
    final savingsGrade = DisabilityCalculator.savingsReserveGrade(
      monthsReserve,
    );

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

  String _overallGrade(double grossMonthly, double savings) {
    return DisabilityCalculator.overallGrade(
      hasIjm: _hasIjm,
      grossMonthly: grossMonthly,
      savings: savings,
    );
  }

  double _lifeDropPercent(double grossMonthly) {
    return DisabilityCalculator.lifeDropPercent(grossMonthly);
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
    final facts = _ledgerFacts(context.watch<CoachProfileProvider>());
    final lppCapitalBefore = facts.isComplete
        ? DisabilityCalculator.lppCapitalBeforeDisability(
            grossMonthly: facts.grossMonthly!,
            age: facts.age!,
          )
        : 0.0;
    final lppCapitalAfter = facts.isComplete
        ? DisabilityCalculator.lppCapitalAfterDisability(
            grossMonthly: facts.grossMonthly!,
            age: facts.age!,
          )
        : 0.0;
    _scheduleScreenReturn(facts);

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
                              context, S.of(context)!, facts),
                        ),
                        if (facts.isComplete) ...[
                          const SizedBox(height: 20),
                          MintEntrance(
                              delay: const Duration(milliseconds: 200),
                              child: DisabilityCliffWidget(
                                grossMonthly: facts.grossMonthly!,
                                acts: _acts(facts.grossMonthly!),
                              )),
                          const SizedBox(height: 20),
                          MintEntrance(
                              delay: const Duration(milliseconds: 300),
                              child: DisabilityCountdownWidget(
                                monthlyExpenses:
                                    DisabilityCalculator.monthlyExpensesProxy(
                                  facts.grossMonthly!,
                                ),
                                initialSavings: facts.savings!,
                              )),
                          const SizedBox(height: 20),
                          if (facts.age! >= 35 && lppCapitalBefore > 0) ...[
                            DisabilityResetWidget(
                              currentAge: facts.age!,
                              currentSalary: DisabilityCalculator.annualGross(
                                facts.grossMonthly!,
                              ),
                              reducedSalary:
                                  DisabilityCalculator.reducedAnnualSalary(
                                facts.grossMonthly!,
                              ),
                              capitalBefore: lppCapitalBefore,
                              capitalAfter: lppCapitalAfter,
                            ),
                            const SizedBox(height: 20),
                          ],
                          MintEntrance(
                              delay: const Duration(milliseconds: 400),
                              child: DisabilityScorecardWidget(
                                items: _scorecardItems(
                                  facts.grossMonthly!,
                                  facts.savings!,
                                ),
                                overallGrade: _overallGrade(
                                  facts.grossMonthly!,
                                  facts.savings!,
                                ),
                                lifeDropPercent:
                                    _lifeDropPercent(facts.grossMonthly!),
                              )),
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
    S s,
    _DisabilityLedgerFacts facts,
  ) {
    final route = facts.missingRoute;
    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            key: const Key('disability_gap_ledger_facts'),
            identifier: 'disability_gap_ledger_facts',
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
                    key: const Key('disability_gap_enrich_profile_cta'),
                    onPressed: () => context.push(route),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: Text(s.dataQualityEnrich),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildFactRow(
            identifier: 'disability_gap_income_fact',
            label: s.disabilityGrossMonthly,
            value: facts.grossMonthly == null
                ? s.dataBlockStatusMissing
                : 'CHF ${_fmtChf(facts.grossMonthly!)}',
            isMissing: facts.grossMonthly == null,
          ),
          const SizedBox(height: 8),
          _buildFactRow(
            identifier: 'disability_gap_age_fact',
            label: s.disabilityYourAge,
            value: facts.age == null
                ? s.dataBlockStatusMissing
                : s.disabilityGapAgeLabel(facts.age!),
            isMissing: facts.age == null,
          ),
          const SizedBox(height: 8),
          _buildFactRow(
            identifier: 'disability_gap_savings_fact',
            label: s.disabilityAvailableSavings,
            value: facts.savings == null
                ? s.dataBlockStatusMissing
                : 'CHF ${_fmtChf(facts.savings!)}',
            isMissing: facts.savings == null,
          ),
          if (facts.isComplete) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    s.disabilityHasIjm,
                    style:
                        MintTextStyles.bodySmall(color: MintColors.textPrimary),
                  ),
                ),
                Switch(
                  value: _hasIjm,
                  onChanged: (v) {
                    setState(() => _hasIjm = v);
                  },
                  activeTrackColor: MintColors.primary,
                ),
              ],
            ),
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

class _DisabilityLedgerFacts {
  const _DisabilityLedgerFacts({
    this.grossMonthly,
    this.age,
    this.savings,
  });

  final double? grossMonthly;
  final int? age;
  final double? savings;

  bool get isComplete => grossMonthly != null && age != null && savings != null;

  String? get missingRoute {
    if (grossMonthly == null) {
      return '/data-block/revenu?inputKey=q_gross_salary_annual';
    }
    if (age == null) {
      return '/data-block/revenu?inputKey=q_birth_year';
    }
    if (savings == null) {
      return '/data-block/patrimoine?inputKey=q_cash_total';
    }
    return null;
  }
}
