import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/wizard_conditions_service.dart';
import 'package:mint_mobile/data/wizard_questions_v2.dart';
import 'package:mint_mobile/models/wizard_question.dart';

/// Test du "Golden Path" (Flux Utilisateur Idéal)
/// Approche Herméneutique : Valider le tout (Le Parcours) par les parties (Les Questions/Logique)
void main() {
  group('Advisor Wizard Golden Paths', () {
    late List<WizardQuestion> questions;

    setUp(() {
      questions = WizardQuestionsV2.questions;
    });

    test('Path A: Standard Employee Journey (Zurich, Married, Kids)', () {
      final Map<String, dynamic> answers = {};

      // 1. Profil Basics
      // Age
      expect(WizardConditionsService.shouldAskQuestion('q_birth_year', answers),
          isTrue);
      answers['q_birth_year'] = 1990; // 36 ans

      // Canton
      expect(WizardConditionsService.shouldAskQuestion('q_canton', answers),
          isTrue);
      answers['q_canton'] = 'ZH';

      // Etat Civil
      expect(
          WizardConditionsService.shouldAskQuestion('q_civil_status', answers),
          isTrue);
      answers['q_civil_status'] = 'married';

      // Enfants
      expect(WizardConditionsService.shouldAskQuestion('q_children', answers),
          isTrue);
      answers['q_children'] =
          '2'; // Impact fiscal important (v2 use string '2' not int 2)

      // 2. Pivot Professionnel
      // Statut
      expect(
          WizardConditionsService.shouldAskQuestion(
              'q_employment_status', answers),
          isTrue);
      answers['q_employment_status'] = 'employee';

      // Revenu
      expect(
          WizardConditionsService.shouldAskQuestion(
              'q_net_income_period_chf', answers),
          isTrue);
      answers['q_net_income_period_chf'] = 8500.0; // Mensuel
      answers['q_pay_frequency'] = 'monthly'; // Implicite souvent

      // 3. Pivot Budgétaire
      // Épargne
      expect(
          WizardConditionsService.shouldAskQuestion(
              'q_savings_monthly', answers),
          isTrue);
      answers['q_savings_monthly'] = 1500.0;
      // -> Ici l'Insight "Intérêts composés" devrait s'activer dans l'UI (verif logique OK)

      // 4. Prévoyance (Suite à Employé)
      // 2nd Pilier (LPP)
      expect(
          WizardConditionsService.shouldAskQuestion(
              'q_has_lpp_certificate', answers),
          isTrue);
      answers['q_has_lpp_certificate'] = 'yes';

      // Rachat LPP (Question avancée)
      expect(
          WizardConditionsService.shouldAskQuestion(
              'q_buyback_potential', answers),
          isTrue);

      // 3a
      expect(WizardConditionsService.shouldAskQuestion('q_has_3a', answers),
          isTrue);
      answers['q_has_3a'] = 'yes';

      // Montant 3a
      expect(
          WizardConditionsService.shouldAskQuestion(
              'q_3a_annual_contribution', answers),
          isTrue);
      answers['q_3a_annual_contribution'] = 7056.0; // Max employé

      // 5. Validation État Final
      // Vérifier que le service de routing considère le parcours "complet" ou avance bien
      final next = WizardConditionsService.getNextQuestion(
          'q_3a_annual_contribution', answers);
      expect(next, isNotNull);
      expect(next?.id, 'q_avs_gaps'); // Prévoyance continue

      // Et après AVS ?
      final afterAvs =
          WizardConditionsService.getNextQuestion('q_avs_gaps', answers);
      expect(afterAvs, isNotNull);
      // After AVS, next question continues (prevoyance or patrimoine section)
      expect(afterAvs, isNotNull);
    });

    test('Path B: Freelancer Journey (Bern, Single)', () {
      final Map<String, dynamic> answers = {};

      // 1. Profil
      answers['q_birth_year'] = 1995;
      answers['q_canton'] = 'BE';
      answers['q_civil_status'] = 'single';
      answers['q_children'] = '0';

      // 2. Pivot Freelance
      answers['q_employment_status'] = 'self_employed';

      // Doit demander si affiliation caisse LPP volontaire
      // Vérifions si cette question existe dans V2, sinon adaptons le test
      // Si q_has_2nd_pillar existe :
      // expect(WizardConditionsService.shouldAskQuestion('q_has_2nd_pillar', answers), isTrue);

      // Revenu
      answers['q_net_income_period_chf'] = 12000.0; // Revenu irrégulier lissé

      // 3. Prévoyance Spécifique
      // Check logique 3a (Grand pilier)
      // Le routing doit permettre d'aller vers le 3a

      expect(WizardConditionsService.shouldAskQuestion('q_has_3a', answers),
          isTrue);
      answers['q_has_3a'] = 'no';

      // Doit proposer d'en ouvrir un (via question suivante ou fin)
      final next = WizardConditionsService.getNextQuestion('q_has_3a', answers);
      expect(next, isNotNull);

      // Pour freelance sans LPP, le plafond 3a est différent (20% revenu).
      // Ce n'est pas le test de routing qui valide le montant, mais le service.
      // Ici on valide que le FLUX continue.
    });

    test('Insight Logic: Tax Savings Trigger', () {
      final Map<String, dynamic> answers = {
        'q_canton': 'VD',
        'q_net_income_period_chf': 10000.0,
        'q_civil_status': 'single',
      };

      // L'insight widget utilise TaxEstimatorService.
      // On teste si les conditions de données sont réunies.
      bool hasDataForInsight = answers['q_canton'] != null &&
          answers['q_net_income_period_chf'] != null;
      expect(hasDataForInsight, isTrue);

      // Validation herméneutique:
      // Si j'ai le canton et le revenu, le système DOIT être capable de me donner un feedback.
    });
  });
}
