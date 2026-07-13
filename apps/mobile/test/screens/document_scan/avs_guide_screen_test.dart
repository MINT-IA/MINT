import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/document_scan/avs_guide_screen.dart';

void main() {
  test('official form URL follows supported locale with EN fallback', () {
    const expectedByLocale = <String, String>{
      'fr': 'https://www.ahv-iv.ch/p/318.282.f',
      'de': 'https://www.ahv-iv.ch/p/318.282.d',
      'it': 'https://www.ahv-iv.ch/p/318.282.i',
      'en': 'https://www.ahv-iv.ch/p/318.282.e',
      'es': 'https://www.ahv-iv.ch/p/318.282.e',
      'pt': 'https://www.ahv-iv.ch/p/318.282.e',
    };

    for (final entry in expectedByLocale.entries) {
      expect(
        avsOfficialFuturePensionFormUri(Locale(entry.key)).toString(),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('official CI request opens the domicile-aware acquisition hub', () {
    expect(
      avsOfficialIndividualAccountRequestUri().toString(),
      'https://www.ahv-iv.ch/fr/Formulaires/Demande-dextrait-de-compte',
    );
  });

  testWidgets('guide presents independent CI and future-calculation branches',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final opened = <Uri>[];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: AvsGuideScreen(
        openExternalUri: (uri) async {
          opened.add(uri);
          return true;
        },
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('avs_ci_branch')), findsOneWidget);
    expect(find.textContaining('A — Vérifier les années, revenus et lacunes'),
        findsOneWidget);
    expect(find.textContaining('extrait CI'), findsWidgets);
    expect(
        find.byKey(const Key('avs_future_calculation_branch')), findsOneWidget);
    expect(find.textContaining('B — Demander séparément le calcul futur'),
        findsOneWidget);
    expect(find.textContaining('318.282'), findsWidgets);
    expect(
      find.textContaining('couples mariés et les partenariats enregistrés'),
      findsOneWidget,
    );
    expect(find.textContaining('demande commune'), findsOneWidget);
    expect(find.textContaining('demande par personne'), findsNothing);

    final ciCta = find.byKey(const Key('avs_official_ci_request_cta'));
    await tester.ensureVisible(ciCta);
    await tester.tap(ciCta);
    await tester.pump();
    expect(opened, [avsOfficialIndividualAccountRequestUri()]);

    final formCta = find.byKey(const Key('avs_official_form_cta'));
    await tester.ensureVisible(formCta);
    await tester.tap(formCta);
    await tester.pump();
    expect(
      opened,
      [
        avsOfficialIndividualAccountRequestUri(),
        avsOfficialFuturePensionFormUri(const Locale('fr')),
      ],
    );

    expect(find.byKey(const Key('avs_ci_scan_cta')), findsOneWidget);
  });

  test('six locales keep CI and future-calculation paths separate', () async {
    const expectedCi = <String, String>{
      'fr': 'A — Vérifier les années, revenus et lacunes',
      'en': 'A — Check years, income and gaps',
      'de': 'A — Jahre, Einkommen und Lücken prüfen',
      'it': 'A — Verificare anni, redditi e lacune',
      'es': 'A — Verificar años, ingresos y lagunas',
      'pt': 'A — Verificar anos, rendimentos e lacunas',
    };
    const expectedFuture = <String, String>{
      'fr': 'B — Demander séparément le calcul futur 318.282',
      'en': 'B — Separately request future calculation 318.282',
      'de': 'B — Die Vorausberechnung 318.282 separat beantragen',
      'it': 'B — Richiedere separatamente il calcolo futuro 318.282',
      'es': 'B — Solicitar por separado el cálculo futuro 318.282',
      'pt': 'B — Pedir separadamente o cálculo futuro 318.282',
    };
    const jointTokens = <String, String>{
      'fr': 'demande commune',
      'en': 'joint request',
      'de': 'gemeinsames Gesuch',
      'it': 'domanda comune',
      'es': 'solicitud conjunta',
      'pt': 'pedido conjunto',
    };
    const registeredPartnershipTokens = <String, String>{
      'fr': 'partenariats enregistrés',
      'en': 'registered partnerships',
      'de': 'eingetragene Partnerschaften',
      'it': 'unioni domestiche registrate',
      'es': 'parejas registradas',
      'pt': 'parcerias registadas',
    };

    for (final locale in expectedCi.keys) {
      final l = await S.delegate.load(Locale(locale));
      expect(l.avsGuideStep1Title, expectedCi[locale], reason: locale);
      expect(l.avsGuideStep2Title, expectedFuture[locale], reason: locale);
      expect(l.avsGuideStep2Subtitle, contains(jointTokens[locale]),
          reason: locale);
      expect(
        l.avsGuideStep2Subtitle,
        contains(registeredPartnershipTokens[locale]),
        reason: locale,
      );
    }
  });
}
