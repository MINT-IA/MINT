import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/sequence_run.dart';
import 'package:mint_mobile/models/sequence_template.dart';
import 'package:mint_mobile/widgets/coach/sequence_progress_card.dart';

SequenceRun startRun(SequenceTemplate template) {
  return SequenceRun.start(
    runId: 'test-run',
    templateId: template.id,
    stepIds: template.steps.map((s) => s.id).toList(),
  );
}

Widget wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
}

void main() {
  group('SequenceProgressCard', () {
    testWidgets('renders goal label and progress', (tester) async {
      final run = startRun(SequenceTemplate.housingPurchase);

      await tester.pumpWidget(wrap(SequenceProgressCard(
        run: run,
        goalLabel: 'Achat immobilier',
        currentStepLabel: 'Calcule ta capacit\u00e9 d\'achat',
      )));

      expect(find.text('Achat immobilier'), findsOneWidget);
      expect(find.text('0/4'), findsOneWidget);
      expect(find.text('Calcule ta capacit\u00e9 d\'achat'), findsOneWidget);
    });

    testWidgets('shows advance CTA when onAdvance is set', (tester) async {
      final run = startRun(SequenceTemplate.housingPurchase);
      var advanced = false;

      await tester.pumpWidget(wrap(SequenceProgressCard(
        run: run,
        goalLabel: 'Achat immobilier',
        currentStepLabel: '\u00c9tape 1',
        onAdvance: () => advanced = true,
      )));

      final btn = find.text('Pr\u00eat pour l\'\u00e9tape suivante');
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      expect(advanced, isTrue);
    });

    testWidgets('hides advance CTA when onAdvance is null', (tester) async {
      final run = startRun(SequenceTemplate.housingPurchase);

      await tester.pumpWidget(wrap(SequenceProgressCard(
        run: run,
        goalLabel: 'Test',
        currentStepLabel: 'Step',
        onAdvance: null,
      )));

      expect(find.text('Pr\u00eat pour l\'\u00e9tape suivante'), findsNothing);
    });

    testWidgets('shows quit button when onQuit is set', (tester) async {
      final run = startRun(SequenceTemplate.housingPurchase);
      var quit = false;

      await tester.pumpWidget(wrap(SequenceProgressCard(
        run: run,
        goalLabel: 'Test',
        currentStepLabel: 'Step',
        onQuit: () => quit = true,
      )));

      final btn = find.text('Quitter le parcours');
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      expect(quit, isTrue);
    });

    testWidgets('progress updates when steps are completed', (tester) async {
      var run = startRun(SequenceTemplate.optimize3a);
      run = run.completeStep('3a_01_simulator', {'contribution': 7258});
      run = run.activateStep('3a_02_withdrawal');

      await tester.pumpWidget(wrap(SequenceProgressCard(
        run: run,
        goalLabel: 'Optimisation 3a',
        currentStepLabel: 'Retrait \u00e9chelonn\u00e9',
      )));

      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('route icon is present', (tester) async {
      final run = startRun(SequenceTemplate.housingPurchase);

      await tester.pumpWidget(wrap(SequenceProgressCard(
        run: run,
        goalLabel: 'Test',
        currentStepLabel: 'Step',
      )));

      expect(find.byIcon(Icons.route_outlined), findsOneWidget);
    });
  });
}
