import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/budget/spending_meter.dart';
import 'package:mint_mobile/widgets/budget/envelope_slider.dart';
import 'package:mint_mobile/widgets/budget/stop_rule_callout.dart';
import 'package:mint_mobile/widgets/budget/emergency_fund_ring.dart';

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
        title: const Text('Budget Mensuel'),
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
                if (plan.emergencyFundMonths > 0 ||
                    widget.inputs.emergencyFundMonths > 0)
                  _staggeredEntry(
                    index: 3,
                    child: _buildEmergencyFundCard(plan),
                  ),
                const SizedBox(height: 24),
                _staggeredEntry(
                  index: 4,
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
          if (taxes > 0) ...[
            const SizedBox(height: 8),
            _breakdownRow('Provision impôts', taxes),
          ],
          if (health > 0) ...[
            const SizedBox(height: 8),
            _breakdownRow('Primes maladie (LAMal)', health),
          ],
          if (otherFixed > 0) ...[
            const SizedBox(height: 8),
            _breakdownRow('Autres charges fixes', otherFixed),
          ],
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
      {bool isPositive = false, bool isBold = false}) {
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
    final target = BudgetPlan.emergencyFundTarget;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
          "• Ceci est une aide à la décision, pas une garantie.",
          style: style,
        ),
        Text(
          "• Les montants sont basés sur les informations déclarées.",
          style: style,
        ),
        Text(
          "• 'Disponible' = Revenus - Logement - Dettes.",
          style: style,
        ),
      ],
    );
  }
}
