import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/fallback_templates.dart';

// ────────────────────────────────────────────────────────────
//  FALLBACK TEMPLATES TESTS — Sprint S35 / Coach Narrative
// ────────────────────────────────────────────────────────────
//
// Tests cover:
//   1. greeting: same-day return
//   2. greeting: recent visit (< 7 days)
//   3. greeting: 3a_deadline fiscal season
//   4. greeting: tax_declaration fiscal season
//   5. greeting: positive friDelta
//   6. greeting: negative friDelta
//   7. greeting: default (score display)
//   8. greeting: no firstName
//   9. scoreSummary: positive trend
//  10. scoreSummary: negative trend
//  11. scoreSummary: stable
//  12. tipNarrative: tax optimization lever
//  13. tipNarrative: liquidity alert
//  14. tipNarrative: retirement gap
//  15. tipNarrative: default enrichment
//  16. premierEclairageReframe: certified data
//  17. premierEclairageReframe: no certified data
//  18. enrichmentGuide: all block types
//  19. fatcaGuidance: expat_us archetype
//  20. fatcaGuidance: non-US archetype
//  21. successionPlanning: with canton
//  22. librePassageGuide: content check
//  23. disabilityBridge: young user
//  24. COMPLIANCE: no banned terms in any template
// ────────────────────────────────────────────────────────────

/// Helper to build a CoachContext with overrides.
CoachContext _ctx({
  String firstName = 'Julien',
  int age = 49,
  String canton = 'VS',
  String archetype = 'swiss_native',
  double friTotal = 72,
  double friDelta = 0,
  String primaryFocus = 'retirement',
  int daysSinceLastVisit = 14,
  String fiscalSeason = '',
  Map<String, double> knownValues = const {},
  Map<String, String> dataReliability = const {},
}) {
  return CoachContext(
    firstName: firstName,
    age: age,
    canton: canton,
    archetype: archetype,
    friTotal: friTotal,
    friDelta: friDelta,
    primaryFocus: primaryFocus,
    daysSinceLastVisit: daysSinceLastVisit,
    fiscalSeason: fiscalSeason,
    knownValues: knownValues,
    dataReliability: dataReliability,
  );
}

/// Banned terms per CLAUDE.md compliance rules.
const _bannedTerms = [
  'garanti',
  'certain',
  'sans risque',
  'optimal',
  'meilleur',
  'parfait',
  'conseiller', // must use "specialiste"
];

/// Check that a text does not contain any banned term.
void _assertNoBannedTerms(String text, String context) {
  final lower = text.toLowerCase();
  for (final term in _bannedTerms) {
    // Use word boundary to avoid false positives (e.g., "certaines" ≠ "certain")
    final pattern = RegExp('\\b${RegExp.escape(term)}\\b');
    expect(
      pattern.hasMatch(lower),
      isFalse,
      reason: 'Banned term "$term" found in $context: "$text"',
    );
  }
}

void main() {
  // ═══════════════════════════════════════════════════════════
  // GREETING
  // ═══════════════════════════════════════════════════════════

  group('FallbackTemplates.greeting', () {
    test('same-day return includes "Bon retour"', () {
      final result = FallbackTemplates.greeting(
        _ctx(daysSinceLastVisit: 0),
      );
      expect(result, contains('Bon retour'));
      expect(result, contains('Julien'));
    });

    test('same-day return without name', () {
      final result = FallbackTemplates.greeting(
        _ctx(firstName: '', daysSinceLastVisit: 0),
      );
      expect(result, 'Bon retour.');
    });

    test('recent visit (< 7 days) includes "Content de te revoir"', () {
      final result = FallbackTemplates.greeting(
        _ctx(daysSinceLastVisit: 3),
      );
      expect(result, contains('Content de te revoir'));
      expect(result, contains('Julien'));
    });

    test('3a_deadline fiscal season mentions 3a', () {
      final result = FallbackTemplates.greeting(
        _ctx(daysSinceLastVisit: 30, fiscalSeason: '3a_deadline'),
      );
      expect(result, contains('3a'));
      expect(result, contains('fin de l\'ann'));
    });

    test('tax_declaration fiscal season mentions declaration', () {
      final result = FallbackTemplates.greeting(
        _ctx(daysSinceLastVisit: 30, fiscalSeason: 'tax_declaration'),
      );
      expect(result, contains('d\u00e9claration fiscale'));
    });

    test('positive friDelta shows gain', () {
      final result = FallbackTemplates.greeting(
        _ctx(daysSinceLastVisit: 14, friDelta: 5),
      );
      expect(result, contains('+5'));
      expect(result, contains('points'));
    });

    test('negative friDelta shows loss', () {
      final result = FallbackTemplates.greeting(
        _ctx(daysSinceLastVisit: 14, friDelta: -3),
      );
      expect(result, contains('-3'));
      expect(result, contains('points'));
    });

    test('default greeting shows enrichment or fallback', () {
      final result = FallbackTemplates.greeting(
        _ctx(daysSinceLastVisit: 14, friDelta: 0, friTotal: 72),
      );
      // Default greeting now shows enrichment action or minimal fallback
      // instead of a bare score.
      expect(result, isNotEmpty);
      expect(result, contains('Julien'));
    });

    test('no firstName uses generic greeting', () {
      final result = FallbackTemplates.greeting(
        _ctx(firstName: '', daysSinceLastVisit: 14, friDelta: 0, friTotal: 50),
      );
      expect(result, startsWith('Bonjour.'));
      expect(result, isNot(contains('Julien')));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // SCORE SUMMARY
  // ═══════════════════════════════════════════════════════════

  group('FallbackTemplates.scoreSummary', () {
    test('positive trend shows "En progression"', () {
      final result = FallbackTemplates.scoreSummary(
        _ctx(friTotal: 72, friDelta: 5),
      );
      expect(result, contains('En progression'));
      expect(result, contains('5'));
      expect(result, contains('72/100'));
    });

    test('negative trend shows "En recul"', () {
      final result = FallbackTemplates.scoreSummary(
        _ctx(friTotal: 65, friDelta: -3),
      );
      expect(result, contains('En recul'));
      expect(result, contains('3'));
    });

    test('zero delta shows "Stable"', () {
      final result = FallbackTemplates.scoreSummary(
        _ctx(friTotal: 72, friDelta: 0),
      );
      expect(result, contains('Stable'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // TIP NARRATIVE
  // ═══════════════════════════════════════════════════════════

  group('FallbackTemplates.tipNarrative', () {
    test('tax optimization lever (> 1000 CHF) mentions 3a', () {
      final result = FallbackTemplates.tipNarrative(
        _ctx(knownValues: {'tax_saving': 2500}),
      );
      expect(result, contains('3a'));
      expect(result, contains("2'500"));
      expect(result, contains('imp\u00f4t'));
    });

    test('liquidity alert (< 3 months)', () {
      final result = FallbackTemplates.tipNarrative(
        _ctx(knownValues: {'months_liquidity': 1.5}),
      );
      expect(result, contains('1.5'));
      expect(result, contains('mois'));
      expect(result, contains('liquidit'));
    });

    test('retirement gap (replacement ratio < 55%)', () {
      final result = FallbackTemplates.tipNarrative(
        _ctx(
          knownValues: {
            'tax_saving': 0,
            'months_liquidity': 6,
            'replacement_ratio': 48,
          },
        ),
      );
      expect(result, contains('48'));
      expect(result, contains('taux de remplacement'));
    });

    test('default: enrichment prompt when all metrics OK', () {
      final result = FallbackTemplates.tipNarrative(
        _ctx(
          friTotal: 72,
          knownValues: {
            'tax_saving': 500,
            'months_liquidity': 6,
            'replacement_ratio': 65,
          },
        ),
      );
      // Should contain enrichment action or contextual fallback
      expect(result, isNotEmpty);
      expect(
        result.contains('LPP') || result.contains('AVS') || result.contains('projections'),
        isTrue,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // CHIFFRE CHOC REFRAME
  // ═══════════════════════════════════════════════════════════

  group('FallbackTemplates.premierEclairageReframe', () {
    test('certified data mentions confidence and certification', () {
      final result = FallbackTemplates.premierEclairageReframe(
        _ctx(
          knownValues: {'confidence_score': 85},
          dataReliability: {'avoirLpp': 'certified'},
        ),
      );
      expect(result, contains('certifi\u00e9es'));
      expect(result, contains('85'));
    });

    test('no certified data shows confidence and enrichment', () {
      final result = FallbackTemplates.premierEclairageReframe(
        _ctx(
          knownValues: {'confidence_score': 40},
          dataReliability: {'avoirLpp': 'estimated'},
        ),
      );
      expect(result, contains('40'));
      // Should suggest enrichment
      expect(
        result.contains('profil') || result.contains('LPP') || result.contains('pr\u00e9cise'),
        isTrue,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // ENRICHMENT GUIDE
  // ═══════════════════════════════════════════════════════════

  group('FallbackTemplates.enrichmentGuide', () {
    test('lpp block type mentions certificat LPP', () {
      final result = FallbackTemplates.enrichmentGuide(_ctx(), 'lpp');
      expect(result, contains('LPP'));
      expect(result, contains('certificat'));
    });

    test('avs block type mentions extrait AVS', () {
      final result = FallbackTemplates.enrichmentGuide(_ctx(), 'avs');
      expect(result, contains('AVS'));
      expect(result, contains('extrait'));
    });

    test('3a block type mentions 3a', () {
      final result = FallbackTemplates.enrichmentGuide(_ctx(), '3a');
      expect(result, contains('3a'));
    });

    test('patrimoine block type mentions patrimoine', () {
      final result = FallbackTemplates.enrichmentGuide(_ctx(), 'patrimoine');
      expect(result, anyOf(contains('patrimoine'), contains('\u00e9pargne')));
    });

    test('fiscalite block type mentions commune', () {
      final result = FallbackTemplates.enrichmentGuide(_ctx(), 'fiscalite');
      expect(result, contains('commune'));
    });

    test('objectifRetraite block type mentions age', () {
      final result =
          FallbackTemplates.enrichmentGuide(_ctx(), 'objectifRetraite');
      expect(result, anyOf(contains('retraite'), contains('travailler')));
    });

    test('compositionMenage block type mentions couple', () {
      final result =
          FallbackTemplates.enrichmentGuide(_ctx(), 'compositionMenage');
      expect(result, contains('couple'));
    });

    test('unknown block type returns generic message', () {
      final result =
          FallbackTemplates.enrichmentGuide(_ctx(), 'unknownBlock');
      expect(result, contains('projections'));
    });

    test('avs block for expat archetype mentions expat', () {
      final result = FallbackTemplates.enrichmentGuide(
        _ctx(archetype: 'expat_eu'),
        'avs',
      );
      expect(result, contains('expatri\u00e9'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // FATCA GUIDANCE
  // ═══════════════════════════════════════════════════════════

  group('FallbackTemplates.fatcaGuidance', () {
    test('expat_us archetype mentions FATCA and IRS', () {
      final result = FallbackTemplates.fatcaGuidance(
        _ctx(archetype: 'expat_us', firstName: 'Lauren'),
      );
      expect(result, contains('FATCA'));
      expect(result, contains('IRS'));
      expect(result, contains('Lauren'));
      expect(result, contains('PFIC'));
      // Uses "specialiste" not "conseiller"
      expect(result, contains('sp\u00e9cialiste'));
      expect(result, isNot(contains('conseiller')));
    });

    test('non-US archetype gives generic nationality message', () {
      final result = FallbackTemplates.fatcaGuidance(
        _ctx(archetype: 'swiss_native'),
      );
      expect(result, isNot(contains('FATCA')));
      expect(result, contains('sp\u00e9cialiste'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // SUCCESSION PLANNING
  // ═══════════════════════════════════════════════════════════

  group('FallbackTemplates.successionPlanning', () {
    test('includes legal references CC art. 457', () {
      final result = FallbackTemplates.successionPlanning(_ctx());
      expect(result, contains('CC art. 457'));
      expect(result, contains('LPP art. 20a'));
    });

    test('includes canton-specific note when canton provided', () {
      final result = FallbackTemplates.successionPlanning(_ctx(canton: 'VS'));
      expect(result, contains('VS'));
    });

    test('handles empty canton gracefully', () {
      final result =
          FallbackTemplates.successionPlanning(_ctx(canton: ''));
      // Should not crash or show "canton de "
      expect(result, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // LIBRE PASSAGE
  // ═══════════════════════════════════════════════════════════

  group('FallbackTemplates.librePassageGuide', () {
    test('mentions LFLP and EPL rules', () {
      final result = FallbackTemplates.librePassageGuide(_ctx());
      expect(result, contains('LFLP'));
      expect(result, contains('LPP art. 30c'));
      expect(result, contains('libre passage'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // DISABILITY BRIDGE
  // ═══════════════════════════════════════════════════════════

  group('FallbackTemplates.disabilityBridge', () {
    test('young user (< 55) includes age-specific note', () {
      final result = FallbackTemplates.disabilityBridge(_ctx(age: 35));
      expect(result, contains('35 ans'));
      expect(result, contains('lacune'));
    });

    test('older user (>= 55) omits age-specific note', () {
      final result = FallbackTemplates.disabilityBridge(_ctx(age: 58));
      expect(result, isNot(contains('58 ans, une lacune')));
      expect(result, contains('LAI art. 28'));
    });

    test('includes LPP and AI references', () {
      final result = FallbackTemplates.disabilityBridge(_ctx());
      expect(result, contains('LAI art. 28'));
      expect(result, contains('LPP art. 23'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // COMPLIANCE: NO BANNED TERMS
  // ═══════════════════════════════════════════════════════════

  group('COMPLIANCE: no banned terms in any fallback template', () {
    final baseCtx = _ctx();
    final usCtx = _ctx(archetype: 'expat_us', firstName: 'Lauren');

    test('greeting contains no banned terms', () {
      _assertNoBannedTerms(FallbackTemplates.greeting(baseCtx), 'greeting');
    });

    test('scoreSummary contains no banned terms', () {
      _assertNoBannedTerms(
        FallbackTemplates.scoreSummary(baseCtx),
        'scoreSummary',
      );
    });

    test('tipNarrative contains no banned terms', () {
      _assertNoBannedTerms(
        FallbackTemplates.tipNarrative(baseCtx),
        'tipNarrative',
      );
    });

    test('premierEclairageReframe contains no banned terms', () {
      _assertNoBannedTerms(
        FallbackTemplates.premierEclairageReframe(baseCtx),
        'premierEclairageReframe',
      );
    });

    test('fatcaGuidance (US) contains no banned terms', () {
      _assertNoBannedTerms(
        FallbackTemplates.fatcaGuidance(usCtx),
        'fatcaGuidance (US)',
      );
    });

    test('fatcaGuidance (non-US) contains no banned terms', () {
      _assertNoBannedTerms(
        FallbackTemplates.fatcaGuidance(baseCtx),
        'fatcaGuidance (non-US)',
      );
    });

    test('successionPlanning contains no banned terms', () {
      _assertNoBannedTerms(
        FallbackTemplates.successionPlanning(baseCtx),
        'successionPlanning',
      );
    });

    test('librePassageGuide contains no banned terms', () {
      _assertNoBannedTerms(
        FallbackTemplates.librePassageGuide(baseCtx),
        'librePassageGuide',
      );
    });

    test('disabilityBridge contains no banned terms', () {
      _assertNoBannedTerms(
        FallbackTemplates.disabilityBridge(baseCtx),
        'disabilityBridge',
      );
    });

    test('enrichmentGuide all blocks contain no banned terms', () {
      for (final block in [
        'lpp', 'avs', '3a', 'patrimoine', 'fiscalite',
        'objectifRetraite', 'compositionMenage', 'unknown',
      ]) {
        _assertNoBannedTerms(
          FallbackTemplates.enrichmentGuide(baseCtx, block),
          'enrichmentGuide($block)',
        );
      }
    });
  });
}
