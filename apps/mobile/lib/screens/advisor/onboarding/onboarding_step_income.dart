import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/onboarding_provider.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_constants.dart';
import 'package:mint_mobile/widgets/onboarding/onboarding_widgets.dart';

class OnboardingStepIncome extends StatelessWidget {
  final TextEditingController incomeController;
  final TextEditingController taxController;
  final TextEditingController lamalController;
  final TextEditingController otherFixedController;
  final ValueChanged<int> onIncomeQuickPick;
  final VoidCallback onContinue;

  const OnboardingStepIncome({
    super.key,
    required this.incomeController,
    required this.taxController,
    required this.lamalController,
    required this.otherFixedController,
    required this.onIncomeQuickPick,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final provider = context.watch<OnboardingProvider>();
    final employmentStatus = provider.employmentStatus;
    final householdType = provider.householdType;

    final hasIncome = (double.tryParse(incomeController.text) ?? 0) > 0;
    final canContinue =
        hasIncome && employmentStatus != null && householdType != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingStepHeader(
            title: l10n?.advisorMiniStep3Title ?? 'Ton revenu',
            subtitle: l10n?.advisorMiniStep3Subtitle ??
                'Pour calculer ton potentiel d\'economie',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: incomeController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => provider.setIncomeDraft(value),
            decoration: InputDecoration(
              labelText: l10n?.advisorMiniIncomeLabel ?? 'Revenu net mensuel',
              hintText: '5000',
              prefixText: 'CHF  ',
            ),
          ),
          const SizedBox(height: 10),
          MintQuickPickChips<int>(
            options: OnboardingConstants.incomeQuickPicks,
            selected: int.tryParse(incomeController.text),
            labelBuilder: (v) => 'CHF $v',
            onSelected: onIncomeQuickPick,
          ),
          const SizedBox(height: 16),
          MintSelectableCard(
            icon: Icons.business_center_outlined,
            label: l10n?.advisorMiniEmploymentEmployee ?? 'Salarie·e',
            isSelected: employmentStatus == 'employee',
            onTap: () => provider.setEmploymentStatus('employee'),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.storefront_outlined,
            label: l10n?.advisorMiniEmploymentSelfEmployed ?? 'Independant·e',
            isSelected: employmentStatus == 'self_employed',
            onTap: () => provider.setEmploymentStatus('self_employed'),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.school_outlined,
            label: l10n?.advisorMiniEmploymentStudent ?? 'Etudiant·e',
            isSelected: employmentStatus == 'student',
            onTap: () => provider.setEmploymentStatus('student'),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.pause_circle_outline,
            label: l10n?.advisorMiniEmploymentUnemployed ?? 'Sans emploi',
            isSelected: employmentStatus == 'unemployed',
            onTap: () => provider.setEmploymentStatus('unemployed'),
          ),
          const SizedBox(height: 16),
          MintSelectableCard(
            icon: Icons.person_outline,
            label: l10n?.onboardingHouseholdSingle ?? 'Seul(e)',
            description: l10n?.onboardingHouseholdSingleDesc ??
                'Je gere mes finances en solo',
            isSelected: householdType == 'single',
            onTap: () => provider.setHouseholdType('single'),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.people_outline,
            label: l10n?.onboardingHouseholdCouple ?? 'En couple',
            description: l10n?.onboardingHouseholdCoupleDesc ??
                'Nous partageons nos objectifs financiers',
            isSelected: householdType == 'couple',
            onTap: () => provider.setHouseholdType('couple'),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.family_restroom_outlined,
            label: l10n?.onboardingHouseholdFamily ?? 'Famille',
            description: l10n?.onboardingHouseholdFamilyDesc ??
                'Avec enfant(s) a charge',
            isSelected: householdType == 'family',
            onTap: () => provider.setHouseholdType('family'),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: Text(l10n?.advisorMiniFixedCostsTitle ??
                'Charges fixes (optionnel)'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    MintChfInputField(
                      controller: taxController,
                      label: l10n?.advisorMiniTaxProvisionLabel ??
                          'Provision impots / mois',
                      hint: '900',
                      optional: true,
                    ),
                    const SizedBox(height: 8),
                    MintChfInputField(
                      controller: lamalController,
                      label:
                          l10n?.advisorMiniLamalLabel ?? 'Primes LAMal / mois',
                      hint: '430',
                      optional: true,
                    ),
                    const SizedBox(height: 8),
                    MintChfInputField(
                      controller: otherFixedController,
                      label: l10n?.advisorMiniOtherFixedLabel ??
                          'Autres charges fixes / mois',
                      hint: '300',
                      optional: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          OnboardingContinueButton(
            enabled: canContinue,
            label: l10n?.advisorMiniSeeProjection ?? 'Voir ma projection',
            icon: Icons.auto_awesome,
            onPressed: onContinue,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
