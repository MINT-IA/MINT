import 'package:mint_mobile/models/wizard_question.dart';
import 'package:mint_mobile/data/wizard_questions_v2.dart';

/// Service "Cerveau" du Wizard
///
/// Responsable de :
/// 1. Déterminer la prochaine question à afficher (Routing dynamique)
/// 2. Calculer le progrès réel (basé sur le chemin probable)
/// 3. Gérer les exclusions de branches (ex: Indépendant -> Pas de questions LPP)
class WizardConditionsService {
  /// Détermine si une question doit être posée en fonction des réponses précédentes
  static bool shouldAskQuestion(
      String questionId, Map<String, dynamic> answers) {
    // 1. Logique Rachat LPP
    // Ne demander "Peux-tu racheter ta LPP ?" que si :
    // - On a une caisse de pension (q_has_pension_fund == 'yes')
    if (questionId == 'q_lpp_buyback_available') {
      final hasPension = answers['q_has_pension_fund'];
      // Skip buyback if user has no pension fund or doesn't know
      // (if you don't know your LPP status, you can't know your buyback amount)
      if (hasPension == 'no' || hasPension == 'unknown') return false;
    }

    // 2. Logique Statut Professionnel & LPP
    // Skip if already inferred from mini-onboarding (employee + income > threshold)
    if (questionId == 'q_has_pension_fund') {
      if (answers.containsKey('q_has_pension_fund')) return false;
      final status = answers['q_employment_status'];
      if (status == 'student' || status == 'retired') return false;
    }

    // 3. Logique Budget & Dettes — computed emergency fund (no longer asked)
    // Si dettes OU pas de fonds d'urgence critique -> Mode Protection
    // (MINT Philosophie : Protection d'abord)
    if (questionId == 'q_has_investments') {
      final hasDebt = answers['q_has_consumer_debt'] == 'yes';
      // Compute emergency fund from cash / monthly expenses
      final cash = _toDouble(answers['q_cash_total']) ?? 0;
      final monthlyExpenses = _estimateMonthlyExpenses(answers);
      final hasEmergencyFund = monthlyExpenses > 0
          ? cash / monthlyExpenses >= 3
          : cash > 10000;
      if (hasDebt || !hasEmergencyFund) return false;
    }

    // 4. Logique Prévoyance 3a
    // Si pas de 3a, on saute les questions de détails
    if (questionId == 'q_3a_accounts_count' ||
        questionId == 'q_3a_annual_contribution') {
      final has3a = answers['q_has_3a'];
      if (has3a != 'yes') return false;
    }

    // 5. Logique Projet Imo
    // Si le but principal est "Achat immobilier", on s'assure de poser q_real_estate_project
    // (C'est une question de Section 4, donc toujours posée si on arrive là, sauf si...)

    // 6. Logique AVS — questions conditionnelles selon le statut de lacunes
    if (questionId == 'q_avs_arrival_year') {
      return answers['q_avs_lacunes_status'] == 'arrived_late';
    }
    if (questionId == 'q_avs_years_abroad') {
      return answers['q_avs_lacunes_status'] == 'lived_abroad';
    }

    // 6b. Logique AVS conjoint — si marié ou partenariat enregistré
    //     (même traitement fiscal, CC art. 65a)
    if (questionId == 'q_spouse_avs_lacunes_status') {
      final civil = answers['q_civil_status'];
      return civil == 'married' || civil == 'registered_partner';
    }
    if (questionId == 'q_spouse_avs_arrival_year') {
      final civil = answers['q_civil_status'];
      final isPartner = civil == 'married' || civil == 'registered_partner';
      return isPartner && answers['q_spouse_avs_lacunes_status'] == 'arrived_late';
    }
    if (questionId == 'q_spouse_avs_years_abroad') {
      final civil = answers['q_civil_status'];
      final isPartner = civil == 'married' || civil == 'registered_partner';
      return isPartner && answers['q_spouse_avs_lacunes_status'] == 'lived_abroad';
    }

    // 7. Logique Dettes → Détails uniquement si dettes déclarées
    if (questionId == 'q_debt_payments_period_chf' ||
        questionId == 'q_total_debt_balance_chf') {
      if (answers['q_has_consumer_debt'] != 'yes') return false;
    }

    // 8. Logique Emploi → Rachat LPP impossible pour retraités et sans emploi
    if (questionId == 'q_lpp_buyback_available') {
      final status = answers['q_employment_status'];
      if (status == 'retired' || status == 'unemployed' || status == 'student') {
        return false;
      }
    }

    // 9. Logique Logement → Pas de coût si chez parents
    if (questionId == 'q_housing_cost_period_chf') {
      if (answers['q_housing_status'] == 'family') return false;
    }

    // 10. Logique Âge → Rachat LPP pas avant 25 ans (épargne LPP commence à 25)
    if (questionId == 'q_lpp_buyback_available') {
      final birthYear = answers['q_birth_year'];
      if (birthYear != null) {
        final age = DateTime.now().year - (birthYear is int ? birthYear : int.tryParse(birthYear.toString()) ?? 0);
        if (age < 25) return false;
      }
    }

    // 11. Logique Taux d'activité → seulement pour salariés
    if (questionId == 'q_activity_rate') {
      return answers['q_employment_status'] == 'employee';
    }

    // 12. Logique Revenu brut → seulement pour salariés (indépendants reportent le net)
    if (questionId == 'q_gross_income') {
      return answers['q_employment_status'] == 'employee';
    }

    // 13. Logique Capital LPP → seulement si caisse de pension
    if (questionId == 'q_lpp_current_capital') {
      final hasPension = answers['q_has_pension_fund'];
      if (hasPension == 'no' || hasPension == 'unknown') return false;
      // Also skip for students/retired (same logic as buyback)
      final status = answers['q_employment_status'];
      if (status == 'student' || status == 'retired') return false;
    }

    // 14. Logique Immobilier existant → seulement pour propriétaires
    if (questionId == 'q_property_value' || questionId == 'q_mortgage_balance') {
      return answers['q_housing_status'] == 'owner';
    }

    return true; // Par défaut, on pose la question
  }

  /// Estime les dépenses mensuelles totales à partir des réponses connues.
  /// Utilisé pour le calcul du fonds d'urgence déduit.
  static double _estimateMonthlyExpenses(Map<String, dynamic> answers) {
    final housing = _toDouble(answers['q_housing_cost_period_chf']) ?? 0;
    final debt = _toDouble(answers['q_debt_payments_period_chf']) ?? 0;
    final tax = _toDouble(answers['q_tax_provision_monthly_chf']) ?? 0;
    final lamal = _toDouble(answers['q_lamal_premium_monthly_chf']) ?? 0;
    final other = _toDouble(answers['q_other_fixed_costs_monthly_chf']) ?? 0;
    return housing + debt + tax + lamal + other;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString().replaceAll("'", '').trim());
  }

  /// Retourne la prochaine question applicable à partir de l'ID actuel
  static WizardQuestion? getNextQuestion(
      String currentQuestionId, Map<String, dynamic> answers) {
    final allQuestions = WizardQuestionsV2.questions;
    final currentIndex =
        allQuestions.indexWhere((q) => q.id == currentQuestionId);

    if (currentIndex == -1 || currentIndex == allQuestions.length - 1) {
      return null; // Fin du wizard
    }

    // Chercher la prochaine question éligible
    for (int i = currentIndex + 1; i < allQuestions.length; i++) {
      final nextQ = allQuestions[i];
      if (shouldAskQuestion(nextQ.id, answers)) {
        return nextQ;
      }
    }

    return null; // Plus de questions éligibles
  }

  /// Calcule le nombre total de questions effectives pour ce profil (estimation)
  static int calculateTotalSteps(Map<String, dynamic> answers) {
    return WizardQuestionsV2.questions
        .where((q) => shouldAskQuestion(q.id, answers))
        .length;
  }
}
