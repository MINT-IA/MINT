import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/educational/educational_widgets.dart';

/// Service de mapping entre les questions wizard et les inserts didactiques
/// Implémente le pattern "just-in-time information" (OECD/INFE)
class EducationalInsertService {
  /// Disclaimer pédagogique (i18n via S)
  static String getDisclaimer(S s) => s.educInsertDisclaimer;

  static const List<String> sources = [
    'LPP (Loi sur la prévoyance professionnelle)',
    'LAVS (Loi sur l\'AVS)',
    'OPP3 (Ordonnance sur le 3e pilier)',
    'LIFD (Loi sur l\'impôt fédéral direct)',
    'LAMal (Loi sur l\'assurance-maladie)',
    'LSFin art. 3 (Définition du conseil en placement)',
    'CC art. 159-251 (Régime matrimonial)',
    'FINMA circ. 2017/7 (Normes minimales hypothécaires)',
  ];
  /// Questions qui ont un insert didactique associé
  static const Set<String> questionsWithInserts = {
    // Inserts existants (S16-S19)
    'q_financial_stress_check',
    'q_has_pension_fund',
    'q_has_3a',
    'q_3a_annual_amount',
    'q_mortgage_type',
    'q_has_consumer_credit',
    'q_has_leasing',
    'q_emergency_fund',
    // Nouveaux inserts S27 — Niveau 1
    'q_civil_status',
    'q_employment_status',
    'q_housing_status',
    'q_canton',
    // Nouveaux inserts S27 — Niveau 2
    'q_lpp_buyback_available',
    'q_3a_accounts_count',
    'q_has_investments',
    'q_real_estate_project',
  };

  /// Vérifie si une question a un insert didactique
  static bool hasInsert(String questionId) {
    return questionsWithInserts.contains(questionId);
  }

  /// Retourne le widget d'insert pour une question donnée
  /// Returns null si aucun insert n'est disponible
  static Widget? getInsertWidget({
    required String questionId,
    required Map<String, dynamic> answers,
    required S s,
    VoidCallback? onLearnMore,
    Function(dynamic)? onAnswer,
  }) {
    switch (questionId) {
      case 'q_financial_stress_check':
        return StressCheckInsertWidget(
          onLearnMore: onLearnMore,
          onAction: (route) { if (kDebugMode) debugPrint('Navigate to $route'); },
        );

      case 'q_has_pension_fund':
        return LppPivotInsertWidget(
          hasPensionFund: answers['q_has_pension_fund'] == 'yes',
          onLearnMore: onLearnMore,
          onChanged: (val) => onAnswer?.call(val ? 'yes' : 'no'),
        );

      case 'q_has_3a':
      case 'q_3a_annual_amount':
        // 1. Income Resolution
        double monthlyIncome = 6000;

        final periodIncome = _parseDouble(answers['q_net_income_period_chf']);
        final monthlyDirect =
            _parseDouble(answers['q_income_net_monthly']); // Fallback key

        if (periodIncome != null) {
          final payFreq = answers['q_pay_frequency'] as String?;
          if (payFreq == 'weekly') {
            monthlyIncome = periodIncome * 4.33;
          } else if (payFreq == 'biweekly') {
            monthlyIncome = periodIncome * 2.17;
          } else {
            monthlyIncome = periodIncome;
          }
        } else if (monthlyDirect != null) {
          monthlyIncome = monthlyDirect;
        }

        // 2. Pension Fund Logic (Crucial Fix for Salaried employees)
        // If employee -> Default to Yes (Small 3a limit)
        // If self employed -> Default to No (Large 3a limit), unless explicit Yes
        final status = answers['q_employment_status'] as String?;
        final explicitLpp = answers['q_has_pension_fund'] == 'yes';

        bool hasPensionFund = explicitLpp;
        if (status == 'employee') {
          hasPensionFund =
              true; // Salaried employees almost always have LPP implies 7k limit
        }

        return TaxSavingsInsertWidget(
          initialIncome: monthlyIncome,
          hasPensionFund: hasPensionFund,
          onLearnMore: onLearnMore,
        );

      case 'q_mortgage_type':
        return MortgageComparisonInsertWidget(
          currentType: answers['q_mortgage_type'] as String?,
          onLearnMore: onLearnMore,
        );

      case 'q_has_consumer_credit':
        return CreditCostInsertWidget(
          creditAmount: _parseDouble(answers['q_credit_amount']),
          interestRate: _parseDouble(answers['q_credit_rate']),
          durationMonths: _parseInt(answers['q_credit_duration']),
          onLearnMore: onLearnMore,
        );

      case 'q_has_leasing':
        return LeasingCostInsertWidget(
          monthlyPayment: _parseDouble(answers['q_leasing_monthly']),
          remainingMonths: _parseInt(answers['q_leasing_remaining_months']),
          onLearnMore: onLearnMore,
        );

      case 'q_emergency_fund':
        return EmergencyFundInsertWidget(
          monthlyExpenses: _parseDouble(answers['q_expenses_fixed_monthly']),
          currentSavings: _parseDouble(answers['q_cash_total']),
          onLearnMore: onLearnMore,
        );

      // ── Nouveaux inserts S27 — Niveau 1 ──

      case 'q_civil_status':
        return GenericInfoInsertWidget(
          title: s.educInsertCivilStatusTitle,
          subtitle: s.educInsertCivilStatusSubtitle,
          chiffreChoc: s.educInsertCivilStatusChiffreChoc,
          learningGoals: [
            s.educInsertCivilStatusGoal1,
            s.educInsertCivilStatusGoal2,
            s.educInsertCivilStatusGoal3,
            s.educInsertCivilStatusGoal4,
            s.educInsertCivilStatusGoal5,
          ],
          disclaimer: s.educInsertCivilStatusDisclaimer,
          sources: const [
            'CC art. 159-251 (Régime matrimonial)',
            'CC art. 470-471 (Réserves héréditaires, révision 2023)',
            'LPP art. 22 (Partage LPP en cas de divorce)',
            'LIFD art. 9 al. 1 (Imposition commune des époux)',
            'LPart art. 1ss (Partenariat enregistré)',
          ],
          actionLabel: s.educInsertCivilStatusAction,
          actionRoute: '/mariage',
          onLearnMore: onLearnMore,
        );

      case 'q_employment_status':
        return GenericInfoInsertWidget(
          title: s.educInsertEmploymentTitle,
          subtitle: s.educInsertEmploymentSubtitle,
          chiffreChoc: s.educInsertEmploymentChiffreChoc,
          learningGoals: [
            s.educInsertEmploymentGoal1,
            s.educInsertEmploymentGoal2,
            s.educInsertEmploymentGoal3,
            s.educInsertEmploymentGoal4,
            s.educInsertEmploymentGoal5,
          ],
          disclaimer: s.educInsertEmploymentDisclaimer,
          sources: const [
            'LAVS art. 3, 10 (Cotisations AVS)',
            'LPP art. 2, 4, 7 (Assujettissement LPP)',
            'LAA art. 1a (Assurance accident)',
            'LACI art. 8 (Droit aux indemnités de chômage)',
            'OPP3 art. 7 (3a indépendant sans LPP)',
          ],
          actionLabel: s.educInsertEmploymentAction,
          actionRoute: '/tools',
          onLearnMore: onLearnMore,
        );

      case 'q_housing_status':
        return GenericInfoInsertWidget(
          title: s.educInsertHousingTitle,
          subtitle: s.educInsertHousingSubtitle,
          chiffreChoc: s.educInsertHousingChiffreChoc,
          learningGoals: [
            s.educInsertHousingGoal1,
            s.educInsertHousingGoal2,
            s.educInsertHousingGoal3,
            s.educInsertHousingGoal4,
            s.educInsertHousingGoal5,
          ],
          disclaimer: s.educInsertHousingDisclaimer,
          sources: const [
            'FINMA circ. 2017/7 (Normes minimales hypothécaires)',
            'LIFD art. 21 al. 1 let. b (Valeur locative)',
            'LIFD art. 32 (Déduction des frais d\'entretien)',
            'LPP art. 30c (EPL)',
            'OPP2 art. 30d-30g (Modalités EPL)',
          ],
          actionLabel: s.educInsertHousingAction,
          actionRoute: '/mortgage/affordability',
          onLearnMore: onLearnMore,
        );

      case 'q_canton':
        return GenericInfoInsertWidget(
          title: s.educInsertCantonTitle,
          subtitle: s.educInsertCantonSubtitle,
          chiffreChoc: s.educInsertCantonChiffreChoc,
          learningGoals: [
            s.educInsertCantonGoal1,
            s.educInsertCantonGoal2,
            s.educInsertCantonGoal3,
            s.educInsertCantonGoal4,
            s.educInsertCantonGoal5,
          ],
          disclaimer: s.educInsertCantonDisclaimer,
          sources: const [
            'LIFD (Impôt fédéral direct)',
            'LHID (Loi sur l\'harmonisation des impôts directs)',
            'Lois cantonales sur les impôts directs (26 lois)',
            'OFS Statistique fiscale de la Suisse',
          ],
          actionLabel: s.educInsertCantonAction,
          actionRoute: '/fiscal',
          onLearnMore: onLearnMore,
        );

      // ── Nouveaux inserts S27 — Niveau 2 ──

      case 'q_lpp_buyback_available':
        return GenericInfoInsertWidget(
          title: s.educInsertLppBuybackTitle,
          subtitle: s.educInsertLppBuybackSubtitle,
          chiffreChoc: s.educInsertLppBuybackChiffreChoc,
          learningGoals: [
            s.educInsertLppBuybackGoal1,
            s.educInsertLppBuybackGoal2,
            s.educInsertLppBuybackGoal3,
            s.educInsertLppBuybackGoal4,
            s.educInsertLppBuybackGoal5,
          ],
          disclaimer: s.educInsertLppBuybackDisclaimer,
          sources: const [
            'LPP art. 79b (Rachat de prestations)',
            'LPP art. 79b al. 3 (Blocage EPL 3 ans)',
            'LIFD art. 33 al. 1 let. d (Déduction des cotisations LPP)',
            'OPP2 art. 60a (Calcul du potentiel de rachat)',
          ],
          actionLabel: s.educInsertLppBuybackAction,
          actionRoute: '/lpp-deep/rachat',
          onLearnMore: onLearnMore,
        );

      case 'q_3a_accounts_count':
        return GenericInfoInsertWidget(
          title: s.educInsert3aCountTitle,
          subtitle: s.educInsert3aCountSubtitle,
          chiffreChoc: s.educInsert3aCountChiffreChoc,
          learningGoals: [
            s.educInsert3aCountGoal1,
            s.educInsert3aCountGoal2,
            s.educInsert3aCountGoal3,
            s.educInsert3aCountGoal4,
            s.educInsert3aCountGoal5,
          ],
          disclaimer: s.educInsert3aCountDisclaimer,
          sources: const [
            'OPP3 art. 3 (Retrait du 3a)',
            'LIFD art. 38 (Imposition séparée des prestations en capital)',
            'Lois cantonales sur l\'imposition des prestations en capital',
            'OPP3 art. 2 (Plafond annuel 3a)',
          ],
          actionLabel: s.educInsert3aCountAction,
          actionRoute: '/3a-deep/staggered-withdrawal',
          onLearnMore: onLearnMore,
        );

      case 'q_has_investments':
        return GenericInfoInsertWidget(
          title: s.educInsertInvestmentsTitle,
          subtitle: s.educInsertInvestmentsSubtitle,
          chiffreChoc: s.educInsertInvestmentsChiffreChoc,
          learningGoals: [
            s.educInsertInvestmentsGoal1,
            s.educInsertInvestmentsGoal2,
            s.educInsertInvestmentsGoal3,
            s.educInsertInvestmentsGoal4,
            s.educInsertInvestmentsGoal5,
          ],
          disclaimer: s.educInsertInvestmentsDisclaimer,
          sources: const [
            'LIFD art. 16 al. 3 (Exonération gains en capital privés)',
            'LIFD art. 20 (Imposition des rendements de fortune)',
            'LSFin art. 3 (Conseil en investissement)',
            'FINMA circ. 2018/3 (Règles de conduite)',
          ],
          actionLabel: s.educInsertInvestmentsAction,
          actionRoute: '/education/hub',
          onLearnMore: onLearnMore,
        );

      case 'q_real_estate_project':
        return GenericInfoInsertWidget(
          title: s.educInsertRealEstateTitle,
          subtitle: s.educInsertRealEstateSubtitle,
          chiffreChoc: s.educInsertRealEstateChiffreChoc,
          learningGoals: [
            s.educInsertRealEstateGoal1,
            s.educInsertRealEstateGoal2,
            s.educInsertRealEstateGoal3,
            s.educInsertRealEstateGoal4,
            s.educInsertRealEstateGoal5,
          ],
          disclaimer: s.educInsertRealEstateDisclaimer,
          sources: const [
            'FINMA circ. 2017/7 (Normes minimales hypothécaires)',
            'ASB Directives relatives aux exigences minimales pour les financements hypothécaires',
            'LPP art. 30c (EPL — encouragement à la propriété)',
            'OPP2 art. 30d-30g (Modalités EPL)',
            'LIFD art. 21 al. 1 let. b (Valeur locative)',
          ],
          actionLabel: s.educInsertRealEstateAction,
          actionRoute: '/mortgage/affordability',
          onLearnMore: onLearnMore,
        );

      default:
        return null;
    }
  }

  /// Retourne le titre du modal "En savoir plus"
  static String? getLearnMoreTitle(String questionId, S s) {
    switch (questionId) {
      case 'q_financial_stress_check':
        return s.educInsertLearnMoreStressCheck;
      case 'q_has_pension_fund':
        return s.educInsertLearnMorePensionFund;
      case 'q_has_3a':
      case 'q_3a_annual_amount':
        return s.educInsertLearnMore3a;
      case 'q_mortgage_type':
        return s.educInsertLearnMoreMortgage;
      case 'q_has_consumer_credit':
        return s.educInsertLearnMoreConsumerCredit;
      case 'q_has_leasing':
        return s.educInsertLearnMoreLeasing;
      case 'q_emergency_fund':
        return s.educInsertLearnMoreEmergencyFund;
      // Nouveaux inserts S27 — Niveau 1
      case 'q_civil_status':
        return s.educInsertLearnMoreCivilStatus;
      case 'q_employment_status':
        return s.educInsertLearnMoreEmployment;
      case 'q_housing_status':
        return s.educInsertLearnMoreHousing;
      case 'q_canton':
        return s.educInsertLearnMoreCanton;
      // Nouveaux inserts S27 — Niveau 2
      case 'q_lpp_buyback_available':
        return s.educInsertLearnMoreLppBuyback;
      case 'q_3a_accounts_count':
        return s.educInsertLearnMore3aCount;
      case 'q_has_investments':
        return s.educInsertLearnMoreInvestments;
      case 'q_real_estate_project':
        return s.educInsertLearnMoreRealEstate;
      default:
        return null;
    }
  }

  /// Parse helper pour double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Parse helper pour int
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
