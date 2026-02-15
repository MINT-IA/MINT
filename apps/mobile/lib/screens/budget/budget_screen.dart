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

class BudgetScreen extends StatefulWidget {
  final BudgetInputs inputs;

  const BudgetScreen({
    super.key,
    required this.inputs,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  @override
  void initState() {
    super.initState();
    // Au chargement, on initialise le provider avec les inputs passés
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetProvider>().setInputs(widget.inputs);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Budget Mensuel'), // TODO: Adapter le titre selon paid frequency
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
                _buildHeader(plan),
                const SizedBox(height: 24),
                SpendingMeter(
                  variablesAmount: plan.variables,
                  futureAmount: plan.future,
                  totalAvailable: plan.available,
                ),
                const SizedBox(height: 32),
                if (widget.inputs.style == BudgetStyle.envelopes3) ...[
                  _buildSliders(context, provider, plan),
                  const SizedBox(height: 24),
                ],
                if (plan.stopRuleTriggered) ...[
                  const StopRuleCallout(),
                  const SizedBox(height: 24),
                ],
                if (plan.emergencyFundMonths > 0 ||
                    widget.inputs.emergencyFundMonths > 0)
                  _buildEmergencyFundCard(plan),
                const SizedBox(height: 24),
                _buildDisclaimers(context),
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
          "Disponible cette période",
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Text(
          "CHF ${plan.available.toStringAsFixed(0)}",
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
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
          activeColor: Colors.indigo.shade300,
          onChanged: (val) {
            provider.updateOverride('future', val);
          },
        ),
        const SizedBox(height: 16),
        EnvelopeSlider(
          label: "🛍️ Variables (Vivre)",
          value: plan.variables,
          max: plan.available,
          activeColor: Colors.tealAccent.shade400,
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
    final progress = plan.emergencyFundProgress;
    final isComplete = months >= target;

    final progressColor = isComplete
        ? const Color(0xFF34C759)
        : months >= 3
            ? const Color(0xFFFF9500)
            : const Color(0xFFFF3B30);

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
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
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
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: MintColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${months.toStringAsFixed(1)} mois couverts',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                'Cible : ${target.toStringAsFixed(0)} mois',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
    );
  }

  Widget _buildDisclaimers(BuildContext context) {
    final style =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey);
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
