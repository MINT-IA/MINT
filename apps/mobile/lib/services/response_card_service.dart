import 'package:flutter/material.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/dashboard_curator_service.dart';

// ────────────────────────────────────────────────────────────
//  RESPONSE CARD SERVICE — Phase 1 (S50-S51)
// ────────────────────────────────────────────────────────────
//
//  Genere les ResponseCards a partir du profil utilisateur.
//  Reutilise CoachingService pour les tips et
//  DashboardCuratorService pour l'urgence/deadline.
//
//  10 templates : retraite, budget, threeA, lpp, fiscal,
//  couple, avs, epl, assurance, alerte.
// ────────────────────────────────────────────────────────────

class ResponseCardService {
  ResponseCardService._();

  /// Genere les cartes les plus pertinentes pour le profil.
  ///
  /// Retourne max [limit] cartes, triees par urgence puis impact.
  static List<ResponseCard> generate({
    required CoachProfile profile,
    int limit = 4,
  }) {
    final cards = <ResponseCard>[];

    // ── Cartes basees sur les coaching tips ──────────────
    final tips = CoachingService.generateTips(
      profile: profile.toCoachingProfile(),
    );

    for (final tip in tips) {
      final card = _fromCoachingTip(tip, profile);
      if (card != null) cards.add(card);
    }

    // ── Cartes structurelles (couple, retraite, assurance) ─
    cards.addAll(_structuralCards(profile, tips));

    // ── Deduplication par type (1 carte max par type) ─────
    final seen = <ResponseCardType>{};
    final deduped = <ResponseCard>[];
    for (final card in cards) {
      if (seen.add(card.type)) deduped.add(card);
    }

    // ── Tri : critical > high > medium > low, puis impact ─
    deduped.sort((a, b) {
      final urgComp = a.urgency.index.compareTo(b.urgency.index);
      if (urgComp != 0) return urgComp;
      return (b.impactChf ?? 0).compareTo(a.impactChf ?? 0);
    });

    return deduped.take(limit).toList();
  }

  /// Genere les cartes pour un contexte chat (filtrees par topic).
  static List<ResponseCard> forChatTopic({
    required CoachProfile profile,
    required String topic,
  }) {
    final all = generate(profile: profile, limit: 10);
    final topicType = _topicToType(topic);
    if (topicType == null) return all.take(2).toList();

    final matched = all.where((c) => c.type == topicType).toList();
    if (matched.isNotEmpty) return matched;

    // Fallback : cartes de la meme categorie
    final category = _topicToCategory(topic);
    return all
        .where((c) => c.category == category)
        .take(2)
        .toList();
  }

  /// Suggested prompts personnalisees basees sur le profil.
  static List<String> suggestedPrompts({
    required CoachProfile profile,
    int limit = 4,
  }) {
    final prompts = <_ScoredPrompt>[];
    final now = DateTime.now();
    final age = now.year - profile.birthYear;

    // ── Toujours pertinent ──────────────────────────────
    prompts.add(_ScoredPrompt('Ma trajectoire retraite', 50));

    // ── Age-driven ──────────────────────────────────────
    if (age >= 50) {
      prompts.add(_ScoredPrompt('Quand partir a la retraite ?', 90));
      prompts.add(_ScoredPrompt('Rente ou capital ?', 85));
    }
    if (age >= 45 && age < 55) {
      prompts.add(_ScoredPrompt('Faut-il racheter ma LPP ?', 80));
    }
    if (age < 35) {
      prompts.add(_ScoredPrompt('Comment bien demarrer mon 3a ?', 75));
    }

    // ── Profile gaps ────────────────────────────────────
    if (profile.prevoyance.avoirLppTotal == null) {
      prompts.add(_ScoredPrompt('Combien vaut ma LPP ?', 70));
    }
    if ((profile.prevoyance.totalEpargne3a ?? 0) <= 0) {
      prompts.add(_ScoredPrompt('Dois-je ouvrir un 3a ?', 65));
    }

    // ── Couple ──────────────────────────────────────────
    if (profile.isCouple) {
      prompts.add(_ScoredPrompt(
        'Notre situation couple',
        60,
      ));
      if (profile.conjoint?.nationality == 'US') {
        prompts.add(_ScoredPrompt('Impact FATCA sur notre couple', 88));
      }
    }

    // ── Archetype-driven ────────────────────────────────
    if (profile.nationality == 'US' ||
        (profile.conjoint?.isFatcaResident ?? false)) {
      prompts.add(_ScoredPrompt('Mes obligations FATCA', 85));
    }
    if (profile.employmentStatus == 'independant') {
      prompts.add(_ScoredPrompt('Ma prevoyance independant', 82));
    }

    // ── Temporal (calendar-driven) ──────────────────────
    if (now.month >= 10) {
      prompts.add(_ScoredPrompt(
        'Mon versement 3a avant le 31 decembre',
        95,
      ));
    }
    if (now.month >= 1 && now.month <= 3) {
      prompts.add(_ScoredPrompt('Mes deductions fiscales', 92));
    }

    // ── Tri et dedup ────────────────────────────────────
    prompts.sort((a, b) => b.score.compareTo(a.score));
    return prompts.take(limit).map((p) => p.text).toList();
  }

  // ──────────────────────────────────────────────────────
  //  PRIVATE : CoachingTip → ResponseCard
  // ──────────────────────────────────────────────────────

  static ResponseCard? _fromCoachingTip(
      CoachingTip tip, CoachProfile profile) {
    final type = _tipIdToType(tip.id);
    if (type == null) return null;

    final urgency = DashboardCuratorService.computeAlertUrgency(tip);
    final deadlineDays = DashboardCuratorService.getDeadlineDaysForTip(tip);

    return ResponseCard(
      id: tip.id,
      type: type,
      title: tip.title,
      subtitle: tip.narrativeMessage ?? tip.message,
      chiffreChoc: tip.estimatedImpactChf != null
          ? _formatChf(tip.estimatedImpactChf!)
          : null,
      chiffreChocLabel: tip.estimatedImpactChf != null
          ? 'impact estime'
          : null,
      ctaLabel: tip.action,
      ctaRoute: _routeForTip(tip),
      urgency: _alertToCardUrgency(urgency),
      icon: tip.icon,
      source: tip.source,
      deadlineDays: deadlineDays,
      impactChf: tip.estimatedImpactChf,
      impactPoints: _impactPointsForCategory(tip.category),
      category: tip.category,
    );
  }

  // ──────────────────────────────────────────────────────
  //  PRIVATE : Cartes structurelles
  // ──────────────────────────────────────────────────────

  static List<ResponseCard> _structuralCards(
      CoachProfile profile, List<CoachingTip> tips) {
    final cards = <ResponseCard>[];
    final tipIds = tips.map((t) => t.id).toSet();

    // ── Carte Couple (si couple + conjoint renseigne) ───
    if (profile.isCouple && profile.conjoint != null) {
      final conjName = profile.conjoint!.firstName ?? 'ton conjoint';
      cards.add(ResponseCard(
        id: 'couple_overview',
        type: ResponseCardType.couple,
        title: 'Votre situation couple',
        subtitle: 'Compare ta visibilite avec $conjName',
        ctaLabel: 'Voir le couple',
        ctaRoute: '/profile/bilan',
        urgency: CardUrgency.medium,
        icon: Icons.people_outline,
        category: 'couple',
        impactPoints: 10,
      ));
    }

    // ── Carte Retraite (si pas deja via tip) ────────────
    final now = DateTime.now();
    final age = now.year - profile.birthYear;
    if (age >= 45 && !tipIds.contains('retirement_countdown')) {
      final targetAge = profile.targetRetirementAge ?? 65;
      final moisRestants = (targetAge - age) * 12;
      cards.add(ResponseCard(
        id: 'retraite_horizon',
        type: ResponseCardType.retraite,
        title: 'Ta retraite dans $moisRestants mois',
        subtitle: 'Explore tes scenarios de depart',
        chiffreChoc: '$moisRestants mois',
        chiffreChocLabel: 'avant ta retraite',
        ctaLabel: 'Voir ma trajectoire',
        ctaRoute: '/retirement',
        urgency: age >= 55 ? CardUrgency.high : CardUrgency.medium,
        icon: Icons.beach_access_outlined,
        category: 'retraite',
        impactPoints: 15,
      ));
    }

    // ── Carte Assurance (si pas de donnees assurance) ───
    if (profile.depenses.assuranceMaladie <= 0) {
      cards.add(ResponseCard(
        id: 'assurance_missing',
        type: ResponseCardType.assurance,
        title: 'Assurance maladie',
        subtitle: 'Ajoute tes primes LAMal pour un bilan complet',
        ctaLabel: 'Renseigner',
        ctaRoute: '/profile/bilan',
        urgency: CardUrgency.low,
        icon: Icons.health_and_safety_outlined,
        source: 'LAMal',
        category: 'assurance',
        impactPoints: 5,
      ));
    }

    return cards;
  }

  // ──────────────────────────────────────────────────────
  //  PRIVATE : Mapping helpers
  // ──────────────────────────────────────────────────────

  static ResponseCardType? _tipIdToType(String id) {
    return switch (id) {
      'deadline_3a' || 'missing_3a' || '3a_not_maxed' => ResponseCardType.threeA,
      'lpp_buyback' => ResponseCardType.lpp,
      'tax_deadline' => ResponseCardType.fiscal,
      'retirement_countdown' => ResponseCardType.retraite,
      'emergency_fund' || 'budget_missing' || 'budget_drift' =>
        ResponseCardType.budget,
      'debt_ratio' => ResponseCardType.alerte,
      'age_milestone' => ResponseCardType.retraite,
      'part_time_gap' => ResponseCardType.avs,
      'independent_alert' => ResponseCardType.lpp,
      _ => null,
    };
  }

  static String _routeForTip(CoachingTip tip) {
    return switch (tip.id) {
      'deadline_3a' || 'missing_3a' || '3a_not_maxed' => '/simulator/3a',
      'lpp_buyback' || 'independent_alert' => '/lpp-deep/rachat',
      'tax_deadline' => '/profile/bilan',
      'retirement_countdown' || 'age_milestone' => '/retirement',
      'emergency_fund' => '/budget',
      'budget_missing' || 'budget_drift' => '/budget',
      'debt_ratio' => '/budget',
      'part_time_gap' => '/profile/bilan',
      _ => '/profile/bilan',
    };
  }

  static CardUrgency _alertToCardUrgency(AlertUrgency alert) {
    return switch (alert) {
      AlertUrgency.urgent => CardUrgency.critical,
      AlertUrgency.active => CardUrgency.high,
      AlertUrgency.info => CardUrgency.medium,
    };
  }

  static int _impactPointsForCategory(String category) {
    return switch (category) {
      'prevoyance' => 15,
      'fiscalite' => 12,
      'retraite' => 15,
      'budget' => 10,
      _ => 8,
    };
  }

  static ResponseCardType? _topicToType(String topic) {
    final lower = topic.toLowerCase();
    if (lower.contains('retraite') || lower.contains('pension')) {
      return ResponseCardType.retraite;
    }
    if (lower.contains('3a') || lower.contains('pilier')) {
      return ResponseCardType.threeA;
    }
    if (lower.contains('lpp') || lower.contains('rachat')) {
      return ResponseCardType.lpp;
    }
    if (lower.contains('impot') || lower.contains('fiscal') ||
        lower.contains('deduction')) {
      return ResponseCardType.fiscal;
    }
    if (lower.contains('budget') || lower.contains('depense')) {
      return ResponseCardType.budget;
    }
    if (lower.contains('couple') || lower.contains('conjoint')) {
      return ResponseCardType.couple;
    }
    if (lower.contains('avs')) return ResponseCardType.avs;
    if (lower.contains('epl') || lower.contains('immobilier')) {
      return ResponseCardType.epl;
    }
    if (lower.contains('assurance') || lower.contains('lamal')) {
      return ResponseCardType.assurance;
    }
    return null;
  }

  static String _topicToCategory(String topic) {
    final lower = topic.toLowerCase();
    if (lower.contains('retraite')) return 'retraite';
    if (lower.contains('3a') || lower.contains('lpp')) return 'prevoyance';
    if (lower.contains('impot') || lower.contains('fiscal')) {
      return 'fiscalite';
    }
    return 'budget';
  }

  static String _formatChf(double amount) {
    if (amount >= 1000) {
      final rounded = (amount / 100).round() * 100;
      final parts = rounded.toString().split('.');
      final intPart = parts[0];
      final formatted = StringBuffer();
      for (var i = 0; i < intPart.length; i++) {
        if (i > 0 && (intPart.length - i) % 3 == 0) {
          formatted.write("'");
        }
        formatted.write(intPart[i]);
      }
      return 'CHF $formatted';
    }
    return 'CHF ${amount.round()}';
  }
}

class _ScoredPrompt {
  final String text;
  final int score;
  const _ScoredPrompt(this.text, this.score);
}
