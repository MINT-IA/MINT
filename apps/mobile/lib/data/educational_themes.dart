import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';

class EducationalTheme {
  final String id;
  final String title;
  final String question;
  final String actionLabel;
  final String route;
  final String reminderText;
  final IconData icon;
  final Color color;
  final int estimatedMinutes;

  const EducationalTheme({
    required this.id,
    required this.title,
    required this.question,
    required this.actionLabel,
    required this.route,
    required this.reminderText,
    required this.icon,
    required this.color,
    this.estimatedMinutes = 3,
  });

  /// Returns a copy with localized strings (fallback = French const values)
  EducationalTheme localized(S? l10n) {
    if (l10n == null) return this;
    final t = _localizedStrings[id];
    if (t == null) return this;
    return EducationalTheme(
      id: id,
      title: t['title']?.call(l10n) ?? title,
      question: t['question']?.call(l10n) ?? question,
      actionLabel: t['actionLabel']?.call(l10n) ?? actionLabel,
      route: route,
      reminderText: t['reminderText']?.call(l10n) ?? reminderText,
      icon: icon,
      color: color,
      estimatedMinutes: estimatedMinutes,
    );
  }

  static final Map<String, Map<String, String? Function(S)>> _localizedStrings = {
    '3a': {
      'title': (l) => l.eduTheme3aTitle,
      'question': (l) => l.eduTheme3aQuestion,
      'actionLabel': (l) => l.eduTheme3aAction,
      'reminderText': (l) => l.eduTheme3aReminder,
    },
    'lpp': {
      'title': (l) => l.eduThemeLppTitle,
      'question': (l) => l.eduThemeLppQuestion,
      'actionLabel': (l) => l.eduThemeLppAction,
      'reminderText': (l) => l.eduThemeLppReminder,
    },
    'avs': {
      'title': (l) => l.eduThemeAvsTitle,
      'question': (l) => l.eduThemeAvsQuestion,
      'actionLabel': (l) => l.eduThemeAvsAction,
      'reminderText': (l) => l.eduThemeAvsReminder,
    },
    'emergency': {
      'title': (l) => l.eduThemeEmergencyTitle,
      'question': (l) => l.eduThemeEmergencyQuestion,
      'actionLabel': (l) => l.eduThemeEmergencyAction,
      'reminderText': (l) => l.eduThemeEmergencyReminder,
    },
    'debt': {
      'title': (l) => l.eduThemeDebtTitle,
      'question': (l) => l.eduThemeDebtQuestion,
      'actionLabel': (l) => l.eduThemeDebtAction,
      'reminderText': (l) => l.eduThemeDebtReminder,
    },
    'mortgage': {
      'title': (l) => l.eduThemeMortgageTitle,
      'question': (l) => l.eduThemeMortgageQuestion,
      'actionLabel': (l) => l.eduThemeMortgageAction,
      'reminderText': (l) => l.eduThemeMortgageReminder,
    },
    'budget': {
      'title': (l) => l.eduThemeBudgetTitle,
      'question': (l) => l.eduThemeBudgetQuestion,
      'actionLabel': (l) => l.eduThemeBudgetAction,
      'reminderText': (l) => l.eduThemeBudgetReminder,
    },
    'lamal': {
      'title': (l) => l.eduThemeLamalTitle,
      'question': (l) => l.eduThemeLamalQuestion,
      'actionLabel': (l) => l.eduThemeLamalAction,
      'reminderText': (l) => l.eduThemeLamalReminder,
    },
    'fiscal': {
      'title': (l) => l.eduThemeFiscalTitle,
      'question': (l) => l.eduThemeFiscalQuestion,
      'actionLabel': (l) => l.eduThemeFiscalAction,
      'reminderText': (l) => l.eduThemeFiscalReminder,
    },
  };
}

class EducationData {
  static const List<EducationalTheme> themes = [
    EducationalTheme(
      id: '3a',
      title: 'Le 3e pilier (3a)',
      question: "C'est quoi le 3a et pourquoi tout le monde en parle ?",
      actionLabel: "Estimer mon économie fiscale",
      route: '/pilier-3a',
      reminderText: "Décembre → Dernier moment pour verser cette année",
      icon: Icons.savings_outlined,
      color: MintColors.success,
    ),
    EducationalTheme(
      id: 'lpp',
      title: 'La caisse de pension (LPP)',
      question: "Est-ce que j'ai une caisse de pension ?",
      actionLabel: "Analyser mon certificat LPP",
      route: '/documents',
      reminderText: "Demander mon certificat LPP à mon employeur",
      icon: Icons.work_outline,
      color: MintColors.info,
      estimatedMinutes: 4,
    ),
     EducationalTheme(
      id: 'avs',
      title: 'Les lacunes AVS',
      question: "Ai-je des années de cotisation manquantes ?",
      actionLabel: "Vérifier mon extrait de compte AVS",
      route: '/retraite',
      reminderText: "Commander mon extrait sur ahv-iv.ch",
      icon: Icons.accessibility_new_outlined,
      color: MintColors.warning,
    ),
    EducationalTheme(
      id: 'emergency',
      title: 'Le fonds d\'urgence',
      question: "Combien je devrais avoir de côté ?",
      actionLabel: "Calculer mon objectif",
      route: '/budget',
      reminderText: "Vérifier mon épargne de sécurité chaque trimestre",
      icon: Icons.shield_outlined,
      color: MintColors.error,
    ),
    EducationalTheme(
      id: 'debt',
      title: 'Les dettes',
      question: "Combien me coûte vraiment ma dette ?",
      actionLabel: "Calculer le coût total",
      route: '/simulator/credit',
      reminderText: "Priorité: rembourser avant d'investir",
      icon: Icons.credit_card_off_outlined,
      color: MintColors.deepOrange,
    ),
    EducationalTheme(
      id: 'mortgage',
      title: 'L\'hypothèque',
      question: "Fixe ou SARON, c'est quoi la différence ?",
      actionLabel: "Comparer les deux stratégies",
      route: '/mortgage/saron-vs-fixed',
      reminderText: "Avant renouvellement: comparer 3 mois à l'avance",
      icon: Icons.house_outlined,
      color: MintColors.indigo,
      estimatedMinutes: 4,
    ),
    EducationalTheme(
      id: 'budget',
      title: 'Le reste à vivre',
      question: "Combien il me reste après les charges fixes ?",
      actionLabel: "Estimer mon reste à vivre",
      route: '/budget', // Using budget route
      reminderText: "Revoir mon budget chaque mois",
      icon: Icons.account_balance_wallet_outlined,
      color: MintColors.teal,
      estimatedMinutes: 2,
    ),
    EducationalTheme(
      id: 'lamal',
      title: 'Les subsides LAMal',
      question: "Ai-je droit à une aide pour mes primes ?",
      actionLabel: "Vérifier mon éligibilité",
      route: '/assurances/lamal',
      reminderText: "Les critères changent selon le canton",
      icon: Icons.medical_services_outlined,
      color: MintColors.pink,
    ),
    EducationalTheme(
      id: 'fiscal',
      title: 'La fiscalité suisse',
      question: "Comment fonctionnent les impôts en Suisse ?",
      actionLabel: "Comparer ma fiscalité cantonale",
      route: '/fiscal',
      reminderText: "Deadline déclaration fiscale : 31 mars (extensible)",
      icon: Icons.calculate_outlined,
      color: MintColors.amber,
    ),
  ];

  static EducationalTheme? getById(String id) {
    final matches = themes.where((t) => t.id == id);
    if (matches.isEmpty) {
      if (kDebugMode) {
        debugPrint('EducationData.getById: unknown themeId "$id"');
      }
      return null;
    }
    return matches.first;
  }
}
