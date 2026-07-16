import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/plan_preview_card.dart';
import 'package:mint_mobile/widgets/coach/widget_renderer.dart';
import 'package:mint_mobile/widgets/home/financial_plan_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _calculatorNarrative =
    'Narration calculateur synthétique — aucune donnée LLM.';
const _llmNarrative = 'NARRATION LLM SENTINELLE À NE JAMAIS AFFICHER';
const _specificSource =
    'Calcul MINT synthétique — objectif CHF divisé par mois restants';
const _mandatoryMintDisclaimer =
    'Les résultats présentés sont des estimations à titre indicatif, '
    'basées sur les données fournies et la législation en vigueur. '
    'Ils ne constituent pas un conseil financier personnalisé. '
    'Consultez un·e spécialiste pour votre situation spécifique.';

CoachProfileProvider _loadedLedger() {
  return CoachProfileProvider()
    ..createFromRemoteProfile({
      'birth_year': 1986,
      'canton': 'VD',
      'income_gross_yearly': 96000.0,
    });
}

FinancialPlan _planFor(CoachProfileProvider ledger) {
  final profile = ledger.profile!;
  final targetDate = DateTime.now().add(const Duration(days: 730));
  return FinancialPlan(
    id: 'synthetic-domain-plan',
    goalDescription: 'Objectif synthétique explicite',
    goalCategory: 'goal_general',
    monthlyTarget: 1000,
    milestones: [
      PlanMilestone(
        targetDate: targetDate,
        targetAmount: 24000,
        description: '100% atteint — 24000 CHF',
      ),
    ],
    projectedOutcome: 24000,
    targetDate: targetDate,
    generatedAt: DateTime(2026, 7, 16),
    profileHashAtGeneration: computeProfileHash(profile),
    coachNarrative: _calculatorNarrative,
    confidenceLevel: 50,
    sources: const [_specificSource],
    disclaimer: _mandatoryMintDisclaimer,
  );
}

Widget _localized(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Widget _toolHarness({
  required CoachProfileProvider ledger,
  required FinancialPlanProvider plans,
  required Map<String, dynamic> input,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: ledger),
      ChangeNotifierProvider<FinancialPlanProvider>.value(value: plans),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr')],
      home: Scaffold(
        body: Builder(
          builder: (context) => WidgetRenderer.build(
            context,
            RagToolCall(name: 'generate_financial_plan', input: input),
          )!,
        ),
      ),
    ),
  );
}

Future<void> _pumpAsync(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

int _renderedTextCount(WidgetTester tester, String fragment) {
  final normalizedFragment = fragment.replaceAll('\u00a0', ' ');
  return tester.widgetList<Text>(find.byType(Text)).where((text) {
    return (text.data ?? '')
        .replaceAll('\u00a0', ' ')
        .contains(normalizedFragment);
  }).length;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('G1-BND-06 domain RED — Coach and Aujourd’hui surfaces', () {
    testWidgets(
      'Coach does not invent a CHF plan without user-owned amount and date',
      (tester) async {
        final ledger = _loadedLedger();
        final plans = FinancialPlanProvider()..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _toolHarness(
            ledger: ledger,
            plans: plans,
            input: const {'goal': 'Objectif conversationnel sans paramètres'},
          ),
        );
        await _pumpAsync(tester);

        expect(
          plans.hasPlan,
          isFalse,
          reason:
              'The LLM goal label does not own a CHF amount or target date.',
        );
      },
    );

    testWidgets('a fresh plan keeps calculator narrative over LLM narrative',
        (tester) async {
      final ledger = _loadedLedger();
      final plans = FinancialPlanProvider()
        ..setPlanDirect(_planFor(ledger))
        ..attachProfileProvider(ledger);
      addTearDown(ledger.dispose);
      addTearDown(plans.dispose);

      await tester.pumpWidget(
        _toolHarness(
          ledger: ledger,
          plans: plans,
          input: const {
            'goal': 'Objectif synthétique explicite',
            'narrative': _llmNarrative,
          },
        ),
      );
      await tester.pump();

      final card = tester.widget<PlanPreviewCard>(find.byType(PlanPreviewCard));
      expect(card.coachNarrative, _calculatorNarrative);
      expect(find.text(_llmNarrative), findsNothing);
    });

    testWidgets('Coach renders the sources carried by the specific plan',
        (tester) async {
      final ledger = _loadedLedger();
      final plan = _planFor(ledger);
      addTearDown(ledger.dispose);

      await tester.pumpWidget(_localized(PlanPreviewCard.fromPlan(plan)));
      await tester.pump();

      expect(find.text(_specificSource), findsOneWidget);
    });

    testWidgets(
      'Aujourd’hui renders plan sources and not hardcoded ARB citations',
      (tester) async {
        final ledger = _loadedLedger();
        final plan = _planFor(ledger);
        addTearDown(ledger.dispose);

        await tester.pumpWidget(
          _localized(
            FinancialPlanCard(
              plan: plan,
              isStale: false,
              onRecalculate: (_) {},
            ),
          ),
        );
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();

        expect(
          (
            _renderedTextCount(tester, _specificSource),
            _renderedTextCount(tester, _mandatoryMintDisclaimer),
            _renderedTextCount(tester, 'LIFD art. 38'),
            _renderedTextCount(tester, 'LPP art. 14'),
          ),
          (1, 1, 0, 0),
          reason: 'The card must render plan.sources and plan.disclaimer, not '
              'generic citations embedded in translations.',
        );
      },
    );
  });
}
