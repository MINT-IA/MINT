/// Generates prioritized questions to ask the partner based on estimation gaps.
///
/// COUP-02: Template-based, ordered by projection impact.
/// Questions are NOT LLM-generated — they are deterministic templates
/// so they can be displayed without network or latency.
library;

import 'package:mint_mobile/services/partner_estimate_service.dart';

/// A single question the user can ask their partner.
class CoupleQuestion {
  final String field; // e.g. 'estimated_salary'
  final String question; // French text to display
  final String impact; // Why this matters
  final int priority; // 1 = highest impact

  const CoupleQuestion({
    required this.field,
    required this.question,
    required this.impact,
    required this.priority,
  });
}

/// Generator for gap-based couple questions.
///
/// Priority order: salary > age > LPP > 3a > canton
/// (descending impact on couple projections).
class CoupleQuestionGenerator {
  static const _templates = <String, CoupleQuestion>{
    'estimated_salary': CoupleQuestion(
      field: 'estimated_salary',
      question: 'Quel est son salaire brut annuel\u00a0?',
      impact:
          'Impact direct sur la rente AVS couple et la capacit\u00e9 hypoth\u00e9caire.',
      priority: 1,
    ),
    'estimated_age': CoupleQuestion(
      field: 'estimated_age',
      question: 'Quel \u00e2ge a-t-il/elle\u00a0?',
      impact:
          'D\u00e9termine l\u2019horizon retraite et les bonifications LPP.',
      priority: 2,
    ),
    'estimated_lpp': CoupleQuestion(
      field: 'estimated_lpp',
      question:
          '\u00c0 combien estime-t-il/elle son avoir LPP\u00a0?',
      impact:
          'Affine la projection de rente couple et les options de rachat.',
      priority: 3,
    ),
    'estimated_3a': CoupleQuestion(
      field: 'estimated_3a',
      question: 'Combien a-t-il/elle en 3e pilier\u00a0?',
      impact:
          'Optimise la strat\u00e9gie de retrait \u00e9chelonn\u00e9 (fiscal).',
      priority: 4,
    ),
    'estimated_canton': CoupleQuestion(
      field: 'estimated_canton',
      question:
          'Dans quel canton est-il/elle domicili\u00e9\u00b7e\u00a0?',
      impact:
          'Les taux d\u2019imposition varient fortement entre cantons.',
      priority: 5,
    ),
  };

  /// Generate questions for missing fields, ordered by priority.
  static List<CoupleQuestion> generate(PartnerEstimate estimate) {
    return estimate.missingFields
        .map((field) => _templates[field])
        .whereType<CoupleQuestion>()
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Generate all 5 questions (for initial couple declaration).
  static List<CoupleQuestion> generateAll() {
    return _templates.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }
}
