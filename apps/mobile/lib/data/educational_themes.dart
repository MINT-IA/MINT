import 'package:flutter/material.dart';
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

  const EducationalTheme({
    required this.id,
    required this.title,
    required this.question,
    required this.actionLabel,
    required this.route,
    required this.reminderText,
    required this.icon,
    required this.color,
  });
}

class EducationData {
  static const List<EducationalTheme> themes = [
    EducationalTheme(
      id: '3a',
      title: 'Le 3e pilier (3a)',
      question: "C'est quoi le 3a et pourquoi tout le monde en parle ?",
      actionLabel: "Estimer mon économie fiscale",
      route: '/simulator/3a',
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
    ),
     EducationalTheme(
      id: 'avs',
      title: 'Les lacunes AVS',
      question: "Ai-je des années de cotisation manquantes ?",
      actionLabel: "Vérifier mon extrait de compte AVS",
      route: '/retirement',
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
      actionLabel: "Simuler mon économie 3a",
      route: '/simulator/3a',
      reminderText: "Deadline declaration fiscale : 31 mars (extensible)",
      icon: Icons.calculate_outlined,
      color: MintColors.amber,
    ),
  ];

  static EducationalTheme getById(String id) {
    return themes.firstWhere((t) => t.id == id, orElse: () => themes.first);
  }
}
