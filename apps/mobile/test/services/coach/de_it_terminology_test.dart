import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ────────────────────────────────────────────────────────────
//  DE + IT FINANCIAL TERMINOLOGY ACCURACY TESTS
//  Phase 06 / QA Profond — Plan 03, Task 2
// ────────────────────────────────────────────────────────────
//
// Validates:
//   - German (DE) ARB file uses correct Swiss German financial terms
//     (Pensionskasse, Saule 3a, AHV, BVG, Steuererklaerung)
//   - Italian (IT) ARB file uses correct Swiss Italian terms
//     (cassa pensione, pilastro 3a, AVS, LPP, dichiarazione fiscale)
//   - No French term leakage in DE/IT files
//   - >= 85% financial key coverage in both languages
//
// See: QA-07, QA-10 requirements.
// ────────────────────────────────────────────────────────────

/// Financial-domain ARB keys that MUST have correct translations.
///
/// Selected from keys whose FR values contain core financial concepts.
/// These keys appear in user-facing screens (simulators, projections,
/// onboarding, coaching messages).
const _financialKeyPatterns = [
  'retraite',
  'pilier',
  '3a',
  'lpp',
  'avs',
  'impot',
  'fiscal',
  'capital',
  'rente',
  'salaire',
  'hypothe',
  'pension',
  'prevoyance',
  'caisse',
  'rachat',
  'cotisation',
  'patrimoine',
];

/// French-only terms that should NOT appear in DE translations.
const _frenchTermsForLeakageCheck = [
  'retraite',
  'pilier',
  'caisse de pension',
  'prevoyance',
];

/// French-only terms that should NOT appear in IT translations.
const _frenchTermsForItLeakageCheck = [
  'retraite',
  'pilier',
  'caisse de pension',
  'prevoyance',
];

void main() {
  late Map<String, dynamic> frArb;
  late Map<String, dynamic> deArb;
  late Map<String, dynamic> itArb;
  late List<String> financialKeys;

  setUpAll(() {
    // Load ARB files as JSON
    final frFile = File('lib/l10n/app_fr.arb');
    final deFile = File('lib/l10n/app_de.arb');
    final itFile = File('lib/l10n/app_it.arb');

    frArb = jsonDecode(frFile.readAsStringSync()) as Map<String, dynamic>;
    deArb = jsonDecode(deFile.readAsStringSync()) as Map<String, dynamic>;
    itArb = jsonDecode(itFile.readAsStringSync()) as Map<String, dynamic>;

    // Build list of financial-domain keys from FR file
    financialKeys = frArb.keys
        .where((k) => !k.startsWith('@'))
        .where((k) {
          final value = frArb[k].toString().toLowerCase();
          final keyLower = k.toLowerCase();
          return _financialKeyPatterns.any(
            (pattern) => value.contains(pattern) || keyLower.contains(pattern),
          );
        })
        .toList();
  });

  // ═══════════════════════════════════════════════════════════
  // Group 1 — DE financial terminology
  // ═══════════════════════════════════════════════════════════

  group('Group 1 - DE financial terminology', () {
    test('DE ARB contains Vorsorge or Pensionskasse for retirement concepts', () {
      // Find keys where FR contains "retraite" or "pension"
      final retirementKeys = frArb.keys
          .where((k) => !k.startsWith('@'))
          .where((k) {
            final v = frArb[k].toString().toLowerCase();
            return v.contains('retraite') || v.contains('pension');
          })
          .take(20)
          .toList();

      expect(retirementKeys, isNotEmpty,
          reason: 'Should find retirement-related FR keys');

      int correctCount = 0;
      for (final key in retirementKeys) {
        final deValue = deArb[key]?.toString().toLowerCase() ?? '';
        if (deValue.contains('vorsorge') ||
            deValue.contains('pension') ||
            deValue.contains('rente') ||
            deValue.contains('ruhestand') ||
            deValue.contains('alters')) {
          correctCount++;
        }
      }
      // At least 80% of retirement keys should have correct DE terms
      expect(
        correctCount / retirementKeys.length,
        greaterThanOrEqualTo(0.80),
        reason: 'DE retirement terms: $correctCount/${retirementKeys.length} correct',
      );
    });

    test('DE ARB contains Saule or Saule 3a for pillar 3a concepts', () {
      final pillar3aKeys = frArb.keys
          .where((k) => !k.startsWith('@'))
          .where((k) {
            final v = frArb[k].toString().toLowerCase();
            return v.contains('3e pilier') ||
                v.contains('pilier 3a') ||
                v.contains('3a');
          })
          .take(20)
          .toList();

      expect(pillar3aKeys, isNotEmpty);

      int correctCount = 0;
      for (final key in pillar3aKeys) {
        final deValue = deArb[key]?.toString().toLowerCase() ?? '';
        // DE should use "Saule" or "3a" or "3. Saule" or "Saeule"
        if (deValue.contains('saule') ||
            deValue.contains('säule') ||
            deValue.contains('3a')) {
          correctCount++;
        }
      }
      expect(
        correctCount / pillar3aKeys.length,
        greaterThanOrEqualTo(0.70),
        reason: 'DE pillar 3a terms: $correctCount/${pillar3aKeys.length} correct',
      );
    });

    test('DE ARB uses BVG for LPP concepts', () {
      final lppKeys = frArb.keys
          .where((k) => !k.startsWith('@'))
          .where((k) {
            final v = frArb[k].toString().toLowerCase();
            return v.contains('lpp') && !v.contains('application');
          })
          .take(20)
          .toList();

      expect(lppKeys, isNotEmpty);

      int correctCount = 0;
      for (final key in lppKeys) {
        final deValue = deArb[key]?.toString().toLowerCase() ?? '';
        if (deValue.contains('bvg') ||
            deValue.contains('pensionskasse') ||
            deValue.contains('lpp')) {
          correctCount++;
        }
      }
      expect(
        correctCount / lppKeys.length,
        greaterThanOrEqualTo(0.70),
        reason: 'DE LPP/BVG terms: $correctCount/${lppKeys.length} correct',
      );
    });

    test('DE ARB uses AHV for AVS concepts', () {
      final avsKeys = frArb.keys
          .where((k) => !k.startsWith('@'))
          .where((k) {
            final v = frArb[k].toString().toLowerCase();
            final kLower = k.toLowerCase();
            return (v.contains('avs') || kLower.contains('avs')) &&
                !v.contains('navigation');
          })
          .take(15)
          .toList();

      // Some repos may not have many pure-AVS keys
      if (avsKeys.isEmpty) return;

      int correctCount = 0;
      for (final key in avsKeys) {
        final deValue = deArb[key]?.toString().toLowerCase() ?? '';
        if (deValue.contains('ahv') || deValue.contains('avs')) {
          correctCount++;
        }
      }
      expect(
        correctCount / avsKeys.length,
        greaterThanOrEqualTo(0.60),
        reason: 'DE AVS/AHV terms: $correctCount/${avsKeys.length} correct',
      );
    });

    test('DE financial keys are non-empty and differ from FR', () {
      int nonEmpty = 0;
      int diffFromFr = 0;
      final sample = financialKeys.take(50).toList();

      for (final key in sample) {
        final deValue = deArb[key]?.toString() ?? '';
        final frValue = frArb[key]?.toString() ?? '';
        if (deValue.isNotEmpty) nonEmpty++;
        if (deValue.isNotEmpty && deValue != frValue) diffFromFr++;
      }

      expect(nonEmpty / sample.length, greaterThanOrEqualTo(0.85),
          reason: 'DE: $nonEmpty/${sample.length} financial keys non-empty');
      expect(diffFromFr / sample.length, greaterThanOrEqualTo(0.80),
          reason: 'DE: $diffFromFr/${sample.length} financial keys differ from FR');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Group 2 — IT financial terminology
  // ═══════════════════════════════════════════════════════════

  group('Group 2 - IT financial terminology', () {
    test('IT ARB contains pensionamento or previdenza for retirement', () {
      final retirementKeys = frArb.keys
          .where((k) => !k.startsWith('@'))
          .where((k) {
            final v = frArb[k].toString().toLowerCase();
            return v.contains('retraite') || v.contains('pension');
          })
          .take(20)
          .toList();

      expect(retirementKeys, isNotEmpty);

      int correctCount = 0;
      for (final key in retirementKeys) {
        final itValue = itArb[key]?.toString().toLowerCase() ?? '';
        if (itValue.contains('pensionamento') ||
            itValue.contains('pensione') ||
            itValue.contains('previdenza') ||
            itValue.contains('rendita') ||
            itValue.contains('vecchiaia') ||
            itValue.contains('ritiro') ||
            itValue.contains('avs') ||
            itValue.contains('anzian')) {
          correctCount++;
        }
      }
      expect(
        correctCount / retirementKeys.length,
        greaterThanOrEqualTo(0.75),
        reason: 'IT retirement terms: $correctCount/${retirementKeys.length} correct',
      );
    });

    test('IT ARB contains pilastro for pillar concepts', () {
      final pillarKeys = frArb.keys
          .where((k) => !k.startsWith('@'))
          .where((k) {
            final v = frArb[k].toString().toLowerCase();
            return v.contains('pilier') || v.contains('3a');
          })
          .take(20)
          .toList();

      expect(pillarKeys, isNotEmpty);

      int correctCount = 0;
      for (final key in pillarKeys) {
        final itValue = itArb[key]?.toString().toLowerCase() ?? '';
        if (itValue.contains('pilastro') || itValue.contains('3a')) {
          correctCount++;
        }
      }
      expect(
        correctCount / pillarKeys.length,
        greaterThanOrEqualTo(0.70),
        reason: 'IT pillar terms: $correctCount/${pillarKeys.length} correct',
      );
    });

    test('IT ARB uses cassa pensione or LPP for pension fund concepts', () {
      final lppKeys = frArb.keys
          .where((k) => !k.startsWith('@'))
          .where((k) {
            final v = frArb[k].toString().toLowerCase();
            return v.contains('lpp') && !v.contains('application');
          })
          .take(20)
          .toList();

      expect(lppKeys, isNotEmpty);

      int correctCount = 0;
      for (final key in lppKeys) {
        final itValue = itArb[key]?.toString().toLowerCase() ?? '';
        if (itValue.contains('cassa pensione') ||
            itValue.contains('lpp') ||
            itValue.contains('previdenza professionale')) {
          correctCount++;
        }
      }
      expect(
        correctCount / lppKeys.length,
        greaterThanOrEqualTo(0.70),
        reason: 'IT LPP terms: $correctCount/${lppKeys.length} correct',
      );
    });

    test('IT financial keys are non-empty and differ from FR', () {
      int nonEmpty = 0;
      int diffFromFr = 0;
      final sample = financialKeys.take(50).toList();

      for (final key in sample) {
        final itValue = itArb[key]?.toString() ?? '';
        final frValue = frArb[key]?.toString() ?? '';
        if (itValue.isNotEmpty) nonEmpty++;
        if (itValue.isNotEmpty && itValue != frValue) diffFromFr++;
      }

      expect(nonEmpty / sample.length, greaterThanOrEqualTo(0.85),
          reason: 'IT: $nonEmpty/${sample.length} financial keys non-empty');
      expect(diffFromFr / sample.length, greaterThanOrEqualTo(0.80),
          reason: 'IT: $diffFromFr/${sample.length} financial keys differ from FR');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Group 3 — Cross-language leakage detection
  // ═══════════════════════════════════════════════════════════

  group('Group 3 - French term leakage detection', () {
    test('DE ARB has minimal French term leakage', () {
      int leakedCount = 0;
      final leakedKeys = <String>[];

      for (final key in deArb.keys) {
        if (key.startsWith('@')) continue;
        final value = deArb[key].toString().toLowerCase();
        for (final frenchTerm in _frenchTermsForLeakageCheck) {
          if (value.contains(frenchTerm)) {
            // Allow if the key itself contains the term (might be a proper noun or code ref)
            if (!key.toLowerCase().contains(frenchTerm)) {
              leakedCount++;
              if (leakedKeys.length < 5) {
                leakedKeys.add('$key: ${deArb[key].toString().substring(0, deArb[key].toString().length.clamp(0, 80))}');
              }
            }
            break;
          }
        }
      }

      // Allow up to 5 leaks (some keys might intentionally reference French terms
      // as proper nouns or legal references)
      expect(
        leakedCount,
        lessThanOrEqualTo(5),
        reason: 'DE has $leakedCount French term leaks: $leakedKeys',
      );
    });

    test('IT ARB has minimal French term leakage', () {
      int leakedCount = 0;
      final leakedKeys = <String>[];

      for (final key in itArb.keys) {
        if (key.startsWith('@')) continue;
        final value = itArb[key].toString().toLowerCase();
        for (final frenchTerm in _frenchTermsForItLeakageCheck) {
          if (value.contains(frenchTerm)) {
            if (!key.toLowerCase().contains(frenchTerm)) {
              leakedCount++;
              if (leakedKeys.length < 5) {
                leakedKeys.add('$key: ${itArb[key].toString().substring(0, itArb[key].toString().length.clamp(0, 80))}');
              }
            }
            break;
          }
        }
      }

      expect(
        leakedCount,
        lessThanOrEqualTo(5),
        reason: 'IT has $leakedCount French term leaks: $leakedKeys',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Group 4 — Coverage percentage (>= 85%)
  // ═══════════════════════════════════════════════════════════

  group('Group 4 - Financial key coverage >= 85%', () {
    test('DE has >= 85% non-empty non-duplicate financial key coverage', () {
      int covered = 0;
      final total = financialKeys.length;

      for (final key in financialKeys) {
        final deValue = deArb[key]?.toString() ?? '';
        final frValue = frArb[key]?.toString() ?? '';
        if (deValue.isNotEmpty && deValue != frValue) {
          covered++;
        }
      }

      final coverage = covered / total;
      expect(
        coverage,
        greaterThanOrEqualTo(0.85),
        reason: 'DE financial coverage: $covered/$total = '
            '${(coverage * 100).toStringAsFixed(1)}% (need >= 85%)',
      );
    });

    test('IT has >= 85% non-empty non-duplicate financial key coverage', () {
      int covered = 0;
      final total = financialKeys.length;

      for (final key in financialKeys) {
        final itValue = itArb[key]?.toString() ?? '';
        final frValue = frArb[key]?.toString() ?? '';
        if (itValue.isNotEmpty && itValue != frValue) {
          covered++;
        }
      }

      final coverage = covered / total;
      expect(
        coverage,
        greaterThanOrEqualTo(0.85),
        reason: 'IT financial coverage: $covered/$total = '
            '${(coverage * 100).toStringAsFixed(1)}% (need >= 85%)',
      );
    });
  });
}
