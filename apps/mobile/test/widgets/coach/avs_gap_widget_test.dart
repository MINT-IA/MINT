import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/expat_service.dart';
import 'package:mint_mobile/widgets/coach/avs_gap_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  Widget buildWidget({
    int? ciObservedMissingContributionYears,
    VoidCallback? onOpenAvsVerificationGuide,
  }) =>
      MaterialApp(
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
            child: AvsGapWidget(
              scenarioStarted: true,
              assessment: ExpatService.assessAvsGapOrientation(
                scenarioStarted: true,
                yearsAbroad: 5,
                ciObservedMissingContributionYears:
                    ciObservedMissingContributionYears,
              ),
              onOpenAvsVerificationGuide: onOpenAvsVerificationGuide ?? () {},
            ),
          ),
        ),
      );

  testWidgets('declared years abroad stay facts to verify, not AVS gaps',
      (tester) async {
    await tester.pumpWidget(buildWidget());

    expect(find.byKey(const Key('expat_avs_declared_years')), findsOneWidget);
    expect(find.textContaining('5'), findsWidgets);
    expect(find.textContaining('pas automatiquement'), findsWidgets);
    expect(find.byKey(const Key('expat_avs_gap_unknown')), findsOneWidget);
  });

  testWidgets(
      'never renders a personal pension or loss amount without evidence',
      (tester) async {
    await tester.pumpWidget(buildWidget());

    expect(find.textContaining(RegExp(r'CHF\s*[0-9]')), findsNothing);
    expect(find.textContaining('Rente estimée'), findsNothing);
    expect(find.textContaining('Perte'), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('CI years stay a count to examine without a personal effect',
      (tester) async {
    await tester.pumpWidget(
      buildWidget(ciObservedMissingContributionYears: 4),
    );

    expect(find.byKey(const Key('expat_avs_gap_documented')), findsOneWidget);
    expect(
      find.text("Années à examiner d'après l'extrait CI : 4"),
      findsOneWidget,
    );
    expect(find.textContaining('certifiées'), findsNothing);
    expect(
      find.textContaining(
        'Ce nombre ne détermine ni ta durée complète de cotisation',
      ),
      findsOneWidget,
    );
    expect(find.textContaining(RegExp(r'44|%')), findsNothing);
    expect(
      find.textContaining(
        RegExp(r'minimum|minimale|minimal|au moins', caseSensitive: false),
      ),
      findsNothing,
    );
    expect(
      find.textContaining(RegExp(r'rente\s*-', caseSensitive: false)),
      findsNothing,
    );
    expect(find.textContaining(RegExp(r'CHF\s*[0-9]')), findsNothing);
  });

  testWidgets('explicit CI zero stays an observed zero, not unknown',
      (tester) async {
    await tester.pumpWidget(
      buildWidget(ciObservedMissingContributionYears: 0),
    );

    expect(find.byKey(const Key('expat_avs_gap_documented')), findsOneWidget);
    expect(find.byKey(const Key('expat_avs_gap_unknown')), findsNothing);
    expect(find.textContaining("extrait CI : 0"), findsOneWidget);
    expect(find.textContaining(RegExp(r'0\s*(sur|/|%)')), findsNothing);
  });

  test('French CI wording matches the verified Swiss verdict exactly',
      () async {
    final l = await S.delegate.load(const Locale('fr'));

    expect(
      l.expatAvsCiObservedMissingYearsTitle(4),
      "Années à examiner d'après l'extrait CI : 4",
    );
    expect(
      l.expatAvsCiObservedMissingYearsBody,
      "Ce nombre ne détermine ni ta durée complète de cotisation, ni l’échelle, ni une réduction de ta rente. La caisse vérifie les périodes qui peuvent être prises en compte, puis fixe l’échelle et le montant officiels. Le montant dépend aussi du revenu annuel moyen déterminant et des bonifications reconnues.",
    );
  });

  testWidgets('keeps voluntary AVS unknown and lists every official condition',
      (tester) async {
    await tester.pumpWidget(buildWidget());

    expect(find.textContaining('AVS obligatoire'), findsWidgets);
    expect(find.textContaining('cinq années consécutives'), findsWidgets);
    expect(find.textContaining('hors de Suisse, de l’UE et de l’AELE'),
        findsWidgets);
    expect(find.textContaining('nationalité suisse, UE ou AELE'), findsWidgets);
    expect(find.textContaining('dans les douze mois'), findsWidgets);
    expect(find.textContaining('ne confirme aucune éligibilité'), findsWidgets);
  });

  test('six locales retain the five voluntary-AVS conditions', () async {
    const expected = <String, String>{
      'fr':
          'Sortie de l’AVS obligatoire · cinq années consécutives et sans interruption d’assurance AVS suisse immédiatement avant la sortie · domicile hors de Suisse, de l’UE et de l’AELE · nationalité suisse, UE ou AELE admissible · demande dans les douze mois. MINT ne confirme aucune éligibilité.',
      'en':
          'Exit from compulsory AVS · five consecutive, uninterrupted years insured under Swiss AVS immediately before exit · residence outside Switzerland, the EU and EFTA · eligible Swiss, EU or EFTA nationality · application within twelve months. MINT does not confirm eligibility.',
      'de':
          'Austritt aus der obligatorischen AHV · fünf aufeinanderfolgende, ununterbrochene Versicherungsjahre in der schweizerischen AHV unmittelbar vor dem Austritt · Wohnsitz ausserhalb der Schweiz, der EU und der EFTA · zulässige schweizerische, EU- oder EFTA-Staatsangehörigkeit · Gesuch innerhalb von zwölf Monaten. MINT bestätigt keine Aufnahmeberechtigung.',
      'it':
          'Uscita dall’AVS obbligatoria · cinque anni consecutivi e senza interruzione di assicurazione AVS svizzera immediatamente prima dell’uscita · domicilio fuori dalla Svizzera, dall’UE e dall’AELS · nazionalità svizzera, UE o AELS ammessa · domanda entro dodici mesi. MINT non conferma l’ammissibilità.',
      'es':
          'Salida del AVS obligatorio · cinco años consecutivos y sin interrupción de seguro AVS suizo inmediatamente antes de la salida · domicilio fuera de Suiza, la UE y la AELC · nacionalidad suiza, UE o AELC admisible · solicitud dentro de los doce meses. MINT no confirma la admisibilidad.',
      'pt':
          'Saída do AVS obrigatório · cinco anos consecutivos e sem interrupção de seguro AVS suíço imediatamente antes da saída · domicílio fora da Suíça, da UE e da EFTA · nacionalidade suíça, UE ou EFTA admissível · pedido no prazo de doze meses. A MINT não confirma a elegibilidade.',
    };

    for (final entry in expected.entries) {
      final l = await S.delegate.load(Locale(entry.key));
      expect(l.expatAvsVoluntaryUnknownBody, entry.value, reason: entry.key);
    }
  });

  testWidgets('guides to the independent CI and future-calculation paths',
      (tester) async {
    await tester.pumpWidget(buildWidget());

    expect(find.textContaining('extrait CI'), findsWidgets);
    expect(find.textContaining('formulaire 318.282'), findsWidgets);
    expect(find.textContaining('à vérifier'), findsWidgets);
  });

  testWidgets('truth disclaimer is educational, not personalised advice',
      (tester) async {
    await tester.pumpWidget(buildWidget());

    expect(find.textContaining('Information éducative'), findsOneWidget);
    expect(find.textContaining('pas un conseil personnalisé'), findsOneWidget);
  });

  testWidgets('official guide CTA invokes the required callback',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(buildWidget(
      onOpenAvsVerificationGuide: () => calls += 1,
    ));

    final cta = find.byKey(const Key('expat_avs_verification_guide_cta'));
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    expect(calls, 1);
  });

  testWidgets('has truthful AVS semantics', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('AVS.*vérifier', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
