import 'package:flutter/material.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Noms des mois en francais (utilise par Check-in + Agir)
const kFrenchMonths = [
  'Janvier',
  'Fevrier',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Aout',
  'Septembre',
  'Octobre',
  'Novembre',
  'Decembre',
];

/// Noms courts des mois en francais
const kFrenchMonthsShort = [
  'Jan',
  'Fev',
  'Mar',
  'Avr',
  'Mai',
  'Jun',
  'Jul',
  'Aou',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Icone par categorie de versement planifie
IconData iconForCategory(String category) {
  switch (category) {
    case '3a':
      return Icons.savings;
    case 'lpp_buyback':
      return Icons.account_balance;
    case 'investissement':
      return Icons.trending_up;
    case 'epargne_libre':
      return Icons.wallet;
    default:
      return Icons.attach_money;
  }
}

/// Couleur par categorie de versement planifie
Color colorForCategory(String category) {
  switch (category) {
    case '3a':
      return const Color(0xFF4F46E5); // Indigo
    case 'lpp_buyback':
      return const Color(0xFF0891B2); // Teal
    case 'investissement':
      return MintColors.success;
    case 'epargne_libre':
      return MintColors.warning;
    default:
      return MintColors.info;
  }
}

/// Route cible pour un coaching tip (utilise par Dashboard + Agir).
String tipRoute(CoachingTip tip) {
  switch (tip.category) {
    case 'fiscalite':
      return '/simulator/3a';
    case 'prevoyance':
      if (tip.id.contains('lpp')) return '/lpp-deep/rachat';
      if (tip.id.contains('3a')) return '/simulator/3a';
      return '/retirement';
    case 'budget':
      if (tip.id.contains('debt')) return '/check/debt';
      if (tip.id.contains('emergency')) return '/budget';
      return '/budget';
    case 'retraite':
      if (tip.id.contains('rente') || tip.id.contains('capital')) {
        if (!FeatureFlags.enableDecisionScaffold) return '/coach/dashboard';
        return '/arbitrage/rente-vs-capital';
      }
      if (tip.id.contains('projection')) {
        return '/coach/dashboard';
      }
      return '/coach/dashboard';
    default:
      return '/report';
  }
}
