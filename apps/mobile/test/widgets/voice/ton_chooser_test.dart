// Phase 12-01 — TonChooser widget tests.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart'
    show VoicePreference;
import 'package:mint_mobile/widgets/voice/ton_chooser.dart';
import 'package:mint_mobile/widgets/voice/ton_chooser_sheet.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr'), Locale('en')],
    home: Scaffold(body: child),
  );
}

void main() {
  group('TonChooser', () {
    testWidgets('renders 3 cells with French labels', (tester) async {
      await tester.pumpWidget(_wrap(
        TonChooser(
          current: VoicePreference.direct,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Doux'), findsOneWidget);
      expect(find.text('Direct'), findsOneWidget);
      expect(find.text('Non filtré'), findsOneWidget);
    });

    testWidgets('renders the 3 micro-examples beneath labels', (tester) async {
      await tester.pumpWidget(_wrap(
        TonChooser(
          current: VoicePreference.direct,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('On y va doucement.'), findsOneWidget);
      expect(find.text('Voici ce que ça veut dire.'), findsOneWidget);
      expect(find.text('Pas de filtre. Tu veux savoir.'), findsOneWidget);
    });

    testWidgets('tapping a cell calls onChanged with matching enum',
        (tester) async {
      VoicePreference? captured;
      await tester.pumpWidget(_wrap(
        TonChooser(
          current: VoicePreference.direct,
          onChanged: (v) => captured = v,
        ),
      ));

      await tester.tap(find.text('Doux'));
      await tester.pumpAndSettle();
      expect(captured, VoicePreference.soft);

      await tester.tap(find.text('Non filtré'));
      await tester.pumpAndSettle();
      expect(captured, VoicePreference.unfiltered);
    });

    testWidgets('selected cell exposes a11y "Sélectionné" label',
        (tester) async {
      await tester.pumpWidget(_wrap(
        TonChooser(
          current: VoicePreference.direct,
          onChanged: (_) {},
        ),
      ));

      final selectedSemantics = tester.getSemantics(
        find.byKey(const ValueKey('ton_cell_direct')),
      );
      expect(selectedSemantics.label, contains('Direct'));
      expect(selectedSemantics.label, contains('Sélectionné'));

      final unselectedSemantics = tester.getSemantics(
        find.byKey(const ValueKey('ton_cell_soft')),
      );
      expect(unselectedSemantics.label, contains('Doux'));
      expect(unselectedSemantics.label, contains('Non sélectionné'));
    });

    testWidgets('each cell tap target ≥ 48dp height', (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 360,
          child: TonChooser(
            current: VoicePreference.direct,
            onChanged: (_) {},
          ),
        ),
      ));
      final size = tester.getSize(find.byKey(const ValueKey('ton_cell_soft')));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('"curseur" never appears in rendered text', (tester) async {
      await tester.pumpWidget(_wrap(
        TonChooser(
          current: VoicePreference.direct,
          onChanged: (_) {},
        ),
      ));
      expect(find.textContaining('curseur'), findsNothing);
      expect(find.textContaining('Curseur'), findsNothing);
    });
  });

  group('TonChooserSheet', () {
    testWidgets('renders title, subtitle, "Plus tard" CTA, no banned word',
        (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () =>
                showTonChooserSheet(ctx, current: VoicePreference.direct),
            child: const Text('open'),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Choisis le ton de Mint'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);
      expect(find.textContaining('curseur'), findsNothing);
    });

    testWidgets('"Plus tard" pops with null', (tester) async {
      VoicePreference? result = VoicePreference.direct;
      bool popped = false;
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result =
                  await showTonChooserSheet(ctx, current: VoicePreference.direct);
              popped = true;
            },
            child: const Text('open'),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ton_sheet_skip')));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(result, isNull);
    });

    testWidgets('Continuer pops with selected value', (tester) async {
      VoicePreference? result;
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result = await showTonChooserSheet(ctx,
                  current: VoicePreference.direct);
            },
            child: const Text('open'),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Doux'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ton_sheet_confirm')));
      await tester.pumpAndSettle();

      expect(result, VoicePreference.soft);
    });
  });
}
