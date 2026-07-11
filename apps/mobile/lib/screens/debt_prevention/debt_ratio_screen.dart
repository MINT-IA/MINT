import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/debt_prevention_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/widgets/premium/mint_count_up.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/common/debt_tools_nav.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:provider/provider.dart';

/// Écran de diagnostic du ratio d'endettement.
///
/// Affiche une gauge visuelle (semi-cercle vert/orange/rouge) avec le ratio,
/// le minimum vital et des recommandations.
/// Base légale : LP art. 93 (minimum vital), LCC.
class DebtRatioScreen extends StatefulWidget {
  const DebtRatioScreen({super.key});

  @override
  State<DebtRatioScreen> createState() => _DebtRatioScreenState();
}

class _DebtRatioScreenState extends State<DebtRatioScreen> {
  String? _seqRunId;
  String? _seqStepId;
  bool _finalReturnEmitted = false;

  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('debt');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readSequenceContext();
    });
  }

  void _readSequenceContext() {
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map<String, dynamic>) {
        _seqRunId = extra['runId'] as String?;
        _seqStepId = extra['stepId'] as String?;
      }
    } catch (_) {
      // Not navigated via GoRouter or no extra — stay Tier B.
    }
  }

  void _emitFinalReturn() {
    if (_finalReturnEmitted) return;
    if (_seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;

    final facts = _factsFromProfile(
        context.read<CoachProfileProvider>().profile, S.of(context)!);
    final result = _resultForFacts(facts);
    if (result == null) {
      final screenReturn = ScreenReturn.abandoned(
        route: '/debt/ratio',
        runId: _seqRunId,
        stepId: _seqStepId,
        eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      ScreenCompletionTracker.markCompletedWithReturn(
        'debt_ratio',
        screenReturn,
      );
      return;
    }
    final screenReturn = ScreenReturn.completed(
      route: '/debt/ratio',
      stepOutputs: {
        'ratio_endettement': result.ratio,
        'marge_mensuelle': result.margeDisponible,
        'revenu_estime': facts.incomeIsEstimated,
        'base_lp': facts.lpBaseCode,
        'supplement_enfant_hypothese': facts.childSupplementAssumption,
        'charges_connues_lp': facts.autresChargesFixes,
      },
      runId: _seqRunId,
      stepId: _seqStepId,
      eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
    );
    ScreenCompletionTracker.markCompletedWithReturn('debt_ratio', screenReturn);
  }

  DebtRatioResult? _resultForFacts(_DebtRatioFacts facts) {
    if (!facts.canCompute) return null;
    return DebtRatioCalculator.calculate(
      revenusMensuels: facts.revenusMensuels!,
      chargesDetteMensuelles: facts.chargesDetteMensuelles!,
      loyer: facts.loyer!,
      autresChargesFixes: facts.autresChargesFixes,
      estCelibataire: facts.estCelibataire!,
      nombreEnfants: facts.nombreEnfants!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<CoachProfileProvider>().profile;
    final facts = _factsFromProfile(profile, S.of(context)!);
    final result = _resultForFacts(facts);

    return PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _emitFinalReturn();
        },
        child: Scaffold(
          backgroundColor: MintColors.white,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: MintColors.white,
                surfaceTintColor: MintColors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
                foregroundColor: MintColors.textPrimary,
                title: Text(
                  S.of(context)!.debtRatioTitle,
                  style: MintTextStyles.titleMedium(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(MintSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    MintEntrance(
                      child: _buildLedgerFactsSection(facts),
                    ),
                    const SizedBox(height: MintSpacing.lg),

                    if (!facts.canCompute) ...[
                      MintEntrance(
                        delay: const Duration(milliseconds: 100),
                        child: _buildMissingFactsSection(facts),
                      ),
                      const SizedBox(height: MintSpacing.lg),
                    ],

                    if (result != null) ...[
                      Semantics(
                        key: const Key('debt_ratio_result_section'),
                        identifier: 'debt_ratio_result_section',
                        container: true,
                        child: Column(
                          children: [
                            MintEntrance(
                              delay: const Duration(milliseconds: 100),
                              child: _buildGaugeSection(result),
                            ),
                            const SizedBox(height: MintSpacing.lg),
                            MintEntrance(
                              delay: const Duration(milliseconds: 200),
                              child: _buildMinimumVitalCard(result),
                            ),
                            const SizedBox(height: MintSpacing.lg),
                            MintEntrance(
                              delay: const Duration(milliseconds: 300),
                              child: _buildRecommandationsSection(result),
                            ),
                            const SizedBox(height: MintSpacing.md),
                            if (result.niveau != DebtRiskLevel.vert) ...[
                              MintEntrance(
                                delay: const Duration(milliseconds: 400),
                                child: _buildRepaymentCta(result),
                              ),
                              const SizedBox(height: MintSpacing.lg),
                            ],
                            if (result.niveau == DebtRiskLevel.rouge) ...[
                              MintEntrance(
                                delay: const Duration(milliseconds: 450),
                                child: _buildAideProfessionnelleSection(),
                              ),
                              const SizedBox(height: MintSpacing.lg),
                            ],
                            _buildDisclaimer(result.disclaimer),
                            const SizedBox(height: MintSpacing.lg),
                          ],
                        ),
                      ),
                    ],

                    if (result == null)
                      MintEntrance(
                        delay: const Duration(milliseconds: 200),
                        child: _buildDisclaimer(
                          S.of(context)!.dataBlockDisclaimer,
                        ),
                      ),
                    if (result == null) const SizedBox(height: MintSpacing.lg),

                    // Navigation croisée dette
                    const DebtToolsNav(currentRoute: '/debt/ratio'),
                    const SizedBox(height: MintSpacing.xxl),
                  ]),
                ),
              ),
            ],
          ),
        ));
  }

  _DebtRatioFacts _factsFromProfile(CoachProfile? profile, S l) {
    if (profile == null) {
      return _DebtRatioFacts.missing(l);
    }
    final provided = profile.userProvidedFields;
    final hasIncome = provided.contains('netIncome') ||
        provided.contains('grossSalaryAnnual') ||
        provided.contains('salary') ||
        provided.contains('selfEmployedNetIncome');
    final income = hasIncome ? profile.toBudgetInputs().netIncome : null;
    final incomeIsDerived = income != null &&
        !provided.contains('netIncome') &&
        !provided.contains('selfEmployedNetIncome');

    final consumerDebtPayments = _consumerDebtPayments(profile);
    final hasConsumerDebtPrincipal =
        (profile.dettes.creditConsommation ?? 0) > 0 ||
            (profile.dettes.leasing ?? 0) > 0 ||
            (profile.dettes.autresDettes ?? 0) > 0;
    final knownNoDebt = provided.contains('hasDebt') &&
        consumerDebtPayments <= 0 &&
        !hasConsumerDebtPrincipal;
    final hasDebtPayments = knownNoDebt ||
        provided.contains('monthlyDebtPayments') ||
        consumerDebtPayments > 0;
    final debtPayments = hasDebtPayments ? consumerDebtPayments : null;

    final hasHousing = provided.contains('housingCost');
    final housing = hasHousing ? profile.depenses.loyer : null;

    final hasCivilStatus = provided.contains('civilStatus');
    final useSingleLpBase =
        hasCivilStatus ? profile.etatCivil != CoachCivilStatus.marie : null;
    final lpBaseCode = hasCivilStatus
        ? (profile.etatCivil == CoachCivilStatus.marie
            ? 'couple_marie'
            : profile.etatCivil == CoachCivilStatus.concubinage
                ? 'individuelle_concubinage'
                : 'individuelle')
        : null;

    final hasChildren = provided.contains('children');
    final children = hasChildren ? profile.nombreEnfants : null;
    final autresChargesFixes = _knownLivingCharges(profile);
    final visibleFacts = <_DebtRatioFact>[
      _DebtRatioFact(
        identifier: 'debt_ratio_income_fact',
        label: l.debtRatioRevenuNet,
        value: income,
        route: '/data-block/revenu?inputKey=q_gross_salary_annual',
        icon: Icons.account_balance_wallet_outlined,
        statusLabel: incomeIsDerived ? l.debtRatioFactEstimated : null,
      ),
      _DebtRatioFact(
        identifier: 'debt_ratio_debt_payments_fact',
        label: l.debtRatioChargesDette,
        value: debtPayments,
        route: '/data-block/patrimoine?inputKey=q_debt_payments_period_chf',
        icon: Icons.credit_card_outlined,
        zeroIsKnown: knownNoDebt,
      ),
      _DebtRatioFact(
        identifier: 'debt_ratio_housing_fact',
        label: l.debtRatioLoyer,
        value: housing,
        route: '/budget/setup?focus=housing',
        icon: Icons.home_outlined,
      ),
      _DebtRatioFact(
        identifier: 'debt_ratio_civil_status_fact',
        label: l.debtRatioSituation,
        valueLabel:
            hasCivilStatus ? _civilStatusLabel(profile.etatCivil, l) : null,
        route: '/data-block/composition_menage?inputKey=q_civil_status',
        icon: Icons.people_alt_outlined,
      ),
      _DebtRatioFact(
        identifier: 'debt_ratio_children_fact',
        label: l.debtRatioEnfants,
        valueLabel: children == null ? null : '$children',
        route: '/data-block/composition_menage?inputKey=q_children',
        icon: Icons.child_care_outlined,
        zeroIsKnown: hasChildren && children == 0,
      ),
    ];
    if (autresChargesFixes > 0) {
      visibleFacts.add(
        _DebtRatioFact(
          identifier: 'debt_ratio_known_charges_fact',
          label: l.debtRatioAutresCharges,
          value: autresChargesFixes,
          icon: Icons.receipt_long_outlined,
          statusLabel: l.debtRatioChargesIncludedInMargin,
        ),
      );
    }

    return _DebtRatioFacts(
      revenusMensuels: income,
      chargesDetteMensuelles: debtPayments,
      loyer: housing,
      autresChargesFixes: autresChargesFixes,
      estCelibataire: useSingleLpBase,
      nombreEnfants: children,
      incomeIsEstimated: incomeIsDerived,
      lpBaseCode: lpBaseCode,
      facts: visibleFacts,
    );
  }

  String _civilStatusLabel(CoachCivilStatus status, S l) {
    return switch (status) {
      CoachCivilStatus.marie => l.debtRatioEnCouple,
      CoachCivilStatus.concubinage => l.debtRatioConcubinage,
      _ => l.debtRatioSeul,
    };
  }

  Widget _buildLedgerFactsSection(_DebtRatioFacts facts) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: facts.facts
          .map(
            (fact) => SizedBox(
              width: 160,
              child: _buildFactCard(fact),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFactCard(_DebtRatioFact fact) {
    final isMissing = fact.isMissing;
    return Semantics(
      key: ValueKey(fact.identifier),
      identifier: fact.identifier,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMissing ? MintColors.warning : MintColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              fact.icon,
              color: isMissing ? MintColors.warning : MintColors.primary,
              size: 18,
            ),
            const SizedBox(height: 10),
            Text(
              fact.label,
              style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              isMissing
                  ? S.of(context)!.dataBlockStatusMissing
                  : fact.displayValue,
              style: MintTextStyles.bodyMedium(
                color: isMissing ? MintColors.warning : MintColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            if (!isMissing && fact.statusLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                fact.statusLabel!,
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMissingFactsSection(_DebtRatioFacts facts) {
    final nextMissing = facts.nextMissing;
    return Semantics(
      key: const Key('debt_ratio_missing_facts'),
      identifier: 'debt_ratio_missing_facts',
      container: true,
      child: MintSurface(
        tone: MintSurfaceTone.peche,
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context)!.dataBlockIncomplete,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: MintSpacing.sm),
            for (final fact in facts.missingFacts)
              Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.xs),
                child: Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 6,
                      color: MintColors.warning,
                    ),
                    const SizedBox(width: MintSpacing.sm),
                    Text(
                      fact.label,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            if (nextMissing != null) ...[
              const SizedBox(height: MintSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('debt_ratio_profile_enrich_cta'),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push(nextMissing.route!);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    S.of(context)!.dataBlockDefaultCta,
                    style: MintTextStyles.titleMedium(color: MintColors.white)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeSection(DebtRatioResult result) {
    final color = switch (result.niveau) {
      DebtRiskLevel.vert => MintColors.success,
      DebtRiskLevel.orange => MintColors.warning,
      DebtRiskLevel.rouge => MintColors.error,
    };

    final label = switch (result.niveau) {
      DebtRiskLevel.vert => S.of(context)!.debtRatioLevelSain,
      DebtRiskLevel.orange => S.of(context)!.debtRatioLevelAttention,
      DebtRiskLevel.rouge => S.of(context)!.debtRatioLevelCritique,
    };

    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      elevated: true,
      child: Column(
        children: [
          // Semi-circle gauge
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: const Size(200, 150),
              painter: _GaugePainter(
                ratio: result.ratio,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          MintCountUp(
            value: result.ratio,
            suffix: '\u00a0%',
            decimals: 1,
            color: color,
            showLigne: false,
            contextText: S.of(context)!.debtRatioSubLabel,
            semanticsLabel: '${result.ratio.toStringAsFixed(1)}% — $label',
          ),
          const SizedBox(height: MintSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.sm + 4, vertical: MintSpacing.xs),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: color)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: MintSpacing.md),
          // Legende
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(MintColors.success, '< 15%'),
              const SizedBox(width: MintSpacing.md),
              _buildLegendDot(MintColors.warning, '15-30%'),
              const SizedBox(width: MintSpacing.md),
              _buildLegendDot(MintColors.error, '> 30%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: MintSpacing.xs),
        Text(
          label,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildMinimumVitalCard(DebtRatioResult result) {
    final isMenace = result.minimumVitalMenace;

    return MintSurface(
      tone: isMenace ? MintSurfaceTone.peche : MintSurfaceTone.blanc,
      elevated: isMenace,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.debtRatioMinVital,
            style: MintTextStyles.bodySmall(
              color: isMenace ? MintColors.redMedium : MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            S.of(context)!.debtRatioMinimumVitalLabel,
            'CHF ${formatChf(result.minimumVital)} / mois',
          ),
          const Divider(height: 20),
          _buildInfoRow(
            S.of(context)!.debtRatioMargeDisponible,
            'CHF ${formatChf(result.margeDisponible)} / mois',
            color: result.margeDisponible > result.minimumVital
                ? MintColors.success
                : MintColors.error,
            isBold: true,
          ),
          if (isMenace) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.redBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: MintColors.redMedium, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.of(context)!.debtRatioMinVitalWarning,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MintColors.redDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? MintTextStyles.bodySmall(color: MintColors.textPrimary)
                : MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          Text(
            value,
            style:
                MintTextStyles.bodySmall(color: color ?? MintColors.textPrimary)
                    .copyWith(
                        fontWeight: isBold ? FontWeight.bold : FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommandationsSection(DebtRatioResult result) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.debtRatioRecommandations,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          for (final reco in result.recommandations)
            Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_forward,
                      color: MintColors.primary, size: 16),
                  const SizedBox(width: MintSpacing.sm + 2),
                  Expanded(
                    child: Text(
                      reco,
                      style: MintTextStyles.bodySmall(
                          color: MintColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRepaymentCta(DebtRatioResult result) {
    final isRouge = result.niveau == DebtRiskLevel.rouge;
    final color = isRouge ? MintColors.error : MintColors.warning;
    final bgColor = isRouge ? MintColors.urgentBg : MintColors.warningBg;

    return Semantics(
      label: S.of(context)!.debtRatioCtaSemantics,
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/debt/repayment');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.trending_down, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRouge
                          ? S.of(context)!.debtRatioCtaRouge
                          : S.of(context)!.debtRatioCtaOrange,
                      style: MintTextStyles.bodyMedium(
                        color: isRouge
                            ? MintColors.redDark
                            : MintColors.deepOrange,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      S.of(context)!.debtRatioCtaDescription,
                      style: TextStyle(
                        fontSize: 12,
                        color: isRouge
                            ? MintColors.redDark
                            : MintColors.deepOrange,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAideProfessionnelleSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MintColors.urgentBg, MintColors.warningBg],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.redBg, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent,
                  color: MintColors.redMedium, size: 24),
              const SizedBox(width: 12),
              Text(
                S.of(context)!.debtRatioAidePro,
                style: MintTextStyles.bodyMedium(color: MintColors.redDark)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dettes Conseils
          _buildResourceLink(
            nom: S.of(context)!.debtRatioDetteConseilNom,
            description: S.of(context)!.debtRatioDetteConseilDesc,
            url: 'https://www.dettes.ch',
            telephone: '0800 40 40 40',
          ),
          const SizedBox(height: 12),

          // Caritas
          _buildResourceLink(
            nom: S.of(context)!.debtRatioCaritasNom,
            description: S.of(context)!.debtRatioCaritasDesc,
            url: 'https://www.caritas.ch/dettes',
            telephone: '0800 708 708',
          ),
        ],
      ),
    );
  }

  Widget _buildResourceLink({
    required String nom,
    required String description,
    required String url,
    String? telephone,
  }) {
    return Semantics(
      label: nom,
      button: true,
      child: InkWell(
        onTap: () => _launchUrl(url),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: MintTextStyles.bodyMedium(
                              color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: MintTextStyles.labelSmall(
                          color: MintColors.textSecondary),
                    ),
                    if (telephone != null) ...[
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        telephone,
                        style: MintTextStyles.labelSmall(color: MintColors.info)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.open_in_new,
                  color: MintColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              disclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  double _knownLivingCharges(CoachProfile profile) {
    final depenses = profile.depenses;
    final provided = profile.userProvidedFields;
    var total = 0.0;
    if (provided.contains('monthlyExpenses')) {
      total += depenses.assuranceMaladie;
    }
    total += depenses.transport ?? 0;
    total += depenses.fraisMedicaux ?? 0;
    // Electricity, telecom and ordinary household expenses are covered by the
    // LP basic amount; adding them again would understate the residual margin.
    // depenses.autresDepensesFixes is intentionally excluded here: in the
    // current profile model it can include debt payments and tax provisions,
    // both of which would distort the LP margin if counted again.
    return total;
  }

  double _consumerDebtPayments(CoachProfile profile) {
    final dettes = profile.dettes;
    return (dettes.mensualiteCreditConso ?? 0) +
        (dettes.mensualiteLeasing ?? 0);
  }
}

class _DebtRatioFact {
  final String identifier;
  final String label;
  final double? value;
  final String? valueLabel;
  final String? route;
  final IconData icon;
  final bool zeroIsKnown;
  final String? statusLabel;

  const _DebtRatioFact({
    required this.identifier,
    required this.label,
    required this.icon,
    this.value,
    this.valueLabel,
    this.route,
    this.zeroIsKnown = false,
    this.statusLabel,
  });

  bool get isMissing => value == null && valueLabel == null && !zeroIsKnown;

  String get displayValue {
    if (valueLabel != null) return valueLabel!;
    final amount = value ?? 0;
    return 'CHF\u00a0${formatChf(amount)}';
  }
}

class _DebtRatioFacts {
  final double? revenusMensuels;
  final double? chargesDetteMensuelles;
  final double? loyer;
  final double autresChargesFixes;
  final bool? estCelibataire;
  final int? nombreEnfants;
  final bool incomeIsEstimated;
  final String? lpBaseCode;
  final List<_DebtRatioFact> facts;

  const _DebtRatioFacts({
    required this.revenusMensuels,
    required this.chargesDetteMensuelles,
    required this.loyer,
    required this.autresChargesFixes,
    required this.estCelibataire,
    required this.nombreEnfants,
    required this.incomeIsEstimated,
    required this.lpBaseCode,
    required this.facts,
  });

  factory _DebtRatioFacts.missing(S l) => _DebtRatioFacts(
        revenusMensuels: null,
        chargesDetteMensuelles: null,
        loyer: null,
        autresChargesFixes: 0,
        estCelibataire: null,
        nombreEnfants: null,
        incomeIsEstimated: false,
        lpBaseCode: null,
        facts: [
          _DebtRatioFact(
            identifier: 'debt_ratio_income_fact',
            label: l.debtRatioRevenuNet,
            icon: Icons.account_balance_wallet_outlined,
            route: '/data-block/revenu?inputKey=q_gross_salary_annual',
          ),
          _DebtRatioFact(
            identifier: 'debt_ratio_debt_payments_fact',
            label: l.debtRatioChargesDette,
            icon: Icons.credit_card_outlined,
            route: '/data-block/patrimoine?inputKey=q_debt_payments_period_chf',
          ),
          _DebtRatioFact(
            identifier: 'debt_ratio_housing_fact',
            label: l.debtRatioLoyer,
            icon: Icons.home_outlined,
            route: '/budget/setup?focus=housing',
          ),
          _DebtRatioFact(
            identifier: 'debt_ratio_civil_status_fact',
            label: l.debtRatioSituation,
            icon: Icons.people_alt_outlined,
            route: '/data-block/composition_menage?inputKey=q_civil_status',
          ),
          _DebtRatioFact(
            identifier: 'debt_ratio_children_fact',
            label: l.debtRatioEnfants,
            icon: Icons.child_care_outlined,
            route: '/data-block/composition_menage?inputKey=q_children',
          ),
        ],
      );

  List<_DebtRatioFact> get missingFacts =>
      facts.where((fact) => fact.isMissing).toList(growable: false);

  _DebtRatioFact? get nextMissing =>
      missingFacts.isEmpty ? null : missingFacts.first;

  bool get canCompute =>
      revenusMensuels != null &&
      chargesDetteMensuelles != null &&
      loyer != null &&
      estCelibataire != null &&
      nombreEnfants != null;

  String get childSupplementAssumption =>
      (nombreEnfants ?? 0) > 0 ? 'age_inconnu_supplement_haut_chf_600' : 'none';
}

// ─────────────────────────────────────────────────────────────────────────────
// Gauge Painter (semi-cercle)
// ─────────────────────────────────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  final double ratio;
  final Color color;

  _GaugePainter({required this.ratio, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2.5;

    // Background arc (gray)
    final bgPaint = Paint()
      ..color = MintColors.lightBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      bgPaint,
    );

    // Green zone (0-15%)
    final greenPaint = Paint()
      ..color = MintColors.success.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi * 0.5, // 0-15% = first half
      false,
      greenPaint,
    );

    // Orange zone (15-30%)
    final orangePaint = Paint()
      ..color = MintColors.warning.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi + pi * 0.5,
      pi * 0.25,
      false,
      orangePaint,
    );

    // Red zone (30%+)
    final redPaint = Paint()
      ..color = MintColors.error.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi + pi * 0.75,
      pi * 0.25,
      false,
      redPaint,
    );

    // Needle position (ratio mapped to 0-pi)
    final clampedRatio = ratio.clamp(0.0, 50.0);
    final angle = pi + (clampedRatio / 50.0) * pi;

    // Needle
    final needlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final needleLength = radius - 10;
    final needleEnd = Offset(
      center.dx + needleLength * cos(angle),
      center.dy + needleLength * sin(angle),
    );

    canvas.drawLine(center, needleEnd, needlePaint);

    // Center dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.ratio != ratio || oldDelegate.color != color;
}
