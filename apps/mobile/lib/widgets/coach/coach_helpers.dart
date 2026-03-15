import 'package:flutter/material.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Noms des mois en francais (utilise par Check-in + Agir)
const kFrenchMonths = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

/// Noms courts des mois en francais
const kFrenchMonthsShort = [
  'Jan',
  'Fév',
  'Mar',
  'Avr',
  'Mai',
  'Jun',
  'Jul',
  'Aoû',
  'Sep',
  'Oct',
  'Nov',
  'Déc',
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
      return MintColors.indigo; // Indigo
    case 'lpp_buyback':
      return MintColors.cyan; // Teal
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
      return '/pilier-3a';
    case 'prevoyance':
      if (tip.id.contains('lpp')) return '/rachat-lpp';
      if (tip.id.contains('3a')) return '/pilier-3a';
      return '/retirement';
    case 'budget':
      if (tip.id.contains('debt')) return '/check/debt';
      if (tip.id.contains('emergency')) return '/budget';
      return '/budget';
    case 'retraite':
      if (tip.id.contains('rente') || tip.id.contains('capital')) {
        if (!FeatureFlags.enableDecisionScaffold) return '/retraite';
        return '/rente-vs-capital';
      }
      if (tip.id.contains('projection')) {
        return '/retraite';
      }
      return '/retraite';
    default:
      return '/rapport';
  }
}
