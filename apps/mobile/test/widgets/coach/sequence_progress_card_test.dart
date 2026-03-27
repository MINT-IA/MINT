import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/sequence_progress_card.dart';

Widget wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
}

void main() {
  group('SequenceProgressCard', () {
    testWidgets('renders goal label and progress', (tester) async {
      await tester.pumpWidget(wrap(const SequenceProgressCard(
        completedCount: 0,
        totalCount: 4,
        goalLabel: 'Achat immobilier',
        currentStepLabel: 'Calcule ta capacit\u00e9 d\'achat',
      )));

      expect(find.text('Achat immobilier'), findsOneWidget);
      expect(find.text('0/4'), findsOneWidget);
      expect(find.text('Calcule ta capacit\u00e9 d\'achat'), findsOneWidget);
    });

    testWidgets('shows advance CTA when onAdvance is set', (tester) async {
      var advanced = false;

      await tester.pumpWidget(wrap(SequenceProgressCard(
        completedCount: 1,
        totalCount: 4,
        goalLabel: 'Achat immobilier',
        currentStepLabel: '\u00c9tape 2/4',
        onAdvance: () => advanced = true,
      )));

      final btn = find.text('Pr\u00eat pour l\'\u00e9tape suivante');
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      expect(advanced, isTrue);
    });

    testWidgets('hides advance CTA when onAdvance is null', (tester) async {
      await tester.pumpWidget(wrap(const SequenceProgressCard(
        completedCount: 0,
        totalCount: 4,
        goalLabel: 'Test',
        currentStepLabel: 'Step',
        onAdvance: null,
      )));

      expect(find.text('Pr\u00eat pour l\'\u00e9tape suivante'), findsNothing);
    });

    testWidgets('shows quit button when onQuit is set', (tester) async {
      var quit = false;

      await tester.pumpWidget(wrap(SequenceProgressCard(
        completedCount: 0,
        totalCount: 4,
        goalLabel: 'Test',
        currentStepLabel: 'Step',
        onQuit: () => quit = true,
      )));

      final btn = find.text('Quitter le parcours');
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      expect(quit, isTrue);
    });

    testWidgets('progress bar reflects completion', (tester) async {
      await tester.pumpWidget(wrap(const SequenceProgressCard(
        completedCount: 2,
        totalCount: 4,
        goalLabel: 'Test',
        currentStepLabel: '\u00c9tape 3/4',
      )));

      expect(find.text('2/4'), findsOneWidget);
    });

    testWidgets('route icon is present', (tester) async {
      await tester.pumpWidget(wrap(const SequenceProgressCard(
        completedCount: 0,
        totalCount: 3,
        goalLabel: 'Test',
        currentStepLabel: 'Step',
      )));

      expect(find.byIcon(Icons.route_outlined), findsOneWidget);
    });
  });
}
