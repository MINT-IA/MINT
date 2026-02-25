import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/onboarding/onboarding_widgets.dart';

class OnboardingStepGoal extends StatelessWidget {
  final String? selectedGoal;
  final Map<String, dynamic>? preview;
  final VoidCallback onComplete;
  final ValueChanged<String> onGoalSelected;

  const OnboardingStepGoal({
    super.key,
    required this.selectedGoal,
    required this.preview,
    required this.onComplete,
    required this.onGoalSelected,
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
            title: l10n?.advisorMiniStep4Title ?? 'Ton objectif',
            subtitle: l10n?.advisorMiniStep4Subtitle ??
                'MINT personnalise ton plan selon ta priorite principale',
          ),
          const SizedBox(height: 22),
          MintSelectableCard(
            icon: Icons.beach_access_outlined,
            label: l10n?.advisorMiniGoalRetirement ?? 'Preparer ma retraite',
            isSelected: selectedGoal == 'retirement',
            onTap: () => onGoalSelected('retirement'),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.house_outlined,
            label:
                l10n?.advisorMiniGoalRealEstate ?? 'Acheter un bien immobilier',
            isSelected: selectedGoal == 'real_estate',
            onTap: () => onGoalSelected('real_estate'),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.money_off_outlined,
            label: l10n?.advisorMiniGoalDebtFree ?? 'Reduire mes dettes',
            isSelected: selectedGoal == 'debt_free',
            onTap: () => onGoalSelected('debt_free'),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.trending_up_outlined,
            label: l10n?.advisorMiniGoalIndependence ??
                'Construire mon independance financiere',
            isSelected: selectedGoal == 'independence',
            onTap: () => onGoalSelected('independence'),
          ),
          if (preview != null) ...[
            const SizedBox(height: 12),
            OnboardingInsightCard(
              icon: Icons.show_chart,
              title: l10n?.advisorMiniPreviewTitle(
                      preview!['targetLabel'] as String) ??
                  'Preview trajectoire',
              body:
                  '${l10n?.advisorMiniPreviewPrudent ?? 'Prudent'}: ${preview!['prudent']}\n'
                  '${l10n?.advisorMiniPreviewBase ?? 'Base'}: ${preview!['base']}\n'
                  '${l10n?.advisorMiniPreviewOptimistic ?? 'Optimiste'}: ${preview!['optimiste']}',
            ),
          ],
          const SizedBox(height: 20),
          OnboardingContinueButton(
            enabled: selectedGoal != null,
            label:
                l10n?.advisorMiniActivateDashboard ?? 'Activer mon dashboard',
            icon: Icons.rocket_launch_outlined,
            backgroundColor: MintColors.primary,
            onPressed: onComplete,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
