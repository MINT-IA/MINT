import 'package:flutter/material.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/screens/budget/budget_screen.dart';

class DebugBudgetBootstrapScreen extends StatefulWidget {
  final double netIncome;
  final double housingCost;
  final double healthInsurance;
  final double taxProvision;
  final double otherFixedCosts;
  final bool renderBudget;

  const DebugBudgetBootstrapScreen({
    super.key,
    required this.netIncome,
    required this.housingCost,
    required this.healthInsurance,
    this.taxProvision = 0,
    this.otherFixedCosts = 0,
    this.renderBudget = false,
  });

  @override
  State<DebugBudgetBootstrapScreen> createState() =>
      _DebugBudgetBootstrapScreenState();
}

class _DebugBudgetBootstrapScreenState
    extends State<DebugBudgetBootstrapScreen> {
  late final Future<BudgetInputs> _result;

  @override
  void initState() {
    super.initState();
    _result = _persistInputs();
  }

  Future<BudgetInputs> _persistInputs() async {
    final inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: widget.netIncome,
      housingCost: widget.housingCost,
      debtPayments: 0,
      taxProvision: widget.taxProvision,
      healthInsurance: widget.healthInsurance,
      otherFixedCosts: widget.otherFixedCosts,
    );
    await BudgetLocalStore().saveInputs(inputs);
    return inputs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<BudgetInputs>(
          future: _result,
          builder: (context, snapshot) {
            final inputs = snapshot.data;
            if (inputs == null) {
              return const Center(
                child: CircularProgressIndicator(
                  key: ValueKey('debug_budget_bootstrap_loading'),
                ),
              );
            }
            if (widget.renderBudget) {
              return BudgetScreen(inputs: inputs);
            }
            final label = [
              'applied',
              'source=budget_inputs',
              'net=${inputs.netIncome.round()}',
              'housing=${inputs.housingCost.round()}',
              'lamal=${inputs.healthInsurance.round()}',
              if (inputs.taxProvision > 0)
                'tax=${inputs.taxProvision.round()}',
              if (inputs.otherFixedCosts > 0)
                'other=${inputs.otherFixedCosts.round()}',
            ].join(' ');

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Semantics(
                key: const ValueKey('e2e_budget_fixture_applied'),
                identifier: 'e2e_budget_fixture_applied',
                label: label,
                container: true,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
