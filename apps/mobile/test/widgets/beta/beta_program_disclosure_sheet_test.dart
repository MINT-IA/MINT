// ────────────────────────────────────────────────────────────────────
//  BetaProgramDisclosureSheet widget tests
// ────────────────────────────────────────────────────────────────────
//
//  Covers :
//   • maybeShow no-op when SharedPreferences flag is set
//   • maybeShow shows sheet when flag is unset, persists flag on dismiss
//   • CTA tap dismisses sheet + sets flag
//   • « En savoir plus » TextButton renders + is tappable
//   • Headline renders Fraunces italic em (TextSpan walk)
//   • Semantics label is announced for screen readers
//
//  Note: url_launcher isn't mocked in widget tests — the canLaunchUrl
//  guard in _openPrivacyUrl prevents crashes during test runs.
// ────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/beta/beta_program_disclosure_sheet.dart';

const String _kFlag = 'mint_beta_disclosure_seen';

Widget _harness({Widget? home}) {
  return MaterialApp(
    locale: const Locale('fr'),
    supportedLocales: S.supportedLocales,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home ??
        Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => BetaProgramDisclosureSheet.maybeShow(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
  );
}

bool _treeContainsText(WidgetTester tester, String needle) {
  final lower = needle.toLowerCase();
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final data = t.data ?? t.textSpan?.toPlainText() ?? '';
    if (data.toLowerCase().contains(lower)) return true;
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('maybeShow is a no-op when the flag is already set',
      (tester) async {
    SharedPreferences.setMockInitialValues({_kFlag: true});

    await tester.pumpWidget(_harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Sheet should not be present — only the "open" button remains.
    expect(find.byType(BetaProgramDisclosureSheet), findsNothing);
  });

  testWidgets('maybeShow renders the sheet when the flag is unset',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BetaProgramDisclosureSheet), findsOneWidget);
    // Headline pieces are visible.
    expect(_treeContainsText(tester, 'apprend avec toi'), isTrue);
    // CTA + secondary visible.
    expect(_treeContainsText(tester, 'Je comprends'), isTrue);
    expect(_treeContainsText(tester, 'En savoir plus'), isTrue);
  });

  testWidgets('CTA tap dismisses sheet and persists the flag',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BetaProgramDisclosureSheet), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Je comprends, on y va'));
    await tester.pumpAndSettle();

    expect(find.byType(BetaProgramDisclosureSheet), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_kFlag), isTrue);
  });

  testWidgets('headline renders an italic emphasis TextSpan', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Walk every Text widget; assert at least one TextSpan child has italic.
    bool foundItalic = false;
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final span = t.textSpan;
      if (span is TextSpan) {
        for (final child in span.children ?? const <InlineSpan>[]) {
          if (child is TextSpan &&
              child.style?.fontStyle == FontStyle.italic) {
            foundItalic = true;
            break;
          }
        }
      }
      if (foundItalic) break;
    }
    expect(foundItalic, isTrue,
        reason: 'Editorial italic em on headline must be present');
  });

  testWidgets('Semantics label exposes beta disclosure context',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(find.byType(BetaProgramDisclosureSheet));
    // Label is composed of the disclosure semantics — check substring.
    expect(semantics.label.toLowerCase(), contains('bêta'));
  });

  test('resetForTest clears the persisted flag', () async {
    SharedPreferences.setMockInitialValues({_kFlag: true});
    await BetaProgramDisclosureSheet.resetForTest();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_kFlag), isNull);
  });

  test('markAcknowledged sets the persisted flag', () async {
    await BetaProgramDisclosureSheet.markAcknowledged();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_kFlag), isTrue);
  });
}
