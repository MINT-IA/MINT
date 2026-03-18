/// Advisor Matching Service — Sprint S65 (Expert Tier).
///
/// Matches users to human advisors ("spécialistes") by specialization,
/// canton, and language. Prepares anonymized dossiers for consultation.
///
/// Rules (NON-NEGOTIABLE):
/// - Advisors shown as LIST, never RANKED
/// - No "best", "top rated", "optimal" language
/// - Dossier uses RANGES not exact values (privacy)
/// - User must validate dossier before sharing
/// - Disclaimer always present
/// - Term "conseiller" is BANNED — always "spécialiste"
///
/// Outil éducatif — ne constitue pas un conseil financier (LSFin).
library;

import 'package:mint_mobile/models/coach_profile.dart';

// ════════════════════════════════════════════════════════════════
//  ENUMS
// ════════════════════════════════════════════════════════════════

/// Specialization areas for financial advisors ("spécialistes").
enum AdvisorSpecialization {
  succession,
  expat,
  divorce,
  retirement,
  tax,
  mortgage,
  debt,
}

// ════════════════════════════════════════════════════════════════
//  MODELS
// ════════════════════════════════════════════════════════════════

/// Profile of a registered advisor ("spécialiste").
///
/// [displayName] uses title form only ("Me Dupont", "Dr Weber")
/// — no full names for privacy.
class AdvisorProfile {
  final String id;
  final String displayName;
  final List<AdvisorSpecialization> specializations;
  final List<String> languages;
  final List<String> cantons;
  final double rating;
  final bool isAvailable;
  final String? nextAvailableSlot;

  const AdvisorProfile({
    required this.id,
    required this.displayName,
    required this.specializations,
    required this.languages,
    required this.cantons,
    required this.rating,
    required this.isAvailable,
    this.nextAvailableSlot,
  });
}

/// Anonymized dossier prepared for an advisor consultation.
///
/// NEVER contains: exact salary, IBAN, SSN, employer name.
/// Uses ranges: "revenu dans la tranche 100-150k", "patrimoine ~250k".
class AdvisorDossier {
  final String summary;
  final Map<String, String> keyMetrics;
  final List<String> questionsForAdvisor;
  final String disclaimer;

  const AdvisorDossier({
    required this.summary,
    required this.keyMetrics,
    required this.questionsForAdvisor,
    required this.disclaimer,
  });
}

// ════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════

/// Matches users with advisors and prepares consultation dossiers.
///
/// All methods are static and pure. No network calls.
class AdvisorMatchingService {
  AdvisorMatchingService._();

  /// Compliance disclaimer included in every dossier.
  static const String _disclaimer =
      'Ce dossier est un résumé éducatif préparé par MINT. '
      'Il ne constitue pas un conseil financier au sens de la LSFin. '
      'Les montants indiqués sont des estimations arrondies. '
      'Vérifie les informations avec ton\u00a0spécialiste.';

  // ── Static advisor pool (mock — replaced by backend in Phase 4) ──

  static const List<AdvisorProfile> _advisorPool = [
    AdvisorProfile(
      id: 'adv_01',
      displayName: 'Me Dupont',
      specializations: [
        AdvisorSpecialization.succession,
        AdvisorSpecialization.divorce,
      ],
      languages: ['fr', 'de'],
      cantons: ['VD', 'GE', 'VS'],
      rating: 4.5,
      isAvailable: true,
    ),
    AdvisorProfile(
      id: 'adv_02',
      displayName: 'Dr Weber',
      specializations: [
        AdvisorSpecialization.tax,
        AdvisorSpecialization.retirement,
      ],
      languages: ['de', 'fr', 'en'],
      cantons: ['ZH', 'BE', 'AG'],
      rating: 4.8,
      isAvailable: true,
    ),
    AdvisorProfile(
      id: 'adv_03',
      displayName: 'Me Rossi',
      specializations: [
        AdvisorSpecialization.expat,
        AdvisorSpecialization.tax,
      ],
      languages: ['fr', 'it', 'en'],
      cantons: ['TI', 'GE', 'VD'],
      rating: 4.3,
      isAvailable: false,
      nextAvailableSlot: '2026-04-15',
    ),
    AdvisorProfile(
      id: 'adv_04',
      displayName: 'Me Favre',
      specializations: [
        AdvisorSpecialization.mortgage,
        AdvisorSpecialization.retirement,
      ],
      languages: ['fr'],
      cantons: ['VS', 'VD', 'FR'],
      rating: 4.6,
      isAvailable: true,
    ),
    AdvisorProfile(
      id: 'adv_05',
      displayName: 'Dr Müller',
      specializations: [
        AdvisorSpecialization.debt,
        AdvisorSpecialization.tax,
      ],
      languages: ['de', 'en'],
      cantons: ['ZH', 'LU', 'SG'],
      rating: 4.4,
      isAvailable: true,
    ),
    AdvisorProfile(
      id: 'adv_06',
      displayName: 'Me Bonvin',
      specializations: [
        AdvisorSpecialization.succession,
        AdvisorSpecialization.retirement,
      ],
      languages: ['fr', 'de'],
      cantons: ['VS', 'BE', 'FR'],
      rating: 4.7,
      isAvailable: true,
    ),
  ];

  // ── Public API ──

  /// Find advisors matching [need], optionally filtered by language.
  ///
  /// Results are sorted **alphabetically** by [displayName] — never ranked.
  /// Returns an empty list if no match found.
  static List<AdvisorProfile> findMatches({
    required CoachProfile profile,
    required AdvisorSpecialization need,
    String? preferredLanguage,
    List<AdvisorProfile>? advisorPool,
  }) {
    final pool = advisorPool ?? _advisorPool;

    var matches = pool.where((a) => a.specializations.contains(need)).toList();

    // Filter by canton if profile has one.
    final canton = profile.canton;
    if (canton.isNotEmpty) {
      final cantonMatches =
          matches.where((a) => a.cantons.contains(canton)).toList();
      if (cantonMatches.isNotEmpty) {
        matches = cantonMatches;
      }
      // If no canton match, keep all specialization matches (broader net).
    }

    // Filter by preferred language if specified.
    if (preferredLanguage != null && preferredLanguage.isNotEmpty) {
      final langMatches = matches
          .where((a) => a.languages.contains(preferredLanguage))
          .toList();
      if (langMatches.isNotEmpty) {
        matches = langMatches;
      }
    }

    // Sort alphabetically — NEVER by rating or ranking.
    matches.sort(
      (a, b) => a.displayName.compareTo(b.displayName),
    );

    return matches;
  }

  /// Prepare an anonymized dossier for an advisor consultation.
  ///
  /// The dossier uses income/patrimoine RANGES (not exact values),
  /// and NEVER includes IBAN, SSN, employer name, or exact salary.
  static Future<AdvisorDossier> prepareDossier({
    required CoachProfile profile,
    required AdvisorSpecialization topic,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final age = effectiveNow.year - profile.birthYear;

    // Income range (rounded to nearest 50k bracket).
    final revenuAnnuel = profile.salaireBrutMensuel * profile.nombreDeMois;
    final incomeRange = _toRange(revenuAnnuel);

    // Patrimoine range.
    final patrimoine = _estimatePatrimoine(profile);
    final patrimoineRange = _toRange(patrimoine);

    // Build key metrics (ranges only).
    final keyMetrics = <String, String>{
      'Âge': '$age ans',
      'Canton': profile.canton,
      'Revenu brut annuel': 'Tranche $incomeRange',
      'Patrimoine estimé': 'Environ $patrimoineRange',
    };

    if (profile.etatCivil == CoachCivilStatus.marie ||
        profile.etatCivil == CoachCivilStatus.concubinage) {
      keyMetrics['Situation familiale'] = profile.etatCivil == CoachCivilStatus.marie
          ? 'Marié·e'
          : 'En concubinage';
    }

    if (profile.nombreEnfants > 0) {
      keyMetrics['Enfants'] = '${profile.nombreEnfants}';
    }

    // Build summary (max 500 chars).
    final summary = _buildSummary(
      age: age,
      canton: profile.canton,
      topic: topic,
      incomeRange: incomeRange,
      patrimoineRange: patrimoineRange,
      archetype: profile.archetype,
    );

    // AI-suggested questions.
    final questions = _suggestQuestions(topic, profile);

    return AdvisorDossier(
      summary: summary,
      keyMetrics: keyMetrics,
      questionsForAdvisor: questions,
      disclaimer: _disclaimer,
    );
  }

  // ── Private helpers ──

  /// Convert an amount to a CHF range string.
  static String _toRange(double amount) {
    if (amount < 50000) return 'CHF\u00a0<\u00a050k';
    if (amount < 100000) return 'CHF\u00a050-100k';
    if (amount < 150000) return 'CHF\u00a0100-150k';
    if (amount < 200000) return 'CHF\u00a0150-200k';
    if (amount < 300000) return 'CHF\u00a0200-300k';
    if (amount < 500000) return 'CHF\u00a0300-500k';
    if (amount < 1000000) return 'CHF\u00a0500k-1M';
    return 'CHF\u00a0>\u00a01M';
  }

  /// Estimate total patrimoine from profile (approximate).
  static double _estimatePatrimoine(CoachProfile profile) {
    final p = profile.patrimoine;
    return p.epargneLiquide + p.investissements + p.immobilierEffectif;
  }

  /// Build a concise summary (max 500 chars).
  static String _buildSummary({
    required int age,
    required String canton,
    required AdvisorSpecialization topic,
    required String incomeRange,
    required String patrimoineRange,
    required FinancialArchetype archetype,
  }) {
    final topicLabel = _topicLabel(topic);
    final archetypeLabel = _archetypeLabel(archetype);

    final buffer = StringBuffer()
      ..write('Profil\u00a0: $archetypeLabel, $age\u00a0ans, canton $canton. ')
      ..write('Revenu brut annuel\u00a0: $incomeRange. ')
      ..write('Patrimoine estimé\u00a0: $patrimoineRange. ')
      ..write('Besoin\u00a0: consultation $topicLabel.');

    final result = buffer.toString();
    // Enforce 500-char limit.
    if (result.length > 500) {
      return '${result.substring(0, 497)}...';
    }
    return result;
  }

  /// Human-readable label for a topic.
  static String _topicLabel(AdvisorSpecialization topic) {
    return switch (topic) {
      AdvisorSpecialization.succession => 'succession',
      AdvisorSpecialization.expat => 'expatriation',
      AdvisorSpecialization.divorce => 'divorce',
      AdvisorSpecialization.retirement => 'retraite',
      AdvisorSpecialization.tax => 'fiscalité',
      AdvisorSpecialization.mortgage => 'hypothèque',
      AdvisorSpecialization.debt => 'gestion de dettes',
    };
  }

  /// Human-readable label for archetype.
  static String _archetypeLabel(FinancialArchetype archetype) {
    return switch (archetype) {
      FinancialArchetype.swissNative => 'Résident·e suisse',
      FinancialArchetype.expatEu => 'Expat EU/AELE',
      FinancialArchetype.expatNonEu => 'Expat hors EU',
      FinancialArchetype.expatUs => 'Résident·e US (FATCA)',
      FinancialArchetype.independentWithLpp => 'Indépendant·e avec LPP',
      FinancialArchetype.independentNoLpp => 'Indépendant·e sans LPP',
      FinancialArchetype.crossBorder => 'Frontalier·ère',
      FinancialArchetype.returningSwiss => 'Suisse de retour',
    };
  }

  /// Suggest relevant questions for the advisor based on topic.
  static List<String> _suggestQuestions(
    AdvisorSpecialization topic,
    CoachProfile profile,
  ) {
    return switch (topic) {
      AdvisorSpecialization.succession => [
        'Quels sont mes droits successoraux selon le CC\u00a0?',
        'Comment protéger mon\u00a0/\u00a0ma conjoint·e en cas de décès\u00a0?',
        'Faut-il envisager un testament ou un pacte successoral\u00a0?',
      ],
      AdvisorSpecialization.expat => [
        'Comment sont totalisées mes années de cotisation AVS à l\'étranger\u00a0?',
        'Quelles conventions bilatérales s\'appliquent à ma situation\u00a0?',
        'Dois-je rapatrier mon libre passage\u00a0?',
      ],
      AdvisorSpecialization.divorce => [
        'Comment se fait le partage de la LPP en cas de divorce\u00a0?',
        'Quel impact sur ma rente AVS\u00a0?',
        'Comment recalculer mon budget post-divorce\u00a0?',
      ],
      AdvisorSpecialization.retirement => [
        'Rente ou capital\u00a0: quelle option correspond à ma situation\u00a0?',
        'Quel est le montant de rachat LPP qui serait fiscalement intéressant\u00a0?',
        'À quel âge puis-je envisager une retraite anticipée\u00a0?',
      ],
      AdvisorSpecialization.tax => [
        'Quelles déductions fiscales pourrais-je encore exploiter\u00a0?',
        'Comment étaler mes retraits de capital pour réduire l\'impôt\u00a0?',
        'Quel est l\'impact d\'un rachat LPP sur ma charge fiscale\u00a0?',
      ],
      AdvisorSpecialization.mortgage => [
        'Quel montant hypothécaire pourrait être accessible dans ma situation\u00a0?',
        'Amortissement direct ou indirect\u00a0: quels scénarios envisager\u00a0?',
        'Puis-je utiliser mon 2e pilier pour l\'apport\u00a0?',
      ],
      AdvisorSpecialization.debt => [
        'Comment prioriser le remboursement de mes dettes\u00a0?',
        'Existe-t-il des solutions de consolidation adaptées\u00a0?',
        'Quelles protections légales existent en cas de difficulté financière\u00a0?',
      ],
    };
  }
}
