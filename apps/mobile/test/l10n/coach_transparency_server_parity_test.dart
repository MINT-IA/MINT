// P2 walkthrough fix (2026-05-07): the auth coach footer claimed
// « Ton salaire exact n'est PAS envoyé » even when the user typed a
// salary in plaintext, because the binary `slm ? SLM : BYOK` switch
// in coach_chat_screen.dart routed `ChatTier.fallback` (server-key
// path) to the BYOK copy.
//
// This test asserts the contract the fix relies on:
//   * Every locale defines the new `coachTransparencyServer` key.
//   * The copy is honest about the server-key path: it does NOT
//     contain the misleading « pas envoyé » / « NOT sent » phrasing.
//   * 6-locale parity preserved (no orphaned key).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const locales = ['fr', 'en', 'de', 'es', 'it', 'pt'];

  // From the test runner cwd (apps/mobile/), ARB files live at
  // lib/l10n/app_<locale>.arb.
  Map<String, String> _loadArb(String locale) {
    final file = File('lib/l10n/app_$locale.arb');
    expect(file.existsSync(), isTrue,
        reason: 'ARB file missing: ${file.path}');
    final raw = file.readAsStringSync();
    final decoded = jsonDecode(raw);
    expect(decoded, isA<Map<String, dynamic>>());
    return Map<String, String>.fromEntries(
      (decoded as Map<String, dynamic>)
          .entries
          .where((e) => e.value is String)
          .map((e) => MapEntry(e.key, e.value as String)),
    );
  }

  group('coachTransparencyServer (P2 walkthrough fix)', () {
    test('exists in all 6 locales', () {
      for (final loc in locales) {
        final arb = _loadArb(loc);
        expect(
          arb.containsKey('coachTransparencyServer'),
          isTrue,
          reason:
              'coachTransparencyServer missing from app_$loc.arb — required '
              'for the 4-way ChatTier copy switch in coach_chat_screen.dart.',
        );
        expect(arb['coachTransparencyServer']!.isNotEmpty, isTrue,
            reason: 'coachTransparencyServer is empty in app_$loc.arb');
      }
    });

    test('FR copy does not claim « pas envoyé »', () {
      final arb = _loadArb('fr');
      final copy = arb['coachTransparencyServer']!;
      expect(
        RegExp(r"pas envoy", caseSensitive: false).hasMatch(copy),
        isFalse,
        reason:
            'FR Server copy must not claim « pas envoyé » — the user message '
            '(including any CHF amount) IS shipped to Anthropic via the MINT '
            'server key. Honest copy required.',
      );
      // Sanity: the copy mentions « MINT » and the API → user understands.
      expect(copy.toLowerCase(), contains('mint'),
          reason: 'FR Server copy should disclose the MINT server key.');
    });

    test('EN copy does not claim « NOT sent »', () {
      final arb = _loadArb('en');
      final copy = arb['coachTransparencyServer']!;
      expect(
        RegExp(r"not sent", caseSensitive: false).hasMatch(copy),
        isFalse,
        reason:
            'EN Server copy must not claim « NOT sent » — the user message '
            'IS shared with Anthropic via the MINT server key.',
      );
      expect(copy.toLowerCase(), contains('mint'));
    });

    test('all 6 locales mention the API', () {
      for (final loc in locales) {
        final arb = _loadArb(loc);
        final copy = arb['coachTransparencyServer']!;
        expect(
          RegExp(r"api", caseSensitive: false).hasMatch(copy),
          isTrue,
          reason:
              'Server copy in $loc must mention API (Claude API / API Claude).',
        );
      }
    });
  });

  group('ARB parity guard', () {
    test('SLM + BYOK + Server keys all present in 6 locales', () {
      for (final loc in locales) {
        final arb = _loadArb(loc);
        for (final key in const [
          'coachTransparencySLM',
          'coachTransparencyBYOK',
          'coachTransparencyServer',
        ]) {
          expect(arb.containsKey(key), isTrue,
              reason: '$key missing from app_$loc.arb');
        }
      }
    });
  });
}
