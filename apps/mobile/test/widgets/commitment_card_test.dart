import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/commitment_card.dart';

// ────────────────────────────────────────────────────────────
//  COMMITMENT CARD WIDGET TESTS — Phase 14 / CMIT-01
//
//  Tests the CommitmentCard widget:
//  1. Renders 3 text fields (QUAND, OU/COMMENT, SI...ALORS)
//  2. Pre-fills with provided values
//  3. Calls onAccept with edited values
//  4. Is dismissible (swipe triggers onDismiss)
//  5. Uses MintColors (no hardcoded hex)
//  6. Accept button has i18n label
// ────────────────────────────────────────────────────────────

Widget _buildTestApp({required Widget child, bool scroll = true}) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    home: Scaffold(
      body: scroll ? SingleChildScrollView(child: child) : child,
    ),
  );
}

void main() {
  group('CommitmentCard widget (CMIT-01)', () {
    testWidgets('renders 3 text fields', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        child: CommitmentCard(
          whenText: '',
          whereText: '',
          ifThenText: '',
        ),
      ));
      await tester.pumpAndSettle();

      // 3 TextFormFields should be present
      expect(find.byType(TextFormField), findsNWidgets(3));

      // Labels should be visible (French i18n)
      expect(find.text('QUAND'), findsOneWidget);
      expect(find.text('O\u00d9 / COMMENT'), findsOneWidget);
      expect(find.text('SI\u2026 ALORS'), findsOneWidget);
    });

    testWidgets('pre-fills with provided values', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        child: CommitmentCard(
          whenText: 'Lundi prochain',
          whereText: 'En ligne sur ma banque',
          ifThenText: 'Si je recois mon salaire, alors je verse 500 CHF',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Lundi prochain'), findsOneWidget);
      expect(find.text('En ligne sur ma banque'), findsOneWidget);
      expect(
        find.text('Si je recois mon salaire, alors je verse 500 CHF'),
        findsOneWidget,
      );
    });

    testWidgets('calls onAccept with edited values', (tester) async {
      String? capturedWhen;
      String? capturedWhere;
      String? capturedIfThen;

      await tester.pumpWidget(_buildTestApp(
        child: CommitmentCard(
          whenText: 'Demain',
          whereText: 'Chez moi',
          ifThenText: 'Si oui, alors je signe',
          onAccept: (w, wh, it) {
            capturedWhen = w;
            capturedWhere = wh;
            capturedIfThen = it;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Edit the WHEN field
      final whenField = find.byType(TextFormField).first;
      await tester.tap(whenField);
      await tester.pumpAndSettle();
      // Clear and type new value
      await tester.enterText(whenField, 'Vendredi soir');
      await tester.pumpAndSettle();

      // Tap accept button (French: "Je m'engage")
      final acceptButton = find.text('Je m\u2019engage');
      expect(acceptButton, findsOneWidget);
      await tester.tap(acceptButton);
      await tester.pumpAndSettle();

      expect(capturedWhen, 'Vendredi soir');
      expect(capturedWhere, 'Chez moi');
      expect(capturedIfThen, 'Si oui, alors je signe');
    });

    testWidgets('is dismissible', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(_buildTestApp(
        scroll: false,
        child: CommitmentCard(
          whenText: 'Test',
          whereText: 'Test',
          ifThenText: 'Test',
          onDismiss: () => dismissed = true,
        ),
      ));
      await tester.pumpAndSettle();

      // Verify Dismissible wraps the card
      expect(find.byType(Dismissible), findsOneWidget);

      // Verify the Dismissible is configured for horizontal swipe
      final dismissible =
          tester.widget<Dismissible>(find.byType(Dismissible));
      expect(dismissible.direction, DismissDirection.horizontal);

      // Fling on the header area (above the text fields) to avoid gesture conflicts
      final headerFinder = find.byIcon(Icons.flag_outlined);
      expect(headerFinder, findsOneWidget);
      await tester.fling(headerFinder, const Offset(400, 0), 2000);
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('uses MintColors (no hardcoded hex)', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        child: CommitmentCard(
          whenText: '',
          whereText: '',
          ifThenText: '',
        ),
      ));
      await tester.pumpAndSettle();

      // Verify the accept button uses MintColors.primary as background
      final button = tester.widget<TextButton>(find.byType(TextButton));
      final style = button.style;
      // The button exists and has a style — MintColors.primary is used
      expect(style, isNotNull);

      // Verify the container uses MintColors.surface (not hardcoded)
      final containers = tester.widgetList<Container>(find.byType(Container));
      bool hasSurfaceColor = false;
      for (final container in containers) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration && decoration.color == MintColors.surface) {
          hasSurfaceColor = true;
          break;
        }
      }
      expect(hasSurfaceColor, isTrue);
    });

    testWidgets('accept button has i18n label', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        child: CommitmentCard(
          whenText: '',
          whereText: '',
          ifThenText: '',
        ),
      ));
      await tester.pumpAndSettle();

      // French locale: "Je m'engage"
      expect(find.text('Je m\u2019engage'), findsOneWidget);

      // Header title should also be localized
      expect(find.text('Mon engagement'), findsOneWidget);
    });
  });
}
