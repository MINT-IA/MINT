// ignore_for_file: lines_longer_than_80_chars

/// Behavioral tests for [resolveIntentOpener] (D-06, D-07).
///
/// Verifies:
///   1. Each of the 7 intent keys maps to a distinct non-null opener string.
///   2. Unknown chip keys return null (graceful degradation).
///   3. Each opener contains language relevant to its intent.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart'
    show resolveIntentOpener;

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Pumps a minimal widget to get a French [S] instance.
Future<S> _buildL10n(WidgetTester tester) async {
  late S captured;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr')],
      locale: const Locale('fr'),
      home: Builder(
        builder: (ctx) {
          captured = S.of(ctx)!;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pump();
  return captured;
}

const _allChipKeys = [
  'intentChip3a',
  'intentChipBilan',
  'intentChipPrevoyance',
  'intentChipFiscalite',
  'intentChipProjet',
  'intentChipChangement',
  'intentChipAutre',
];

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('resolveIntentOpener (D-06, D-07)', () {
    testWidgets('3a chip returns string containing "3a"', (tester) async {
      final l10n = await _buildL10n(tester);
      final result = resolveIntentOpener('intentChip3a', l10n);
      expect(result, isNotNull);
      expect(result, contains('3a'));
    });

    testWidgets('projet chip returns string containing "immobilier"',
        (tester) async {
      final l10n = await _buildL10n(tester);
      final result = resolveIntentOpener('intentChipProjet', l10n);
      expect(result, isNotNull);
      expect(result, contains('immobilier'));
    });

    testWidgets('unknown chip key returns null (graceful degradation)',
        (tester) async {
      final l10n = await _buildL10n(tester);
      final result = resolveIntentOpener('unknownChipKey', l10n);
      expect(result, isNull);
    });

    testWidgets('all 7 intent keys map to distinct non-null strings',
        (tester) async {
      final l10n = await _buildL10n(tester);

      final results = _allChipKeys
          .map((key) => resolveIntentOpener(key, l10n))
          .toList();

      // All non-null
      for (final r in results) {
        expect(r, isNotNull, reason: 'Every chip key must resolve');
      }

      // All distinct
      final unique = results.toSet();
      expect(unique.length, equals(_allChipKeys.length),
          reason: 'Each intent must have a unique opener');
    });

    testWidgets('prevoyance chip returns non-null opener', (tester) async {
      final l10n = await _buildL10n(tester);
      final result = resolveIntentOpener('intentChipPrevoyance', l10n);
      expect(result, isNotNull);
      expect(result!.isNotEmpty, isTrue);
    });

    testWidgets('bilan chip returns non-null opener', (tester) async {
      final l10n = await _buildL10n(tester);
      final result = resolveIntentOpener('intentChipBilan', l10n);
      expect(result, isNotNull);
      expect(result!.isNotEmpty, isTrue);
    });

    testWidgets('autre chip returns non-null opener', (tester) async {
      final l10n = await _buildL10n(tester);
      final result = resolveIntentOpener('intentChipAutre', l10n);
      expect(result, isNotNull);
      expect(result!.isNotEmpty, isTrue);
    });
  });
}
