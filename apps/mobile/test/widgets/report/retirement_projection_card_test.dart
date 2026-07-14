import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/widgets/report/retirement_projection_card.dart';
import 'package:mint_mobile/widgets/report/thematic_card.dart';

void main() {
  testWidgets(
    'shows AVS, LPP, and 3a pending with their real evidence routes',
    (tester) async {
      const projection = RetirementProjection(
        yearsUntilRetirement: 12,
        lppCapital: null,
        pillar3aCapital: null,
        monthlyAvsRent: 2222,
        monthlyLppRent: null,
        currentMonthlyIncome: 10000,
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: ThematicCard(
                emoji: '🏦',
                title: 'Retraite',
                status: CardStatus.aVerifier,
                children: [RetirementProjectionCard(projection: projection)],
              ),
            ),
          ),
          GoRoute(
            path: '/scan/avs-guide',
            builder: (_, __) => const Scaffold(
              body: Text('avs-guide-destination'),
            ),
          ),
          GoRoute(
            path: '/scan',
            builder: (_, state) => Scaffold(
              body: Text(
                state.extra == DocumentType.lppCertificate
                    ? 'lpp-scan-destination'
                    : 'wrong-scan-destination',
              ),
            ),
          ),
          GoRoute(
            path: '/data-block/3a',
            builder: (_, __) => const Scaffold(
              body: Text('3a-data-destination'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('financial_report_avs_pending')),
          findsOneWidget);
      expect(find.byKey(const Key('financial_report_lpp_pending')),
          findsOneWidget);
      expect(
          find.byKey(const Key('financial_report_3a_pending')), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('financial_report_avs_pending'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('financial_report_lpp_pending'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('financial_report_3a_pending'),
        findsOneWidget,
      );
      expect(
        find.text('Vérifie ton compte et demande ton calcul AVS'),
        findsOneWidget,
      );
      expect(find.text('Ajouter mon certificat LPP'), findsOneWidget);
      expect(find.text('Compléter mes données 3a'), findsOneWidget);
      expect(find.textContaining("CHF\u00a01'234"), findsNothing);
      expect(find.textContaining("CHF\u00a060'000"), findsNothing);
      expect(find.textContaining("CHF\u00a02'222"), findsNothing);
      expect(find.textContaining("CHF\u00a03'456"), findsNothing);
      expect(find.textContaining('Taux de remplacement'), findsNothing);
      expect(find.textContaining('rente réduite'), findsNothing);
      expect(find.text('À vérifier'), findsNWidgets(3));
      expect(find.text('À renforcer'), findsNothing);
      expect(find.text('Alerte'), findsNothing);

      await tester.tap(find.text('Demande ton calcul AVS officiel'));
      await tester.pumpAndSettle();
      expect(find.text('avs-guide-destination'), findsOneWidget);

      router.go('/');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter mon certificat LPP'));
      await tester.pumpAndSettle();
      expect(find.text('lpp-scan-destination'), findsOneWidget);

      router.go('/');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compléter mes données 3a'));
      await tester.pumpAndSettle();
      expect(find.text('3a-data-destination'), findsOneWidget);
    },
  );
}
