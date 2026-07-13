import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';
import 'package:mint_mobile/widgets/coach/widget_renderer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestCoachProfileProvider extends CoachProfileProvider {
  CoachProfile? _testProfile;

  void setTestProfile(CoachProfile profile) {
    _testProfile = profile;
  }

  @override
  CoachProfile? get profile => _testProfile;
}

CoachProfile _profile({
  double salary = 7500,
  String canton = 'VS',
  String employmentStatus = 'salarie',
}) {
  return CoachProfile(
    birthYear: 1981,
    canton: canton,
    salaireBrutMensuel: salary,
    employmentStatus: employmentStatus,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2046),
      label: 'Retraite',
    ),
  );
}

Widget _buildTestApp(
  RagToolCall call, {
  CoachProfile? profile,
  bool includeProvider = true,
  void Function(Object? extra)? onDestination,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: WidgetRenderer.build(context, call) ??
              const SizedBox(key: Key('no-route-cta')),
        ),
      ),
      GoRoute(
        path: '/rachat-lpp',
        builder: (context, state) {
          onDestination?.call(state.extra);
          return const Scaffold(body: Text('Rachat'));
        },
      ),
    ],
  );

  Widget app = MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
  );

  if (includeProvider) {
    final provider = _TestCoachProfileProvider();
    if (profile != null) provider.setTestProfile(profile);
    app = ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: app,
    );
  }
  return app;
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WidgetRenderer route_to_screen readiness wiring', () {
    testWidgets(
        'ready decision uses canonical route, ignores legacy payload, and pushes no extra',
        (tester) async {
      Object? destinationExtra = Object();
      await tester.pumpWidget(_buildTestApp(
        const RagToolCall(
          name: 'route_to_screen',
          input: {
            'intent': 'lpp_buyback',
            'confidence': 0.9,
            'context_message': 'Voici ton simulateur.',
            'route': '/admin/evil',
            'is_partial': true,
            'prefill': {'salaireBrut': 1},
          },
        ),
        profile: _profile(),
        onDestination: (extra) => destinationExtra = extra,
      ));
      await tester.pump();

      final card = tester.widget<RouteSuggestionCard>(
        find.byType(RouteSuggestionCard),
      );
      expect(card.route, '/rachat-lpp');
      expect(card.isPartial, isFalse);
      expect(card.contextMessage, 'Voici ton simulateur.');

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Rachat'), findsOneWidget);
      expect(destinationExtra, isNull);
    });

    testWidgets('partial decision renders canonical route with warning',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        const RagToolCall(
          name: 'route_to_screen',
          input: {
            'intent': 'libre_passage',
            'confidence': 0.8,
            'context_message': 'Estimation disponible.',
            'is_partial': false,
          },
        ),
        profile: _profile(employmentStatus: ''),
      ));
      await tester.pump();

      final card = tester.widget<RouteSuggestionCard>(
        find.byType(RouteSuggestionCard),
      );
      expect(card.route, '/libre-passage');
      expect(card.isPartial, isTrue);
    });

    testWidgets('blocked askFirst decision renders no CTA', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        const RagToolCall(
          name: 'route_to_screen',
          input: {
            'intent': 'cantonal_fiscal_comparator',
            'confidence': 0.9,
            'context_message': 'Comparons les cantons.',
          },
        ),
        profile: _profile(salary: 0),
      ));
      await tester.pump();

      expect(find.byType(RouteSuggestionCard), findsNothing);
    });

    testWidgets('low confidence renders no CTA even for a ready profile',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        const RagToolCall(
          name: 'route_to_screen',
          input: {
            'intent': 'lpp_buyback',
            'confidence': 0.49,
            'context_message': 'Peut-être ce simulateur.',
          },
        ),
        profile: _profile(),
      ));
      await tester.pump();

      expect(find.byType(RouteSuggestionCard), findsNothing);
    });

    for (final invalidConfidence in <double>[
      double.nan,
      double.infinity,
      -0.1,
      1.1,
    ]) {
      testWidgets('invalid confidence $invalidConfidence fails closed',
          (tester) async {
        await tester.pumpWidget(_buildTestApp(
          RagToolCall(
            name: 'route_to_screen',
            input: {
              'intent': 'lpp_buyback',
              'confidence': invalidConfidence,
            },
          ),
          profile: _profile(),
        ));
        await tester.pump();

        expect(find.byType(RouteSuggestionCard), findsNothing);
      });
    }

    testWidgets('missing confidence fails closed', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        const RagToolCall(
          name: 'route_to_screen',
          input: {
            'intent': 'lpp_buyback',
            'context_message': 'Voici ton simulateur.',
          },
        ),
        profile: _profile(),
      ));
      await tester.pump();

      expect(find.byType(RouteSuggestionCard), findsNothing);
    });

    testWidgets('provider with absent profile fails closed', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        const RagToolCall(
          name: 'route_to_screen',
          input: {
            'intent': 'lpp_buyback',
            'confidence': 0.9,
          },
        ),
      ));
      await tester.pump();

      expect(find.byType(RouteSuggestionCard), findsNothing);
    });

    testWidgets('missing provider fails closed without throwing',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        const RagToolCall(
          name: 'route_to_screen',
          input: {
            'intent': 'lpp_buyback',
            'confidence': 0.9,
            'route': '/rachat-lpp',
          },
        ),
        includeProvider: false,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(RouteSuggestionCard), findsNothing);
    });

    testWidgets('legacy route without intent is ignored', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        const RagToolCall(
          name: 'route_to_screen',
          input: {
            'route': '/rachat-lpp',
            'confidence': 0.9,
            'is_partial': false,
            'prefill': {'avoirLpp': 70377},
          },
        ),
        profile: _profile(),
      ));
      await tester.pump();

      expect(find.byType(RouteSuggestionCard), findsNothing);
    });

    testWidgets('unknown intent renders no CTA', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        const RagToolCall(
          name: 'route_to_screen',
          input: {
            'intent': 'unknown_financial_surface',
            'confidence': 0.9,
          },
        ),
        profile: _profile(),
      ));
      await tester.pump();

      expect(find.byType(RouteSuggestionCard), findsNothing);
    });
  });
}
