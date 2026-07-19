import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';

import '../../support/pillar3a_beneficiary_handoff_fixture.dart';

Map<String, dynamic> _answers() => <String, dynamic>{
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_civil_status': 'single',
      'q_children': '0',
      'q_employment_status': 'employee',
      'q_net_income_period_chf': 6000.0,
    };

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: home,
    );

String _renderedUnder(WidgetTester tester, Finder root) => tester
    .widgetList<Text>(find.descendant(of: root, matching: find.byType(Text)))
    .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
    .join('\n');

void main() {
  testWidgets('dossier renders the exact Swiss 3a specialist allowlist',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_app(FinancialReportScreenV2(
      wizardAnswers: _answers(),
      pillar3aBeneficiaryHandoff: pillar3aBeneficiaryHandoffFixture(),
    )));
    await tester.pumpAndSettle();

    final section = find.bySemanticsIdentifier(
      'financial_report_pillar3a_beneficiary_handoff',
    );
    expect(section, findsOneWidget);
    final rendered = _renderedUnder(tester, section);
    for (final exact in const <String>[
      'Date portée par la source institutionnelle',
      'Année juridique indiquée dans le document',
      'Dates attestées par l’institution, non déduites par MINT',
      'Situation du contrat déclarée par la personne : actif et non versé',
      'La date de la source et l’année juridique ne permettent pas de conclure '
          'qu’aucune désignation plus récente n’existe. Le régime indiqué est '
          'celui attesté par le document; MINT ne le déduit ni de ces dates ni '
          'de la relation déclarée.',
      'Quelle désignation est actuellement enregistrée auprès de '
          'l’institution pour ce contrat ?',
      'Quelle est sa date de prise d’effet, la date de sa dernière modification '
          'et quel régime temporel l’institution confirme-t-elle ?',
      'MINT ne détermine ni la personne bénéficiaire, ni l’ordre, ni la part, '
          'et ne valide pas la portée juridique de la désignation.',
      'OPP 3 art. 2, al. 2–3; modification du 12 juin 2026, RO 2026 325, '
          'ch. II, al. 2; entrée en vigueur le 1er juin 2027; OFAS, Bulletin '
          'PP no 168, ch. 1168.',
    ]) {
      expect(rendered, contains(exact), reason: exact);
    }
    for (final expected in const <String>[
      'Confirmation de l’institution 3a',
      '18 juillet 2026',
      '2026',
      '15 janvier 2026',
      '12 juin 2026',
      '19 juillet 2026',
    ]) {
      expect(rendered, contains(expected), reason: expected);
    }

    final lowered = rendered.toLowerCase();
    for (final forbidden in const <String>[
      '11111111-1111-4111-8111-111111111111',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '33333333-3333-4333-8333-333333333333',
      'referenceid',
      'documentauthorityid',
      'nom du bénéficiaire',
      'classe bénéficiaire',
      'rang bénéficiaire',
      'quote-part',
      'sha256',
      '/private/',
      '.pdf',
      'iban',
      'numéro avs',
      'ocr',
    ]) {
      expect(lowered, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  testWidgets('dossier omits exact 3a section when handoff is null',
      (tester) async {
    await tester.pumpWidget(_app(FinancialReportScreenV2(
      wizardAnswers: _answers(),
    )));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsIdentifier(
        'financial_report_pillar3a_beneficiary_handoff',
      ),
      findsNothing,
    );
  });
}
