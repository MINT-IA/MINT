import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/onboarding/onboarding_widgets.dart';

class OnboardingStepStress extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onContinue;

  const OnboardingStepStress({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingStepHeader(
            title: l10n?.advisorMiniStep1Title ?? 'Quelle est ta priorite ?',
            subtitle: l10n?.advisorMiniStep1Subtitle ??
                'MINT s\'adapte a ce qui compte pour toi maintenant',
          ),
          const SizedBox(height: 22),
          MintSelectableCard(
            icon: Icons.savings_outlined,
            label: l10n?.advisorMiniStressBudget ?? 'Maitriser mon budget',
            isSelected: selected == 'budget',
            selectedColor: const Color(0xFF10B981),
            onTap: () => onSelected('budget'),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.money_off_outlined,
            label: l10n?.advisorMiniStressDebt ?? 'Reduire mes dettes',
            isSelected: selected == 'debt',
            selectedColor: const Color(0xFFEF4444),
            onTap: () => onSelected('debt'),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.account_balance_outlined,
            label: l10n?.advisorMiniStressTax ?? 'Optimiser mes impots',
            isSelected: selected == 'tax',
            selectedColor: const Color(0xFF6366F1),
            onTap: () => onSelected('tax'),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.beach_access_outlined,
            label: l10n?.advisorMiniStressRetirement ?? 'Securiser ma retraite',
            isSelected: selected == 'pension',
            selectedColor: const Color(0xFF0EA5E9),
            onTap: () => onSelected('pension'),
          ),
          const SizedBox(height: 20),
          OnboardingContinueButton(
            enabled: selected != null,
            label: l10n?.onboardingContinue ?? 'Suivant',
            onPressed: onContinue,
            backgroundColor: MintColors.textPrimary,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
