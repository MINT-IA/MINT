import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/crisis_dashboard_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final indicators = [
    const CrisisIndicator(
      label: 'Réserves de trésorerie',
      emoji: '💰',
      value: '2.5',
      unit: 'mois',
      status: CrisisStatus.warning,
      legalRef: 'Objectif : 3 mois minimum',
      action: 'Constitue un coussin de 3 mois avant tout remboursement anticipé.',
    ),
    const CrisisIndicator(
      label: 'Jours de chômage consommés',
      emoji: '📅',
      value: '45',
      unit: '/ 260',
      status: CrisisStatus.ok,
      legalRef: 'LACI art. 27 — max 260 jours sur 2 ans',
    ),
    const CrisisIndicator(
      label: 'Libre passage LPP transféré',
      emoji: '🏦',
      value: 'NON',
      unit: '',
      status: CrisisStatus.critical,
      legalRef: 'LPP art. 5 — 30 jours après fin du contrat',
      action: 'Appelle sfbvg.ch immédiatement — risque de perdre les intérêts.',
    ),
    const CrisisIndicator(
      label: 'Déficit mensuel',
      emoji: '📉',
      value: '-200',
      unit: 'CHF',
      status: CrisisStatus.warning,
      legalRef: 'LP art. 93 — minimum vital',
      action: 'Identifie 2 postes à couper — objectif : revenir à 0.',
    ),
    const CrisisIndicator(
      label: 'Dettes en cours',
      emoji: '💳',
      value: '15\'000',
      unit: 'CHF',
      status: CrisisStatus.warning,
      legalRef: 'Ratio : 27% du revenu annuel',
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
            child: CrisisDashboardWidget(
              indicators: indicators,
              priorityAction: 'Transférer le libre passage LPP dans les 30 jours. Appelle sfbvg.ch.',
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('crise'), findsWidgets);
  });

  testWidgets('shows all indicator labels', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Réserves'), findsWidgets);
    expect(find.textContaining('chômage'), findsWidgets);
    expect(find.textContaining('LPP'), findsWidgets);
  });

  testWidgets('shows critical indicator count', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('critique'), findsWidgets);
  });

  testWidgets('shows indicator values', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('2.5'), findsWidgets);
    expect(find.textContaining('45'), findsWidgets);
  });

  testWidgets('shows priority action', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('libre passage'), findsWidgets);
  });

  testWidgets('shows LACI legal reference', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LACI'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('tableau de bord crise', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
