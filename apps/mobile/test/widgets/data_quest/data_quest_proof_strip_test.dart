import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/data_quest/data_quest_service.dart';
import 'package:mint_mobile/widgets/data_quest/data_quest_proof_strip.dart';

void main() {
  Finder findSemanticsIdentifier(String identifier) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.identifier == identifier,
      description: 'Semantics(identifier: $identifier)',
    );
  }

  String? semanticsValue(WidgetTester tester, String identifier) {
    final widget =
        tester.widget<Semantics>(findSemanticsIdentifier(identifier));
    return widget.properties.value;
  }

  Future<void> pumpProofStrip(
    WidgetTester tester, {
    required DataQuestPlan plan,
  }) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: DataQuestProofStrip(
          plan: plan,
          semanticsPrefix: 'sim3a',
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> pumpNextQuestionCard(
    WidgetTester tester, {
    required DataQuestPlan plan,
    String semanticsPrefix = 'sim3a',
  }) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: DataQuestNextQuestionCard(
          plan: plan,
          semanticsPrefix: semanticsPrefix,
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> pumpNextQuestionCardRouter(
    WidgetTester tester, {
    required DataQuestPlan plan,
    String semanticsPrefix = 'sim3a',
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: DataQuestNextQuestionCard(
              plan: plan,
              semanticsPrefix: semanticsPrefix,
            ),
          ),
        ),
        GoRoute(
          path: '/data-block/:type',
          builder: (_, state) => Scaffold(
            body: Text('block ${state.pathParameters['type']}'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      routerConfig: router,
    ));
    await tester.pump();
  }

  testWidgets('exposes runtime proof id through semantics only',
      (tester) async {
    await pumpProofStrip(
      tester,
      plan: const DataQuestPlan(
        caseId: 'first_salary_tax',
        targetRoute: '/pilier-3a',
        pdfSectionId: 'dossier_first_salary_tax',
        maestroFlowId: 'pending',
        runtimeProofId: 'mobile-first-salary-patrol',
        asks: [],
      ),
    );

    expect(
      semanticsValue(tester, 'sim3a_data_quest_runtime_proof'),
      'mobile-first-salary-patrol',
    );
    expect(
      tester
          .getSemantics(
            find.bySemanticsIdentifier('sim3a_data_quest_runtime_proof'),
          )
          .value,
      'mobile-first-salary-patrol',
    );
    final runtimeProofSemantics = tester.widget<Semantics>(
      findSemanticsIdentifier('sim3a_data_quest_runtime_proof'),
    );
    expect(runtimeProofSemantics.properties.hidden, isTrue);
    expect(find.textContaining('mobile-first-salary-patrol'), findsNothing);
    expect(find.textContaining('pending'), findsNothing);
  });

  testWidgets('next question card names the first-salary 3a contribution',
      (tester) async {
    await pumpNextQuestionCard(
      tester,
      plan: const DataQuestPlan(
        caseId: 'first_salary_tax',
        targetRoute: '/pilier-3a',
        pdfSectionId: 'dossier_first_salary_tax',
        maestroFlowId: 'pending',
        runtimeProofId: 'mobile-first-salary-patrol',
        asks: [
          DataQuestAsk(
            caseId: 'first_salary_tax',
            inputKey: 'pillar3aAnnual',
            ledgerKey: 'pillar3aAnnual',
            questionId: 'ask_pillar3a_annual',
            mode: DataQuestAskMode.collect,
            tone: DataQuestTone.plain,
            stage: DataQuestStage.useful,
          ),
        ],
      ),
    );

    expect(find.bySemanticsIdentifier('sim3a_data_quest_next_question'),
        findsOneWidget);
    expect(find.text('Versement annuel'), findsOneWidget);
    expect(find.text('Donnée du scénario'), findsNothing);
  });

  testWidgets('next question card names household composition for mortgage',
      (tester) async {
    await pumpNextQuestionCard(
      tester,
      semanticsPrefix: 'mortgage',
      plan: const DataQuestPlan(
        caseId: 'buy_property',
        targetRoute: '/hypotheque',
        pdfSectionId: 'dossier_buy_property',
        maestroFlowId: 'pending',
        runtimeProofId: 'mobile-f2-patrol',
        asks: [
          DataQuestAsk(
            caseId: 'buy_property',
            inputKey: 'householdType',
            ledgerKey: 'householdType',
            questionId: 'ask_household_type',
            mode: DataQuestAskMode.collect,
            tone: DataQuestTone.plain,
            stage: DataQuestStage.guard,
          ),
        ],
      ),
    );

    expect(find.bySemanticsIdentifier('mortgage_data_quest_next_question'),
        findsOneWidget);
    expect(find.text('Composition du ménage'), findsOneWidget);
    expect(find.text('Donnée du scénario'), findsNothing);
  });

  testWidgets('next question card opens the owner data block', (tester) async {
    await pumpNextQuestionCardRouter(
      tester,
      semanticsPrefix: 'mortgage',
      plan: const DataQuestPlan(
        caseId: 'buy_property',
        targetRoute: '/hypotheque',
        pdfSectionId: 'dossier_buy_property',
        maestroFlowId: 'pending',
        runtimeProofId: 'mobile-f2-patrol',
        asks: [
          DataQuestAsk(
            caseId: 'buy_property',
            inputKey: 'householdType',
            ledgerKey: 'householdType',
            questionId: 'ask_household_type',
            mode: DataQuestAskMode.collect,
            tone: DataQuestTone.plain,
            stage: DataQuestStage.guard,
          ),
        ],
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey('mortgage_data_quest_next_question_cta'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('block compositionMenage'), findsOneWidget);
  });

  testWidgets('next question card opens patrimoine owner for mortgage rate',
      (tester) async {
    await pumpNextQuestionCardRouter(
      tester,
      semanticsPrefix: 'mortgage',
      plan: const DataQuestPlan(
        caseId: 'buy_property',
        targetRoute: '/hypotheque',
        pdfSectionId: 'dossier_buy_property',
        maestroFlowId: 'pending',
        runtimeProofId: 'mobile-f2-patrol',
        asks: [
          DataQuestAsk(
            caseId: 'buy_property',
            inputKey: 'patrimoine.mortgageRate',
            ledgerKey: 'patrimoine.mortgageRate',
            questionId: 'ask_mortgage_rate',
            mode: DataQuestAskMode.collect,
            tone: DataQuestTone.plain,
            stage: DataQuestStage.required,
          ),
        ],
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey('mortgage_data_quest_next_question_cta'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('block patrimoine'), findsOneWidget);
  });

  testWidgets('next question card opens patrimoine owner for parent liquidity',
      (tester) async {
    await pumpNextQuestionCardRouter(
      tester,
      semanticsPrefix: 'succession',
      plan: const DataQuestPlan(
        caseId: 'transmit_property',
        targetRoute: '/succession',
        pdfSectionId: 'dossier_transmit_property',
        maestroFlowId: 'phase2_data_quest_transmit_property',
        runtimeProofId: 'mobile-transmit-property-patrol',
        asks: [
          DataQuestAsk(
            caseId: 'transmit_property',
            inputKey: 'parentLiquidAssets',
            ledgerKey: 'patrimoine.epargneLiquide',
            questionId: 'ask_parent_liquid_assets',
            mode: DataQuestAskMode.collect,
            tone: DataQuestTone.gentle,
            stage: DataQuestStage.guard,
          ),
        ],
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey('succession_data_quest_next_question_cta'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('block patrimoine'), findsOneWidget);
  });

  testWidgets('next question card opens retirement-goal owner for target age',
      (tester) async {
    await pumpNextQuestionCardRouter(
      tester,
      semanticsPrefix: 'succession',
      plan: const DataQuestPlan(
        caseId: 'transmit_property',
        targetRoute: '/succession',
        pdfSectionId: 'dossier_transmit_property',
        maestroFlowId: 'phase2_data_quest_transmit_property',
        runtimeProofId: 'mobile-transmit-property-patrol',
        asks: [
          DataQuestAsk(
            caseId: 'transmit_property',
            inputKey: 'targetRetirementAge',
            ledgerKey: 'targetRetirementAge',
            questionId: 'ask_target_retirement_age',
            mode: DataQuestAskMode.collect,
            tone: DataQuestTone.gentle,
            stage: DataQuestStage.guard,
          ),
        ],
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey('succession_data_quest_next_question_cta'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('block objectifRetraite'), findsOneWidget);
  });

  testWidgets('next question card opens LPP owner for pension assets',
      (tester) async {
    await pumpNextQuestionCardRouter(
      tester,
      semanticsPrefix: 'succession',
      plan: const DataQuestPlan(
        caseId: 'transmit_property',
        targetRoute: '/succession',
        pdfSectionId: 'dossier_transmit_property',
        maestroFlowId: 'phase2_data_quest_transmit_property',
        runtimeProofId: 'mobile-transmit-property-patrol',
        asks: [
          DataQuestAsk(
            caseId: 'transmit_property',
            inputKey: 'avoirLpp',
            ledgerKey: 'avoirLpp',
            questionId: 'ask_lpp_assets',
            mode: DataQuestAskMode.collect,
            tone: DataQuestTone.gentle,
            stage: DataQuestStage.guard,
          ),
        ],
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey('succession_data_quest_next_question_cta'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('block lpp'), findsOneWidget);
  });

  testWidgets('next question card opens 3a owner for pension assets',
      (tester) async {
    await pumpNextQuestionCardRouter(
      tester,
      semanticsPrefix: 'succession',
      plan: const DataQuestPlan(
        caseId: 'transmit_property',
        targetRoute: '/succession',
        pdfSectionId: 'dossier_transmit_property',
        maestroFlowId: 'phase2_data_quest_transmit_property',
        runtimeProofId: 'mobile-transmit-property-patrol',
        asks: [
          DataQuestAsk(
            caseId: 'transmit_property',
            inputKey: 'pillar3aBalance',
            ledgerKey: 'pillar3aBalance',
            questionId: 'ask_pillar3a_balance',
            mode: DataQuestAskMode.collect,
            tone: DataQuestTone.gentle,
            stage: DataQuestStage.guard,
          ),
        ],
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey('succession_data_quest_next_question_cta'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('block 3a'), findsOneWidget);
  });
}
