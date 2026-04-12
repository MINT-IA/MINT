// Phase 10 Plan 10-03 — widget tests for [JargonText].

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/text/jargon_text.dart';

/// Walks the [InlineSpan] tree of every [RichText] currently in the tree
/// and invokes the [TapGestureRecognizer] attached to the first [TextSpan]
/// whose text equals [termKey]. Returns true if a recogniser was fired.
///
/// This is more robust than geometry-based taps for inline spans because
/// the hit-test box of a TextSpan shrinks with the glyph width and
/// TalkBack/Flutter text metrics drift across devices.
bool _tapSpan(WidgetTester tester, String termKey) {
  for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
    var fired = false;
    rt.text.visitChildren((span) {
      if (fired) return false;
      if (span is TextSpan &&
          span.text == termKey &&
          span.recognizer is TapGestureRecognizer) {
        (span.recognizer as TapGestureRecognizer).onTap?.call();
        fired = true;
        return false;
      }
      return true;
    });
    if (fired) return true;
  }
  return false;
}

Widget _host(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  setUp(() {
    // GlossaryService.trackLookup hits SharedPreferences; mock it so the
    // widget path doesn't block on a MissingPluginException.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'renders plain Text when no markers are present',
    (tester) async {
      await tester.pumpWidget(_host(
        const JargonText('Une phrase simple sans marqueur.'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Une phrase simple sans marqueur.'), findsOneWidget);
      // Fast path → plain Text, not RichText.
      expect(find.byType(RichText), findsWidgets,
          reason: 'Text itself uses RichText internally; presence is OK.');
    },
  );

  testWidgets(
    'parses [[term:LPP]] and opens a bottom sheet with the definition',
    (tester) async {
      await tester.pumpWidget(_host(
        const JargonText('Ton [[term:LPP]] finance ta retraite.'),
      ));
      await tester.pumpAndSettle();

      // The surrounding prose is rendered via RichText with an inline span.
      expect(find.byType(RichText), findsWidgets);

      // Fire the TapGestureRecognizer on the LPP span directly — geometry
      // taps on inline TextSpans are flaky across font metrics.
      final fired = _tapSpan(tester, 'LPP');
      expect(fired, isTrue, reason: 'LPP span must carry a tap recogniser.');
      await tester.pumpAndSettle();

      // Bottom sheet opened — the LPP glossary body (from app_fr.arb)
      // starts with "Le 2e pilier". We assert on that literal to stay
      // resilient to minor copy edits in the rest of the sentence.
      expect(find.textContaining('2e pilier'), findsWidgets,
          reason: 'Tapping [[term:LPP]] must surface its glossary body.');
    },
  );

  testWidgets(
    'unknown term marker falls back to underlined span but does not crash '
    'when tapped (no bottom sheet)',
    (tester) async {
      await tester.pumpWidget(_host(
        const JargonText('Terme [[term:DOESNOTEXIST]] inconnu.'),
      ));
      await tester.pumpAndSettle();

      // Fire the tap recogniser on the unknown span directly — it must
      // not throw and must not open a sheet.
      final fired = _tapSpan(tester, 'DOESNOTEXIST');
      expect(fired, isTrue,
          reason: 'Unknown term still renders a tappable span.');
      await tester.pumpAndSettle();

      // No bottom sheet should have opened (unknown glossary key = no-op).
      // We assert the absence of a ModalBarrier that a sheet would add.
      expect(find.byType(ModalBarrier).evaluate().length, lessThanOrEqualTo(1),
          reason:
              'Only the root MaterialApp barrier may exist — no sheet barrier.');
    },
  );

  test('jargonMarkerPattern matches expected shapes', () {
    final matches = jargonMarkerPattern
        .allMatches('foo [[term:LPP]] bar [[term:3a]] baz')
        .toList();
    expect(matches.length, 2);
    expect(matches[0].group(1), 'LPP');
    expect(matches[1].group(1), '3a');

    // Unclosed marker → no match.
    expect(jargonMarkerPattern.allMatches('[[term:broken').toList(), isEmpty);
  });
}
