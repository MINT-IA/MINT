import 'package:flutter/material.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/screens/budget/budget_screen.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:provider/provider.dart';

class BudgetContainerScreen extends StatelessWidget {
  const BudgetContainerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dans une vraie app, on utiliserait le BudgetProvider pour récupérer l'état persistant
    // Pour l'instant, on check si des inputs existent
    final inputs = context.watch<BudgetProvider>().inputs;

    if (inputs == null) {
      return _buildEmptyState(context);
    }

    return BudgetScreen(inputs: inputs);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 64, color: MintColors.textMuted),
              const SizedBox(height: 24),
              const Text(
                'Ton Budget n\'est pas encore configuré',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Définis tes revenus et charges pour débloquer ton plan mensuel.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MintColors.textSecondary),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {
                  // Redirige vers le wizard partie Budget (ou ouvre un modal de config rapide)
                  // Pour l'instant, on renvoie vers le Wizard global
                  // TODO: Créer un deep link direct vers la section Budget du Wizard
                  context.read<BudgetProvider>().setInputs(BudgetInputs(
                      netIncome: 6000,
                      housingCost: 2000,
                      debtPayments: 0,
                      payFrequency: PayFrequency.monthly,
                      style: BudgetStyle
                          .envelopes3)); // Mock init pour débloquer UX immédiatement pour le test
                },
                child: const Text('Configurer mon Budget'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
