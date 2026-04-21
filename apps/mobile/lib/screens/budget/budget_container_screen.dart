import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/screens/budget/budget_screen.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

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
      appBar: AppBar(title: Text(S.of(context)!.budgetTitle)),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MintEntrance(child: ExcludeSemantics(child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    size: 48, color: MintColors.primary),
              ))),
              const SizedBox(height: 24),
              MintEntrance(delay: const Duration(milliseconds: 100), child: Text(
                S.of(context)!.budgetCardEmptyTitle,
                textAlign: TextAlign.center,
                style: MintTextStyles.titleLarge(),
              )),
              const SizedBox(height: MintSpacing.md),
              MintEntrance(delay: const Duration(milliseconds: 200), child: Text(
                S.of(context)!.budgetCardEmptyBody,
                textAlign: TextAlign.center,
                style: MintTextStyles.bodyMedium(),
              )),
              const SizedBox(height: 32),
              Semantics(
                button: true,
                label: S.of(context)!.semanticsBudgetStartButton,
                child: FilledButton.icon(
                  onPressed: () => context.push('/budget/setup'),
                  icon: const Icon(Icons.edit_note),
                  label: Text(S.of(context)!.budgetCardEmptyAction),
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ))),
    );
  }
}
