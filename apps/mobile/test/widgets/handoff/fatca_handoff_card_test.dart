import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/handoff/fatca_handoff_card.dart';

// ────────────────────────────────────────────────────────────────
//  FATCA HAND-OFF CARD — Phase 93 Plan 02 (COMP-04)
//
//  - Render under FR + EN + DE + ES + IT + PT locales.
//  - Banned-term hygiene scan over the 18 ARB strings.
//  - FR-specific accent hygiene check.
//  - Tap-callback wiring.
// ────────────────────────────────────────────────────────────────

Widget _wrap(Widget child, Locale locale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: Scaffold(body: child),
  );
}

Map<String, dynamic> _arbFor(String code) {
  // The widget test runs from `apps/mobile/`. ARB lives at lib/l10n/.
  final path = 'lib/l10n/app_$code.arb';
  final raw = File(path).readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  group('FatcaHandoffCard render', () {
    testWidgets('FR locale shows the FR ARB strings', (tester) async {
      await tester.pumpWidget(
        _wrap(const FatcaHandoffCard(), const Locale('fr')),
      );
      await tester.pumpAndSettle();

      // Match a fragment of the FR title to avoid coupling to the full
      // string (CLAUDE.md règle 2 also enforces diacritics inside).
      expect(find.textContaining('éclairage spécialisé'), findsOneWidget);
      expect(find.textContaining('FATCA'), findsOneWidget);
      expect(find.text('Trouver un·e spécialiste US-CH'), findsOneWidget);
    });

    testWidgets('EN locale shows the EN ARB strings', (tester) async {
      await tester.pumpWidget(
        _wrap(const FatcaHandoffCard(), const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Find a US-CH specialist'), findsOneWidget);
      expect(find.textContaining('US-CH situation'), findsOneWidget);
      // FR strings are NOT visible under EN locale.
      expect(find.textContaining('éclairage spécialisé'), findsNothing);
    });

    for (final lang in ['de', 'es', 'it', 'pt']) {
      testWidgets('$lang locale renders the localized CTA', (tester) async {
        await tester.pumpWidget(
          _wrap(const FatcaHandoffCard(), Locale(lang)),
        );
        await tester.pumpAndSettle();

        final arb = _arbFor(lang);
        // CTA is a fixed full-string match, perfect for find.text.
        expect(find.text(arb['fatcaHandoffCta'] as String), findsOneWidget);
        // Body must contain the FATCA acronym in every locale.
        expect(find.textContaining('FATCA'), findsOneWidget);
      });
    }

    testWidgets('CTA tap fires the injected callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          FatcaHandoffCard(onCtaTap: () => taps += 1),
          const Locale('fr'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trouver un·e spécialiste US-CH'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });

  group('ARB hygiene (LSFin règle 1 + accents règle 2)', () {
    const bannedByLanguage = <String, List<String>>{
      'fr': ['optimal', 'garanti', 'meilleur', 'parfait', 'sans risque'],
      'en': ['guaranteed', 'optimal', 'best', 'risk-free', 'perfect'],
      'de': ['garantiert', 'optimal', 'beste', 'risikolos', 'perfekt'],
      'es': ['garantizado', 'óptimo', 'mejor', 'sin riesgo', 'perfecto'],
      'it': ['garantito', 'ottimale', 'migliore', 'senza rischio', 'perfetto'],
      'pt': ['garantido', 'ótimo', 'melhor', 'sem risco', 'perfeito'],
    };

    test('all 18 FATCA ARB strings are banned-term clean', () {
      // CLAUDE.md règle 1 forbids the standalone use of these terms.
      // We match on word boundaries (`\b...\b`) so legitimate compound
      // nouns (e.g. German "Doppelbesteuerung" which contains "beste"
      // as a substring) don't trigger a false positive.
      var stringsScanned = 0;
      for (final entry in bannedByLanguage.entries) {
        final arb = _arbFor(entry.key);
        for (final key in [
          'fatcaHandoffTitle',
          'fatcaHandoffBody',
          'fatcaHandoffCta',
        ]) {
          final value = arb[key];
          expect(value, isA<String>(),
              reason: '$key missing in ${entry.key} ARB');
          final lower = (value as String).toLowerCase();
          for (final word in entry.value) {
            // Use Unicode word boundaries via negated char classes so we
            // catch the banned term standalone but allow it as a
            // substring of a legitimate compound (FR/DE compound nouns).
            final pattern = RegExp(
              r'(^|[^\p{L}\p{N}])' +
                  RegExp.escape(word.toLowerCase()) +
                  r'($|[^\p{L}\p{N}])',
              unicode: true,
            );
            expect(
              pattern.hasMatch(lower),
              isFalse,
              reason: 'banned term "$word" found standalone in '
                  '${entry.key}.$key — value="$lower"',
            );
          }
          stringsScanned += 1;
        }
      }
      expect(stringsScanned, 18,
          reason: 'expected 6 locales × 3 keys = 18 strings scanned');
    });

    test('FR strings use proper diacritics (CLAUDE.md règle 2)', () {
      final fr = _arbFor('fr');
      final body = fr['fatcaHandoffBody'] as String;
      final title = fr['fatcaHandoffTitle'] as String;
      final cta = fr['fatcaHandoffCta'] as String;

      expect(title, contains('éclairage'));
      expect(title, contains('spécialisé'));
      expect(body, contains('décision'));
      expect(body, contains('spécialiste'));
      // Must NOT contain ASCII-e variants of those words.
      expect(title, isNot(contains('eclairage')));
      expect(title, isNot(contains('specialise')));
      expect(body, isNot(contains('decision')));
      expect(cta, contains('spécialiste'));
    });
  });
}
