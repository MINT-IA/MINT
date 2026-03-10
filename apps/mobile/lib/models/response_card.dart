import 'package:flutter/material.dart';

// ────────────────────────────────────────────────────────────
//  RESPONSE CARD MODEL — Phase 1 / Pulse Dynamic Cards
// ────────────────────────────────────────────────────────────
//
//  Modele unifie pour les cartes contextuelles du dashboard Pulse
//  et du chat Coach. Chaque carte porte :
//    - Un type (10 categories)
//    - Un chiffre-choc (impactful number)
//    - Un CTA (call-to-action educatif)
//    - Un urgency level (deadline-driven)
//    - Compliance data (disclaimer, sources)
//
//  Aucun terme banni. CTA educatifs uniquement.
// ────────────────────────────────────────────────────────────

/// Les 10 types de Response Cards.
enum ResponseCardType {
  /// Rachat LPP — potentiel d'economie fiscale.
  lppBuyback,

  /// Versement 3a — deadline annuelle.
  pillar3a,

  /// Taux de remplacement — projection retraite.
  replacementRate,

  /// Rente vs capital — breakeven analysis.
  renteVsCapital,

  /// Lacune AVS — annees manquantes.
  avsGap,

  /// Fiscalite — deductions possibles.
  taxOptimization,

  /// Couple — alerte point faible partenaire.
  coupleAlert,

  /// Patrimoine — diversification / liquidite.
  patrimoine,

  /// Hypotheque — capacite d'achat ou refinancement.
  mortgage,

  /// Independant — couverture lacunaire.
  independant,
}

/// Niveau d'urgence d'une carte.
enum CardUrgency {
  /// Aucune echeance proche.
  low,

  /// Echeance dans 1-3 mois.
  medium,

  /// Echeance imminente (< 1 mois) ou action critique.
  high,
}

/// Un chiffre-choc avec son explication.
class ChiffreChoc {
  /// Le nombre impactant (ex: 12'450).
  final double value;

  /// Unite / suffixe (ex: "CHF", "CHF/an", "%", "ans").
  final String unit;

  /// Phrase explicative courte.
  final String explanation;

  const ChiffreChoc({
    required this.value,
    required this.unit,
    required this.explanation,
  });

  /// Formattage Suisse : 12'450 CHF
  String get formatted {
    if (unit == '%') {
      return '${value.toStringAsFixed(1)}%';
    }
    if (unit == 'ans' || unit == 'mois') {
      return '${value.toStringAsFixed(0)} $unit';
    }
    // CHF formatting with Swiss apostrophe
    final intPart = value.round().abs();
    final sign = value < 0 ? '-' : '';
    final str = intPart.toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write("'");
      buf.write(str[i]);
    }
    return '$sign$buf $unit'.trim();
  }

  Map<String, dynamic> toJson() => {
        'value': value,
        'unit': unit,
        'explanation': explanation,
      };

  factory ChiffreChoc.fromJson(Map<String, dynamic> json) => ChiffreChoc(
        value: (json['value'] as num).toDouble(),
        unit: json['unit'] as String,
        explanation: json['explanation'] as String,
      );
}

/// CTA educatif (call-to-action).
class CardCta {
  /// Texte du bouton (ex: "Simuler un rachat").
  final String label;

  /// Route GoRouter (ex: "/lpp-deep/rachat").
  final String route;

  /// Icone optionnel.
  final String? icon;

  const CardCta({
    required this.label,
    required this.route,
    this.icon,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'route': route,
        if (icon != null) 'icon': icon,
      };

  factory CardCta.fromJson(Map<String, dynamic> json) => CardCta(
        label: json['label'] as String,
        route: json['route'] as String,
        icon: json['icon'] as String?,
      );
}

/// Response Card — carte contextuelle dynamique.
class ResponseCard {
  /// Identifiant unique de la carte.
  final String id;

  /// Type de carte (determine le style visuel).
  final ResponseCardType type;

  /// Titre principal (ex: "Rachat LPP").
  final String title;

  /// Sous-titre contextuel (ex: "Economie fiscale estimee").
  final String subtitle;

  /// Chiffre-choc impactant.
  final ChiffreChoc chiffreChoc;

  /// CTA educatif.
  final CardCta cta;

  /// Urgence (drive le badge deadline).
  final CardUrgency urgency;

  /// Date limite optionnelle (ex: "31.12.2026").
  final DateTime? deadline;

  /// Disclaimer obligatoire.
  final String disclaimer;

  /// Sources legales.
  final List<String> sources;

  /// Alertes (seuils depasses, etc.).
  final List<String> alertes;

  /// Points d'impact sur le score de visibilite.
  final int impactPoints;

  /// Categorie pour le filtrage (prevoyance, fiscalite, budget, etc.).
  final String category;

  /// Impact estime en CHF (null si non quantifiable).
  final double? impactChf;

  /// Icone Material optionnelle.
  final IconData? icon;

  const ResponseCard({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.chiffreChoc,
    required this.cta,
    this.urgency = CardUrgency.low,
    this.deadline,
    required this.disclaimer,
    this.sources = const [],
    this.alertes = const [],
    this.impactPoints = 0,
    this.category = '',
    this.impactChf,
    this.icon,
  });

  /// Nombre de jours avant la deadline (null si pas de deadline).
  int? get daysUntilDeadline {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now()).inDays;
  }

  /// Texte du badge deadline.
  String? get deadlineBadge {
    final days = daysUntilDeadline;
    if (days == null) return null;
    if (days <= 0) return 'Expire';
    if (days == 1) return 'Demain';
    if (days <= 30) return 'J-$days';
    final months = (days / 30).round();
    return '$months mois';
  }

  /// Couleur de bordure selon l'urgence.
  Color get borderColor {
    switch (urgency) {
      case CardUrgency.high:
        return const Color(0xFFE53935);
      case CardUrgency.medium:
        return const Color(0xFF1A73E8);
      case CardUrgency.low:
        return const Color(0xFF9E9E9E);
    }
  }

  /// Couleur de fond du badge selon l'urgence.
  Color get badgeColor {
    switch (urgency) {
      case CardUrgency.high:
        return const Color(0xFFFFEBEE);
      case CardUrgency.medium:
        return const Color(0xFFE3F2FD);
      case CardUrgency.low:
        return const Color(0xFFF5F5F5);
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        'chiffreChoc': chiffreChoc.toJson(),
        'cta': cta.toJson(),
        'urgency': urgency.name,
        if (deadline != null) 'deadline': deadline!.toIso8601String(),
        'disclaimer': disclaimer,
        'sources': sources,
        'alertes': alertes,
        'impactPoints': impactPoints,
        if (category.isNotEmpty) 'category': category,
        if (impactChf != null) 'impactChf': impactChf,
      };
}
