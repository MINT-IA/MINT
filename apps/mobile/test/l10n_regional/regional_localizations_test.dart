// ────────────────────────────────────────────────────────────
//  REGIONAL LOCALIZATIONS DELEGATE — Phase 6 L1.4 tests
// ────────────────────────────────────────────────────────────
//
// Verifies:
//   - Canton → regional anchor resolution (primary + secondary)
//   - Delegate isSupported gating (canton × locale language)
//   - Silent fallback: null canton, unmapped canton, missing key,
//     locale mismatch
//   - ARB asset loading for VS/ZH/TI
//   - shouldReload on canton change (hot swap)
//
// The pure LLM-prompt surface of RegionalVoiceService is already
// covered by test/services/voice/regional_voice_service_test.dart.
// This file covers ONLY the UI regional microcopy bridge introduced
// in Phase 6 Plan 06-03.
// ────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n_regional/regional_localizations_delegate.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Pre-warm the regional ARB cache once so subsequent tests see a
  // SynchronousFuture on load (removes frame-timing flakiness).
  setUpAll(() async {
    for (final canton in RegionalCanton.values) {
      await RegionalLocalizationsDelegate(canton)
          .load(Locale(kRegionalBaseLanguage[canton]!));
    }
  });

  group('resolveRegionalCanton', () {
    test('VS maps to vs anchor', () {
      expect(resolveRegionalCanton('VS'), RegionalCanton.vs);
    });

    test('secondary Romande cantons (VD/GE/NE/JU/FR) map to vs anchor', () {
      for (final c in const ['VD', 'GE', 'NE', 'JU', 'FR']) {
        expect(
          resolveRegionalCanton(c),
          RegionalCanton.vs,
          reason: '$c should route to VS anchor',
        );
      }
    });

    test('ZH maps to zh anchor', () {
      expect(resolveRegionalCanton('ZH'), RegionalCanton.zh);
    });

    test('secondary Deutschschweiz cantons map to zh anchor', () {
      for (final c in const ['BE', 'LU', 'ZG', 'AG', 'SG', 'BS', 'BL']) {
        expect(
          resolveRegionalCanton(c),
          RegionalCanton.zh,
          reason: '$c should route to ZH anchor',
        );
      }
    });

    test('TI maps to ti anchor', () {
      expect(resolveRegionalCanton('TI'), RegionalCanton.ti);
    });

    test('GR secondary maps to ti anchor', () {
      expect(resolveRegionalCanton('GR'), RegionalCanton.ti);
    });

    test('null / empty / whitespace / unknown return null', () {
      expect(resolveRegionalCanton(null), isNull);
      expect(resolveRegionalCanton(''), isNull);
      expect(resolveRegionalCanton('   '), isNull);
      expect(resolveRegionalCanton('XX'), isNull);
    });

    test('canton code is case- and whitespace-tolerant', () {
      expect(resolveRegionalCanton(' vs '), RegionalCanton.vs);
      expect(resolveRegionalCanton('zh'), RegionalCanton.zh);
    });
  });

  group('RegionalLocalizationsDelegate.isSupported', () {
    test('null canton → never supported (safe default)', () {
      const d = RegionalLocalizationsDelegate(null);
      expect(d.isSupported(const Locale('fr')), isFalse);
      expect(d.isSupported(const Locale('de')), isFalse);
      expect(d.isSupported(const Locale('it')), isFalse);
      expect(d.isSupported(const Locale('en')), isFalse);
    });

    test('VS canton supports only fr locale (locale-locked per D-01)', () {
      const d = RegionalLocalizationsDelegate(RegionalCanton.vs);
      expect(d.isSupported(const Locale('fr')), isTrue);
      expect(d.isSupported(const Locale('de')), isFalse);
      expect(d.isSupported(const Locale('it')), isFalse);
      expect(d.isSupported(const Locale('en')), isFalse);
    });

    test('ZH canton supports only de locale', () {
      const d = RegionalLocalizationsDelegate(RegionalCanton.zh);
      expect(d.isSupported(const Locale('de')), isTrue);
      expect(d.isSupported(const Locale('fr')), isFalse);
      expect(d.isSupported(const Locale('en')), isFalse);
    });

    test('TI canton supports only it locale', () {
      const d = RegionalLocalizationsDelegate(RegionalCanton.ti);
      expect(d.isSupported(const Locale('it')), isTrue);
      expect(d.isSupported(const Locale('fr')), isFalse);
      expect(d.isSupported(const Locale('de')), isFalse);
    });
  });

  group('RegionalLocalizationsDelegate.shouldReload', () {
    test('reloads when canton changes', () {
      const a = RegionalLocalizationsDelegate(RegionalCanton.vs);
      const b = RegionalLocalizationsDelegate(RegionalCanton.zh);
      expect(a.shouldReload(b), isTrue);
    });

    test('does not reload when canton is the same', () {
      const a = RegionalLocalizationsDelegate(RegionalCanton.vs);
      const b = RegionalLocalizationsDelegate(RegionalCanton.vs);
      expect(a.shouldReload(b), isFalse);
    });

    test('reloads when going from null to set canton', () {
      const a = RegionalLocalizationsDelegate(null);
      const b = RegionalLocalizationsDelegate(RegionalCanton.ti);
      expect(a.shouldReload(b), isTrue);
    });
  });

  group('RegionalLocalizations asset loading', () {
    test('VS ARB loads and exposes the 25 Phase 6 keys', () async {
      const d = RegionalLocalizationsDelegate(RegionalCanton.vs);
      final loc = await d.load(const Locale('fr'));
      expect(loc.canton, RegionalCanton.vs);
      expect(loc.overrideCount, 25);
      expect(loc.lookup('greetingMorning'), 'Salut');
      expect(loc.lookup('coachInputHint'), contains('sous'));
      // Silent fallback for a key NOT in the regional ARB.
      expect(loc.lookup('does_not_exist'), isNull);
    });

    test('ZH ARB loads with de-CH base language and Grüezi greeting',
        () async {
      const d = RegionalLocalizationsDelegate(RegionalCanton.zh);
      final loc = await d.load(const Locale('de'));
      expect(loc.overrideCount, 25);
      expect(loc.lookup('greetingMorning'), 'Grüezi');
      expect(loc.lookup('settingsSheetTitle'), 'Einstellungen');
    });

    test('TI ARB loads with it-CH base language and Ciao greeting', () async {
      const d = RegionalLocalizationsDelegate(RegionalCanton.ti);
      final loc = await d.load(const Locale('it'));
      expect(loc.overrideCount, 25);
      expect(loc.lookup('greetingMorning'), 'Ciao');
      expect(loc.lookup('emptyStateDefaultBody'), contains('piano'));
    });

    test('every regional ARB carries the UNVALIDATED marker (D-08)',
        () async {
      for (final path in const [
        'lib/l10n_regional/app_regional_vs.arb',
        'lib/l10n_regional/app_regional_zh.arb',
        'lib/l10n_regional/app_regional_ti.arb',
      ]) {
        final raw = await rootBundle.loadString(path);
        final json = jsonDecode(raw) as Map<String, dynamic>;
        expect(
          json['@@x-unvalidated'],
          isA<String>(),
          reason: '$path must carry @@x-unvalidated per D-08',
        );
        expect(
          (json['@@x-unvalidated'] as String),
          contains('UNVALIDATED'),
        );
      }
    });
  });

  // Helper that mounts a minimal Localizations subtree using the same
  // delegates a MaterialApp would install via RegionalVoiceService, then
  // captures the result of the stacking lookup from a child context.
  Future<String?> pumpAndCapture(
    WidgetTester tester, {
    required String? canton,
    required Locale locale,
    required String key,
    required String baseFallback,
  }) async {
    String? captured;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Localizations(
          locale: locale,
          delegates: <LocalizationsDelegate<dynamic>>[
            RegionalVoiceService.delegateForCanton(canton),
            DefaultWidgetsLocalizations.delegate,
          ],
          child: Builder(
            builder: (context) {
              captured =
                  RegionalVoiceService.lookup(context, key, baseFallback);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    // Localizations delegates load asynchronously (rootBundle.loadString);
    // pump twice then settle to ensure the post-load rebuild fires before
    // we read the captured value.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    return captured;
  }

  group('RegionalVoiceService UI bridge (stacking)', () {
    testWidgets('VS canton installs regional layer and lookup returns '
        'the VS override', (tester) async {
      final captured = await pumpAndCapture(
        tester,
        canton: 'VS',
        locale: const Locale('fr'),
        key: 'greetingMorning',
        baseFallback: 'FALLBACK',
      );
      expect(captured, 'Salut');
    });

    testWidgets('null canton → lookup silently returns base fallback',
        (tester) async {
      final captured = await pumpAndCapture(
        tester,
        canton: null,
        locale: const Locale('fr'),
        key: 'greetingMorning',
        baseFallback: 'Bonjour',
      );
      expect(captured, 'Bonjour');
    });

    testWidgets('VS canton with wrong locale (en) → silent base fallback',
        (tester) async {
      final captured = await pumpAndCapture(
        tester,
        canton: 'VS',
        locale: const Locale('en'),
        key: 'greetingMorning',
        baseFallback: 'Hello',
      );
      expect(captured, 'Hello');
    });

    testWidgets('missing regional key → silent base fallback', (tester) async {
      final captured = await pumpAndCapture(
        tester,
        canton: 'VS',
        locale: const Locale('fr'),
        key: 'key_that_does_not_exist',
        baseFallback: 'BASE_VALUE',
      );
      expect(captured, 'BASE_VALUE');
    });

    testWidgets('FR (Fribourg) secondary canton routes to VS anchor',
        (tester) async {
      final captured = await pumpAndCapture(
        tester,
        canton: 'FR',
        locale: const Locale('fr'),
        key: 'greetingMorning',
        baseFallback: 'Bonjour',
      );
      expect(captured, 'Salut');
    });

    testWidgets('ZH canton with de locale returns Grüezi', (tester) async {
      final captured = await pumpAndCapture(
        tester,
        canton: 'ZH',
        locale: const Locale('de'),
        key: 'greetingMorning',
        baseFallback: 'Guten Morgen',
      );
      expect(captured, 'Grüezi');
    });

    testWidgets('TI canton with it locale returns Ciao', (tester) async {
      final captured = await pumpAndCapture(
        tester,
        canton: 'TI',
        locale: const Locale('it'),
        key: 'greetingMorning',
        baseFallback: 'Buongiorno',
      );
      expect(captured, 'Ciao');
    });
  });
}
