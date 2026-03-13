import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/budget/spending_meter.dart';
import 'package:mint_mobile/widgets/budget/envelope_slider.dart';
import 'package:mint_mobile/widgets/budget/stop_rule_callout.dart';
import 'package:mint_mobile/widgets/budget/emergency_fund_ring.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/coach/budget_sandwich_chart.dart';
import 'package:mint_mobile/widgets/coach/budget_503020_widget.dart';
import 'package:mint_mobile/widgets/coach/crash_test_budget_widget.dart';

class BudgetScreen extends StatefulWidget {
  final BudgetInputs inputs;

  const BudgetScreen({
    super.key,
    required this.inputs,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  late Animation<double> _staggerAnimation;

  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('budget');
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _staggerAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: Curves.easeOutCubic,
    );
    // Au chargement, on initialise le provider avec les inputs passés
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetProvider>().setInputs(widget.inputs);
      _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  /// Staggered entry: returns opacity and slide offset for card at [index].
  /// Total slots: 5 (header, donut, sliders, emergency, disclaimers).
  Widget _staggeredEntry({required int index, required Widget child}) {
    const totalSlots = 5;
    return AnimatedBuilder(
      animation: _staggerAnimation,
      builder: (context, _) {
        final cardProgress =
            ((_staggerAnimation.value * totalSlots) - index).clamp(0.0, 1.0);
        return Opacity(
          opacity: cardProgress,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - cardProgress)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context)!.budgetMonthlyTitle),
      ),
      body: Consumer<BudgetProvider>(
        builder: (context, provider, child) {
          final plan = provider.plan;

          if (plan == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _staggeredEntry(
                  index: 0,
                  child: _buildDataQualityBanner(widget.inputs),
                ),
                const SizedBox(height: 12),
                _staggeredEntry(index: 0, child: _buildHeader(plan)),
                const SizedBox(height: 24),
                _staggeredEntry(
                  index: 1,
                  child: SpendingMeter(
                    variablesAmount: plan.variables,
                    futureAmount: plan.future,
                    totalAvailable: plan.available,
                  ),
                ),
                const SizedBox(height: 32),
                if (widget.inputs.style == BudgetStyle.envelopes3) ...[
                  _staggeredEntry(
                    index: 2,
                    child: _buildSliders(context, provider, plan),
                  ),
                  const SizedBox(height: 24),
                ],
                if (plan.stopRuleTriggered) ...[
                  _staggeredEntry(
                    index: 2,
                    child: const StopRuleCallout(),
                  ),
                  const SizedBox(height: 24),
                ],
                // ── 50/30/20 Rule ─────────────────────────────────
                _staggeredEntry(
                  index: 3,
                  child: Budget503020Widget(
                    netSalary: widget.inputs.netIncome,
                    chiffreChoc: plan.available > 0
                        ? 'En épargnant CHF ${(plan.available * 0.20).toStringAsFixed(0)}/mois, tu accumules CHF ${(plan.available * 0.20 * 120).toStringAsFixed(0)} en 10 ans.'
                        : null,
                    categories: [
                      BudgetCategory(
                        label: 'Besoins',
                        emoji: '🏠',
                        percent: 50,
                        amount: plan.available * 0.50,
                        examples: const ['Loyer', 'LAMal', 'impôts', 'dettes'],
                      ),
                      BudgetCategory(
                        label: 'Vie',
                        emoji: '🛒',
                        percent: 30,
                        amount: plan.available * 0.30,
                        examples: const ['Alimentation', 'transport', 'loisirs'],
                      ),
                      BudgetCategory(
                        label: 'Futur',
                        emoji: '🌱',
                        percent: 20,
                        amount: plan.available * 0.20,
                        examples: const ['Épargne', '3a', 'projets'],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Sandwich visuel (données réelles) ─────────────
                _staggeredEntry(
                  index: 3,
                  child: BudgetSandwichChart(
                    incomes: [
                      BudgetLineItem(label: 'Revenu net', amount: widget.inputs.netIncome),
                    ],
                    expenses: [
                      if (widget.inputs.housingCost > 0)
                        BudgetLineItem(label: 'Logement', amount: widget.inputs.housingCost),
                      if (widget.inputs.taxProvision > 0)
                        BudgetLineItem(label: 'Provision impôts', amount: widget.inputs.taxProvision),
                      if (widget.inputs.healthInsurance > 0)
                        BudgetLineItem(label: 'LAMal', amount: widget.inputs.healthInsurance),
                      if (widget.inputs.debtPayments > 0)
                        BudgetLineItem(label: 'Dettes', amount: widget.inputs.debtPayments),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (plan.emergencyFundMonths > 0 ||
                    widget.inputs.emergencyFundMonths > 0)
                  _staggeredEntry(
                    index: 3,
                    child: _buildEmergencyFundCard(plan),
                  ),
                const SizedBox(height: 24),

                // ── Crash Test budget ─────────────────────────────
                _staggeredEntry(
                  index: 4,
                  child: CrashTestBudgetWidget(
                    monthlyIncome: widget.inputs.netIncome,
                    survivalIncome: widget.inputs.netIncome * 0.70,
                    reserveMonths: widget.inputs.emergencyFundMonths > 0
                        ? widget.inputs.emergencyFundMonths.toDouble()
                        : null,
                    lines: [
                      if (widget.inputs.housingCost > 0)
                        BudgetLine(
                          label: 'Logement',
                          emoji: '🏠',
                          normalAmount: widget.inputs.housingCost,
                          survivalAmount: widget.inputs.housingCost,
                          status: BudgetLineStatus.locked,
                        ),
                      if (widget.inputs.healthInsurance > 0)
                        BudgetLine(
                          label: 'LAMal',
                          emoji: '🏥',
                          normalAmount: widget.inputs.healthInsurance,
                          survivalAmount: widget.inputs.healthInsurance,
                          status: BudgetLineStatus.locked,
                        ),
                      if (widget.inputs.taxProvision > 0)
                        BudgetLine(
                          label: 'Impôts',
                          emoji: '🧾',
                          normalAmount: widget.inputs.taxProvision,
                          survivalAmount: widget.inputs.taxProvision * 0.80,
                          status: BudgetLineStatus.paused,
                        ),
                      if (widget.inputs.debtPayments > 0)
                        BudgetLine(
                          label: 'Dettes',
                          emoji: '💳',
                          normalAmount: widget.inputs.debtPayments,
                          survivalAmount: widget.inputs.debtPayments,
                          status: BudgetLineStatus.locked,
                        ),
                      BudgetLine(
                        label: 'Variables',
                        emoji: '🛒',
                        normalAmount: plan.variables,
                        survivalAmount: plan.variables * 0.50,
                        status: BudgetLineStatus.cut,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _staggeredEntry(
                  index: 5,
                  child: _buildDisclaimers(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BudgetPlan plan) {
    return Column(
      children: [
        Text(
          "Disponible ce mois",
          style: GoogleFonts.inter(
            fontSize: 14,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: plan.available),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return Text(
              "CHF ${value.toStringAsFixed(0)}",
              style: GoogleFonts.montserrat(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: MintColors.textPrimary,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildBreakdown(),
      ],
    );
  }

  Widget _buildBreakdown() {
    final income = widget.inputs.netIncome;
    final housing = widget.inputs.housingCost;
    final debt = widget.inputs.debtPayments;
    final taxes = widget.inputs.taxProvision;
    final health = widget.inputs.healthInsurance;
    final otherFixed = widget.inputs.otherFixedCosts;
    final available = income - housing - debt - taxes - health - otherFixed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          _breakdownRow('Revenu net', income, isPositive: true),
          if (housing > 0) ...[
            const SizedBox(height: 8),
            _breakdownRow('Logement', housing),
          ],
          if (debt > 0) ...[
            const SizedBox(height: 8),
            _breakdownRow('Remboursement dettes', debt),
          ],
          const SizedBox(height: 8),
          _breakdownRow(
            'Provision impôts${taxes > 0 ? "" : " (non renseigné)"}',
            taxes,
            qualityTag: widget.inputs.isTaxEstimated ? 'estimé' : 'saisi',
          ),
          const SizedBox(height: 8),
          _breakdownRow(
            'Primes maladie (LAMal)${health > 0 ? "" : " (non renseigné)"}',
            health,
            qualityTag: widget.inputs.isHealthEstimated ? 'estimé' : 'saisi',
          ),
          const SizedBox(height: 8),
          _breakdownRow(
            'Autres charges fixes${otherFixed > 0 ? "" : " (non renseigné)"}',
            otherFixed,
            qualityTag:
                widget.inputs.isOtherFixedMissing ? 'manquant' : 'saisi',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _breakdownRow(
            'Disponible',
            available.clamp(0, double.infinity),
            isPositive: true,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, double amount,
      {bool isPositive = false, bool isBold = false, String? qualityTag}) {
    final sign = isPositive ? '' : '– ';
    final displayAmount = isPositive ? amount : amount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: isBold ? MintColors.textPrimary : MintColors.textSecondary,
          ),
        ),
        Row(
          children: [
            if (qualityTag != null && !isBold) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: qualityTag == 'saisi'
                      ? MintColors.success.withValues(alpha: 0.12)
                      : qualityTag == 'estimé'
                          ? MintColors.warning.withValues(alpha: 0.12)
                          : MintColors.textMuted.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  qualityTag,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: qualityTag == 'saisi'
                        ? MintColors.success
                        : qualityTag == 'estimé'
                            ? MintColors.warning
                            : MintColors.textSecondary,
                  ),
                ),
              ),
            ],
            Text(
              '$sign CHF ${displayAmount.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isBold
                    ? MintColors.primary
                    : isPositive
                        ? MintColors.textPrimary
                        : MintColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataQualityBanner(BudgetInputs inputs) {
    final hasEstimate = inputs.hasEstimatedValues;
    final hasMissing = inputs.hasMissingValues;
    if (!hasEstimate && !hasMissing) {
      return const SizedBox.shrink();
    }
    final message = hasMissing
        ? 'Certaines charges sont encore manquantes. Complète ton diagnostic pour fiabiliser ce budget.'
        : 'Ce budget inclut des estimations (impôts/LAMal). Renseigne tes montants réels pour une projection plus fiable.';
    return GestureDetector(
      onTap: () => context.push('/profile/bilan'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MintColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: MintColors.warning.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: MintColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Compléter mes données →',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MintColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliders(
      BuildContext context, BudgetProvider provider, BudgetPlan plan) {
    return Column(
      children: [
        EnvelopeSlider(
          label: "🔒 Futur (Épargne, Projets)",
          value: plan.future,
          max: plan.available,
          activeColor: MintColors.info,
          onChanged: (val) {
            provider.updateOverride('future', val);
          },
        ),
        const SizedBox(height: 16),
        EnvelopeSlider(
          label: "🛍️ Variables (Vivre)",
          value: plan.variables,
          max: plan.available,
          activeColor: MintColors.success,
          onChanged: (val) {
            provider.updateOverride('variables', val);
          },
        ),
      ],
    );
  }

  Widget _buildEmergencyFundCard(BudgetPlan plan) {
    final months = plan.emergencyFundMonths;
    const target = BudgetPlan.emergencyFundTarget;
    final isComplete = months >= target;

    final progressColor = isComplete
        ? MintColors.success
        : months >= 3
            ? MintColors.warning
            : MintColors.error;

    final statusText = isComplete
        ? 'Objectif atteint'
        : months >= 3
            ? 'En bonne voie'
            : 'A renforcer';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: MintColors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Row(
            children: [
              Icon(
                isComplete ? Icons.shield_rounded : Icons.shield_outlined,
                color: progressColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                "Fonds d'urgence",
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Ring + info row ──
          Row(
            children: [
              // Left: EmergencyFundRing
              EmergencyFundRing(
                months: months,
                target: target,
              ),
              const SizedBox(width: 16),
              // Right: text info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${months.toStringAsFixed(1)} mois couverts',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cible : ${target.toStringAsFixed(0)} mois',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isComplete
                          ? 'Tu es protege contre les imprevu. Continue ainsi.'
                          : 'Epargne au moins ${target.toStringAsFixed(0)} mois de depenses '
                              'pour te proteger contre un imprévu (perte d\'emploi, reparation...).',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimers(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: MintColors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text("IMPORTANT:", style: style?.copyWith(fontWeight: FontWeight.bold)),
        Text(
          "• Ceci est un outil éducatif, ne constitue pas un conseil financier (LSFin).",
          style: style,
        ),
        Text(
          "• Les montants sont basés sur les informations déclarées.",
          style: style,
        ),
        Text(
          "• 'Disponible' = Revenus - Logement - Dettes - Impôts - LAMal - Charges fixes.",
          style: style,
        ),
      ],
    );
  }
}
