import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/wizard_question.dart';
import 'package:mint_mobile/models/clarity_state.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:mint_mobile/data/wizard_questions.dart';

class WizardService {
  static const _questionAnswerAliases = {
    'q_housing_cost_period_chf': ['_coach_depenses_loyer'],
    'q_lamal_premium_monthly_chf': ['_coach_depenses_assurance'],
  };

  static const _answerQuestionAliases = {
    '_coach_depenses_loyer': 'q_housing_cost_period_chf',
    '_coach_depenses_assurance': 'q_lamal_premium_monthly_chf',
  };

  /// Filtre les questions selon le profil utilisateur
  static List<WizardQuestion> getQuestionsForUser(
    Profile? profile,
    Map<String, dynamic> answers,
  ) {
    // Utilisation du nouveau getter
    final allQuestions = WizardQuestions.questions;
    final filteredQuestions = <WizardQuestion>[];

    for (final question in allQuestions) {
      if (_shouldShowQuestion(question, profile, answers)) {
        filteredQuestions.add(question);
      }
    }

    return filteredQuestions;
  }

  /// Détermine si une question doit être affichée
  static bool _shouldShowQuestion(
    WizardQuestion question,
    Profile? profile,
    Map<String, dynamic> answers,
  ) {
    if (!question.shouldShow(answers)) {
      return false;
    }
    return true;
  }

  /// Calcule l'état de clarté
  static ClarityState calculateClarityState(
    Map<String, dynamic> answers,
    Map<String, dynamic> completedActions,
  ) {
    return ClarityState.calculate(answers, completedActions);
  }

  /// Détermine si Safe Mode est actif selon YAML CH
  static bool isSafeModeActive(Map<String, dynamic> answers) {
    final bool hasDebtStress = answers['q_late_payments_6m'] == 'yes' ||
        answers['q_creditcard_minimum_or_overdraft'] == 'often' ||
        answers['q_has_consumer_credit'] == 'yes' ||
        answers['q_has_consumer_debt'] == 'yes';

    final debtRatio = _calculateDebtRatio(answers);

    final String? emergencyFund = answers['q_emergency_fund'];
    final bool hasEmergencyFund =
        emergencyFund == 'yes_6months' || emergencyFund == 'yes_3months';

    return hasDebtStress || debtRatio > 0.3 || !hasEmergencyFund;
  }

  /// Calcule le ratio dettes/revenus
  static double _calculateDebtRatio(Map<String, dynamic> answers) {
    final income = getMonthlyIncome(answers);

    if (income == 0) return 0;

    double totalDebt = 0;

    if (answers['q_has_leasing'] == 'yes') {
      totalDebt += (answers['q_leasing_monthly'] as num?)?.toDouble() ?? 0.0;
    }

    if (answers['q_has_consumer_credit'] == 'yes') {
      totalDebt += (answers['q_credit_monthly'] as num?)?.toDouble() ?? 0.0;
    }

    if (answers.containsKey('q_debt_payments_period_chf')) {
      // Normaliser la dette périodique en mensuel
      final rawDebt =
          (answers['q_debt_payments_period_chf'] as num?)?.toDouble() ?? 0.0;
      final frequency = answers['q_pay_frequency'] as String? ?? 'monthly';
      // Mêmes facteurs que l'income
      double factor = 1.0;
      if (frequency == 'biweekly') factor = 2.166; // 26 / 12
      if (frequency == 'weekly') factor = 4.333; // 52 / 12

      totalDebt += rawDebt * factor;
    }

    return totalDebt / income;
  }

  /// Calcule le revenu net mensuel normalisé
  static double getMonthlyIncome(Map<String, dynamic> answers) {
    if (answers.containsKey('q_net_income_monthly')) {
      return (answers['q_net_income_monthly'] as num?)?.toDouble() ?? 0.0;
    }

    final rawIncome =
        (answers['q_net_income_period_chf'] as num?)?.toDouble() ?? 0.0;
    final frequency = answers['q_pay_frequency'] as String? ?? 'monthly';

    switch (frequency) {
      case 'weekly':
        return rawIncome * 4.333; // 52 semaines / 12
      case 'biweekly':
        return rawIncome * 2.166; // 26 paiements / 12
      case 'monthly':
      default:
        return rawIncome;
    }
  }

  /// Retourne la prochaine question la plus pertinente
  static WizardQuestion? getNextMostValuableQuestion(
    List<WizardQuestion> remainingQuestions,
    Map<String, dynamic> answers,
  ) {
    // Prioriser selon impact sur précision
    final priorityOrder = [
      'q_canton',
      'q_birth_year',
      'q_household_type',
      'q_net_income_period_chf', // Priorité budget
      'q_savings_monthly',
      'q_has_3a',
      'q_has_lpp_certificate',
      'q_primary_goal',
    ];

    if (remainingQuestions.isEmpty) return null;

    for (final priorityId in priorityOrder) {
      final match = remainingQuestions.where((q) => q.id == priorityId);
      if (match.isNotEmpty) return match.first;
    }

    return remainingQuestions.first;
  }

  /// Valide qu'une réponse respecte les contraintes
  ///
  /// Pass [l] (S) for localized error messages.
  static String? validateAnswer(WizardQuestion question, dynamic answer,
      {S? l}) {
    // Required
    if (question.required && answer == null) {
      return l?.wizardValidationRequired ?? 'Cette question est obligatoire';
    }

    // Input validation
    bool isNumericQuestion = question.type == QuestionType.input ||
        question.type == QuestionType.number;
    if (isNumericQuestion && (answer is int || answer is double)) {
      if (question.minValue != null && answer < question.minValue!) {
        return 'Valeur minimum : ${question.minValue}'; // Dynamic interpolation — not extracted
      }
      if (question.maxValue != null && answer > question.maxValue!) {
        return 'Valeur maximum : ${question.maxValue}'; // Dynamic interpolation — not extracted
      }
    }

    return null;
  }

  /// Génère un résumé des réponses pour affichage
  ///
  /// Pass [l] (S) for localized fallback values.
  static Map<String, String> generateAnswersSummary(
    Map<String, dynamic> answers,
    List<WizardQuestion> questions, {
    S? l,
  }) {
    final summary = <String, String>{};

    for (final entry in answers.entries) {
      final questionId = _answerQuestionAliases[entry.key] ?? entry.key;
      final question = questions.firstWhere(
        (q) => q.id == questionId,
        orElse: () => questions.first,
      );

      if (question.id == questionId) {
        summary[question.title] = _formatAnswer(entry.value, question, l: l);
      }
    }

    return summary;
  }

  static String _formatAnswer(dynamic value, WizardQuestion question, {S? l}) {
    if (value == null) return l?.wizardAnswerNotProvided ?? '-';

    if (question.type == QuestionType.choice) {
      final option = question.options?.firstWhere(
        (o) => o.value == value,
        orElse: () => question.options!.first,
      );
      return option?.label ?? value.toString();
    }

    if (question.type == QuestionType.input) {
      if (question.hint?.contains('CHF') == true) {
        return 'CHF ${value.toString()}';
      }
      return value.toString();
    }

    return value.toString();
  }

  /// Calcule le score de complétude (0-100%)
  static double calculateCompletionScore(
    Map<String, dynamic> answers,
    List<WizardQuestion> allQuestions,
  ) {
    final requiredQuestions = allQuestions.where((q) => q.required).toList();
    final answeredRequired = requiredQuestions
        .where((q) => _hasAnswerForQuestion(answers, q.id))
        .length;

    if (requiredQuestions.isEmpty) return 100.0;

    return (answeredRequired / requiredQuestions.length) * 100;
  }

  static bool _hasAnswerForQuestion(Map<String, dynamic> answers, String id) {
    if (answers[id] != null) return true;
    final aliases = _questionAnswerAliases[id] ?? const <String>[];
    return aliases.any((alias) => answers[alias] != null);
  }
}
