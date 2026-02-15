import 'package:flutter/material.dart';
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
