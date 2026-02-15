import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/screens/budget/budget_screen.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:provider/provider.dart';

class BudgetContainerScreen extends StatelessWidget {
  const BudgetContainerScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    size: 48, color: MintColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Ton budget se construit automatiquement',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Complete ton diagnostic pour debloquer ton plan mensuel '
                'avec tes vrais revenus et charges.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.push('/advisor/wizard'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Faire mon diagnostic'),
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
