import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
