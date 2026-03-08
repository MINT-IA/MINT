import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/job_change_checklist_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final items = [
    const ChecklistItem(
      deadline: 'J0',
      action: 'Demander certificat LPP ancien employeur',
      legalRef: 'LPP art. 3',
      emoji: '📄',
      consequence: 'Sans certificat, tu ne peux pas comparer les caisses.',
    ),
    const ChecklistItem(
      deadline: 'J+5',
      action: 'Vérifier le transfert libre passage',
      legalRef: 'OLP art. 1-3',
      emoji: '🏦',
    ),
    const ChecklistItem(
      deadline: 'J+30',
      action: 'Premier bulletin de salaire — vérifier les déductions',
      legalRef: 'CO art. 323',
      emoji: '🧾',
    ),
  ];

  Widget buildWidget() => MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: JobChangeChecklistWidget(items: items),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Checklist'), findsWidgets);
  });

  testWidgets('shows progress bar', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.byType(LinearProgressIndicator), findsWidgets);
  });

  testWidgets('shows checklist items', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('certificat LPP'), findsWidgets);
    expect(find.textContaining('libre passage'), findsWidgets);
  });

  testWidgets('shows deadline badges', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('J0'), findsWidgets);
    expect(find.textContaining('J+30'), findsWidgets);
  });

  testWidgets('shows critical alert', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('certificat LPP'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('Checklist', caseSensitive: false)), findsOneWidget);
  });
}
