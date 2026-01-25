import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart'; // Ensure this path is correct alias
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
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
                _buildHeader(provider.plan!),
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
