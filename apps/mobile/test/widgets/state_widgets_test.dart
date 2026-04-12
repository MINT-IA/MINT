import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/common/mint_loading_state.dart';
import 'package:mint_mobile/widgets/common/mint_error_state.dart';

void main() {
  group('MintLoadingState', () {
    testWidgets('renders CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MintLoadingState()),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders with message text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MintLoadingState(message: 'Loading data...')),
        ),
      );

      expect(find.text('Loading data...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders without message text when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MintLoadingState()),
        ),
      );

      // Only the indicator, no text widgets with message content
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Should not find any Text widget (no message)
      final textWidgets = find.byType(Text);
      expect(textWidgets, findsNothing);
    });

    testWidgets('is wrapped in Center widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MintLoadingState()),
        ),
      );

      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('has Semantics with default label when no message',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MintLoadingState()),
        ),
      );

      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final hasLoadingLabel =
          semantics.any((s) => s.properties.label == 'Loading');
      expect(hasLoadingLabel, isTrue);
    });

    testWidgets('has Semantics with message label when provided',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MintLoadingState(message: 'Please wait')),
        ),
      );

      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final hasLabel =
          semantics.any((s) => s.properties.label == 'Please wait');
      expect(hasLabel, isTrue);
    });
  });

  group('MintErrorState', () {
    testWidgets('renders error icon, title, and body', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MintErrorState(
              title: 'Error occurred',
              body: 'Please try again later.',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Error occurred'), findsOneWidget);
      expect(find.text('Please try again later.'), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry is provided', (tester) async {
      var retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MintErrorState(
              title: 'Error',
              body: 'Something went wrong.',
              retryLabel: 'Retry',
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      expect(retryCalled, isTrue);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MintErrorState(
              title: 'Error',
              body: 'Something went wrong.',
            ),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('is wrapped in Center widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MintErrorState(
              title: 'Error',
              body: 'Body text',
            ),
          ),
        ),
      );

      // MintErrorState's Center is an ancestor of the error icon
      expect(
        find.ancestor(
          of: find.byIcon(Icons.error_outline),
          matching: find.byType(Center),
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('error icon has size 48', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MintErrorState(
              title: 'Error',
              body: 'Body text',
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.size, 48);
    });

    testWidgets('accepts i18n strings without hardcoded text', (tester) async {
      const frenchTitle = 'Quelque chose n\u2019a pas march\u00e9';
      const frenchBody = 'V\u00e9rifie ta connexion et r\u00e9essaie.';
      const frenchRetry = 'R\u00e9essayer';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MintErrorState(
              title: frenchTitle,
              body: frenchBody,
              retryLabel: frenchRetry,
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text(frenchTitle), findsOneWidget);
      expect(find.text(frenchBody), findsOneWidget);
      expect(find.text(frenchRetry), findsOneWidget);
    });
  });
}
