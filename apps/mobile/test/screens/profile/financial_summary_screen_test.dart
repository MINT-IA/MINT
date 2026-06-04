import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/profile/financial_summary_screen.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:provider/provider.dart';

class _FakeCoachProfileProvider extends CoachProfileProvider {
  _FakeCoachProfileProvider(this._profile);

  final CoachProfile? _profile;

  @override
  CoachProfile? get profile => _profile;
}

Widget _pumpable(CoachProfile? profile) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(
        value: _FakeCoachProfileProvider(profile),
      ),
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
    ],
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: FinancialSummaryScreen(),
    ),
  );
}

void main() {
  testWidgets('empty material profile shows diagnostic state, not covered gap',
      (tester) async {
    await tester.pumpWidget(_pumpable(CoachProfile.fromWizardAnswers({})));
    await tester.pumpAndSettle();

    expect(find.text('Aucun profil renseigné'), findsOneWidget);
    expect(find.text('Commencer le diagnostic'), findsOneWidget);
    expect(find.text('Tu es bien couvert·e'), findsNothing);
  });

  testWidgets('material profile leads with dossier facts before projection',
      (tester) async {
    tester.view.physicalSize = const Size(368, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final profile = CoachProfile.fromWizardAnswers(
      CoachProfileSeeds.registry['julien_swiss']!.toWizardAnswers(
        now: DateTime(2026, 6, 4),
      ),
    );

    await tester.pumpWidget(_pumpable(profile));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile_dossier_facts_summary')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find
          .byKey(const ValueKey('profile_dossier_provenance_summary'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(
      find
          .byKey(const ValueKey('profile_dossier_correction_action'))
          .hitTestable(),
      findsOneWidget,
    );

    final factsHeader = find.text('Ce que tu as');
    final projectionHeader = find.text('À la retraite, il te manquera');

    expect(factsHeader, findsOneWidget);
    expect(projectionHeader, findsOneWidget);
    expect(
      tester.getTopLeft(factsHeader).dy,
      lessThan(tester.getTopLeft(projectionHeader).dy),
    );
    expect(projectionHeader.hitTestable(), findsNothing);
  });

  testWidgets('dossier correction sheet covers income housing LAMal and debts',
      (tester) async {
    final profile = CoachProfile.fromWizardAnswers(
      CoachProfileSeeds.registry['julien_swiss']!.toWizardAnswers(
        now: DateTime(2026, 6, 4),
      ),
    );

    await tester.pumpWidget(_pumpable(profile));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('profile_dossier_correction_action')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Corriger les faits du dossier'), findsOneWidget);
    expect(find.text('Revenus bruts mensuels (CHF)'), findsOneWidget);
    expect(find.text('Loyer mensuel (CHF)'), findsOneWidget);
    expect(find.text('Prime LAMal mensuelle (CHF)'), findsOneWidget);

    await tester.drag(
      find.text('Prime LAMal mensuelle (CHF)'),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hypothèque (CHF)'), findsOneWidget);
    expect(find.text('Crédit consommation (CHF)'), findsOneWidget);
  });
}
