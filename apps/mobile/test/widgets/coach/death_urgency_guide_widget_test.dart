import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/death_urgency_guide_widget.dart';

void main() {
  final phases = [
    UrgencyPhase(
      timeframe: '24h',
      emoji: '🕊️',
      title: 'Urgences immédiates',
      actions: [
        'Déclarer le décès à l\'état civil (24h).',
        'Contacter le médecin pour le certificat.',
      ],
      color: Colors.red,
    ),
    UrgencyPhase(
      timeframe: '1 semaine',
      emoji: '📄',
      title: 'Démarches administratives',
      actions: [
        'Informer la caisse AVS.',
        'Contacter la caisse de pension LPP.',
      ],
      color: Colors.orange,
    ),
  ];

  Widget buildWidget() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DeathUrgencyGuideWidget(phases: phases),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('urgence'), findsWidgets);
  });

  testWidgets('shows phase timeframes', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('24h'), findsWidgets);
    expect(find.textContaining('1 semaine'), findsWidgets);
  });

  testWidgets('shows phase titles', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Urgences immédiates'), findsWidgets);
  });

  testWidgets('first phase is expanded by default', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('état civil'), findsWidgets);
  });

  testWidgets('shows support note', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('seul'), findsWidgets);
  });

  testWidgets('shows CC legal reference', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('CC'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('urgence décès', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
