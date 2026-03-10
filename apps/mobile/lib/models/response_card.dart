import 'package:flutter/material.dart';

// ────────────────────────────────────────────────────────────
//  RESPONSE CARD MODEL — Phase 1 (S50-S51)
// ────────────────────────────────────────────────────────────
//
//  Modele unifie pour les 10 types de cartes coach.
//  Utilise dans PulseScreen (cards dynamiques) et
//  CoachChatScreen (inline apres reponse).
//
//  Chaque carte a un chiffre-choc optionnel, un CTA,
//  un deeplink, et des metadata compliance (source, disclaimer).
// ────────────────────────────────────────────────────────────

/// Les 10 types de Response Card — enum definitif.
enum ResponseCardType {
  retraite,
  budget,
  threeA,
  lpp,
  fiscal,
  couple,
  avs,
  epl,
  assurance,
  alerte,
}

/// Urgence d'affichage (couleur de bordure).
enum CardUrgency {
  critical, // rouge — action immediate
  high, // orange — action recommandee
  medium, // bleu — informatif important
  low, // gris — contexte
}

/// Une Response Card complete.
class ResponseCard {
  /// Type de carte (determine le template visuel).
  final ResponseCardType type;

  /// Titre court (max 40 chars).
  final String title;

  /// Sous-titre explicatif (max 80 chars).
  final String subtitle;

  /// Chiffre-choc optionnel (ex: "CHF 34'200").
  final String? chiffreChoc;

  /// Legende du chiffre-choc (ex: "economie fiscale potentielle").
  final String? chiffreChocLabel;

  /// Texte du bouton CTA (ex: "Simuler mon 3a").
  final String ctaLabel;

  /// Route GoRouter pour le CTA.
  final String ctaRoute;

  /// Urgence (affecte la couleur de bordure).
  final CardUrgency urgency;

  /// Icone Material.
  final IconData icon;

  /// Reference legale (ex: "LPP art. 79b").
  final String? source;

  /// Jours avant echeance (null si pas de deadline).
  final int? deadlineDays;

  /// Impact estime en CHF (null si non quantifiable).
  final double? impactChf;

  /// Impact en points de visibilite (0 si non applicable).
  final int impactPoints;

  /// Identifiant unique (lie au CoachingTip.id si origine tip).
  final String id;

  /// Categorie pour le filtrage (prevoyance, fiscalite, budget, etc.).
  final String category;

  const ResponseCard({
    required this.type,
    required this.title,
    required this.subtitle,
    this.chiffreChoc,
    this.chiffreChocLabel,
    required this.ctaLabel,
    required this.ctaRoute,
    this.urgency = CardUrgency.medium,
    required this.icon,
    this.source,
    this.deadlineDays,
    this.impactChf,
    this.impactPoints = 0,
    required this.id,
    required this.category,
  });

  /// Couleur de bordure selon l'urgence.
  Color get borderColor {
    switch (urgency) {
      case CardUrgency.critical:
        return const Color(0xFFE53935); // MintColors.error
      case CardUrgency.high:
        return const Color(0xFFFFA726); // MintColors.warning
      case CardUrgency.medium:
        return const Color(0xFF1A73E8); // MintColors.primary
      case CardUrgency.low:
        return const Color(0xFF9E9E9E); // MintColors.textSecondary
    }
  }

  /// Couleur de fond du badge selon l'urgence.
  Color get badgeColor {
    switch (urgency) {
      case CardUrgency.critical:
        return const Color(0xFFFFEBEE);
      case CardUrgency.high:
        return const Color(0xFFFFF3E0);
      case CardUrgency.medium:
        return const Color(0xFFE3F2FD);
      case CardUrgency.low:
        return const Color(0xFFF5F5F5);
    }
  }

  /// Texte du badge deadline (ex: "J-21", "Demain").
  String? get deadlineText {
    if (deadlineDays == null || deadlineDays! < 0) return null;
    if (deadlineDays == 0) return "Aujourd'hui";
    if (deadlineDays == 1) return 'Demain';
    return 'J-$deadlineDays';
  }
}
