import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/onboarding_provider.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_constants.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/onboarding/onboarding_widgets.dart';

class OnboardingStepIncome extends StatelessWidget {
  final TextEditingController incomeController;
  final TextEditingController housingController;
  final TextEditingController debtPaymentsController;
  final TextEditingController cashSavingsController;
  final TextEditingController investmentsController;
  final TextEditingController pillar3aTotalController;
  final TextEditingController taxController;
  final TextEditingController lamalController;
  final TextEditingController otherFixedController;
  final TextEditingController partnerIncomeController;
  final TextEditingController partnerBirthYearController;
  final TextEditingController partnerFirstNameController;
  final ValueChanged<int> onIncomeQuickPick;
  final VoidCallback onContinue;

  const OnboardingStepIncome({
    super.key,
    required this.incomeController,
    required this.housingController,
    required this.debtPaymentsController,
    required this.cashSavingsController,
    required this.investmentsController,
    required this.pillar3aTotalController,
    required this.taxController,
    required this.lamalController,
    required this.otherFixedController,
    required this.partnerIncomeController,
    required this.partnerBirthYearController,
    required this.partnerFirstNameController,
    required this.onIncomeQuickPick,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final provider = context.watch<OnboardingProvider>();
    final employmentStatus = provider.employmentStatus;
    final householdType = provider.householdType;
    final housingStatus = provider.housingStatus;
    final canContinue = provider.canAdvanceFromStep3;
    final missingItems = <String>[];
    if (provider.effectiveIncomeMonthly <= 0) {
      missingItems.add(
          l10n?.advisorMiniIncomeLabel ?? 'Revenu net mensuel');
    }
    if (provider.housingStatus == null ||
        (provider.housingStatus != 'hosted' &&
            provider.effectiveHousingCostMonthly <= 0)) {
      missingItems.add(l10n?.advisorMiniHousingTitle ?? 'Logement');
    }
    if (employmentStatus == null) {
      missingItems.add(l10n?.advisorMiniEmploymentEmployee ?? 'Statut professionnel');
    }
    if (householdType == null) {
      missingItems.add(l10n?.onboardingHouseholdSingle ?? 'Type de foyer');
    }
    if (provider.isHouseholdWithPartner) {
      if (provider.civilStatusChoice == null) {
        missingItems.add(
            l10n?.advisorMiniCivilStatusLabel ?? 'État civil du couple');
      }
      if (provider.effectivePartnerIncomeMonthly <= 0) {
        missingItems.add(l10n?.advisorMiniPartnerIncomeLabel ??
            'Revenu partenaire');
      }
      if (provider.effectivePartnerBirthYear == null) {
        missingItems.add(l10n?.advisorMiniPartnerBirthYearLabel ??
            'Annee de naissance partenaire');
      }
      if (provider.partnerEmploymentStatus == null) {
        missingItems.add(
            l10n?.advisorMiniPartnerStatusInactive ?? 'Statut partenaire');
      }
    }

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
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.child_care_outlined,
            label: l10n?.onboardingHouseholdSingleParent ?? 'Parent solo',
            description: l10n?.onboardingHouseholdSingleParentDesc ??
                'Je gere seul(e) avec enfant(s) a charge',
            isSelected: householdType == 'single_parent',
            onTap: () => provider.setHouseholdType('single_parent'),
          ),
          // ── Partner data (couple / family only) ──
          if (householdType == 'couple' || householdType == 'family') ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                l10n?.advisorMiniPartnerProfileTitle ?? 'Profil du/de la partenaire',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n?.advisorMiniPartnerRequiredBody ??
                  'Ajoute l\'état civil, le revenu, l\'année de naissance et le statut du partenaire pour une projection foyer fiable.',
              style: const TextStyle(
                fontSize: 12,
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            // Civil status choice
            MintSelectableCard(
              icon: Icons.favorite,
              label: l10n?.advisorMiniCivilStatusMarried ?? 'Marie·e',
              isSelected: provider.civilStatusChoice == 'married',
              onTap: () => provider.setCivilStatusChoice('married'),
            ),
            const SizedBox(height: 8),
            MintSelectableCard(
              icon: Icons.people,
              label:
                  l10n?.advisorMiniCivilStatusConcubinage ?? 'En concubinage',
              isSelected: provider.civilStatusChoice == 'concubinage',
              onTap: () => provider.setCivilStatusChoice('concubinage'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: partnerFirstNameController,
              textCapitalization: TextCapitalization.words,
              onChanged: provider.setPartnerFirstNameDraft,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: l10n?.advisorMiniPartnerFirstNameLabel ??
                    'Prénom du/de la partenaire (optionnel)',
                hintText:
                    l10n?.advisorMiniPartnerFirstNameHint ?? 'Ex: Lauren',
              ),
            ),
            const SizedBox(height: 12),
            // Partner income
            MintChfInputField(
              controller: partnerIncomeController,
              label: l10n?.advisorMiniPartnerIncomeLabel ??
                  'Revenu net mensuel du·de la partenaire',
              hint: '4000',
              onChanged: (value) => provider.setPartnerIncomeDraft(value),
            ),
            const SizedBox(height: 12),
            // Partner birth year
            TextField(
              controller: partnerBirthYearController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              onChanged: (value) => provider.setPartnerBirthYearDraft(value),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: l10n?.advisorMiniPartnerBirthYearLabel ??
                    'Année de naissance du/de la partenaire',
                hintText: '1990',
                counterText: '',
                filled: true,
                fillColor: MintColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MintColors.lightBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MintColors.lightBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: MintColors.primary, width: 1.8),
                ),
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            // Partner employment status
            MintSelectableCard(
              icon: Icons.business_center_outlined,
              label: l10n?.advisorMiniEmploymentEmployee ?? 'Salarie·e',
              description: l10n?.advisorMiniPartnerStatusHint ?? 'Partenaire',
              isSelected: provider.partnerEmploymentStatus == 'employee',
              onTap: () => provider.setPartnerEmploymentStatus('employee'),
            ),
            const SizedBox(height: 8),
            MintSelectableCard(
              icon: Icons.storefront_outlined,
              label: l10n?.advisorMiniEmploymentSelfEmployed ?? 'Independant·e',
              description: l10n?.advisorMiniPartnerStatusHint ?? 'Partenaire',
              isSelected: provider.partnerEmploymentStatus == 'self_employed',
              onTap: () => provider.setPartnerEmploymentStatus('self_employed'),
            ),
            const SizedBox(height: 8),
            MintSelectableCard(
              icon: Icons.pause_circle_outline,
              label: l10n?.advisorMiniPartnerStatusInactive ?? 'Sans activite',
              description: l10n?.advisorMiniPartnerStatusHint ?? 'Partenaire',
              isSelected: provider.partnerEmploymentStatus == 'inactive',
              onTap: () => provider.setPartnerEmploymentStatus('inactive'),
            ),
            if (!provider.hasPartnerRequiredData) ...[
              const SizedBox(height: 12),
              OnboardingInsightCard(
                icon: Icons.info_outline,
                title: l10n?.advisorMiniPartnerRequiredTitle ??
                    'Infos partenaire requises',
                body: l10n?.advisorMiniPartnerRequiredBody ??
                    'Ajoute l\'etat civil, le revenu, l\'annee de naissance et le statut du partenaire pour une projection foyer fiable.',
              ),
            ],
          ],
          const SizedBox(height: 12),
          Text(
            l10n?.advisorMiniHousingTitle ?? 'Logement',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.home_outlined,
            label: l10n?.advisorMiniHousingTenant ?? 'Locataire',
            isSelected: housingStatus == 'tenant',
            onTap: () => provider.setHousingStatus('tenant'),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.house_outlined,
            label: l10n?.advisorMiniHousingOwner ?? 'Propriétaire',
            isSelected: housingStatus == 'owner',
            onTap: () => provider.setHousingStatus('owner'),
          ),
          const SizedBox(height: 8),
          MintSelectableCard(
            icon: Icons.groups_outlined,
            label: l10n?.advisorMiniHousingHosted ?? 'Hébergé / sans loyer',
            isSelected: housingStatus == 'hosted',
            onTap: () => provider.setHousingStatus('hosted'),
          ),
          const SizedBox(height: 10),
          MintChfInputField(
            controller: housingController,
            label: (housingStatus == 'owner')
                ? (l10n?.advisorMiniHousingCostOwner ??
                    'Charges logement / hypothèque / mois')
                : (l10n?.advisorMiniHousingCostTenant ??
                    'Loyer / charges logement / mois'),
            hint: '1900',
            onChanged: (value) => provider.setHousingCostDraft(value),
          ),
          const SizedBox(height: 10),
          MintChfInputField(
            controller: debtPaymentsController,
            label: l10n?.advisorMiniDebtPaymentsLabel ??
                'Remboursements dettes / leasing / mois',
            hint: '0',
            optional: true,
            onChanged: (value) => provider.setDebtPaymentsDraft(value),
          ),
          const SizedBox(height: 12),
          Text(
            l10n?.advisorMiniPatrimonyTitle ?? 'Patrimoine (optionnel)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          MintChfInputField(
            controller: cashSavingsController,
            label: l10n?.advisorMiniCashSavingsLabel ??
                'Liquidités / épargne disponible',
            hint: '20000',
            optional: true,
            onChanged: (value) => provider.setCashSavingsDraft(value),
          ),
          const SizedBox(height: 8),
          MintChfInputField(
            controller: investmentsController,
            label: l10n?.advisorMiniInvestmentsTotalLabel ??
                'Placements (titres, ETF, fonds)',
            hint: '50000',
            optional: true,
            onChanged: (value) => provider.setInvestmentsTotalDraft(value),
          ),
          const SizedBox(height: 8),
          MintChfInputField(
            controller: pillar3aTotalController,
            label: l10n?.advisorMiniPillar3aTotalLabel ??
                'Total 3a approximatif',
            hint: '30000',
            optional: true,
            onChanged: (value) => provider.setPillar3aTotalDraft(value),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: Text(l10n?.advisorMiniFixedCostsTitle ??
                'Charges fixes (optionnel)'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.advisorMiniFixedCostsHint ??
                          'Inclure: logement, internet/mobile, assurances ménage/RC/auto, transport, abonnements et frais récurrents.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
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
            label: l10n?.onboardingContinue ?? 'Continuer',
            icon: Icons.auto_awesome,
            onPressed: onContinue,
          ),
          if (!canContinue && missingItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            OnboardingInsightCard(
              icon: Icons.info_outline,
              title: l10n?.advisorMiniReadyTitle ?? 'Validation',
              body:
                  'Complète: ${missingItems.take(3).join(', ')}${missingItems.length > 3 ? '…' : ''}',
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
