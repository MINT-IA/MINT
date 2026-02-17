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
      // Si on a répondu 'no' ou 'unknown' à la q_has_pension_fund, on saute
      if (hasPension == 'no') return false;

      // Si indépendant, on check le statut (souvent pas de LPP, mais parfois oui)
      // Par sécurité, on se fie à q_has_pension_fund qui est explicite
    }

    // 2. Logique Statut Professionnel & LPP
    // La question q_has_pension_fund est pertinente pour tous,
    // mais on peut la pré-remplir ou sauter si on voulait être agressif.
    // Pour l'instant on la garde pour tout le monde pour confirmer.

    // 3. Logique Budget & Dettes
    // Si "Dettes de consommation" = OUI (q_has_consumer_debt == 'yes'),
    // On pourrait prioriser le fonds d'urgence et sauter l'investissement.
    if (questionId == 'q_has_investments') {
      final hasDebt = answers['q_has_consumer_debt'] == 'yes';
      final emergencyFund = answers['q_emergency_fund'] == 'no';

      // Si dettes OU pas de fonds d'urgence critique -> Mode Protection
      // On évite de parler d'investissements exotiques pour ne pas distraire
      // (MINT Philosophie : Protection d'abord)
      if (hasDebt || emergencyFund) return false;
    }

    // 4. Logique Prévoyance 3a
    // Si pas de 3a, on saute les questions de détails
    if (questionId == 'q_3a_accounts_count' ||
        questionId == 'q_3a_providers' ||
        questionId == 'q_3a_annual_contribution') {
      final has3a = answers['q_has_3a'];
      if (has3a != 'yes') return false;
    }

    // 5. Logique Projet Imo
    // Si le but principal est "Achat immobilier", on s'assure de poser q_real_estate_project
    // (C'est une question de Section 4, donc toujours posée si on arrive là, sauf si...)

    // 6. Logique AVS — conjoint uniquement si marié
    if (questionId == 'q_spouse_first_employment_year') {
      return answers['q_civil_status'] == 'married';
    }

    // 7. Logique Dettes → Détails uniquement si dettes déclarées
    if (questionId == 'q_debt_payments_period_chf' ||
        questionId == 'q_total_debt_balance_chf') {
      if (answers['q_has_consumer_debt'] != 'yes') return false;
    }

    // 8. Logique Emploi → LPP non pertinent pour étudiants
    if (questionId == 'q_has_pension_fund') {
      if (answers['q_employment_status'] == 'student') return false;
    }

    // 9. Logique Emploi → Rachat LPP impossible pour retraités
    if (questionId == 'q_lpp_buyback_available') {
      if (answers['q_employment_status'] == 'retired') return false;
    }

    // 10. Logique Logement → Pas de coût si chez parents
    if (questionId == 'q_housing_cost_period_chf') {
      if (answers['q_housing_status'] == 'family') return false;
    }

    // 11. (Removed — q_first_employment_year is valid for all ages)

    // 12. Logique Âge → Rachat LPP pas avant 25 ans (épargne LPP commence à 25)
    if (questionId == 'q_lpp_buyback_available') {
      final birthYear = answers['q_birth_year'];
      if (birthYear != null) {
        final age = DateTime.now().year - (birthYear is int ? birthYear : int.tryParse(birthYear.toString()) ?? 0);
        if (age < 25) return false;
      }
    }

    return true; // Par défaut, on pose la question
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
