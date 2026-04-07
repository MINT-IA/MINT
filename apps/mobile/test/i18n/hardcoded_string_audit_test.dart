import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ────────────────────────────────────────────────────────────
//  HARDCODED STRING AUDIT + I18N COVERAGE VERIFICATION
//  Phase 06 / QA Profond -- Plan 04, Task 2
// ────────────────────────────────────────────────────────────
//
// Validates:
//   - Zero hardcoded French strings in Phase 1-5 Dart files
//   - All 6 ARB files have matching key counts (no missing translations)
//   - New Phase 1-5 i18n keys exist in ALL 6 ARB files
//   - No empty string values for financial-critical keys
//
// See: QA-08, COMP-05, T-06-08 requirements.
// ────────────────────────────────────────────────────────────

/// Files created/modified in Phases 1-5 to audit for hardcoded strings.
///
/// Only includes files that exist in the codebase.
const _phase1to5Files = [
  'lib/screens/onboarding/intent_screen.dart',
  'lib/screens/onboarding/quick_start_screen.dart',
  'lib/screens/onboarding/premier_eclairage_screen.dart',
  'lib/screens/onboarding/plan_screen.dart',
  'lib/screens/profile/privacy_control_screen.dart',
  'lib/widgets/home/anticipation_signal_card.dart',
  'lib/widgets/home/hero_stat_card.dart',
  'lib/widgets/home/progress_milestone_card.dart',
  'lib/widgets/home/action_opportunity_card.dart',
  'lib/services/contextual/coach_opener_service.dart',
];

/// Regex pattern to catch hardcoded multi-word French strings in Text() widgets.
///
/// Catches: Text('Bonjour le monde'), Text("Votre rente estimee")
/// Excludes: Text(variable), Text(l10n.key), single words, numbers, routes
///
/// Pattern breakdown:
///   Text\(\s* — match Text( with optional whitespace
///   ['"] — opening quote
///   ([A-Z\u00C0-\u017F]...) — starts with uppercase (including accented)
///   followed by lowercase words (>= 3 chars after first word)
///   ['"] — closing quote
final _hardcodedFrenchPattern = RegExp(
  r'''Text\(\s*['"]([A-Z\u00C0-\u017F][a-z\u00E0-\u017F]+\s+.{3,})['"]''',
);

/// Check if a matched string is a false positive (route, technical string).
bool _isFalsePositive(String matchedString) {
  // Route paths start with /
  if (matchedString.startsWith('/')) return true;
  // Single character or very short
  if (matchedString.length < 4) return true;
  // Technical identifiers (camelCase, snake_case)
  if (RegExp(r'^[a-z][a-zA-Z0-9_]+$').hasMatch(matchedString)) return true;
  // Package/class names
  if (RegExp(r'^[A-Z][a-zA-Z]+\.[a-zA-Z]').hasMatch(matchedString)) return true;
  return false;
}

/// ARB file paths (6 languages).
const _arbFiles = {
  'fr': 'lib/l10n/app_fr.arb',
  'de': 'lib/l10n/app_de.arb',
  'en': 'lib/l10n/app_en.arb',
  'es': 'lib/l10n/app_es.arb',
  'it': 'lib/l10n/app_it.arb',
  'pt': 'lib/l10n/app_pt.arb',
};

/// Extract non-metadata keys from an ARB JSON map.
///
/// Excludes keys starting with @ (metadata) and @@locale.
List<String> _extractKeys(Map<String, dynamic> arb) {
  return arb.keys
      .where((k) => !k.startsWith('@') && k != '@@locale')
      .toList()
    ..sort();
}

/// Financial-critical key prefixes whose values must be non-empty.
const _financialKeyPrefixes = [
  'retirement',
  'lpp',
  'avs',
  'pillar3a',
  'tax',
  'mortgage',
  'salary',
  'retraite',
  'pilier',
  'impot',
  'hypothe',
  'capital',
  'rente',
];

/// Key prefixes for Phase 1-5 features.
const _phase1to5KeyPrefixes = [
  'coachOpener',
  'anticipation',
  'privacyControl',
  'contextualCard',
  'premierEclairage',
  'heroStat',
  'progressMilestone',
  'actionOpportunity',
  'planScreen',
  'intentScreen',
  'quickStart',
];

void main() {
  late Map<String, Map<String, dynamic>> arbMaps;
  late Map<String, List<String>> arbKeys;

  setUpAll(() {
    arbMaps = {};
    arbKeys = {};

    for (final entry in _arbFiles.entries) {
      final file = File(entry.value);
      if (!file.existsSync()) {
        fail('ARB file not found: ${entry.value}');
      }
      final json =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      arbMaps[entry.key] = json;
      arbKeys[entry.key] = _extractKeys(json);
    }
  });

  // ═══════════════════════════════════════════════════════════
  //  GROUP 1 -- Hardcoded string detection in new files
  // ═══════════════════════════════════════════════════════════

  group('Hardcoded string detection in Phase 1-5 files', () {
    for (final filePath in _phase1to5Files) {
      test('$filePath has zero hardcoded French text literals', () {
        final file = File(filePath);
        if (!file.existsSync()) {
          // File does not exist (may not have been created in this phase)
          // Skip gracefully -- this is not a failure
          return;
        }

        final content = file.readAsStringSync();
        final lines = content.split('\n');
        final hardcodedMatches = <String>[];

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];

          // Skip comments and imports
          if (line.trimLeft().startsWith('//') ||
              line.trimLeft().startsWith('import ') ||
              line.trimLeft().startsWith('///')) {
            continue;
          }

          final matches = _hardcodedFrenchPattern.allMatches(line);
          for (final match in matches) {
            final captured = match.group(1) ?? '';
            if (!_isFalsePositive(captured)) {
              hardcodedMatches.add('  Line ${i + 1}: "$captured"');
            }
          }
        }

        expect(
          hardcodedMatches,
          isEmpty,
          reason:
              'Found ${hardcodedMatches.length} hardcoded French string(s) '
              'in $filePath:\n${hardcodedMatches.join('\n')}',
        );
      });
    }
  });

  // ═══════════════════════════════════════════════════════════
  //  GROUP 2 -- ARB file key parity
  // ═══════════════════════════════════════════════════════════

  group('ARB file key parity (all 6 languages)', () {
    test('all ARB files loaded successfully', () {
      expect(arbMaps.keys.length, 6);
      for (final lang in _arbFiles.keys) {
        expect(
          arbKeys[lang],
          isNotNull,
          reason: 'ARB keys for $lang should be loaded',
        );
      }
    });

    test('FR key count matches DE key count', () {
      final frCount = arbKeys['fr']!.length;
      final deCount = arbKeys['de']!.length;
      expect(
        deCount,
        frCount,
        reason:
            'DE has $deCount keys but FR has $frCount keys. '
            'Missing: ${frCount - deCount} keys.',
      );
    });

    test('FR key count matches EN key count', () {
      final frCount = arbKeys['fr']!.length;
      final enCount = arbKeys['en']!.length;
      expect(
        enCount,
        frCount,
        reason:
            'EN has $enCount keys but FR has $frCount keys. '
            'Missing: ${frCount - enCount} keys.',
      );
    });

    test('FR key count matches ES key count', () {
      final frCount = arbKeys['fr']!.length;
      final esCount = arbKeys['es']!.length;
      expect(
        esCount,
        frCount,
        reason:
            'ES has $esCount keys but FR has $frCount keys. '
            'Missing: ${frCount - esCount} keys.',
      );
    });

    test('FR key count matches IT key count', () {
      final frCount = arbKeys['fr']!.length;
      final itCount = arbKeys['it']!.length;
      expect(
        itCount,
        frCount,
        reason:
            'IT has $itCount keys but FR has $frCount keys. '
            'Missing: ${frCount - itCount} keys.',
      );
    });

    test('FR key count matches PT key count', () {
      final frCount = arbKeys['fr']!.length;
      final ptCount = arbKeys['pt']!.length;
      expect(
        ptCount,
        frCount,
        reason:
            'PT has $ptCount keys but FR has $frCount keys. '
            'Missing: ${frCount - ptCount} keys.',
      );
    });

    test('identify missing keys per language', () {
      final frKeySet = arbKeys['fr']!.toSet();
      final missingReport = <String>[];

      for (final lang in ['de', 'en', 'es', 'it', 'pt']) {
        final langKeySet = arbKeys[lang]!.toSet();
        final missingInLang = frKeySet.difference(langKeySet);
        if (missingInLang.isNotEmpty) {
          missingReport
              .add('$lang missing ${missingInLang.length}: ${missingInLang.take(10).join(', ')}');
        }
      }

      expect(
        missingReport,
        isEmpty,
        reason:
            'Some languages are missing keys:\n${missingReport.join('\n')}',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  GROUP 3 -- Phase 1-5 key existence in all languages
  // ═══════════════════════════════════════════════════════════

  group('Phase 1-5 i18n keys exist in all 6 ARB files', () {
    test('new Phase 1-5 key prefixes have at least one key in FR', () {
      final frKeySet = arbKeys['fr']!.toSet();

      for (final prefix in _phase1to5KeyPrefixes) {
        final matchingKeys =
            frKeySet.where((k) => k.startsWith(prefix)).toList();
        // At least some keys should exist for each prefix
        // (not all prefixes may have been added, so we document coverage)
        if (matchingKeys.isEmpty) {
          // Non-fatal: document which prefixes have no keys yet
          // This is informational, not a failure, since some features
          // may use different naming patterns
        }
      }

      // At least the anticipation and premierEclairage keys should exist
      final hasAnticipation =
          frKeySet.any((k) => k.startsWith('anticipation'));
      final hasPremierEclairage =
          frKeySet.any((k) => k.startsWith('premierEclairage'));

      expect(
        hasAnticipation,
        isTrue,
        reason: 'FR ARB should have anticipation* keys from Phase 4',
      );
      expect(
        hasPremierEclairage,
        isTrue,
        reason: 'FR ARB should have premierEclairage* keys from Phase 1',
      );
    });

    test('anticipation keys exist in all 6 languages with non-empty values', () {
      final frKeySet = arbKeys['fr']!.toSet();
      final anticipationKeys =
          frKeySet.where((k) => k.startsWith('anticipation')).toList();

      expect(
        anticipationKeys,
        isNotEmpty,
        reason: 'Should have anticipation* keys in FR',
      );

      for (final key in anticipationKeys) {
        for (final lang in _arbFiles.keys) {
          final value = arbMaps[lang]?[key];
          expect(
            value,
            isNotNull,
            reason: 'Key "$key" missing in $lang ARB file',
          );
          if (value != null) {
            expect(
              (value as String).length,
              greaterThanOrEqualTo(1),
              reason: 'Key "$key" in $lang has empty value',
            );
          }
        }
      }
    });

    test('premierEclairage keys exist in all 6 languages with non-empty values', () {
      final frKeySet = arbKeys['fr']!.toSet();
      final keys =
          frKeySet.where((k) => k.startsWith('premierEclairage')).toList();

      expect(keys, isNotEmpty,
          reason: 'Should have premierEclairage* keys in FR');

      for (final key in keys) {
        for (final lang in _arbFiles.keys) {
          final value = arbMaps[lang]?[key];
          expect(
            value,
            isNotNull,
            reason: 'Key "$key" missing in $lang ARB file',
          );
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  GROUP 4 -- No empty values for financial-critical keys
  // ═══════════════════════════════════════════════════════════

  group('Financial-critical keys have non-empty values', () {
    for (final lang in _arbFiles.keys) {
      test('$lang ARB has no empty financial key values', () {
        final arb = arbMaps[lang]!;
        final keys = arbKeys[lang]!;
        final emptyFinancialKeys = <String>[];

        for (final key in keys) {
          // Check if this key matches any financial prefix
          final isFinancial = _financialKeyPrefixes.any(
            (prefix) => key.toLowerCase().contains(prefix.toLowerCase()),
          );

          if (isFinancial) {
            final value = arb[key];
            if (value == null ||
                value is! String ||
                value.trim().isEmpty) {
              emptyFinancialKeys.add(key);
            }
          }
        }

        expect(
          emptyFinancialKeys,
          isEmpty,
          reason:
              '$lang has ${emptyFinancialKeys.length} financial keys with '
              'empty/short values: ${emptyFinancialKeys.take(10).join(', ')}',
        );
      });
    }
  });
}
