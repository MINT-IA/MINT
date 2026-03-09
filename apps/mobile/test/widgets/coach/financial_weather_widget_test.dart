import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/financial_weather_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final scenarios = [
    const WeatherScenario(
      weather: FinancialWeather.sunny,
      probabilityPercent: 45,
      monthlyIncomeMin: 5200,
      monthlyIncomeMax: 6500,
      description: 'Tu vis confortablement',
    ),
    const WeatherScenario(
      weather: FinancialWeather.partlyCloudy,
      probabilityPercent: 35,
      monthlyIncomeMin: 4200,
      monthlyIncomeMax: 5200,
      description: 'Budget serr\u00e9 mais ok',
    ),
    const WeatherScenario(
      weather: FinancialWeather.rainy,
      probabilityPercent: 20,
      monthlyIncomeMin: 3500,
      monthlyIncomeMax: 4200,
      description: 'Il faudra des ajustements',
    ),
  ];

  Widget buildTestWidget({
    FinancialWeather outlook = FinancialWeather.partlyCloudy,
    FinancialWeather? trend,
  }) {
    return MaterialApp(
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
          child: FinancialWeatherWidget(
            scenarios: scenarios,
            currentOutlook: outlook,
            trendTowards: trend,
          ),
        ),
      ),
    );
  }

  group('FinancialWeatherWidget', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(FinancialWeatherWidget), findsOneWidget);
    });

    testWidgets('shows header', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('t\u00e9o'), findsWidgets);
    });

    testWidgets('shows all 3 scenarios', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('Soleil'), findsWidgets);
      expect(find.textContaining('Nuageux'), findsWidgets);
      expect(find.textContaining('Pluie'), findsWidgets);
    });

    testWidgets('shows current outlook', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('Aujourd'), findsWidgets);
    });

    testWidgets('shows probabilities', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('45%'), findsWidgets);
      expect(find.textContaining('35%'), findsWidgets);
      expect(find.textContaining('20%'), findsWidgets);
    });

    testWidgets('shows disclaimer', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('conseil'), findsWidgets);
    });

    testWidgets('handles trend indicator', (tester) async {
      await tester.pumpWidget(
          buildTestWidget(trend: FinancialWeather.sunny));
      await tester.pumpAndSettle();
      expect(find.textContaining('tendance'), findsWidgets);
    });

    testWidgets('has Semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
